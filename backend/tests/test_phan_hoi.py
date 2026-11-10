"""Phản hồi trong app + báo cáo tuần."""
import os
import uuid
from datetime import datetime, timedelta, timezone

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.phan_hoi import PhanHoi  # noqa: E402
from app.services.analytics import _tong_phan_hoi, bao_cao_tuan  # noqa: E402

seed.run()
client = TestClient(app)
URL = "/api/v1/phan-hoi"


def _gui(body: dict, may: str | None = None, headers: dict | None = None):
    h = {"X-Client-Id": may or uuid.uuid4().hex, **(headers or {})}
    return client.post(URL, json=body, headers=h)


def test_gui_phan_hoi_hop_le_luu_kem_nguon_da_lam_sach():
    may = uuid.uuid4().hex
    r = _gui({"diem": 5, "nps": 9, "gop_y": "  Hay lắm!  ", "ngu_canh": "quiz",
              "target": "bach-dang-938", "nguon": "Facebook", "noi_dung": "on thi su"}, may)
    assert r.status_code == 201
    db = SessionLocal()
    try:
        p = db.query(PhanHoi).filter_by(client_id=may).one()
        assert (p.diem, p.nps, p.gop_y, p.nguon, p.noi_dung) == (5, 9, "Hay lắm!", "facebook", "on-thi-su")
    finally:
        db.close()


def test_phan_hoi_rong_hoac_ngoai_khoang_bi_tu_choi():
    assert _gui({"ngu_canh": "quiz"}).status_code == 422
    assert _gui({"gop_y": "   "}).status_code == 422
    assert _gui({"diem": 6}).status_code == 422
    assert _gui({"nps": 11}).status_code == 422
    assert _gui({"diem": 3, "ngu_canh": "la"}).status_code == 422


def test_chi_chon_tran_muon_them_cung_gui_duoc_luu_da_lam_sach():
    """Chip "muốn thêm trận nào" một mình đã là phản hồi; slug làm sạch, bỏ rỗng và trùng."""
    may = uuid.uuid4().hex
    r = _gui({"muon_them": ["dien-bien-phu-1954", " Hai Ba Trung 40 ", "dien-bien-phu-1954", "!!"],
              "ngu_canh": "quiz"}, may)
    assert r.status_code == 201
    db = SessionLocal()
    try:
        p = db.query(PhanHoi).filter_by(client_id=may).one()
        assert (p.diem, p.nps, p.gop_y) == (None, None, None)
        assert p.muon_them == "dien-bien-phu-1954,hai-ba-trung-40"
    finally:
        db.close()


def test_muon_them_qua_5_hoac_qua_dai_hoac_toan_rong_bi_tu_choi():
    sau = ["hai-ba-trung-40", "nhu-nguyet-1077", "chong-mong-co-1258", "rach-gam-xoai-mut-1785",
           "dien-bien-phu-1954", "van-lang-au-lac"]
    assert _gui({"muon_them": sau}).status_code == 422
    assert _gui({"muon_them": sau[:5]}).status_code == 201
    assert _gui({"muon_them": ["a" * 33]}).status_code == 422
    assert _gui({"muon_them": []}).status_code == 422
    assert _gui({"muon_them": ["!!", "   "]}).status_code == 422


def test_tong_hop_dem_tran_muon_them_giam_dan():
    db = SessionLocal()
    moc = datetime.now(timezone.utc) + timedelta(days=500)   # khoảng riêng, không lẫn test khác
    try:
        for m in ("dien-bien-phu-1954,hai-ba-trung-40", "dien-bien-phu-1954", None,
                  "van-lang-au-lac,dien-bien-phu-1954", "hai-ba-trung-40"):
            db.add(PhanHoi(client_id="muon-them-test", diem=5, muon_them=m, created_at=moc))
        db.commit()
        kq = _tong_phan_hoi(db, moc - timedelta(minutes=1), moc + timedelta(minutes=1), 5, 5)
    finally:
        db.query(PhanHoi).filter_by(client_id="muon-them-test").delete()
        db.commit()
        db.close()
    assert kq["muon_them"] == [{"slug": "dien-bien-phu-1954", "so": 3},
                               {"slug": "hai-ba-trung-40", "so": 2},
                               {"slug": "van-lang-au-lac", "so": 1}]


def test_mot_may_gui_qua_10_lan_mot_ngay_bi_chan():
    may = uuid.uuid4().hex
    for _ in range(10):
        assert _gui({"diem": 4}, may).status_code == 201
    assert _gui({"diem": 4}, may).status_code == 429
    assert _gui({"diem": 4}).status_code == 201, "máy khác không bị ảnh hưởng"


def test_cong_thuc_nps():
    """NPS = % ủng hộ (9–10) − % phản đối (0–6)."""
    db = SessionLocal()
    moc = datetime.now(timezone.utc) + timedelta(days=400)   # khoảng riêng, không lẫn test khác
    try:
        for d in (10, 9, 9, 8, 7, 3, 0, 6, 10, 5):
            db.add(PhanHoi(client_id="nps-test", nps=d, diem=4, created_at=moc))
        db.commit()
        kq = _tong_phan_hoi(db, moc - timedelta(minutes=1), moc + timedelta(minutes=1), 20, 10)
    finally:
        db.query(PhanHoi).filter_by(client_id="nps-test").delete()
        db.commit()
        db.close()
    # 4 ủng hộ (10,9,9,10) = 40%; 4 phản đối (3,0,6,5) = 40%; trung lập 20% → NPS 0
    assert kq["nps"] == {"so": 10, "diem": 0, "ung_ho": 40, "trung_lap": 20, "phan_doi": 40}
    assert kq["ti_le_tra_loi"] == 50.0
    assert kq["sao_tb"] == 4.0


def test_xoa_tai_khoan_xoa_luon_phan_hoi_cua_nguoi_do():
    email = f"hs{uuid.uuid4().hex[:8]}@test.com"
    client.post("/api/v1/auth/register", json={"email": email, "full_name": "A", "password": "12345678"})
    tok = client.post("/api/v1/auth/login", data={"username": email, "password": "12345678"}).json()["access_token"]
    h = {"Authorization": f"Bearer {tok}"}
    may = uuid.uuid4().hex
    assert _gui({"gop_y": "Tên em là A, trường B"}, may, h).status_code == 201
    assert client.delete("/api/v1/auth/me", headers=h).status_code == 204
    db = SessionLocal()
    try:
        assert db.query(PhanHoi).filter_by(client_id=may).count() == 0
    finally:
        db.close()


def test_bao_cao_tuan_co_du_cac_muc():
    _gui({"diem": 5, "nps": 10, "gop_y": "Rất thích phần chat", "ngu_canh": "chat"})
    db = SessionLocal()
    try:
        md = bao_cao_tuan(db)
    finally:
        db.close()
    for muc in ("## Số liệu tuần", "| Thiết bị hoạt động |", "| NPS (−100 → +100) |",
                "### Phễu tuần này", "### Khách đến từ đâu", "### Phản hồi người dùng",
                "Rất thích phần chat"):
        assert muc in md, muc


def test_bao_cao_tuan_co_dong_tran_muon_them():
    db = SessionLocal()
    moc = datetime.now(timezone.utc) + timedelta(days=600)   # tuần riêng, không lẫn test khác
    try:
        for m in ("chien-dich-ho-chi-minh-1975,van-lang-au-lac", "chien-dich-ho-chi-minh-1975"):
            db.add(PhanHoi(client_id="bao-cao-muon-them", ngu_canh="ho-so", diem=4, muon_them=m,
                           created_at=moc))
        db.commit()
        md = bao_cao_tuan(db, den=moc + timedelta(minutes=1))
    finally:
        db.query(PhanHoi).filter_by(client_id="bao-cao-muon-them").delete()
        db.commit()
        db.close()
    assert "- Muốn app có thêm: chien-dich-ho-chi-minh-1975 (2) · van-lang-au-lac (1)" in md, md


def test_route_bao_cao_tuan_tra_markdown():
    r = client.get("/api/v1/analytics/bao-cao-tuan")
    assert r.status_code in (200, 401)
    if r.status_code == 200:
        assert r.headers["content-type"].startswith("text/markdown")
