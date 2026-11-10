"""Đọc nhiều câu trắc nghiệm từ một khối chữ dán vào — để giáo viên soạn đề nhanh.

Giáo viên (hoặc AI theo prompt trong docs/HUONG_DAN_KIEM_TRA_TREN_LOP.md) viết:

    Câu 1: Trận Bạch Đằng năm 938 do ai chỉ huy?
    A. Ngô Quyền
    B. Lê Hoàn
    C. Trần Hưng Đạo
    D. Lý Thường Kiệt
    Đáp án: A
    Giải thích: Năm 938 Ngô Quyền đánh tan quân Nam Hán trên sông Bạch Đằng.

Chịu được những lệch thường gặp khi chép từ Word/ChatGPT: "Câu hỏi 1." / "1)" / "1.",
"A)" / "A:" / "a.", chữ đậm **…**, dòng trống thừa, câu hỏi dài nhiều dòng, giải thích
nhiều dòng, "Đáp án đúng: B", "Đáp án: B. Lê Hoàn".
"""
from __future__ import annotations

import re

_DAU_CAU = re.compile(r"^(?:câu(?:\s*hỏi)?\s*\d*\s*[:.)\-–]?|\d{1,3}\s*[.):\-–])\s*(.*)$", re.I)
_PHUONG_AN = re.compile(r"^\(?([A-Da-d])\s*[.):\-–]\s*(.+)$")
_DAP_AN = re.compile(r"^(?:đáp\s*án(?:\s*đúng)?|answer|đ/?a)\s*[:：\-–]?\s*\(?([A-Da-d])\b", re.I)
_GIAI_THICH = re.compile(r"^(?:giải\s*thích|lời\s*giải|vì\s*sao|explanation)\s*[:：\-–]?\s*(.*)$", re.I)


def _sach(dong: str) -> str:
    dong = dong.replace("**", "").replace("__", "").strip()
    return re.sub(r"^[-*•]\s+", "", dong)


def doc(van_ban: str) -> list[dict]:
    """Trả danh sách câu thô: {question, option_a..d, correct_option, explanation}.

    Không kiểm hợp lệ ở đây (để route báo lỗi từng câu bằng tiếng Việt dễ hiểu)."""
    cac_cau: list[dict] = []
    hien: dict | None = None
    dang = None          # "hoi" | "giai_thich" — phần nào đang được viết tiếp nhiều dòng

    def moi(noi_dung: str) -> dict:
        c = {"question": noi_dung, "option_a": "", "option_b": "", "option_c": "", "option_d": "",
             "correct_option": "", "explanation": ""}
        cac_cau.append(c)
        return c

    for dong_tho in van_ban.replace("\r", "").split("\n"):
        dong = _sach(dong_tho)
        if not dong or set(dong) <= set("-=_*#"):
            continue
        if m := _DAP_AN.match(dong):
            if hien is not None:
                hien["correct_option"] = m.group(1).upper()
            dang = None
            continue
        if m := _GIAI_THICH.match(dong):
            if hien is not None:
                hien["explanation"] = m.group(1).strip()
            dang = "giai_thich"
            continue
        m = _PHUONG_AN.match(dong)
        # "A. …" là phương án chỉ khi đang có câu hỏi và chưa sang phần giải thích
        if m and hien is not None and dang != "giai_thich":
            hien[f"option_{m.group(1).lower()}"] = m.group(2).strip()
            dang = None
            continue
        if m := _DAU_CAU.match(dong):
            hien = moi(m.group(1).strip())
            dang = "hoi"
            continue
        if hien is None:          # chữ trước câu đầu tiên (lời dẫn của AI) — bỏ
            continue
        if dang == "giai_thich":
            hien["explanation"] = (hien["explanation"] + " " + dong).strip()
        elif dang == "hoi" and not hien["option_a"]:
            hien["question"] = (hien["question"] + " " + dong).strip()
        else:
            # Gặp dòng lạ sau khi đã có phương án: coi là câu hỏi mới không đánh số
            hien = moi(dong)
            dang = "hoi"
    return cac_cau


def ly_do_loi(c: dict) -> str | None:
    """Lỗi đầu tiên của một câu, viết cho giáo viên đọc. None = hợp lệ (trừ trùng phương án)."""
    if len(c["question"]) < 5:
        return "Thiếu nội dung câu hỏi."
    thieu = [k.upper() for k in "abcd" if not c[f"option_{k}"]]
    if thieu:
        return f"Thiếu phương án {', '.join(thieu)}."
    if not c["correct_option"]:
        return 'Thiếu dòng "Đáp án: …".'
    if len(c["question"]) > 1000:
        return "Câu hỏi dài quá 1000 ký tự."
    if any(len(c[f"option_{k}"]) > 300 for k in "abcd"):
        return "Có phương án dài quá 300 ký tự."
    if len(c["explanation"]) > 2000:
        return "Giải thích dài quá 2000 ký tự."
    pa = [" ".join(c[f"option_{k}"].split()).lower() for k in "abcd"]
    if len(set(pa)) < 4:
        return "Bốn phương án phải khác nhau."
    return None
