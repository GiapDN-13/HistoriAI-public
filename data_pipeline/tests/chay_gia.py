"""Chạy B3→B7 bằng mô hình GIẢ để bắt lỗi ráp nối, không tốn lượt gọi thật.

Mô hình giả trả lời theo nhãn lượt gọi: B3 thì trích đúng câu đầu của đoạn,
B4 ghép cặp mệnh đề đầu, B5 sinh 3 câu hỏi, B6 làm bài đúng hết.
Chạy trong thư mục tạm để không đụng kết quả thật.
"""
import re, shutil, sys, tempfile
from pathlib import Path
GOC = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GOC))
import chung

tam = Path(tempfile.mkdtemp())
for d in ("b3", "b4", "b5", "b6", "hang_cho"):
    (tam / d).mkdir()
for t in ("b0_khung.json", "b1_thuc_the.json", "b2_tong_hop.json"):
    shutil.copy(GOC / "ket_qua" / t, tam / t)

def gia(self, he, nd, **kw):
    nhan = kw.get("nhan", "")
    if nhan.startswith("B3"):
        doan = nd.split("ĐOẠN VĂN:\n", 1)[1]
        cau = [c for c in re.split(r"(?<=[.!?])\s+", doan) if 8 <= len(c.split()) <= 40 and "=" not in c][:3]
        return [{"noi_dung": re.sub(r"\d", "", c)[:120] or "x", "trich_dan": c, "loai": "dien_bien"} for c in cau]
    if nhan.startswith("B4"):
        return {"trung": [[1, 1], [2, 2]], "mau_thuan": []}
    if nhan.startswith("B5 tóm tắt"):
        return {"thcs": "chữ " * 70, "thpt": "chữ " * 120, "thoi_ky": "Nhà Trần", "menh_de_dung": [1]}
    if nhan.startswith("B5 quiz"):
        return [{"cau_hoi": f"Câu hỏi thử {i} {nhan}?", "a": f"Đúng {i}", "b": f"Sai b{i}", "c": f"Sai c{i}",
                 "d": f"Sai d{i}", "dap_an": "a", "muc_do": "biet", "menh_de": [1], "yccd": 1,
                 "giai_thich": "vì thế"} for i in range(3)]
    if nhan.startswith("B6"):
        n = nd.count("Câu ")
        return [{"so": k + 1, "chon": "?", "so_dung": 1} for k in range(n)]
    return None

chung.MoHinh.hoi_json = gia
import b3_trich_menh_de as b3, b4_kiem_chung_cheo as b4, b5_sinh_noi_dung as b5, b6_cong_chat_luong as b6, b7_xuat_seed as b7
for m in (b3, b4, b5, b6, b7):
    m.KET_QUA = tam
b3.RA, b4.RA, b5.RA, b6.RA = tam / "b3", tam / "b4", tam / "b5", tam / "b6"
b7.HANG_CHO = tam / "hang_cho"

# B6 cần đáp án đúng: vá lượt làm bài để luôn chọn đáp án đúng của từng câu
goc_lam = b6.lam_bai_mu
b6.lam_bai_mu = lambda mh, slug, ds: [(True, "")] * len(ds)
b6.cau_hoi_co_san = lambda slug: []

b3.main(1); b4.main(1); b5.main(1); b6.main(1)
seed = b7.main(False)
print("SỰ KIỆN:", [(e["slug"], e["grades"], len(e["sources"])) for e in seed["events"]])
print("CÂU HỎI:", len(seed["quiz"]), "| đáp án:", sorted({q["correct_option"] for q in seed["quiz"]}))
print("VĨ NHÂN:", [(f["slug"], len(f["verified_facts"] or "")) for f in seed["figures"]])
print("CỔ VẬT:", len(seed["artifacts"]))
print("BÁO CÁO:", (tam / "hang_cho" / "bao_cao.html").stat().st_size, "byte →", tam / "hang_cho" / "bao_cao.html")
