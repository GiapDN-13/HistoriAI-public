"""Chuỗi ngày học (streak) — tính theo NGÀY GIỜ VIỆT NAM.

Trước 27/09 con số này luôn bằng 0: app không bao giờ gọi /me/streak, mà endpoint
cũ lại so với `UserProgress.updated_at` — trường vừa bị chính lượt nộp quiz đặt
thành hôm nay, nên có gọi cũng luôn ra "đã cập nhật hôm nay".

Giờ lưu hẳn ngày học gần nhất (`users.ngay_hoc_cuoi`) và gọi `ghi_ngay_hoc` ngay
trong các hành động học thật (nộp quiz, hỏi vĩ nhân khi đã đăng nhập):
  • cùng ngày      → giữ nguyên
  • hôm qua        → +1
  • cách hơn 1 ngày → về 1
"Ngày" theo giờ Việt Nam — học lúc 6 giờ sáng không được tính là "hôm qua" chỉ
vì máy chủ chạy giờ UTC.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from app.models.user import User

GIO_VN = timezone(timedelta(hours=7))


def hom_nay() -> date:
    return datetime.now(GIO_VN).date()


def ghi_ngay_hoc(user: User, hom_nay_: date | None = None) -> int:
    """Cập nhật streak cho một lượt học. KHÔNG commit — người gọi commit."""
    nay = hom_nay_ or hom_nay()
    cuoi = user.ngay_hoc_cuoi
    if cuoi == nay:
        return user.streak or 0
    if cuoi == nay - timedelta(days=1):
        user.streak = (user.streak or 0) + 1
    else:
        user.streak = 1
    user.ngay_hoc_cuoi = nay
    return user.streak


def streak_hien_tai(user: User, hom_nay_: date | None = None) -> int:
    """Streak để HIỂN THỊ: bỏ lỡ quá một ngày thì chuỗi đã đứt, hiện 0 dù cột
    trong CSDL còn giữ số cũ (chỉ ghi lại ở lần học kế tiếp)."""
    nay = hom_nay_ or hom_nay()
    cuoi = user.ngay_hoc_cuoi
    if cuoi is None or (nay - cuoi).days > 1:
        return 0
    return user.streak or 0


def iso_utc(dt: datetime | None) -> str | None:
    """Thời điểm dạng ISO CÓ múi giờ. SQLite trả datetime không múi giờ (đã là UTC):
    gửi thẳng thì app hiểu là giờ địa phương → lượt làm lúc 20:23 hiện thành 13:23."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat()


def ngay_vn(dt: datetime | None) -> str | None:
    """Ngày theo giờ Việt Nam (đăng ký lúc 6 giờ sáng không bị tính là hôm trước)."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(GIO_VN).date().isoformat()
