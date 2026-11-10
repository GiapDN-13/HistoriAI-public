"""Route Đấu Trường Sử Việt: lấy câu hỏi & chấm điểm + cộng XP."""
import math
import secrets

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_current_user_optional
from app.db.session import get_db
from app.models.event import HistoricalEvent
from app.models.progress import UserProgress
from app.models.quiz import QuizQuestion
from app.models.quiz_attempt import QuizAttempt
from app.models.user import User
from app.schemas.content import (
    QuizAnswer,
    QuizCheckAnswer,
    QuizCheckResult,
    QuizQuestionOut,
    QuizSubmitResult,
)
from app.services.ngay_hoc import ghi_ngay_hoc

router = APIRouter(prefix="/quiz", tags=["quiz"])

# Mỗi câu đúng được 10 XP gốc
XP_PER_CORRECT_BASE = 10


def _calc_level(xp: int) -> int:
    """Cấp độ = floor(sqrt(xp / 100)) + 1."""
    return max(1, int(math.isqrt(xp // 100)) + 1)


@router.get("/{event_slug}", response_model=list[QuizQuestionOut])
def get_quiz(event_slug: str, db: Session = Depends(get_db)):
    """Lấy bộ câu hỏi cho một sự kiện (đáp án đúng không trả ra ngoài)."""
    event = db.query(HistoricalEvent).filter(HistoricalEvent.slug == event_slug).first()
    if not event:
        raise HTTPException(404, "Không tìm thấy sự kiện")
    return db.query(QuizQuestion).filter(QuizQuestion.event_id == event.id).all()


@router.post("/check", response_model=QuizCheckResult)
def check_quiz_answer(
    answer: QuizCheckAnswer,
    db: Session = Depends(get_db),
    _current: User | None = Depends(get_current_user_optional),
):
    """Chấm một đáp án để phản hồi tức thì, không ghi điểm hay tiến độ.

    KHÔNG bắt đăng nhập: trước đây bắt, nên khách bấm đáp án là báo lỗi rồi đồng
    hồ chạy lại mãi — trong khi màn quiz mời "chơi thử không cần tài khoản". Chấm
    một câu không ghi gì.

    Từ 21/10 trả kèm đáp án đúng + lời giải để app giảng lại ngay khi chọn sai
    (góp ý người dùng; màn hướng dẫn cũng hứa "sai thì được giảng lại ngay"). Không
    làm lộ thêm gì: trước đây gọi thử đủ 4 phương án cũng biết đáp án, còn XP chỉ
    cộng ở /submit, một lần cho mỗi câu.
    """
    question = db.query(QuizQuestion).filter(QuizQuestion.id == answer.question_id).first()
    if not question:
        raise HTTPException(404, "Không tìm thấy câu hỏi")
    dung = question.correct_option.upper()
    return QuizCheckResult(
        question_id=question.id,
        correct=dung == answer.selected_option,
        correct_option=dung,
        explanation=question.explanation,
    )


@router.post("/submit", response_model=list[QuizSubmitResult])
def submit_quiz(
    answers: list[QuizAnswer],
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    """Chấm điểm + cộng XP + cập nhật tiến độ + chuỗi ngày học.

    XP CHỈ CỘNG CHO LẦN ĐẦU TRẢ LỜI ĐÚNG mỗi câu. Trước đây làm lại cùng bộ câu là
    lại +10 XP mỗi câu đúng — cày vô hạn, bảng vàng mất nghĩa. Làm lại vẫn được
    chấm, vẫn nâng điểm tốt nhất, chỉ không cộng XP lần hai.
    """
    asked_ids = [a.question_id for a in answers]
    questions = {
        q.id: q
        for q in db.query(QuizQuestion).filter(QuizQuestion.id.in_(asked_ids)).all()
    } if asked_ids else {}
    # Câu người này đã từng trả lời đúng — không cộng XP lại
    da_dung = {
        qid for (qid,) in db.query(QuizAttempt.question_id)
        .filter(QuizAttempt.user_id == current.id, QuizAttempt.is_correct.is_(True),
                QuizAttempt.question_id.in_(asked_ids))
        .distinct().all()
    } if asked_ids else set()

    lan_nop = secrets.token_hex(8)
    results: list[QuizSubmitResult] = []
    xp_moi = 0
    correct_by_event: dict[int, int] = {}
    tinh_roi: set[int] = set()          # một câu gửi hai lần trong cùng lượt: chỉ tính một

    for ans in answers:
        q = questions.get(ans.question_id)
        if not q or q.id in tinh_roi:
            continue
        tinh_roi.add(q.id)
        correct = q.correct_option.upper() == ans.selected_option.upper()
        xp = XP_PER_CORRECT_BASE if correct and q.id not in da_dung else 0
        xp_moi += xp
        correct_by_event[q.event_id] = correct_by_event.get(q.event_id, 0) + int(correct)
        db.add(QuizAttempt(
            user_id=current.id,
            event_id=q.event_id,
            question_id=q.id,
            selected_option=(ans.selected_option or "").upper()[:1],
            is_correct=correct,
            lan_nop=lan_nop,
        ))
        results.append(QuizSubmitResult(
            question_id=q.id,
            correct=correct,
            correct_option=q.correct_option,
            explanation=q.explanation,
            xp=xp,
        ))

    if xp_moi:
        current.xp = (current.xp or 0) + xp_moi
        current.level = _calc_level(current.xp)
    if results:
        ghi_ngay_hoc(current)

    total_by_event: dict[int, int] = dict(
        db.query(QuizQuestion.event_id, func.count(QuizQuestion.id))
        .filter(QuizQuestion.event_id.in_(list(correct_by_event)))
        .group_by(QuizQuestion.event_id)
        .all()
    ) if correct_by_event else {}

    for eid, event_correct in correct_by_event.items():
        total = total_by_event.get(eid, 0)
        mastery = int(event_correct / total * 100) if total else 0
        progress = db.query(UserProgress).filter_by(user_id=current.id, event_id=eid).first()
        if not progress:
            progress = UserProgress(user_id=current.id, event_id=eid)
            db.add(progress)
        progress.mastery = max(progress.mastery or 0, mastery)
        progress.quiz_best_score = max(progress.quiz_best_score or 0, event_correct)

    db.commit()
    return results
