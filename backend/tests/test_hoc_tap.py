"""Audit tính năng 27/09: quiz cho khách, XP lần đầu, chuỗi ngày học, lịch sử làm bài,
ôn câu sai, thống kê, sửa hồ sơ, đổi mật khẩu, chat nhớ ngữ cảnh."""
import os
import uuid
from datetime import date

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.quiz import QuizQuestion  # noqa: E402
from app.models.user import User  # noqa: E402
from app.schemas.chat import LuotChat  # noqa: E402
from app.services.ai_chat import _tin_nhan  # noqa: E402
from app.services.ngay_hoc import ghi_ngay_hoc, streak_hien_tai  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"


def _tk():
    email = f"hs{uuid.uuid4().hex[:8]}@test.com"
    client.post("/api/v1/auth/register", json={"email": email, "full_name": "Học Sinh", "password": MK},
                headers={"X-Client-Id": uuid.uuid4().hex})
    ma = client.post("/api/v1/auth/login", data={"username": email, "password": MK}).json()["access_token"]
    return email, {"Authorization": f"Bearer {ma}"}


def _cau():
    db = SessionLocal()
    try:
        q = db.query(QuizQuestion).order_by(QuizQuestion.id).first()
        return q.id, q.correct_option.upper(), next(o for o in "ABCD" if o != q.correct_option.upper())
    finally:
        db.close()


# ---------- quiz ----------

def test_khach_cham_duoc_tung_cau():
    qid, dung, _ = _cau()
    r = client.post("/api/v1/quiz/check", json={"question_id": qid, "selected_option": dung})
    assert r.status_code == 200 and r.json()["correct"] is True


def test_chon_sai_hoac_het_gio_van_biet_dap_an_dung():
    # Góp ý 05/10: "chọn đáp án sai không hiện ra đáp án đúng cũng như giải thích".
    qid, dung, sai = _cau()
    for chon in (sai, ""):
        r = client.post("/api/v1/quiz/check", json={"question_id": qid, "selected_option": chon})
        assert r.status_code == 200
        assert r.json()["correct"] is False
        assert r.json()["correct_option"] == dung
        assert "explanation" in r.json()


def test_xp_chi_cong_lan_dau_dung():
    _, h = _tk()
    qid, dung, sai = _cau()
    r1 = client.post("/api/v1/quiz/submit", json=[{"question_id": qid, "selected_option": dung}], headers=h)
    assert r1.json()[0]["xp"] == 10
    xp1 = client.get("/api/v1/auth/me", headers=h).json()["xp"]
    r2 = client.post("/api/v1/quiz/submit", json=[{"question_id": qid, "selected_option": dung}], headers=h)
    assert r2.json()[0]["xp"] == 0, "làm lại câu đã đúng không được cộng XP nữa"
    assert client.get("/api/v1/auth/me", headers=h).json()["xp"] == xp1
    # gửi trùng câu trong một lượt cũng chỉ tính một lần
    r3 = client.post("/api/v1/quiz/submit", json=[{"question_id": qid, "selected_option": sai}] * 3, headers=h)
    assert len(r3.json()) == 1


def test_nop_quiz_bat_dau_chuoi_ngay():
    _, h = _tk()
    assert client.get("/api/v1/auth/me", headers=h).json()["streak"] == 0
    qid, dung, _ = _cau()
    client.post("/api/v1/quiz/submit", json=[{"question_id": qid, "selected_option": dung}], headers=h)
    assert client.get("/api/v1/auth/me", headers=h).json()["streak"] == 1


def test_luat_chuoi_ngay():
    u = User(streak=0, ngay_hoc_cuoi=None)
    assert ghi_ngay_hoc(u, date(2026, 9, 1)) == 1
    assert ghi_ngay_hoc(u, date(2026, 9, 1)) == 1, "cùng ngày giữ nguyên"
    assert ghi_ngay_hoc(u, date(2026, 9, 2)) == 2
    assert streak_hien_tai(u, date(2026, 9, 3)) == 2, "chưa học hôm nay vẫn giữ chuỗi"
    assert streak_hien_tai(u, date(2026, 9, 4)) == 0, "bỏ quá một ngày là đứt"
    assert ghi_ngay_hoc(u, date(2026, 9, 5)) == 1


def test_lich_su_va_on_cau_sai():
    _, h = _tk()
    qid, dung, sai = _cau()
    client.post("/api/v1/quiz/submit", json=[{"question_id": qid, "selected_option": sai}], headers=h)
    ls = client.get("/api/v1/me/lich-su-quiz", headers=h).json()
    assert len(ls) == 1 and ls[0]["dung"] == 0 and ls[0]["tong"] == 1 and ls[0]["event_slug"]
    ct = client.get(f"/api/v1/me/lich-su-quiz/{ls[0]['ma']}", headers=h).json()
    assert ct[0]["selected_option"] == sai and ct[0]["correct_option"].upper() == dung
    cs = client.get("/api/v1/me/cau-sai", headers=h).json()
    assert [c["id"] for c in cs] == [qid]
    assert "correct_option" not in cs[0], "bộ ôn câu sai không được lộ đáp án"
    client.post("/api/v1/quiz/submit", json=[{"question_id": qid, "selected_option": dung}], headers=h)
    assert client.get("/api/v1/me/cau-sai", headers=h).json() == [], "ôn đúng thì câu rời danh sách"
    assert len(client.get("/api/v1/me/lich-su-quiz", headers=h).json()) == 2


def test_lich_su_cua_nguoi_khac_khong_xem_duoc():
    _, h1 = _tk()
    _, h2 = _tk()
    qid, dung, _ = _cau()
    client.post("/api/v1/quiz/submit", json=[{"question_id": qid, "selected_option": dung}], headers=h1)
    ma = client.get("/api/v1/me/lich-su-quiz", headers=h1).json()[0]["ma"]
    assert client.get(f"/api/v1/me/lich-su-quiz/{ma}", headers=h2).status_code == 404


def test_thong_ke():
    _, h = _tk()
    qid, dung, _ = _cau()
    client.post("/api/v1/quiz/submit", json=[{"question_id": qid, "selected_option": dung}], headers=h)
    t = client.get("/api/v1/me/thong-ke", headers=h).json()
    assert t["tong_cau"] == 1 and t["cau_dung"] == 1 and t["ti_le_dung"] == 100
    assert t["so_su_kien_da_hoc"] == 1 and t["hang"] >= 1 and t["ngay_tham_gia"]


# ---------- hồ sơ ----------

def test_sua_ten_va_anh_dai_dien():
    _, h = _tk()
    r = client.patch("/api/v1/auth/me", json={"full_name": "  Nguyễn   Văn  An ", "avatar": "trong-dong"}, headers=h)
    assert r.status_code == 200
    assert r.json()["full_name"] == "Nguyễn Văn An" and r.json()["avatar"] == "trong-dong"
    assert client.patch("/api/v1/auth/me", json={"avatar": "anh-la"}, headers=h).status_code == 422
    assert client.patch("/api/v1/auth/me", json={"full_name": "A"}, headers=h).status_code == 422
    assert client.get("/api/v1/auth/me", headers=h).json()["grade"] is None, "không gửi lớp thì giữ nguyên"


def test_doi_mat_khau_can_mat_khau_cu():
    email, h = _tk()
    sai = client.post("/api/v1/auth/doi-mat-khau", json={"mat_khau_cu": "sai-roi", "mat_khau_moi": "moi123456"}, headers=h)
    assert sai.status_code == 400
    r = client.post("/api/v1/auth/doi-mat-khau", json={"mat_khau_cu": MK, "mat_khau_moi": "moi123456"}, headers=h)
    assert r.status_code == 200
    assert client.get("/api/v1/auth/me", headers=h).status_code == 401, "mã cũ bị thu hồi"
    moi = {"Authorization": f"Bearer {r.json()['access_token']}"}
    assert client.get("/api/v1/auth/me", headers=moi).status_code == 200, "máy này nhận mã mới"
    assert client.post("/api/v1/auth/login", data={"username": email, "password": "moi123456"}).status_code == 200


def test_tai_khoan_google_dat_mat_khau_khong_can_mat_khau_cu():
    email, h = _tk()
    db = SessionLocal()
    u = db.query(User).filter(User.email == email).first()
    u.co_mat_khau, u.google_sub = False, "g-123"
    db.commit()
    db.close()
    me = client.get("/api/v1/auth/me", headers=h).json()
    assert me["co_mat_khau"] is False and me["lien_ket_google"] is True
    r = client.post("/api/v1/auth/doi-mat-khau", json={"mat_khau_moi": "datlan0001"}, headers=h)
    assert r.status_code == 200
    moi = {"Authorization": f"Bearer {r.json()['access_token']}"}
    assert client.get("/api/v1/auth/me", headers=moi).json()["co_mat_khau"] is True


# ---------- chat nhớ ngữ cảnh ----------

class _NV:
    name, slug, period, persona_prompt, knowledge_boundary, verified_facts = (
        "Trần Hưng Đạo", "tran-hung-dao", "Trần", "Ta là Trần Hưng Đạo.", None, None)


def test_chat_gui_kem_luot_cu():
    ls = [LuotChat(role="assistant", content="Chào con."),       # lượt đầu là assistant → bỏ
          LuotChat(role="user", content="Trận Bạch Đằng năm nào?"),
          LuotChat(role="assistant", content="Năm 1288."),
          LuotChat(role="user", content="Còn gì nữa?")]           # user chưa có trả lời → bỏ
    m = _tin_nhan(_NV(), "Vậy sau đó thì sao?", None, ls)
    assert [x["role"] for x in m] == ["system", "user", "assistant", "user"]
    assert m[1]["content"] == "Trận Bạch Đằng năm nào?" and m[-1]["content"] == "Vậy sau đó thì sao?"


def test_chat_chi_nho_8_luot_cuoi():
    ls = [LuotChat(role="user" if i % 2 == 0 else "assistant", content=f"c{i}") for i in range(30)]
    m = _tin_nhan(_NV(), "mới", None, ls)
    assert len(m) == 1 + 8 + 1


def test_thoi_gian_co_mui_gio_va_ngay_theo_gio_vn():
    from datetime import datetime
    from app.services.ngay_hoc import iso_utc, ngay_vn
    assert iso_utc(datetime(2026, 9, 27, 13, 23)) == "2026-09-27T13:23:00+00:00"
    assert ngay_vn(datetime(2026, 9, 27, 23, 30)) == "2026-09-28", "6 giờ 30 sáng VN là ngày 28"
    _, h = _tk()
    qid, dung, _ = _cau()
    client.post("/api/v1/quiz/submit", json=[{"question_id": qid, "selected_option": dung}], headers=h)
    luc = client.get("/api/v1/me/lich-su-quiz", headers=h).json()[0]["luc"]
    assert luc.endswith("+00:00"), luc
