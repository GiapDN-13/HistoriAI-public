"""Thanh toán Premium (SePay + VietQR) và hạn mức hỏi vĩ nhân theo ngày.

Chỗ này là TIỀN THẬT: cộng thiếu thì phụ huynh mất tiền, cộng thừa (gửi lại, trùng
mã) thì nhóm mất doanh thu — nên từng nhánh của webhook đều có test riêng.
"""
import binascii
import itertools
import json
import os
import random
import uuid
from datetime import datetime, timedelta, timezone

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.api.routes import chat as route_chat  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.thanh_toan import DonThanhToan, GiaoDichNganHang  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import soan_san, vietqr  # noqa: E402
from app.services.gioi_han import bo_gioi_han  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"
KHOA = "khoa-thu-sepay"
V1 = "/api/v1"
# Chuỗi trùng với BIN/số tài khoản GIẢ dùng trong test — không phải tài khoản thật.
BIN, SO_TK, CHU_TK = "970422", "0123456789", "NGUYEN VAN A"

_so_id = itertools.count(random.randint(10 ** 8, 10 ** 9))


@pytest.fixture
def bat(monkeypatch):
    monkeypatch.setattr(settings, "THANH_TOAN_BIN", BIN)
    monkeypatch.setattr(settings, "THANH_TOAN_TEN_NH", "MB Bank")
    monkeypatch.setattr(settings, "THANH_TOAN_SO_TK", SO_TK)
    monkeypatch.setattr(settings, "THANH_TOAN_CHU_TK", CHU_TK)
    monkeypatch.setattr(settings, "SEPAY_WEBHOOK_KEY", KHOA)


@pytest.fixture
def tat(monkeypatch):
    for ten in ("THANH_TOAN_BIN", "THANH_TOAN_SO_TK", "THANH_TOAN_CHU_TK", "SEPAY_WEBHOOK_KEY"):
        monkeypatch.setattr(settings, ten, "")


# ---------------------------------------------------------------- tiện ích

def _hoc_sinh():
    email = f"tt{uuid.uuid4().hex[:8]}@test.com"
    r = client.post(f"{V1}/auth/register", json={"email": email, "full_name": "Học sinh", "password": MK},
                    headers={"X-Client-Id": uuid.uuid4().hex})
    assert r.status_code == 201, r.text
    return email, _dang_nhap(email)


def _dang_nhap(email):
    r = client.post(f"{V1}/auth/login", data={"username": email, "password": MK})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _quan_tri():
    email = f"qt{uuid.uuid4().hex[:6]}@historiai.org"
    db = SessionLocal()
    db.add(User(email=email, full_name="Quản trị", role="admin", hashed_password=hash_password(MK)))
    db.commit()
    db.close()
    return _dang_nhap(email)


def _tao_don(h, goi="thang"):
    return client.post(f"{V1}/thanh-toan/don", json={"goi": goi}, headers=h)


def _sepay(noi_dung, so_tien=39000, id_=None, loai="in", khoa=KHOA):
    h = {"Authorization": f"Apikey {khoa}"} if khoa is not None else {}
    return client.post(f"{V1}/thanh-toan/sepay", headers=h, json={
        "id": id_ if id_ is not None else next(_so_id), "gateway": "MBBank",
        "transactionDate": "2026-10-30 10:00:00", "accountNumber": SO_TK, "code": None,
        "content": noi_dung, "transferType": loai, "transferAmount": so_tien,
        "accumulated": 1000000, "subAccount": None, "referenceCode": "FT123", "description": noi_dung,
    })


def _xem(h, ma):
    return client.get(f"{V1}/thanh-toan/don/{ma}", headers=h)


def _han(iso):
    return datetime.fromisoformat(iso)


def _giao_dich(sepay_id):
    db = SessionLocal()
    try:
        g = db.query(GiaoDichNganHang).filter(GiaoDichNganHang.sepay_id == sepay_id).first()
        return g and (g.trang_thai, g.ma_don)
    finally:
        db.close()


# ---------------------------------------------------------------- VietQR

def _doc_tlv(chuoi):
    ra, i = {}, 0
    while i < len(chuoi):
        ma, dai = chuoi[i:i + 2], int(chuoi[i + 2:i + 4])
        ra[ma] = chuoi[i + 4:i + 4 + dai]
        i += 4 + dai
    return ra


def _crc_doc_lap(du_lieu: str) -> str:
    """Tính lại CRC16-CCITT/FALSE từng bit, không dùng chung mã với app."""
    crc = 0xFFFF
    for b in du_lieu.encode():
        for bit in range(7, -1, -1):
            dau = ((crc >> 15) & 1) ^ ((b >> bit) & 1)
            crc = (crc << 1) & 0xFFFF
            if dau:
                crc ^= 0x1021
    return f"{crc:04X}"


# Chuỗi mẫu đã biết của VietQR động (BIN 970422, tài khoản 0123456789, 39.000đ, nội dung HAI4K7Q2).
MAU = ("00020101021238540010A00000072701240006970422011001234567890208QRIBFTTA"
       "53037045405390005802VN62120808HAI4K7Q26304ABBF")


def test_crc16_ccitt_false_dung_vector_chuan():
    # Vector chuẩn của CRC-16/CCITT-FALSE: "123456789" → 0x29B1.
    assert vietqr.crc16_ccitt("123456789") == "29B1"
    assert _crc_doc_lap("123456789") == "29B1"
    assert f"{binascii.crc_hqx(b'123456789', 0xFFFF):04X}" == "29B1"


def test_chuoi_vietqr_khop_chuoi_mau_va_crc_doc_lap():
    s = vietqr.dung_chuoi(BIN, SO_TK, 39000, "HAI4K7Q2")
    assert s == MAU
    assert s[-4:] == _crc_doc_lap(s[:-4]) == f"{binascii.crc_hqx(s[:-4].encode(), 0xFFFF):04X}"
    assert s[-4:] == s[-4:].upper()


def test_chuoi_vietqr_doc_nguoc_tung_truong():
    t = _doc_tlv(vietqr.dung_chuoi(BIN, SO_TK, 2000, "HAI9ZZZZ"))
    assert t["00"] == "01" and t["01"] == "12"          # QR động
    nh = _doc_tlv(t["38"])
    assert nh["00"] == "A000000727" and nh["02"] == "QRIBFTTA"
    tk = _doc_tlv(nh["01"])
    assert tk["00"] == BIN and tk["01"] == SO_TK
    assert t["53"] == "704" and t["54"] == "2000" and t["58"] == "VN"
    assert _doc_tlv(t["62"])["08"] == "HAI9ZZZZ"
    assert list(t) == ["00", "01", "38", "53", "54", "58", "62", "63"]   # đúng thứ tự, CRC cuối


@pytest.mark.parametrize("bin_nh,so_tk,tien", [("12345", SO_TK, 1000), ("97042x", SO_TK, 1000),
                                                (BIN, "", 1000), (BIN, SO_TK, 0)])
def test_vietqr_tu_choi_dau_vao_sai(bin_nh, so_tk, tien):
    with pytest.raises(ValueError):
        vietqr.dung_chuoi(bin_nh, so_tk, tien, "HAI4K7Q2")


# ---------------------------------------------------------------- gói + đơn

def test_chua_cau_hinh_goi_tat_va_tao_don_503(tat):
    _, h = _hoc_sinh()
    r = client.get(f"{V1}/thanh-toan/goi")
    assert r.status_code == 200 and r.json()["bat"] is False
    assert _tao_don(h).status_code == 503
    assert "detail" in _tao_don(h).json()


def test_thieu_mot_trong_ba_thong_tin_ngan_hang_van_la_chua_bat(bat, monkeypatch):
    monkeypatch.setattr(settings, "THANH_TOAN_CHU_TK", "")
    assert client.get(f"{V1}/thanh-toan/goi").json()["bat"] is False


def test_goi_cong_khai_mot_goi_cho_nguoi_thuong(bat):
    j = client.get(f"{V1}/thanh-toan/goi").json()
    assert j == {"bat": True, "goi": [{"ma": "thang", "ten": "Premium 1 tháng",
                                       "so_tien": 39000, "so_ngay": 30}]}
    _, h = _hoc_sinh()
    assert [g["ma"] for g in client.get(f"{V1}/thanh-toan/goi", headers=h).json()["goi"]] == ["thang"]


def test_quan_tri_thay_them_goi_thu(bat):
    j = client.get(f"{V1}/thanh-toan/goi", headers=_quan_tri()).json()
    assert j["goi"][-1] == {"ma": "thu", "ten": "Gói thử 2.000đ", "so_tien": 2000, "so_ngay": 1}


def test_tao_don_dung_hinh_dang_hop_dong(bat):
    _, h = _hoc_sinh()
    r = _tao_don(h)
    assert r.status_code == 200, r.text
    d = r.json()
    assert len(d["ma_don"]) == 8 and d["ma_don"].startswith("HAI")
    assert set(d["ma_don"][3:]) <= set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    assert d["noi_dung"] == d["ma_don"] and d["so_tien"] == 39000 and d["trang_thai"] == "cho"
    assert d["ngan_hang"] == {"ten": "MB Bank", "so_tk": SO_TK, "chu_tk": CHU_TK}
    assert d["qr_chuoi"] == vietqr.dung_chuoi(BIN, SO_TK, 39000, d["ma_don"])
    han = _han(d["het_han"])
    assert han.tzinfo is not None
    assert timedelta(minutes=29) < han - datetime.now(timezone.utc) <= timedelta(minutes=30)


def test_tao_don_can_dang_nhap(bat):
    assert client.post(f"{V1}/thanh-toan/don", json={"goi": "thang"}).status_code == 401


def test_tao_lai_cung_goi_nhan_lai_don_cu(bat):
    _, h = _hoc_sinh()
    a, b = _tao_don(h).json(), _tao_don(h).json()
    assert a["ma_don"] == b["ma_don"]


def test_nguoi_khac_khong_nhan_chung_don(bat):
    _, h1 = _hoc_sinh()
    _, h2 = _hoc_sinh()
    assert _tao_don(h1).json()["ma_don"] != _tao_don(h2).json()["ma_don"]


def test_don_het_han_thi_tao_don_moi(bat):
    _, h = _hoc_sinh()
    cu = _tao_don(h).json()["ma_don"]
    _dat_het_han(cu)
    assert _tao_don(h).json()["ma_don"] != cu


def test_goi_khong_ton_tai_400_va_goi_thu_chi_quan_tri(bat):
    _, h = _hoc_sinh()
    assert _tao_don(h, "khong-co").status_code == 400
    assert _tao_don(h, "thu").status_code == 403
    r = _tao_don(_quan_tri(), "thu")
    assert r.status_code == 200 and r.json()["so_tien"] == 2000


def _dat_het_han(ma):
    db = SessionLocal()
    d = db.query(DonThanhToan).filter(DonThanhToan.ma_don == ma).first()
    d.het_han = datetime.now(timezone.utc) - timedelta(minutes=5)
    db.commit()
    db.close()


# ---------------------------------------------------------------- xem đơn

def test_xem_don_cua_nguoi_khac_404_chu_don_va_quan_tri_xem_duoc(bat):
    _, h1 = _hoc_sinh()
    _, h2 = _hoc_sinh()
    ma = _tao_don(h1).json()["ma_don"]
    assert _xem(h2, ma).status_code == 404
    assert _xem({}, ma).status_code == 401
    r = _xem(h1, ma)
    assert r.status_code == 200
    assert r.json() == {"ma_don": ma, "trang_thai": "cho", "so_tien": 39000, "premium_den": None}
    assert _xem(_quan_tri(), ma).status_code == 200
    assert _xem(h1, "HAIKHONGCO").status_code == 404


def test_don_qua_han_hien_het_han(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    _dat_het_han(ma)
    assert _xem(h, ma).json()["trang_thai"] == "het_han"


# ---------------------------------------------------------------- webhook

def test_webhook_thieu_hoac_sai_khoa_401(bat):
    assert _sepay("HAI4K7Q2", khoa=None).status_code == 401
    assert _sepay("HAI4K7Q2", khoa="sai").status_code == 401
    r = client.post(f"{V1}/thanh-toan/sepay", json={"id": 1}, headers={"Authorization": f"Bearer {KHOA}"})
    assert r.status_code == 401


def test_webhook_chua_dat_khoa_tu_choi_het(tat):
    assert _sepay("HAI4K7Q2", khoa="").status_code == 401
    r = client.post(f"{V1}/thanh-toan/sepay", json={"id": 1}, headers={"Authorization": "Apikey "})
    assert r.status_code == 401


def test_webhook_khop_don_thi_da_tra_va_cong_30_ngay(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    sid = next(_so_id)
    r = _sepay(ma, 39000, id_=sid)
    assert r.status_code == 200 and r.json() == {"success": True}
    j = _xem(h, ma).json()
    assert j["trang_thai"] == "da_tra"
    con = _han(j["premium_den"]) - datetime.now(timezone.utc)
    assert timedelta(days=29, hours=23) < con <= timedelta(days=30)
    assert _giao_dich(sid) == ("da_khop", ma)
    me = client.get(f"{V1}/auth/me", headers=h).json()
    assert me["la_premium"] is True and me["premium_den"] == j["premium_den"]


def test_gui_trung_cung_id_khong_cong_them(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    sid = next(_so_id)
    _sepay(ma, id_=sid)
    den1 = _xem(h, ma).json()["premium_den"]
    r = _sepay(ma, id_=sid)
    assert r.status_code == 200 and r.json() == {"success": True}
    assert _xem(h, ma).json()["premium_den"] == den1


def test_chuyen_hai_lan_cung_ma_don_chi_cong_mot_lan(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    _sepay(ma)
    den1 = _xem(h, ma).json()["premium_den"]
    sid2 = next(_so_id)
    assert _sepay(ma, id_=sid2).status_code == 200
    assert _xem(h, ma).json()["premium_den"] == den1
    assert _giao_dich(sid2)[0] == "chua_khop"     # tiền thừa để quản trị hoàn/đối soát tay


def test_thieu_tien_thi_chua_khop_va_don_van_cho(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    sid = next(_so_id)
    assert _sepay(ma, 38999, id_=sid).status_code == 200
    assert _giao_dich(sid) == ("chua_khop", ma)
    j = _xem(h, ma).json()
    assert j["trang_thai"] == "cho" and j["premium_den"] is None


def test_du_hoac_thua_tien_van_khop(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    _sepay(ma, 50000)
    assert _xem(h, ma).json()["trang_thai"] == "da_tra"


def test_noi_dung_co_chu_la_quanh_ma_don_van_khop_khong_phan_biet_hoa_thuong(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    _sepay(f"MBVCB.123456.chuyen tien {ma.lower()}.CT tu NGUYEN VAN B", 39000)
    assert _xem(h, ma).json()["trang_thai"] == "da_tra"


def test_chu_lap_hai_giong_ma_don_khong_lam_hong_viec_tim(bat):
    # "THAILAN1" chứa "HAILAN1" (HAI + 5 ký tự) nhưng không phải đơn nào — phải đi tiếp tới mã thật.
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    _sepay(f"THAILAN1 {ma}", 39000)
    assert _xem(h, ma).json()["trang_thai"] == "da_tra"


def test_don_het_han_ma_tien_ve_dung_so_van_kich_hoat(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    _dat_het_han(ma)
    assert _xem(h, ma).json()["trang_thai"] == "het_han"
    _sepay(ma, 39000)
    j = _xem(h, ma).json()
    assert j["trang_thai"] == "da_tra" and j["premium_den"]
    assert client.get(f"{V1}/auth/me", headers=h).json()["la_premium"] is True


def test_chuyen_ra_bi_bo_qua(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    sid = next(_so_id)
    r = _sepay(ma, 39000, id_=sid, loai="out")
    assert r.status_code == 200 and r.json() == {"success": True}
    assert _xem(h, ma).json()["trang_thai"] == "cho"
    assert _giao_dich(sid)[0] == "bo_qua"


def test_khong_co_ma_don_thi_chua_khop_va_hien_trong_danh_sach(bat):
    sid = next(_so_id)
    assert _sepay("chuyen tien an trua", 100000, id_=sid).status_code == 200
    assert _giao_dich(sid) == ("chua_khop", None)
    ds = client.get(f"{V1}/thanh-toan/giao-dich-chua-khop", headers=_quan_tri())
    assert ds.status_code == 200
    j = ds.json()
    assert len(j) <= 50 and any(g["sepay_id"] == sid and g["so_tien"] == 100000 for g in j)
    # Danh sách mới nhất trước
    assert [g["id"] for g in j] == sorted((g["id"] for g in j), reverse=True)


def test_ma_giong_dang_nhung_khong_co_don_thi_chua_khop(bat):
    sid = next(_so_id)
    _sepay("HAIZZZZZ", 39000, id_=sid)
    assert _giao_dich(sid) == ("chua_khop", None)


def test_webhook_body_khong_co_id_400(bat):
    r = client.post(f"{V1}/thanh-toan/sepay", json={"content": "x"}, headers={"Authorization": f"Apikey {KHOA}"})
    assert r.status_code == 400


# ---------------------------------------------------------------- xác nhận tay, danh sách

def test_xac_nhan_tay_chi_quan_tri(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    assert client.post(f"{V1}/thanh-toan/xac-nhan-tay", json={"ma_don": ma}).status_code == 401
    assert client.post(f"{V1}/thanh-toan/xac-nhan-tay", json={"ma_don": ma}, headers=h).status_code == 403
    assert client.get(f"{V1}/thanh-toan/giao-dich-chua-khop", headers=h).status_code == 403
    r = client.post(f"{V1}/thanh-toan/xac-nhan-tay", json={"ma_don": ma}, headers=_quan_tri())
    assert r.status_code == 200 and r.json()["trang_thai"] == "da_tra"
    assert _xem(h, ma).json()["trang_thai"] == "da_tra"
    db = SessionLocal()
    assert db.query(DonThanhToan).filter(DonThanhToan.ma_don == ma).first().nguon == "tay"
    db.close()


def test_xac_nhan_tay_hai_lan_khong_cong_doi_va_don_la_404(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    qt = _quan_tri()
    client.post(f"{V1}/thanh-toan/xac-nhan-tay", json={"ma_don": ma}, headers=qt)
    den1 = _xem(h, ma).json()["premium_den"]
    client.post(f"{V1}/thanh-toan/xac-nhan-tay", json={"ma_don": ma}, headers=qt)
    assert _xem(h, ma).json()["premium_den"] == den1
    assert client.post(f"{V1}/thanh-toan/xac-nhan-tay", json={"ma_don": "HAIKHONGCO"}, headers=qt).status_code == 404


def test_premium_cong_noi_vao_han_cu(bat):
    email, h = _hoc_sinh()
    cu = datetime.now(timezone.utc) + timedelta(days=10)
    db = SessionLocal()
    db.query(User).filter(User.email == email).first().premium_den = cu
    db.commit()
    db.close()
    ma = _tao_don(h).json()["ma_don"]
    _sepay(ma)
    moi = _han(_xem(h, ma).json()["premium_den"])
    assert abs((moi - (cu + timedelta(days=30))).total_seconds()) < 5


def test_premium_da_het_han_thi_tinh_tu_bay_gio(bat):
    email, h = _hoc_sinh()
    db = SessionLocal()
    db.query(User).filter(User.email == email).first().premium_den = datetime.now(timezone.utc) - timedelta(days=100)
    db.commit()
    db.close()
    assert client.get(f"{V1}/auth/me", headers=h).json()["la_premium"] is False
    ma = _tao_don(h).json()["ma_don"]
    _sepay(ma)
    con = _han(_xem(h, ma).json()["premium_den"]) - datetime.now(timezone.utc)
    assert timedelta(days=29, hours=23) < con <= timedelta(days=30)


def test_auth_me_co_la_premium_mac_dinh_false(bat):
    _, h = _hoc_sinh()
    me = client.get(f"{V1}/auth/me", headers=h).json()
    assert me["la_premium"] is False and me["premium_den"] is None


def test_xoa_tai_khoan_giu_don_da_tra_va_khong_vo_khoa_ngoai(bat):
    _, h = _hoc_sinh()
    ma = _tao_don(h).json()["ma_don"]
    _sepay(ma)
    cho = _hoc_sinh()[1]
    ma_cho = _tao_don(cho).json()["ma_don"]
    assert client.delete(f"{V1}/auth/me", headers=h).status_code == 204
    assert client.delete(f"{V1}/auth/me", headers=cho).status_code == 204
    db = SessionLocal()
    da_tra = db.query(DonThanhToan).filter(DonThanhToan.ma_don == ma).first()
    assert da_tra is not None and da_tra.user_id is None
    assert db.query(DonThanhToan).filter(DonThanhToan.ma_don == ma_cho).first() is None
    db.close()


# ---------------------------------------------------------------- hạn mức chat theo ngày

@pytest.fixture
def ai_gia(monkeypatch):
    """Chat thật gọi LLM + TTS: thay bằng bản giả và đếm số lần AI được gọi."""
    goi = []

    def tra_loi(*a, **k):
        goi.append(1)
        return {"reply": "Ta là Trần Hưng Đạo.", "audio_url": None, "sources": []}

    def luong(*a, **k):
        goi.append(1)
        return iter(["Ta là ", "Trần Hưng Đạo."])

    monkeypatch.setattr(route_chat, "generate_reply", tra_loi)
    monkeypatch.setattr(route_chat, "stream_reply", luong)
    monkeypatch.setattr(route_chat, "synthesize", lambda *a, **k: None)
    return goi


def _hoi(h=None, may=None, duong="chat", cau="Ông nghĩ gì về giặc Nguyên?", lich_su=None):
    # Mỗi lượt đổi X-Client-Id cho người đã đăng nhập: hạn mức ngày đếm theo TÀI KHOẢN,
    # còn lớp chống lạm dụng 8 lượt/phút theo máy sẽ chặn trước nếu dùng chung một mã.
    return client.post(f"{V1}/chat" + ("/stream" if duong == "stream" else ""),
                       json={"figure_slug": "tran-hung-dao", "message": cau, "history": lich_su or []},
                       headers={**(h or {}), "X-Client-Id": may or uuid.uuid4().hex})


def test_tai_khoan_thuong_het_10_cau_thi_cau_11_nhan_402(ai_gia):
    _, h = _hoc_sinh()
    for _ in range(10):
        assert _hoi(h).status_code == 200
    r = _hoi(h)
    assert r.status_code == 402
    assert r.json()["detail"] == {
        "ma": "het_luot_ngay",
        "thong_bao": "Hôm nay bạn đã hỏi hết 10 câu miễn phí. Nâng cấp Premium để hỏi không giới hạn.",
        "gioi_han": 10}
    assert len(ai_gia) == 10       # câu bị chặn không gọi AI


def test_stream_cung_bi_chan_402_truoc_khi_mo_luong(ai_gia):
    _, h = _hoi_het(10, duong="stream")
    r = _hoi(h, duong="stream")
    assert r.status_code == 402 and r.json()["detail"]["ma"] == "het_luot_ngay"


def _hoi_het(n, duong="chat"):
    _, h = _hoc_sinh()
    for _ in range(n):
        assert _hoi(h, duong=duong).status_code == 200
    return None, h


def test_quan_tri_khong_bi_tran_ngay_nhung_khong_thanh_premium(ai_gia):
    # Tài khoản demo của nhóm: trình diễn mà hết 10 câu là hỏng buổi.
    h = _quan_tri()
    for _ in range(13):
        assert _hoi(h).status_code == 200
    assert client.get(f"{V1}/auth/me", headers=h).json()["la_premium"] is False


def test_premium_khong_bi_chan_theo_ngay(ai_gia):
    email, h = _hoi_het(10)
    assert _hoi(h).status_code == 402
    me = client.get(f"{V1}/auth/me", headers=h).json()
    db = SessionLocal()
    db.query(User).filter(User.id == me["id"]).first().premium_den = datetime.now(timezone.utc) + timedelta(days=5)
    db.commit()
    db.close()
    for _ in range(12):
        assert _hoi(h).status_code == 200
    assert _hoi(h, duong="stream").status_code == 200


def test_premium_het_han_thi_lai_bi_chan(ai_gia):
    _, h = _hoi_het(10)
    me = client.get(f"{V1}/auth/me", headers=h).json()
    db = SessionLocal()
    db.query(User).filter(User.id == me["id"]).first().premium_den = datetime.now(timezone.utc) - timedelta(seconds=1)
    db.commit()
    db.close()
    assert _hoi(h).status_code == 402


def test_khach_gioi_han_5_cau_theo_client_id(ai_gia):
    may = uuid.uuid4().hex
    for _ in range(5):
        assert _hoi(may=may).status_code == 200
    r = _hoi(may=may)
    assert r.status_code == 402 and r.json()["detail"]["gioi_han"] == 5
    assert "5 câu miễn phí" in r.json()["detail"]["thong_bao"]
    assert _hoi(may=uuid.uuid4().hex).status_code == 200      # máy khác không bị vạ lây


def test_doi_may_khong_lach_duoc_voi_tai_khoan_da_dang_nhap(ai_gia):
    # `_hoi` đã đổi X-Client-Id mỗi lượt — đếm theo user_id nên vẫn bị chặn ở câu 11.
    _, h = _hoi_het(10)
    assert _hoi(h, may=uuid.uuid4().hex).status_code == 402


def test_cau_goi_y_soan_san_khong_tinh_luot(ai_gia, tmp_path, monkeypatch):
    cau = 'Ý chí "Sát Thát" bắt nguồn từ đâu?'
    tep = tmp_path / "soan.json"
    tep.write_text(json.dumps({"tran-hung-dao": [{"hoi": cau, "dap": "Ta kể con nghe."}]},
                              ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(soan_san, "TEP", tep)
    soan_san._kho.cache_clear()
    try:
        may = uuid.uuid4().hex
        for _ in range(3):     # 6 câu soạn sẵn > hạn mức khách (5), vẫn không bị chặn
            assert _hoi(may=may, cau=cau, duong="stream").status_code == 200
            assert _hoi(may=may, cau=cau).status_code == 200
        assert ai_gia == []
        bo_gioi_han.dat_lai()   # 8 lượt/phút theo máy là lớp khác, không phải thứ đang thử
        # và hạn mức của máy này còn nguyên: vẫn hỏi được đủ 5 câu AI
        for _ in range(5):
            assert _hoi(may=may).status_code == 200
        assert _hoi(may=may).status_code == 402
    finally:
        soan_san._kho.cache_clear()


def test_hoi_tiep_co_lich_su_van_tinh_luot(ai_gia):
    # Câu soạn sẵn chỉ áp cho câu ĐẦU cuộc trò chuyện; có lịch sử là câu AI thật.
    may = uuid.uuid4().hex
    ls = [{"role": "user", "content": "chào"}, {"role": "assistant", "content": "chào con"}]
    for _ in range(5):
        assert _hoi(may=may, lich_su=ls).status_code == 200
    assert _hoi(may=may, lich_su=ls).status_code == 402


def test_han_muc_doc_tu_cau_hinh(ai_gia, monkeypatch):
    monkeypatch.setattr(settings, "CHAT_KHACH_NGAY", 2)
    may = uuid.uuid4().hex
    assert _hoi(may=may).status_code == 200 and _hoi(may=may).status_code == 200
    r = _hoi(may=may)
    assert r.status_code == 402 and r.json()["detail"]["gioi_han"] == 2
