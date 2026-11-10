"""Thu hồi phiên đăng nhập, quên/đặt lại mật khẩu, lọc dữ liệu gửi Sentry."""
import os
import uuid
from datetime import datetime, timedelta, timezone

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from jose import jwt  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.core.theo_doi_loi import _loc  # noqa: E402
from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402
from app.services import gui_email  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"


def _tai_khoan():
    email = f"hs{uuid.uuid4().hex[:8]}@test.com"
    r = client.post("/api/v1/auth/register", json={"email": email, "full_name": "Học Sinh", "password": MK},
                    headers={"X-Client-Id": uuid.uuid4().hex})
    assert r.status_code == 201
    return email, r.json()["id"]


def _ma(email, mk=MK):
    r = client.post("/api/v1/auth/login", data={"username": email, "password": mk})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def _me(ma):
    return client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {ma}"}).status_code


# ---------- thu hồi phiên ----------

def test_dang_xuat_thu_hoi_dung_may_do():
    email, _ = _tai_khoan()
    may_a, may_b = _ma(email), _ma(email)
    assert client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {may_a}"}).status_code == 204
    assert _me(may_a) == 401, "mã đã đăng xuất phải hết dùng được ngay"
    assert _me(may_b) == 200, "máy khác không bị ảnh hưởng"


def test_dang_xuat_moi_noi_thu_hoi_tat_ca():
    email, _ = _tai_khoan()
    may_a, may_b = _ma(email), _ma(email)
    r = client.post("/api/v1/auth/logout?moi_noi=true", headers={"Authorization": f"Bearer {may_a}"})
    assert r.status_code == 204
    assert _me(may_a) == 401 and _me(may_b) == 401
    assert _me(_ma(email)) == 200, "đăng nhập lại thì dùng được bình thường"


def test_ma_cu_khong_co_jti_van_nhan_khi_chua_doi_doi():
    """Mã cấp trước bản thu hồi (không jti/tv) không bị đá văng lúc deploy."""
    _, uid = _tai_khoan()
    cu = jwt.encode({"sub": str(uid), "type": "access",
                     "exp": datetime.now(timezone.utc) + timedelta(days=1)},
                    settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    assert _me(cu) == 200


# ---------- quên mật khẩu ----------

@pytest.fixture
def thu_gui(monkeypatch):
    hop = []
    monkeypatch.setattr(settings, "SMTP_USER", "nhom@test.com")
    monkeypatch.setattr(settings, "SMTP_PASSWORD", "x")
    monkeypatch.setattr(settings, "PUBLIC_BASE_URL", "https://historiai.org")
    monkeypatch.setattr(gui_email, "gui", lambda den, tieu_de, van_ban, html=None: hop.append((den, van_ban)))
    return hop


def _lay_ma(van_ban):
    dong = next(d for d in van_ban.splitlines() if "#ma=" in d)
    assert dong.startswith("https://historiai.org/dat-lai-mat-khau/#ma=")
    return dong.split("#ma=", 1)[1].strip()


def test_tat_smtp_thi_bao_ro_503(monkeypatch):
    monkeypatch.setattr(settings, "SMTP_USER", "")
    r = client.post("/api/v1/auth/quen-mat-khau", json={"email": "ai@test.com"})
    assert r.status_code == 503


def test_email_chua_dang_ky_tra_loi_giong_het(thu_gui):
    email, _ = _tai_khoan()
    co = client.post("/api/v1/auth/quen-mat-khau", json={"email": email})
    khong = client.post("/api/v1/auth/quen-mat-khau", json={"email": f"khong{uuid.uuid4().hex[:6]}@test.com"})
    assert co.status_code == khong.status_code == 200
    assert co.json() == khong.json(), "không được để lộ email nào đã đăng ký"
    assert [d for d, _ in thu_gui] == [email]


def test_dat_lai_mat_khau_tron_luong(thu_gui):
    email, _ = _tai_khoan()
    ma_phien_cu = _ma(email)
    client.post("/api/v1/auth/quen-mat-khau", json={"email": email})
    ma = _lay_ma(thu_gui[-1][1])

    r = client.post("/api/v1/auth/dat-lai-mat-khau", json={"ma": ma, "mat_khau_moi": "matkhaumoi9"})
    assert r.status_code == 200, r.text
    assert client.post("/api/v1/auth/login", data={"username": email, "password": MK}).status_code == 401
    assert _me(_ma(email, "matkhaumoi9")) == 200
    assert _me(ma_phien_cu) == 401, "đổi mật khẩu phải đá văng phiên cũ"
    lai = client.post("/api/v1/auth/dat-lai-mat-khau", json={"ma": ma, "mat_khau_moi": "khac12345"})
    assert lai.status_code == 400, "mã chỉ dùng một lần"


def test_yeu_cau_moi_vo_hieu_ma_cu(thu_gui):
    email, _ = _tai_khoan()
    client.post("/api/v1/auth/quen-mat-khau", json={"email": email})
    ma_1 = _lay_ma(thu_gui[-1][1])
    client.post("/api/v1/auth/quen-mat-khau", json={"email": email})
    ma_2 = _lay_ma(thu_gui[-1][1])
    assert client.post("/api/v1/auth/dat-lai-mat-khau",
                       json={"ma": ma_1, "mat_khau_moi": "abcdefgh1"}).status_code == 400
    assert client.post("/api/v1/auth/dat-lai-mat-khau",
                       json={"ma": ma_2, "mat_khau_moi": "abcdefgh1"}).status_code == 200


def test_ma_bia_va_mat_khau_ngan_bi_tu_choi(thu_gui):
    assert client.post("/api/v1/auth/dat-lai-mat-khau",
                       json={"ma": "x" * 43, "mat_khau_moi": "abcdefgh1"}).status_code == 400
    assert client.post("/api/v1/auth/dat-lai-mat-khau",
                       json={"ma": "x" * 43, "mat_khau_moi": "ngan"}).status_code == 422


def test_khong_ban_thu_rac_qua_3_lan_moi_gio(thu_gui):
    email, _ = _tai_khoan()
    for _ in range(3):
        assert client.post("/api/v1/auth/quen-mat-khau", json={"email": email}).status_code == 200
    assert client.post("/api/v1/auth/quen-mat-khau", json={"email": email}).status_code == 429
    assert len(thu_gui) == 3


# ---------- Sentry ----------

def test_sentry_khong_gui_du_lieu_ca_nhan():
    ev = {"request": {"url": "https://historiai.org/api/v1/analytics/dashboard?key=bimat",
                      "headers": {"Authorization": "Bearer abc", "X-Client-Id": "may1", "User-Agent": "ua"},
                      "data": {"password": "12345678"}, "query_string": "key=bimat"},
          "user": {"email": "hs@test.com"}}
    ra = _loc(ev, {})
    assert ra["request"]["url"].endswith("/dashboard")
    assert ra["request"]["headers"] == {"User-Agent": "ua"}
    assert "data" not in ra["request"] and "query_string" not in ra["request"]
    assert "user" not in ra
