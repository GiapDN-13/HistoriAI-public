"""Ranh giới miễn phí / Premium ở MÁY CHỦ: bài lộ trình và bộ ôn câu sai.

(Bản tin phụ huynh có test riêng trong test_ban_tin.py.)

Điều không được hỏng: phần bị khoá thì máy chủ KHÔNG gửi dữ liệu — kiểm trên chính
phản hồi JSON, không kiểm giao diện. Quản trị xem đủ như Premium; hết hạn Premium thì
khoá lại ngay.
"""
import os
import uuid
from datetime import datetime, timedelta, timezone

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.event import HistoricalEvent  # noqa: E402
from app.models.quiz import QuizQuestion  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import lo_trinh  # noqa: E402

seed.run()
client = TestClient(app)
API = "/api/v1"
MK = "12345678"
MA_LO_TRINH = "bach-dang-938__bach-dang-1288"
CAC_BAI = ["bach-dang-938", "khang-chien-tong-981", "bach-dang-1288"]
CAC_MUC_BI_CAT = ("boi_canh", "dien_bien", "ket_qua")


def _tk():
    email = f"kp{uuid.uuid4().hex[:8]}@test.com"
    client.post(f"{API}/auth/register", json={"email": email, "full_name": "Học Sinh", "password": MK},
                headers={"X-Client-Id": uuid.uuid4().hex})
    ma = client.post(f"{API}/auth/login", data={"username": email, "password": MK}).json()["access_token"]
    db = SessionLocal()
    try:
        uid = db.query(User.id).filter(User.email == email).scalar()
    finally:
        db.close()
    return uid, {"Authorization": f"Bearer {ma}"}


def _sua(uid: int, **cot) -> None:
    db = SessionLocal()
    try:
        u = db.get(User, uid)
        for k, v in cot.items():
            setattr(u, k, v)
        db.commit()
    finally:
        db.close()


def _premium(uid: int, ngay: int = 30) -> None:
    _sua(uid, premium_den=(datetime.now(timezone.utc) + timedelta(days=ngay)).replace(tzinfo=None))


def _lo_trinh(h=None) -> dict:
    lt = client.get(f"{API}/lo-trinh", headers=h or {})
    assert lt.status_code == 200, lt.text
    return {x["ma"]: x for x in lt.json()}[MA_LO_TRINH]


# ---------- /lo-trinh ----------

def test_lo_trinh_khach_bai_dau_day_du_bai_sau_bi_khoa():
    lt = _lo_trinh()
    bai = lt["su_kien"]
    assert [b["slug"] for b in bai] == CAC_BAI

    dau = bai[0]
    assert dau["khoa"] is False
    assert dau["boi_canh"] and dau["dien_bien"] and dau["ket_qua"] and dau["kien_thuc"]["y"]

    for b in bai[1:]:
        assert b["khoa"] is True, b["slug"]
        # Vẫn hiện mục tiêu + câu chốt + tên để người học biết bài nói gì.
        assert b["muc_tieu"] and b["cau_chot"] and b["ten"] and b["ten_ngan"]
        # Các mục còn lại RỖNG trong chính phản hồi — không phải giấu ở giao diện.
        for muc in CAC_MUC_BI_CAT:
            assert b[muc] == [], (b["slug"], muc)
        assert b["kien_thuc"] == {"tieu_de": "", "y": []}


def test_lo_trinh_khach_khong_lo_chu_trong_noi_dung_bai_khoa():
    """Dò thô trên toàn văn JSON: mọi câu của bài 2 và 3 (trừ mục tiêu, câu chốt) không có mặt."""
    tho = lo_trinh._kho()
    goc = next(lt for lt in tho if lt["ma"] == MA_LO_TRINH)["su_kien"]
    van_ban = client.get(f"{API}/lo-trinh").text
    for sk in goc[1:]:
        cac_y = sk["boi_canh"] + sk["dien_bien"] + sk["ket_qua"] + sk["kien_thuc"]["y"]
        assert cac_y, "dữ liệu thật phải có nội dung để phép thử này có nghĩa"
        for y in cac_y:
            assert y not in van_ban, y[:60]


def test_lo_trinh_nguoi_thuong_da_dang_nhap_van_bi_khoa():
    _, h = _tk()
    bai = _lo_trinh(h)["su_kien"]
    assert [b["khoa"] for b in bai] == [False, True, True]


def test_lo_trinh_premium_tra_day_du():
    uid, h = _tk()
    _premium(uid)
    bai = _lo_trinh(h)["su_kien"]
    assert [b["khoa"] for b in bai] == [False, False, False]
    for b in bai:
        assert b["boi_canh"] and b["dien_bien"] and b["ket_qua"] and b["kien_thuc"]["y"]
    # Đúng bằng nội dung gốc, không bị cắt hay đổi.
    goc = next(lt for lt in lo_trinh._kho() if lt["ma"] == MA_LO_TRINH)["su_kien"]
    assert [b["dien_bien"] for b in bai] == [g["dien_bien"] for g in goc]


def test_lo_trinh_quan_tri_tra_day_du_du_khong_co_premium():
    uid, h = _tk()
    _sua(uid, role="admin")
    assert _lo_trinh(h)["su_kien"][2]["khoa"] is False
    assert _lo_trinh(h)["su_kien"][2]["ket_qua"]


def test_lo_trinh_het_han_premium_la_khoa_lai_ngay():
    uid, h = _tk()
    _premium(uid, ngay=30)
    assert _lo_trinh(h)["su_kien"][1]["khoa"] is False
    _premium(uid, ngay=-1)
    assert _lo_trinh(h)["su_kien"][1]["khoa"] is True


def test_lo_trinh_khong_de_lop_dem_dung_chung_giua_cac_nguoi():
    r = client.get(f"{API}/lo-trinh")
    assert "authorization" in r.headers["vary"].lower()
    assert "private" in r.headers["cache-control"]


def test_lo_trinh_token_hong_xu_nhu_khach():
    r = client.get(f"{API}/lo-trinh", headers={"Authorization": "Bearer khong-dung"})
    assert r.status_code == 200
    assert _lo_trinh({"Authorization": "Bearer khong-dung"})["su_kien"][1]["khoa"] is True


# ---------- /me/cau-sai ----------

def _lam_sai(h, n: int) -> list[int]:
    """Nộp sai n câu (mỗi lượt một câu để id tăng dần). Trả id câu theo thứ tự nộp."""
    db = SessionLocal()
    try:
        e = db.query(HistoricalEvent).filter_by(slug="bach-dang-938").one()
        ds = db.query(QuizQuestion).filter_by(event_id=e.id).order_by(QuizQuestion.id).limit(n).all()
        cap = [(q.id, next(o for o in "ABCD" if o != q.correct_option.upper())) for q in ds]
    finally:
        db.close()
    assert len(cap) == n, "trận 938 phải có đủ câu cho phép thử"
    for qid, chon in cap:
        r = client.post(f"{API}/quiz/submit", headers=h,
                        json=[{"question_id": qid, "selected_option": chon}])
        assert r.status_code == 200, r.text
    return [q for q, _ in cap]


def _on(h, **tham_so) -> dict:
    r = client.get(f"{API}/me/cau-sai", headers=h, params={"kem_tong": 1, "limit": 100, **tham_so})
    assert r.status_code == 200, r.text
    return r.json()


def test_cau_sai_nguoi_thuong_nhan_5_cau_gan_nhat_cung_tong_that():
    _, h = _tk()
    ids = _lam_sai(h, 8)
    j = _on(h)
    assert j["tong"] == 8 and j["da_cat"] == 3
    # 5 câu GẦN NHẤT, mới → cũ.
    assert [c["id"] for c in j["cau_hoi"]] == list(reversed(ids))[:5]
    # Hỏi nhiều hơn cũng không lấy được câu thứ 6.
    assert len(_on(h, limit=200)["cau_hoi"]) == 5


def test_cau_sai_nguoi_thuong_it_hon_5_khong_bi_cat():
    _, h = _tk()
    _lam_sai(h, 3)
    j = _on(h)
    assert (len(j["cau_hoi"]), j["tong"], j["da_cat"]) == (3, 3, 0)


def test_cau_sai_premium_on_toan_bo():
    uid, h = _tk()
    ids = _lam_sai(h, 8)
    _premium(uid)
    j = _on(h)
    assert j["tong"] == 8 and j["da_cat"] == 0
    assert [c["id"] for c in j["cau_hoi"]] == list(reversed(ids))


def test_cau_sai_quan_tri_on_toan_bo():
    uid, h = _tk()
    _lam_sai(h, 7)
    _sua(uid, role="admin")
    j = _on(h)
    assert (len(j["cau_hoi"]), j["tong"], j["da_cat"]) == (7, 7, 0)


def test_cau_sai_premium_tu_gioi_han_limit_khong_bi_tinh_la_cau_khoa():
    uid, h = _tk()
    _lam_sai(h, 8)
    _premium(uid)
    j = _on(h, limit=3)
    assert len(j["cau_hoi"]) == 3 and j["tong"] == 8 and j["da_cat"] == 0


def test_cau_sai_dung_lai_thi_roi_khoi_danh_sach_va_tong_giam():
    _, h = _tk()
    ids = _lam_sai(h, 6)
    assert _on(h)["tong"] == 6
    db = SessionLocal()
    try:
        q = db.get(QuizQuestion, ids[-1])        # câu gần nhất, đang trong 5 câu đầu danh sách
        dung = q.correct_option.upper()
    finally:
        db.close()
    client.post(f"{API}/quiz/submit", headers=h, json=[{"question_id": q.id, "selected_option": dung}])
    j = _on(h)
    assert j["tong"] == 5 and j["da_cat"] == 0
    assert ids[-1] not in [c["id"] for c in j["cau_hoi"]]


def test_cau_sai_khong_co_kem_tong_van_la_mang_tron_cho_app_cu():
    _, h = _tk()
    _lam_sai(h, 7)
    r = client.get(f"{API}/me/cau-sai?limit=10", headers=h)
    assert isinstance(r.json(), list) and len(r.json()) == 5, "APK 0.5.x đọc thẳng mảng"
    assert "correct_option" not in r.json()[0], "bộ ôn không lộ đáp án"


def test_cau_sai_phai_dang_nhap():
    assert client.get(f"{API}/me/cau-sai?kem_tong=1").status_code == 401
