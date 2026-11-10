"""B7 — Xuất nội dung đạt chuẩn ra tệp seed, dựng trang hàng chờ, và (trên VPS) nạp vào app.

KHÔNG GHI ĐÈ NỘI DUNG NHÓM VIẾT TAY
    Tệp seed chính (backend/data/seed_data.json) do nhóm viết và giữ nguyên.
    Đường ống ghi ra tệp RIÊNG seed_lam_giau.json, và mọi thứ nó mang vào đều
    nằm ở CỘT MỚI (summary_thcs, summary_thpt, curriculum, sources,
    verified_facts). Tóm tắt, persona và mô tả cổ vật cũ không bị động tới.

NẠP VÀO APP (chỉ khi chạy trên VPS với --nap)
    1. Sao lưu CSDL bằng API backup của sqlite (an toàn khi dịch vụ đang ghi).
    2. Chép tệp seed vào backend, chạy seed bằng chính môi trường của backend.
    3. Gọi API đếm lại, so với số trong tệp seed. Lệch là ghi lỗi vào nhật ký.
    Backend chưa có bản biết đọc seed_lam_giau.json thì bỏ qua bước nạp.

RA
    ket_qua/seed_lam_giau.json
    ket_qua/hang_cho/bao_cao.html   — trang duy nhất người duyệt cần đọc
"""
from __future__ import annotations

import html
import json
import re
import shutil
import sqlite3
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from chung import CACHE, KET_QUA, bi_loai_tru, doc_cau_hinh, doc_json, ghi_json, ghi_log, tai

HANG_CHO = KET_QUA / "hang_cho"
HANG_CHO.mkdir(parents=True, exist_ok=True)
BACKEND = Path("/home/giapdn/historiai/backend")
WEB = Path("/home/giapdn/historiai/web")
API = "https://historiai.anhzap.shop/api/v1"
MUC_DO = {"biet": 1, "hieu": 2, "van_dung": 3}


def era_theo_nam(nam: int) -> str:
    if nam < 938:
        return "co-dai"
    return "phong-kien" if nam < 1858 else "hien-dai"


def tieu_de_hien_thi(t: str) -> str:
    """'Trận Bạch Đằng (938)' → 'Trận Bạch Đằng'. Năm đã có cột riêng."""
    return re.sub(r"\s*\([^)]*\)\s*$", "", t).strip()


def nam_du_phong(tieu_de: str, b4: dict) -> tuple[int | None, str | None]:
    """Năm khi Wikidata không ghi: năm trong ngoặc ở tiêu đề bài, rồi năm xuất hiện
    nhiều nhất trong các mệnh đề hạng A (hoà thì lấy năm sớm nhất).

    Chỉ lấy từ mệnh đề HẠNG A — tức năm đó đã được ≥ 2 nguồn cùng ghi — nên
    không có chỗ cho một năm do mô hình tự nghĩ ra.
    """
    m = re.search(r"\((\d{1,4})\s*(?:[–-]\s*\d{1,4})?\)", tieu_de)
    if m:
        return int(m.group(1)), "năm ở tiêu đề bài"
    dem: dict[int, int] = {}
    for md in b4.get("menh_de", []):
        if md.get("hang") != "A":
            continue
        for so, tcn in re.findall(r"năm\s+(\d{1,4})(\s*TCN)?", md["noi_dung"]):
            n = -int(so) if tcn.strip() else int(so)
            dem[n] = dem.get(n, 0) + 1
    if not dem:
        return None, None
    nam = sorted(dem, key=lambda n: (-dem[n], n))[0]
    return nam, "năm nhắc nhiều nhất trong mệnh đề hạng A"


def nguon_cua(slug: str) -> list[dict]:
    tl = doc_json(CACHE / "tai_lieu" / f"{slug}.json") or {}
    ra = []
    wp = tl.get("wikipedia")
    if wp:
        ra.append({"ten": f"Wikipedia tiếng Việt — {wp['tieu_de']}", "url": wp["url"],
                   "phien_ban": wp["revid"], "giay_phep": wp["giay_phep"]})
    for d in {(x["chuong"], x["revid"]) for x in (tl.get("vnsl") or {}).get("doan", [])}:
        ra.append({"ten": f"Việt Nam sử lược (Trần Trọng Kim) — {d[0].split('/', 1)[-1]}",
                   "url": "https://vi.wikisource.org/wiki/" + d[0].replace(" ", "_"),
                   "phien_ban": d[1], "giay_phep": "Phạm vi công cộng"})
    en = tl.get("enwiki")
    if en:
        ra.append({"ten": f"Wikipedia tiếng Anh — {en['tieu_de']}", "url": en["url"],
                   "phien_ban": en["revid"], "giay_phep": en["giay_phep"]})
    wd = tl.get("wikidata")
    if wd:
        ra.append({"ten": "Wikidata", "url": wd["url"], "giay_phep": "CC0"})
    anh = tl.get("anh")
    if anh and not anh.get("bi_loai"):
        ra.append({"ten": f"Ảnh: {anh['ten_tep']}" + (f" — {anh['tac_gia']}" if anh.get("tac_gia") else ""),
                   "url": anh["trang"], "giay_phep": anh["giay_phep"]})
    return ra


def chuong_trinh_cua(khung: dict, ma_ds: list[str]) -> list[dict]:
    theo_ma = {c["ma"]: c for c in khung["chu_de"]}
    return [{"ma": m, "cap": theo_ma[m]["cap"], "lop": theo_ma[m]["lop"], "chu_de": theo_ma[m]["chu_de"]}
            for m in ma_ds if m in theo_ma]


def dung_seed(ch: dict) -> tuple[dict, dict]:
    khung = doc_json(KET_QUA / "b0_khung.json")
    b1 = doc_json(KET_QUA / "b1_thuc_the.json")
    b2 = doc_json(KET_QUA / "b2_tong_hop.json", {})
    seed = {"tao_luc": datetime.now().isoformat(timespec="seconds"),
            "events": [], "quiz": [], "figures": [], "artifacts": []}
    hang_cho = {"su_kien_khong_len": [], "tom_tat_loai": [], "cau_hoi_loai": [], "menh_de_c": [],
                "trich_dan_loai": 0, "goi_y_b1_loai": b1.get("bi_loai", []), "nguoi_duyet_loai": []}
    # Danh sách người duyệt dán lại từ nút "Chép danh sách loại" của trang duyệt:
    # mỗi dòng "Q|<slug>|<câu hỏi>" hoặc "E|<slug>". Mục có tên ở đây không bao giờ lên app.
    tep_loai = KET_QUA / "da_loai.txt"
    da_loai = {d.strip() for d in tep_loai.read_text(encoding="utf-8").splitlines()
               if d.strip()} if tep_loai.exists() else set()

    hang_cho["loai_tru"] = [t["bai_wp"]["title"] for t in b1["thuc_the"]
                            if bi_loai_tru(t, ch) and t.get("bai_wp")]
    for tt in b1["thuc_the"]:
        slug = tt["slug"]
        if bi_loai_tru(tt, ch):
            continue
        b6 = doc_json(KET_QUA / "b6" / f"{slug}.json")
        b4 = doc_json(KET_QUA / "b4" / f"{slug}.json") or {"menh_de": []}
        b3 = doc_json(KET_QUA / "b3" / f"{slug}.json") or {}
        hang_cho["trich_dan_loai"] += len(b3.get("bi_loai", []))
        theo_id = {m["id"]: m for m in b4["menh_de"]}
        for m in b4["menh_de"]:
            if m["hang"] == "C" and m["nguon"] == "wikipedia":
                hang_cho["menh_de_c"].append({"slug": slug, **m,
                                              "voi": [theo_id.get(x["voi"], {}) for x in m["mau_thuan"]]})
        if not b6:
            continue
        chuong_trinh = chuong_trinh_cua(khung, tt["ma"])
        lop = sorted({c["lop"] for c in chuong_trinh})
        nguon = nguon_cua(slug)

        if tt["loai"] == "su_kien":
            if b6.get("tom_tat_bi_loai"):
                hang_cho["tom_tat_loai"].append({"slug": slug, **b6["tom_tat_bi_loai"]})
            for q in b6.get("cau_hoi_bi_loai", []):
                hang_cho["cau_hoi_loai"].append({"slug": slug, **q,
                                                 "can_cu": [theo_id.get(i, {}) for i in q.get("menh_de", [])]})
            tom = b6.get("tom_tat") or {}
            cau_hoi = b6.get("cau_hoi", [])
            nam = (b2.get(slug) or {}).get("nam")
            nguon_nam = "Wikidata" if nam is not None else None
            if nam is None:
                nam, nguon_nam = nam_du_phong(tt["bai_wp"]["title"], b4)
            if not tt.get("co_san"):
                ly_do = None
                if nam is None:
                    ly_do = "không xác định được năm từ nguồn"
                elif not tom:
                    ly_do = "tóm tắt không qua cổng kiểm"
                elif len(cau_hoi) < ch["sinh"]["cau_hoi_toi_thieu_de_len_app"]:
                    ly_do = f"chỉ {len(cau_hoi)} câu hỏi qua cổng kiểm (cần ≥ {ch['sinh']['cau_hoi_toi_thieu_de_len_app']})"
                if ly_do:
                    hang_cho["su_kien_khong_len"].append({"slug": slug, "ten": tt["bai_wp"]["title"],
                                                          "ly_do": ly_do})
                    continue
            if f"E|{slug}" in da_loai:
                hang_cho["nguoi_duyet_loai"].append(f"E|{slug}")
                continue
            anh = (doc_json(CACHE / "tai_lieu" / f"{slug}.json") or {}).get("anh") or {}
            e = {"slug": slug, "summary_thcs": tom.get("thcs"), "summary_thpt": tom.get("thpt"),
                 "grades": ",".join(str(x) for x in lop), "curriculum": chuong_trinh, "sources": nguon,
                 "moi": not tt.get("co_san"), "nguon_nam": nguon_nam}
            if not tt.get("co_san"):
                e.update({"title": tieu_de_hien_thi(tt["bai_wp"]["title"]), "year": int(nam),
                          "period": tom.get("thoi_ky") or None, "era": era_theo_nam(int(nam)),
                          "features": "timeline,quiz",
                          "anh_nguon": anh.get("url") if anh and not anh.get("bi_loai") else None})
            seed["events"].append(e)
            for q in cau_hoi:
                if f"Q|{slug}|{q['cau_hoi']}" in da_loai:
                    hang_cho["nguoi_duyet_loai"].append(f"Q|{slug}|{q['cau_hoi']}")
                    continue
                can_cu = [theo_id[i] for i in q["menh_de"] if i in theo_id]
                seed["quiz"].append({
                    "event_slug": slug, "question": q["cau_hoi"],
                    "option_a": q["phuong_an"]["a"], "option_b": q["phuong_an"]["b"],
                    "option_c": q["phuong_an"]["c"], "option_d": q["phuong_an"]["d"],
                    "correct_option": q["dap_an"].upper(), "explanation": q["giai_thich"],
                    "difficulty": MUC_DO.get(q["muc_do"], 1),
                    "curriculum_ref": q.get("yccd"),
                    "grade_min": lop[0] if lop else None,
                    "source_claims": [{"noi_dung": m["noi_dung"], "trich_dan": m["trich_dan"],
                                       "url": m.get("url")} for m in can_cu],
                    # Mọi căn cứ đều chỉ nhờ cặp Wikipedia Việt–Anh xác nhận → soát kỹ
                    "chi_viet_anh": bool(can_cu) and all(m.get("chi_viet_anh") for m in can_cu),
                })
        elif tt["loai"] == "nhan_vat":
            seed["figures"].append({"slug": slug, "verified_facts": b6.get("khoi_su_lieu") or None,
                                    "sources": nguon})
        else:
            seed["artifacts"].append({"slug": slug, "sources": nguon})
    return seed, hang_cho


# ───────────────────────── trang hàng chờ ─────────────────────────

def _e(s) -> str:
    return html.escape(str(s or ""))


def dung_bao_cao(seed: dict, hang_cho: dict) -> str:
    """Trang tĩnh, tự chứa. Người duyệt tích ô những mục muốn LOẠI, bấm nút để
    chép danh sách gửi lại. Trạng thái tích lưu trong trình duyệt để đọc dở
    mai đọc tiếp được."""
    ev_moi = [e for e in seed["events"] if e.get("moi")]
    ev_cu = [e for e in seed["events"] if not e.get("moi")]
    theo_su_kien: dict[str, list] = {}
    for q in seed["quiz"]:
        theo_su_kien.setdefault(q["event_slug"], []).append(q)

    def the_cau_hoi(q, k):
        dung = q["correct_option"]
        pa = "".join(f"<li class='{'dung' if c.upper() == dung else ''}'>{c.upper()}. {_e(q['option_' + c])}</li>"
                     for c in "abcd")
        can_cu = "".join(f"<blockquote>“{_e(m['trich_dan'])}” <a href='{_e(m.get('url'))}' target='_blank'>nguồn</a></blockquote>"
                         for m in q["source_claims"])
        ma = f"Q|{q['event_slug']}|{q['question']}"
        canh_bao = ("<p class='cb'>⚠ Chỉ Wikipedia tiếng Việt và tiếng Anh cùng xác nhận — hai bản hay "
                    "dịch qua lại nên không hẳn độc lập. Soát kỹ câu này.</p>") if q.get("chi_viet_anh") else ""
        return (f"<div class='the'><label class='loai'><input type='checkbox' data-ma='{_e(ma)}'> Loại câu này</label>"
                f"<p class='hoi'>{k}. {_e(q['question'])}</p>{canh_bao}<ul>{pa}</ul>"
                f"<p class='gt'>{_e(q['explanation'])}</p>"
                + (f"<p class='yc'>Yêu cầu cần đạt: {_e(q['curriculum_ref'])}</p>" if q.get("curriculum_ref") else "")
                + f"<details><summary>Căn cứ ({len(q['source_claims'])})</summary>{can_cu}</details></div>")

    def khoi_su_kien(e):
        ten = e.get("title") or e["slug"]
        cau = theo_su_kien.get(e["slug"], [])
        ct = " · ".join(f"Lớp {c['lop']}" for c in e["curriculum"])
        ghi_nam = (f" <small>(năm lấy từ {_e(e['nguon_nam'])})</small>"
                   if e.get("moi") and e.get("nguon_nam") and e["nguon_nam"] != "Wikidata" else "")
        return (f"<section class='sk'><h3>{_e(ten)} {('· ' + str(e['year'])) if e.get('year') else ''}{ghi_nam}"
                f" <small>{_e(ct)}</small></h3>"
                + (f"<label class='loai'><input type='checkbox' data-ma='E|{_e(e['slug'])}'> Loại cả sự kiện này</label>" if e.get("moi") else "")
                + (f"<p class='tt'><b>THCS:</b> {_e(e['summary_thcs'])}</p><p class='tt'><b>THPT:</b> {_e(e['summary_thpt'])}</p>"
                   if e.get("summary_thcs") else "<p class='tt mo'>Tóm tắt không qua cổng kiểm — giữ bản cũ.</p>")
                + "".join(the_cau_hoi(q, k + 1) for k, q in enumerate(cau)) + "</section>")

    loai_cau = "".join(
        f"<div class='the xam'><p class='hoi'>{_e(q.get('cau_hoi'))}</p><p class='ly'>Lý do loại: {_e(q.get('ly_do'))}</p></div>"
        for q in hang_cho["cau_hoi_loai"][:400])
    loai_sk = "".join(f"<li><b>{_e(x['ten'])}</b> — {_e(x['ly_do'])}</li>" for x in hang_cho["su_kien_khong_len"])
    md_c = "".join(
        f"<div class='the xam'><p><b>{_e(m['slug'])}</b>: {_e(m['noi_dung'])}</p>"
        + "".join(f"<p class='ly'>↔ {_e(v.get('noi_dung'))} <i>({_e(v.get('nguon'))})</i></p>" for v in m["voi"])
        + "</div>" for m in hang_cho["menh_de_c"][:200])

    so_cau = len(seed["quiz"])
    return f"""<!doctype html><html lang="vi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow">
<title>Duyệt dữ liệu HistoriAI</title>
<style>
:root{{--nen:#FDF9F4;--nen2:#FBF3E6;--do:#BA2323;--vang:#D4AF37;--chu:#2B1410;--nhat:#7C5A4A;--xanh:#2E7D32}}
@media (prefers-color-scheme:dark){{:root:not([data-theme=light]){{--nen:#1c1412;--nen2:#271c19;--chu:#f3e9e2;--nhat:#c4a99a}}}}
body{{margin:0;background:var(--nen);color:var(--chu);font:15px/1.6 Inter,system-ui,sans-serif}}
main{{max-width:880px;margin:0 auto;padding:16px}}
h1,h2,h3{{font-family:"Times New Roman",serif;color:var(--do)}} h3 small{{color:var(--nhat);font-size:13px;font-family:Inter,sans-serif}}
.tong{{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px}}
.tong div{{background:var(--nen2);border-left:4px solid var(--vang);padding:10px 12px;border-radius:0 8px 8px 0}}
.tong b{{display:block;font-size:24px;color:var(--do)}}
.the{{background:var(--nen2);border-radius:10px;padding:12px 14px;margin:10px 0;position:relative}}
.the.xam{{opacity:.85}} .hoi{{font-weight:600;margin:0 0 6px;padding-right:110px}} ul{{margin:4px 0 6px;padding-left:18px}}
li.dung{{color:var(--xanh);font-weight:700}} .gt,.yc,.ly{{color:var(--nhat);margin:4px 0;font-size:14px}}
.loai{{position:absolute;top:10px;right:12px;font-size:13px;color:var(--do)}} section .loai{{position:static;display:block}}
blockquote{{margin:6px 0;padding:4px 10px;border-left:3px solid var(--vang);font-size:14px}}
.cb{{background:#FFF3CD;color:#7A4B00;border-radius:6px;padding:6px 10px;font-size:13px;margin:4px 0 8px}}
.tt{{background:var(--nen2);padding:10px 12px;border-radius:8px}} .mo{{color:var(--nhat)}}
#thanh{{position:sticky;bottom:0;background:var(--do);color:#fff;padding:10px 16px;display:flex;gap:12px;align-items:center;justify-content:space-between}}
#thanh button{{background:var(--vang);border:0;padding:8px 14px;border-radius:6px;font-weight:700;cursor:pointer}}
a{{color:var(--do)}}
</style></head><body><main>
<h1>Duyệt dữ liệu làm giàu</h1>
<p>Tạo lúc {_e(seed['tao_luc'])}. Mọi nội dung dưới mục <b>Đã lên app</b> đã qua đủ cổng kiểm tự động
(trích dẫn nguyên văn · ≥ 2 nguồn độc lập · làm bài mù). Tích ô những mục bạn thấy SAI, rồi bấm nút cuối trang
để chép danh sách gửi lại. Các ô đã tích được nhớ trong trình duyệt này.</p>
<div class="tong">
<div><b>{len(ev_cu)}</b>sự kiện có sẵn được bổ sung</div>
<div><b>{len(ev_moi)}</b>sự kiện mới</div>
<div><b>{so_cau}</b>câu hỏi lên app</div>
<div><b>{len(hang_cho['cau_hoi_loai'])}</b>câu hỏi bị cổng kiểm loại</div>
<div><b>{hang_cho['trich_dan_loai']}</b>mệnh đề bị loại vì trích dẫn sai</div>
<div><b>{len(hang_cho['menh_de_c'])}</b>điểm các nguồn ghi khác nhau</div>
</div>
<h2>Đã lên app — sự kiện có sẵn</h2>{''.join(khoi_su_kien(e) for e in ev_cu)}
<h2>Đã lên app — sự kiện mới</h2>{''.join(khoi_su_kien(e) for e in ev_moi) or '<p class=mo>Chưa có.</p>'}
<h2>Sự kiện không lên app</h2><ul>{loai_sk or '<li>Không có.</li>'}</ul>
<p class="mo">Loại khỏi vòng 2 vì không phải sự kiện lịch sử Việt Nam có mốc năm: {_e(', '.join(hang_cho.get('loai_tru', [])) or 'không có')}.</p>
<h2>Điểm các nguồn ghi khác nhau (hạng C)</h2><p class="mo">Không dùng cho quiz. Để tham khảo.</p>{md_c or '<p class=mo>Không có.</p>'}
<h2>Câu hỏi bị cổng kiểm loại</h2><p class="mo">Để biết cổng kiểm đang chặn những gì. Không cần duyệt.</p>{loai_cau or '<p class=mo>Không có.</p>'}
</main>
<div id="thanh"><span id="dem">0 mục đã tích</span><button id="chep">Chép danh sách loại</button></div>
<script>
const K='duyet-historiai';let s={{}};try{{s=JSON.parse(localStorage.getItem(K)||'{{}}')}}catch(e){{}}
const o=[...document.querySelectorAll('input[data-ma]')];
function cap(){{document.getElementById('dem').textContent=o.filter(x=>x.checked).length+' mục đã tích';try{{localStorage.setItem(K,JSON.stringify(s))}}catch(e){{}}}}
o.forEach(x=>{{x.checked=!!s[x.dataset.ma];x.onchange=()=>{{s[x.dataset.ma]=x.checked;cap()}}}});cap();
document.getElementById('chep').onclick=async()=>{{const t=o.filter(x=>x.checked).map(x=>x.dataset.ma).join('\\n')||'(không loại mục nào)';
try{{await navigator.clipboard.writeText(t);alert('Đã chép. Dán lại cho Claude.')}}catch(e){{prompt('Chép đoạn này:',t)}}}};
</script></body></html>"""


# ───────────────────────── nạp vào app (VPS) ─────────────────────────

def tai_anh(seed: dict) -> None:
    thu_muc = WEB / "thumbnails" / "su-kien"
    thu_muc.mkdir(parents=True, exist_ok=True)
    for e in seed["events"]:
        url = e.pop("anh_nguon", None)
        if not e.get("moi"):
            continue
        tep = thu_muc / f"{e['slug']}.jpg"
        if url and not tep.exists():
            try:
                tep.write_bytes(tai(url, dang="bin"))
            except Exception as loi:
                ghi_log(f"  không tải được ảnh {e['slug']}: {loi}")
        e["thumbnail_url"] = f"{{ASSET}}/thumbnails/su-kien/{e['slug']}.jpg" if tep.exists() else None


def nap(seed: dict) -> None:
    seed_py = BACKEND / "app" / "db" / "seed.py"
    if "seed_lam_giau" not in seed_py.read_text(encoding="utf-8"):
        ghi_log("B7: backend chưa có bản đọc được seed_lam_giau.json — bỏ qua bước nạp")
        return
    db = BACKEND.parent / "data" / "historiai.db"
    sao_luu = BACKEND.parent / "data" / "sao_luu"
    sao_luu.mkdir(exist_ok=True)
    dich = sao_luu / f"historiai_truoc_lam_giau_{datetime.now():%Y%m%d_%H%M}.db"
    with sqlite3.connect(db) as nguon, sqlite3.connect(dich) as den:
        nguon.backup(den)
    ghi_log(f"B7: đã sao lưu CSDL → {dich.name}")

    tai_anh(seed)
    ghi_json(BACKEND / "data" / "seed_lam_giau.json", seed)
    r = subprocess.run([str(BACKEND / ".venv" / "bin" / "python"), "-m", "app.db.seed"],
                       cwd=BACKEND, capture_output=True, text=True, timeout=600)
    ghi_log("B7 seed:", (r.stdout or "").strip()[-400:], (r.stderr or "").strip()[-400:])
    if r.returncode != 0:
        ghi_log("B7: SEED LỖI — CSDL vẫn còn bản sao lưu ở trên")
        return
    su_kien = tai(f"{API}/events", cache=False)
    co = {e["slug"] for e in su_kien}
    thieu = [e["slug"] for e in seed["events"] if e["slug"] not in co]
    ghi_log(f"B7 kiểm sau nạp: API có {len(su_kien)} sự kiện; "
            + (f"THIẾU {thieu}" if thieu else "đủ mọi sự kiện trong seed"))


def main(nap_vao_app: bool = False) -> dict:
    ch = doc_cau_hinh()
    seed, hang_cho = dung_seed(ch)
    if nap_vao_app:
        nap(seed)
    ghi_json(KET_QUA / "seed_lam_giau.json", seed)
    ghi_json(HANG_CHO / "hang_cho.json", hang_cho)
    (HANG_CHO / "bao_cao.html").write_text(dung_bao_cao(seed, hang_cho), encoding="utf-8")
    moi = sum(1 for e in seed["events"] if e.get("moi"))
    ghi_log(f"B7: {len(seed['events'])} sự kiện ({moi} mới), {len(seed['quiz'])} câu hỏi, "
            f"{len(seed['figures'])} vĩ nhân, {len(seed['artifacts'])} cổ vật")
    return seed


if __name__ == "__main__":
    main("--nap" in sys.argv)
