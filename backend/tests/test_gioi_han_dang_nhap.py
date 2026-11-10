"""Chặn dò mật khẩu và tài khoản rác — mà không chặn cả lớp chung một wifi."""
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"


def _dk(email=None, may=None):
    email = email or f"hs{uuid.uuid4().hex[:8]}@test.com"
    r = client.post("/api/v1/auth/register", json={"email": email, "full_name": "HS", "password": MK},
                    headers={"X-Client-Id": may or uuid.uuid4().hex})
    return email, r


def _dn(email, mk):
    return client.post("/api/v1/auth/login", data={"username": email, "password": mk})


def test_do_mat_khau_bi_chan_sau_10_lan_sai():
    email, _ = _dk()
    for _ in range(10):
        assert _dn(email, "sai-mat-khau").status_code == 401
    r = _dn(email, "sai-mat-khau")
    assert r.status_code == 429
    assert _dn(email, MK).status_code == 429, "đang bị khoá thì đúng mật khẩu cũng phải chờ"


def test_tai_khoan_khac_cung_mang_van_dang_nhap_duoc():
    nan_nhan, _ = _dk()
    for _ in range(10):
        _dn(nan_nhan, "sai")
    ban_cung_lop, _ = _dk()
    assert _dn(ban_cung_lop, MK).status_code == 200


def test_ca_lop_40_nguoi_dang_nhap_cung_luc_khong_bi_chan():
    ds = [_dk()[0] for _ in range(40)]
    assert all(_dn(e, MK).status_code == 200 for e in ds)


def test_dang_nhap_dung_xoa_so_lan_sai():
    email, _ = _dk()
    for _ in range(9):
        _dn(email, "sai")
    assert _dn(email, MK).status_code == 200
    for _ in range(9):                       # đếm lại từ 0, chưa tới ngưỡng
        assert _dn(email, "sai").status_code == 401


def test_mot_may_tao_qua_5_tai_khoan_mot_gio_bi_chan():
    may = uuid.uuid4().hex
    for _ in range(5):
        assert _dk(may=may)[1].status_code == 201
    assert _dk(may=may)[1].status_code == 429
    assert _dk()[1].status_code == 201, "máy khác trong cùng mạng vẫn đăng ký được"
