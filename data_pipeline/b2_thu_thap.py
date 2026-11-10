"""B2 — Thu thập: Wikipedia, Wikidata, Việt Nam sử lược, ảnh Commons.

Không gọi mô hình ngôn ngữ ở bước này — chạy được ngay cả khi chưa có khoá.

Mỗi tài liệu lưu kèm SIÊU DỮ LIỆU NGUỒN (URL, mã phiên bản trang, giấy phép)
để sau này mọi câu hỏi trong app lần ngược được tới đúng phiên bản trang đã đọc.

VIỆT NAM SỬ LƯỢC VÀ HAI TRẬN BẠCH ĐẰNG
    Cả hai trận đều có chữ "Bạch Đằng". Để không lấy nhầm đoạn trận 1288 làm
    nguồn cho trận 938, mỗi chương được gắn khoảng năm đọc từ tiêu đề chương
    (vd "NHÀ NGÔ (939 — 965)"), và chỉ những chương có khoảng năm phủ năm của sự
    kiện mới được tìm.

RA
    cache/tai_lieu/<slug>.json    — tài liệu thô theo từng nguồn
    ket_qua/b2_tong_hop.json      — năm sự kiện, ảnh, thống kê
"""
from __future__ import annotations

import html
import re

from chung import (CACHE, KET_QUA, bi_loai_tru, chuan_hoa_so_khop, doc_cau_hinh, doc_json, ghi_json,
                   ghi_log, nfc, tai)

API_WP = "https://vi.wikipedia.org/w/api.php"
API_WD = "https://www.wikidata.org/w/api.php"
API_WS = "https://vi.wikisource.org/w/api.php"
API_CM = "https://commons.wikimedia.org/w/api.php"
TAI_LIEU = CACHE / "tai_lieu"
TAI_LIEU.mkdir(parents=True, exist_ok=True)

GIAY_PHEP_NHAN = ("pd", "public domain", "cc0", "cc by", "cc-by", "cc by-sa", "cc-by-sa")


# ───────────────────────── Wikipedia ─────────────────────────

def lay_wikipedia(tieu_de: str, bo_muc: list[str]) -> dict:
    j = tai(API_WP, {"action": "query", "format": "json", "formatversion": 2, "redirects": 1,
                     "prop": "extracts|revisions|pageimages", "explaintext": 1,
                     "exsectionformat": "wiki", "rvprop": "ids", "piprop": "name|original",
                     "titles": tieu_de})
    p = j["query"]["pages"][0]
    van_ban = nfc(p.get("extract", ""))
    # Cắt bỏ các mục không phải sử liệu (Tham khảo, Xem thêm…) cùng mọi mục con của chúng
    doan, bo = [], False
    for dong in van_ban.split("\n"):
        m = re.match(r"^(=+)\s*(.*?)\s*=+$", dong)
        if m:
            if len(m.group(1)) == 2:
                bo = m.group(2) in bo_muc
            if bo:
                continue
        if not bo:
            doan.append(dong)
    van_ban = re.sub(r"\n{3,}", "\n\n", "\n".join(doan)).strip()
    return {
        "nguon": "wikipedia",
        "ten_nguon": "Wikipedia tiếng Việt",
        "tieu_de": p["title"],
        "url": f"https://vi.wikipedia.org/wiki/{p['title'].replace(' ', '_')}",
        "revid": p["revisions"][0]["revid"],
        "giay_phep": "CC BY-SA 4.0",
        "van_ban": van_ban,
        "anh": p.get("pageimage"),
    }


# ───────────────────────── Wikidata ─────────────────────────

THUOC_TINH = {
    # mã: (nhãn tiếng Việt, loại mệnh đề)
    "P585": ("Thời điểm", "nien_dai"), "P580": ("Bắt đầu", "nien_dai"),
    "P582": ("Kết thúc", "nien_dai"), "P571": ("Thành lập", "nien_dai"),
    "P576": ("Chấm dứt", "nien_dai"), "P569": ("Sinh", "nien_dai"), "P570": ("Mất", "nien_dai"),
    "P276": ("Địa điểm", "dia_diem"), "P17": ("Quốc gia", "dia_diem"),
    "P19": ("Nơi sinh", "dia_diem"), "P20": ("Nơi mất", "dia_diem"),
    "P710": ("Bên tham gia", "nhan_vat"), "P1344": ("Tham gia sự kiện", "su_kien"),
    "P361": ("Là một phần của", "su_kien"), "P39": ("Chức vụ", "nhan_vat"),
    "P22": ("Cha", "nhan_vat"), "P25": ("Mẹ", "nhan_vat"),
    "P186": ("Chất liệu", "dac_diem"), "P2048": ("Chiều cao", "so_lieu"),
    "P2386": ("Đường kính", "so_lieu"), "P2049": ("Chiều rộng", "so_lieu"),
}


def _nam(gia_tri: dict) -> tuple[str, int | None]:
    t = gia_tri.get("time", "")
    m = re.match(r"([+-])(\d+)-(\d\d)-(\d\d)", t)
    if not m:
        return t, None
    nam = int(m.group(2)) * (-1 if m.group(1) == "-" else 1)
    do_chinh_xac = gia_tri.get("precision", 9)
    if do_chinh_xac >= 11 and m.group(3) != "00":
        chu = f"ngày {int(m.group(4))}/{int(m.group(3))}/{abs(nam)}"
    elif do_chinh_xac == 10:
        chu = f"tháng {int(m.group(3))}/{abs(nam)}"
    elif do_chinh_xac <= 7:
        chu = f"thế kỷ {abs(nam) // 100 + 1}"
        nam = None if do_chinh_xac < 7 else nam
    else:
        chu = f"năm {abs(nam)}"
    if nam is not None and nam < 0:
        chu += " TCN"
    return chu, nam


def lay_wikidata(qid: str) -> dict:
    j = tai(API_WD, {"action": "wbgetentities", "format": "json", "ids": qid,
                     "props": "claims|labels", "languages": "vi"})
    thuc = j["entities"][qid]
    menh_de, can_nhan = [], set()
    tho = []
    for ma, (nhan, loai) in THUOC_TINH.items():
        for c in thuc.get("claims", {}).get(ma, []):
            dv = c.get("mainsnak", {}).get("datavalue")
            if not dv:
                continue
            tho.append((ma, nhan, loai, dv))
            if dv["type"] == "wikibase-entityid":
                can_nhan.add(dv["value"]["id"])
    nhan_vi = {}
    ds = sorted(can_nhan)
    for i in range(0, len(ds), 50):
        jj = tai(API_WD, {"action": "wbgetentities", "format": "json", "ids": "|".join(ds[i:i + 50]),
                          "props": "labels", "languages": "vi"})
        for k, v in jj["entities"].items():
            if "vi" in v.get("labels", {}):
                nhan_vi[k] = v["labels"]["vi"]["value"]
    nam_su_kien = None
    for ma, nhan, loai, dv in tho:
        if dv["type"] == "time":
            chu, nam = _nam(dv["value"])
            if ma in ("P585", "P580", "P571") and nam_su_kien is None:
                nam_su_kien = nam
            menh_de.append({"noi_dung": f"{nhan}: {chu}", "loai": loai, "thuoc_tinh": ma,
                            "nam": nam})
        elif dv["type"] == "wikibase-entityid":
            k = dv["value"]["id"]
            if k in nhan_vi:   # không có nhãn tiếng Việt thì bỏ, không hiện mã Q cho học sinh
                menh_de.append({"noi_dung": f"{nhan}: {nhan_vi[k]}", "loai": loai, "thuoc_tinh": ma})
        elif dv["type"] == "quantity":
            so = dv["value"]["amount"].lstrip("+")
            menh_de.append({"noi_dung": f"{nhan}: {so}", "loai": loai, "thuoc_tinh": ma})
    return {
        "nguon": "wikidata", "ten_nguon": "Wikidata", "qid": qid,
        "url": f"https://www.wikidata.org/wiki/{qid}", "giay_phep": "CC0",
        "nhan": thuc.get("labels", {}).get("vi", {}).get("value"),
        "menh_de": menh_de, "nam": nam_su_kien,
    }


# ───────────────────────── Việt Nam sử lược ─────────────────────────

def _chu_tu_html(s: str) -> str:
    s = re.sub(r"<style.*?</style>|<script.*?</script>", "", s, flags=re.S)
    s = re.sub(r"<(sup|span)[^>]*class=\"[^\"]*(reference|noprint|ws-noexport)[^\"]*\"[^>]*>.*?</\1>",
               "", s, flags=re.S)
    s = re.sub(r"</p>|<br\s*/?>|</h\d>|</li>|</div>", "\n", s)
    s = html.unescape(re.sub(r"<[^>]+>", "", s))
    s = s.replace("​", "")
    return nfc(re.sub(r"\n\s*\n+", "\n\n", s)).strip()


def chi_muc_vnsl() -> list[dict]:
    """Toàn bộ các chương Việt Nam sử lược, mỗi chương kèm khoảng năm. Tải một lần."""
    tep = CACHE / "vnsl_chi_muc.json"
    cu = doc_json(tep)
    if cu:
        return cu
    trang, tiep = [], None
    while True:
        p = {"action": "query", "format": "json", "list": "allpages",
             "apprefix": "Việt Nam sử lược/", "aplimit": 500}
        if tiep:
            p["apcontinue"] = tiep
        j = tai(API_WS, p)
        trang += [x["title"] for x in j["query"]["allpages"]]
        tiep = j.get("continue", {}).get("apcontinue")
        if not tiep:
            break
    chuong = []
    for t in trang:
        if not re.search(r"/Chương|/Phụ lục|/Tổng kết", t):
            continue
        j = tai(API_WS, {"action": "parse", "page": t, "prop": "text|revid", "format": "json",
                         "formatversion": 2})
        if "parse" not in j:
            continue
        chu = _chu_tu_html(j["parse"]["text"])
        m = re.search(r"\((\d{3,4})\s*[—–-]\s*(\d{3,4})\)", chu)
        chuong.append({"tieu_de": t, "revid": j["parse"]["revid"], "van_ban": chu,
                       "tu_nam": int(m.group(1)) if m else None,
                       "den_nam": int(m.group(2)) if m else None})
    ghi_log(f"  VNSL: {len(chuong)} chương, {sum(c['tu_nam'] is not None for c in chuong)} chương có khoảng năm")
    ghi_json(tep, chuong)
    return chuong


_LA_MA = {"I": 1, "V": 5, "X": 10, "L": 50}


def _so_la_ma(s: str) -> int:
    tong = 0
    for i, c in enumerate(s):
        v = _LA_MA.get(c, 0)
        tong += -v if i + 1 < len(s) and _LA_MA.get(s[i + 1], 0) > v else v
    return tong


def gan_khoang_nam(chuong: list[dict]) -> list[dict]:
    """Khoảng năm của từng chương, suy theo THỨ TỰ TRONG SÁCH.

    Tiêu đề chương không đáng tin một mình: chương Bắc thuộc ghi nhiều khoảng
    (589–617, 618–907, 907–959) nên phải lấy cả dải; chương nhà Trần lại lọt một
    con số "(317 — 419)" trích từ sử Tàu. Sách đi theo thời gian, nên năm phải
    tăng dần theo chương: khoảng nào lùi hẳn về trước chương liền trước thì bỏ,
    chương nào không có năm thì lấy kẹp giữa hai chương hai bên.
    """
    def khoa(c):
        m = re.search(r"Quyển (\w+)/Phần (\w+)(?:/Chương (\w+))?", c["tieu_de"])
        if not m:
            return (9, 9, 999)
        ch = m.group(3)
        return (_so_la_ma(m.group(1)), _so_la_ma(m.group(2)), _so_la_ma(ch) if ch else 999)
    ds = sorted(chuong, key=khoa)
    truoc = -3000
    for c in ds:
        cap = [(int(a), int(b)) for a, b in
               re.findall(r"\((\d{3,4})\s*[—–-]\s*(\d{3,4})\)", c["van_ban"])]
        cap = [(a, b) for a, b in cap if a <= b and a >= truoc - 50]
        c["tu_nam"], c["den_nam"] = (min(a for a, _ in cap), max(b for _, b in cap)) if cap else (None, None)
        if c["tu_nam"] is not None:
            truoc = c["tu_nam"]
    for i, c in enumerate(ds):
        if c["tu_nam"] is None:
            lui = next((d["den_nam"] for d in reversed(ds[:i]) if d["den_nam"] is not None), None)
            toi = next((d["tu_nam"] for d in ds[i + 1:] if d["tu_nam"] is not None), None)
            c["tu_nam"] = lui if lui is not None else (toi if toi is not None else -3000)
            c["den_nam"] = toi if toi is not None else 3000
            c["tu_nam"], c["den_nam"] = sorted((c["tu_nam"], c["den_nam"]))
            c["suy_doan"] = True
    return ds


_TU_CHUNG = r"^(trận|khởi nghĩa|chiến tranh|cuộc|kháng chiến|chiến dịch|phong trào|nhà|hiệp định|hiệp ước|cải cách|chiến thắng)\s+"


def tu_khoa_chinh(tieu_de: str) -> list[str]:
    """'Trận Bạch Đằng (938)' → ['bạch đằng']; 'Trận Ngọc Hồi – Đống Đa' → ['ngọc hồi', 'đống đa']."""
    t = re.sub(r"\(.*?\)", "", tieu_de).strip()
    t = re.sub(_TU_CHUNG, "", t.lower()).strip()
    t = re.sub(_TU_CHUNG, "", t).strip()
    phan = [chuan_hoa_so_khop(x) for x in re.split(r"\s*[–—-]\s*|\s+lần thứ\s+", t) if x.strip()]
    return [p for p in phan if len(p) >= 4 and p not in TU_QUA_CHUNG]


# Từ nào gần như chương nào cũng có thì không dùng để tìm đoạn được
TU_QUA_CHUNG = {"nhất", "việt", "việt nam", "đại việt", "nam", "bắc", "tống", "minh",
                "nguyên", "thanh", "pháp", "mỹ", "quân", "nước"}

# Vòng 1: từ khoá viết tay cho những thực thể mà tên bài không đủ để tìm
TU_KHOA_VONG_1 = {
    "khang-chien-tong-981": ["hầu nhân bảo", "lê hoàn", "chi lăng", "tôn toàn hưng"],
    "quang-trung-1789": ["ngọc hồi", "đống đa", "tôn sĩ nghị", "hà hồi"],
    "lam-son-1428": ["lam sơn", "lê lợi", "chi lăng", "liễu thăng"],
    "bach-dang-938": ["bạch đằng", "hoằng tháo"],
    "bach-dang-1288": ["bạch đằng", "ô mã nhi"],
    "tran-hung-dao": ["hưng đạo", "trần quốc tuấn"],
    "quang-trung": ["nguyễn huệ", "quang trung", "bắc bình vương"],
}


def doan_vnsl(chuong: list[dict], tu_khoa: list[str], nam: int | None,
              gioi_han_ky_tu: int) -> list[dict]:
    """Các đoạn trong VNSL nhắc tới thực thể, kèm một đoạn ngữ cảnh mỗi bên."""
    if not tu_khoa:
        return []
    ra, tong = [], 0
    for c in gan_khoang_nam(chuong):
        if nam is not None and c["tu_nam"] is not None:
            le = 30 if c.get("suy_doan") else 15   # khoảng suy ra thì nới biên
            if not (c["tu_nam"] - le <= nam <= c["den_nam"] + le):
                continue
        doan = [d for d in c["van_ban"].split("\n\n") if d.strip()]
        chuan = [chuan_hoa_so_khop(d) for d in doan]
        trung = [i for i, d in enumerate(chuan) if any(k in d for k in tu_khoa)]
        if not trung:
            continue
        lay = sorted({j for i in trung for j in (i - 1, i, i + 1) if 0 <= j < len(doan)})
        for i in lay:
            if tong + len(doan[i]) > gioi_han_ky_tu:
                break
            ra.append({"chuong": c["tieu_de"], "revid": c["revid"], "van_ban": doan[i]})
            tong += len(doan[i])
    return ra


# ───────────────────────── Wikipedia tiếng Anh ─────────────────────────

BO_MUC_ANH = ["See also", "References", "Notes", "External links", "Further reading",
              "Bibliography", "Sources", "Citations", "In popular culture", "Footnotes"]


def lay_wikipedia_anh(qid: str) -> dict | None:
    """Bài Wikipedia tiếng Anh cùng thực thể (qua liên kết Wikidata). None nếu không có."""
    j = tai(API_WD, {"action": "wbgetentities", "format": "json", "ids": qid,
                     "props": "sitelinks", "sitefilter": "enwiki"})
    lk = j["entities"][qid].get("sitelinks", {}).get("enwiki")
    if not lk:
        return None
    jj = tai("https://en.wikipedia.org/w/api.php", {
        "action": "query", "format": "json", "formatversion": 2, "redirects": 1,
        "prop": "extracts|revisions", "explaintext": 1, "exsectionformat": "wiki",
        "rvprop": "ids", "titles": lk["title"]})
    p = jj["query"]["pages"][0]
    van_ban = nfc(p.get("extract", ""))
    doan, bo = [], False
    for dong in van_ban.split("\n"):
        m = re.match(r"^(=+)\s*(.*?)\s*=+$", dong)
        if m and len(m.group(1)) == 2:
            bo = m.group(2) in BO_MUC_ANH
        if not bo:
            doan.append(dong)
    return {"nguon": "enwiki", "ten_nguon": "Wikipedia tiếng Anh", "tieu_de": p["title"],
            "url": f"https://en.wikipedia.org/wiki/{p['title'].replace(' ', '_')}",
            "revid": p["revisions"][0]["revid"], "giay_phep": "CC BY-SA 4.0",
            "van_ban": re.sub(r"\n{3,}", "\n\n", "\n".join(doan)).strip()}


# ───────────────────────── Commons ─────────────────────────

def lay_anh(ten_tep: str | None) -> dict | None:
    if not ten_tep:
        return None
    j = tai(API_CM, {"action": "query", "format": "json", "formatversion": 2,
                     "titles": f"File:{ten_tep}", "prop": "imageinfo",
                     "iiprop": "url|extmetadata", "iiurlwidth": 800})
    p = j["query"]["pages"][0]
    if "imageinfo" not in p:
        return None
    ii = p["imageinfo"][0]
    md = ii.get("extmetadata", {})
    gp = re.sub(r"<[^>]+>", "", md.get("LicenseShortName", {}).get("value", "")).strip()
    if not any(k in gp.lower() for k in GIAY_PHEP_NHAN):
        return {"bi_loai": True, "ten_tep": ten_tep, "giay_phep": gp or "không rõ"}
    tac_gia = html.unescape(re.sub(r"<[^>]+>", "", md.get("Artist", {}).get("value", ""))).strip()
    return {"ten_tep": ten_tep, "url": ii.get("thumburl") or ii["url"],
            "trang": ii.get("descriptionurl"), "giay_phep": gp, "tac_gia": tac_gia[:200]}


# ───────────────────────── chạy ─────────────────────────

def main() -> None:
    ch = doc_cau_hinh()
    b1 = doc_json(KET_QUA / "b1_thuc_the.json")
    chuong = chi_muc_vnsl()
    tong_hop = doc_json(KET_QUA / "b2_tong_hop.json", {})
    for t in b1["thuc_the"]:
        if bi_loai_tru(t, ch):
            continue
        tep = TAI_LIEU / f"{t['slug']}.json"
        if tep.exists() and t["slug"] in tong_hop:
            # Bổ sung Wikipedia tiếng Anh cho sự kiện vòng 2 đã thu thập từ trước
            if t["vong"] == 2 and ch["vong_2"].get("wikipedia_anh"):
                tl = doc_json(tep)
                qid = (t.get("bai_wp") or {}).get("qid")
                if "enwiki" not in tl and qid:
                    tl["enwiki"] = lay_wikipedia_anh(qid)
                    ghi_json(tep, tl)
                    ghi_log(f"B2 {t['slug']}: thêm Wikipedia tiếng Anh — "
                            f"{len((tl['enwiki'] or {}).get('van_ban', ''))} ký tự")
            continue
        bai = t.get("bai_wp")
        if not bai:
            tong_hop[t["slug"]] = {"loi": "không có bài nguồn"}
            continue
        wp = lay_wikipedia(bai["title"], ch["thu_thap"]["bo_muc"])
        wd = lay_wikidata(bai["qid"]) if bai.get("qid") else None
        nam = (wd or {}).get("nam")
        if nam is None and t.get("nam_goi_y"):
            # Năm do mô hình gợi ý chỉ được nhận khi chính bài Wikipedia có ghi năm đó
            # ở phần mở đầu — không thì bỏ, thà thiếu năm còn hơn năm bịa.
            try:
                n = int(t["nam_goi_y"])
                if str(abs(n)) in wp["van_ban"][:1500]:
                    nam = n
            except (TypeError, ValueError):
                pass
        gioi_han = ch["thu_thap"]["ky_tu_moi_doan"] * (2 if t["vong"] == 1 else 1)
        vnsl = doan_vnsl(chuong, TU_KHOA_VONG_1.get(t["slug"]) or tu_khoa_chinh(bai["title"]),
                         nam if t["loai"] == "su_kien" else None, gioi_han)
        anh = lay_anh(wp.get("anh"))
        en = (lay_wikipedia_anh(bai["qid"]) if t["vong"] == 2 and bai.get("qid")
              and ch["vong_2"].get("wikipedia_anh") else None)
        ghi_json(tep, {"slug": t["slug"], "wikipedia": wp, "wikidata": wd, "enwiki": en,
                       "vnsl": {"nguon": "vnsl", "ten_nguon": "Việt Nam sử lược (Trần Trọng Kim, 1920)",
                                "giay_phep": "Phạm vi công cộng", "doan": vnsl},
                       "anh": anh})
        tong_hop[t["slug"]] = {"nam": nam, "ky_tu_wp": len(wp["van_ban"]),
                               "menh_de_wd": len((wd or {}).get("menh_de", [])),
                               "doan_vnsl": len(vnsl), "anh": bool(anh and not anh.get("bi_loai"))}
        ghi_log(f"B2 {t['slug']}: WP {len(wp['van_ban'])} ký tự · WD {tong_hop[t['slug']]['menh_de_wd']} "
                f"dữ kiện · VNSL {len(vnsl)} đoạn · năm {nam}")
        ghi_json(KET_QUA / "b2_tong_hop.json", tong_hop)
    ghi_json(KET_QUA / "b2_tong_hop.json", tong_hop)
    ghi_log(f"B2 xong: {len(tong_hop)} thực thể")


if __name__ == "__main__":
    main()
