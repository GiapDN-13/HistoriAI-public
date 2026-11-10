"""B3 — Trích mệnh đề sự kiện, mỗi mệnh đề kèm câu trích nguyên văn đã kiểm.

CHỐT CHẶN CHỐNG BỊA — cả hai đều kiểm bằng code, không nhờ mô hình tự khai:
    1. Câu trích phải CÓ THẬT trong đoạn nguồn (sau khi chuẩn hoá chính tả 1920,
       dấu ngoặc, khoảng trắng). Trích sai, trích "gần đúng", trích ghép hai
       câu xa nhau — đều bị loại.
    2. Mọi con số trong mệnh đề phải xuất hiện trong chính câu trích. Mô hình
       hay "tiện tay" thêm năm tháng mà đoạn nguồn không nói — chặn ở đây.

Dữ kiện Wikidata đã có cấu trúc nên không qua mô hình: chuyển thẳng thành
mệnh đề, câu trích chính là giá trị gốc.

RA
    ket_qua/b3/<slug>.json
"""
from __future__ import annotations

import difflib
import re

from chung import (CACHE, KET_QUA, MoHinh, an_toan, bi_loai_tru, cac_so, chuan_hoa_so_khop, doc_cau_hinh, doc_json,
                   ghi_json, ghi_log)

RA = KET_QUA / "b3"
RA.mkdir(parents=True, exist_ok=True)

LOAI_HOP_LE = {"nien_dai", "nhan_vat", "dien_bien", "nguyen_nhan", "y_nghia", "so_lieu",
               "dia_diem", "dac_diem", "su_kien"}

HE_THONG = """Bạn là người trích xuất sử liệu cẩn thận. Đọc ĐOẠN VĂN và tách ra các MỆNH ĐỀ NGUYÊN TỬ về chủ thể được nêu.
Quy tắc bắt buộc:
- Mỗi mệnh đề nói ĐÚNG MỘT dữ kiện, viết bằng tiếng Việt hiện đại, câu ngắn, đủ chủ ngữ.
- Chỉ dùng thông tin CÓ TRONG ĐOẠN VĂN. Không suy luận, không thêm kiến thức bên ngoài, không thêm năm tháng nếu đoạn văn không ghi.
- Mỗi mệnh đề kèm "trich_dan": CHÉP Y NGUYÊN một câu hoặc một phần câu LIÊN TỤC (8 đến 40 từ) trong đoạn văn chứng minh mệnh đề. Không sửa chữ, không nối hai câu, không dùng dấu "...".
- Chỉ lấy dữ kiện liên quan trực tiếp đến chủ thể. Bỏ qua chú thích, tranh cãi học thuật, văn hoá đại chúng.
- "loai" là một trong: nien_dai, nhan_vat, dien_bien, nguyen_nhan, y_nghia, so_lieu, dia_diem, dac_diem.
Trả về mảng JSON: [{"noi_dung": "...", "trich_dan": "...", "loai": "..."}]. Tối đa 8 mệnh đề, chọn những dữ kiện quan trọng nhất."""


def cat_doan(van_ban: str, ky_tu: int, toi_da: int) -> list[str]:
    """Cắt theo ranh giới đoạn văn, không cắt giữa câu."""
    doan, hien = [], ""
    for p in re.split(r"\n\s*\n|\n(?==)", van_ban):
        p = p.strip()
        if not p or re.fullmatch(r"=+.*=+", p):
            if p:
                hien += ("\n" if hien else "") + p
            continue
        if len(hien) + len(p) > ky_tu and hien:
            doan.append(hien)
            hien = ""
            if len(doan) >= toi_da:
                break
        hien += ("\n\n" if hien else "") + p[: ky_tu * 2]
    if hien and len(doan) < toi_da:
        doan.append(hien)
    return doan


def kiem_trich_dan(trich: str, doan: str) -> bool:
    t, d = chuan_hoa_so_khop(trich), chuan_hoa_so_khop(doan)
    if len(t.split()) < 5:
        return False
    if t in d:
        return True
    # Chịu lệch rất nhỏ (một dấu câu, một khoảng trắng) nhưng không chịu diễn đạt lại:
    # đoạn khớp liên tục dài nhất phải phủ ≥ 92% câu trích.
    m = difflib.SequenceMatcher(None, d, t, autojunk=False).find_longest_match(0, len(d), 0, len(t))
    return m.size >= 0.92 * len(t)


def so_hop_le(noi_dung: str, trich: str) -> bool:
    return cac_so(noi_dung) <= cac_so(trich)


def trich_mot_doan(mo_hinh: MoHinh, chu_the: str, doan: str, nhan: str) -> tuple[list, list]:
    kq = mo_hinh.hoi_json(HE_THONG, f"Chủ thể: {chu_the}\n\nĐOẠN VĂN:\n{doan}", toi_da=900, nhan=nhan)
    nhan_duoc, bi_loai = [], []
    for m in kq if isinstance(kq, list) else []:
        if not isinstance(m, dict) or not m.get("noi_dung") or not m.get("trich_dan"):
            continue
        nd, td = str(m["noi_dung"]).strip(), str(m["trich_dan"]).strip()
        if not kiem_trich_dan(td, doan):
            bi_loai.append({"noi_dung": nd, "trich_dan": td, "ly_do": "câu trích không có trong nguồn"})
        elif not so_hop_le(nd, td):
            bi_loai.append({"noi_dung": nd, "trich_dan": td,
                            "ly_do": "mệnh đề có con số không nằm trong câu trích"})
        else:
            loai = m.get("loai") if m.get("loai") in LOAI_HOP_LE else "dien_bien"
            nhan_duoc.append({"noi_dung": nd, "trich_dan": td, "loai": loai})
    return nhan_duoc, bi_loai


def chu_the(tl: dict) -> str:
    wp = tl["wikipedia"]["tieu_de"]
    return wp


def xu_ly(mo_hinh: MoHinh, ch: dict, tt: dict) -> None:
    slug = tt["slug"]
    tep = RA / f"{slug}.json"
    tl = doc_json(CACHE / "tai_lieu" / f"{slug}.json")
    if not tl:
        return
    ban = doc_json(tep, {"menh_de": [], "bi_loai": [], "doan_xong": []})
    # Tệp đã xong nhưng vừa có nguồn mới (Wikipedia tiếng Anh) → trích tiếp phần mới
    if ban.get("xong") and not (tl.get("enwiki") and "enwp0" not in ban["doan_xong"]):
        return
    tt_ch = ch["thu_thap"]
    toi_da = tt_ch["doan_toi_da_vong_1"] if tt["vong"] == 1 else tt_ch["doan_toi_da_vong_2"]
    ten = chu_the(tl)

    viec = []
    wp = tl["wikipedia"]
    for i, d in enumerate(cat_doan(wp["van_ban"], tt_ch["ky_tu_moi_doan"], toi_da)):
        viec.append(("wp", i, d, {"nguon": "wikipedia", "url": wp["url"], "revid": wp["revid"]}))
    vnsl = tl["vnsl"]["doan"]
    if vnsl:
        chu_vnsl = "\n\n".join(d["van_ban"] for d in vnsl)
        toi_da_v = 2 if tt["vong"] == 1 else 1
        for i, d in enumerate(cat_doan(chu_vnsl, tt_ch["ky_tu_moi_doan"], toi_da_v)):
            chuong = sorted({x["chuong"] for x in vnsl if x["van_ban"][:60] in d})
            viec.append(("vnsl", i, d, {"nguon": "vnsl", "chuong": chuong,
                                        "url": "https://vi.wikisource.org/wiki/" +
                                               (chuong[0] if chuong else "Việt_Nam_sử_lược").replace(" ", "_")}))

    en = tl.get("enwiki")
    if en and en.get("van_ban"):
        for i, d in enumerate(cat_doan(en["van_ban"], tt_ch["ky_tu_moi_doan"], 1)):
            viec.append(("enwp", i, d, {"nguon": "enwiki", "url": en["url"], "revid": en["revid"]}))

    for nguon, i, d, meta in viec:
        khoa = f"{nguon}{i}"
        if khoa in ban["doan_xong"]:
            continue
        nhan_duoc, bi_loai = trich_mot_doan(mo_hinh, ten, d, f"B3 {slug} {khoa}")
        # Đếm theo TIỀN TỐ MÃ, không theo m["nguon"]: khoá viết tắt ("wp") khác
        # tên nguồn lưu trong mệnh đề ("wikipedia"). Đếm theo tên nguồn thì luôn
        # ra 0, mọi đoạn đánh số lại từ wp0 → mã trùng nhau → B4 xếp hạng nhầm
        # và câu hỏi trỏ về căn cứ sai (lỗi phát hiện khi soát mẫu vòng 1).
        n0 = sum(1 for m in ban["menh_de"] if m["id"].startswith(f"{slug}#{nguon}"))
        for k, m in enumerate(nhan_duoc):
            ban["menh_de"].append({"id": f"{slug}#{nguon}{n0 + k}", **m, **meta})
        ban["bi_loai"] += [{**b, "nguon": nguon} for b in bi_loai]
        ban["doan_xong"].append(khoa)
        ghi_json(tep, ban)   # lưu sau MỖI đoạn — hết lượt giữa chừng không mất gì

    # Wikidata: không qua mô hình
    wd = tl.get("wikidata") or {}
    ban["menh_de"] = [m for m in ban["menh_de"] if m["nguon"] != "wikidata"]
    for k, m in enumerate(wd.get("menh_de", [])):
        ban["menh_de"].append({"id": f"{slug}#wd{k}", "noi_dung": m["noi_dung"],
                               "trich_dan": m["noi_dung"], "loai": m["loai"],
                               "nguon": "wikidata", "url": wd["url"], "nam": m.get("nam")})
    ban["xong"] = True
    ghi_json(tep, ban)
    dem = {}
    for m in ban["menh_de"]:
        dem[m["nguon"]] = dem.get(m["nguon"], 0) + 1
    ghi_log(f"B3 {slug}: {dem} mệnh đề nhận, {len(ban['bi_loai'])} bị loại")


def main(vong: int | None = None) -> None:
    ch = doc_cau_hinh()
    mo_hinh = MoHinh(ch["llm"])
    b1 = doc_json(KET_QUA / "b1_thuc_the.json")
    for tt in b1["thuc_the"]:
        if vong is not None and tt["vong"] != vong:
            continue
        if tt.get("bai_wp") and not bi_loai_tru(tt, ch):
            an_toan("B3", tt["slug"], lambda: xu_ly(mo_hinh, ch, tt))


if __name__ == "__main__":
    main()
