"""B0 — Dựng khung chương trình: lớp → chủ đề → nội dung → yêu cầu cần đạt.

NGUỒN
    THCS: Chương trình môn Lịch sử và Địa lí (TT 32/2018) — PDF có lớp chữ, lấy
          nguyên văn theo toạ độ cột.
    THPT: Chương trình môn Lịch sử SỬA ĐỔI theo TT 13/2022. Bản chính thức trên
          Cổng Chính phủ là ảnh scan, OCR sai dấu quá nhiều để dùng làm chữ. Chữ
          lấy từ bản HTML toàn văn (văn bản pháp luật, không bảo hộ quyền tác
          giả), rồi ĐỐI CHIẾU từng yêu cầu cần đạt với OCR của bản scan chính
          thức. Câu nào không tìm thấy trong bản chính thức thì bị đánh dấu.

    Không dùng chương trình Lịch sử THPT bản 2018: đã bị sửa đổi, gắn nội dung
    vào đó là gắn vào một văn bản hết hiệu lực.

RA
    ket_qua/b0_khung.json
"""
from __future__ import annotations

import html
import json
import re
from collections import defaultdict

import fitz

from chung import CACHE, KET_QUA, chuan_hoa_so_khop, ghi_json, ghi_log, nfc

THU_MUC = CACHE / "chuong_trinh"
COT_PHAI_X = 380     # toạ độ x ranh giới hai cột trong PDF THCS (đo trực tiếp)

# Từ khoá để tách phần LỊCH SỬ VIỆT NAM khỏi lịch sử thế giới. App là app học
# sử Việt nên vòng 2 chỉ đi theo các chủ đề Việt Nam. Champa, Phù Nam, Văn Lang
# là lịch sử trên lãnh thổ Việt Nam nên được tính.
TU_KHOA_VN = [
    "việt nam", "đại việt", "đại cồ việt", "văn lang", "âu lạc", "champa", "chăm pa",
    "phù nam", "bắc thuộc", "biển đông", "hồ chí minh", "dân tộc việt", "nhà lý",
    "nhà trần", "nhà hồ", "nhà lê", "nhà nguyễn", "tây sơn", "lam sơn", "ngô quyền",
    "đinh", "tiền lê", "mông – nguyên", "mông - nguyên", "trịnh", "đàng trong",
    "đàng ngoài", "thăng long", "đông dương", "cách mạng tháng tám", "điện biên",
    "đổi mới", "chống mỹ", "chống pháp", "quang trung", "trống đồng", "hùng vương",
    "hai bà trưng", "bà triệu", "lý bí", "khúc", "dương đình nghệ", "cộng đồng các dân tộc",
    "hoàng sa", "trường sa", "nam bộ", "sông hồng", "cửu long", "óc eo",
]


def la_viet_nam(*chu: str) -> bool:
    s = " ".join(chu).lower()
    return any(k in s for k in TU_KHOA_VN)


def _la_chu_hoa(s: str) -> bool:
    chu = [c for c in s if c.isalpha()]
    return len(chu) >= 4 and all(c.isupper() for c in chu)


# ───────────────────────── THCS ─────────────────────────

def doc_thcs() -> list[dict]:
    d = fitz.open(THU_MUC / "thcs_ls_dl.pdf")
    dong = []
    for so_trang in range(9, 51):            # trang 10–51: phần "Nội dung giáo dục"
        for khoi in d[so_trang].get_text("dict")["blocks"]:
            for l in khoi.get("lines", []):
                chu = nfc("".join(s["text"] for s in l["spans"])).strip()
                if chu:
                    dong.append((so_trang + 1, round(l["bbox"][1]), l["bbox"][0], chu))
    dong.sort(key=lambda x: (x[0], x[1], x[2]))

    chu_de_ds: list[dict] = []
    lop = mon = None
    chu_de = muc = None
    cha = ""                 # nội dung cấp "–" đang mở, để ghép với mục con "+"
    tieu_de_cho = ""         # dòng chữ hoa đang gom (tiêu đề chủ đề bị ngắt dòng)

    def mo_chu_de(ten: str, trang: int):
        nonlocal chu_de, muc, cha
        chu_de = {"cap": "THCS", "lop": lop, "mon": mon, "chu_de": ten, "trang": trang, "muc": []}
        chu_de_ds.append(chu_de)
        muc, cha = None, ""

    for trang, y, x, chu in dong:
        if re.fullmatch(r"\d{1,2}", chu) or chu in ("Nội dung", "Yêu cầu cần đạt"):
            continue
        m = re.fullmatch(r"LỚP ([6-9])", chu)
        if m:
            lop, mon, chu_de = int(m.group(1)), None, None
            continue
        if chu in ("LỊCH SỬ", "ĐỊA LÍ") and x > 300:
            mon = "lich_su" if chu == "LỊCH SỬ" else "dia_li"
            continue
        if chu == "CHỦ ĐỀ CHUNG":
            mon = "chung"
            continue
        if mon is None or lop is None:
            continue

        if x < COT_PHAI_X:
            if _la_chu_hoa(chu):
                # tiêu đề chủ đề có thể ngắt thành 2 dòng liền nhau → gom lại
                if chu_de and chu_de["muc"] == [] and chu_de["chu_de"] == tieu_de_cho:
                    chu_de["chu_de"] = tieu_de_cho = f"{tieu_de_cho} {chu}"
                else:
                    tieu_de_cho = chu
                    mo_chu_de(chu, trang)
                continue
            if chu_de is None:
                mo_chu_de("(chưa có tiêu đề)", trang)
            if chu.startswith(("–", "-")):
                cha = chu.lstrip("–- ").strip()
                muc = {"noi_dung": cha, "yccd": [], "trang": trang}
                chu_de["muc"].append(muc)
            elif chu.startswith("+"):
                con = chu.lstrip("+ ").strip()
                muc = {"noi_dung": f"{cha} › {con}" if cha else con, "yccd": [], "trang": trang}
                chu_de["muc"].append(muc)
            elif muc is not None:
                # dòng nối tiếp của nội dung — cập nhật cả phần "cha" nếu đang ở cấp "–"
                if " › " in muc["noi_dung"]:
                    muc["noi_dung"] += " " + chu
                else:
                    muc["noi_dung"] += " " + chu
                    cha = muc["noi_dung"]
        else:
            if chu_de is None:
                continue
            if muc is None:
                muc = {"noi_dung": "", "yccd": [], "trang": trang}
                chu_de["muc"].append(muc)
            if chu.startswith(("–", "-")):
                muc["yccd"].append(chu.lstrip("–- ").strip())
            elif muc["yccd"]:
                muc["yccd"][-1] += " " + chu
            else:
                muc["yccd"].append(chu)

    for cd in chu_de_ds:
        for m in cd["muc"]:
            m["noi_dung"] = re.sub(r"\s+", " ", m["noi_dung"]).strip()
            m["yccd"] = [re.sub(r"\s+", " ", y).strip() for y in m["yccd"] if y.strip()]
        cd["muc"] = [m for m in cd["muc"] if m["noi_dung"] or m["yccd"]]
    return [cd for cd in chu_de_ds if cd["mon"] in ("lich_su", "chung") and cd["muc"]]


# ───────────────────────── THPT ─────────────────────────

def _chu_o(o: str) -> list[str]:
    """Các đoạn <p> trong một ô bảng, đã bỏ thẻ."""
    doan = re.findall(r"<p[^>]*>(.*?)</p>", o, flags=re.S) or [o]
    ra = []
    for p in doan:
        t = html.unescape(re.sub(r"<[^>]+>", "", p))
        t = nfc(re.sub(r"\s+", " ", t.replace("\xa0", " "))).strip()
        if t:
            ra.append(t)
    return ra


def doc_thpt() -> list[dict]:
    s = (THU_MUC / "hoatieu_ls.html").read_text(encoding="utf-8")
    s = re.sub(r"<script.*?</script>|<style.*?</style>", "", s, flags=re.S)
    bat_dau = s.find("2. Nội dung cụ thể")
    s = s[bat_dau:]

    chu_de_ds = []
    # Duyệt tuần tự: đoạn tiêu đề (LỚP n / CHUYÊN ĐỀ …) rồi tới bảng của nó
    vi_tri = [(m.start(), "p", m.group(0)) for m in re.finditer(r"<p[^>]*>.*?</p>", s, flags=re.S)]
    vi_tri += [(m.start(), "t", m.group(0)) for m in re.finditer(r"<table.*?</table>", s, flags=re.S)]
    vi_tri.sort()
    lop, chuyen_de = None, False
    het_bang = -1
    for pos, loai, khoi in vi_tri:
        if pos < het_bang:
            continue
        if loai == "p":
            t = " ".join(_chu_o(khoi))
            m = re.fullmatch(r"LỚP (1[0-2])", t.strip())
            if m:
                lop, chuyen_de = int(m.group(1)), False
            elif re.match(r"(?i)chuyên đề học tập", t):
                chuyen_de = True
            elif t.startswith(("VI.", "VI ", "VI. PHƯƠNG")):
                break
            continue
        het_bang = pos + len(khoi)
        if lop is None:
            continue
        chu_de = None
        for hang in re.findall(r"<tr.*?</tr>", khoi, flags=re.S):
            o = re.findall(r"<td([^>]*)>(.*?)</td>", hang, flags=re.S)
            if not o:
                continue
            if len(o) == 1 and "colspan" in o[0][0]:
                ten = " ".join(_chu_o(o[0][1]))
                if ten and ten != "Nội dung":
                    chu_de = {"cap": "THPT", "lop": lop, "mon": "lich_su", "chu_de": ten,
                              "chuyen_de": chuyen_de, "muc": []}
                    chu_de_ds.append(chu_de)
                continue
            trai = [x for c in o[:-1] for x in _chu_o(c[1])]
            phai = _chu_o(o[-1][1])
            if trai[:1] == ["Nội dung"] or phai[:1] in (["Yêu cầu cần đạt"], ["Yêu cầu cần đạt"]):
                continue
            if "".join(phai).replace("Yêu cầu cần đạt", "").strip() == "" and not trai:
                continue
            if chu_de is None:
                chu_de = {"cap": "THPT", "lop": lop, "mon": "lich_su", "chu_de": "(chưa có tiêu đề)",
                          "chuyen_de": chuyen_de, "muc": []}
                chu_de_ds.append(chu_de)
            yccd = [p.lstrip("-–• ").strip() for p in phai if p.lstrip("-–• ").strip()]
            chu_de["muc"].append({"noi_dung": " › ".join(t.lstrip("-–• ") for t in trai),
                                  "yccd": [y for y in yccd if "cầu cần đạt" not in y]})
    return [cd for cd in chu_de_ds if cd["muc"]]


# ───────────────────── đối chiếu bản scan chính thức ─────────────────────

def _cap_am_tiet(s: str) -> set[tuple[str, str]]:
    w = chuan_hoa_so_khop(s).split()
    return set(zip(w, w[1:]))


def doi_chieu_ocr(chu_de_ds: list[dict]) -> dict:
    """Tỉ lệ cặp âm tiết của mỗi yêu cầu cần đạt tìm thấy trong OCR bản chính thức.

    OCR rơi chữ và sai dấu, nên không so nguyên văn được. So theo CẶP âm tiết
    liền nhau: một câu chép từ nơi khác mà không có trong bản chính thức thì
    gần như không thể trùng nhiều cặp. Ngưỡng 0,5 đo trên các câu mẫu.
    """
    thu_muc = THU_MUC / "ocr_tt13"
    tep = sorted(thu_muc.glob("trang_*.json")) if thu_muc.exists() else []
    if len(tep) < 60:
        return {"trang_thai": f"OCR chưa xong ({len(tep)}/68 trang) — chưa đối chiếu"}
    cap_ocr = set()
    for t in tep:
        j = json.loads(t.read_text(encoding="utf-8"))
        # ghép theo hàng (y gần nhau) để không mất cặp âm tiết ở chỗ OCR cắt khung
        hang = defaultdict(list)
        for d in j["dong"]:
            hang[round(d["y0"] / 25)].append((d["x0"], d["chu"]))
        for k in sorted(hang):
            cap_ocr |= _cap_am_tiet(" ".join(c for _, c in sorted(hang[k])))
    khop = tong = 0
    for cd in chu_de_ds:
        if cd["cap"] != "THPT":
            continue
        for m in cd["muc"]:
            m["doi_chieu"] = []
            for y in m["yccd"]:
                cap = _cap_am_tiet(y)
                ti_le = round(len(cap & cap_ocr) / len(cap), 2) if cap else 0
                m["doi_chieu"].append(ti_le)
                tong += 1
                khop += ti_le >= 0.5
    return {"trang_thai": "đã đối chiếu", "tong_yccd": tong, "khop_ban_chinh_thuc": khop}


def main() -> None:
    thcs = doc_thcs()
    thpt = doc_thpt()
    tat_ca = thcs + thpt
    dem = defaultdict(int)
    for cd in tat_ca:
        dem[(cd["cap"], cd["lop"])] += 1
        cd["ma"] = f"{cd['cap']}-{cd['lop']}-{dem[(cd['cap'], cd['lop'])]:02d}"
        # Phân loại theo TỪNG MỤC chứ không theo cả chủ đề: "Chủ nghĩa xã hội từ
        # 1917" là chủ đề thế giới nhưng có mục về Việt Nam; gộp cả chủ đề thì
        # hoặc bỏ sót mục đó, hoặc kéo cả Cách mạng tháng Mười vào app sử Việt.
        # Tiêu đề chủ đề là tiếng Việt Nam thì mọi mục bên trong đều tính.
        cd["chuyen_de"] = cd["chu_de"].lower().startswith("chuyên đề")
        tieu_de_vn = la_viet_nam(cd["chu_de"])
        for m in cd["muc"]:
            m["viet_nam"] = tieu_de_vn or la_viet_nam(m["noi_dung"], *m["yccd"])
        cd["viet_nam"] = any(m["viet_nam"] for m in cd["muc"])
    doi_chieu = doi_chieu_ocr(tat_ca)

    ghi_json(KET_QUA / "b0_khung.json", {
        "nguon": {
            "THCS": "Chương trình GDPT môn Lịch sử và Địa lí, ban hành kèm TT 32/2018/TT-BGDĐT",
            "THPT": "Chương trình GDPT môn Lịch sử, sửa đổi theo TT 13/2022/TT-BGDĐT "
                    "(bản chính thức: datafiles.chinhphu.vn/cpp/files/vbpq/2022/08/13-bgddt.signed.pdf)",
        },
        "doi_chieu_ban_chinh_thuc": doi_chieu,
        "chu_de": tat_ca,
    })
    for lop in range(6, 13):
        cds = [c for c in tat_ca if c["lop"] == lop]
        ghi_log(f"B0 lớp {lop}: {len(cds)} chủ đề, "
                f"{sum(len(m['yccd']) for c in cds for m in c['muc'])} yêu cầu cần đạt, "
                f"{sum(c['viet_nam'] for c in cds)} chủ đề Việt Nam")
    ghi_log("B0 đối chiếu:", doi_chieu)


if __name__ == "__main__":
    main()
