"""Kiểm mã đăng nhập (ID token) Google gửi cho app.

App (web: nút Google; Android: Credential Manager) nhận ID token từ Google rồi gửi
lên /auth/google. Ở đây kiểm chữ ký bằng khoá công khai của Google, hạn dùng,
người phát (accounts.google.com) và `aud` phải là client ID của CHÍNH app mình —
thiếu bước kiểm aud thì mã Google cấp cho app khác cũng đăng nhập được vào đây.
"""
from __future__ import annotations

from app.core.config import settings


class MaGoogleSai(Exception):
    pass


def client_ids() -> list[str]:
    return [x.strip() for x in settings.GOOGLE_CLIENT_IDS.split(",") if x.strip()]


def kiem(id_token: str) -> dict:
    """Trả về {email, ten, sub} nếu mã hợp lệ và email đã được Google xác minh."""
    from google.auth.transport import requests as g_requests
    from google.oauth2 import id_token as g_id_token

    try:
        info = g_id_token.verify_oauth2_token(id_token, g_requests.Request(), audience=None)
    except ValueError as e:
        raise MaGoogleSai(str(e)) from e
    if info.get("aud") not in client_ids():
        raise MaGoogleSai("aud không khớp")
    if info.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
        raise MaGoogleSai("iss lạ")
    if not info.get("email") or not info.get("email_verified"):
        raise MaGoogleSai("email chưa xác minh")
    return {"email": info["email"].strip().lower(), "ten": (info.get("name") or "").strip(),
            "sub": info["sub"]}
