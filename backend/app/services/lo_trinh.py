"""Bài học theo LỘ TRÌNH do nhóm soạn — mục "Bài học theo lộ trình" ở màn chi tiết sự kiện.

VÌ SAO
    Góp ý lặp lại nhiều nhất là "nội dung còn ít". Nhóm đã soạn tài liệu lộ trình bám
    SGK (mục tiêu, bối cảnh, diễn biến, kết quả, câu chốt cho từng trận);
    `tools/nhap_lo_trinh.py` chuyển nguyên văn tài liệu thành `data/lo_trinh.json`.

CHỈ TRẢ BẢN ĐÃ DUYỆT
    Tệp có thể chứa cả bản nháp (vd lộ trình Lam Sơn → Quang Trung do AI soạn, chờ
    nhóm kiểm theo SGK). Đây là nội dung học sinh đọc để học bài — một ý sai lọt lên
    là dạy sai. Nên chỉ lộ trình có `da_duyet` đúng bằng `true` mới ra API; chuỗi
    "true" hay thiếu trường đều coi là chưa duyệt.

Đọc tệp một lần rồi giữ trong bộ nhớ (như `soan_san.py`): nội dung chỉ đổi khi chạy
lại script nhập và khởi động lại máy chủ. Tệp hỏng hay thiếu thì trả rỗng — app ẩn
mục bài học chứ không vỡ màn.
"""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

TEP = Path(__file__).resolve().parents[2] / "data" / "lo_trinh.json"


@lru_cache(maxsize=1)
def _kho() -> tuple[dict, ...]:
    try:
        tho = json.loads(TEP.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return ()
    ds = tho.get("lo_trinh", []) if isinstance(tho, dict) else []
    return tuple(lt for lt in ds if isinstance(lt, dict) and lt.get("da_duyet") is True)


def da_duyet(day_du: bool) -> list[dict]:
    """Các lộ trình đã duyệt, đúng thứ tự trong tệp.

    `day_du=False` (bản thường): bài ĐẦU của mỗi lộ trình giữ nguyên để ai cũng học
    thử được; các bài sau chỉ còn `muc_tieu` + `cau_chot`, đánh `khoa: true`. Cắt ở
    máy chủ, không giấu ở giao diện: nội dung bài khoá không có trong phản hồi thì
    không ai lấy được bằng cách mở công cụ nhà phát triển. Bắt buộc truyền `day_du`
    để không ai quên mà vô tình trả đủ cho khách.
    """
    ra = []
    for lt in _kho():
        bai = []
        for i, sk in enumerate(lt.get("su_kien", [])):
            if day_du or i == 0:
                bai.append({**sk, "khoa": False})
            else:
                bai.append({
                    "slug": sk.get("slug"), "ten": sk.get("ten"), "ten_ngan": sk.get("ten_ngan"),
                    "muc_tieu": sk.get("muc_tieu", ""), "cau_chot": sk.get("cau_chot", ""),
                    "boi_canh": [], "kien_thuc": {"tieu_de": "", "y": []},
                    "dien_bien": [], "ket_qua": [], "khoa": True,
                })
        ra.append({**lt, "su_kien": bai})
    return ra
