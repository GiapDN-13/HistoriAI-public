"""Ảnh đại diện tự tải lên: làm sạch (bỏ GPS/EXIF), cắt vuông, hiện công khai, dọn tệp."""
import io
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from PIL import Image  # noqa: E402

from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402
from app.services import anh_tai_len  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"


@pytest.fixture(autouse=True)
def _thu_muc_tam(tmp_path, monkeypatch):
    monkeypatch.setattr(anh_tai_len, "THU_MUC", tmp_path / "anh")
    from app.api.routes import auth
    auth._luot_tai_anh.clear()


def _tk():
    email = f"a{uuid.uuid4().hex[:8]}@test.com"
    client.post("/api/v1/auth/register", json={"email": email, "full_name": "An", "password": MK},
                headers={"X-Client-Id": uuid.uuid4().hex})
    tok = client.post("/api/v1/auth/login", data={"username": email, "password": MK}).json()["access_token"]
    return {"Authorization": f"Bearer {tok}"}


def _anh_co_gps(w=1200, h=800) -> bytes:
    img = Image.new("RGB", (w, h), (186, 35, 35))
    exif = Image.Exif()
    exif[0x8825] = {1: "N", 2: (16.0, 4.0, 12.5), 3: "E", 4: (108.0, 13.0, 3.1)}   # GPS gần Đà Nẵng
    exif[0x0110] = "Dien thoai cua em"                 # Model
    b = io.BytesIO()
    img.save(b, "JPEG", exif=exif)
    return b.getvalue()


def _tai(h, du_lieu, ten="anh.jpg"):
    return client.post("/api/v1/auth/me/anh-dai-dien", headers=h, files={"anh": (ten, du_lieu, "image/jpeg")})


def test_tai_len_lam_sach_va_cat_vuong():
    goc = _anh_co_gps()
    assert Image.open(io.BytesIO(goc)).getexif(), "ảnh thử phải có EXIF"
    h = _tk()
    r = _tai(h, goc)
    assert r.status_code == 200, r.text
    me = r.json()
    assert me["avatar"].startswith("tl-") and not me["avatar_url"].endswith(".jpg"), "nginx chặn đuôi .jpg"
    anh = client.get(me["avatar_url"])
    assert anh.status_code == 200 and anh.headers["content-type"] == "image/jpeg"
    ra = Image.open(io.BytesIO(anh.content))
    assert ra.size == (320, 320)
    assert not ra.getexif(), "ảnh công khai đã bỏ sạch EXIF (GPS, loại máy)"
    # Thống kê nội bộ: vị trí LÀM TRÒN ~11 km + loại máy, không lộ ra API của người dùng
    from app.db.session import SessionLocal
    from app.models.user import User
    db = SessionLocal()
    try:
        u = db.query(User).filter(User.avatar == me["avatar"]).one()
        assert u.vi_tri_anh == "16.1,108.2", u.vi_tri_anh      # 16°04', 108°13' → làm tròn
        assert u.may_anh == "Dien thoai cua em"
    finally:
        db.close()
    assert "vi_tri" not in r.text and "16.1" not in r.text


def test_tu_choi_tep_khong_phai_anh_va_anh_qua_lon():
    h = _tk()
    r = _tai(h, b"<?php echo 1; ?>", "a.jpg")
    assert r.status_code == 422 and "không phải ảnh" in r.text
    assert _tai(h, b"\xff" * (anh_tai_len.TOI_DA_BYTE + 10)).status_code == 422


def test_doi_anh_xoa_tep_cu_va_go_anh():
    h = _tk()
    cu = _tai(h, _anh_co_gps()).json()["avatar_url"]
    moi = _tai(h, _anh_co_gps(600, 900)).json()["avatar_url"]
    assert cu != moi
    assert client.get(cu).status_code == 404, "ảnh cũ phải bị xoá"
    # chọn lại ảnh trong bộ có sẵn → xoá ảnh tải lên
    r = client.patch("/api/v1/auth/me", json={"avatar": "hoa-sen"}, headers=h).json()
    assert r["avatar"] == "hoa-sen" and r["avatar_url"] is None
    assert client.get(moi).status_code == 404
    _tai(h, _anh_co_gps())
    assert client.delete("/api/v1/auth/me/anh-dai-dien", headers=h).json()["avatar"] is None


def test_xoa_tai_khoan_xoa_anh():
    h = _tk()
    u = _tai(h, _anh_co_gps()).json()["avatar_url"]
    assert client.delete("/api/v1/auth/me", headers=h).status_code == 204
    assert client.get(u).status_code == 404


def test_duong_dan_la_bi_chan():
    for ten in ("..%2F..%2Fapp.db", "abc.png", "a" * 60, "khong-co-that"):
        assert client.get(f"/api/v1/anh-dai-dien/{ten}").status_code == 404


def test_bang_vang_chung_hien_anh():
    h = _tk()
    url = _tai(h, _anh_co_gps()).json()["avatar_url"]
    toi = next(d for d in client.get("/api/v1/leaderboard", headers=h).json() if d["la_toi"])
    assert toi["avatar_url"] == url
