"""Người dùng: học sinh / giáo viên / nhà trường."""
from sqlalchemy import Boolean, Column, Date, DateTime, Integer, String, func

from app.db.session import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(String, default="student")  # student | teacher | school
    refresh_token = Column(String, nullable=True)
    # "Đời" mã đăng nhập — tăng khi đổi/đặt lại mật khẩu hoặc đăng xuất mọi thiết bị,
    # làm mọi mã đã cấp trước đó hết hiệu lực. Xem app/core/security.py.
    token_version = Column(Integer, nullable=False, default=0, server_default="0")
    xp = Column(Integer, default=0)
    # Lớp đang học (6–12). Không bắt buộc — để trống thì app hiện tóm tắt THCS.
    grade = Column(Integer, nullable=True)
    level = Column(Integer, default=1)
    streak = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    # Nguồn ĐẦU TIÊN của máy đã dùng để đăng ký (facebook, zalo, qr, truc-tiep…).
    # Trả lời "người này đăng ký từ đâu" — xem mobile/lib/core/nguon_truy_cap.dart.
    nguon = Column(String(40), nullable=True)
    kenh = Column(String(40), nullable=True)
    chien_dich = Column(String(40), nullable=True)
    # Ngày học gần nhất (giờ VN) — để tính chuỗi ngày học. Xem services/ngay_hoc.py.
    ngay_hoc_cuoi = Column(Date, nullable=True)
    # Ảnh đại diện: mã ảnh trong bộ có sẵn (app/core/anh_dai_dien.py) hoặc "tl-<mã>" =
    # ảnh tự tải lên (services/anh_tai_len.py).
    avatar = Column(String(40), nullable=True)
    # Thống kê nội bộ, đọc từ EXIF ảnh tải lên: vị trí ĐÃ LÀM TRÒN ~11 km ("16.1,108.2")
    # và loại máy. Không bao giờ trả về API cho người khác — xem services/anh_tai_len.py.
    vi_tri_anh = Column(String(24), nullable=True)
    may_anh = Column(String(80), nullable=True)
    # Mã tài khoản Google (sub) — có nghĩa là đã từng đăng nhập bằng Google.
    google_sub = Column(String(64), nullable=True, index=True)
    # False khi tài khoản tạo bằng Google (mật khẩu ngẫu nhiên, chủ tài khoản không
    # biết) — app hiện "Đặt mật khẩu" thay vì "Đổi mật khẩu".
    co_mat_khau = Column(Boolean, nullable=False, default=True, server_default="1")
    # Premium có hiệu lực tới thời điểm này (rỗng = chưa từng mua). Mỗi lần trả tiền
    # cộng thêm ngày vào MỐC LỚN HƠN của (bây giờ, hạn cũ) — xem services/thanh_toan.py.
    premium_den = Column(DateTime(timezone=True), nullable=True)
