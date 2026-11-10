"""Bảng điểm Excel: đúng 3 trang, đúng số liệu, chỉ giáo viên chủ phòng tải được."""
import io
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from openpyxl import load_workbook  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"
DE = "\n\n".join(f"Câu {i}: Câu hỏi số {i} về Bạch Đằng?\nA. Đúng {i}\nB. Sai {i}\nC. Ba {i}\nD. Bốn {i}\nĐáp án: A"
                 for i in range(1, 4))


@pytest.fixture(autouse=True)
def _ma_gv(monkeypatch):
    monkeypatch.setattr(settings, "MA_GIAO_VIEN", "ma-thu-gv")


def _tk(ten):
    email = f"x{uuid.uuid4().hex[:8]}@test.com"
    client.post("/api/v1/auth/register", json={"email": email, "full_name": ten, "password": MK},
                headers={"X-Client-Id": uuid.uuid4().hex})
    return {"Authorization": "Bearer " + client.post("/api/v1/auth/login",
            data={"username": email, "password": MK}).json()["access_token"]}


def test_xuat_excel_ba_trang_dung_so_lieu():
    gv = _tk("Cô Lan")
    client.post("/api/v1/auth/lam-giao-vien", json={"ma": "ma-thu-gv"}, headers=gv)
    client.post("/api/v1/lop/cau-rieng/nhap", json={"van_ban": DE, "luu": True}, headers=gv)
    ids = [c["id"] for c in client.get("/api/v1/lop/kho-cau", headers=gv).json()[0]["cau"]]
    de = client.post("/api/v1/lop/de", json={"tieu_de": "Ôn Bạch Đằng", "cau_ids": ids}, headers=gv).json()
    ma = client.post("/api/v1/lop/phong", json={"de_id": de["id"]}, headers=gv).json()["ma"]
    for ten, dung in (("Nguyễn Văn An", 3), ("Lê Thị Bình", 1)):
        r = client.post(f"/api/v1/phong/{ma}/vao", json={"ho_ten": ten, "pin": "1234", "lop": "7A2"},
                        headers={"X-Client-Id": uuid.uuid4().hex}).json()
        hs = {"Authorization": "Bearer " + r["access_token"]}
        for i, c in enumerate(client.get(f"/api/v1/phong/{ma}/de", headers=hs).json()["cau"]):
            client.post(f"/api/v1/phong/{ma}/tra-loi", json={"question_id": c["id"], "chon": "A" if i < dung else "B"},
                        headers=hs)
        client.post(f"/api/v1/phong/{ma}/nop", headers=hs)

    r = client.get(f"/api/v1/lop/phong/{ma}/xlsx", headers=gv)
    assert r.status_code == 200 and "spreadsheetml" in r.headers["content-type"]
    wb = load_workbook(io.BytesIO(r.content))
    assert wb.sheetnames == ["Bảng điểm", "Từng câu", "Chi tiết"]
    o = [[c.value for c in row] for row in wb["Bảng điểm"].iter_rows()]
    assert "Ôn Bạch Đằng" in o[0][0]
    dong = {row[1]: row for row in o if row[1] in ("Nguyễn Văn An", "Lê Thị Bình")}
    assert dong["Nguyễn Văn An"][3] == 3 and dong["Nguyễn Văn An"][5] == 10
    assert dong["Lê Thị Bình"][3] == 1
    ct = [[c.value for c in row] for row in wb["Chi tiết"].iter_rows()]
    binh = next(row for row in ct if row[0] == "Lê Thị Bình")
    assert binh.count("✓") == 1 and sum(1 for v in binh if isinstance(v, str) and v.startswith("✗")) == 2

    assert client.get(f"/api/v1/lop/phong/{ma}/xlsx", headers=_tk("Người lạ")).status_code == 403
