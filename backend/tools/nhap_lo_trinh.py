"""Nhập TÀI LIỆU LỘ TRÌNH HỌC do nhóm soạn (.docx) thành data/lo_trinh.json cho app.

VÌ SAO
    Góp ý lặp lại nhiều nhất của người dùng là "nội dung còn ít". Nhóm đã soạn tài
    liệu lộ trình bám sách giáo khoa (Bạch Đằng 938 → Chống Tống 981 → Bạch Đằng 1288)
    nhưng app mới dùng mỗi câu chốt (mobile/lib/data/ghi_nho.dart). Script này đưa
    phần bài học (mục tiêu, bối cảnh, diễn biến…) lên app mà không ai phải chép tay —
    chép tay là chỗ sai chữ và lệch bản với tài liệu gốc.

    Giữ NGUYÊN VĂN câu chữ của nhóm, chỉ cắt khoảng trắng thừa: nhóm đã đối chiếu
    từng câu với SGK, script không được "sửa giúp".

ĐỊNH DẠNG TÀI LIỆU (đúng như Lộ-trình-học-giai-đoạn-Bạch-Đằng.docx)
    Lộ trình học: <tên lộ trình>
    1. <tên trận>               ← nhận ra vì đoạn KẾ TIẾP là "a) …"
    a) Mục tiêu                 → muc_tieu
    b) Bối cảnh …               → boi_canh        (mỗi dòng "- " là một ý)
    c) <tiêu đề tự do>          → kien_thuc       {tieu_de, y}: "Kế sách chủ chốt",
                                                  "Kiến thức cần nhớ", "Vì sao…?"
    d) Diễn biến …              → dien_bien       (dòng "1. …", giữ đúng thứ tự)
    e) Kết quả và câu chốt      → ket_qua; dòng "Câu chốt để nhớ: “…”" → cau_chot
    f) Quiz                     → BỎ QUA
    Nhận mục theo CHỮ CÁI a)–f) chứ không theo tên mục: trận 1288 viết "b) Bối cảnh và
    cuộc xâm lược", "d) Diễn biến trận Bạch Đằng" — vẫn là mục b, mục d.

    Không nạp quiz: 30 câu của tài liệu Bạch Đằng đã nằm trong kho
    (data/seed_data.json); nạp nữa là trùng câu. Phần "Đáp án quiz" cuối tệp cũng bỏ qua.

    Tên trận ghép với slug sự kiện bằng bảng TRAN bên dưới. Gặp tên chưa có trong bảng
    thì DỪNG và báo — đoán theo chữ gần giống là gắn nhầm bài học vào trận khác.

DUYỆT
    Mặc định ghi `da_duyet: true` (nhóm đã soạn và kiểm). Bản nháp — nhất là bản do AI
    soạn — phải chạy với --chua-duyet: API /lo-trinh không trả lộ trình chưa duyệt.
    Tài liệu có chữ "BẢN NHÁP" ở đầu mà quên --chua-duyet thì script từ chối, để bản
    chưa ai kiểm không lọt lên app vì sót một cờ. Duyệt xong: xoá dòng BẢN NHÁP rồi
    chạy lại không có cờ, hoặc đổi thẳng `da_duyet` sang true trong lo_trinh.json.

DÙNG (từ thư mục backend/)
    python -m tools.nhap_lo_trinh "…/Lộ-trình-học-giai-đoạn-Bạch-Đằng.docx"
    python -m tools.nhap_lo_trinh --chua-duyet "…/Lộ-trình-học-…(BẢN NHÁP chờ duyệt).docx"
    → cập nhật data/lo_trinh.json: lộ trình cùng `ma` bị thay, lộ trình khác giữ nguyên.

Đọc .docx bằng zipfile + XML có sẵn của Python (không cần python-docx), để chạy được
cả trên VPS lẫn máy CI.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

RA = Path(__file__).resolve().parents[1] / "data" / "lo_trinh.json"
SEED = Path(__file__).resolve().parents[1] / "data" / "seed_data.json"

GHI_CHU = (
    "Bài học theo lộ trình (API GET /lo-trinh, màn chi tiết sự kiện). Tạo bằng "
    "tools/nhap_lo_trinh.py từ tài liệu .docx của nhóm — sửa ở tài liệu rồi chạy lại, "
    "đừng sửa tay ở đây. API chỉ trả lộ trình có da_duyet = true; bản nháp nhóm duyệt "
    "xong thì đổi da_duyet sang true."
)

# Tên trận (đúng như dòng tiêu đề trong tài liệu, bỏ số thứ tự) → (slug, tên ngắn).
# Slug phải có trong data/seed_data.json. Tên ngắn dùng cho dòng
# "Theo lộ trình: Bạch Đằng 938 → Chống Tống 981 → …" ở app.
TRAN: dict[str, tuple[str, str]] = {
    "Trận Bạch Đằng năm 938": ("bach-dang-938", "Bạch Đằng 938"),
    "Cuộc kháng chiến chống Tống năm 981": ("khang-chien-tong-981", "Chống Tống 981"),
    "Trận Bạch Đằng năm 1288": ("bach-dang-1288", "Bạch Đằng 1288"),
    "Khởi nghĩa Lam Sơn (1418–1427)": ("lam-son-1428", "Lam Sơn 1428"),
    "Quang Trung đại phá quân Thanh (1789)": ("quang-trung-1789", "Quang Trung 1789"),
}

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"

_TIEU_DE_LO_TRINH = re.compile(r"^Lộ trình học\s*:\s*(.+)$")
_SO = re.compile(r"^(\d+)[.)]\s+(.+)$")
_MUC = re.compile(r"^([a-f])\)\s*(.*)$")
_CAU_CHOT = re.compile(r"^Câu chốt để nhớ\s*:\s*(.+)$")
_NGOAC = "“”\"'‘’«»"


class LoiTaiLieu(ValueError):
    """Tài liệu không đúng định dạng — báo rõ chỗ sai thay vì ghi ra JSON hỏng."""


def _gon(s: str) -> str:
    """Chỉ cắt khoảng trắng (kể cả khoảng trắng không ngắt \\xa0 Word hay chèn)."""
    return " ".join(unicodedata.normalize("NFC", s).split())


def _khoa(s: str) -> str:
    """Khoá so tên trận: không phân biệt hoa thường, kiểu gạch nối, khoảng trắng.

    Chỉ nới đến thế — "Trận Bạch Đằng 938" (thiếu chữ "năm") vẫn là KHÔNG khớp.
    """
    s = re.sub(r"[–—‐-]", "-", _gon(s).lower())
    return re.sub(r"\s*-\s*", "-", s)


_BANG = {_khoa(k): v for k, v in TRAN.items()}


def doan_van(duong: Path) -> list[str]:
    """Chữ của từng đoạn <w:p> trong word/document.xml, đã cắt khoảng trắng."""
    with zipfile.ZipFile(duong) as z:
        goc = ET.fromstring(z.read("word/document.xml"))
    ra = []
    for p in goc.iter(f"{W}p"):
        manh = []
        for el in p.iter():
            if el.tag == f"{W}t":
                manh.append(el.text or "")
            elif el.tag in (f"{W}tab", f"{W}br", f"{W}cr"):
                manh.append(" ")
        ra.append(_gon("".join(manh)))
    return ra


def _bo_gach(s: str) -> str:
    return s[2:].strip() if s.startswith("- ") else s


def _bo_ngoac(s: str) -> str:
    return s.strip().strip(_NGOAC).strip()


def phan_tich(cac_doan: list[str]) -> tuple[str, list[dict]]:
    """(tên lộ trình, danh sách sự kiện theo thứ tự trong tài liệu)."""
    doan = [d for d in cac_doan if d and d != "---"]
    ten = next((m.group(1).strip() for d in doan if (m := _TIEU_DE_LO_TRINH.match(d))), None)
    if not ten:
        raise LoiTaiLieu('Không thấy dòng tiêu đề "Lộ trình học: …".')

    su_kien: list[dict] = []
    hien: dict | None = None
    muc = ""
    for i, d in enumerate(doan):
        m_so = _SO.match(d)
        ke = doan[i + 1] if i + 1 < len(doan) else ""
        # Tiêu đề trận cũng đánh số "1. …" như dòng diễn biến và câu quiz; chỉ tiêu đề
        # mới có "a) Mục tiêu" ngay sau.
        if m_so and _MUC.match(ke) and _MUC.match(ke).group(1) == "a":
            ten_tran = m_so.group(2).strip()
            ghep = _BANG.get(_khoa(ten_tran))
            if not ghep:
                raise LoiTaiLieu(
                    f'Trận "{ten_tran}" chưa có trong bảng TRAN của tools/nhap_lo_trinh.py. '
                    "Thêm đúng tên trận và slug sự kiện vào bảng rồi chạy lại.")
            hien = {"slug": ghep[0], "ten": ten_tran, "ten_ngan": ghep[1],
                    "muc_tieu": "", "boi_canh": [],
                    "kien_thuc": {"tieu_de": "", "y": []},
                    "dien_bien": [], "ket_qua": [], "cau_chot": ""}
            su_kien.append(hien)
            muc = ""
            continue
        if hien is None:
            continue   # tiêu đề lộ trình, dòng BẢN NHÁP, lời dẫn trước trận đầu

        m_muc = _MUC.match(d)
        if m_muc:
            muc = m_muc.group(1)
            if muc == "c":
                hien["kien_thuc"]["tieu_de"] = m_muc.group(2).strip()
            continue

        if muc == "a":
            hien["muc_tieu"] = _gon(f'{hien["muc_tieu"]} {_bo_gach(d)}')
        elif muc == "b":
            hien["boi_canh"].append(_bo_gach(d))
        elif muc == "c":
            hien["kien_thuc"]["y"].append(_bo_gach(d))
        elif muc == "d":
            hien["dien_bien"].append(m_so.group(2).strip() if m_so else _bo_gach(d))
        elif muc == "e":
            y = _bo_gach(d)
            m_chot = _CAU_CHOT.match(y)
            if m_chot:
                hien["cau_chot"] = _bo_ngoac(m_chot.group(1))
            else:
                hien["ket_qua"].append(y)
        # muc "f" (quiz), "Đáp án quiz", ghi chú cuối tệp: bỏ qua.

    if not su_kien:
        raise LoiTaiLieu('Không thấy trận nào (dòng "1. <tên trận>" rồi "a) Mục tiêu").')
    thay = set()
    for sk in su_kien:
        if sk["slug"] in thay:
            raise LoiTaiLieu(f'Trận "{sk["ten"]}" xuất hiện hai lần.')
        thay.add(sk["slug"])
        thieu = [ten_muc for ten_muc, co in (
            ("a) Mục tiêu", sk["muc_tieu"]), ("b) Bối cảnh", sk["boi_canh"]),
            ("c) tiêu đề", sk["kien_thuc"]["tieu_de"]), ("c) các ý", sk["kien_thuc"]["y"]),
            ("d) Diễn biến", sk["dien_bien"]), ("e) Kết quả", sk["ket_qua"]),
            ("e) Câu chốt để nhớ", sk["cau_chot"]),
        ) if not co]
        if thieu:
            raise LoiTaiLieu(f'Trận "{sk["ten"]}" thiếu: {", ".join(thieu)}.')
    return ten, su_kien


def la_ban_nhap(cac_doan: list[str]) -> bool:
    """Dòng chữ đầu tiên của tài liệu có ghi BẢN NHÁP."""
    dau = next((d for d in cac_doan if d), "")
    return "BẢN NHÁP" in dau.upper()


def doc_kho(tep: Path) -> list[dict]:
    if not tep.exists():
        return []
    tho = json.loads(tep.read_text(encoding="utf-8"))
    return list(tho.get("lo_trinh", []))


def gop(kho: list[dict], moi: dict) -> list[dict]:
    """Thay lộ trình cùng `ma` (giữ vị trí), không thì thêm vào cuối.

    Một trận chỉ được thuộc MỘT lộ trình: app hiện "bài 2/3" theo lộ trình chứa trận
    đó — hai lộ trình cùng chứa thì không biết hiện bài mấy.
    """
    slug_moi = {sk["slug"] for sk in moi["su_kien"]}
    for lt in kho:
        if lt["ma"] == moi["ma"]:
            continue
        trung = slug_moi & {sk["slug"] for sk in lt["su_kien"]}
        if trung:
            raise LoiTaiLieu(
                f'Trận {", ".join(sorted(trung))} đã thuộc lộ trình "{lt["ma"]}". '
                "Mỗi trận chỉ nằm trong một lộ trình.")
    ra = [moi if lt["ma"] == moi["ma"] else lt for lt in kho]
    if not any(lt["ma"] == moi["ma"] for lt in kho):
        ra.append(moi)
    return ra


def kiem_slug_trong_seed(su_kien: list[dict], seed: Path = SEED) -> None:
    co = {e["slug"] for e in json.loads(seed.read_text(encoding="utf-8"))["events"]}
    la = [sk["slug"] for sk in su_kien if sk["slug"] not in co]
    if la:
        raise LoiTaiLieu(f"Slug không có trong seed_data.json: {', '.join(la)} — sửa bảng TRAN.")


def nhap(duong: Path, *, chua_duyet: bool = False, ma: str | None = None,
         ra: Path = RA) -> dict:
    cac_doan = doan_van(duong)
    if la_ban_nhap(cac_doan) and not chua_duyet:
        raise LoiTaiLieu(
            "Tài liệu ghi BẢN NHÁP ở dòng đầu. Chạy với --chua-duyet, hoặc nhóm duyệt "
            "xong thì xoá dòng đó rồi chạy lại.")
    ten, su_kien = phan_tich(cac_doan)
    kiem_slug_trong_seed(su_kien)
    lo_trinh = {
        # Mã đặt theo trận đầu và trận cuối: chạy lại cùng tài liệu ra đúng mã cũ,
        # nên cập nhật được chứ không đẻ thêm bản trùng.
        "ma": ma or f'{su_kien[0]["slug"]}__{su_kien[-1]["slug"]}',
        "ten": ten,
        "da_duyet": not chua_duyet,
        "nguon": duong.name,
        "su_kien": su_kien,
    }
    kho = gop(doc_kho(ra), lo_trinh)
    ra.write_text(json.dumps({"_ghi_chu": GHI_CHU, "lo_trinh": kho},
                             ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return lo_trinh


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Nhập tài liệu lộ trình học (.docx) vào data/lo_trinh.json.")
    ap.add_argument("docx", type=Path)
    ap.add_argument("--chua-duyet", action="store_true",
                    help="ghi da_duyet: false (bản nháp — API chưa trả)")
    ap.add_argument("--ma", help="mã lộ trình; mặc định <slug trận đầu>__<slug trận cuối>")
    a = ap.parse_args(argv)
    try:
        lt = nhap(a.docx, chua_duyet=a.chua_duyet, ma=a.ma)
    except LoiTaiLieu as e:
        print(f"LỖI: {e}", file=sys.stderr)
        return 1
    print(f'  {lt["ma"]}: "{lt["ten"]}" — {"ĐÃ DUYỆT" if lt["da_duyet"] else "CHƯA DUYỆT"}')
    for sk in lt["su_kien"]:
        print(f'    {sk["slug"]}: {len(sk["boi_canh"])} ý bối cảnh, '
              f'{len(sk["kien_thuc"]["y"])} ý "{sk["kien_thuc"]["tieu_de"]}", '
              f'{len(sk["dien_bien"])} bước diễn biến, {len(sk["ket_qua"])} ý kết quả')
    print(f"  ghi {RA}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
