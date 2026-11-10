"""Giọng đọc có sổ đếm riêng, không ăn vào lượt hỏi chat.

Lỗi thật 28/09: app xin giọng cho từng câu của câu trả lời, mà /speak/stream dùng
chung 8 lượt/phút với /chat. Câu trả lời 8 câu → từ câu thứ 9 bị 429 → app đọc bằng
giọng trình duyệt ("vĩ nhân đổi giọng giữa chừng"), và câu hỏi kế tiếp cũng bị chặn.
"""
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402
from app.services import gioi_han as G  # noqa: E402

seed.run()
client = TestClient(app)


def _giong(may, i):
    return client.post("/api/v1/chat/speak/stream",
                       json={"figure_slug": "tran-hung-dao", "text": f"Câu thứ {i} của câu trả lời."},
                       headers={"X-Client-Id": may})


def test_cau_tra_loi_dai_khong_bi_chan_giua_chung():
    may = uuid.uuid4().hex
    ma = [_giong(may, i).status_code for i in range(30)]
    assert 429 not in ma, f"câu giọng bị chặn ở lượt {ma.index(429) + 1}"


def test_doc_giong_khong_an_vao_luot_hoi_chat():
    may = uuid.uuid4().hex
    for i in range(30):
        _giong(may, i)
    # Vẫn còn nguyên lượt hỏi của phút này.
    for _ in range(G.MAY_PHUT.so_luot):
        G.bo_gioi_han.xin_luot(may, "9.9.9.9", "2026-09-28")


def test_giong_van_co_tran_chong_spam():
    may = uuid.uuid4().hex
    ma = [_giong(may, i).status_code for i in range(G.GIONG_MAY_PHUT.so_luot + 3)]
    assert ma[-1] == 429


def test_giong_khong_tinh_vao_tran_llm_moi_ngay():
    truoc = G.bo_gioi_han.da_dung_hom_nay
    _giong(uuid.uuid4().hex, 0)
    assert G.bo_gioi_han.da_dung_hom_nay == truoc
