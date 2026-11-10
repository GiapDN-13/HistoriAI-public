"""Câu trả lời soạn sẵn cho các câu GỢI Ý ở màn chat — không tốn lượt AI.

VÌ SAO CẦN
    Groq miễn phí chỉ có ~200k token/ngày cho cả tổ chức, mỗi câu chat ~3,5k token
    → ~55 câu/ngày cho TẤT CẢ người dùng. Một lớp 30 em mỗi em bấm vài câu gợi ý là
    hết lượt, chat chết cho mọi người — đúng lúc demo. Mà phần lớn người thử đầu tiên
    bấm câu gợi ý chứ không tự gõ.

CÁCH LÀM
    `data/tra_loi_soan_san.json` giữ câu trả lời cho đúng các câu gợi ý trong app
    (`_suggestedQuestions` ở mobile/lib/features/chat/chat_screen.dart). Câu trả lời
    tạo MỘT LẦN bằng đúng đường chat thật — cùng lời nhắc, cùng sử liệu chống bịa —
    qua `python -m tools.soan_tra_loi`, rồi người trong nhóm đọc lại.

    Chỉ dùng khi câu gợi ý mở đầu cuộc trò chuyện (lịch sử rỗng): giữa chừng thì câu
    trả lời phải nối được mạch trước đó, bản soạn sẵn không làm được.

    Câu trả lời cố định còn có lợi phụ: giọng đọc từng câu đã nằm trong lưu đệm của
    máy chủ sau lần nghe đầu, nên những lần sau phát ngay, chắc chắn đúng giọng.
"""
from __future__ import annotations

import json
import re
import unicodedata
from functools import lru_cache
from pathlib import Path

TEP = Path(__file__).resolve().parents[2] / "data" / "tra_loi_soan_san.json"


def chuan_hoa(s: str) -> str:
    """So khớp không phân biệt hoa thường, dấu câu, khoảng trắng, kiểu ngoặc kép."""
    s = unicodedata.normalize("NFC", s).lower()
    s = re.sub(r"[^\w\s]", " ", s)
    return " ".join(s.split())


@lru_cache(maxsize=1)
def _kho() -> dict[tuple[str, str], dict]:
    try:
        tho = json.loads(TEP.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    kho = {}
    for slug, ds in tho.items():
        if slug.startswith("_"):
            continue
        for m in ds:
            if m.get("dap", "").strip():
                kho[(slug, chuan_hoa(m["hoi"]))] = m
    return kho


def tim(slug: str, cau_hoi: str, lich_su: list | None) -> dict | None:
    """Bản soạn sẵn {hoi, dap, nguon} nếu đây là câu gợi ý mở đầu cuộc trò chuyện."""
    if lich_su:
        return None
    return _kho().get((slug, chuan_hoa(cau_hoi)))


def manh(chu: str, so_tu: int = 3):
    """Cắt câu trả lời thành từng mẩu vài từ để app hiện dần như đang gõ."""
    tu = re.findall(r"\S+\s*", chu)
    for i in range(0, len(tu), so_tu):
        yield "".join(tu[i:i + so_tu])
