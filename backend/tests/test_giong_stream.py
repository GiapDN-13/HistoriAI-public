"""Phát giọng theo luồng: đọc đuổi tệp đang ghi, dự phòng khi VieNeu hỏng, và lưu đệm."""
import os
import threading
import time
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402
from app.services import giong_stream as gs  # noqa: E402
from app.services import tts  # noqa: E402

seed.run()
client = TestClient(app)


@pytest.fixture(autouse=True)
def _vieneu(monkeypatch):
    monkeypatch.setattr(settings, "TTS_PROVIDER", "vieneu")
    monkeypatch.setattr(gs, "_phien", gs.OrderedDict())
    yield


def _cau():
    return f"Câu thử {uuid.uuid4().hex[:8]}."


def test_doc_duoi_tep_dang_ghi_nhan_du_va_dung_thu_tu(monkeypatch):
    manh = [b"ID3-dau-", b"giua-", b"cuoi"]

    def gia(p):
        part = gs.tep_dang_ghi(p.ma)
        with open(part, "wb") as f:
            for m in manh:
                f.write(m)
                f.flush()
                time.sleep(0.15)          # đang ghi dở thì người đọc đã bắt đầu đọc
        return True                       # đổi tên .part → .mp3 là việc của _chay

    monkeypatch.setattr(gs, "_tao_vieneu", gia)
    ma = gs.bat_dau("tran-hung-dao", _cau())
    t0 = time.time()
    luong = gs.doc(ma)
    dau = next(luong)
    assert time.time() - t0 < 0.5, "phải có byte đầu ngay, không đợi tạo xong cả câu"
    assert dau + b"".join(luong) == b"".join(manh)
    assert gs.trang_thai(ma).xong.wait(3), "phiên phải kết thúc sau khi người đọc đóng tệp"
    assert gs.tep_xong(ma).exists() and not gs.tep_dang_ghi(ma).exists()


def test_cung_cau_lan_sau_phat_tu_tep(monkeypatch):
    goi = []

    def gia(p):
        goi.append(1)
        gs.tep_xong(p.ma).write_bytes(b"mp3")
        return True

    monkeypatch.setattr(gs, "_tao_vieneu", gia)
    cau = _cau()
    ma1 = gs.bat_dau("quang-trung", cau)
    gs.trang_thai(ma1).xong.wait(2)
    monkeypatch.setattr(gs, "_phien", gs.OrderedDict())     # như khởi động lại backend
    ma2 = gs.bat_dau("quang-trung", cau)
    assert ma1 == ma2 and len(goi) == 1
    assert gs.trang_thai(ma2).nguon == "cache"


def test_vieneu_hong_thi_dung_giong_du_phong(monkeypatch):
    monkeypatch.setattr(gs, "_tao_vieneu", lambda p: False)

    def du_phong(text, voice):
        ten = f"dp-{uuid.uuid4().hex[:6]}.mp3"
        (tts._CACHE_DIR / ten).write_bytes(b"giong-edge")
        return ten

    monkeypatch.setattr(tts, "synth_du_phong", du_phong)
    ma = gs.bat_dau("tran-hung-dao", _cau())
    assert b"".join(gs.doc(ma)) == b"giong-edge"
    assert gs.trang_thai(ma).nguon == "du_phong"


def test_route_tra_duong_dan_va_phat_duoc(monkeypatch):
    monkeypatch.setattr(gs, "_tao_vieneu",
                        lambda p: gs.tep_xong(p.ma).write_bytes(b"am-thanh") or True)
    r = client.post("/api/v1/chat/speak/stream",
                    json={"figure_slug": "tran-hung-dao", "text": _cau()})
    assert r.status_code == 200
    url = r.json()["audio_url"]
    assert "/chat/audio/stream/" in url and url.endswith(".mp3")
    g = client.get(url[url.index("/api/v1"):])
    assert g.status_code == 200 and g.content == b"am-thanh"
    assert g.headers["cache-control"] == "no-store"


def test_ca_hai_nguon_hong_thi_503_de_app_doc_bang_trinh_duyet(monkeypatch):
    monkeypatch.setattr(gs, "_tao_vieneu", lambda p: False)
    monkeypatch.setattr(tts, "synth_du_phong", lambda text, voice: None)
    r = client.post("/api/v1/chat/speak/stream",
                    json={"figure_slug": "tran-hung-dao", "text": _cau()})
    url = r.json()["audio_url"]
    assert client.get(url[url.index("/api/v1"):]).status_code == 503


def test_ma_la_hay_ky_tu_la_bi_tu_choi():
    assert client.get("/api/v1/chat/audio/stream/khongtontai123.mp3").status_code == 404
    assert client.get("/api/v1/chat/audio/stream/..%2F..%2Fetc.mp3").status_code == 404


def test_hai_nguoi_cung_hoi_mot_cau_chi_tao_mot_lan(monkeypatch):
    goi = []
    xong = threading.Event()

    def gia(p):
        goi.append(1)
        xong.wait(1)
        gs.tep_xong(p.ma).write_bytes(b"x")
        return True

    monkeypatch.setattr(gs, "_tao_vieneu", gia)
    cau = _cau()
    a = gs.bat_dau("quang-trung", cau)
    b = gs.bat_dau("quang-trung", cau)
    xong.set()
    gs.trang_thai(a).xong.wait(2)
    assert a == b and len(goi) == 1


# ---------- 27/09: không đổi giọng giữa chừng ----------

def test_vieneu_ban_thi_cho_roi_thu_lai_chu_khong_doi_giong(monkeypatch):
    """Trước đây 503 là rơi ngay sang Edge (giọng mặc định) từ câu thứ ba trở đi."""
    lan = []

    def mot_lan(p):
        lan.append(1)
        if len(lan) < 3:
            return 503
        gs.tep_dang_ghi(p.ma).write_bytes(b"giong-nhan-vat")
        return 200

    monkeypatch.setattr(gs, "_stream_mot_lan", mot_lan)
    monkeypatch.setattr(tts, "synth_du_phong", lambda t, v: pytest.fail("không được dùng dự phòng"))
    ma = gs.bat_dau("tran-hung-dao", _cau())
    assert b"".join(gs.doc(ma)) == b"giong-nhan-vat"
    assert gs.trang_thai(ma).nguon == "vieneu" and len(lan) == 3


def test_nhieu_cau_cung_luc_deu_ra_giong_nhan_vat_theo_thu_tu(monkeypatch):
    dang_chay, thu_tu = [], []

    def mot_lan(p):
        dang_chay.append(1)
        assert len(dang_chay) == 1, "VieNeu chỉ được nhận một câu một lúc"
        time.sleep(0.05)
        thu_tu.append(p.text)
        gs.tep_dang_ghi(p.ma).write_bytes(p.text.encode())
        dang_chay.pop()
        return 200

    monkeypatch.setattr(gs, "_stream_mot_lan", mot_lan)
    cau = [_cau() for _ in range(5)]
    ma = []
    for c in cau:
        ma.append(gs.bat_dau("quang-trung", c))
        time.sleep(0.01)
    for m in ma:
        assert gs.trang_thai(m).xong.wait(5)
        assert gs.trang_thai(m).nguon == "vieneu"
    assert thu_tu == [tts.clean_for_speech(c) for c in cau], "câu xin trước tạo trước"


def test_giong_du_phong_khong_luu_de_ten_chinh(monkeypatch):
    """Bản Edge không được nằm ở <mã>.mp3 — nếu không, câu đó mãi mãi giọng mặc định."""
    monkeypatch.setattr(gs, "_stream_mot_lan", lambda p: 500)

    def du_phong(text, voice):
        ten = f"dp-{uuid.uuid4().hex[:6]}.mp3"
        (tts._CACHE_DIR / ten).write_bytes(b"giong-edge")
        return ten

    monkeypatch.setattr(tts, "synth_du_phong", du_phong)
    cau = _cau()
    ma = gs.bat_dau("tran-hung-dao", cau)
    assert b"".join(gs.doc(ma)) == b"giong-edge"
    assert not gs.tep_xong(ma).exists()
    # Hết hạn phiên dự phòng → lần sau thử VieNeu lại, lần này VieNeu chạy được
    gs.trang_thai(ma).tao_luc -= gs.PHIEN_DU_PHONG_S + 1

    def ok(p):
        gs.tep_dang_ghi(p.ma).write_bytes(b"giong-nhan-vat")
        return 200

    monkeypatch.setattr(gs, "_stream_mot_lan", ok)
    ma2 = gs.bat_dau("tran-hung-dao", cau)
    assert ma2 == ma and b"".join(gs.doc(ma2)) == b"giong-nhan-vat"
