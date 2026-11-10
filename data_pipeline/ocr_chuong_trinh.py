"""Nhận dạng chữ bản scan Thông tư 13/2022 (chương trình Lịch sử THPT sửa đổi).

VÌ SAO PHẢI OCR
    Bản PDF trên Cổng thông tin Chính phủ là ảnh scan có chữ ký số, không có lớp
    chữ. Chương trình Lịch sử THPT bản 2018 thì có chữ, nhưng đã bị Thông tư
    13/2022 sửa đổi — dùng bản cũ là gắn nội dung vào một chương trình không còn
    hiệu lực.

Mỗi trang ghi ra một tệp JSON gồm từng dòng chữ kèm toạ độ khung. Toạ độ là thứ
cho phép tách hai cột "Nội dung" / "Yêu cầu cần đạt" ở bước B0. Trang nào đã
nhận dạng rồi thì bỏ qua, nên dừng giữa chừng chạy lại vẫn an toàn.
"""
import json
import sys

import fitz
import easyocr

from chung import CACHE, ghi_log

PDF = CACHE / "chuong_trinh" / "tt13_2022.pdf"
RA = CACHE / "chuong_trinh" / "ocr_tt13"
RA.mkdir(parents=True, exist_ok=True)


def main() -> None:
    d = fitz.open(PDF)
    doc = easyocr.Reader(["vi"], gpu=False, verbose=False)
    for i in range(len(d)):
        tep = RA / f"trang_{i + 1:02d}.json"
        if tep.exists():
            continue
        anh = d[i].get_pixmap(dpi=200).tobytes("png")
        dong = doc.readtext(anh, detail=1, paragraph=False)
        ket_qua = [
            {"x0": float(min(p[0] for p in hop)), "y0": float(min(p[1] for p in hop)),
             "x1": float(max(p[0] for p in hop)), "y1": float(max(p[1] for p in hop)),
             "chu": chu, "tin_cay": round(float(tc), 3)}
            for hop, chu, tc in dong
        ]
        tep.write_text(json.dumps({"trang": i + 1, "rong": d[i].rect.width * 200 / 72,
                                   "dong": ket_qua}, ensure_ascii=False), encoding="utf-8")
        ghi_log(f"OCR trang {i + 1}/{len(d)}: {len(ket_qua)} dòng")
    ghi_log("OCR xong")


if __name__ == "__main__":
    sys.exit(main())
