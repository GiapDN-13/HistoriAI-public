"""Route nội dung: sự kiện (timeline), nhân vật, hiện vật AR."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.artifact import Artifact
from app.models.event import HistoricalEvent
from app.models.figure import HistoricalFigure
from app.models.quiz import QuizQuestion
from app.schemas.content import ArtifactOut, EventOut, FigureOut

router = APIRouter(tags=["content"])


def _dem_quiz(db: Session) -> dict[int, int]:
    """Số câu hỏi theo từng sự kiện.

    Thẻ ở Đấu trường trước đây ghi cứng "3 câu trắc nghiệm" cho mọi trận, trong
    khi kho thật đã có 10 câu — vừa nói sai với người học, vừa bán rẻ nội dung
    nhóm đã soạn. Gộp một truy vấn ở đây thay vì để màn hình gọi từng sự kiện.
    """
    rows = (
        db.query(QuizQuestion.event_id, func.count(QuizQuestion.id))
        .group_by(QuizQuestion.event_id)
        .all()
    )
    return {eid: n for eid, n in rows}


def _kem_so_cau(ev: HistoricalEvent, dem: dict[int, int]) -> EventOut:
    out = EventOut.model_validate(ev)
    out.quiz_count = dem.get(ev.id, 0)
    return out


@router.get("/events", response_model=list[EventOut])
def list_events(era: str | None = None, db: Session = Depends(get_db)):
    """Danh sách sự kiện cho Timeline. Lọc theo era nếu có (co-dai/phong-kien/hien-dai)."""
    q = db.query(HistoricalEvent)
    if era:
        q = q.filter(HistoricalEvent.era == era)
    dem = _dem_quiz(db)
    return [_kem_so_cau(e, dem) for e in q.order_by(HistoricalEvent.year).all()]


@router.get("/events/{slug}", response_model=EventOut)
def get_event(slug: str, db: Session = Depends(get_db)):
    ev = db.query(HistoricalEvent).filter(HistoricalEvent.slug == slug).first()
    if not ev:
        raise HTTPException(404, "Không tìm thấy sự kiện")
    return _kem_so_cau(ev, _dem_quiz(db))


@router.get("/figures", response_model=list[FigureOut])
def list_figures(db: Session = Depends(get_db)):
    """Danh sách nhân vật cho Chat Vĩ Nhân."""
    return db.query(HistoricalFigure).order_by(HistoricalFigure.unlock_level).all()


@router.get("/artifacts", response_model=list[ArtifactOut])
def list_artifacts(db: Session = Depends(get_db)):
    """Danh sách hiện vật 3D cho AR Museum."""
    return db.query(Artifact).all()
