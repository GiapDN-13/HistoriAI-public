"""Mục "Doanh thu & Premium" của dashboard: số liệu, báo cáo tuần, nút xác nhận tay.

Chỗ này là tiền thật nên số nào cũng kiểm bằng đơn dựng tay với giờ đã biết.

Các test số liệu dùng một "bây giờ" giả ở năm 2040: CSDL test dùng chung giữa các tệp
test (đơn của test_thanh_toan nằm ở 2026), đặt mốc xa như vậy thì chỉ còn đơn của tệp này
trong khoảng tính. Riêng "từng mua / mua lại" tính trên toàn lịch sử nên so theo mức chênh
trước/sau khi thêm dữ liệu.
"""
import json
import os
import uuid
from datetime import datetime, timedelta, timezone

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.thanh_toan import DonThanhToan, GiaoDichNganHang  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services.analytics import bao_cao_tuan  # noqa: E402
from app.services.doanh_thu import tinh_doanh_thu  # noqa: E402

seed.run()
client = TestClient(app)
V1 = "/api/v1"
KHOA = "khoa-doanh-thu"

VN = timezone(timedelta(hours=7))
# 10:00 sáng 16/03/2040 giờ VN.
DEN = datetime(2040, 3, 16, 10, 0, tzinfo=VN)


def vn(ngay, gio, phut=0):
    # Đổi sang UTC trước khi ghi: SQLite bỏ múi giờ, ghi thẳng giờ VN là lưu lệch 7 tiếng
    # (đúng như cách code thật chỉ ghi UTC).
    return datetime(2040, 3, ngay, gio, phut, tzinfo=VN).astimezone(timezone.utc)


def _ma():
    return "HAI" + uuid.uuid4().hex[:5].upper()


def _nguoi(db, ten, premium_den=None, role="student"):
    u = User(email=f"{uuid.uuid4().hex[:10]}@riengtu.example", full_name=ten, role=role,
             hashed_password=hash_password("12345678"), premium_den=premium_den)
    db.add(u)
    db.flush()
    return u


def _don(db, user, tra=None, goi="thang", so_tien=39000, nguon=None, tao=None, het_han=None):
    """Đơn đã trả lúc [tra] (hoặc đơn chờ nếu không có [tra])."""
    tao = tao or ((tra - timedelta(minutes=5)) if tra else DEN)
    d = DonThanhToan(ma_don=_ma(), user_id=user.id, goi=goi, so_tien=so_tien,
                     trang_thai="da_tra" if tra else "cho", tao_luc=tao,
                     het_han=het_han or tao + timedelta(minutes=30),
                     tra_luc=tra, nguon=nguon if tra else None)
    db.add(d)
    db.flush()
    return d


@pytest.fixture(scope="module")
def du_lieu():
    db = SessionLocal()
    try:
        truoc = tinh_doanh_thu(db, 7, DEN)["premium"]
        an = _nguoi(db, "Nguyễn Văn An", premium_den=DEN + timedelta(days=10))
        binh = _nguoi(db, "Trần Thị Bình", premium_den=DEN + timedelta(days=2))
        _nguoi(db, "Lê Hết Hạn", premium_den=DEN - timedelta(days=1))
        qt = _nguoi(db, "Quản Trị Viên", premium_den=DEN + timedelta(days=1), role="admin")

        o_hom_qua = _don(db, an, tra=vn(15, 23, 30), nguon="sepay")       # 23:30 VN ngày 15
        o_hom_nay = _don(db, binh, tra=vn(16, 0, 30), nguon="tay")        # 00:30 VN ngày 16 = 17:30 UTC ngày 15
        o_cu = _don(db, an, tra=vn(1, 12), nguon="sepay")                 # ngoài 7 ngày, trong 30 ngày
        o_thu = _don(db, qt, tra=vn(16, 8), goi="thu", so_tien=2000, nguon="tay")
        _don(db, an, tao=vn(16, 8), het_han=vn(16, 8, 30))                # hết hạn, không trả
        _don(db, binh, tao=vn(16, 9, 50), het_han=vn(16, 10, 20))         # còn chờ

        dai = "Chuyen khoan mua premium " + "x" * 100
        db.add(GiaoDichNganHang(sepay_id=9_000_000_001, so_tien=39000, noi_dung=dai, ngay_gd="2040-03-15 23:30:00",
                                ma_don="HAIAB234", trang_thai="chua_khop", nhan_luc=vn(15, 23, 30)))
        db.add(GiaoDichNganHang(sepay_id=9_000_000_002, so_tien=39000, noi_dung="da khop roi",
                                trang_thai="da_khop", nhan_luc=vn(15, 23, 31)))
        db.add(GiaoDichNganHang(sepay_id=9_000_000_003, so_tien=39000, noi_dung="tien ra",
                                trang_thai="bo_qua", nhan_luc=vn(15, 23, 32)))
        db.commit()
        return {"truoc": truoc, "an": an.email, "o": (o_hom_qua.ma_don, o_hom_nay.ma_don, o_cu.ma_don,
                                                       o_thu.ma_don)}
    finally:
        db.close()


@pytest.fixture
def ket_qua(du_lieu):
    db = SessionLocal()
    try:
        return tinh_doanh_thu(db, 7, DEN)
    finally:
        db.close()


# ----------------------------------------------------------------- doanh thu

def test_goi_thu_khong_vao_doanh_thu_nhung_duoc_dem_rieng(ket_qua):
    # 39.000 (15/03) + 39.000 (16/03): 2.000đ của gói thử không cộng vào đâu cả.
    assert ket_qua["trong_khoang"] == {"so_tien": 78000, "so_don": 2}
    assert ket_qua["so_don_thu"] == 1
    assert sum(d["so_tien"] for d in ket_qua["theo_ngay"]) == 78000


def test_ranh_gioi_ngay_theo_gio_viet_nam(ket_qua):
    # 00:30 ngày 16 giờ VN còn là 17:30 ngày 15 giờ UTC — vẫn phải rơi vào "hôm nay" 16/03.
    assert ket_qua["hom_nay"] == {"so_tien": 39000, "so_don": 1}
    theo_ngay = {d["ngay"]: d for d in ket_qua["theo_ngay"]}
    assert theo_ngay["2040-03-16"] == {"ngay": "2040-03-16", "so_tien": 39000, "so_don": 1}
    # 23:30 giờ VN ngày 15 đúng là ngày 15.
    assert theo_ngay["2040-03-15"]["so_tien"] == 39000


def test_theo_ngay_du_cac_ngay_ke_ca_ngay_khong_co_don(ket_qua):
    ngay = [d["ngay"] for d in ket_qua["theo_ngay"]]
    assert ngay == [f"2040-03-{n:02d}" for n in range(10, 17)]
    assert [d["so_tien"] for d in ket_qua["theo_ngay"]][:5] == [0] * 5


def test_cua_so_7_va_30_ngay(ket_qua):
    assert ket_qua["bay_ngay"] == {"so_tien": 78000, "so_don": 2}
    # đơn ngày 01/03 chỉ vào cửa sổ 30 ngày
    assert ket_qua["ba_muoi_ngay"] == {"so_tien": 117000, "so_don": 3}


def test_khoang_dang_xem_doi_theo_days(du_lieu):
    db = SessionLocal()
    try:
        dai = tinh_doanh_thu(db, 30, DEN)
        ngan = tinh_doanh_thu(db, 1, DEN)
    finally:
        db.close()
    assert dai["trong_khoang"]["so_tien"] == 117000
    assert len(dai["theo_ngay"]) == 30
    assert ngan["trong_khoang"] == {"so_tien": 39000, "so_don": 1}
    assert [d["ngay"] for d in ngan["theo_ngay"]] == ["2040-03-16"]


def test_ti_le_tra_va_don_het_han(ket_qua):
    # Đơn tạo trong 7 ngày (không kể gói thử): 2 đã trả + 1 hết hạn + 1 còn chờ.
    assert ket_qua["don"] == {"da_tao": 4, "da_tra": 2, "het_han": 1, "dang_cho": 1, "ti_le_tra": 50.0}


def test_ti_le_tra_bang_0_khi_chua_co_don():
    db = SessionLocal()
    try:
        r = tinh_doanh_thu(db, 7, datetime(2050, 1, 1, tzinfo=VN))
    finally:
        db.close()
    assert r["don"]["da_tao"] == 0 and r["don"]["ti_le_tra"] == 0.0
    assert r["trong_khoang"] == {"so_tien": 0, "so_don": 0}


def test_nguon_tra_tu_dong_va_xac_nhan_tay(ket_qua):
    # Gói thử cũng xác nhận tay nhưng không được tính vào đây.
    assert ket_qua["nguon_tra"] == {"sepay": 1, "tay": 1}


# ------------------------------------------------------------------- Premium

def test_dang_premium_va_sap_het_han(ket_qua):
    p = ket_qua["premium"]
    # An (còn 10 ngày) + Bình (còn 2 ngày); người hết hạn và quản trị không tính.
    assert p["dang_co"] == 2
    assert p["sap_het_han"] == 1


def test_tung_mua_va_mua_lai(du_lieu, ket_qua):
    truoc, sau = du_lieu["truoc"], ket_qua["premium"]
    # An mua 2 lần (15/03 và 01/03), Bình 1 lần; gói thử của quản trị không tính.
    assert sau["tung_mua"] - truoc["tung_mua"] == 2
    assert sau["mua_lai"] - truoc["mua_lai"] == 1


# ------------------------------------------------------------ danh sách / riêng tư

def test_don_gan_day_sap_moi_nhat_truoc_va_khong_lo_thong_tin(du_lieu, ket_qua):
    thu, hom_nay, hom_qua = du_lieu["o"][3], du_lieu["o"][1], du_lieu["o"][0]
    ds = ket_qua["don_gan_day"]
    assert [d["ma_don"] for d in ds[:3]] == [thu, hom_nay, hom_qua]
    assert ds[2] == {"ma_don": hom_qua, "goi": "thang", "so_tien": 39000,
                     "gio_tra": "15/03/2040 23:30", "nguon": "sepay", "nguoi_mua": "An"}
    assert len(ds) <= 20

    # Không email, không user_id, không họ tên đầy đủ.
    tho = json.dumps(ket_qua, ensure_ascii=False)
    assert du_lieu["an"] not in tho and "@riengtu.example" not in tho
    assert "Nguyễn Văn" not in tho
    assert "user_id" not in tho


def test_giao_dich_chua_khop_cat_noi_dung_va_bo_qua_loai_khac(ket_qua):
    ds = ket_qua["chua_khop"]
    assert len(ds) <= 20
    gd = next(g for g in ds if g["sepay_id"] == 9_000_000_001)
    assert len(gd["noi_dung"]) == 60 and gd["noi_dung"].startswith("Chuyen khoan mua premium")
    assert gd["so_tien"] == 39000 and gd["ma_don"] == "HAIAB234"
    assert gd["gio"] == "15/03/2040 23:30"
    assert {9_000_000_002, 9_000_000_003}.isdisjoint(g["sepay_id"] for g in ds)
    assert set(gd) == {"sepay_id", "so_tien", "noi_dung", "gio", "ma_don"}


def test_bao_cao_tuan_co_dong_doanh_thu(du_lieu):
    db = SessionLocal()
    try:
        md = bao_cao_tuan(db, DEN)
    finally:
        db.close()
    assert "Doanh thu tuần: 78.000 đ · 2 đơn · 2 người đang có Premium" in md


# ------------------------------------------------------------------- route

@pytest.fixture
def khoa(monkeypatch):
    monkeypatch.setattr(settings, "ANALYTICS_KEY", KHOA)


def _don_cho():
    """Một đơn đang chờ của người chưa có Premium; trả về (mã đơn, user_id)."""
    db = SessionLocal()
    try:
        u = _nguoi(db, "Phụ Huynh Mới")
        d = _don(db, u, tao=datetime.now(timezone.utc))
        db.commit()
        return d.ma_don, u.id
    finally:
        db.close()


def _doc(ma):
    db = SessionLocal()
    try:
        d = db.query(DonThanhToan).filter(DonThanhToan.ma_don == ma).one()
        u = db.get(User, d.user_id)
        return d.trang_thai, d.nguon, u.premium_den
    finally:
        db.close()


def _xac_nhan(ma, key=KHOA, **them):
    return client.post(f"{V1}/analytics/xac-nhan-don", params={"key": key} if key else {},
                       json={"ma_don": ma, **them})


def test_xac_nhan_sai_khoa_bi_tu_choi(khoa):
    ma, _ = _don_cho()
    assert _xac_nhan(ma, key=None).status_code == 401
    assert _xac_nhan(ma, key="sai").status_code == 401
    assert _doc(ma)[0] == "cho"


def test_xac_nhan_bi_khoa_khi_chua_dat_khoa_analytics(monkeypatch):
    # Route xem số liệu để ngỏ khi chưa đặt khoá, nhưng route này cộng Premium thì không được.
    monkeypatch.setattr(settings, "ANALYTICS_KEY", "")
    ma, _ = _don_cho()
    assert _xac_nhan(ma, key=None).status_code == 403
    assert _xac_nhan(ma, key="").status_code == 403
    assert _doc(ma)[0] == "cho"


def test_xac_nhan_dung_khoa_cong_premium_mot_lan(khoa):
    ma, _ = _don_cho()
    r = _xac_nhan(ma.lower())      # gõ thường vẫn nhận
    assert r.status_code == 200, r.text
    assert r.json()["vua_kich_hoat"] is True and r.json()["trang_thai"] == "da_tra"
    trang_thai, nguon, den = _doc(ma)
    assert (trang_thai, nguon) == ("da_tra", "tay")
    assert den is not None
    # SQLite trả về không múi giờ (đã là UTC) — gắn lại để so với giờ hiện tại.
    con_lai = den.replace(tzinfo=timezone.utc) - datetime.now(timezone.utc)
    assert timedelta(days=29, hours=23) < con_lai <= timedelta(days=30)

    r2 = _xac_nhan(ma)
    assert r2.status_code == 200
    assert r2.json()["vua_kich_hoat"] is False
    assert _doc(ma)[2] == den          # lần hai không cộng thêm ngày


def test_xac_nhan_ma_la_tra_404(khoa):
    assert _xac_nhan("HAIKHONGCO").status_code == 404


def test_xac_nhan_kem_sepay_id_dua_khoan_tien_ra_khoi_danh_sach_chua_khop(khoa):
    ma, _ = _don_cho()
    ma_da_tra, _ = _don_cho()
    db = SessionLocal()
    try:
        db.add_all([
            GiaoDichNganHang(sepay_id=9_100_000_001, so_tien=39000, noi_dung="sai ma",
                             trang_thai="chua_khop", nhan_luc=datetime.now(timezone.utc)),
            GiaoDichNganHang(sepay_id=9_100_000_002, so_tien=39000, noi_dung="chuyen lan hai",
                             trang_thai="chua_khop", nhan_luc=datetime.now(timezone.utc)),
        ])
        db.commit()
    finally:
        db.close()

    assert _xac_nhan(ma, sepay_id=9_100_000_001).status_code == 200
    # Đơn đã trả từ trước: khoản tiền thứ hai phải còn đó để quản trị tính chuyện hoàn tiền.
    assert _xac_nhan(ma_da_tra).status_code == 200
    assert _xac_nhan(ma_da_tra, sepay_id=9_100_000_002).json()["vua_kich_hoat"] is False

    db = SessionLocal()
    try:
        g1 = db.query(GiaoDichNganHang).filter_by(sepay_id=9_100_000_001).one()
        g2 = db.query(GiaoDichNganHang).filter_by(sepay_id=9_100_000_002).one()
        assert (g1.trang_thai, g1.ma_don) == ("da_khop", ma)
        assert g2.trang_thai == "chua_khop"
        assert db.query(DonThanhToan).filter_by(ma_don=ma).one().giao_dich_id == g1.id
    finally:
        db.close()


def test_summary_co_khoa_doanh_thu(khoa):
    r = client.get(f"{V1}/analytics/summary", params={"key": KHOA, "days": 7})
    assert r.status_code == 200
    dt = r.json()["doanh_thu"]
    assert {"hom_nay", "bay_ngay", "ba_muoi_ngay", "trong_khoang", "theo_ngay", "don", "so_don_thu",
            "premium", "nguon_tra", "don_gan_day", "chua_khop"} <= set(dt)
    assert len(dt["theo_ngay"]) == 7
    assert isinstance(dt["trong_khoang"]["so_tien"], int)
    # route summary vẫn cần khoá
    assert client.get(f"{V1}/analytics/summary", params={"key": "sai"}).status_code == 401
