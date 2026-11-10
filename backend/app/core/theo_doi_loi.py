"""Theo dõi lỗi bằng Sentry — biết app hỏng ở đâu trước khi người dùng phải kể.

Người dùng phần lớn là học sinh vị thành niên, nên cố ý gửi ÍT nhất có thể:
  • send_default_pii=False: không IP, không cookie, không thông tin đăng nhập.
  • Không gửi thân request (max_request_body_size="never") — thân request chat
    là chữ học sinh tự gõ, form đăng nhập chứa mật khẩu.
  • _loc() xoá thêm header Authorization/X-Client-Id và chuỗi truy vấn (có ?key=
    của dashboard) cho chắc, phòng khi thư viện đổi mặc định.
  • Không đo hiệu năng (traces_sample_rate=0) — gói miễn phí có hạn mức, dành cho lỗi.
Lỗi 4xx (sai mật khẩu, chưa đăng nhập…) là chuyện bình thường, không gửi.
"""
from __future__ import annotations

from app.core.config import settings

_HEADER_BO = {"authorization", "x-client-id", "cookie"}


def _loc(event: dict, _hint: dict) -> dict | None:
    req = event.get("request") or {}
    hdr = req.get("headers")
    if isinstance(hdr, dict):
        req["headers"] = {k: v for k, v in hdr.items() if k.lower() not in _HEADER_BO}
    req.pop("data", None)
    req.pop("cookies", None)
    req.pop("query_string", None)
    if isinstance(req.get("url"), str):
        req["url"] = req["url"].split("?", 1)[0]
    event.pop("user", None)
    return event


def bat_sentry() -> bool:
    if not settings.SENTRY_DSN:
        return False
    import sentry_sdk

    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        environment=settings.SENTRY_ENV,
        send_default_pii=False,
        max_request_body_size="never",
        traces_sample_rate=0.0,
        before_send=_loc,
    )
    return True
