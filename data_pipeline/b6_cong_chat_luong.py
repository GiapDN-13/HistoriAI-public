"""B6 — Cổng chất lượng tự động. Trượt MỘT cổng là vào hàng chờ, không lên app.

CÂU HỎI QUIZ
    1. Đúng khuôn: đủ 4 phương án khác nhau, đáp án thuộc a–d.
    2. Không trùng câu đã có trong app hay câu vừa sinh (so độ giống nội dung).
    3. Truy được nguồn: đáp án dựa trên ít nhất một mệnh đề hạng A.
    4. Hợp lứa tuổi: độ dài, không "tất cả các đáp án trên".
    5. LÀM BÀI MÙ: một lượt gọi RIÊNG (cùng mô hình, không thấy đáp án) làm câu hỏi. Phải
       chọn đúng, và phải xác nhận chỉ có MỘT phương án đúng. Máy chọn sai hoặc
       thấy hai phương án cùng đúng → câu mơ hồ → loại.
    6. Cân bằng: đảo vị trí phương án bằng code để đáp án đúng không dồn vào một chữ.

TÓM TẮT
    Mọi năm và con số trong bài phải khớp một mệnh đề hạng A (hoặc năm của chính
    sự kiện). Độ dài đúng khoảng. Trượt thì sự kiện giữ tóm tắt cũ, bản mới vào
    hàng chờ.

RA
    ket_qua/b6/<slug>.json        — nội dung đạt, kèm lý do từng câu bị loại
"""
from __future__ import annotations

import difflib
import random

from chung import KET_QUA, MoHinh, an_toan, bi_loai_tru, cac_so, chuan_hoa_so_khop, doc_cau_hinh, doc_json, ghi_json, ghi_log, tai

RA = KET_QUA / "b6"
RA.mkdir(parents=True, exist_ok=True)
API = "https://historiai.anhzap.shop/api/v1"

CAM = ["tất cả các đáp án", "tất cả đều đúng", "cả a và b", "cả a, b", "không có đáp án nào",
       "tất cả những điều trên", "cả ba đáp án"]

HE_THONG_LAM_BAI = """Bạn là học sinh giỏi Lịch sử Việt Nam. Làm các câu trắc nghiệm dưới đây bằng kiến thức lịch sử của bạn.
Với mỗi câu: "chon" là chữ cái phương án đúng nhất; "so_dung" là số phương án ĐÚNG về mặt lịch sử (1 nếu chỉ có một phương án đúng, 2 nếu có hai phương án cùng đúng...).
Trả về mảng JSON: [{"so": 1, "chon": "b", "so_dung": 1}, ...]"""


def gan_giong(a: str, b: str) -> bool:
    return difflib.SequenceMatcher(None, chuan_hoa_so_khop(a), chuan_hoa_so_khop(b)).ratio() > 0.8


def cau_hoi_co_san(slug: str) -> list[str]:
    try:
        return [q["question"] for q in tai(f"{API}/quiz/{slug}", cache=False)]
    except Exception:
        return []   # sự kiện mới chưa có trên app


def kiem_khuon(q: dict) -> str | None:
    pa = q["phuong_an"]
    if not q["cau_hoi"] or any(not pa[k] for k in "abcd"):
        return "thiếu câu hỏi hoặc phương án"
    if len({chuan_hoa_so_khop(pa[k]) for k in "abcd"}) < 4:
        return "có phương án trùng nhau"
    if q["dap_an"] not in "abcd" or not q["dap_an"]:
        return "đáp án không thuộc a–d"
    if not q["menh_de"]:
        return "không trỏ được về mệnh đề hạng A nào"
    if len(q["cau_hoi"]) > 260 or any(len(pa[k]) > 140 for k in "abcd"):
        return "câu hỏi hoặc phương án quá dài"
    chu = (q["cau_hoi"] + " " + " ".join(pa.values())).lower()
    if any(c in chu for c in CAM):
        return "dùng phương án kiểu 'tất cả các đáp án'"
    return None


def dao_phuong_an(q: dict, dich: str) -> dict:
    """Đưa đáp án đúng về vị trí `dich`, giữ nguyên thứ tự tương đối các phương án nhiễu."""
    pa = q["phuong_an"]
    dung = pa[q["dap_an"]]
    nhieu = [pa[k] for k in "abcd" if k != q["dap_an"]]
    moi = {}
    for k in "abcd":
        moi[k] = dung if k == dich else nhieu.pop(0)
    return {**q, "phuong_an": moi, "dap_an": dich}


def lam_bai_mu(mo_hinh: MoHinh, slug: str, ds: list[dict]) -> list[tuple[bool, str]]:
    ket = []
    for i in range(0, len(ds), 6):   # 6 câu một lượt: vòng 2 chỉ tốn đúng 1 lượt
        khoi = ds[i:i + 6]
        de = "\n\n".join(
            f"Câu {k + 1}: {q['cau_hoi']}\n" + "\n".join(f"{c}. {q['phuong_an'][c]}" for c in "abcd")
            for k, q in enumerate(khoi))
        kq = mo_hinh.hoi_json(HE_THONG_LAM_BAI, de, toi_da=600, nhan=f"B6 làm bài {slug} {i}")
        theo_so = {}
        for x in kq if isinstance(kq, list) else []:
            try:
                theo_so[int(x["so"])] = x
            except (KeyError, ValueError, TypeError):
                pass
        for k, q in enumerate(khoi):
            x = theo_so.get(k + 1)
            if not x:
                ket.append((False, "lượt làm bài mù không trả lời câu này"))
            elif str(x.get("chon", "")).lower()[:1] != q["dap_an"]:
                ket.append((False, f"làm bài mù chọn '{x.get('chon')}' — đáp án đúng là '{q['dap_an']}'"))
            elif str(x.get("so_dung", "1")) not in ("1", "1.0"):
                ket.append((False, f"làm bài mù thấy {x.get('so_dung')} phương án cùng đúng — câu mơ hồ"))
            else:
                ket.append((True, ""))
    return ket


def kiem_tom_tat(tom: dict, so_a: set[str], nam_su_kien) -> str | None:
    if not tom.get("thcs") or not tom.get("thpt"):
        return "thiếu bản THCS hoặc THPT"
    n1, n2 = len(tom["thcs"].split()), len(tom["thpt"].split())
    if not (40 <= n1 <= 150) or not (60 <= n2 <= 240):
        return f"độ dài lệch khoảng (THCS {n1} từ, THPT {n2} từ)"
    cho_phep = set(so_a)
    if nam_su_kien is not None:
        cho_phep.add(str(abs(int(nam_su_kien))))
    la = (cac_so(tom["thcs"]) | cac_so(tom["thpt"])) - cho_phep
    if la:
        return f"có con số không khớp mệnh đề hạng A nào: {', '.join(sorted(la))}"
    return None


_TU_RONG = {"khoảng", "hơn", "gần", "chừng", "năm", "thời", "kỳ", "kì", "của", "và", "là", "các",
            "những", "một", "được", "có", "cho", "với", "trong", "tại", "ở", "đã", "bị", "theo", "người"}


def _tu_noi_dung(s: str) -> set[str]:
    return {w for w in chuan_hoa_so_khop(s).split() if len(w) >= 2 and w not in _TU_RONG and not w.isdigit()}


def mde_chua_dap_an(dap_an: str, m: dict) -> bool:
    """Mệnh đề có thật sự CHỨA đáp án không — kiểm bằng code.

    Mọi con số trong đáp án phải có trong mệnh đề (nội dung hoặc câu trích),
    và ít nhất một nửa số từ nội dung của đáp án phải có mặt. Đáp án không có
    từ nội dung nào (vd "Khoảng 60") thì chỉ xét số.
    """
    chu = m["noi_dung"] + " " + m["trich_dan"]
    if not cac_so(dap_an) <= cac_so(chu):
        return False
    tu = _tu_noi_dung(dap_an)
    if not tu:
        return bool(cac_so(dap_an))
    return len(tu & _tu_noi_dung(chu)) / len(tu) >= 0.5


def kiem_can_cu(q: dict, md_a: list[dict]) -> tuple[list[str] | None, str | None]:
    """Đáp án đúng phải nằm trong mệnh đề căn cứ. Mô hình hay trỏ nhầm số thứ tự
    mệnh đề — thì tìm lại trong mọi mệnh đề hạng A; không có đâu thì loại.

    Soát mẫu vòng 1: 3/4 câu có câu trích căn cứ không liên quan đáp án (câu hỏi
    số quân Nguyên thiệt hại lại dẫn câu Trần Quốc Tuấn giăng bẫy). Trước đây
    cổng chỉ xét "có trỏ về mệnh đề A", không xét "mệnh đề đó chứa đáp án".
    """
    dap_an = q["phuong_an"][q["dap_an"]]
    theo_id = {m["id"]: m for m in md_a}

    def khop(m: dict) -> bool:
        # Đáp án có trong mệnh đề CHƯA ĐỦ: câu "Quang Trung lên ngôi vào dịp nào"
        # từng lấy căn cứ là câu "quân Tây Sơn tiến lên làng Ngọc Hồi" chỉ vì đáp
        # án tình cờ chung chữ "tiến quân". Câu hỏi cũng phải nói về điều mệnh đề nói.
        if not mde_chua_dap_an(dap_an, m):
            return False
        tu_hoi = _tu_noi_dung(q["cau_hoi"])
        return not tu_hoi or len(tu_hoi & _tu_noi_dung(m["noi_dung"] + " " + m["trich_dan"])) / len(tu_hoi) >= 0.25

    dung = [i for i in q["menh_de"] if i in theo_id and khop(theo_id[i])]
    if dung:
        return dung, None
    tim = [m["id"] for m in md_a if khop(m)]
    if tim:
        return tim[:2], None
    return None, f"đáp án '{dap_an}' không có trong mệnh đề hạng A nào — mô hình có thể đã dùng kiến thức ngoài nguồn"


def xu_ly(mo_hinh: MoHinh, tt: dict, nam: int | None) -> None:
    slug = tt["slug"]
    tep = RA / f"{slug}.json"
    if tep.exists():
        return
    b5 = doc_json(KET_QUA / "b5" / f"{slug}.json")
    b4 = doc_json(KET_QUA / "b4" / f"{slug}.json")
    if not b5 or not b4:
        return
    if b5["loai"] != "su_kien":
        ghi_json(tep, {**b5, "dat": True})
        return

    so_a = set()
    for m in b4["menh_de"]:
        if m["hang"] == "A":
            so_a |= cac_so(m["noi_dung"])

    loi_tom = kiem_tom_tat(b5["tom_tat"], so_a, nam)

    co_san = cau_hoi_co_san(slug) if tt.get("co_san") else []
    qua, truot = [], []
    for q in b5["cau_hoi"]:
        loi = kiem_khuon(q)
        if not loi and any(gan_giong(q["cau_hoi"], c) for c in co_san):
            loi = "trùng câu đã có trong app"
        if not loi and any(gan_giong(q["cau_hoi"], c["cau_hoi"]) for c in qua):
            loi = "trùng câu vừa sinh"
        (truot if loi else qua).append({**q, "ly_do": loi} if loi else q)

    ket = lam_bai_mu(mo_hinh, slug, qua) if qua else []
    dat = []
    md_a = [m for m in b4["menh_de"] if m["hang"] == "A"]
    for q, (ok, ly_do) in zip(qua, ket):
        if not ok:
            truot.append({**q, "ly_do": ly_do})
            continue
        # Cổng 7 — chạy SAU làm bài mù để các lô gửi đi không đổi, chạy lại dùng được cache.
        can_cu, loi = kiem_can_cu(q, md_a)
        if not loi:
            # Cùng đáp án, cùng căn cứ = cùng một câu hỏi viết lại. So chữ (> 80%
            # giống) để lọt 3 câu "quân Nam Hán do ai chỉ huy" diễn đạt khác nhau.
            da = chuan_hoa_so_khop(q["phuong_an"][q["dap_an"]])
            if any(chuan_hoa_so_khop(d["phuong_an"][d["dap_an"]]) == da and set(d["menh_de"]) & set(can_cu)
                   for d in dat):
                loi = "trùng ý câu đã nhận (cùng đáp án, cùng căn cứ)"
        if loi:
            truot.append({**q, "ly_do": loi})
        else:
            dat.append({**q, "menh_de": can_cu})

    # Cân bằng vị trí đáp án — xác định theo slug để chạy lại vẫn ra đúng như cũ
    ngau = random.Random(slug)
    vi_tri = list("abcd") * (len(dat) // 4 + 1)
    ngau.shuffle(vi_tri)
    dat = [dao_phuong_an(q, vi_tri[i]) for i, q in enumerate(dat)]

    ghi_json(tep, {"slug": slug, "loai": "su_kien",
                   "tom_tat": b5["tom_tat"] if not loi_tom else None,
                   "tom_tat_bi_loai": {"ban": b5["tom_tat"], "ly_do": loi_tom} if loi_tom else None,
                   "cau_hoi": dat, "cau_hoi_bi_loai": truot})
    ghi_log(f"B6 {slug}: tóm tắt {'ĐẠT' if not loi_tom else 'loại (' + loi_tom + ')'}, "
            f"câu hỏi {len(dat)} đạt / {len(truot)} loại")


def main(vong: int | None = None) -> None:
    ch = doc_cau_hinh()
    mo_hinh = MoHinh(ch["llm"])
    b2 = doc_json(KET_QUA / "b2_tong_hop.json", {})
    for tt in doc_json(KET_QUA / "b1_thuc_the.json")["thuc_the"]:
        if (vong is None or tt["vong"] == vong) and tt.get("bai_wp") and not bi_loai_tru(tt, ch):
            an_toan("B6", tt["slug"], lambda: xu_ly(mo_hinh, tt, (b2.get(tt["slug"]) or {}).get("nam")))


if __name__ == "__main__":
    main()
