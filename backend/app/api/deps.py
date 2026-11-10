"""Dependencies dùng chung cho các route (lấy user hiện tại từ JWT)."""
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import decode_access_payload
from app.db.session import get_db
from app.models.phien import TokenThuHoi
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_PREFIX}/auth/login")


def _nguoi_dung_tu_ma(token: str, db: Session) -> tuple[User, dict] | None:
    """Kiểm đủ ba lớp: chữ ký + hạn, sổ thu hồi (đăng xuất), đời mã (đổi mật khẩu).

    Mã cấp TRƯỚC khi có thu hồi không mang jti/tv: vẫn nhận khi tài khoản còn ở
    đời 0, để lần deploy này không đá văng mọi người đang đăng nhập.
    """
    payload = decode_access_payload(token)
    if payload is None:
        return None
    jti = payload.get("jti")
    if jti and db.get(TokenThuHoi, jti) is not None:
        return None
    user = db.query(User).filter(User.id == int(payload["sub"])).first()
    if user is None:
        return None
    if int(payload.get("tv", 0)) != (user.token_version or 0):
        return None
    return user, payload


def get_current_payload(token: str = Depends(oauth2_scheme),
                        db: Session = Depends(get_db)) -> tuple[User, dict]:
    kq = _nguoi_dung_tu_ma(token, db)
    if kq is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.")
    return kq


def get_current_user(kq: tuple[User, dict] = Depends(get_current_payload)) -> User:
    return kq[0]


# Bản "không bắt buộc đăng nhập": dùng cho những route mà khách vãng lai
# vẫn gọi được (đo lường), nhưng nếu có token thì gắn luôn danh tính.
oauth2_scheme_optional = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_PREFIX}/auth/login", auto_error=False
)


def get_current_user_optional(
    token: str | None = Depends(oauth2_scheme_optional),
    db: Session = Depends(get_db),
) -> User | None:
    """Trả về user nếu token hợp lệ, ngược lại None — không ném 401."""
    if not token:
        return None
    kq = _nguoi_dung_tu_ma(token, db)
    return kq[0] if kq else None
