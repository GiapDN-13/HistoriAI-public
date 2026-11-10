"""Chỉ số mở rộng của dashboard: D1/D7/D30, thời gian dùng, thiết bị, loại máy tự động."""
import os
import uuid
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.analytics import AnalyticsEvent  # noqa: E402
from app.services import analytics_mo_rong as M  # noqa: E402

seed.run()
client = TestClient(app)
VN = timezone(timedelta(hours=7))


def _r(cid, ngay: date, gio=9, phut=0, sid=None, name="timeline_view", params=None, platform="web"):
    return SimpleNamespace(client_id=cid, session_id=sid or f"{cid}-{ngay}", name=name, params=params,
                           platform=platform, user_id=None,
                           created_at=datetime(ngay.year, ngay.month, ngay.day, gio, phut, tzinfo=VN))


HOM_NAY = date(2026, 10, 5)
D0 = date(2026, 9, 1)


def test_dn_tinh_dung_ngay_va_trong_vong():
    rows = [
        _r("a", D0), _r("a", D0 + timedelta(days=1)), _r("a", D0 + timedelta(days=7)),
        _r("b", D0), _r("b", D0 + timedelta(days=3)),          # quay lại ngày 3: không D1, không D7
        _r("c", D0),                                           # không quay lại
    ]
    t = M._giu_chan(rows, set(), HOM_NAY)["tong"]
    assert t["d1"]["quay_lai"] == 1 and t["d1"]["du_dieu_kien"] == 3
    assert t["d7"]["quay_lai"] == 1
    assert t["d7"]["trong_vong"] == 2, "b quay lại trong 7 ngày"
    assert t["d30"]["pct"] == 0.0


def test_chua_du_ngay_thi_khong_tinh():
    rows = [_r("moi", HOM_NAY - timedelta(days=3))]
    t = M._giu_chan(rows, set(), HOM_NAY)["tong"]
    assert t["d1"]["du_dieu_kien"] == 1
    assert t["d7"]["du_dieu_kien"] == 0 and t["d7"]["pct"] is None


def test_thoi_gian_phien_va_thoat_ngay():
    rows = [_r("a", D0, 9, 0, "s1"), _r("a", D0, 9, 10, "s1"),   # 600 s
            _r("b", D0, 9, 0, "s2")]                              # 1 hành vi = thoát ngay
    t = M._thoi_gian(rows, set(), 30)
    assert t["so_phien"] == 2
    assert t["tb_phien_co_tuong_tac_giay"] == 600
    assert t["thoat_ngay_pct"] == 50.0


def test_doc_user_agent():
    iphone = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605 Version/17.0 Mobile/15E148 Safari/604.1"
    zalo = "Mozilla/5.0 (Linux; Android 13; SM-A536E) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36 Zalo android/1"
    edge = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36 Edg/120"
    assert M.doc_thiet_bi(iphone) == {"loai": "Điện thoại", "hdh": "iOS", "trinh_duyet": "Safari", "tu_dong": False}
    assert M.doc_thiet_bi(zalo)["trinh_duyet"].startswith("Zalo")
    assert M.doc_thiet_bi(edge)["loai"] == "Máy tính" and M.doc_thiet_bi(edge)["trinh_duyet"] == "Edge"
    assert M.doc_thiet_bi("Mozilla/5.0 HeadlessChrome/120")["tu_dong"]


def test_track_ghi_thiet_bi_va_bo_may_tu_dong():
    that, tu_dong = f"c-{uuid.uuid4().hex[:8]}", f"c-{uuid.uuid4().hex[:8]}"
    for cid, ua in ((that, "Mozilla/5.0 (Linux; Android 13) Chrome/120 Mobile Safari/537.36"),
                    (tu_dong, "Mozilla/5.0 HeadlessChrome/120")):
        client.post("/api/v1/analytics/track", headers={"User-Agent": ua}, json={"events": [
            {"name": "app_open", "client_id": cid, "session_id": cid + "-s", "platform": "web"}]})
    db = SessionLocal()
    try:
        ev = db.query(AnalyticsEvent).filter(AnalyticsEvent.client_id == that).one()
        assert ev.params["_tb"]["hdh"] == "Android"
    finally:
        db.close()
    k = {"key": settings.ANALYTICS_KEY} if settings.ANALYTICS_KEY else {}
    d = client.get("/api/v1/analytics/summary", params={"days": 7, **k}).json()
    assert d["mo_rong"]["da_loai_tu_dong"] >= 1
    assert "giu_chan" in d["mo_rong"] and "tai_khoan" in d["mo_rong"]
    nguon_may = sum(x["nguoi"] for x in d["nguon"])
    assert nguon_may == d["totals"]["people"], "máy tự động bị bỏ khỏi mọi bảng"
