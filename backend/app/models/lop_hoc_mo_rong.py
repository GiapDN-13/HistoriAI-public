"""Lớp học giai đoạn 3: câu hỏi giáo viên tự soạn + lớp cố định (8A2…) để thống kê nhiều buổi.

CauRieng       câu hỏi của RIÊNG một giáo viên. Cố ý để BẢNG RIÊNG, không thêm cột chủ sở
               hữu vào quiz_questions:
                 • kho quiz chung đã qua kiểm duyệt nội dung; mọi endpoint công khai
                   (GET /quiz/{slug}, /me/cau-sai, lịch sử, đếm số câu…) đang đọc thẳng
                   quiz_questions. Thêm cột chủ sở hữu thì PHẢI nhớ lọc ở từng chỗ đó —
                   quên một chỗ là câu chưa duyệt lọt ra cho cả app. Bảng riêng thì các
                   chỗ ấy không bao giờ thấy câu riêng, khỏi phải nhớ gì.
                 • đường ống làm giàu dữ liệu và seed ghi vào quiz_questions; bảng riêng
                   không đụng tới chúng.
               Trong đề (DeKiemTra.cau_ids) câu riêng mang id ÂM: -CauRieng.id. Nhờ vậy
               cột JSON cũ giữ nguyên kiểu list[int], đề trộn được câu kho + câu riêng —
               xem app/services/cau_trong_de.py.
LopHoc         lớp cố định của một giáo viên ("8A2"). Phòng thi gắn với lớp qua
               PhongThi.lop_id → thống kê các buổi của cùng một lớp.
ThanhVienLop   học sinh trong lớp. Hai đường vào: (1) em vào một phòng của lớp → tự ghi
               nhận; (2) giáo viên thêm tay tên em (user_id rỗng) — lần đầu em vào phòng
               của lớp với đúng tên đó thì dòng ấy được nối với tài khoản của em.
"""
from datetime import datetime, timezone

from sqlalchemy import (Boolean, Column, DateTime, ForeignKey, Integer, String, Text,
                        UniqueConstraint)

from app.db.session import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class CauRieng(Base):
    __tablename__ = "cau_rieng"

    id = Column(Integer, primary_key=True)
    giao_vien_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    # Tên cột giống hệt QuizQuestion để code chấm bài dùng chung được (duck typing).
    event_id = Column(Integer, ForeignKey("historical_events.id"), nullable=True)
    question = Column(Text, nullable=False)
    option_a = Column(String(300), nullable=False)
    option_b = Column(String(300), nullable=False)
    option_c = Column(String(300), nullable=False)
    option_d = Column(String(300), nullable=False)
    correct_option = Column(String(1), nullable=False)
    explanation = Column(Text, nullable=True)
    difficulty = Column(Integer, nullable=False, default=1)
    # Xoá câu đã nằm trong một đề thì chỉ ẩn — bài cũ của học sinh vẫn xem lại được.
    an = Column(Boolean, nullable=False, default=False)
    tao_luc = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
    sua_luc = Column(DateTime(timezone=True), nullable=True)


class LopHoc(Base):
    __tablename__ = "lop_hoc"
    __table_args__ = (UniqueConstraint("giao_vien_id", "ten", name="uq_lop_hoc_gv_ten"),)

    id = Column(Integer, primary_key=True)
    giao_vien_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    ten = Column(String(40), nullable=False)
    tao_luc = Column(DateTime(timezone=True), nullable=False, default=_utcnow)


class ThanhVienLop(Base):
    __tablename__ = "thanh_vien_lop"
    __table_args__ = (UniqueConstraint("lop_id", "user_id", name="uq_thanh_vien_lop_user"),)

    id = Column(Integer, primary_key=True)
    lop_id = Column(Integer, ForeignKey("lop_hoc.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)   # rỗng = thêm tay, chưa vào phòng
    ten_hien = Column(String(60), nullable=False)
    cach = Column(String(10), nullable=False, default="phong")    # "phong" | "tay"
    them_luc = Column(DateTime(timezone=True), nullable=False, default=_utcnow)
