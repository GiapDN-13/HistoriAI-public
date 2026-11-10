"""Chỉ số mở rộng cho dashboard: giữ chân D1/D7/D30, thiết bị, tài khoản, thời gian dùng.

Bổ sung 05/10 theo yêu cầu giảng viên. Tính trên bảng analytics_events có sẵn — không
cần sự kiện mới, trừ phần LOẠI THIẾT BỊ: trước 05/10 máy chủ không ghi trình duyệt/hệ
điều hành, nên phần đó chỉ có số từ 05/10 (bản ghi cũ hiện "chưa ghi nhận").

ĐỊNH NGHĨA (ghi lên dashboard cho người đọc):
    Dn       — trong số thiết bị lần ĐẦU mở app vào ngày N, bao nhiêu % có mở lại đúng
               ngày N+n (giờ VN). Chỉ tính những thiết bị đã đủ n ngày.
    Phiên    — một lần mở app (session_id do app sinh). Thời lượng = từ hành vi đầu tới
               hành vi cuối của phiên → THẤP HƠN thực tế, vì không biết người dùng còn
               nhìn màn hình bao lâu sau hành vi cuối.
    Thoát ngay — phiên chỉ có một hành vi (mở app rồi đóng).
    Độ bám  — DAU trung bình / MAU: người dùng tháng mở app bao nhiêu % số ngày.
"""
from __future__ import annotations

import re
import statistics
from datetime import date, datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.models.analytics import AnalyticsEvent
from app.models.user import User

VN_TZ = timezone(timedelta(hours=7))
MOC_RETENTION = (1, 7, 30)
EMAIL_TAO_NHANH = "@nhanh.historiai.org"     # tài khoản học sinh tạo nhanh trong phòng thi


# ───────────────────────── Đọc User-Agent ─────────────────────────

def doc_thiet_bi(ua: str | None) -> dict:
    """Loại máy / hệ điều hành / trình duyệt từ User-Agent. Thô nhưng đủ để chia nhóm."""
    ua = ua or ""
    u = ua.lower()
    tu_dong = bool(re.search(r"headless|playwright|puppeteer|bot|crawler|spider|curl|python-|okhttp", u))
    if "ipad" in u or ("android" in u and "mobile" not in u) or "tablet" in u:
        loai = "Máy tính bảng"
    elif re.search(r"mobile|iphone|ipod|android", u):
        loai = "Điện thoại"
    elif ua:
        loai = "Máy tính"
    else:
        loai = "Chưa rõ"
    if "android" in u:
        hdh = "Android"
    elif re.search(r"iphone|ipad|ipod", u):
        hdh = "iOS"
    elif "windows" in u:
        hdh = "Windows"
    elif "mac os" in u or "macintosh" in u:
        hdh = "macOS"
    elif "cros" in u:
        hdh = "ChromeOS"
    elif "linux" in u:
        hdh = "Linux"
    else:
        hdh = "Chưa rõ"
    # Thứ tự quan trọng: Edge/Opera/Cốc Cốc/Zalo/Facebook đều có chữ "chrome"/"safari".
    for mau, ten in (("zalo", "Zalo (trình duyệt trong app)"), ("fban|fbav|fb_iab", "Facebook (trong app)"),
                     ("instagram", "Instagram (trong app)"), ("coc_coc|coccoc", "Cốc Cốc"),
                     ("edg/", "Edge"), ("opr/|opera", "Opera"), ("samsungbrowser", "Samsung Internet"),
                     ("firefox|fxios", "Firefox"), ("chrome|crios", "Chrome"), ("safari", "Safari")):
        if re.search(mau, u):
            trinh = ten
            break
    else:
        trinh = "Chưa rõ" if not ua else "Khác"
    return {"loai": loai, "hdh": hdh, "trinh_duyet": trinh, "tu_dong": tu_dong}


# ───────────────────────── Tiện ích ─────────────────────────

def _vn(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(VN_TZ)


def _pct(a: int, b: int) -> float | None:
    return round(a * 100 / b, 1) if b else None


def may_tu_dong(rows) -> set[str]:
    """Thiết bị kiểm thử / bot — loại khỏi mọi chỉ số.

    Hai dấu hiệu: trình duyệt tự động (ghi từ 05/10), hoặc mở app bằng link gắn
    ?utm_source=kiem-thu (nhóm dùng khi tự thử, có từ trước 05/10)."""
    return {r.client_id for r in rows
            if r.name == "app_open" and isinstance(r.params, dict)
            and ((isinstance(r.params.get("_tb"), dict) and r.params["_tb"].get("tu_dong"))
                 or r.params.get("nguon") == "kiem-thu")}


# ───────────────────────── Giữ chân ─────────────────────────

def _giu_chan(rows_all, bo: set[str], hom_nay: date) -> dict:
    ngay_dau: dict[str, date] = {}
    ngay_co_mat: dict[str, set[date]] = {}
    for r in rows_all:
        if r.client_id in bo:
            continue
        d = _vn(r.created_at).date()
        ngay_co_mat.setdefault(r.client_id, set()).add(d)
        if r.client_id not in ngay_dau or d < ngay_dau[r.client_id]:
            ngay_dau[r.client_id] = d

    tong = {}
    for n in MOC_RETENTION:
        du = [c for c, d0 in ngay_dau.items() if d0 + timedelta(days=n) <= hom_nay]
        quay = [c for c in du if ngay_dau[c] + timedelta(days=n) in ngay_co_mat[c]]
        # "Trong vòng n ngày": quay lại BẤT KỲ ngày nào từ N+1 tới N+n — dễ hiểu hơn với
        # app học không mở hằng ngày; Dn cổ điển (đúng ngày N+n) thường rất thấp.
        trong = [c for c in du if any(ngay_dau[c] < d <= ngay_dau[c] + timedelta(days=n)
                                      for d in ngay_co_mat[c])]
        tong[f"d{n}"] = {"du_dieu_kien": len(du), "quay_lai": len(quay), "pct": _pct(len(quay), len(du)),
                         "trong_vong": len(trong), "pct_trong_vong": _pct(len(trong), len(du))}

    # Theo nhóm tuần bắt đầu (thứ Hai) — đường cong giữ chân từng đợt người mới
    nhom: dict[date, list[str]] = {}
    for c, d0 in ngay_dau.items():
        nhom.setdefault(d0 - timedelta(days=d0.weekday()), []).append(c)
    theo_tuan = []
    for tuan in sorted(nhom)[-8:]:
        ds = nhom[tuan]
        dong = {"tuan": tuan.isoformat(), "so_moi": len(ds)}
        for n in MOC_RETENTION:
            du = [c for c in ds if ngay_dau[c] + timedelta(days=n) <= hom_nay]
            quay = [c for c in du if ngay_dau[c] + timedelta(days=n) in ngay_co_mat[c]]
            dong[f"d{n}"] = _pct(len(quay), len(du)) if len(du) == len(ds) else None
        theo_tuan.append(dong)
    return {"tong": tong, "theo_tuan": theo_tuan}


# ───────────────────────── Thời gian dùng ─────────────────────────

def _thoi_gian(rows, bo: set[str], so_ngay: int) -> dict:
    phien: dict[str, list] = {}
    for r in rows:
        if r.client_id in bo:
            continue
        p = phien.setdefault(r.session_id, [r.created_at, r.created_at, 0, r.client_id])
        p[0] = min(p[0], r.created_at)
        p[1] = max(p[1], r.created_at)
        p[2] += 1
    if not phien:
        return {"so_phien": 0}
    # Phiên dài quá 2 giờ thường là tab bỏ quên rồi quay lại — chặn trần cho khỏi méo.
    giay = [min((p[1] - p[0]).total_seconds(), 7200) for p in phien.values()]
    co_tuong_tac = [g for g, p in zip(giay, phien.values()) if p[2] > 1]
    nguoi = {p[3] for p in phien.values()}
    tong_theo_nguoi: dict[str, float] = {}
    for g, p in zip(giay, phien.values()):
        tong_theo_nguoi[p[3]] = tong_theo_nguoi.get(p[3], 0) + g
    return {
        "so_phien": len(giay),
        "tb_phien_giay": round(statistics.mean(giay)),
        "trung_vi_phien_giay": round(statistics.median(giay)),
        "tb_phien_co_tuong_tac_giay": round(statistics.mean(co_tuong_tac)) if co_tuong_tac else 0,
        "thoat_ngay_pct": _pct(sum(1 for p in phien.values() if p[2] <= 1), len(phien)),
        "phien_moi_nguoi": round(len(giay) / len(nguoi), 2),
        "tb_moi_nguoi_giay": round(statistics.mean(tong_theo_nguoi.values())),
        "so_ngay": so_ngay,
    }


# ───────────────────────── Thiết bị ─────────────────────────

def _thiet_bi(rows, bo: set[str]) -> dict:
    nen: dict[str, set[str]] = {}
    tb: dict[str, dict] = {}
    for r in rows:
        if r.client_id in bo:
            continue
        nen.setdefault(r.platform, set()).add(r.client_id)
        if (r.name == "app_open" and isinstance(r.params, dict)
                and isinstance(r.params.get("_tb"), dict)):
            tb.setdefault(r.client_id, r.params["_tb"])
    moi_nguoi = {c for s in nen.values() for c in s}

    def dem(khoa: str):
        d: dict[str, int] = {}
        for c in moi_nguoi:
            ten = tb[c].get(khoa, "Chưa rõ") if c in tb else "Chưa ghi nhận (trước 05/10)"
            d[ten] = d.get(ten, 0) + 1
        return [{"ten": k, "so": v, "pct": _pct(v, len(moi_nguoi))}
                for k, v in sorted(d.items(), key=lambda kv: -kv[1])]

    ten_nen = {"web": "Web (trình duyệt)", "android": "App Android", "ios": "App iOS"}
    return {
        "nen_tang": [{"ten": ten_nen.get(k, k), "so": len(v), "pct": _pct(len(v), len(moi_nguoi))}
                     for k, v in sorted(nen.items(), key=lambda kv: -len(kv[1]))],
        "loai": dem("loai"), "hdh": dem("hdh"), "trinh_duyet": dem("trinh_duyet"),
        "da_ghi_nhan": len([c for c in moi_nguoi if c in tb]),
        "tong": len(moi_nguoi),
    }


# ───────────────────────── Tài khoản ─────────────────────────

def _tai_khoan(db: Session, rows, bo: set[str], since: datetime, now: datetime) -> dict:
    users = db.query(User.id, User.email, User.role, User.google_sub, User.created_at).all()
    def cach(u):
        if (u.email or "").endswith(EMAIL_TAO_NHANH):
            return "Tạo nhanh trong phòng thi"
        return "Google" if u.google_sub else "Email + mật khẩu"
    def trong_ky(u):
        if not u.created_at:
            return False
        c = u.created_at if u.created_at.tzinfo else u.created_at.replace(tzinfo=timezone.utc)
        return since <= c < now
    moi = [u for u in users if trong_ky(u)]
    hoat_dong = {r.user_id for r in rows if r.user_id and r.client_id not in bo}
    may = {r.client_id for r in rows if r.client_id not in bo}
    may_dang_nhap = {r.client_id for r in rows if r.user_id and r.client_id not in bo}

    def nhom(ds, f):
        d: dict[str, int] = {}
        for u in ds:
            d[f(u)] = d.get(f(u), 0) + 1
        return [{"ten": k, "so": v} for k, v in sorted(d.items(), key=lambda kv: -kv[1])]

    ten_vai = {"student": "Học sinh", "teacher": "Giáo viên", "school": "Trường"}
    return {
        "tong": len(users),
        "moi_trong_ky": len(moi),
        "hoat_dong_trong_ky": len(hoat_dong),
        "may_dang_nhap_pct": _pct(len(may_dang_nhap), len(may)),
        "theo_vai_tro": nhom(users, lambda u: ten_vai.get(u.role or "student", u.role)),
        "theo_cach_dang_ky": nhom(users, cach),
        "moi_theo_cach_dang_ky": nhom(moi, cach),
    }


# ───────────────────────── Gộp ─────────────────────────

def build_mo_rong(db: Session, days: int, now: datetime) -> dict:
    since = now - timedelta(days=days)
    tat_ca = (db.query(AnalyticsEvent).filter(AnalyticsEvent.created_at < now)
              .order_by(AnalyticsEvent.created_at).all())
    trong_ky = [r for r in tat_ca if (r.created_at if r.created_at.tzinfo
                                      else r.created_at.replace(tzinfo=timezone.utc)) >= since]
    bo = may_tu_dong(tat_ca)
    hom_nay = _vn(now).date()

    theo_ngay: dict[date, set[str]] = {}
    for r in trong_ky:
        if r.client_id not in bo:
            theo_ngay.setdefault(_vn(r.created_at).date(), set()).add(r.client_id)
    mau = len({c for s in theo_ngay.values() for c in s})
    dau_tb = sum(len(s) for s in theo_ngay.values()) / days

    return {
        "giu_chan": _giu_chan(tat_ca, bo, hom_nay),
        "thoi_gian": _thoi_gian(trong_ky, bo, days),
        "thiet_bi": _thiet_bi(trong_ky, bo),
        "tai_khoan": _tai_khoan(db, trong_ky, bo, since, now),
        "do_bam": {"dau_tb": round(dau_tb, 1), "mau": mau, "pct": _pct(round(dau_tb * 10), mau * 10)},
        "da_loai_tu_dong": len(bo),
    }
