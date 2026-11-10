"""Dán nhiều câu (định dạng của prompt AI) + bảng vàng phòng thi cho học sinh."""
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402
from app.services import nhap_cau  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"

# Đúng kiểu ChatGPT hay trả: lời dẫn, chữ đậm, "Câu 1:", "A)", giải thích nhiều dòng
DE_AI = """Dưới đây là bộ câu hỏi theo yêu cầu của thầy cô:

**Câu 1:** Trận Bạch Đằng năm 938 do ai chỉ huy?
A. Ngô Quyền
B. Lê Hoàn
C. Trần Hưng Đạo
D. Lý Thường Kiệt
**Đáp án: A**
Giải thích: Năm 938 Ngô Quyền đánh tan quân Nam Hán
trên sông Bạch Đằng.

---

Câu 2. Quân giặc trong trận Bạch Đằng 938 là quân nào?
A) Nam Hán
B) Tống
C) Nguyên
D) Minh
Đáp án đúng: A. Nam Hán
Giải thích: Hoằng Tháo chỉ huy quân Nam Hán.

Câu 3: Câu thiếu đáp án
A. Một
B. Hai
C. Ba
D. Bốn
"""


def test_doc_dinh_dang_ai():
    cac = nhap_cau.doc(DE_AI)
    assert len(cac) == 3
    assert cac[0]["question"] == "Trận Bạch Đằng năm 938 do ai chỉ huy?"
    assert cac[0]["correct_option"] == "A" and cac[0]["option_d"] == "Lý Thường Kiệt"
    assert cac[0]["explanation"].endswith("trên sông Bạch Đằng.")
    assert cac[1]["option_b"] == "Tống" and cac[1]["correct_option"] == "A"
    assert nhap_cau.ly_do_loi(cac[2]) == 'Thiếu dòng "Đáp án: …".'
    assert nhap_cau.ly_do_loi(cac[0]) is None


@pytest.fixture(autouse=True)
def _ma_gv(monkeypatch):
    monkeypatch.setattr(settings, "MA_GIAO_VIEN", "ma-thu-gv")


def _tk(ten="HS"):
    email = f"u{uuid.uuid4().hex[:8]}@test.com"
    client.post("/api/v1/auth/register", json={"email": email, "full_name": ten, "password": MK},
                headers={"X-Client-Id": uuid.uuid4().hex})
    tok = client.post("/api/v1/auth/login", data={"username": email, "password": MK}).json()["access_token"]
    return {"Authorization": f"Bearer {tok}"}


def _gv():
    h = _tk("Cô Lan")
    client.post("/api/v1/auth/lam-giao-vien", json={"ma": "ma-thu-gv"}, headers=h)
    return h


def test_xem_truoc_roi_luu_chi_cau_hop_le():
    gv = _gv()
    xem = client.post("/api/v1/lop/cau-rieng/nhap", json={"van_ban": DE_AI}, headers=gv).json()
    assert (xem["hop_le"], xem["loi"], xem["da_luu"]) == (2, 1, 0)
    assert client.get("/api/v1/lop/cau-rieng", headers=gv).json() == [], "xem trước không được lưu"
    luu = client.post("/api/v1/lop/cau-rieng/nhap", json={"van_ban": DE_AI, "luu": True}, headers=gv).json()
    assert luu["da_luu"] == 2
    assert len(client.get("/api/v1/lop/cau-rieng", headers=gv).json()) == 2


def test_hoc_sinh_khong_nhap_duoc_va_van_ban_rong_bao_ro():
    assert client.post("/api/v1/lop/cau-rieng/nhap", json={"van_ban": DE_AI}, headers=_tk()).status_code == 403
    r = client.post("/api/v1/lop/cau-rieng/nhap", json={"van_ban": "chào cô"}, headers=_gv())
    assert r.status_code == 422 and "Câu 1" in r.text


def _vao(ma, ten):
    r = client.post(f"/api/v1/phong/{ma}/vao", json={"ho_ten": ten, "pin": "1234", "lop": "8A2"},
                    headers={"X-Client-Id": uuid.uuid4().hex})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_bang_vang_bai_tap():
    gv = _gv()
    client.post("/api/v1/lop/cau-rieng/nhap", json={"van_ban": DE_AI, "luu": True}, headers=gv)
    kho = client.get("/api/v1/lop/kho-cau", headers=gv).json()
    ids = [c["id"] for c in kho[0]["cau"]]           # nhóm "câu tự soạn" đứng đầu
    de = client.post("/api/v1/lop/de", json={"tieu_de": "Ôn Bạch Đằng", "cau_ids": ids}, headers=gv).json()
    ma = client.post("/api/v1/lop/phong", json={"de_id": de["id"]}, headers=gv).json()["ma"]

    gioi, kem = _vao(ma, "An Giỏi"), _vao(ma, "Bình")
    for h, dung in ((gioi, True), (kem, False)):
        for c in client.get(f"/api/v1/phong/{ma}/de", headers=h).json()["cau"]:
            client.post(f"/api/v1/phong/{ma}/tra-loi", json={"question_id": c["id"], "chon": "A" if dung else "B"},
                        headers=h)
    assert client.get(f"/api/v1/phong/{ma}/xep-hang", headers=gioi).status_code == 409, "chưa nộp chưa xem"
    for h in (gioi, kem):
        client.post(f"/api/v1/phong/{ma}/nop", headers=h)
    bv = client.get(f"/api/v1/phong/{ma}/xep-hang", headers=kem).json()
    assert [d["ten"] for d in bv["top"]] == ["An Giỏi", "Bình"]
    assert bv["cua_toi"]["hang"] == 2 and bv["top"][1]["la_toi"] and not bv["top"][0]["la_toi"]
    assert bv["tong_hoc_sinh"] == 2 and bv["tieu_de"] == "Ôn Bạch Đằng" and bv["giao_vien"] == "Cô Lan"
    toi = client.get(f"/api/v1/phong/{ma}/xep-hang", headers=gioi).json()["cua_toi"]
    assert toi["hang"] == 1 and toi["diem_10"] == 10 and toi["vuot_pct"] == 100
    assert "user_id" not in str(bv)
    assert all("avatar_url" in d for d in bv["top"]) and "avatar_url" in bv["cua_toi"]
