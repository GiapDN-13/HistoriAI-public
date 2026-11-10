"""Lớp học giai đoạn 3: câu giáo viên tự soạn, lớp cố định, thống kê nhiều buổi, giữ tài khoản nhanh."""
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.lop_hoc_mo_rong import CauRieng, LopHoc, ThanhVienLop  # noqa: E402
from app.models.quiz import QuizQuestion  # noqa: E402
from app.models.quiz_attempt import QuizAttempt  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"
API = "/api/v1"


@pytest.fixture(autouse=True)
def _ma_gv(monkeypatch):
    monkeypatch.setattr(settings, "MA_GIAO_VIEN", "ma-thu-gv")


def _tk():
    email = f"gv{uuid.uuid4().hex[:8]}@test.com"
    client.post(f"{API}/auth/register", json={"email": email, "full_name": "Thầy Hùng", "password": MK},
                headers={"X-Client-Id": uuid.uuid4().hex})
    ma = client.post(f"{API}/auth/login", data={"username": email, "password": MK}).json()["access_token"]
    return {"Authorization": f"Bearer {ma}"}


def _gv():
    h = _tk()
    assert client.post(f"{API}/auth/lam-giao-vien", json={"ma": "ma-thu-gv"}, headers=h).status_code == 200
    return h


CAU = {"question": "Ngô Quyền đóng cọc ở sông nào?", "option_a": "Sông Bạch Đằng", "option_b": "Sông Hồng",
       "option_c": "Sông Mã", "option_d": "Sông Cầu", "correct_option": "A",
       "explanation": "Trận Bạch Đằng năm 938.", "event_slug": "bach-dang-938"}


def _cau_rieng(gv, **doi):
    r = client.post(f"{API}/lop/cau-rieng", json={**CAU, **doi}, headers=gv)
    assert r.status_code == 201, r.text
    return r.json()


def _vao(ma, ten, pin="1234"):
    r = client.post(f"{API}/phong/{ma}/vao", json={"ho_ten": ten, "pin": pin},
                    headers={"X-Client-Id": uuid.uuid4().hex})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _dap_an_kho(ids):
    db = SessionLocal()
    try:
        return {q.id: q.correct_option.upper() for q in db.query(QuizQuestion).filter(QuizQuestion.id.in_(ids))}
    finally:
        db.close()


def _lam_het(ma, hs, dung: set[int] | None = None, dap_an: dict | None = None):
    """Trả lời mọi câu; câu trong `dung` chọn đúng, còn lại chọn sai. Rồi nộp."""
    for c in client.get(f"{API}/phong/{ma}/de", headers=hs).json()["cau"]:
        da = dap_an[c["id"]]
        chon = da if dung is None or c["id"] in dung else next(o for o in "ABCD" if o != da)
        client.post(f"{API}/phong/{ma}/tra-loi", json={"question_id": c["id"], "chon": chon}, headers=hs)
    return client.post(f"{API}/phong/{ma}/nop", headers=hs).json()


# ================================================================ câu tự soạn

def test_soan_sua_xoa_cau_rieng_va_chi_minh_thay():
    gv, gv2 = _gv(), _gv()
    c = _cau_rieng(gv)
    assert c["id"] < 0 and c["cau_rieng_id"] == -c["id"] and c["event_title"]
    assert [x["cau_rieng_id"] for x in client.get(f"{API}/lop/cau-rieng", headers=gv).json()] == [c["cau_rieng_id"]]
    assert client.get(f"{API}/lop/cau-rieng", headers=gv2).json() == []
    # Kho câu khi soạn đề: câu riêng đứng đầu, chỉ của mình
    kho = client.get(f"{API}/lop/kho-cau", headers=gv).json()
    assert kho[0]["rieng"] is True and kho[0]["cau"][0]["id"] == c["id"]
    assert all(not nhom.get("rieng") for nhom in client.get(f"{API}/lop/kho-cau", headers=gv2).json())
    # Giáo viên khác không sửa/xoá được
    assert client.patch(f"{API}/lop/cau-rieng/{c['cau_rieng_id']}", json={"question": "Bị sửa trộm?"},
                        headers=gv2).status_code == 404
    assert client.delete(f"{API}/lop/cau-rieng/{c['cau_rieng_id']}", headers=gv2).status_code == 404
    s = client.patch(f"{API}/lop/cau-rieng/{c['cau_rieng_id']}", json={"question": "Sửa lỗi chính tả nhé?",
                                                                       "event_slug": None}, headers=gv)
    assert s.status_code == 200 and s.json()["question"] == "Sửa lỗi chính tả nhé?" and s.json()["event_slug"] is None
    assert client.delete(f"{API}/lop/cau-rieng/{c['cau_rieng_id']}", headers=gv).json()["chi_an"] is False
    assert client.get(f"{API}/lop/cau-rieng", headers=gv).json() == []


def test_cau_rieng_kiem_du_lieu():
    gv = _gv()
    assert client.post(f"{API}/lop/cau-rieng", json={**CAU, "option_b": "sông bạch  đằng"},
                       headers=gv).status_code == 422, "bốn phương án phải khác nhau"
    assert client.post(f"{API}/lop/cau-rieng", json={**CAU, "correct_option": "E"}, headers=gv).status_code == 422
    assert client.post(f"{API}/lop/cau-rieng", json={**CAU, "event_slug": "khong-co"}, headers=gv).status_code == 404
    assert client.post(f"{API}/lop/cau-rieng", json=CAU, headers=_tk()).status_code == 403, "học sinh không soạn được"


def test_de_tron_cau_kho_va_cau_rieng_cham_dung_va_khong_lot_ra_quiz_cong_khai():
    gv, gv2 = _gv(), _gv()
    c = _cau_rieng(gv)
    kho = client.get(f"{API}/lop/kho-cau", headers=gv).json()
    ids_kho = [x["id"] for x in kho[1]["cau"][:2]]
    # Giáo viên khác không mượn được câu riêng của người ta vào đề
    assert client.post(f"{API}/lop/de", json={"tieu_de": "Mượn", "cau_ids": [c["id"]]},
                       headers=gv2).status_code == 400
    de = client.post(f"{API}/lop/de", json={"tieu_de": "Trộn", "cau_ids": ids_kho + [c["id"]]}, headers=gv).json()
    assert de["so_cau"] == 3
    ma = client.post(f"{API}/lop/phong", json={"de_id": de["id"]}, headers=gv).json()["ma"]

    hs = _vao(ma, "Đỗ Quyên")
    bai = client.get(f"{API}/phong/{ma}/de", headers=hs).json()
    assert c["id"] in [x["id"] for x in bai["cau"]] and "correct_option" not in str(bai)
    dap_an = {**_dap_an_kho(ids_kho), c["id"]: "A"}
    nop = _lam_het(ma, hs, dap_an=dap_an)
    assert nop["so_dung"] == 3
    rieng = next(x for x in nop["cau"] if x["id"] == c["id"])
    assert rieng["correct_option"] == "A" and rieng["explanation"] == CAU["explanation"]

    # Bảng theo dõi của giáo viên có câu riêng
    bang = client.get(f"{API}/lop/phong/{ma}/bang", headers=gv).json()
    assert any(x["id"] == c["id"] and x["so_dung"] == 1 for x in bang["tung_cau"])

    # Câu riêng KHÔNG vào lịch sử làm bài/ôn câu sai/quiz công khai
    db = SessionLocal()
    try:
        assert db.query(QuizAttempt).filter(QuizAttempt.question_id == c["id"]).count() == 0
        assert db.query(QuizAttempt).filter(QuizAttempt.lan_nop == f"phong-{ma}").count() == 2
    finally:
        db.close()
    assert CAU["question"] not in client.get(f"{API}/quiz/bach-dang-938").text
    assert CAU["question"] not in client.get(f"{API}/me/cau-sai", headers=hs).text

    # Đã có học sinh trả lời: không đổi được đáp án đúng; xoá thì chỉ ẩn, bài cũ vẫn xem lại được
    cid = c["cau_rieng_id"]
    assert client.patch(f"{API}/lop/cau-rieng/{cid}", json={"correct_option": "B"}, headers=gv).status_code == 409
    assert client.patch(f"{API}/lop/cau-rieng/{cid}", json={"explanation": "Năm 938, Ngô Quyền."},
                        headers=gv).status_code == 200
    assert client.delete(f"{API}/lop/cau-rieng/{cid}", headers=gv).json()["chi_an"] is True
    assert any(x["id"] == c["id"] for x in client.post(f"{API}/phong/{ma}/nop", headers=hs).json()["cau"])
    assert client.post(f"{API}/lop/de", json={"tieu_de": "Dùng lại", "cau_ids": [c["id"]]},
                       headers=gv).status_code == 400, "câu đã xoá không đưa vào đề mới được"


# ================================================================ lớp cố định + thống kê

def test_lop_co_dinh_ghi_nhan_thanh_vien_va_quyen_rieng_tu():
    gv, gv2 = _gv(), _gv()
    lop = client.post(f"{API}/lop/lop-hoc", json={"ten": " 8A2 "}, headers=gv)
    assert lop.status_code == 201 and lop.json()["ten"] == "8A2"
    lop_id = lop.json()["id"]
    assert client.post(f"{API}/lop/lop-hoc", json={"ten": "8a2"}, headers=gv).status_code == 409
    # Thêm tay một em trước khi em vào phòng
    assert client.post(f"{API}/lop/lop-hoc/{lop_id}/thanh-vien", json={"ten": "Vũ Hà"}, headers=gv).status_code == 201

    kho = client.get(f"{API}/lop/kho-cau", headers=gv).json()
    de = client.post(f"{API}/lop/de", json={"tieu_de": "Buổi 1", "cau_ids": [kho[0]["cau"][0]["id"]]},
                     headers=gv).json()
    # Không mở được phòng cho lớp của người khác
    assert client.post(f"{API}/lop/phong", json={"de_id": de["id"], "lop_id": lop_id},
                       headers=gv2).status_code == 404
    p = client.post(f"{API}/lop/phong", json={"de_id": de["id"], "lop_id": lop_id}, headers=gv).json()
    assert p["lop_id"] == lop_id
    _vao(p["ma"], "vũ hà")                # trùng tên em được thêm tay → nối vào dòng đó
    _vao(p["ma"], "Lý Tâm")
    ct = client.get(f"{API}/lop/lop-hoc/{lop_id}", headers=gv).json()
    assert ct["si_so"] == 2 and ct["so_buoi"] == 1
    assert all(t["da_vao_phong"] for t in ct["thanh_vien"])
    assert {t["ten"] for t in ct["thanh_vien"]} == {"Vũ Hà", "Lý Tâm"}

    # Giáo viên khác không thấy gì của lớp này
    assert client.get(f"{API}/lop/lop-hoc/{lop_id}", headers=gv2).status_code == 404
    assert client.get(f"{API}/lop/lop-hoc/{lop_id}/thong-ke", headers=gv2).status_code == 404
    assert client.get(f"{API}/lop/lop-hoc", headers=gv2).json() == []

    # Bỏ một em, rồi xoá lớp: phòng giữ nguyên, thành phòng lẻ
    tam = next(t for t in ct["thanh_vien"] if t["ten"] == "Lý Tâm")
    assert client.delete(f"{API}/lop/lop-hoc/{lop_id}/thanh-vien/{tam['id']}", headers=gv).status_code == 204
    assert client.get(f"{API}/lop/lop-hoc", headers=gv).json()[0]["si_so"] == 1
    assert client.delete(f"{API}/lop/lop-hoc/{lop_id}", headers=gv).status_code == 204
    assert client.get(f"{API}/lop/phong/{p['ma']}/bang", headers=gv).json()["phong"]["lop_id"] is None


def test_gan_phong_cu_vao_lop_ghi_nhan_hoc_sinh_da_lam():
    gv = _gv()
    lop_id = client.post(f"{API}/lop/lop-hoc", json={"ten": "9B"}, headers=gv).json()["id"]
    kho = client.get(f"{API}/lop/kho-cau", headers=gv).json()
    de = client.post(f"{API}/lop/de", json={"tieu_de": "Cũ", "cau_ids": [kho[0]["cau"][0]["id"]]}, headers=gv).json()
    ma = client.post(f"{API}/lop/phong", json={"de_id": de["id"]}, headers=gv).json()["ma"]
    _vao(ma, "Mai Anh")
    r = client.post(f"{API}/lop/phong/{ma}/gan-lop", json={"lop_id": lop_id}, headers=gv)
    assert r.status_code == 200 and r.json()["lop_id"] == lop_id
    assert client.get(f"{API}/lop/lop-hoc/{lop_id}", headers=gv).json()["si_so"] == 1
    assert client.post(f"{API}/lop/phong/{ma}/gan-lop", json={"lop_id": lop_id}, headers=_gv()).status_code == 404


def test_thong_ke_nhieu_buoi():
    gv = _gv()
    lop_id = client.post(f"{API}/lop/lop-hoc", json={"ten": "7C"}, headers=gv).json()["id"]
    c = _cau_rieng(gv)
    kho = client.get(f"{API}/lop/kho-cau", headers=gv).json()
    ids = [x["id"] for x in kho[1]["cau"][:3]]
    dap_an = {**_dap_an_kho(ids), c["id"]: "A"}

    def buoi(ten_de, cau_ids):
        de = client.post(f"{API}/lop/de", json={"tieu_de": ten_de, "cau_ids": cau_ids}, headers=gv).json()
        return client.post(f"{API}/lop/phong", json={"de_id": de["id"], "lop_id": lop_id, "tron_cau": False},
                           headers=gv).json()["ma"]

    # Buổi 1: An đúng 1/4 (chỉ đúng câu riêng), Bình đúng 4/4
    ma1 = buoi("Buổi 1", ids + [c["id"]])
    _lam_het(ma1, _vao(ma1, "An"), dung={c["id"]}, dap_an=dap_an)
    _lam_het(ma1, _vao(ma1, "Bình"), dap_an=dap_an)
    _vao(ma1, "Cường")        # vào mà không làm → vắng, không tính 0 điểm
    # Buổi 2: An đúng hết
    ma2 = buoi("Buổi 2", ids)
    _lam_het(ma2, _vao(ma2, "An", pin="5678"), dap_an=dap_an)

    tk = client.get(f"{API}/lop/lop-hoc/{lop_id}/thong-ke", headers=gv).json()
    assert [b["ma"] for b in tk["buoi"]] == [ma1, ma2]
    assert tk["buoi"][0]["so_tinh"] == 2 and tk["buoi"][0]["so_bai"] == 3
    assert tk["buoi"][0]["diem_tb"] == pytest.approx((2.5 + 10) / 2)
    assert tk["buoi"][1]["diem_tb"] == 10
    # Hai lần vào của "An" là hai tài khoản nhanh khác nhau → hai dòng; em nào cũng có điểm đúng buổi
    an = [h for h in tk["hoc_sinh"] if h["ten"] == "An"]
    assert {tuple(h["diem"]) for h in an} == {(2.5, None), (None, 10.0)}
    binh = next(h for h in tk["hoc_sinh"] if h["ten"] == "Bình")
    assert binh["diem"] == [10.0, None] and binh["diem_tb"] == 10
    cuong = next(h for h in tk["hoc_sinh"] if h["ten"] == "Cường")
    assert cuong["so_buoi"] == 0 and cuong["diem_tb"] is None
    # Câu yếu nhất: câu kho ở buổi 1 (An sai) — câu riêng cả lớp đúng hết nên xếp cuối
    assert tk["cau_yeu"][0]["ti_le_dung"] < 100
    assert tk["cau_yeu"][-1]["id"] == c["id"] and tk["cau_yeu"][-1]["ti_le_dung"] == 100
    assert tk["su_kien_yeu"] and all("su_kien" in s for s in tk["su_kien_yeu"])


def test_thong_ke_tien_bo_cua_mot_em_qua_cac_buoi():
    gv = _gv()
    lop_id = client.post(f"{API}/lop/lop-hoc", json={"ten": "6A"}, headers=gv).json()["id"]
    hs = _tk()                                       # em có tài khoản thật: cùng một người qua hai buổi
    kho = client.get(f"{API}/lop/kho-cau", headers=gv).json()
    ids = [x["id"] for x in kho[0]["cau"][:2]]
    dap_an = _dap_an_kho(ids)
    for so_dung in (0, 2):
        de = client.post(f"{API}/lop/de", json={"tieu_de": f"B{so_dung}", "cau_ids": ids}, headers=gv).json()
        ma = client.post(f"{API}/lop/phong", json={"de_id": de["id"], "lop_id": lop_id}, headers=gv).json()["ma"]
        client.post(f"{API}/phong/{ma}/vao", json={}, headers=hs)
        _lam_het(ma, hs, dung=set(ids[:so_dung]), dap_an=dap_an)
    tk = client.get(f"{API}/lop/lop-hoc/{lop_id}/thong-ke", headers=gv).json()
    assert len(tk["hoc_sinh"]) == 1
    h = tk["hoc_sinh"][0]
    assert h["diem"] == [0.0, 10.0] and h["thay_doi"] == 10.0 and h["so_buoi"] == 2


# ================================================================ giữ tài khoản nhanh

def _phong_nhanh():
    gv = _gv()
    kho = client.get(f"{API}/lop/kho-cau", headers=gv).json()
    ids = [kho[0]["cau"][0]["id"]]
    de = client.post(f"{API}/lop/de", json={"tieu_de": "Giữ", "cau_ids": ids}, headers=gv).json()
    return client.post(f"{API}/lop/phong", json={"de_id": de["id"]}, headers=gv).json()["ma"], ids


def test_giu_tai_khoan_nhanh_giu_nguyen_bai_va_xp():
    ma, ids = _phong_nhanh()
    hs = _vao(ma, "Hoàng Yến")
    _lam_het(ma, hs, dap_an=_dap_an_kho(ids))
    truoc = client.get(f"{API}/auth/me", headers=hs).json()
    assert truoc["xp"] > 0

    email = f"yen{uuid.uuid4().hex[:6]}@gmail.com"
    r = client.post(f"{API}/auth/giu-tai-khoan", json={"email": email, "mat_khau": "matkhau123"}, headers=hs)
    assert r.status_code == 200, r.text
    moi = {"Authorization": f"Bearer {r.json()['access_token']}"}
    sau = client.get(f"{API}/auth/me", headers=moi).json()
    assert sau["id"] == truoc["id"] and sau["xp"] == truoc["xp"] and sau["email"] == email
    assert sau["co_mat_khau"] is True
    assert client.get(f"{API}/auth/me", headers=hs).status_code == 401, "mã cũ cấp lúc vào phòng hết hiệu lực"
    # Đăng nhập được bằng email + mật khẩu mới; lịch sử còn nguyên
    dn = client.post(f"{API}/auth/login", data={"username": email, "password": "matkhau123"})
    assert dn.status_code == 200
    assert client.get(f"{API}/me/lich-su-quiz", headers=moi).json()
    # PIN không còn là cửa vào tài khoản đã có email
    lai = client.post(f"{API}/phong/{ma}/vao", json={"ho_ten": "Hoàng Yến", "pin": "1234"},
                      headers={"X-Client-Id": uuid.uuid4().hex})
    assert lai.status_code == 200
    la = client.get(f"{API}/auth/me", headers={"Authorization": f"Bearer {lai.json()['access_token']}"}).json()
    assert la["id"] != truoc["id"], "tên + PIN cũ chỉ tạo được bài mới, không vào được tài khoản đã giữ"
    # Đăng nhập bằng email rồi vào lại phòng → lấy lại đúng bài
    vao = client.post(f"{API}/phong/{ma}/vao", json={}, headers=moi).json()
    assert vao["bai"]["da_nop"] is True and vao["tai_khoan_nhanh"] is False
    # Đã có email rồi thì không "giữ" lần nữa
    assert client.post(f"{API}/auth/giu-tai-khoan", json={"email": f"x{email}", "mat_khau": "matkhau123"},
                       headers=moi).status_code == 400


def test_giu_tai_khoan_kiem_trung_email_va_gioi_han():
    ma, _ = _phong_nhanh()
    email = f"trung{uuid.uuid4().hex[:6]}@test.com"
    client.post(f"{API}/auth/register", json={"email": email, "full_name": "Người Có Trước", "password": MK},
                headers={"X-Client-Id": uuid.uuid4().hex})
    hs = _vao(ma, "Học Trò")
    assert client.post(f"{API}/auth/giu-tai-khoan", json={"email": email.upper(), "mat_khau": "matkhau123"},
                       headers=hs).status_code == 400, "trùng email (không phân biệt hoa thường)"
    assert client.post(f"{API}/auth/giu-tai-khoan", json={"email": "a@nhanh.historiai.org", "mat_khau": "matkhau123"},
                       headers=hs).status_code == 422
    assert client.post(f"{API}/auth/giu-tai-khoan", json={"email": "ok@test.com", "mat_khau": "ngan"},
                       headers=hs).status_code == 422
    # Cùng giới hạn với đăng ký: 5 lần / giờ / máy
    may = {**hs, "X-Client-Id": "may-co-dinh"}
    ma_loi = [client.post(f"{API}/auth/giu-tai-khoan", json={"email": email, "mat_khau": "matkhau123"},
                          headers=may).status_code for _ in range(6)]
    assert ma_loi[-1] == 429


def test_xoa_tai_khoan_giao_vien_xoa_cau_rieng_va_lop():
    gv = _gv()
    c = _cau_rieng(gv)
    lop_id = client.post(f"{API}/lop/lop-hoc", json={"ten": "10A1"}, headers=gv).json()["id"]
    client.post(f"{API}/lop/lop-hoc/{lop_id}/thanh-vien", json={"ten": "Tên Thêm Tay"}, headers=gv)
    de = client.post(f"{API}/lop/de", json={"tieu_de": "Đề X", "cau_ids": [c["id"]]}, headers=gv).json()
    ma = client.post(f"{API}/lop/phong", json={"de_id": de["id"], "lop_id": lop_id}, headers=gv).json()["ma"]
    hs = _vao(ma, "Em Sẽ Xoá")
    # Học sinh xoá tài khoản → tên em biến khỏi danh sách lớp
    assert client.delete(f"{API}/auth/me", headers=hs).status_code == 204
    assert {t["ten"] for t in client.get(f"{API}/lop/lop-hoc/{lop_id}", headers=gv).json()["thanh_vien"]} \
        == {"Tên Thêm Tay"}
    assert client.delete(f"{API}/auth/me", headers=gv).status_code == 204
    db = SessionLocal()
    try:
        assert db.get(CauRieng, c["cau_rieng_id"]) is None
        assert db.get(LopHoc, lop_id) is None
        assert db.query(ThanhVienLop).filter(ThanhVienLop.lop_id == lop_id).count() == 0
    finally:
        db.close()
