"""Sự kiện đo lường hành vi người dùng — nguồn số liệu cho báo cáo.

Đừng nhầm với `models/event.py`: file đó là *sự kiện lịch sử* (Bạch Đằng,
Lam Sơn...). File này ghi lại *người dùng đã làm gì* trong app.

Hai định danh song song:
  - `client_id`  : máy/trình duyệt, lưu bền trong shared_preferences → đếm
                   người dùng hoạt động (DAU/WAU) và tỉ lệ quay lại, kể cả
                   khách chưa đăng nhập.
  - `session_id` : mỗi lần mở app một mã mới → đếm phiên và dựng phễu.
"""
from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
)

from app.db.session import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class AnalyticsEvent(Base):
    __tablename__ = "analytics_events"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(64), nullable=False, index=True)      # vd: quiz_submit
    client_id = Column(String(64), nullable=False, index=True)
    session_id = Column(String(64), nullable=False, index=True)
    # Khách chưa đăng nhập vẫn được ghi nhận, user_id để trống.
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    platform = Column(String(16), nullable=False, default="web")  # web | android | ios
    target = Column(String(128))   # slug đối tượng: bach-dang-1288, tran-hung-dao...
    value = Column(Integer)        # số kèm theo: số câu đúng, giây xem video...
    params = Column(JSON)          # phần tuỳ biến, không dùng để tổng hợp
    client_ts = Column(DateTime(timezone=True))  # giờ máy client (có thể sai lệch)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow, index=True)


# Tổng hợp luôn lọc theo khoảng thời gian rồi mới nhóm theo tên sự kiện.
Index("ix_analytics_created_name", AnalyticsEvent.created_at, AnalyticsEvent.name)
