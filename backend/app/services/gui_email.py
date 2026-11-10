"""Gửi email qua SMTP (hiện chỉ dùng cho quên mật khẩu).

Chạy trong BackgroundTasks của FastAPI, SAU khi đã trả lời request — vì hai lẽ:
  1. Gmail mất 1–3 giây mỗi thư; không bắt người dùng chờ.
  2. Thời gian trả lời như nhau dù email có tài khoản hay không, nên không đo
     giờ phản hồi để dò xem email nào đã đăng ký được.
Lỗi gửi chỉ ghi nhật ký (và Sentry nếu bật) — người dùng đã nhận câu trả lời chung.
"""
from __future__ import annotations

import logging
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr

from app.core.config import settings

log = logging.getLogger("historiai.email")


def da_bat() -> bool:
    return bool(settings.SMTP_USER and settings.SMTP_PASSWORD)


def gui(den: str, tieu_de: str, van_ban: str, html: str | None = None) -> None:
    thu = EmailMessage()
    gui_tu = settings.SMTP_FROM or settings.SMTP_USER
    thu["From"] = formataddr((settings.SMTP_TEN, gui_tu))
    thu["To"] = den
    thu["Subject"] = tieu_de
    thu.set_content(van_ban)
    if html:
        thu.add_alternative(html, subtype="html")
    try:
        if settings.SMTP_PORT == 465:
            with smtplib.SMTP_SSL(settings.SMTP_HOST, 465, timeout=20,
                                  context=ssl.create_default_context()) as s:
                s.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                s.send_message(thu)
        else:
            with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=20) as s:
                s.starttls(context=ssl.create_default_context())
                s.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                s.send_message(thu)
    except Exception:
        # Không ghi địa chỉ người nhận vào nhật ký — chỉ cần biết là lỗi và vì sao.
        log.exception("gửi email thất bại")
