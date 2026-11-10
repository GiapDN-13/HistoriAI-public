"""Khách đến từ đâu: thống kê theo nguồn ĐẦU TIÊN của máy, và nguồn lưu trên tài khoản."""
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services.analytics import build_summary  # noqa: E402

seed.run()
client = TestClient(app)


def _gui(client_id: str, ten: str, params: dict | None = None):
    r = client.post("/api/v1/analytics/track", json={"events": [{
        "name": ten, "client_id": client_id, "session_id": uuid.uuid4().hex,
        "platform": "web", **({"params": params} if params else {}),
    }]})
    assert r.status_code == 200 and r.json()["accepted"] == 1


def _dong(tom: dict, nguon: str, chien_dich=None, noi_dung=None) -> dict:
    return next(x for x in tom["nguon"] if x["nguon"] == nguon and x["chien_dich"] == chien_dich
                and x["noi_dung"] == noi_dung)


def test_may_tinh_cho_nguon_dau_tien_ke_ca_khi_quay_lai_truc_tiep():
    nhan = "fb-" + uuid.uuid4().hex[:6]
    may = uuid.uuid4().hex
    _gui(may, "app_open", {"nguon": nhan, "chien_dich": "ra-mat", "nguon_phien": nhan, "lan_dau": True})
    _gui(may, "signup_success")
    # Hôm sau gõ thẳng địa chỉ: app vẫn gửi nguồn ĐẦU TIÊN, chỉ nguon_phien đổi
    _gui(may, "app_open", {"nguon": nhan, "chien_dich": "ra-mat", "nguon_phien": "truc-tiep", "lan_dau": False})
    _gui(may, "quiz_submit")

    db = SessionLocal()
    try:
        dong = _dong(build_summary(db, days=30), nhan, "ra-mat")
    finally:
        db.close()
    assert dong["nguoi"] == 1, "một máy vào hai lần vẫn là một người"
    assert dong["dang_ky"] == 1 and dong["lam_quiz"] == 1
    assert dong["ti_le_dang_ky"] == 100


def test_may_chua_tung_gui_nguon_vao_nhom_chua_ro_khong_doan_la_truc_tiep():
    may = uuid.uuid4().hex
    _gui(may, "app_open")                      # bản app cũ, chưa có đo nguồn
    db = SessionLocal()
    try:
        tom = build_summary(db, days=30)
    finally:
        db.close()
    assert any(x["nguon"] == "chua-ro" and x["nguoi"] >= 1 for x in tom["nguon"])


def test_dang_ky_luu_nguon_da_lam_sach_tren_tai_khoan():
    email = f"hs{uuid.uuid4().hex[:8]}@test.com"
    r = client.post("/api/v1/auth/register", json={
        "email": email, "full_name": "Học Sinh", "password": "12345678",
        "nguon": "Facebook Page!!", "kenh": "social", "chien_dich": "Ra Mắt 10/2026"})
    assert r.status_code == 201
    db = SessionLocal()
    try:
        u = db.query(User).filter_by(email=email).one()
        assert (u.nguon, u.kenh, u.chien_dich) == ("facebook-page", "social", "ra-mt-102026")
        tom = build_summary(db, days=30)
    finally:
        db.close()
    assert any(x["nguon"] == "facebook-page" for x in tom["tai_khoan_theo_nguon"])


def test_dang_ky_khong_co_nguon_van_duoc():
    r = client.post("/api/v1/auth/register", json={
        "email": f"hs{uuid.uuid4().hex[:8]}@test.com", "full_name": "A", "password": "12345678"})
    assert r.status_code == 201


def test_seeding_tach_rieng_tung_group_facebook():
    """Cùng nguồn facebook, cùng đợt, khác group → hai dòng riêng để biết group nào hiệu quả."""
    dot = "seed-" + uuid.uuid4().hex[:6]
    for group, so_may, so_dk in (("on-thi-su-thpt", 3, 1), ("phu-huynh-thcs", 2, 0)):
        for i in range(so_may):
            may = uuid.uuid4().hex
            _gui(may, "app_open", {"nguon": "facebook", "kenh": "seeding", "chien_dich": dot,
                                   "noi_dung": group, "nguon_phien": "facebook", "lan_dau": True})
            if i < so_dk:
                _gui(may, "signup_success")
    db = SessionLocal()
    try:
        tom = build_summary(db, days=30)
    finally:
        db.close()
    a = _dong(tom, "facebook", dot, "on-thi-su-thpt")
    b = _dong(tom, "facebook", dot, "phu-huynh-thcs")
    assert (a["nguoi"], a["dang_ky"], a["kenh"]) == (3, 1, "seeding")
    assert (b["nguoi"], b["dang_ky"]) == (2, 0)
