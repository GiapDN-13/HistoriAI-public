"""Schema cho đăng ký / đăng nhập / token."""
import re

from pydantic import BaseModel, EmailStr, Field, field_validator


def lam_sach_nhan(v: str | None) -> str | None:
    """'Facebook Page!!' → 'facebook-page'. Cùng luật với app để hai bên gộp khớp."""
    if not v:
        return None
    t = re.sub(r"\s+", "-", v.strip().lower())
    t = re.sub(r"[^a-z0-9_-]", "", t)
    t = re.sub(r"-{2,}", "-", t)
    return t[:40] or None


class UserRegister(BaseModel):
    email: EmailStr
    full_name: str
    password: str
    role: str = "student"   # bỏ qua — app cũ còn gửi; máy chủ luôn tạo học sinh
    # Lớp đang học. Không bắt buộc: người dùng cũ và người bỏ qua vẫn đăng ký được.
    grade: int | None = Field(default=None, ge=6, le=12)
    # Nguồn truy cập đầu tiên của máy (app tự gửi). Không bắt buộc; nhận chuỗi lạ
    # thì làm sạch về a-z0-9-_ chứ không từ chối — không để đo lường chặn đăng ký.
    nguon: str | None = None
    kenh: str | None = None
    chien_dich: str | None = None

    @field_validator("nguon", "kenh", "chien_dich")
    @classmethod
    def lam_sach_nhan(cls, v: str | None) -> str | None:
        return lam_sach_nhan(v)

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Mật khẩu phải có ít nhất 8 ký tự")
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"
    moi_tao: bool | None = None   # chỉ /auth/google: tài khoản vừa được tạo


class RefreshRequest(BaseModel):
    refresh_token: str


class ErrorOut(BaseModel):
    code: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorOut


class UserOut(BaseModel):
    id: int
    email: EmailStr
    full_name: str
    role: str
    xp: int
    level: int
    streak: int
    grade: int | None = None
    avatar: str | None = None
    avatar_url: str | None = None   # chỉ có khi là ảnh tự tải lên — xem services/anh_tai_len.py
    co_mat_khau: bool = True          # False: tài khoản Google chưa đặt mật khẩu riêng
    lien_ket_google: bool = False     # đã từng đăng nhập bằng Google
    ngay_tham_gia: str | None = None
    premium_den: str | None = None    # ISO có múi giờ; rỗng = chưa từng mua
    la_premium: bool = False          # còn hạn tại thời điểm gọi

    class Config:
        from_attributes = True

    @field_validator("premium_den", mode="before")
    @classmethod
    def _premium_den_iso(cls, v):
        # model_validate đọc thẳng cột datetime của User; SQLite trả không múi giờ nên
        # phải gắn UTC trước khi gửi, kẻo app hiểu thành giờ địa phương.
        from app.services.ngay_hoc import iso_utc
        return iso_utc(v) if hasattr(v, "isoformat") else v

    @classmethod
    def tu(cls, user) -> "UserOut":
        """Dựng từ User. Streak lấy bản HIỂN THỊ (đứt chuỗi thì 0) — xem services/ngay_hoc.py."""
        from app.services.ngay_hoc import ngay_vn, streak_hien_tai

        o = cls.model_validate(user)
        o.streak = streak_hien_tai(user)
        o.co_mat_khau = user.co_mat_khau is not False
        o.lien_ket_google = bool(user.google_sub)
        o.ngay_tham_gia = ngay_vn(user.created_at)
        from app.services.ngay_hoc import iso_utc
        from app.services.thanh_toan import la_premium
        o.premium_den = iso_utc(user.premium_den)
        o.la_premium = la_premium(user)
        from app.services.anh_tai_len import url
        o.avatar_url = url(user.avatar)
        return o


class DangNhapGoogle(BaseModel):
    id_token: str = Field(min_length=20, max_length=4096)
    # Chỉ dùng khi tạo tài khoản mới — cùng ý nghĩa với UserRegister.
    grade: int | None = Field(default=None, ge=6, le=12)
    nguon: str | None = None
    kenh: str | None = None
    chien_dich: str | None = None

    @field_validator("nguon", "kenh", "chien_dich")
    @classmethod
    def lam_sach_nhan(cls, v: str | None) -> str | None:
        return lam_sach_nhan(v)


class QuenMatKhau(BaseModel):
    email: EmailStr


class DatLaiMatKhau(BaseModel):
    ma: str = Field(min_length=20, max_length=128)
    mat_khau_moi: str

    @field_validator("mat_khau_moi")
    @classmethod
    def du_manh(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Mật khẩu phải có ít nhất 8 ký tự")
        return v


class UserUpdate(BaseModel):
    """Những trường người dùng tự sửa được. Trường nào không gửi thì giữ nguyên."""
    grade: int | None = Field(default=None, ge=6, le=12)
    full_name: str | None = Field(default=None, min_length=2, max_length=60)
    avatar: str | None = Field(default=None, max_length=40)

    @field_validator("full_name")
    @classmethod
    def ten_gon(cls, v: str | None) -> str | None:
        if v is None:
            return v
        v = " ".join(v.split())
        if len(v) < 2:
            raise ValueError("Họ tên quá ngắn")
        return v


class DoiMatKhau(BaseModel):
    # Bỏ trống khi tài khoản chưa có mật khẩu riêng (tạo bằng Google).
    mat_khau_cu: str | None = None
    mat_khau_moi: str

    @field_validator("mat_khau_moi")
    @classmethod
    def du_manh(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Mật khẩu phải có ít nhất 8 ký tự")
        return v
