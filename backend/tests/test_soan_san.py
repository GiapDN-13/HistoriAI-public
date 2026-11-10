"""Câu gợi ý mở đầu cuộc trò chuyện trả bản soạn sẵn, KHÔNG gọi AI."""
import json
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.api.routes import chat as route  # noqa: E402
from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402
from app.services import soan_san  # noqa: E402

seed.run()
client = TestClient(app)
HOI = 'Ý chí "Sát Thát" bắt nguồn từ đâu?'


@pytest.fixture
def kho(tmp_path, monkeypatch):
    tep = tmp_path / "soan.json"
    tep.write_text(json.dumps({"tran-hung-dao": [
        {"hoi": HOI, "dap": "Ta kể con nghe. Quân dân khắc chữ lên tay.", "nguon": ["Đại Việt sử ký toàn thư"]},
        {"hoi": "Câu chưa soạn?", "dap": ""},
    ]}, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(soan_san, "TEP", tep)
    soan_san._kho.cache_clear()
    yield
    soan_san._kho.cache_clear()


@pytest.fixture
def cam_ai(monkeypatch):
    def hong(*a, **k):
        raise AssertionError("không được gọi AI cho câu đã soạn sẵn")
    monkeypatch.setattr(route, "stream_reply", hong)
    monkeypatch.setattr(route, "generate_reply", hong)


def _hoi(cau, lich_su=None, duong="/api/v1/chat/stream"):
    return client.post(duong, json={"figure_slug": "tran-hung-dao", "message": cau,
                                    "history": lich_su or [], "nhan_nguon": True},
                       headers={"X-Client-Id": uuid.uuid4().hex})


def test_cau_goi_y_tra_ban_soan_khong_goi_ai(kho, cam_ai):
    r = _hoi(HOI)
    assert r.status_code == 200
    chu = "".join(d[6:] for d in r.text.split("\n\n") if d.startswith("data: ")
                  and not d.startswith("data: ["))
    assert chu == "Ta kể con nghe. Quân dân khắc chữ lên tay."
    assert '[NGUON]["Đại Việt sử ký toàn thư"]' in r.text
    assert r.text.rstrip().endswith("data: [DONE]")


def test_khong_phan_biet_hoa_thuong_dau_cau_ngoac(kho, cam_ai):
    assert _hoi("ý chí “sát thát” bắt nguồn từ đâu").status_code == 200


def test_chat_thuong_khong_stream_cung_dung_ban_soan(kho, cam_ai, monkeypatch):
    monkeypatch.setattr(route, "synthesize", lambda *a, **k: None)
    r = _hoi(HOI, duong="/api/v1/chat")
    assert r.json()["reply"].startswith("Ta kể con nghe")


def test_giua_cuoc_tro_chuyen_thi_hoi_ai_that(kho, monkeypatch):
    goi = []
    monkeypatch.setattr(route, "stream_reply", lambda *a, **k: goi.append(1) or iter(["AI"]))
    _hoi(HOI, lich_su=[{"role": "user", "content": "chào"}, {"role": "assistant", "content": "chào con"}])
    assert goi, "đã có lịch sử thì phải để AI trả lời nối mạch"


def test_cau_chua_soan_thi_hoi_ai_that(kho, monkeypatch):
    goi = []
    monkeypatch.setattr(route, "stream_reply", lambda *a, **k: goi.append(1) or iter(["AI"]))
    _hoi("Câu chưa soạn?")
    assert goi


def test_cau_hoi_trong_app_khop_tep_du_lieu():
    """Sửa câu gợi ý trong app mà quên sửa tệp dữ liệu thì bản soạn sẵn chết lặng."""
    import pathlib
    dart = (pathlib.Path(__file__).resolve().parents[2] / "mobile/lib/features/chat/chat_screen.dart"
            ).read_text(encoding="utf-8")
    kho = json.loads(soan_san.TEP.read_text(encoding="utf-8"))
    for slug in ("tran-hung-dao", "quang-trung"):
        for m in kho[slug]:
            assert soan_san.chuan_hoa(m["hoi"]) in soan_san.chuan_hoa(dart), m["hoi"]
