"""Đăng nhập / đăng ký bằng Google. Không gọi Google thật: thay hàm kiểm mã."""
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402
from app.services import google_dang_nhap  # noqa: E402

seed.run()
client = TestClient(app)


@pytest.fixture
def google(monkeypatch):
    """Mã giả 'ok:<email>' hợp lệ; mọi mã khác bị Google từ chối."""
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_IDS", "web-id.apps.googleusercontent.com")

    def kiem(tok):
        if not tok.startswith("ok:" + "x" * 20):
            raise google_dang_nhap.MaGoogleSai("sai")
        email = tok.split("|", 1)[1]
        return {"email": email.lower(), "ten": "Nguyễn Văn A", "sub": "123"}

    monkeypatch.setattr(google_dang_nhap, "kiem", kiem)


def _tok(email):
    return "ok:" + "x" * 20 + "|" + email


def _gg(email, **them):
    return client.post("/api/v1/auth/google", json={"id_token": _tok(email), **them},
                       headers={"X-Client-Id": uuid.uuid4().hex})


def test_chua_cau_hinh_thi_503(monkeypatch):
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_IDS", "")
    assert client.post("/api/v1/auth/google", json={"id_token": "y" * 30}).status_code == 503


def test_lan_dau_tao_tai_khoan_kem_nguon(google):
    email = f"gg{uuid.uuid4().hex[:8]}@gmail.com"
    r = _gg(email, grade=9, nguon="facebook")
    assert r.status_code == 200, r.text
    assert r.json()["moi_tao"] is True
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {r.json()['access_token']}"}).json()
    assert me["email"] == email and me["full_name"] == "Nguyễn Văn A" and me["grade"] == 9
    lai = _gg(email)
    assert lai.json()["moi_tao"] is False, "lần sau là đăng nhập, không tạo trùng"


def test_noi_vao_tai_khoan_mat_khau_san_co(google):
    email = f"hs{uuid.uuid4().hex[:8]}@gmail.com"
    dk = client.post("/api/v1/auth/register", json={"email": email, "full_name": "HS", "password": "12345678"},
                     headers={"X-Client-Id": uuid.uuid4().hex})
    r = _gg(email.upper())
    assert r.json()["moi_tao"] is False
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {r.json()['access_token']}"}).json()
    assert me["id"] == dk.json()["id"]


def test_ma_gia_bi_tu_choi(google):
    r = client.post("/api/v1/auth/google", json={"id_token": "gia" + "z" * 30})
    assert r.status_code == 401


def test_kiem_that_tu_choi_aud_la(monkeypatch):
    """Hàm kiểm thật: mã Google hợp lệ nhưng cấp cho app KHÁC phải bị từ chối."""
    from google.oauth2 import id_token as g_id_token
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_IDS", "cua-minh.apps.googleusercontent.com")
    monkeypatch.setattr(g_id_token, "verify_oauth2_token", lambda *a, **k: {
        "aud": "app-khac.apps.googleusercontent.com", "iss": "accounts.google.com",
        "email": "a@gmail.com", "email_verified": True, "sub": "1"})
    with pytest.raises(google_dang_nhap.MaGoogleSai):
        google_dang_nhap.kiem("bat-ky")
    monkeypatch.setattr(g_id_token, "verify_oauth2_token", lambda *a, **k: {
        "aud": "cua-minh.apps.googleusercontent.com", "iss": "accounts.google.com",
        "email": "a@gmail.com", "email_verified": False, "sub": "1"})
    with pytest.raises(google_dang_nhap.MaGoogleSai):
        google_dang_nhap.kiem("bat-ky")
