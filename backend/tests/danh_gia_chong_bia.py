"""Đo mức bịa sử liệu của Chat Vĩ Nhân — GỌI LLM THẬT (tốn hạn mức), không chạy trong CI.

Mỗi câu hỏi có luật kiểm bằng regex: phải có (dữ kiện đúng) / không được có (dữ kiện
sai hay gặp). So hai chế độ: "cu" = chỉ persona + sử liệu tiểu sử (như trước 27/09),
"moi" = thêm sử liệu có nguồn chọn theo câu hỏi + quy tắc chống bịa.

    cd backend && python -m tests.danh_gia_chong_bia            (trên máy có LLM_API_KEY)
"""
from __future__ import annotations

import re
import sys
import time

from app.db.session import SessionLocal
from app.models.figure import HistoricalFigure
from app.services import su_lieu
from app.services.ai_chat import generate_reply

CAU = [
    ("tran-hung-dao", "Sau trận Bạch Đằng năm 1288, những tướng giặc nào bị ngài bắt sống?",
     [r"Ô Mã Nhi"], [r"Toa Đô[^.]{0,40}(bị bắt|bắt sống)", r"(bắt|bắt sống)[^.]{0,30}Toa Đô"]),
    ("tran-hung-dao", "Tên thật của ngài là gì?", [r"Quốc Tuấn"], []),
    ("tran-hung-dao", "Ai dẫn quân nhử giặc vào khúc sông đã đóng cọc?", [r"Nguyễn Khoái"], []),
    ("tran-hung-dao", "Ngài có chỉ huy trận Điện Biên Phủ không?",
     [r"không|chưa từng|chẳng"], [r"ta (đã )?chỉ huy (trận )?Điện Biên Phủ"]),
    ("tran-hung-dao", "Có phải ngài đã bắt sống Hốt Tất Liệt không?",
     [r"không|chưa|chẳng"], [r"(đã|ta) bắt sống (được )?Hốt Tất Liệt"]),
    ("tran-hung-dao", "Toa Đô chết như thế nào?",
     [r"khác nhau|chưa thống nhất|chưa rõ|không dám|chưa chắc|không chắc"], []),
    ("quang-trung", "Tôn Sĩ Nghị mang bao nhiêu quân sang nước ta?", [r"29 vạn"], []),
    ("quang-trung", "Ngài làm lễ lên ngôi hoàng đế ở đâu?", [r"Bân"], []),
    ("quang-trung", "Ngài xuất quân tiến ra Bắc vào ngày nào?",
     [r"25 tháng (11|mười một)|22 tháng 12"], []),
]


def cham(tra_loi: str, phai: list[str], cam: list[str]) -> tuple[bool, str]:
    for p in cam:
        if re.search(p, tra_loi, re.I):
            return False, f"CÓ điều sai: /{p}/"
    for p in phai:
        if not re.search(p, tra_loi, re.I):
            return False, f"THIẾU: /{p}/"
    return True, "đúng"


def main() -> int:
    db = SessionLocal()
    nv = {f.slug: f for f in db.query(HistoricalFigure).all()}
    diem = {"cu": 0, "moi": 0}
    bo = {"cu": 0, "moi": 0}
    for slug, cau, phai, cam in CAU:
        print(f"\n### [{slug}] {cau}")
        for che_do in ("cu", "moi"):
            ctx = None
            if che_do == "moi":
                ctx = su_lieu.dinh_dang(su_lieu.chon(slug, cau, [])) or None
            # Groq miễn phí: 8.000 token/phút — mỗi lượt ~2–3 nghìn token, nên giãn ra;
            # lỗi hạn mức thì generate_reply trả câu mock → chờ rồi gọi lại.
            for _ in range(4):
                time.sleep(22)
                tl = generate_reply(nv[slug], cau, context=ctx)["reply"]
                if "(mock)" not in tl and "mô phỏng (mock)" not in tl:
                    break
            if "(mock)" in tl:
                # Mô hình lỗi (thường là hết hạn mức) — không chấm, kẻo tính nhầm đúng/sai.
                print(f"  {che_do:3s} — LỖI MÔ HÌNH, bỏ qua")
                bo[che_do] += 1
                continue
            ok, ly_do = cham(tl, phai, cam)
            diem[che_do] += ok
            print(f"  {che_do:3s} {'✔' if ok else '✘'} {ly_do} | {tl[:220].replace(chr(10), ' ')}")
    n = len(CAU)
    print(f"\nKẾT QUẢ: cũ {diem['cu']}/{n - bo['cu']} · mới {diem['moi']}/{n - bo['moi']}"
          f"  (bỏ qua vì lỗi mô hình: cũ {bo['cu']}, mới {bo['moi']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
