"""Chế độ kiểm tra cho lớp học: giáo viên ra đề, mở phòng, học sinh quét QR vào làm.

Giai đoạn 1 (27/09/2026): chế độ BÀI TẬP — mỗi em tự làm theo nhịp của mình trong khi
phòng còn mở; giáo viên xem bảng tiến độ gần như tức thì (app tự làm mới vài giây một
lần). Chế độ TRỰC TIẾP (giáo viên bấm chuyển từng câu, kiểu Kahoot) để giai đoạn 2.

DeKiemTra   đề = danh sách câu lấy từ kho quiz, thời gian mỗi câu.
PhongThi    một lần mở đề cho một lớp: mã 6 chữ số (in thành QR), mở/đóng, hạn chót.
BaiThi      bài của một học sinh trong một phòng. Học sinh "đăng ký nhanh" chỉ bằng họ
            tên + mã PIN 4 số (không email — phần lớn là trẻ vị thành niên): vào lại
            đúng phòng bằng đúng tên + PIN là lấy lại được bài đang làm.
"""
from datetime import datetime, timezone

from sqlalchemy import (JSON, Boolean, Column, DateTime, ForeignKey, Integer, String,
                        UniqueConstraint)

from app.db.session import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class DeKiemTra(Base):
    __tablename__ = "de_kiem_tra"

    id = Column(Integer, primary_key=True)
    giao_vien_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    tieu_de = Column(String(120), nullable=False)
    cau_ids = Column(JSON, nullable=False)            # [id câu hỏi], theo thứ tự giáo viên chọn
    giay_moi_cau = Column(Integer, nullable=False, default=30)
    tao_luc = Column(DateTime(timezone=True), nullable=False, default=_utcnow)


class PhongThi(Base):
    __tablename__ = "phong_thi"

    id = Column(Integer, primary_key=True)
    ma = Column(String(6), nullable=False, unique=True, index=True)
    de_id = Column(Integer, ForeignKey("de_kiem_tra.id"), nullable=False)
    giao_vien_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    dang_mo = Column(Boolean, nullable=False, default=True)
    tron_cau = Column(Boolean, nullable=False, default=True)
    han_chot = Column(DateTime(timezone=True), nullable=True)
    tao_luc = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    dong_luc = Column(DateTime(timezone=True), nullable=True)
    # --- giai đoạn 2: chế độ TRỰC TIẾP (app/services/phong_truc_tiep.py) ---
    # Ba cột dưới là trạng thái cốt lõi của trận: lưu CSDL (không chỉ bộ nhớ) để máy chủ
    # khởi động lại giữa tiết vẫn biết đang ở câu nào, đã lộ đáp án chưa.
    che_do = Column(String(12), nullable=False, default="bai_tap")   # "bai_tap" | "truc_tiep"
    pha = Column(String(12), nullable=True)            # cho | dang_hoi | lo_dap_an | ket_thuc (chỉ trực tiếp)
    cau_hien_tai = Column(Integer, nullable=True)      # vị trí trong de.cau_ids, tính từ 0
    cau_bat_dau_luc = Column(DateTime(timezone=True), nullable=True)   # mốc tính giờ + điểm tốc độ
    # Giai đoạn 3: phòng mở cho một lớp cố định (lop_hoc_mo_rong.LopHoc). Rỗng = phòng lẻ.
    lop_id = Column(Integer, ForeignKey("lop_hoc.id"), nullable=True, index=True)


class BaiThi(Base):
    __tablename__ = "bai_thi"
    __table_args__ = (UniqueConstraint("phong_id", "user_id", name="uq_bai_thi_phong_user"),)

    id = Column(Integer, primary_key=True)
    phong_id = Column(Integer, ForeignKey("phong_thi.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    ten_hien = Column(String(60), nullable=False)     # tên học sinh nhập khi vào phòng
    lop = Column(String(20), nullable=True)           # "8A2" — tự do, để giáo viên lọc
    pin_bam = Column(String(100), nullable=True)      # bcrypt của PIN; chỉ có ở tài khoản nhanh
    thu_tu = Column(JSON, nullable=False)             # [id câu] đã trộn riêng cho em này
    tra_loi = Column(JSON, nullable=False, default=dict)   # {"<id câu>": {"chon": "A", "dung": true}}
    bat_dau = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    nop_luc = Column(DateTime(timezone=True), nullable=True)
    so_dung = Column(Integer, nullable=False, default=0)
