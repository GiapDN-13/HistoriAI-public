"""Phản hồi người dùng gửi ngay trong app: số sao, điểm giới thiệu (NPS), lời góp ý.

Lưu kèm NGUỒN ĐẦU TIÊN của máy (facebook, zalo, group seeding nào…) để trả lời
được "người đến từ kênh nào thì đánh giá sản phẩm ra sao" — không chỉ đếm xem
kênh nào mang được nhiều người về.
"""
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text

from app.db.session import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class PhanHoi(Base):
    __tablename__ = "phan_hoi"

    id = Column(Integer, primary_key=True, index=True)
    client_id = Column(String(64), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    diem = Column(Integer, nullable=True)        # 1–5 sao
    nps = Column(Integer, nullable=True)         # 0–10: "có giới thiệu cho bạn bè không?"
    gop_y = Column(Text, nullable=True)          # chữ người dùng tự gõ — có thể chứa thông tin cá nhân
    ngu_canh = Column(String(16), nullable=False, default="khac")   # quiz | chat | ho-so | khac
    target = Column(String(128), nullable=True)  # slug sự kiện / vĩ nhân đang dùng lúc hỏi
    # Trận/chủ đề người dùng muốn app có thêm (chip chọn nhanh, tối đa 3), slug nối
    # bằng dấu phẩy. Góp ý lặp nhiều nhất là "nội dung còn ít" nhưng chữ tự gõ không
    # nói được là trận NÀO — cột này để đếm thẳng được.
    muon_them = Column(String(200), nullable=True)
    nguon = Column(String(40), nullable=True)
    kenh = Column(String(40), nullable=True)
    chien_dich = Column(String(40), nullable=True)
    noi_dung = Column(String(40), nullable=True)
    nen_tang = Column(String(16), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_utcnow, index=True)
