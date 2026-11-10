"""Hạn mức hỏi vĩ nhân MỖI NGÀY của bản miễn phí — thứ duy nhất Premium mở khoá.

KHÁC `gioi_han.py` Ở ĐÂU
    `gioi_han.py` là lưới chống lạm dụng (theo phút, giờ, IP, trần toàn hệ), nằm trong
    bộ nhớ, mất khi khởi động lại — chấp nhận được vì nó không phải thứ ta bán. Hạn mức
    ngày này là ranh giới giữa miễn phí và trả phí nên lưu trong CSDL: khởi động lại
    máy chủ mà đặt lại số đếm là tặng cả ngày hỏi miễn phí. Premium chỉ bỏ trần NGÀY
    của từng người; các lớp ở `gioi_han.py` vẫn áp cho mọi người.

ĐẾM THEO AI
    Đã đăng nhập → theo tài khoản (đổi máy không lách được). Khách → theo `X-Client-Id`;
    thiếu header thì theo IP, giống `chan_lam_dung`. Ngày tính theo giờ Việt Nam.
"""
from __future__ import annotations

from fastapi import HTTPException, Request
from sqlalchemy import update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.thanh_toan import LuotChatNgay
from app.models.user import User
from app.services.gioi_han import dia_chi_that
from app.services.ngay_hoc import hom_nay
from app.services.thanh_toan import la_premium


def _doi_tuong(user: User | None, request: Request) -> str:
    if user is not None:
        return f"u:{user.id}"
    may = (request.headers.get("x-client-id") or "").strip()[:64]
    return f"k:{may}" if may else f"k:ip:{dia_chi_that(request)}"


def _het_luot(gioi_han: int) -> HTTPException:
    return HTTPException(402, detail={
        "ma": "het_luot_ngay",
        "thong_bao": f"Hôm nay bạn đã hỏi hết {gioi_han} câu miễn phí. "
                     "Nâng cấp Premium để hỏi không giới hạn.",
        "gioi_han": gioi_han,
    })


def xin_luot_ai(db: Session, user: User | None, request: Request) -> None:
    """Ghi nhận MỘT câu hỏi gọi AI, hoặc ném 402 nếu hôm nay đã hết lượt miễn phí.

    Chỉ gọi ở nhánh thật sự gọi AI (sau khi câu soạn sẵn đã được loại): câu gợi ý
    mở đầu không tốn token nên không được trừ vào lượt của học sinh.
    """
    # Quản trị (tài khoản demo của nhóm) không bị trần ngày: trình diễn trước hội đồng
    # mà hết 10 câu là hỏng buổi demo. Không hiện thành Premium ở /auth/me.
    if la_premium(user) or (user is not None and user.role == "admin"):
        return
    gioi_han = settings.CHAT_MIEN_PHI_NGAY if user is not None else settings.CHAT_KHACH_NGAY
    doi_tuong, ngay = _doi_tuong(user, request), hom_nay()

    # Cộng bằng UPDATE có điều kiện (so_luot < giới hạn) để kiểm và cộng là MỘT bước:
    # hai câu hỏi đến cùng lúc không cùng đọc "9" rồi cùng cộng thành 11.
    cau_lenh = (update(LuotChatNgay)
                .where(LuotChatNgay.doi_tuong == doi_tuong, LuotChatNgay.ngay == ngay,
                       LuotChatNgay.so_luot < gioi_han)
                .values(so_luot=LuotChatNgay.so_luot + 1))
    if db.execute(cau_lenh).rowcount:
        db.commit()
        return

    if db.query(LuotChatNgay.id).filter(LuotChatNgay.doi_tuong == doi_tuong,
                                        LuotChatNgay.ngay == ngay).first() is not None:
        db.rollback()
        raise _het_luot(gioi_han)   # có dòng mà không cộng được = đã chạm trần

    # Lần hỏi đầu tiên trong ngày: chưa có dòng nào.
    if gioi_han <= 0:
        raise _het_luot(gioi_han)
    db.add(LuotChatNgay(doi_tuong=doi_tuong, ngay=ngay, so_luot=1))
    try:
        db.commit()
    except IntegrityError:
        # Hai câu đầu tiên đến cùng lúc, bên kia tạo dòng trước: cộng lại như thường.
        db.rollback()
        xin_luot_ai(db, user, request)
