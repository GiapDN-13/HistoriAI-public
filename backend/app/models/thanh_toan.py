"""Thanh toán Premium qua chuyển khoản (SePay) và hạn mức hỏi vĩ nhân theo ngày.

DonThanhToan
    Một lần muốn mua. Mã đơn (HAI + 5 ký tự) chính là nội dung chuyển khoản —
    người trả gõ mã đó vào ngân hàng, SePay báo về, ta tìm mã trong nội dung để
    biết tiền của ai. Không có mã thì không biết cộng Premium cho tài khoản nào.

GiaoDichNganHang
    MỌI giao dịch SePay gửi tới, kể cả cái không khớp đơn nào. `sepay_id` duy nhất
    để SePay gửi lại (nó gửi lại khi không nhận được 200) không cộng ngày hai lần.
    Giữ nguyên JSON gốc để quản trị đối soát tay khi có tranh chấp.

LuotChatNgay
    Số câu AI đã hỏi trong ngày của một người (hoặc một máy khách). Nằm trong CSDL
    chứ không trong bộ nhớ như `services/gioi_han.py`: hạn mức này là thứ ta bán
    (Premium bỏ nó), khởi động lại máy chủ mà reset số đếm là phát miễn phí.
"""
from datetime import datetime, timezone

from sqlalchemy import (JSON, Column, Date, DateTime, ForeignKey, Integer, String,
                        UniqueConstraint)

from app.db.session import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class DonThanhToan(Base):
    __tablename__ = "don_thanh_toan"

    id = Column(Integer, primary_key=True)
    ma_don = Column(String(12), unique=True, nullable=False, index=True)
    # Rỗng khi chủ đơn đã xoá tài khoản: đơn ĐÃ TRẢ vẫn giữ làm chứng từ đối soát.
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    goi = Column(String(16), nullable=False)
    so_tien = Column(Integer, nullable=False)
    trang_thai = Column(String(12), nullable=False, default="cho")   # cho | da_tra
    tao_luc = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    het_han = Column(DateTime(timezone=True), nullable=False)
    tra_luc = Column(DateTime(timezone=True), nullable=True)
    nguon = Column(String(8), nullable=True)                          # sepay | tay
    giao_dich_id = Column(Integer, ForeignKey("giao_dich_ngan_hang.id"), nullable=True)


class GiaoDichNganHang(Base):
    __tablename__ = "giao_dich_ngan_hang"

    id = Column(Integer, primary_key=True)
    sepay_id = Column(Integer, unique=True, nullable=False)
    so_tien = Column(Integer, nullable=False, default=0)
    noi_dung = Column(String, nullable=True)
    ngay_gd = Column(String(32), nullable=True)       # nguyên văn "transactionDate" của SePay
    ma_don = Column(String(12), nullable=True)        # chỉ có khi khớp được đơn
    trang_thai = Column(String(12), nullable=False)   # da_khop | chua_khop | bo_qua
    nhan_luc = Column(DateTime(timezone=True), nullable=False, default=_utcnow, index=True)
    du_lieu = Column(JSON, nullable=True)             # JSON gốc của SePay


class LuotChatNgay(Base):
    __tablename__ = "luot_chat_ngay"
    __table_args__ = (UniqueConstraint("doi_tuong", "ngay", name="uq_luot_chat_doi_tuong_ngay"),)

    id = Column(Integer, primary_key=True)
    # "u:<user_id>" với người đã đăng nhập, "k:<X-Client-Id>" với khách.
    doi_tuong = Column(String(80), nullable=False, index=True)
    ngay = Column(Date, nullable=False)                # ngày theo giờ Việt Nam
    so_luot = Column(Integer, nullable=False, default=0)
