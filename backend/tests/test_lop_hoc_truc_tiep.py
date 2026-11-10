"""Chế độ TRỰC TIẾP (giai đoạn 2): sảnh chờ → giáo viên chuyển từng câu → lộ đáp án + TOP 5
→ bảng xếp hạng chung cuộc. Chặn hồi quy chỗ quan trọng nhất: KHÔNG lộ đáp án xuống máy
học sinh trước khi giáo viên kết thúc câu."""
import json
import os
import uuid
from datetime import timedelta

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from starlette.websockets import WebSocketDisconnect  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.lop_hoc import PhongThi  # noqa: E402
from app.models.quiz import QuizQuestion  # noqa: E402
from app.models.quiz_attempt import QuizAttempt  # noqa: E402
from app.services import phong_truc_tiep as tt  # noqa: E402

seed.run()
MK = "12345678"


@pytest.fixture(scope="module")
def c():
    # Một vòng lặp sự kiện cho cả tệp: kết nối WebSocket và route REST dùng chung bộ nhớ phòng.
    with TestClient(app) as kh:
        yield kh


@pytest.fixture(autouse=True)
def _ma_gv(monkeypatch):
    monkeypatch.setattr(settings, "MA_GIAO_VIEN", "ma-thu-gv")


def _gv(c):
    email = f"gv{uuid.uuid4().hex[:8]}@test.com"
    c.post("/api/v1/auth/register", json={"email": email, "full_name": "Thầy Hùng", "password": MK},
           headers={"X-Client-Id": uuid.uuid4().hex})
    ma = c.post("/api/v1/auth/login", data={"username": email, "password": MK}).json()["access_token"]
    h = {"Authorization": f"Bearer {ma}"}
    assert c.post("/api/v1/auth/lam-giao-vien", json={"ma": "ma-thu-gv"}, headers=h).status_code == 200
    return h, ma


def _mo(c, h, so_cau=2):
    kho = c.get("/api/v1/lop/kho-cau", headers=h).json()
    ids = [q["id"] for q in kho[0]["cau"][:so_cau]]
    de = c.post("/api/v1/lop/de", json={"tieu_de": "Đấu trường Bạch Đằng", "cau_ids": ids, "giay_moi_cau": 20},
                headers=h).json()
    p = c.post("/api/v1/lop/phong", json={"de_id": de["id"], "che_do": "truc_tiep"}, headers=h)
    assert p.status_code == 201, p.text
    assert p.json()["che_do"] == "truc_tiep" and p.json()["pha"] == "cho"
    return p.json()["ma"], ids


def _vao(c, ma, ten):
    r = c.post(f"/api/v1/phong/{ma}/vao", json={"ho_ten": ten, "pin": "1234"},
               headers={"X-Client-Id": uuid.uuid4().hex})
    assert r.status_code == 200, r.text
    tok = r.json()["access_token"]
    return {"Authorization": f"Bearer {tok}"}, tok


def _dap_an(ids):
    db = SessionLocal()
    try:
        return {q.id: q.correct_option.upper() for q in db.query(QuizQuestion).filter(QuizQuestion.id.in_(ids))}
    finally:
        db.close()


def _cho(ws, dk, toi_da=20):
    """Đọc gói tin tới khi gặp gói thoả `dk` (bỏ qua các gói cập nhật trung gian)."""
    for _ in range(toi_da):
        tin = ws.receive_json()
        if dk(tin):
            return tin
    raise AssertionError("không nhận được gói tin mong đợi")


def _noi(c, ma, tok):
    ws = c.websocket_connect(f"/api/v1/ws/phong/{ma}")
    w = ws.__enter__()
    w.send_json({"loai": "xac_thuc", "token": tok})
    return ws, w


def _lenh(c, h, ma, lenh, tu_cau=None):
    r = c.post(f"/api/v1/lop/phong/{ma}/truc-tiep", json={"lenh": lenh, "tu_cau": tu_cau}, headers=h)
    assert r.status_code == 200, r.text
    return r.json()


# ---------------------------------------------------------------- công thức điểm

def test_diem_toc_do_dung_nhanh_nhieu_diem_hon():
    assert tt.diem_toc_do(True, 0, 20) == 1000
    assert tt.diem_toc_do(True, 10_000, 20) == 750
    assert tt.diem_toc_do(True, 20_000, 20) == 500
    assert tt.diem_toc_do(True, 99_000, 20) == 500, "trễ quá giờ vẫn kẹp ở mức sàn"
    assert tt.diem_toc_do(False, 0, 20) == 0


# ---------------------------------------------------------------- trọn trận qua WebSocket

def test_tron_tran_truc_tiep_qua_websocket(c):
    gv, gv_tok = _gv(c)
    ma, ids = _mo(c, gv)
    da = _dap_an(ids)
    (h_an, t_an), (h_binh, t_binh) = _vao(c, ma, "Nguyễn An"), _vao(c, ma, "Trần Bình")
    info = c.get(f"/api/v1/phong/{ma}").json()
    assert info["che_do"] == "truc_tiep"

    cm_gv, w_gv = _noi(c, ma, gv_tok)
    cm_an, w_an = _noi(c, ma, t_an)
    cm_binh, w_binh = _noi(c, ma, t_binh)
    try:
        dau = _cho(w_gv, lambda t: t.get("loai") == "trang_thai")
        assert dau["vai"] == "gv" and dau["pha"] == "cho"
        sanh = _cho(w_gv, lambda t: t.get("loai") == "trang_thai" and len(t.get("dang_noi", [])) == 2)
        assert {h["ten"] for h in sanh["hoc_sinh"]} == {"Nguyễn An", "Trần Bình"}
        assert _cho(w_an, lambda t: t.get("loai") == "trang_thai")["pha"] == "cho"
        _cho(w_binh, lambda t: t.get("loai") == "trang_thai")

        # --- câu 1 hiện đồng thời trên máy mọi em, KHÔNG kèm đáp án
        w_gv.send_json({"loai": "dieu_khien", "lenh": "bat_dau"})
        c1_an = _cho(w_an, lambda t: t.get("pha") == "dang_hoi")
        c1_binh = _cho(w_binh, lambda t: t.get("pha") == "dang_hoi")
        for t in (c1_an, c1_binh):
            assert t["cau_so"] == 0 and t["cau"]["id"] == ids[0] and 0 < t["con_lai_ms"] <= 20_000
            s = json.dumps(t)
            assert "dap_an" not in t and "phan_bo" not in t and "correct" not in s and "giai_thich" not in s
            assert t["cua_toi"]["da_chon"] is None and "dung" not in t["cua_toi"]
        _cho(w_gv, lambda t: t.get("pha") == "dang_hoi")

        # --- An đúng, Bình sai; máy em chỉ nhận "đã nhận", chưa biết đúng sai
        sai = next(o for o in "ABCD" if o != da[ids[0]])
        w_an.send_json({"loai": "tra_loi", "cau_so": 0, "chon": da[ids[0]]})
        nhan = _cho(w_an, lambda t: t.get("loai") == "da_nhan")
        assert nhan == {"loai": "da_nhan", "cau_so": 0, "chon": da[ids[0]]}
        dem = _cho(w_gv, lambda t: t.get("so_da_tra_loi") == 1)
        assert dem["pha"] == "dang_hoi" and "dap_an" not in dem, "máy chiếu cũng chưa được hiện đáp án"
        w_binh.send_json({"loai": "tra_loi", "cau_so": 0, "chon": sai})

        # --- cả lớp đã trả lời → tự lộ đáp án, khỏi chờ hết giờ
        lo_an = _cho(w_an, lambda t: t.get("pha") == "lo_dap_an")
        lo_binh = _cho(w_binh, lambda t: t.get("pha") == "lo_dap_an")
        assert lo_an["dap_an"] == da[ids[0]] and lo_an["phan_bo"][da[ids[0]]] == 1 and lo_an["phan_bo"][sai] == 1
        assert lo_an["cua_toi"]["dung"] is True and lo_an["cua_toi"]["hang"] == 1
        assert 900 < lo_an["cua_toi"]["diem_cau"] <= 1000, "trả lời gần như tức thì → gần 1000 điểm"
        assert lo_binh["cua_toi"]["dung"] is False and lo_binh["cua_toi"]["diem_cau"] == 0
        assert lo_binh["cua_toi"]["hang"] == 2
        assert [x["ten"] for x in lo_an["top"]] == ["Nguyễn An", "Trần Bình"]
        _cho(w_gv, lambda t: t.get("pha") == "lo_dap_an")

        # --- bấm đúp "Câu tiếp" chỉ chuyển MỘT câu
        _lenh(c, gv, ma, "cau_tiep", tu_cau=0)
        assert _lenh(c, gv, ma, "cau_tiep", tu_cau=0)["cau_so"] == 1
        c2 = _cho(w_binh, lambda t: t.get("pha") == "dang_hoi" and t.get("cau_so") == 1)
        assert "dap_an" not in c2

        # --- Bình mất mạng rồi vào lại → bắt kịp đúng câu 2
        w_binh.send_json({"loai": "tra_loi", "cau_so": 1, "chon": da[ids[1]]})
        _cho(w_binh, lambda t: t.get("loai") == "da_nhan")
        cm_binh.__exit__(None, None, None)
        cm_binh, w_binh = _noi(c, ma, t_binh)
        lai = _cho(w_binh, lambda t: t.get("loai") == "trang_thai")
        assert lai["pha"] == "dang_hoi" and lai["cau_so"] == 1 and lai["cua_toi"]["da_chon"] == da[ids[1]]

        # --- An không kịp trả lời; giáo viên kết thúc câu rồi sang câu cuối → chung cuộc
        _lenh(c, gv, ma, "ket_thuc_cau", tu_cau=1)
        lo2 = _cho(w_an, lambda t: t.get("pha") == "lo_dap_an" and t.get("cau_so") == 1)
        assert lo2["cua_toi"]["da_chon"] is None and lo2["cua_toi"]["diem_cau"] == 0
        _lenh(c, gv, ma, "cau_tiep", tu_cau=1)
        het = _cho(w_gv, lambda t: t.get("pha") == "ket_thuc")
        assert [h["ten"] for h in het["bang_xep_hang"]] == ["Trần Bình", "Nguyễn An"] or \
               [h["hang"] for h in het["bang_xep_hang"]] == [1, 2]
        het_an = _cho(w_an, lambda t: t.get("pha") == "ket_thuc")
        assert het_an["cua_toi"]["so_dung"] == 1 and "bang_xep_hang" not in het_an, \
            "học sinh chỉ thấy TOP 5 + hạng mình, không thấy cả bảng điểm lớp"
    finally:
        for cm in (cm_gv, cm_an, cm_binh):
            cm.__exit__(None, None, None)

    # --- bài trực tiếp vào lịch sử học như giai đoạn 1
    db = SessionLocal()
    try:
        p = db.query(PhongThi).filter(PhongThi.ma == ma).first()
        assert p.pha == "ket_thuc" and p.dang_mo is False
        assert db.query(QuizAttempt).filter(QuizAttempt.lan_nop == f"phong-{ma}").count() == 3
    finally:
        db.close()
    assert ids[0] in [q["id"] for q in c.get("/api/v1/me/cau-sai", headers=h_binh).json()]
    xem_lai = c.post(f"/api/v1/phong/{ma}/nop", headers=h_an)
    assert xem_lai.status_code == 200 and xem_lai.json()["so_dung"] == 1, "hết trận xem lại được đáp án"
    bang = c.get(f"/api/v1/lop/phong/{ma}/bang", headers=gv).json()
    assert bang["phong"]["so_nop"] == 2
    assert "Nguyễn An,,1,2,5.0,có" in c.get(f"/api/v1/lop/phong/{ma}/csv", headers=gv).text


# ---------------------------------------------------------------- dự phòng hỏi định kỳ + khôi phục

def test_hoi_dinh_ky_va_khoi_phuc_sau_khi_may_chu_khoi_dong_lai(c):
    gv, _ = _gv(c)
    ma, ids = _mo(c, gv)
    hs, _ = _vao(c, ma, "Lê Cường")
    _vao(c, ma, "Phạm Dung")
    tt_hs = c.get(f"/api/v1/phong/{ma}/truc-tiep", headers=hs).json()
    assert tt_hs["vai"] == "hs" and tt_hs["pha"] == "cho" and "hoc_sinh" not in tt_hs

    _lenh(c, gv, ma, "bat_dau")
    q = c.get(f"/api/v1/phong/{ma}/truc-tiep", headers=hs).json()
    assert q["pha"] == "dang_hoi" and "dap_an" not in q and "correct" not in json.dumps(q)
    r = c.post(f"/api/v1/phong/{ma}/truc-tiep/tra-loi", json={"cau_so": 0, "chon": "A"}, headers=hs)
    assert r.status_code == 200 and "dung" not in r.json()
    assert c.post(f"/api/v1/phong/{ma}/truc-tiep/tra-loi", json={"cau_so": 1, "chon": "A"},
                  headers=hs).status_code == 409, "chưa tới câu 2"

    # Máy chủ khởi động lại (mất sạch bộ nhớ) trong lúc câu 1 đã quá giờ
    tt.quan_ly._phong.clear()
    db = SessionLocal()
    try:
        p = db.query(PhongThi).filter(PhongThi.ma == ma).first()
        p.cau_bat_dau_luc = p.cau_bat_dau_luc - timedelta(seconds=60)
        db.commit()
    finally:
        db.close()
    sau = c.get(f"/api/v1/phong/{ma}/truc-tiep", headers=hs).json()
    assert sau["pha"] == "lo_dap_an" and sau["cau_so"] == 0 and sau["cua_toi"]["da_chon"] == "A"
    assert "dap_an" in sau
    tre = c.post(f"/api/v1/phong/{ma}/truc-tiep/tra-loi", json={"cau_so": 0, "chon": "B"}, headers=_vao(c, ma, "Phạm Dung")[0])
    assert tre.status_code == 409


def test_het_gio_thi_khong_nhan_tra_loi(c):
    gv, _ = _gv(c)
    ma, _ = _mo(c, gv)
    _vao(c, ma, "Võ Em")
    _lenh(c, gv, ma, "bat_dau")
    db = SessionLocal()
    try:
        p = db.query(PhongThi).filter(PhongThi.ma == ma).first()
        uid = db.query(tt.BaiThi).filter(tt.BaiThi.phong_id == p.id).first().user_id
        muon = tt._aware(p.cau_bat_dau_luc) + timedelta(seconds=20 + tt.GIAY_CHO_TRE + 0.1)
        kip = tt._aware(p.cau_bat_dau_luc) + timedelta(seconds=20.5)
        with pytest.raises(tt.LoiTrucTiep):
            tt.tra_loi(db, ma, uid, 0, "A", bay_gio=muon)
        assert tt.tra_loi(db, ma, uid, 0, "A", bay_gio=kip)["so_da_tra_loi"] == 1, \
            "bấm ở giây cuối, gói tin tới trễ nửa giây vẫn được tính"
    finally:
        db.close()


# ---------------------------------------------------------------- phân quyền

def test_phan_quyen_va_chan_duong_bai_tap(c):
    gv, gv_tok = _gv(c)
    ma, _ = _mo(c, gv)
    hs, t_hs = _vao(c, ma, "Đỗ Giang")

    # Đường bài tập (giai đoạn 1) không được dùng để xem trước / trả lời trước cả đề
    assert c.get(f"/api/v1/phong/{ma}/de", headers=hs).status_code == 409
    assert c.post(f"/api/v1/phong/{ma}/tra-loi", json={"question_id": 1, "chon": "A"}, headers=hs).status_code == 409
    assert c.post(f"/api/v1/phong/{ma}/nop", headers=hs).status_code == 409

    # Học sinh không điều khiển được; giáo viên phòng khác cũng không
    assert c.post(f"/api/v1/lop/phong/{ma}/truc-tiep", json={"lenh": "bat_dau"}, headers=hs).status_code == 404
    gv2, gv2_tok = _gv(c)
    assert c.post(f"/api/v1/lop/phong/{ma}/truc-tiep", json={"lenh": "bat_dau"}, headers=gv2).status_code == 403
    assert c.get(f"/api/v1/phong/{ma}/truc-tiep").status_code == 401

    for tok, ma_dong in ((None, 4401), ("sai-ma", 4401), (gv2_tok, 4403)):
        with c.websocket_connect(f"/api/v1/ws/phong/{ma}") as w:
            w.send_json({"loai": "xac_thuc", "token": tok})
            with pytest.raises(WebSocketDisconnect) as loi:
                for _ in range(3):
                    w.receive_json()
            assert loi.value.code == ma_dong
    with c.websocket_connect("/api/v1/ws/phong/000000") as w:
        w.send_json({"loai": "xac_thuc", "token": t_hs})
        with pytest.raises(WebSocketDisconnect) as loi:
            for _ in range(3):
                w.receive_json()
        assert loi.value.code in (4403, 4404)

    # Học sinh gửi lệnh điều khiển qua WebSocket → bị từ chối, trạng thái không đổi
    with c.websocket_connect(f"/api/v1/ws/phong/{ma}") as w:
        w.send_json({"loai": "xac_thuc", "token": t_hs})
        _cho(w, lambda t: t.get("loai") == "trang_thai")
        w.send_json({"loai": "dieu_khien", "lenh": "bat_dau"})
        assert _cho(w, lambda t: t.get("loai") == "loi")
    assert c.get(f"/api/v1/phong/{ma}/truc-tiep", headers=hs).json()["pha"] == "cho"


def test_ket_thuc_som_va_dong_phong_giua_tran(c):
    gv, _ = _gv(c)
    ma, _ = _mo(c, gv, so_cau=3)
    hs, _ = _vao(c, ma, "Bùi Hà")
    _lenh(c, gv, ma, "bat_dau")
    c.post(f"/api/v1/phong/{ma}/truc-tiep/tra-loi", json={"cau_so": 0, "chon": "A"}, headers=hs)
    # Đóng bằng nút của giai đoạn 1 → lần đọc sau coi như hết trận, bài vẫn được nộp
    assert c.post(f"/api/v1/lop/phong/{ma}/dong", headers=gv).status_code == 200
    het = c.get(f"/api/v1/phong/{ma}/truc-tiep", headers=hs).json()
    assert het["pha"] == "ket_thuc" and het["cua_toi"]["tong_diem"] >= 0
    assert c.post(f"/api/v1/phong/{ma}/nop", headers=hs).json()["bai"]["da_nop"] is True


def test_phong_bai_tap_khong_dung_duong_truc_tiep(c):
    gv, _ = _gv(c)
    kho = c.get("/api/v1/lop/kho-cau", headers=gv).json()
    de = c.post("/api/v1/lop/de", json={"tieu_de": "Bài tập", "cau_ids": [kho[0]["cau"][0]["id"]]}, headers=gv).json()
    p = c.post("/api/v1/lop/phong", json={"de_id": de["id"]}, headers=gv).json()
    assert p["che_do"] == "bai_tap" and p["pha"] is None
    assert c.get(f"/api/v1/phong/{p['ma']}/truc-tiep", headers=gv).status_code == 404


def test_gop_gd2_gd3_thi_truc_tiep_bang_cau_tu_soan(c):
    """Chỗ giao nhau của hai giai đoạn: câu RIÊNG của giáo viên (id âm) chơi được ở chế độ
    trực tiếp, và không lọt vào lịch sử làm bài / XP của học sinh."""
    h, _ = _gv(c)
    r = c.post("/api/v1/lop/cau-rieng", headers=h, json={
        "question": "Câu tự soạn: trận Bạch Đằng năm 938 do ai chỉ huy?",
        "option_a": "Lý Thường Kiệt", "option_b": "Ngô Quyền", "option_c": "Lê Lợi", "option_d": "Quang Trung",
        "correct_option": "B", "explanation": "Ngô Quyền đánh quân Nam Hán năm 938."})
    assert r.status_code in (200, 201), r.text
    rieng = next(q for q in c.get("/api/v1/lop/kho-cau", headers=h).json()[0]["cau"] if q["id"] < 0)
    de = c.post("/api/v1/lop/de", headers=h, json={"tieu_de": "Trực tiếp câu riêng", "cau_ids": [rieng["id"]],
                                                  "giay_moi_cau": 20}).json()
    ma = c.post("/api/v1/lop/phong", headers=h, json={"de_id": de["id"], "che_do": "truc_tiep"}).json()["ma"]
    hs, _ = _vao(c, ma, "Em Kiểm Thử")

    assert c.post(f"/api/v1/lop/phong/{ma}/truc-tiep", headers=h, json={"lenh": "bat_dau"}).status_code == 200
    anh = c.get(f"/api/v1/phong/{ma}/truc-tiep", headers=hs).json()
    assert "Câu tự soạn: trận Bạch Đằng" in json.dumps(anh, ensure_ascii=False)
    assert "Ngô Quyền đánh quân Nam Hán" not in json.dumps(anh, ensure_ascii=False), "chưa lộ giải thích"
    assert c.post(f"/api/v1/phong/{ma}/truc-tiep/tra-loi", headers=hs,
                  json={"cau_so": 0, "chon": "B"}).status_code == 200
    assert c.post(f"/api/v1/lop/phong/{ma}/truc-tiep", headers=h, json={"lenh": "ket_thuc"}).status_code == 200

    bang = c.get(f"/api/v1/lop/phong/{ma}/bang", headers=h).json()
    assert bang["hoc_sinh"][0]["so_dung"] == 1
    me = c.get("/api/v1/auth/me", headers=hs).json()
    db = SessionLocal()
    try:
        assert db.query(QuizAttempt).filter(QuizAttempt.user_id == me["id"]).count() == 0, \
            "câu riêng không vào lịch sử làm bài chung"
    finally:
        db.close()
    assert me["xp"] == 0, "câu riêng không cộng XP"
