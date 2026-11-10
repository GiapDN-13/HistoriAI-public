"""Vai trò: đăng ký không tự xưng được; quản trị có quyền giáo viên và không lên bảng vàng."""
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.core.security import hash_password  # noqa: E402
from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.user import User  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"


def _dang_nhap(ten, mk=MK):
    r = client.post("/api/v1/auth/login", data={"username": ten, "password": mk})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_dang_ky_tu_xung_giao_vien_van_la_hoc_sinh():
    email = f"x{uuid.uuid4().hex[:8]}@test.com"
    r = client.post("/api/v1/auth/register", json={"email": email, "full_name": "X", "password": MK,
                                                   "role": "teacher"}, headers={"X-Client-Id": uuid.uuid4().hex})
    assert r.status_code == 201
    assert r.json()["role"] == "student"
    me = client.get("/api/v1/auth/me", headers=_dang_nhap(email)).json()
    assert me["role"] == "student"


def _tao_quan_tri():
    ten = f"qt{uuid.uuid4().hex[:6]}"
    db = SessionLocal()
    db.add(User(email=f"{ten}@historiai.org", full_name="Quản trị", role="admin",
                hashed_password=hash_password(MK), xp=10 ** 9))
    db.commit()
    db.close()
    return ten


def test_quan_tri_dang_nhap_bang_ten_ngan_va_co_quyen_giao_vien():
    h = _dang_nhap(_tao_quan_tri())
    me = client.get("/api/v1/auth/me", headers=h)
    assert me.status_code == 200 and me.json()["role"] == "admin"
    # Một route chỉ giáo viên vào được — quản trị không bị 403
    assert client.get("/api/v1/lop/de", headers=h).status_code != 403


def test_quan_tri_khong_len_bang_vang():
    _tao_quan_tri()
    email = f"hs{uuid.uuid4().hex[:6]}@test.com"
    client.post("/api/v1/auth/register", json={"email": email, "full_name": "HS", "password": MK},
                headers={"X-Client-Id": uuid.uuid4().hex})
    bang = client.get("/api/v1/leaderboard", headers=_dang_nhap(email)).json()
    assert all(d["xp"] < 10 ** 9 for d in bang), "tài khoản quản trị (XP khủng) không được lên bảng"
