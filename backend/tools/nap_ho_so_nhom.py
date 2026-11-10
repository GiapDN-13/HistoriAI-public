"""Nạp HỒ SƠ NHÂN VẬT do nhóm biên soạn (.docx) thành kho sử liệu cho chat.

Hồ sơ nhóm (thư mục EXE201/KNB/, ngày 27/09/2026) là nguồn ƯU TIÊN CAO NHẤT: người
biên soạn đã đối chiếu và ghi sẵn các lưu ý diễn giải ("không gán cho ông quyền chỉ
huy trực tiếp…", "các số liệu… là ước tính"). Đứng trên mệnh đề tự động của đường ống.

Cấu trúc tệp: mọi đoạn đều style Normal; tiêu đề nhận theo đầu dòng
    "I. …" (số La Mã) · "A. …" (chữ cái) · "1. …" (số)      — ý thì bắt đầu bằng "- ".
Mỗi ý thành một mục {t, muc, hang: "K"}; `muc` là chuỗi tiêu đề ("Trận Bạch Đằng
(1288) › Bố trí và diễn biến") — vừa giúp tìm đúng đoạn, vừa cho mô hình biết ý đó
thuộc bối cảnh nào.

DÙNG (từ thư mục backend/):
    python tools/nap_ho_so_nhom.py "…/KNB/TRẦN-HƯNG-ĐẠO-Knowledge-Base.docx" \\
                                   "…/KNB/QUANG-TRUNG-Knowledge-Base.docx"
    → ghi data/ho_so_nhom.json (tệp riêng: chạy lại đường ống không ghi đè).
"""
from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

import docx

RA = Path(__file__).resolve().parents[1] / "data" / "ho_so_nhom.json"
NGUON = "Hồ sơ nhân vật (nhóm HistoriAI biên soạn)"

# Tên tệp → slug vĩ nhân trong CSDL
SLUG = {"TRAN-HUNG-DAO": "tran-hung-dao", "QUANG-TRUNG": "quang-trung"}

_LA_MA = re.compile(r"^(?:[IVX]+)\.\s+(.+)$")
_CHU = re.compile(r"^[A-Z]\.\s+(.+)$")
_SO = re.compile(r"^\d+\.\s+(.+)$")


def _bo_dau(s: str) -> str:
    s = unicodedata.normalize("NFD", s.replace("Đ", "D").replace("đ", "d"))
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def _slug(duong: Path) -> str:
    ten = _bo_dau(duong.stem).upper()
    for k, v in SLUG.items():
        if ten.startswith(k):
            return v
    raise SystemExit(f"Không biết tệp {duong.name} là của vĩ nhân nào — thêm vào SLUG.")


def _viet_hoa_dau(s: str) -> str:
    """"TRẬN BẠCH ĐẰNG (1288)" → "Trận bạch đằng (1288)" thì xấu; chỉ hạ chữ hoa khi cả
    dòng viết HOA (tiêu đề cấp I), giữ nguyên các tiêu đề đã viết thường."""
    return s.capitalize() if s.isupper() else s


def doc(duong: Path) -> list[dict]:
    muc = ["", "", ""]
    ra: list[dict] = []
    for p in docx.Document(str(duong)).paragraphs:
        t = " ".join(p.text.split())
        if not t or "KNOWLEDGE BASE" in t.upper():
            continue
        if t.startswith("- "):
            y = t[2:].strip()
            if y:
                ra.append({"t": y, "muc": " › ".join(m for m in muc if m), "hang": "K",
                           "nguon": NGUON, "url": ""})
            continue
        for cap, mau in enumerate((_LA_MA, _CHU, _SO)):
            m = mau.match(t)
            if m:
                muc[cap] = _viet_hoa_dau(m.group(1).strip())
                for sau in range(cap + 1, 3):
                    muc[sau] = ""
                break
    return ra


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    kho: dict[str, list[dict]] = {}
    for a in sys.argv[1:]:
        p = Path(a)
        ds = doc(p)
        kho[_slug(p)] = ds
        print(f"  {_slug(p)}: {len(ds)} ý từ {p.name}")
    RA.write_text(json.dumps(kho, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"  ghi {RA}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
