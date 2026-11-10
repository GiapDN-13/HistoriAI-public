"""Nạp dữ liệu làm giàu (data_pipeline/) — những điều không được phép hỏng.

Quan trọng nhất: đường ống KHÔNG được ghi đè nội dung nhóm viết tay. Tiêu đề,
năm, tóm tắt của sự kiện có sẵn phải giữ nguyên; nội dung mới chỉ vào cột mới.
"""
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine, inspect, text  # noqa: E402

from app.db import migrate_nhe, seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.event import HistoricalEvent  # noqa: E402
from app.models.figure import HistoricalFigure  # noqa: E402
from app.models.quiz import QuizQuestion  # noqa: E402
from app.services.ai_chat import _build_system_prompt  # noqa: E402

seed.run()
client = TestClient(app)

SLUG_MOI = "tran-chi-lang-thu-nghiem"


def _du_lieu():
    return {
        "events": [
            {"slug": "bach-dang-938", "moi": False,
             "summary_thcs": "Bản THCS thử", "summary_thpt": "Bản THPT thử",
             "grades": "6,11", "curriculum": [{"ma": "THCS-6-04", "cap": "THCS", "lop": 6, "chu_de": "X"}],
             "sources": [{"ten": "Wikipedia", "url": "https://vi.wikipedia.org/wiki/X", "giay_phep": "CC BY-SA 4.0"}]},
            {"slug": SLUG_MOI, "moi": True, "title": "Trận thử nghiệm", "year": 1427,
             "period": "Lê sơ", "era": "phong-kien", "features": "timeline,quiz",
             "summary_thcs": "Tóm tắt THCS", "summary_thpt": "Tóm tắt THPT",
             "grades": "7", "curriculum": [], "sources": [], "thumbnail_url": None},
        ],
        "quiz": [
            {"event_slug": SLUG_MOI, "question": "Câu hỏi thử nghiệm làm giàu?",
             "option_a": "A1", "option_b": "B1", "option_c": "C1", "option_d": "D1",
             "correct_option": "C", "explanation": "vì thế", "difficulty": 2,
             "curriculum_ref": "Trình bày được…", "grade_min": 7,
             "source_claims": [{"noi_dung": "n", "trich_dan": "t", "url": "u"}]},
        ],
        "figures": [{"slug": "tran-hung-dao", "verified_facts": "SỬ LIỆU ĐÃ KIỂM CHỨNG:\n- dữ kiện thử",
                     "sources": [{"ten": "Wikipedia"}]}],
        "artifacts": [{"slug": "trong-dong-dong-son", "sources": [{"ten": "Wikipedia"}]}],
    }


def test_su_kien_co_san_giu_nguyen_noi_dung_nhom_viet():
    db = SessionLocal()
    try:
        cu = db.query(HistoricalEvent).filter_by(slug="bach-dang-938").one()
        tieu_de, nam, tom_tat = cu.title, cu.year, cu.summary
        seed._nap_lam_giau(db, _du_lieu())
        db.refresh(cu)
        assert (cu.title, cu.year, cu.summary) == (tieu_de, nam, tom_tat), \
            "đường ống đã ghi đè nội dung nhóm viết tay"
        assert cu.summary_thcs == "Bản THCS thử"
        assert cu.grades == "6,11"
        assert cu.sources[0]["giay_phep"] == "CC BY-SA 4.0"
    finally:
        db.close()


def test_su_kien_moi_duoc_tao_va_nap_lai_khong_nhan_doi_cau_hoi():
    db = SessionLocal()
    try:
        seed._nap_lam_giau(db, _du_lieu())
        seed._nap_lam_giau(db, _du_lieu())      # chạy lại: phải idempotent
        moi = db.query(HistoricalEvent).filter_by(slug=SLUG_MOI).one()
        assert moi.title == "Trận thử nghiệm" and moi.year == 1427
        assert moi.summary == "Tóm tắt THCS", "sự kiện mới cần có summary để app cũ vẫn hiện"
        cau = db.query(QuizQuestion).filter_by(event_id=moi.id).all()
        assert len(cau) == 1
        assert cau[0].correct_option == "C"
        assert cau[0].source_claims[0]["trich_dan"] == "t"
    finally:
        db.close()


def test_su_kien_co_san_bi_thieu_trong_csdl_thi_khong_tu_tao():
    du = _du_lieu()
    du["events"] = [{**du["events"][0], "slug": "khong-ton-tai-" + uuid.uuid4().hex[:6]}]
    db = SessionLocal()
    try:
        seed._nap_lam_giau(db, du)
        assert db.query(HistoricalEvent).filter_by(slug=du["events"][0]["slug"]).first() is None
    finally:
        db.close()


def test_api_tra_ve_cot_moi():
    db = SessionLocal()
    try:
        seed._nap_lam_giau(db, _du_lieu())
    finally:
        db.close()
    e = next(x for x in client.get("/api/v1/events").json() if x["slug"] == "bach-dang-938")
    assert e["summary_thpt"] == "Bản THPT thử"
    assert e["curriculum"][0]["lop"] == 6
    assert e["sources"][0]["url"].startswith("https://")


def test_chat_noi_su_lieu_da_kiem_vao_persona_khong_de():
    db = SessionLocal()
    try:
        seed._nap_lam_giau(db, _du_lieu())
        f = db.query(HistoricalFigure).filter_by(slug="tran-hung-dao").one()
        prompt = _build_system_prompt(f)
        assert prompt.startswith(f.persona_prompt), "persona nhóm viết phải còn nguyên ở đầu"
        assert "dữ kiện thử" in prompt
    finally:
        db.close()


def test_migrate_nhe_them_cot_vao_bang_cu(tmp_path, monkeypatch):
    """Bảng tạo từ bản cũ (chưa có cột mới) phải được thêm cột, không mất dữ liệu."""
    eng = create_engine(f"sqlite:///{tmp_path / 'cu.db'}")
    with eng.begin() as c:
        c.execute(text("CREATE TABLE historical_events (id INTEGER PRIMARY KEY, slug VARCHAR, "
                       "title VARCHAR, year INTEGER)"))
        c.execute(text("INSERT INTO historical_events VALUES (1, 'x', 'Tiêu đề cũ', 938)"))
    monkeypatch.setattr(migrate_nhe, "engine", eng)
    migrate_nhe.dam_bao_cot()
    cot = {c["name"] for c in inspect(eng).get_columns("historical_events")}
    assert {"summary_thcs", "summary_thpt", "grades", "curriculum", "sources"} <= cot
    with eng.begin() as c:
        assert c.execute(text("SELECT title FROM historical_events")).scalar() == "Tiêu đề cũ"


def _dang_ky(lop=None):
    email = f"hs{uuid.uuid4().hex[:8]}@test.com"
    body = {"email": email, "full_name": "Học Sinh", "password": "12345678"}
    if lop is not None:
        body["grade"] = lop
    return email, client.post("/api/v1/auth/register", json=body)


def test_dang_ky_lop_ngoai_6_12_bi_tu_choi():
    assert _dang_ky(13)[1].status_code == 422
    assert _dang_ky(5)[1].status_code == 422


def test_dang_ky_khong_can_lop_va_sua_lop_sau():
    email, r = _dang_ky()
    assert r.status_code == 201 and r.json()["grade"] is None
    tok = client.post("/api/v1/auth/login", data={"username": email, "password": "12345678"}).json()["access_token"]
    h = {"Authorization": f"Bearer {tok}"}
    r = client.patch("/api/v1/auth/me", json={"grade": 8}, headers=h)
    assert r.status_code == 200 and r.json()["grade"] == 8
    assert client.get("/api/v1/auth/me", headers=h).json()["grade"] == 8
    assert client.patch("/api/v1/auth/me", json={"grade": 20}, headers=h).status_code == 422
    assert client.patch("/api/v1/auth/me", json={"grade": 8}).status_code == 401
