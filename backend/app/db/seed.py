"""Nạp dữ liệu mẫu 'Hào khí Đại Việt' vào DB.

Chạy:  python -m app.db.seed
Idempotent: bỏ qua bản ghi đã tồn tại (theo slug).
"""
import json
from pathlib import Path

from app.core.config import settings
from app.db.migrate_nhe import dam_bao_cot
from app.db.session import Base, SessionLocal, engine
from app.models.artifact import Artifact
from app.models.event import HistoricalEvent
from app.models.figure import HistoricalFigure
from app.models.quiz import QuizQuestion

DATA_FILE = Path(__file__).resolve().parents[2] / "data" / "seed_data.json"
# Do đường ống làm giàu dữ liệu sinh ra (data_pipeline/b7_xuat_seed.py). Tách
# tệp riêng để không bao giờ đè lên seed_data.json nhóm viết tay.
LAM_GIAU_FILE = DATA_FILE.with_name("seed_lam_giau.json")


def _resolve(url: str | None) -> str | None:
    """Thay {ASSET} bằng ASSET_BASE_URL thật từ config."""
    if not url:
        return url
    return url.replace("{ASSET}", settings.ASSET_BASE_URL.rstrip("/"))


def _nap_lam_giau(db, data: dict) -> None:
    """Nạp nội dung đường ống đã kiểm (seed_lam_giau.json).

    Với sự kiện CÓ SẴN chỉ điền các cột mới — tiêu đề, năm, tóm tắt, video do
    nhóm viết tay giữ nguyên. Sự kiện MỚI thì tạo hẳn.
    Câu hỏi khớp theo nội dung như phần quiz chính: có rồi thì cập nhật, không
    bao giờ xoá, để không lỡ tay xoá lịch sử làm bài của người học.
    """
    for e in data.get("events", []):
        cu = db.query(HistoricalEvent).filter_by(slug=e["slug"]).first()
        if cu is None:
            if not e.get("moi"):
                continue          # sự kiện có sẵn mà không thấy trong CSDL: không tự tạo
            cu = HistoricalEvent(
                slug=e["slug"], title=e["title"], year=e["year"], period=e.get("period"),
                era=e.get("era"), summary=e.get("summary_thcs"),
                thumbnail_url=_resolve(e.get("thumbnail_url")), features=e.get("features"),
            )
            db.add(cu)
        elif e.get("moi"):
            # sự kiện do đường ống tạo từ lần trước — được phép cập nhật cả phần hiển thị
            cu.title, cu.year = e["title"], e["year"]
            cu.period, cu.era = e.get("period"), e.get("era")
            cu.summary = e.get("summary_thcs")
            cu.thumbnail_url = _resolve(e.get("thumbnail_url"))
        if e.get("summary_thcs"):
            cu.summary_thcs = e["summary_thcs"]
            cu.summary_thpt = e["summary_thpt"]
        cu.grades = e.get("grades")
        cu.curriculum = e.get("curriculum")
        cu.sources = e.get("sources")
    db.commit()

    for q in data.get("quiz", []):
        event = db.query(HistoricalEvent).filter_by(slug=q["event_slug"]).first()
        if not event:
            continue
        cu = db.query(QuizQuestion).filter_by(event_id=event.id, question=q["question"]).first()
        if cu is None:
            cu = QuizQuestion(event_id=event.id, question=q["question"])
            db.add(cu)
        for k in ("option_a", "option_b", "option_c", "option_d", "correct_option",
                  "explanation", "difficulty", "curriculum_ref", "source_claims", "grade_min"):
            setattr(cu, k, q.get(k))
    db.commit()

    for f in data.get("figures", []):
        cu = db.query(HistoricalFigure).filter_by(slug=f["slug"]).first()
        if cu:
            cu.verified_facts = f.get("verified_facts")
            cu.sources = f.get("sources")
    for a in data.get("artifacts", []):
        cu = db.query(Artifact).filter_by(slug=a["slug"]).first()
        if cu:
            cu.sources = a.get("sources")
    db.commit()


def run() -> None:
    Base.metadata.create_all(bind=engine)
    dam_bao_cot()   # migrate nhẹ, xem app/db/migrate_nhe.py
    data = json.loads(DATA_FILE.read_text(encoding="utf-8"))
    db = SessionLocal()
    try:
        # --- Events ---
        # Sự kiện đã có thì CẬP NHẬT chứ không bỏ qua. Trước đây bỏ qua nên sửa
        # features hay đổi link video trong seed rồi chạy lại cũng không ăn thua —
        # phải xoá sạch cơ sở dữ liệu, kéo theo mất cả số liệu đo lường.
        for e in data["events"]:
            cu = db.query(HistoricalEvent).filter_by(slug=e["slug"]).first()
            if cu:
                cu.title = e["title"]
                cu.year = e["year"]
                cu.period = e["period"]
                cu.era = e["era"]
                cu.summary = e["summary"]
                cu.cinematic_video_url = _resolve(e["cinematic_video_url"])
                cu.thumbnail_url = _resolve(e["thumbnail_url"])
                cu.features = e["features"]
                continue
            db.add(HistoricalEvent(
                slug=e["slug"], title=e["title"], year=e["year"], period=e["period"],
                era=e["era"], summary=e["summary"],
                cinematic_video_url=_resolve(e["cinematic_video_url"]),
                thumbnail_url=_resolve(e["thumbnail_url"]), features=e["features"],
            ))
        db.commit()

        # --- Figures ---
        for f in data["figures"]:
            existing = db.query(HistoricalFigure).filter_by(slug=f["slug"]).first()
            if existing:
                # Đồng bộ dữ liệu cấu hình persona cho bản ghi đã có (idempotent).
                # model_url PHẢI qua _resolve như mọi đường dẫn tài nguyên khác.
                # Trước đây chỗ này bỏ quên, không lộ ra vì seed ghi sẵn URL
                # tuyệt đối; tới khi chuyển sang {ASSET} thì API trả nguyên chuỗi
                # "{ASSET}/models/..." và model 3D nhân vật tắt ngóm.
                moi = _resolve(f.get("model_url"))
                if moi and existing.model_url != moi:
                    existing.model_url = moi
                if existing.knowledge_boundary != f.get("knowledge_boundary"):
                    existing.knowledge_boundary = f.get("knowledge_boundary")
                continue
            db.add(HistoricalFigure(
                slug=f["slug"], name=f["name"], title=f["title"], period=f["period"],
                portrait_url=_resolve(f["portrait_url"]), persona_prompt=f["persona_prompt"],
                voice_id=f["voice_id"], is_featured=f["is_featured"],
                unlock_level=f["unlock_level"], model_url=_resolve(f.get("model_url")),
                knowledge_boundary=f.get("knowledge_boundary"),
            ))
        db.commit()

        # --- Artifacts ---
        # Cũng cập nhật thay vì bỏ qua, cùng lý do như phần sự kiện: đổi đường
        # dẫn model trong seed rồi chạy lại phải ăn ngay, không phải xoá DB.
        for a in data["artifacts"]:
            cu = db.query(Artifact).filter_by(slug=a["slug"]).first()
            if cu:
                cu.name = a["name"]
                cu.period = a["period"]
                cu.description = a["description"]
                cu.model_glb_url = _resolve(a["model_glb_url"])
                cu.model_usdz_url = _resolve(a["model_usdz_url"])
                cu.thumbnail_url = _resolve(a["thumbnail_url"])
                cu.real_scale_meters = a["real_scale_meters"]
                continue
            db.add(Artifact(
                slug=a["slug"], name=a["name"], period=a["period"],
                description=a["description"], model_glb_url=_resolve(a["model_glb_url"]),
                model_usdz_url=_resolve(a["model_usdz_url"]),
                thumbnail_url=_resolve(a["thumbnail_url"]),
                real_scale_meters=a["real_scale_meters"],
            ))
        db.commit()

        # --- Quiz (cần map event_slug -> event_id) ---
        for q in data["quiz"]:
            event = db.query(HistoricalEvent).filter_by(slug=q["event_slug"]).first()
            if not event:
                continue
            cu = db.query(QuizQuestion).filter_by(
                event_id=event.id, question=q["question"]
            ).first()
            if cu:
                # Cập nhật thay vì bỏ qua — cùng lý do như sự kiện và cổ vật.
                # Trước đây bỏ qua, nên sửa một đáp án SAI trong seed rồi chạy
                # lại cũng không ăn thua: phải xoá sạch cơ sở dữ liệu, kéo theo
                # mất cả lịch sử làm bài và số liệu đo lường.
                #
                # Khoá đối chiếu là NỘI DUNG câu hỏi. Sửa câu chữ của đề thì
                # coi như câu mới, câu cũ vẫn nằm lại — muốn bỏ hẳn thì phải
                # xoá tay. Chấp nhận đánh đổi này để không bao giờ lỡ tay xoá
                # mất lịch sử làm bài của người học.
                cu.option_a = q["option_a"]
                cu.option_b = q["option_b"]
                cu.option_c = q["option_c"]
                cu.option_d = q["option_d"]
                cu.correct_option = q["correct_option"]
                cu.explanation = q["explanation"]
                cu.difficulty = q["difficulty"]
                continue
            db.add(QuizQuestion(
                event_id=event.id, question=q["question"],
                option_a=q["option_a"], option_b=q["option_b"],
                option_c=q["option_c"], option_d=q["option_d"],
                correct_option=q["correct_option"], explanation=q["explanation"],
                difficulty=q["difficulty"],
            ))
        db.commit()

        if LAM_GIAU_FILE.exists():
            _nap_lam_giau(db, json.loads(LAM_GIAU_FILE.read_text(encoding="utf-8")))

        print(
            "[OK] Seed done:",
            db.query(HistoricalEvent).count(), "events,",
            db.query(HistoricalFigure).count(), "figures,",
            db.query(Artifact).count(), "artifacts,",
            db.query(QuizQuestion).count(), "quiz questions.",
        )
    finally:
        db.close()


if __name__ == "__main__":
    run()
