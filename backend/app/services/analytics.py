"""Danh mục sự kiện đo lường và phần tổng hợp số liệu cho báo cáo.

Vì sao tổng hợp bằng Python thay vì SQL: câu lệnh nhóm-theo-ngày viết khác
nhau giữa SQLite (dùng khi chạy test) và PostgreSQL (chạy thật). Quy mô dự
án chỉ vài nghìn event nên đọc ra rồi đếm là đủ nhanh, mà chạy giống nhau ở
cả hai nơi. Khi nào vượt vài trăm nghìn dòng hãy chuyển sang bảng tổng hợp
theo ngày.
"""
from datetime import date, datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.models.analytics import AnalyticsEvent
from app.models.phan_hoi import PhanHoi
from app.models.user import User
from app.services.doanh_thu import dinh_dang_tien, tinh_doanh_thu

# Giờ Việt Nam — mọi con số "theo ngày" đều quy về múi này, để một buổi học
# lúc 21h tối không bị đẩy sang ngày hôm sau như khi tính theo UTC.
VN_TZ = timezone(timedelta(hours=7))

# --- Danh mục sự kiện được phép ghi ------------------------------------
# Tên nào không có ở đây sẽ bị từ chối, tránh mỗi người đặt một kiểu rồi
# đến lúc làm báo cáo không gom được số.
EVENT_NAMES: set[str] = {
    # hỏi phản hồi trong app: hiện / gửi / bỏ qua → tỉ lệ người chịu trả lời
    "phan_hoi_hien", "phan_hoi_gui", "phan_hoi_bo_qua",
    # Vòng đời
    "app_open",
    "signup_start",
    "signup_success",
    "login_success",
    # Khám phá nội dung
    "timeline_view",
    "event_open",
    "video_play",
    "ar_open",
    # Bấm "Đặt vào phòng": rời app sang Scene Viewer để dựng cổ vật ra giữa
    # phòng đúng kích thước thật. Tách khỏi `ar_open` (chỉ là xoay model trong
    # app) vì đây là hai mức quan tâm khác hẳn nhau — và vì nút này chỉ hiện
    # trên Android có Scene Viewer, nên số của nó còn dùng để biết bao nhiêu
    # phần người dùng thật sự với tới được tính năng.
    "ar_view",
    # Ba tính năng cốt lõi
    "chat_open",
    "chat_message_sent",
    "chat_voice_play",
    "quiz_start",
    "quiz_submit",
    "quiz_result_view",
    # Hướng dẫn lần đầu. `value` là số trang, nên đếm được người bỏ ngang ở
    # trang nào — chỗ đó chính là chỗ lời giới thiệu chưa đủ thuyết phục.
    "onboarding_view",
    "onboarding_done",
    "onboarding_skip",
    # Chỉ dẫn tại chỗ trong từng màn. `target` là tên màn, `value` là số bước
    # — đọc cặp này là biết màn nào người dùng bỏ ngang chỉ dẫn ở bước mấy.
    "chi_dan_view",
    "chi_dan_done",
    "chi_dan_skip",
    # Doanh thu
    "premium_view",
    "premium_cta_click",
}

# Phễu chính trong báo cáo: từ lúc mở app đến lúc bấm mua gói.
# Mỗi bậc đếm theo số *người* (client_id) đã làm ít nhất một trong các
# sự kiện của bậc đó.
FUNNEL_STEPS: list[tuple[str, tuple[str, ...]]] = [
    ("Mở app", ("app_open",)),
    ("Xem nội dung", ("timeline_view", "event_open")),
    ("Dùng tính năng lõi", ("chat_open", "quiz_start", "video_play", "ar_open")),
    ("Làm hết một lượt quiz", ("quiz_submit",)),
    ("Tạo tài khoản", ("signup_success",)),
    ("Bấm mua Premium", ("premium_cta_click",)),
]

# Những sự kiện đáng biết "người dùng quan tâm nội dung nào nhất".
TOP_TARGET_EVENTS = (
    "event_open", "chat_open", "quiz_start", "ar_open", "ar_view", "video_play",
)


def _as_utc(dt: datetime) -> datetime:
    """SQLite trả datetime không kèm múi giờ — gán UTC để so sánh được."""
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _vn_date(dt: datetime) -> date:
    return _as_utc(dt).astimezone(VN_TZ).date()


def _rate(part: int, whole: int) -> float:
    """Tỉ lệ phần trăm, làm tròn 1 chữ số. Mẫu bằng 0 thì trả 0."""
    return round(part / whole * 100, 1) if whole else 0.0


def _tong_phan_hoi(db: Session, since: datetime, den: datetime,
                   nguoi_hien: int, nguoi_gui: int) -> dict:
    """NPS, sao trung bình, theo nguồn / ngữ cảnh, trận muốn thêm, và các góp ý mới nhất
    trong khoảng."""
    ds = (db.query(PhanHoi).filter(PhanHoi.created_at >= since, PhanHoi.created_at < den)
          .order_by(PhanHoi.created_at.desc()).all())

    def nps_cua(nhom):
        diem = [p.nps for p in nhom if p.nps is not None]
        if not diem:
            return None
        ung_ho = sum(d >= 9 for d in diem) / len(diem) * 100
        phan_doi = sum(d <= 6 for d in diem) / len(diem) * 100
        return {"so": len(diem), "diem": round(ung_ho - phan_doi),
                "ung_ho": round(ung_ho), "trung_lap": round(100 - ung_ho - phan_doi),
                "phan_doi": round(phan_doi)}

    def sao_tb(nhom):
        s = [p.diem for p in nhom if p.diem is not None]
        return round(sum(s) / len(s), 2) if s else None

    def gom(khoa):
        g: dict = {}
        for p in ds:
            g.setdefault(khoa(p), []).append(p)
        return [{"nhom": k, "so": len(v), "sao_tb": sao_tb(v), "nps": nps_cua(v)}
                for k, v in sorted(g.items(), key=lambda kv: -len(kv[1]))]

    # Trận/chủ đề muốn thêm: mỗi lượt phản hồi đếm một lần cho mỗi slug (đã bỏ trùng lúc nhận).
    # Trả lời "nội dung còn ít — thêm trận NÀO trước" khi nhóm chọn việc cho đường ống.
    muon: dict[str, int] = {}
    for p in ds:
        for s in (p.muon_them or "").split(","):
            if s:
                muon[s] = muon.get(s, 0) + 1

    return {
        "so_luot": len(ds),
        "sao_tb": sao_tb(ds),
        "nps": nps_cua(ds),
        "ti_le_tra_loi": _rate(nguoi_gui, nguoi_hien),
        "theo_nguon": gom(lambda p: (p.nguon or "chua-ro") + (f" / {p.noi_dung}" if p.noi_dung else "")),
        "theo_ngu_canh": gom(lambda p: p.ngu_canh),
        "muon_them": [{"slug": s, "so": n}
                      for s, n in sorted(muon.items(), key=lambda kv: (-kv[1], kv[0]))],
        "gop_y_moi": [
            {"luc": p.created_at.astimezone(VN_TZ).strftime("%d/%m %H:%M") if p.created_at.tzinfo
             else p.created_at.strftime("%d/%m %H:%M"),
             "ngu_canh": p.ngu_canh, "target": p.target, "diem": p.diem, "nps": p.nps,
             "nguon": p.nguon or "chua-ro", "gop_y": p.gop_y}
            for p in ds if p.gop_y][:30],
    }


def build_summary(db: Session, days: int = 30, den: datetime | None = None) -> dict:
    """Gom toàn bộ số liệu của [days] ngày kết thúc tại [den] (mặc định: bây giờ)."""
    now = den or datetime.now(timezone.utc)
    since = now - timedelta(days=days)
    rows = (
        db.query(AnalyticsEvent)
        .filter(AnalyticsEvent.created_at >= since, AnalyticsEvent.created_at < now)
        .order_by(AnalyticsEvent.created_at)
        .all()
    )
    # Trình duyệt tự động (kiểm thử của nhóm, bot) không phải người dùng — bỏ khỏi mọi số.
    from app.services.analytics_mo_rong import build_mo_rong, may_tu_dong
    bo = may_tu_dong(rows)
    rows = [r for r in rows if r.client_id not in bo]

    today_vn = now.astimezone(VN_TZ).date()

    # --- Gom sẵn vài chỉ số trong một lượt duyệt -----------------------
    by_name: dict[str, int] = {}
    people_by_name: dict[str, set[str]] = {}      # tên sự kiện → tập client_id
    targets: dict[str, dict[str, int]] = {}       # tên sự kiện → slug → lượt
    daily: dict[date, dict[str, set[str] | int]] = {}
    people_by_day: dict[date, set[str]] = {}
    all_people: set[str] = set()
    all_sessions: set[str] = set()
    signed_in: set[int] = set()
    first_seen: dict[str, date] = {}              # client_id → ngày đầu tiên
    platforms: dict[str, int] = {}
    quiz_scores: list[int] = []
    # Nguồn đầu tiên của từng máy, lấy từ app_open sớm nhất có ghi nguồn
    # (nguồn, kênh, chiến dịch, nội dung) — nội dung dùng để tách từng group khi seeding
    client_nguon: dict[str, tuple[str, str | None, str | None, str | None]] = {}

    for r in rows:
        d = _vn_date(r.created_at)
        by_name[r.name] = by_name.get(r.name, 0) + 1
        people_by_name.setdefault(r.name, set()).add(r.client_id)
        all_people.add(r.client_id)
        all_sessions.add(r.session_id)
        platforms[r.platform] = platforms.get(r.platform, 0) + 1
        if r.user_id:
            signed_in.add(r.user_id)
        if r.name in TOP_TARGET_EVENTS and r.target:
            targets.setdefault(r.name, {})
            targets[r.name][r.target] = targets[r.name].get(r.target, 0) + 1
        if r.name == "quiz_submit" and r.value is not None:
            quiz_scores.append(r.value)
        if (r.name == "app_open" and r.client_id not in client_nguon
                and isinstance(r.params, dict) and r.params.get("nguon")):
            p = r.params
            client_nguon[r.client_id] = tuple(
                (str(p[k])[:40] if p.get(k) else None)
                for k in ("nguon", "kenh", "chien_dich", "noi_dung"))

        people_by_day.setdefault(d, set()).add(r.client_id)
        slot = daily.setdefault(d, {"events": 0, "sessions": set(), "people": set()})
        slot["events"] += 1
        slot["sessions"].add(r.session_id)
        slot["people"].add(r.client_id)

        if r.client_id not in first_seen or d < first_seen[r.client_id]:
            first_seen[r.client_id] = d

    # --- Người dùng hoạt động -----------------------------------------
    def people_since(n_days: int) -> int:
        cutoff = today_vn - timedelta(days=n_days - 1)
        return len({c for d, ppl in people_by_day.items() if d >= cutoff for c in ppl})

    # --- Phễu ----------------------------------------------------------
    funnel = []
    top_count = 0
    prev_count = 0
    for i, (label, names) in enumerate(FUNNEL_STEPS):
        reached = set()
        for n in names:
            reached |= people_by_name.get(n, set())
        count = len(reached)
        if i == 0:
            top_count = prev_count = count
        funnel.append({
            "step": label,
            "events": list(names),
            "people": count,
            "pct_of_top": _rate(count, top_count),
            "pct_of_prev": _rate(count, prev_count),
        })
        prev_count = count

    # --- Tỉ lệ quay lại hôm sau (D1) ------------------------------------
    # Người mở app ngày N có quay lại ngày N+1 không. Bỏ qua ngày hôm nay
    # vì "ngày mai" chưa xảy ra.
    cohort = 0
    returned = 0
    for client_id, d0 in first_seen.items():
        if d0 >= today_vn:
            continue
        cohort += 1
        if client_id in people_by_day.get(d0 + timedelta(days=1), set()):
            returned += 1

    # --- Khách đến từ đâu -----------------------------------------------
    # Mỗi máy tính cho nguồn ĐẦU TIÊN của nó. Máy chưa từng gửi nguồn (bản app
    # cũ, trước khi có đo nguồn) gộp vào "chua-ro" — không đoán là trực tiếp.
    BUOC_NGUON = [("dang_ky", "signup_success"), ("lam_quiz", "quiz_submit"),
                  ("chat", "chat_message_sent"), ("bam_mua", "premium_cta_click")]
    theo_nguon: dict[tuple, dict] = {}
    for c in all_people:
        khoa = client_nguon.get(c, ("chua-ro", None, None, None))
        dong = theo_nguon.setdefault(khoa, {"nguoi": set(), **{k: set() for k, _ in BUOC_NGUON}})
        dong["nguoi"].add(c)
        for k, ten in BUOC_NGUON:
            if c in people_by_name.get(ten, set()):
                dong[k].add(c)
    nguon_bang = sorted(
        ({"nguon": n, "kenh": kn, "chien_dich": cd, "noi_dung": nd, "nguoi": len(v["nguoi"]),
          **{k: len(v[k]) for k, _ in BUOC_NGUON},
          "ti_le_dang_ky": _rate(len(v["dang_ky"]), len(v["nguoi"]))}
         for (n, kn, cd, nd), v in theo_nguon.items()),
        key=lambda x: (-x["nguoi"], x["nguon"]))

    # Tài khoản đăng ký theo nguồn (trong khoảng thời gian đang xem)
    tai_khoan: dict[str, int] = {}
    for (n,) in (db.query(User.nguon).filter(User.created_at >= since, User.created_at < now).all()):
        tai_khoan[n or "chua-ro"] = tai_khoan.get(n or "chua-ro", 0) + 1

    return {
        "doanh_thu": tinh_doanh_thu(db, days, now),
        "mo_rong": build_mo_rong(db, days, now),
        "phan_hoi": _tong_phan_hoi(db, since, now,
                                   len(people_by_name.get("phan_hoi_hien", set())),
                                   len(people_by_name.get("phan_hoi_gui", set()))),
        "nguon": nguon_bang,
        "tai_khoan_theo_nguon": [{"nguon": k, "so": v} for k, v in
                                 sorted(tai_khoan.items(), key=lambda kv: -kv[1])],
        "range": {
            "days": days,
            "from": since.astimezone(VN_TZ).date().isoformat(),
            "to": today_vn.isoformat(),
            "timezone": "UTC+7 (giờ Việt Nam)",
            "generated_at": now.astimezone(VN_TZ).strftime("%d/%m/%Y %H:%M"),
        },
        "totals": {
            "events": len(rows),
            "people": len(all_people),
            "sessions": len(all_sessions),
            "signed_in_users": len(signed_in),
            "platforms": dict(sorted(platforms.items(), key=lambda kv: -kv[1])),
        },
        "active": {
            "dau": len(people_by_day.get(today_vn, set())),
            "wau": people_since(7),
            "mau": people_since(30),
        },
        "daily": [
            {
                "date": d.isoformat(),
                "events": v["events"],
                "sessions": len(v["sessions"]),
                "people": len(v["people"]),
            }
            for d, v in sorted(daily.items())
        ],
        "by_event": [
            {"name": n, "count": c, "people": len(people_by_name.get(n, set()))}
            for n, c in sorted(by_name.items(), key=lambda kv: -kv[1])
        ],
        "funnel": funnel,
        "top_targets": {
            ev: [
                {"target": t, "count": c}
                for t, c in sorted(slugs.items(), key=lambda kv: -kv[1])[:8]
            ]
            for ev, slugs in targets.items()
        },
        "quiz": {
            "submits": len(quiz_scores),
            "avg_correct": round(sum(quiz_scores) / len(quiz_scores), 2) if quiz_scores else 0,
        },
        "retention_d1": {
            "cohort": cohort,
            "returned": returned,
            "pct": _rate(returned, cohort),
        },
    }


# ───────────────────────── Báo cáo tuần ─────────────────────────

def _thiet_bi_moi(db: Session, since: datetime, den: datetime) -> int:
    """Thiết bị có lần xuất hiện ĐẦU TIÊN (tính trên toàn bộ lịch sử) nằm trong khoảng."""
    from sqlalchemy import func
    q = (db.query(AnalyticsEvent.client_id, func.min(AnalyticsEvent.created_at).label("dau"))
         .group_by(AnalyticsEvent.client_id).subquery())
    return db.query(q).filter(q.c.dau >= since, q.c.dau < den).count()


def bao_cao_tuan(db: Session, den: datetime | None = None) -> str:
    """Bảng số liệu 7 ngày kết thúc tại [den], so với 7 ngày liền trước — dạng Markdown
    để chép thẳng vào báo cáo tuần. Mọi con số đều lấy từ bảng đo lường của nhóm."""
    den = den or datetime.now(timezone.utc)
    truoc_den = den - timedelta(days=7)
    t = build_summary(db, days=7, den=den)
    p = build_summary(db, days=7, den=truoc_den)

    def nguoi(s, ten):
        return next((x["people"] for x in s["by_event"] if x["name"] == ten), 0)

    def tai_khoan_moi(s_den):
        return db.query(User).filter(User.created_at >= s_den - timedelta(days=7),
                                     User.created_at < s_den).count()

    def doi(a, b):
        if a is None or b is None:
            return "—"
        if b == 0:
            return "mới" if a else "0"
        d = (a - b) / b * 100
        return f"{'+' if d >= 0 else ''}{d:.0f}%"

    ph_t, ph_p = t["phan_hoi"], p["phan_hoi"]
    nps_t = (ph_t["nps"] or {}).get("diem")
    nps_p = (ph_p["nps"] or {}).get("diem")
    chi_so = [
        ("Thiết bị hoạt động", t["totals"]["people"], p["totals"]["people"]),
        ("Thiết bị mới", _thiet_bi_moi(db, den - timedelta(days=7), den),
         _thiet_bi_moi(db, truoc_den - timedelta(days=7), truoc_den)),
        ("Phiên sử dụng", t["totals"]["sessions"], p["totals"]["sessions"]),
        ("Tài khoản mới", tai_khoan_moi(den), tai_khoan_moi(truoc_den)),
        ("Người làm quiz", nguoi(t, "quiz_submit"), nguoi(p, "quiz_submit")),
        ("Người chat với vĩ nhân", nguoi(t, "chat_message_sent"), nguoi(p, "chat_message_sent")),
        ("Quay lại hôm sau (%)", t["retention_d1"]["pct"], p["retention_d1"]["pct"]),
        # D7/D30 tính trên toàn lịch sử tới cuối mỗi tuần (xem analytics_mo_rong.py)
        ("Giữ chân D7 (%)", t["mo_rong"]["giu_chan"]["tong"]["d7"]["pct"],
         p["mo_rong"]["giu_chan"]["tong"]["d7"]["pct"]),
        ("Giữ chân D30 (%)", t["mo_rong"]["giu_chan"]["tong"]["d30"]["pct"],
         p["mo_rong"]["giu_chan"]["tong"]["d30"]["pct"]),
        ("Thời gian TB mỗi phiên (giây)", t["mo_rong"]["thoi_gian"].get("tb_phien_giay"),
         p["mo_rong"]["thoi_gian"].get("tb_phien_giay")),
        ("Lượt phản hồi", ph_t["so_luot"], ph_p["so_luot"]),
        ("Số sao trung bình (1–5)", ph_t["sao_tb"], ph_p["sao_tb"]),
        ("NPS (−100 → +100)", nps_t, nps_p),
    ]
    tu = (den - timedelta(days=7)).astimezone(VN_TZ).strftime("%d/%m")
    toi = (den - timedelta(seconds=1)).astimezone(VN_TZ).strftime("%d/%m/%Y")
    o = [f"## Số liệu tuần {tu} – {toi}", "",
         "_Nguồn: bảng đo lường của nhóm tại historiai.org. Đếm theo thiết bị, gộp cả người chưa "
         "tạo tài khoản._", "",
         "| Chỉ số | Tuần này | Tuần trước | Thay đổi |", "|---|---:|---:|---:|"]
    for ten, a, b in chi_so:
        o.append(f"| {ten} | {'—' if a is None else a} | {'—' if b is None else b} | {doi(a, b)} |")

    # Không tính gói thử 2.000đ của quản trị (xem services/doanh_thu.py).
    dt = t["doanh_thu"]
    o += ["", f"Doanh thu tuần: {dinh_dang_tien(dt['bay_ngay']['so_tien'])} đ · "
              f"{dt['bay_ngay']['so_don']} đơn · {dt['premium']['dang_co']} người đang có Premium"]

    o += ["", "### Phễu tuần này", "", "| Bậc | Số người | % so với bậc đầu |", "|---|---:|---:|"]
    o += [f"| {f['step']} | {f['people']} | {f['pct_of_top']}% |" for f in t["funnel"]]

    o += ["", "### Khách đến từ đâu (tuần này)", "",
          "| Nguồn | Kênh | Chiến dịch | Nội dung / group | Người vào | Đăng ký | Tỉ lệ ĐK |",
          "|---|---|---|---|---:|---:|---:|"]
    o += [f"| {x['nguon']} | {x['kenh'] or '—'} | {x['chien_dich'] or '—'} | {x['noi_dung'] or '—'} "
          f"| {x['nguoi']} | {x['dang_ky']} | {x['ti_le_dang_ky']}% |" for x in t["nguon"][:10]]

    o += ["", "### Phản hồi người dùng (tuần này)", ""]
    if ph_t["so_luot"]:
        n = ph_t["nps"]
        o.append(f"- {ph_t['so_luot']} lượt phản hồi · sao trung bình {ph_t['sao_tb'] or '—'} · "
                 f"tỉ lệ người được hỏi chịu trả lời {ph_t['ti_le_tra_loi']}%")
        if n:
            o.append(f"- NPS {n['diem']} ({n['so']} người trả lời: ủng hộ {n['ung_ho']}% · "
                     f"trung lập {n['trung_lap']}% · phản đối {n['phan_doi']}%)")
        if ph_t["muon_them"]:
            o.append("- Muốn app có thêm: " + " · ".join(
                f"{x['slug']} ({x['so']})" for x in ph_t["muon_them"][:5]))
        gy = ph_t["gop_y_moi"][:5]
        if gy:
            o += ["", "Góp ý mới nhất:"]
            o += [f"- “{g['gop_y'][:200]}” — {g['ngu_canh']}, {g['diem'] or '?'} sao, nguồn {g['nguon']}"
                  for g in gy]
    else:
        o.append("- Chưa có phản hồi trong tuần.")
    return "\n".join(o) + "\n"
