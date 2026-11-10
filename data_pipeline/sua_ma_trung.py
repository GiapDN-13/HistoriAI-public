"""Sửa một lần: đánh số lại mã mệnh đề bị trùng trong các tệp B3 đã có.

Lỗi đếm ở B3 làm mọi đoạn đánh số lại từ wp0. Script này giữ NGUYÊN nội dung
và thứ tự mệnh đề, chỉ đổi mã cho duy nhất: wp0, wp1, … theo đúng thứ tự xuất
hiện. Vì nội dung và thứ tự không đổi, lời gọi B4 sau đó vẫn khớp cache.

Chạy xong phải xoá kết quả B4/B5/B6 để tính lại với mã đúng.
"""
import re

from chung import KET_QUA, doc_json, ghi_json, ghi_log


def main() -> None:
    sua = 0
    for tep in sorted((KET_QUA / "b3").glob("*.json")):
        b3 = doc_json(tep)
        dem: dict[str, int] = {}
        trung = len({m["id"] for m in b3["menh_de"]}) != len(b3["menh_de"])
        for m in b3["menh_de"]:
            slug, duoi = m["id"].split("#", 1)
            nguon = re.match(r"[a-z]+", duoi).group(0)
            m["id"] = f"{slug}#{nguon}{dem.get(nguon, 0)}"
            dem[nguon] = dem.get(nguon, 0) + 1
        ghi_json(tep, b3)
        sua += trung
    ghi_log(f"Sửa mã trùng: {sua} tệp B3 có mã trùng đã được đánh số lại")


if __name__ == "__main__":
    main()
