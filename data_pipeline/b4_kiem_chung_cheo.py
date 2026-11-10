"""B4 — Kiểm chứng chéo: xếp hạng A / B / C cho từng mệnh đề.

    A  ≥ 2 nguồn ĐỘC LẬP cùng xác nhận     → dùng được cho mọi thứ, kể cả đáp án quiz
    B  chỉ 1 nguồn                          → dùng cho tóm tắt có ghi nguồn, KHÔNG làm đáp án
    C  các nguồn MÂU THUẪN nhau             → không dùng; vào hàng chờ

Mô hình ngôn ngữ chỉ làm một việc: GHÉP CẶP mệnh đề nói cùng một điều. Nó
không được quyền xếp hạng. Mọi cặp nó ghép đều bị code kiểm lại:

    • Con số: hai mệnh đề cùng có năm/số liệu mà không chung số nào → không
      phải "cùng một điều", cặp bị huỷ. Nếu mô hình bảo là mâu thuẫn và số
      khác nhau thật → hạng C.
    • Độc lập: Wikipedia hay trích nguyên văn Việt Nam sử lược. Hai câu trích
      gần như giống hệt chữ thì là MỘT nguồn chép lại, không phải hai nguồn —
      cặp đó không được tính để lên hạng A.

RA
    ket_qua/b4/<slug>.json
"""
from __future__ import annotations

import difflib

from chung import KET_QUA, MoHinh, an_toan, bi_loai_tru, cac_so, chuan_hoa_so_khop, doc_cau_hinh, doc_json, ghi_json, ghi_log

RA = KET_QUA / "b4"
RA.mkdir(parents=True, exist_ok=True)

HE_THONG = """Bạn đối chiếu sử liệu. Có hai danh sách mệnh đề về cùng một chủ thể, lấy từ hai nguồn khác nhau.
Nhiệm vụ:
1. "trung": các cặp [số bên TRÁI, số bên PHẢI] nói CÙNG MỘT dữ kiện (có thể diễn đạt khác nhau).
   Chỉ ghép khi nội dung thực sự trùng, không ghép vì cùng chủ đề chung chung.
2. "mau_thuan": các cặp [số TRÁI, số PHẢI, "lý do ngắn"] nói về cùng một điều nhưng thông tin TRÁI NGƯỢC
   (khác năm, khác người chỉ huy, khác kết quả, khác số liệu).
Trả về JSON: {"trung": [[1, 3], ...], "mau_thuan": [[2, 5, "..."], ...]}"""


def _nam(s: str) -> set[str]:
    return {x for x in cac_so(s) if 2 <= len(x) <= 4}


def doc_lap(a: dict, b: dict) -> bool:
    """Hai câu trích giống nhau ≥ 80% chữ thì coi là cùng một nguồn chép lại."""
    if a["nguon"] == b["nguon"]:
        return False
    ta, tb = chuan_hoa_so_khop(a["trich_dan"]), chuan_hoa_so_khop(b["trich_dan"])
    return difflib.SequenceMatcher(None, ta, tb, autojunk=False).ratio() < 0.8


def so_khop(a: dict, b: dict) -> bool | None:
    """True: cùng số hoặc một bên không có số. False: cả hai có số mà không chung số nào."""
    na, nb = _nam(a["noi_dung"]), _nam(b["noi_dung"])
    if not na or not nb:
        return True
    return bool(na & nb)


def xu_ly(mo_hinh: MoHinh, slug: str) -> None:
    tep = RA / f"{slug}.json"
    b3 = doc_json(KET_QUA / "b3" / f"{slug}.json")
    if not b3 or not b3.get("xong"):
        return
    cu = doc_json(tep, {})
    # B3 có thêm mệnh đề (vd vừa thêm Wikipedia tiếng Anh) thì tính lại; không thì bỏ qua
    if cu.get("xong") and {m["id"] for m in b3["menh_de"]} <= {m["id"] for m in cu["menh_de"]}:
        return
    md = b3["menh_de"]
    trai = [m for m in md if m["nguon"] == "wikipedia"]
    phai = [m for m in md if m["nguon"] != "wikipedia"]
    xac_nhan: dict[str, set[str]] = {m["id"]: set() for m in md}
    mau_thuan: dict[str, list] = {}
    cap_huy = []

    # Chia khối để mỗi lượt gọi vừa trần token/phút
    KHOI = 40
    for i in range(0, max(len(trai), 1), KHOI):
        khoi_trai = trai[i:i + KHOI]
        if not khoi_trai or not phai:
            break
        de = "BÊN TRÁI (Wikipedia):\n" + "\n".join(f"{k + 1}. {m['noi_dung']}" for k, m in enumerate(khoi_trai))
        de += "\n\nBÊN PHẢI (nguồn khác):\n" + "\n".join(f"{k + 1}. {m['noi_dung']}" for k, m in enumerate(phai))
        kq = mo_hinh.hoi_json(HE_THONG, de, toi_da=700, nhan=f"B4 {slug} {i}") or {}
        for cap in kq.get("trung", []) if isinstance(kq, dict) else []:
            try:
                a, b = khoi_trai[int(cap[0]) - 1], phai[int(cap[1]) - 1]
            except (ValueError, IndexError, TypeError):
                continue
            if not so_khop(a, b):
                cap_huy.append([a["id"], b["id"], "hai bên khác số — không phải cùng một dữ kiện"])
                continue
            if not doc_lap(a, b):
                cap_huy.append([a["id"], b["id"], "hai câu trích gần như giống hệt — một nguồn chép lại"])
                continue
            xac_nhan[a["id"]].add(b["id"])
            xac_nhan[b["id"]].add(a["id"])
        for cap in kq.get("mau_thuan", []) if isinstance(kq, dict) else []:
            try:
                a, b = khoi_trai[int(cap[0]) - 1], phai[int(cap[1]) - 1]
                ly_do = str(cap[2]) if len(cap) > 2 else ""
            except (ValueError, IndexError, TypeError):
                continue
            na, nb = _nam(a["noi_dung"]), _nam(b["noi_dung"])
            # Mâu thuẫn về số chỉ được nhận khi số khác nhau THẬT; mâu thuẫn về chữ thì giữ
            # lời mô hình nhưng vẫn là hạng C — thà loại oan một mệnh đề còn hơn đưa sai lên app.
            if na and nb and na & nb and not (na ^ nb):
                continue
            for x, y in ((a, b), (b, a)):
                mau_thuan.setdefault(x["id"], []).append({"voi": y["id"], "ly_do": ly_do})

    theo_id = {m["id"]: m for m in md}
    ket_qua = []
    for m in md:
        if m["id"] in mau_thuan:
            hang = "C"
        elif xac_nhan[m["id"]]:
            hang = "A"
        else:
            hang = "B"
        nguon_xn = {m["nguon"]} | {theo_id[i]["nguon"] for i in xac_nhan[m["id"]] if i in theo_id}
        ket_qua.append({**m, "hang": hang, "xac_nhan_boi": sorted(xac_nhan[m["id"]]),
                        "mau_thuan": mau_thuan.get(m["id"], []),
                        # Hạng A mà chỉ nhờ Wikipedia Việt + Anh xác nhận: hai bản hay dịch qua
                        # lại nên không hẳn độc lập — trang duyệt đánh dấu để soát kỹ.
                        "chi_viet_anh": hang == "A" and nguon_xn <= {"wikipedia", "enwiki"}})
    dem = {h: sum(1 for m in ket_qua if m["hang"] == h) for h in "ABC"}
    ghi_json(tep, {"menh_de": ket_qua, "cap_bi_huy": cap_huy, "dem": dem, "xong": True})
    ghi_log(f"B4 {slug}: A={dem['A']} B={dem['B']} C={dem['C']}, {len(cap_huy)} cặp bị code huỷ")


def main(vong: int | None = None) -> None:
    ch = doc_cau_hinh()
    mo_hinh = MoHinh(ch["llm"])
    for tt in doc_json(KET_QUA / "b1_thuc_the.json")["thuc_the"]:
        if (vong is None or tt["vong"] == vong) and tt.get("bai_wp") and not bi_loai_tru(tt, ch):
            an_toan("B4", tt["slug"], lambda: xu_ly(mo_hinh, tt["slug"]))


if __name__ == "__main__":
    main()
