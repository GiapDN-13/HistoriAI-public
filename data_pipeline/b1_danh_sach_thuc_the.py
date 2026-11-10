"""B1 — Lập danh sách thực thể cần có, gắn mã Wikidata làm định danh chung.

VÒNG 1: đúng những gì app đang có (5 sự kiện, 2 vĩ nhân, 9 cổ vật). Tên bài
        Wikipedia viết tay ở đây, rồi hỏi API để lấy tên chuẩn và mã Wikidata.
        Tên nào API không nhận thì báo, KHÔNG đoán.

VÒNG 2: với mỗi chủ đề Việt Nam trong khung (B0), mô hình ngôn ngữ đề xuất các
        sự kiện chính kèm tên bài Wikipedia. Code tự kiểm tra bài đó CÓ THẬT;
        tên bịa thì bị loại ngay tại đây, không đi tiếp được bước nào.

Hai trận Bạch Đằng 938 và 1288 là hai thực thể khác nhau — gộp theo mã
Wikidata, không gộp theo tên.

RA
    ket_qua/b1_thuc_the.json
"""
from __future__ import annotations

import re

from chung import (KET_QUA, ChuaCoKhoa, HetNganSach, MoHinh, doc_cau_hinh, doc_json,
                   ghi_json, ghi_log, nfc, slugify, tai)

API_WP = "https://vi.wikipedia.org/w/api.php"

VONG_1 = [
    # (loại, slug trong app, tên bài Wikipedia)
    ("su_kien", "bach-dang-938", "Trận Bạch Đằng (938)"),
    ("su_kien", "khang-chien-tong-981", "Chiến tranh Tống–Việt lần thứ nhất"),
    ("su_kien", "bach-dang-1288", "Trận Bạch Đằng (1288)"),
    ("su_kien", "lam-son-1428", "Khởi nghĩa Lam Sơn"),
    ("su_kien", "quang-trung-1789", "Trận Ngọc Hồi – Đống Đa"),
    ("nhan_vat", "tran-hung-dao", "Trần Hưng Đạo"),
    ("nhan_vat", "quang-trung", "Quang Trung"),
    ("co_vat", "trong-dong-dong-son", "Trống đồng Đông Sơn"),
    ("co_vat", "trong-dong-khai-quat", "Trống đồng Đông Sơn"),
    ("co_vat", "trong-dong-hoa-van", "Trống đồng Đông Sơn"),
    ("co_vat", "coc-bach-dang-1288", "Các trận địa bãi cọc trong lịch sử Việt Nam"),
    ("co_vat", "thuyen-chien-dong-son", "Văn hóa Đông Sơn"),
    ("co_vat", "kiem-dong-son", "Văn hóa Đông Sơn"),
    ("co_vat", "nghe-den-vua-dinh", "Đền Vua Đinh Tiên Hoàng"),
    ("co_vat", "rong-co-loa", "Thành Cổ Loa"),
    ("co_vat", "hu-tien-dong", None),   # không có bài nào khớp đúng hiện vật này
]


def tra_bai(tieu_de: str) -> dict | None:
    """Tên bài → {title, pageid, qid} theo tên chuẩn sau chuyển hướng. None nếu không có."""
    j = tai(API_WP, {"action": "query", "format": "json", "formatversion": 2, "redirects": 1,
                     "prop": "pageprops", "ppprop": "wikibase_item", "titles": tieu_de})
    trang = (j.get("query") or {}).get("pages") or []
    if not trang or trang[0].get("missing") or trang[0].get("invalid"):
        return None
    p = trang[0]
    if "(định hướng)" in p["title"]:
        return None
    return {"title": p["title"], "pageid": p["pageid"],
            "qid": (p.get("pageprops") or {}).get("wikibase_item")}


def tim_bai(tieu_de: str) -> dict | None:
    """Tên đoán gần đúng → bài có thật. Tra thẳng trước, không có thì tìm kiếm
    và chỉ nhận kết quả đầu nếu tên gần như trùng — tránh nhận nhầm bài khác."""
    kq = tra_bai(tieu_de)
    if kq:
        return kq
    j = tai(API_WP, {"action": "query", "format": "json", "list": "search",
                     "srsearch": tieu_de, "srlimit": 3})
    for r in j.get("query", {}).get("search", []):
        a, b = slugify(tieu_de), slugify(r["title"])
        if a == b or (a in b and len(a) >= 0.7 * len(b)) or (b in a and len(b) >= 0.7 * len(a)):
            return tra_bai(r["title"])
    return None


HE_THONG_DE_XUAT = """Bạn là giáo viên Lịch sử Việt Nam. Với một chủ đề trong chương trình giáo dục phổ thông,
hãy liệt kê các SỰ KIỆN LỊCH SỬ VIỆT NAM cụ thể mà học sinh cần biết để đạt các yêu cầu cần đạt.
Chỉ chọn sự kiện có mốc năm rõ ràng (trận đánh, cuộc khởi nghĩa, cuộc kháng chiến, cải cách, hiệp định,
sự kiện chính trị). Không chọn khái niệm chung, không chọn nhân vật, không chọn sự kiện thế giới.
Với mỗi sự kiện, ghi TÊN BÀI trên Wikipedia tiếng Việt đúng như bạn biết nó tồn tại.
Trả về mảng JSON: [{"ten_bai": "...", "nam": 1288, "ly_do": "gắn với yêu cầu nào"}]. Tối đa 6 sự kiện."""


def de_xuat_vong_2(mo_hinh: MoHinh, khung: dict, gioi_han: int) -> list[dict]:
    ra = []
    for cd in khung["chu_de"]:
        muc_vn = [m for m in cd["muc"] if m.get("viet_nam")]
        if not muc_vn or cd.get("chuyen_de"):
            continue
        noi = "\n".join(f"- {m['noi_dung']}\n  Yêu cầu: " + " | ".join(m["yccd"][:6]) for m in muc_vn)
        de_bai = f"Lớp {cd['lop']} ({cd['cap']}). Chủ đề: {cd['chu_de']}\n{noi}"[:6000]
        goi_y = mo_hinh.hoi_json(HE_THONG_DE_XUAT, de_bai, toi_da=900, nhan=f"B1 {cd['ma']}")
        if not isinstance(goi_y, list):
            ghi_log(f"  B1 {cd['ma']}: mô hình trả rác, bỏ qua")
            continue
        for g in goi_y[:gioi_han]:
            if isinstance(g, dict) and g.get("ten_bai"):
                ra.append({"ten_goi_y": nfc(str(g["ten_bai"])), "nam_goi_y": g.get("nam"),
                           "ma": cd["ma"], "lop": cd["lop"]})
    return ra


def main() -> None:
    ch = doc_cau_hinh()
    khung = doc_json(KET_QUA / "b0_khung.json")
    cu = doc_json(KET_QUA / "b1_thuc_the.json", {"thuc_the": [], "bi_loai": []})
    thuc_the: dict[str, dict] = {t["slug"]: t for t in cu["thuc_the"]}
    bi_loai = cu["bi_loai"]

    # ── vòng 1 ──
    for loai, slug, ten in VONG_1:
        if slug in thuc_the:
            continue
        bai = tra_bai(ten) if ten else None
        if ten and not bai:
            ghi_log(f"  B1 vòng 1: KHÔNG tìm thấy bài '{ten}' cho {slug}")
        thuc_the[slug] = {"slug": slug, "loai": loai, "vong": 1, "co_san": True,
                          "bai_wp": bai, "ma": []}

    # Gắn mã chương trình cho vòng 1 bằng khớp từ khoá trong nội dung + yêu cầu
    tu_khoa = {
        "bach-dang-938": ["bạch đằng năm 938", "nam hán", "ngô quyền", "bước ngoặt lịch sử ở đầu thế kỉ x"],
        "khang-chien-tong-981": ["chống tống của lê hoàn", "năm 981"],
        "bach-dang-1288": ["mông – nguyên", "mông - nguyên", "mông nguyên"],
        "lam-son-1428": ["lam sơn"],
        "quang-trung-1789": ["tây sơn"],
        "tran-hung-dao": ["mông – nguyên", "mông - nguyên", "trần quốc tuấn"],
        "quang-trung": ["tây sơn"],
        "trong-dong-dong-son": ["văn lang", "đông sơn", "sông hồng"],
        "trong-dong-khai-quat": ["văn lang", "đông sơn", "sông hồng"],
        "trong-dong-hoa-van": ["văn lang", "đông sơn", "sông hồng"],
        "thuyen-chien-dong-son": ["văn lang", "đông sơn"],
        "kiem-dong-son": ["văn lang", "đông sơn"],
        "coc-bach-dang-1288": ["mông – nguyên", "mông - nguyên"],
        "nghe-den-vua-dinh": ["đinh bộ lĩnh", "nhà đinh"],
        "rong-co-loa": ["âu lạc"],
    }
    for slug, tks in tu_khoa.items():
        t = thuc_the.get(slug)
        if not t:
            continue
        ma = set(t["ma"])
        for cd in khung["chu_de"]:
            for m in cd["muc"]:
                chu = (m["noi_dung"] + " " + " ".join(m["yccd"])).lower()
                if any(k in chu for k in tks):
                    ma.add(cd["ma"])
        t["ma"] = sorted(ma)

    # ── vòng 2 ──
    if ch["vong_2"]["bat"] and not cu.get("vong_2_xong"):
        mo_hinh = MoHinh(ch["llm"])
        try:
            goi_y = de_xuat_vong_2(mo_hinh, khung, ch["vong_2"]["su_kien_moi_chu_de"])
        except (ChuaCoKhoa, HetNganSach):
            ghi_json(KET_QUA / "b1_thuc_the.json", {"thuc_the": list(thuc_the.values()),
                                                   "bi_loai": bi_loai, "vong_2_xong": False})
            raise
        theo_qid = {t["bai_wp"]["qid"]: t for t in thuc_the.values()
                    if t.get("bai_wp") and t["bai_wp"].get("qid")}
        for g in goi_y:
            bai = tim_bai(g["ten_goi_y"])
            if not bai or not bai.get("qid"):
                bi_loai.append({**g, "ly_do": "không có bài Wikipedia nào đúng tên này"})
                continue
            if bai["qid"] in theo_qid:
                t = theo_qid[bai["qid"]]
                t["ma"] = sorted(set(t["ma"]) | {g["ma"]})
                continue
            slug = slugify(bai["title"])
            if slug in thuc_the:
                slug = f"{slug}-{bai['qid'].lower()}"
            t = {"slug": slug, "loai": "su_kien", "vong": 2, "co_san": False,
                 "bai_wp": bai, "ma": [g["ma"]], "nam_goi_y": g.get("nam_goi_y")}
            thuc_the[slug] = t
            theo_qid[bai["qid"]] = t
        cu["vong_2_xong"] = True

    ghi_json(KET_QUA / "b1_thuc_the.json", {"thuc_the": list(thuc_the.values()),
                                           "bi_loai": bi_loai,
                                           "vong_2_xong": cu.get("vong_2_xong", False)})
    v1 = sum(t["vong"] == 1 for t in thuc_the.values())
    v2 = sum(t["vong"] == 2 for t in thuc_the.values())
    ghi_log(f"B1: {v1} thực thể vòng 1, {v2} sự kiện vòng 2, {len(bi_loai)} gợi ý bị loại vì không có bài thật")


if __name__ == "__main__":
    main()
