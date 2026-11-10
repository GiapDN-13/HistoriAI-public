"""Test hệ đo lường — chạy với SQLite tạm như test_smoke."""
import os
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402
from app.services.analytics import EVENT_NAMES  # noqa: E402

seed.run()
client = TestClient(app)

TEST_PW = "12345678"


def _ev(name: str, client_id: str, session_id: str, **kw) -> dict:
    return {"name": name, "client_id": client_id, "session_id": session_id,
            "platform": "web", **kw}


def _track(events: list[dict], headers: dict | None = None):
    return client.post("/api/v1/analytics/track", json={"events": events},
                       headers=headers or {})


def _new_ids() -> tuple[str, str]:
    return f"c-{uuid.uuid4().hex[:8]}", f"s-{uuid.uuid4().hex[:8]}"


def test_track_khach_khong_can_dang_nhap():
    """Khách chưa đăng nhập vẫn được ghi nhận — phần lớn người thử là khách."""
    cid, sid = _new_ids()
    r = _track([_ev("app_open", cid, sid), _ev("timeline_view", cid, sid)])
    assert r.status_code == 200
    assert r.json()["accepted"] == 2
    assert r.json()["rejected"] == 0


def test_track_bo_qua_ten_la():
    """Tên ngoài danh mục bị bỏ, phần còn lại của gói vẫn được ghi."""
    cid, sid = _new_ids()
    r = _track([_ev("app_open", cid, sid), _ev("khong_co_that", cid, sid)])
    assert r.status_code == 200
    body = r.json()
    assert body["accepted"] == 1
    assert body["rejected"] == 1
    assert body["unknown"] == ["khong_co_that"]


def test_track_gan_user_id_khi_co_token():
    """Có token thì event nối được với tài khoản, để ghép với XP/tiến độ."""
    email = f"track-{uuid.uuid4().hex[:6]}@test.com"
    client.post("/api/v1/auth/register",
                json={"email": email, "full_name": "Track", "password": TEST_PW})
    tok = client.post("/api/v1/auth/login",
                      data={"username": email, "password": TEST_PW}).json()["access_token"]
    cid, sid = _new_ids()
    _track([_ev("quiz_submit", cid, sid, target="lam-son-1428", value=2)],
           headers={"Authorization": f"Bearer {tok}"})

    from app.db.session import SessionLocal
    from app.models.analytics import AnalyticsEvent
    db = SessionLocal()
    try:
        row = db.query(AnalyticsEvent).filter(AnalyticsEvent.client_id == cid).one()
        assert row.user_id is not None
        assert row.value == 2
        assert row.target == "lam-son-1428"
    finally:
        db.close()


def test_track_gioi_han_50_event_moi_lan():
    """Gói quá 50 event bị từ chối, tránh ai đó bơm rác vào bảng."""
    cid, sid = _new_ids()
    r = _track([_ev("app_open", cid, sid) for _ in range(51)])
    assert r.status_code == 422


def test_summary_dung_cau_truc_va_dem_dung():
    """Số liệu tổng hợp có đủ các khối mà báo cáo cần."""
    cid, sid = _new_ids()
    _track([
        _ev("app_open", cid, sid),
        _ev("event_open", cid, sid, target="bach-dang-1288"),
        _ev("quiz_start", cid, sid, target="bach-dang-1288"),
        _ev("quiz_submit", cid, sid, target="bach-dang-1288", value=3),
    ])
    body = client.get("/api/v1/analytics/summary?days=7").json()

    for khoi in ("range", "totals", "active", "daily", "by_event",
                 "funnel", "top_targets", "quiz", "retention_d1"):
        assert khoi in body, f"Thiếu khối {khoi}"

    assert body["totals"]["events"] >= 4
    assert body["active"]["dau"] >= 1
    # Phễu phải giữ nguyên thứ tự các bậc và bậc đầu là 100%
    assert body["funnel"][0]["pct_of_top"] == 100.0
    assert len(body["funnel"]) == 6
    ten_su_kien = {e["name"] for e in body["by_event"]}
    assert {"app_open", "quiz_submit"} <= ten_su_kien
    assert body["quiz"]["submits"] >= 1


def test_summary_phieu_khong_dem_trung_mot_nguoi():
    """Một người bấm quiz 5 lần vẫn chỉ tính là 1 người trong phễu."""
    cid, sid = _new_ids()
    _track([_ev("premium_cta_click", cid, sid) for _ in range(5)])
    body = client.get("/api/v1/analytics/summary?days=7").json()
    buoc_mua = next(f for f in body["funnel"] if f["step"] == "Bấm mua Premium")
    so_luot = next(e["count"] for e in body["by_event"] if e["name"] == "premium_cta_click")
    assert so_luot >= 5
    # Phễu đếm người, không đếm lượt bấm — nên phải nhỏ hơn hẳn số lượt
    assert buoc_mua["people"] < so_luot


def test_summary_can_khoa_khi_da_dat_key():
    """Đặt ANALYTICS_KEY rồi thì người ngoài không xem được số liệu."""
    goc = settings.ANALYTICS_KEY
    settings.ANALYTICS_KEY = "khoa-test"
    try:
        assert client.get("/api/v1/analytics/summary").status_code == 401
        assert client.get("/api/v1/analytics/summary?key=sai").status_code == 401
        assert client.get("/api/v1/analytics/summary?key=khoa-test").status_code == 200
        assert client.get("/api/v1/analytics/summary",
                          headers={"X-Analytics-Key": "khoa-test"}).status_code == 200
    finally:
        settings.ANALYTICS_KEY = goc


def test_danh_muc_event_cong_khai():
    """App và người viết báo cáo dùng chung một danh mục tên sự kiện."""
    r = client.get("/api/v1/analytics/events")
    assert r.status_code == 200
    assert set(r.json()) == EVENT_NAMES


def test_dashboard_tra_ve_html():
    r = client.get("/api/v1/analytics/dashboard")
    assert r.status_code == 200
    assert "text/html" in r.headers["content-type"]
    assert "HistoriAI" in r.text
