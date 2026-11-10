"""Route tiến độ học tập & leaderboard."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.event import HistoricalEvent
from app.models.progress import UserProgress
from app.models.quiz import QuizQuestion
from app.models.quiz_attempt import QuizAttempt
from app.models.user import User
from app.schemas.content import QuizQuestionOut
from app.services.anh_tai_len import url as anh_url
from app.services.ngay_hoc import ghi_ngay_hoc, iso_utc, ngay_vn, streak_hien_tai
from app.services.thanh_toan import duoc_xem_day_du

router = APIRouter(tags=["progress"])


@router.get("/me/progress")
def get_my_progress(
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    """Danh sách tiến độ của user hiện tại theo từng sự kiện."""
    progress_list = (
        db.query(UserProgress)
        .filter(UserProgress.user_id == current.id)
        .all()
    )
    # Map event_id → event slug/title để trả về
    event_ids = [p.event_id for p in progress_list]
    events = {e.id: e for e in db.query(HistoricalEvent).filter(HistoricalEvent.id.in_(event_ids)).all()}
    result = []
    for p in progress_list:
        ev = events.get(p.event_id)
        result.append({
            "event_slug": ev.slug if ev else None,
            "event_title": ev.title if ev else None,
            "mastery": p.mastery or 0,
            "quiz_best_score": p.quiz_best_score or 0,
            "updated_at": iso_utc(p.updated_at),
        })
    return result


def _ten_rut_gon(ho_ten: str | None) -> str:
    """"Đặng Nguyên Giáp" -> "Giáp Đ." — đủ để nhận ra mình, không đủ để lộ.

    Bảng vàng không cần biết đủ họ tên ai mới vui được. Người dùng sản phẩm
    này phần lớn là học sinh THCS/THPT, tức trẻ vị thành niên; đăng đủ họ tên
    lên một bảng ai cũng xem được là chuyện không nên có.
    """
    phan = (ho_ten or "").split()
    if not phan:
        return "Ẩn danh"
    if len(phan) == 1:
        return phan[0]
    return f"{phan[-1]} {phan[0][0]}."


@router.get("/leaderboard")
def get_leaderboard(
    limit: int = Query(10, ge=1, le=100),
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    """Top người dùng theo XP.

    PHẢI đăng nhập mới xem được. Trước đây endpoint này mở cho tất cả và trả
    về HỌ TÊN ĐẦY ĐỦ — ai biết đường dẫn cũng lấy được danh sách tên thật của
    toàn bộ người dùng.

    Trả thêm `la_toi` để màn hình tô đậm dòng của chính người đang xem mà không
    phải đoán bằng cách so tên.
    """
    top_users = (
        db.query(User)
        .filter(User.role != "admin")      # tài khoản quản trị của nhóm không thi đua
        .order_by(User.xp.desc())
        .limit(limit)
        .all()
    )
    ra = [
        {
            "rank": i + 1,
            "ten": _ten_rut_gon(u.full_name),
            "xp": u.xp,
            "level": u.level,
            "streak": streak_hien_tai(u),
            "la_toi": u.id == current.id,
            "avatar": u.avatar,
            "avatar_url": anh_url(u.avatar),
        }
        for i, u in enumerate(top_users)
    ]
    # Người xem ngoài top: nối thêm dòng của chính họ với hạng thật, để bảng vàng
    # luôn trả lời được "mình đang đứng thứ mấy".
    if not any(d["la_toi"] for d in ra) and current.role != "admin":
        hang = db.query(func.count(User.id)).filter(
            User.xp > (current.xp or 0), User.role != "admin").scalar() + 1
        ra.append({"rank": hang, "ten": _ten_rut_gon(current.full_name), "xp": current.xp,
                   "level": current.level, "streak": streak_hien_tai(current), "la_toi": True,
                   "avatar": current.avatar, "avatar_url": anh_url(current.avatar)})
    return ra


@router.post("/me/streak")
def update_streak(
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    """Ghi nhận một lượt học hôm nay (app gọi sau khi hỏi vĩ nhân). Nộp quiz tự ghi,
    không cần gọi. Gọi nhiều lần trong ngày không sao."""
    streak = ghi_ngay_hoc(current)
    db.commit()
    return {"streak": streak, "message": "Đã ghi nhận ngày học"}


@router.get("/me/thong-ke")
def thong_ke(
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    """Số liệu cho màn Hồ sơ: tổng câu đã làm, tỉ lệ đúng, số trận đã học, hạng."""
    tong, dung = db.query(
        func.count(QuizAttempt.id),
        func.sum(case((QuizAttempt.is_correct.is_(True), 1), else_=0)),
    ).filter(QuizAttempt.user_id == current.id).one()
    tong, dung = int(tong or 0), int(dung or 0)
    so_su_kien = db.query(func.count(UserProgress.id)).filter(
        UserProgress.user_id == current.id).scalar() or 0
    hang = db.query(func.count(User.id)).filter(User.xp > (current.xp or 0)).scalar() + 1
    tong_nguoi = db.query(func.count(User.id)).scalar() or 1
    return {
        "tong_cau": tong,
        "cau_dung": dung,
        "ti_le_dung": round(dung * 100 / tong) if tong else 0,
        "so_su_kien_da_hoc": so_su_kien,
        "hang": hang,
        "tong_nguoi": tong_nguoi,
        "streak": streak_hien_tai(current),
        "ngay_hoc_cuoi": current.ngay_hoc_cuoi.isoformat() if current.ngay_hoc_cuoi else None,
        "ngay_tham_gia": ngay_vn(current.created_at),
    }


def _khoa_luot(a: QuizAttempt) -> str:
    """Mã một lượt nộp. Dòng cũ không có lan_nop → gom theo sự kiện + phút nộp."""
    if a.lan_nop:
        return a.lan_nop
    phut = a.created_at.strftime("%Y%m%d%H%M") if a.created_at else "0"
    return f"cu-{a.event_id}-{phut}"


@router.get("/me/lich-su-quiz")
def lich_su_quiz(
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    """Các lượt làm bài gần nhất, mới → cũ: sự kiện, lúc nộp, đúng/tổng."""
    dong = (db.query(QuizAttempt).filter(QuizAttempt.user_id == current.id)
            .order_by(QuizAttempt.id.desc()).limit(limit * 15).all())
    luot: dict[str, dict] = {}
    for a in dong:
        k = _khoa_luot(a)
        l = luot.setdefault(k, {"ma": k, "event_id": a.event_id, "luc": a.created_at,
                                "dung": 0, "tong": 0})
        l["tong"] += 1
        l["dung"] += int(bool(a.is_correct))
    ds = list(luot.values())[:limit]
    su_kien = {e.id: e for e in db.query(HistoricalEvent).filter(
        HistoricalEvent.id.in_({l["event_id"] for l in ds})).all()} if ds else {}
    return [{
        "ma": l["ma"],
        "event_slug": su_kien[l["event_id"]].slug if l["event_id"] in su_kien else None,
        "event_title": su_kien[l["event_id"]].title if l["event_id"] in su_kien else None,
        "luc": iso_utc(l["luc"]),
        "dung": l["dung"],
        "tong": l["tong"],
    } for l in ds]


@router.get("/me/lich-su-quiz/{ma}")
def chi_tiet_luot(
    ma: str,
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    """Từng câu của một lượt: câu hỏi, đã chọn, đáp án đúng, giải thích."""
    dong = [a for a in db.query(QuizAttempt).filter(QuizAttempt.user_id == current.id)
            .filter((QuizAttempt.lan_nop == ma) if not ma.startswith("cu-")
                    else QuizAttempt.lan_nop.is_(None))
            .order_by(QuizAttempt.id).all() if _khoa_luot(a) == ma]
    if not dong:
        raise HTTPException(404, "Không tìm thấy lượt làm bài")
    cau = {q.id: q for q in db.query(QuizQuestion).filter(
        QuizQuestion.id.in_([a.question_id for a in dong])).all()}
    return [{
        "question_id": a.question_id,
        "question": cau[a.question_id].question if a.question_id in cau else "(câu hỏi đã bị gỡ)",
        "options": ({k: getattr(cau[a.question_id], f"option_{k.lower()}") for k in "ABCD"}
                    if a.question_id in cau else {}),
        "selected_option": a.selected_option or "",
        "correct_option": cau[a.question_id].correct_option if a.question_id in cau else "",
        "correct": bool(a.is_correct),
        "explanation": cau[a.question_id].explanation if a.question_id in cau else None,
    } for a in dong]


# Bản thường ôn tối đa chừng này câu sai gần nhất mỗi lượt; Premium ôn hết.
TOI_DA_CAU_SAI_MIEN_PHI = 5


@router.get("/me/cau-sai")
def cau_sai(
    limit: int = Query(10, ge=1, le=200),
    kem_tong: bool = Query(False),
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    """Câu mà LẦN GẦN NHẤT người này trả lời còn sai — bộ "Ôn câu sai".

    Trả lời đúng ở lần ôn là câu tự rời khỏi danh sách. Không trả đáp án đúng
    (chơi lại như quiz thường, chấm qua /quiz/check và /quiz/submit).

    BẢN THƯỜNG CHỈ ĐƯỢC 5 CÂU GẦN NHẤT — cắt ở đây chứ không ở app, nên sửa app hay
    gọi thẳng API cũng không lấy được câu thứ 6. Premium/quản trị nhận tới `limit`.

    `kem_tong=1` → trả {"cau_hoi": [...], "tong": số câu sai thật, "da_cat": số câu bị
    giấu}. Không đặt thì vẫn trả mảng trơn như trước: APK đã cài (0.5.x) đọc thẳng
    mảng, đổi hình dạng là màn "Lịch sử học" của họ hỏng cho tới khi họ cập nhật.
    """
    moi_nhat = (db.query(QuizAttempt.question_id, func.max(QuizAttempt.id).label("mid"))
                .filter(QuizAttempt.user_id == current.id)
                .group_by(QuizAttempt.question_id).subquery())
    goc = (db.query(QuizAttempt).join(moi_nhat, QuizAttempt.id == moi_nhat.c.mid)
           .join(QuizQuestion, QuizQuestion.id == QuizAttempt.question_id)   # bỏ câu đã gỡ khỏi kho
           .filter(QuizAttempt.is_correct.is_(False)))
    tong = goc.count()
    tran = limit if duoc_xem_day_du(current) else min(limit, TOI_DA_CAU_SAI_MIEN_PHI)
    sai = goc.order_by(QuizAttempt.id.desc()).limit(tran).all()
    cau = {q.id: q for q in db.query(QuizQuestion).filter(
        QuizQuestion.id.in_([a.question_id for a in sai])).all()} if sai else {}
    su_kien = {e.id: e for e in db.query(HistoricalEvent).filter(
        HistoricalEvent.id.in_({q.event_id for q in cau.values()})).all()} if cau else {}
    ra = []
    for a in sai:
        q = cau.get(a.question_id)
        if q is None:
            continue
        d = QuizQuestionOut.model_validate(q).model_dump()
        d["event_slug"] = su_kien[q.event_id].slug if q.event_id in su_kien else None
        d["event_title"] = su_kien[q.event_id].title if q.event_id in su_kien else None
        ra.append(d)
    if kem_tong:
        # da_cat = số câu bản thường chưa mở được, KHÔNG phải số câu vượt `limit` mà
        # người gọi tự đặt: Premium gọi limit=3 vẫn thấy da_cat=0, không bị gài mua.
        da_cat = 0 if duoc_xem_day_du(current) else max(0, tong - TOI_DA_CAU_SAI_MIEN_PHI)
        return {"cau_hoi": ra, "tong": tong, "da_cat": da_cat}
    return ra
