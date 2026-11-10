"""Chế độ kiểm tra cho lớp học (giai đoạn 1): giáo viên ra đề → mở phòng → học sinh vào nhanh
bằng tên + PIN → làm bài → nộp → giáo viên xem bảng và xuất CSV."""
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.quiz import QuizQuestion  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"


@pytest.fixture(autouse=True)
def _ma_gv(monkeypatch):
    monkeypatch.setattr(settings, "MA_GIAO_VIEN", "ma-thu-gv")


def _tk():
    email = f"gv{uuid.uuid4().hex[:8]}@test.com"
    client.post("/api/v1/auth/register", json={"email": email, "full_name": "Cô Lan", "password": MK},
                headers={"X-Client-Id": uuid.uuid4().hex})
    ma = client.post("/api/v1/auth/login", data={"username": email, "password": MK}).json()["access_token"]
    return {"Authorization": f"Bearer {ma}"}


def _gv():
    h = _tk()
    assert client.post("/api/v1/auth/lam-giao-vien", json={"ma": "ma-thu-gv"}, headers=h).status_code == 200
    return h


def _dap_an(ids):
    db = SessionLocal()
    try:
        return {q.id: q.correct_option.upper() for q in db.query(QuizQuestion).filter(QuizQuestion.id.in_(ids))}
    finally:
        db.close()


def _mo_phong(h, so_cau=3, **them):
    kho = client.get("/api/v1/lop/kho-cau", headers=h).json()
    ids = [c["id"] for c in kho[0]["cau"][:so_cau]]
    de = client.post("/api/v1/lop/de", json={"tieu_de": "Ôn Bạch Đằng", "cau_ids": ids, "giay_moi_cau": 20},
                     headers=h).json()
    p = client.post("/api/v1/lop/phong", json={"de_id": de["id"], **them}, headers=h)
    assert p.status_code == 201, p.text
    return p.json(), ids


def _vao(ma, ten, pin="1234", lop="8A2"):
    return client.post(f"/api/v1/phong/{ma}/vao", json={"ho_ten": ten, "pin": pin, "lop": lop},
                       headers={"X-Client-Id": uuid.uuid4().hex})


# ---------- phân quyền ----------

def test_hoc_sinh_khong_mo_duoc_phong_va_ma_sai_bi_tu_choi():
    h = _tk()
    assert client.get("/api/v1/lop/kho-cau", headers=h).status_code == 403
    assert client.post("/api/v1/auth/lam-giao-vien", json={"ma": "doan-bua"}, headers=h).status_code == 400


def test_chua_dat_ma_giao_vien_thi_khong_ai_nang_duoc(monkeypatch):
    monkeypatch.setattr(settings, "MA_GIAO_VIEN", "")
    h = _tk()
    assert client.post("/api/v1/auth/lam-giao-vien", json={"ma": ""}, headers=h).status_code == 422
    assert client.post("/api/v1/auth/lam-giao-vien", json={"ma": "x"}, headers=h).status_code == 400


# ---------- trọn luồng ----------

def test_tron_luong_giao_vien_va_hoc_sinh():
    gv = _gv()
    phong, ids = _mo_phong(gv)
    ma = phong["ma"]
    assert len(ma) == 6 and phong["link"].endswith(f"/vao/{ma}")

    info = client.get(f"/api/v1/phong/{ma}").json()
    assert info["so_cau"] == 3 and info["dang_mo"] and "correct_option" not in str(info)

    r = _vao(ma, "Nguyễn Văn An")
    assert r.status_code == 200, r.text
    assert r.json()["tai_khoan_nhanh"] is True
    hs = {"Authorization": f"Bearer {r.json()['access_token']}"}

    de = client.get(f"/api/v1/phong/{ma}/de", headers=hs).json()
    assert sorted(c["id"] for c in de["cau"]) == sorted(ids)
    assert "correct_option" not in str(de), "không được gửi đáp án xuống máy học sinh"

    da = _dap_an(ids)
    q1, q2 = de["cau"][0]["id"], de["cau"][1]["id"]
    assert client.post(f"/api/v1/phong/{ma}/tra-loi", json={"question_id": q1, "chon": da[q1]},
                       headers=hs).json()["dung"] is True
    sai = next(o for o in "ABCD" if o != da[q2])
    assert client.post(f"/api/v1/phong/{ma}/tra-loi", json={"question_id": q2, "chon": sai},
                       headers=hs).json()["dung"] is False
    # trả lời lại câu đã làm → giữ lần đầu
    lai = client.post(f"/api/v1/phong/{ma}/tra-loi", json={"question_id": q2, "chon": da[q2]}, headers=hs).json()
    assert lai["da_tra_loi_truoc"] is True and lai["dung"] is False

    nop = client.post(f"/api/v1/phong/{ma}/nop", headers=hs).json()
    assert nop["so_dung"] == 1 and nop["tong"] == 3 and nop["diem_10"] == pytest.approx(3.33, 0.01)
    assert all("correct_option" in c and "explanation" in c for c in nop["cau"]), "nộp xong mới thấy đáp án"
    assert client.post(f"/api/v1/phong/{ma}/tra-loi", json={"question_id": de["cau"][2]["id"], "chon": "A"},
                       headers=hs).status_code == 409

    # Bài lớp học vào lịch sử làm bài thường → Ôn câu sai có câu q2
    assert q2 in [c["id"] for c in client.get("/api/v1/me/cau-sai", headers=hs).json()]

    _vao(ma, "Trần Thị Bình")          # vào nhưng chưa làm
    bang = client.get(f"/api/v1/lop/phong/{ma}/bang", headers=gv).json()
    assert bang["phong"]["so_bai"] == 2 and bang["phong"]["so_nop"] == 1
    assert bang["hoc_sinh"][0]["ten"] == "Nguyễn Văn An", "đã nộp xếp trước"
    cau2 = next(c for c in bang["tung_cau"] if c["id"] == q2)
    assert cau2["so_tra_loi"] == 1 and cau2["ti_le_dung"] == 0 and cau2["nham_nhieu_nhat"] == sai

    csv = client.get(f"/api/v1/lop/phong/{ma}/csv", headers=gv)
    assert csv.status_code == 200 and csv.text.startswith("﻿Họ tên")
    assert "Nguyễn Văn An,8A2,1,3,3.33,có" in csv.text


def test_vao_lai_bang_ten_va_pin_lay_lai_bai_dang_lam():
    gv = _gv()
    phong, _ = _mo_phong(gv)
    ma = phong["ma"]
    a = _vao(ma, "Lê Minh")
    ha = {"Authorization": f"Bearer {a.json()['access_token']}"}
    q = client.get(f"/api/v1/phong/{ma}/de", headers=ha).json()["cau"][0]["id"]
    client.post(f"/api/v1/phong/{ma}/tra-loi", json={"question_id": q, "chon": "A"}, headers=ha)

    lai = _vao(ma, "lê minh", pin="1234")          # máy khác, viết thường
    assert lai.status_code == 200 and lai.json()["bai"]["da_lam"] == 1
    assert _vao(ma, "Lê Minh", pin="9999").status_code == 409, "sai PIN — không cho lấy bài của bạn"


def test_doan_pin_bi_chan():
    gv = _gv()
    ma = _mo_phong(gv)[0]["ma"]
    _vao(ma, "Phạm Hoa", pin="1111")
    for i in range(8):
        assert _vao(ma, "Phạm Hoa", pin=f"{2000 + i}").status_code == 409
    assert _vao(ma, "Phạm Hoa", pin="3000").status_code == 429


def test_phong_dong_thi_khong_nhan_bai_moi():
    gv = _gv()
    ma = _mo_phong(gv)[0]["ma"]
    a = _vao(ma, "Hồ Nam")
    ha = {"Authorization": f"Bearer {a.json()['access_token']}"}
    assert client.post(f"/api/v1/lop/phong/{ma}/dong", headers=gv).json()["dang_mo"] is False
    assert _vao(ma, "Học Sinh Muộn").status_code == 410
    q = client.get(f"/api/v1/phong/{ma}/de", headers=ha).json()["cau"][0]["id"]
    assert client.post(f"/api/v1/phong/{ma}/tra-loi", json={"question_id": q, "chon": "A"},
                       headers=ha).status_code == 410
    assert client.post(f"/api/v1/phong/{ma}/nop", headers=ha).status_code == 200, "vẫn nộp được phần đã làm"


def test_giao_vien_khac_khong_xem_duoc_phong():
    ma = _mo_phong(_gv())[0]["ma"]
    assert client.get(f"/api/v1/lop/phong/{ma}/bang", headers=_gv()).status_code == 404


def test_hoc_sinh_da_dang_nhap_vao_bang_tai_khoan_cua_minh():
    ma = _mo_phong(_gv())[0]["ma"]
    h = _tk()
    r = client.post(f"/api/v1/phong/{ma}/vao", json={"lop": "9A"}, headers=h)
    assert r.status_code == 200 and r.json()["tai_khoan_nhanh"] is False
    assert r.json()["bai"]["ten"] == "Cô Lan"


def test_thieu_ten_hoac_pin_thi_bao_ro():
    ma = _mo_phong(_gv())[0]["ma"]
    assert client.post(f"/api/v1/phong/{ma}/vao", json={"ho_ten": "An"}).status_code == 422
    assert client.post(f"/api/v1/phong/{ma}/vao", json={"ho_ten": "An", "pin": "12a4"}).status_code == 422
    assert client.get("/api/v1/phong/000000").status_code == 404


def test_xoa_tai_khoan_xoa_ca_du_lieu_lop_hoc():
    from app.models.lop_hoc import BaiThi, DeKiemTra, PhongThi
    gv = _gv()
    phong, _ = _mo_phong(gv)
    hs = {"Authorization": f"Bearer {_vao(phong['ma'], 'Học Sinh Xoá').json()['access_token']}"}
    assert client.delete("/api/v1/auth/me", headers=hs).status_code == 204
    assert client.get(f"/api/v1/lop/phong/{phong['ma']}/bang", headers=gv).json()["hoc_sinh"] == []
    assert client.delete("/api/v1/auth/me", headers=gv).status_code == 204
    db = SessionLocal()
    try:
        assert db.query(PhongThi).filter(PhongThi.ma == phong["ma"]).first() is None
        assert db.query(DeKiemTra).filter(DeKiemTra.id == phong["de_id"]).first() is None
        assert db.query(BaiThi).filter(BaiThi.ten_hien == "Học Sinh Xoá").first() is None
    finally:
        db.close()
