"""Thu hồi phiên đăng nhập và mã đặt lại mật khẩu.

TokenThuHoi
    Mã đăng nhập (JWT) sống 7 ngày và tự kiểm được bằng chữ ký — nên trước đây
    "đăng xuất" chỉ là xoá mã trên máy; ai đã chép được mã vẫn dùng tiếp tới hết
    hạn. Giờ đăng xuất ghi jti của mã vào đây, mọi request đều tra sổ này.
    Chỉ cần giữ tới khi mã tự hết hạn — sau đó dòng vô dụng, dọn đi.

MaDatLai
    Chỉ lưu BĂM SHA-256 của mã gửi qua email, không lưu mã gốc: ai đọc được
    CSDL (bản sao lưu, máy chủ bị lộ) cũng không dùng được mã để chiếm tài khoản.
    Dùng một lần, sống 30 phút.
"""
from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String

from app.db.session import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class TokenThuHoi(Base):
    __tablename__ = "token_thu_hoi"

    jti = Column(String(32), primary_key=True)
    het_han = Column(DateTime(timezone=True), nullable=False, index=True)


class MaDatLai(Base):
    __tablename__ = "ma_dat_lai"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    ma_bam = Column(String(64), nullable=False, unique=True)
    het_han = Column(DateTime(timezone=True), nullable=False)
    da_dung = Column(Boolean, nullable=False, default=False)
    tao_luc = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
