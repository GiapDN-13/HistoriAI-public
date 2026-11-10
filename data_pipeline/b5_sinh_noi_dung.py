"""B5 — Sinh nội dung cho app từ các mệnh đề đã xếp hạng.

Mỗi mẩu nội dung sinh ra phải TRỎ VỀ id mệnh đề nó dựa vào — để B6 kiểm và
để người duyệt lần ngược được tới câu trích gốc.

    SỰ KIỆN   tóm tắt THCS + THPT (mệnh đề A và B), câu hỏi quiz (CHỈ mệnh đề A)
    VĨ NHÂN   khối "sử liệu đã kiểm chứng" nối vào persona — ghép bằng code từ
              mệnh đề A, không qua mô hình, nên không có chỗ cho bịa. Mệnh đề C
              thành danh sách "điểm sử sách ghi khác nhau" để nhân vật biết mình
              không chắc thay vì chọn đại một con số.
    CỔ VẬT    chỉ gắn nguồn. Mô tả hiện có do nhóm viết cho đúng mô hình 3D; bài
              Wikipedia viết về LOẠI hiện vật, thay mô tả bằng nó dễ lệch với
              đúng hiện vật đang hiển thị.

RA
    ket_qua/b5/<slug>.json
"""
from __future__ import annotations

from chung import KET_QUA, MoHinh, an_toan, bi_loai_tru, doc_cau_hinh, doc_json, ghi_json, ghi_log

RA = KET_QUA / "b5"
RA.mkdir(parents=True, exist_ok=True)

HE_THONG_TOM_TAT = """Bạn viết tóm tắt lịch sử cho học sinh Việt Nam. Chỉ được dùng thông tin trong DANH SÁCH MỆNH ĐỀ.
Mệnh đề đánh dấu [A] đã được hai nguồn xác nhận; [B] chỉ một nguồn — dùng [B] thận trọng, không lấy năm tháng hay con số từ [B].
Viết hai bản:
- "thcs": cho học sinh lớp 6–9, 60–100 từ, câu ngắn, ít thuật ngữ.
- "thpt": cho học sinh lớp 10–12, 100–160 từ, có bối cảnh, diễn biến chính, ý nghĩa.
Diễn đạt lại bằng lời của bạn, KHÔNG chép nguyên câu. Không thêm bất kỳ năm, con số, tên người, địa danh nào ngoài danh sách.
"thoi_ky": tên thời kỳ/triều đại ngắn gọn (vd "Nhà Trần", "Tây Sơn", "Bắc thuộc", "Kháng chiến chống Pháp").
"menh_de_dung": mảng số thứ tự các mệnh đề đã dùng.
Trả về JSON: {"thcs": "...", "thpt": "...", "thoi_ky": "...", "menh_de_dung": [1, 2]}"""

HE_THONG_QUIZ = """Bạn là giáo viên Lịch sử ra đề trắc nghiệm cho học sinh Việt Nam. Chỉ được dùng các MỆNH ĐỀ ĐÃ KIỂM CHỨNG dưới đây làm căn cứ cho đáp án đúng.
Quy tắc:
- Mỗi câu có 4 phương án, CHỈ MỘT phương án đúng. Ba phương án nhiễu phải hợp lý (cùng loại: năm gần, nhân vật cùng thời, địa danh cùng vùng) nhưng chắc chắn sai.
- Không dùng "tất cả các đáp án trên", "cả A và B", câu phủ định kép.
- Mức độ: "biet" (nhớ dữ kiện), "hieu" (giải thích nguyên nhân, ý nghĩa), "van_dung" (so sánh, rút ra bài học). Cố gắng có đủ ba mức.
- Câu hỏi ngắn gọn (dưới 35 từ), phù hợp học sinh.
- "menh_de": số thứ tự mệnh đề làm căn cứ cho đáp án đúng. "yccd": số thứ tự yêu cầu cần đạt mà câu hỏi phục vụ (0 nếu không có).
- "giai_thich": 1–2 câu vì sao đáp án đúng.
Trả về mảng JSON: [{"cau_hoi": "...", "a": "...", "b": "...", "c": "...", "d": "...", "dap_an": "a", "muc_do": "biet", "menh_de": [3], "yccd": 1, "giai_thich": "..."}]"""


def yccd_cua(khung: dict, ma_ds: list[str]) -> list[str]:
    ra = []
    for cd in khung["chu_de"]:
        if cd["ma"] in ma_ds:
            for m in cd["muc"]:
                if m.get("viet_nam", True):
                    ra += m["yccd"]
    # giữ thứ tự, bỏ trùng
    return list(dict.fromkeys(ra))


def sinh_su_kien(mo_hinh: MoHinh, ch: dict, tt: dict, b4: dict, khung: dict) -> dict:
    slug = tt["slug"]
    ten = tt["bai_wp"]["title"]
    md_a = [m for m in b4["menh_de"] if m["hang"] == "A"]
    md_b = [m for m in b4["menh_de"] if m["hang"] == "B" and m["nguon"] != "wikidata"]
    ds = md_a + md_b[:40]
    danh_sach = "\n".join(f"{k + 1}. [{m['hang']}] {m['noi_dung']}" for k, m in enumerate(ds))
    tom = mo_hinh.hoi_json(HE_THONG_TOM_TAT, f"Chủ đề: {ten}\n\nDANH SÁCH MỆNH ĐỀ:\n{danh_sach}",
                           toi_da=900, nhan=f"B5 tóm tắt {slug}") or {}
    dung = []
    for k in tom.get("menh_de_dung", []) if isinstance(tom, dict) else []:
        try:
            dung.append(ds[int(k) - 1]["id"])
        except (ValueError, IndexError, TypeError):
            pass

    cau_hoi = []
    yccd = yccd_cua(khung, tt["ma"])[:8]
    tran = ch["sinh"]["cau_hoi_toi_da_moi_su_kien"] if tt["vong"] == 1 else ch["sinh"]["cau_hoi_toi_da_vong_2"]
    so_cau = min(tran, len(md_a))
    if so_cau >= 1:
        ds_a = "\n".join(f"{k + 1}. {m['noi_dung']}" for k, m in enumerate(md_a[:45]))
        ds_y = "\n".join(f"{k + 1}. {y}" for k, y in enumerate(yccd)) or "(không có)"
        # Groq miễn phí chỉ cho ~1.000 token đầu ra mỗi phút và từ chối lượt xin
        # nhiều hơn — nên ra đề theo từng lượt 3 câu, kèm các câu đã có để lượt
        # sau không ra trùng.
        lan = 0
        while len(cau_hoi) < so_cau and lan < 5:
            lan += 1
            da_co = "\n".join(f"- {q['cau_hoi']}" for q in cau_hoi) or "(chưa có)"
            n = min(3, so_cau - len(cau_hoi))
            kq = mo_hinh.hoi_json(
                HE_THONG_QUIZ,
                f"Chủ đề: {ten}\nSố câu cần ra: {n}\n\nMỆNH ĐỀ ĐÃ KIỂM CHỨNG:\n{ds_a}\n\n"
                f"YÊU CẦU CẦN ĐẠT (chương trình GDPT 2018):\n{ds_y}\n\n"
                f"CÂU ĐÃ RA (không lặp lại nội dung):\n{da_co}",
                toi_da=900, nhan=f"B5 quiz {slug} {lan}")
            moi_ra = 0
            for q in kq if isinstance(kq, list) else []:
                if not isinstance(q, dict):
                    continue
                can_cu = []
                for k in q.get("menh_de", []) or []:
                    try:
                        can_cu.append(md_a[:45][int(k) - 1]["id"])
                    except (ValueError, IndexError, TypeError):
                        pass
                try:
                    y = int(q.get("yccd") or 0)
                    y_chu = yccd[y - 1] if 1 <= y <= len(yccd) else None
                except (ValueError, TypeError):
                    y_chu = None
                cau_hoi.append({
                    "cau_hoi": str(q.get("cau_hoi", "")).strip(),
                    "phuong_an": {k: str(q.get(k, "")).strip() for k in "abcd"},
                    "dap_an": str(q.get("dap_an", "")).strip().lower()[:1],
                    "muc_do": q.get("muc_do") if q.get("muc_do") in ("biet", "hieu", "van_dung") else "biet",
                    "menh_de": can_cu, "yccd": y_chu,
                    "giai_thich": str(q.get("giai_thich", "")).strip(),
                })
                moi_ra += 1
            if moi_ra == 0:
                break      # mô hình trả rác hai lần liền thì thôi, không đốt thêm lượt
    return {"slug": slug, "loai": "su_kien",
            "tom_tat": {"thcs": (tom or {}).get("thcs", ""), "thpt": (tom or {}).get("thpt", ""),
                        "thoi_ky": (tom or {}).get("thoi_ky", ""), "menh_de_dung": dung},
            "cau_hoi": cau_hoi}


def sinh_nhan_vat(tt: dict, b4: dict) -> dict:
    a = [m for m in b4["menh_de"] if m["hang"] == "A" and m["nguon"] != "wikidata"]
    c = [m for m in b4["menh_de"] if m["hang"] == "C"]
    # Mỗi dữ kiện A có ít nhất 2 bản (một mỗi nguồn); chỉ giữ bản Wikipedia cho gọn
    a_wp = [m for m in a if m["nguon"] == "wikipedia"] or a
    khoi = ""
    if a_wp:
        khoi += "SỬ LIỆU ĐÃ KIỂM CHỨNG (≥ 2 nguồn độc lập xác nhận):\n" + \
                "\n".join(f"- {m['noi_dung']}" for m in a_wp[:40])
    if c:
        khoi += ("\n\nCÁC ĐIỂM SỬ SÁCH GHI KHÁC NHAU — nếu được hỏi, nói rõ là các nguồn chưa thống "
                 "nhất, KHÔNG chọn đại một đáp án:\n" +
                 "\n".join(f"- {m['noi_dung']}" for m in c[:15] if m["nguon"] == "wikipedia"))
    return {"slug": tt["slug"], "loai": "nhan_vat", "khoi_su_lieu": khoi.strip(),
            "menh_de": [m["id"] for m in a_wp[:40]]}


def main(vong: int | None = None) -> None:
    ch = doc_cau_hinh()
    mo_hinh = MoHinh(ch["llm"])
    khung = doc_json(KET_QUA / "b0_khung.json")
    for tt in doc_json(KET_QUA / "b1_thuc_the.json")["thuc_the"]:
        if (vong is not None and tt["vong"] != vong) or not tt.get("bai_wp") or bi_loai_tru(tt, ch):
            continue
        tep = RA / f"{tt['slug']}.json"
        if tep.exists():
            continue
        b4 = doc_json(KET_QUA / "b4" / f"{tt['slug']}.json")
        if not b4 or not b4.get("xong"):
            continue
        def viec(tt=tt, b4=b4, tep=tep):
            if tt["loai"] == "su_kien":
                kq = sinh_su_kien(mo_hinh, ch, tt, b4, khung)
                ghi_log(f"B5 {tt['slug']}: tóm tắt {'có' if kq['tom_tat']['thcs'] else 'TRỐNG'}, "
                        f"{len(kq['cau_hoi'])} câu hỏi nháp")
            elif tt["loai"] == "nhan_vat":
                kq = sinh_nhan_vat(tt, b4)
                ghi_log(f"B5 {tt['slug']}: khối sử liệu {len(kq['menh_de'])} dữ kiện")
            else:
                kq = {"slug": tt["slug"], "loai": "co_vat"}
            ghi_json(tep, kq)
        an_toan("B5", tt["slug"], viec)


if __name__ == "__main__":
    main()
