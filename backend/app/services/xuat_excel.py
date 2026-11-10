"""Xuất bảng điểm phòng thi ra tệp Excel (.xlsx) cho giáo viên.

CSV mở được bằng Excel nhưng trơ trọi: cột hẹp, không tên đề, không định dạng — giáo
viên phải tự chỉnh trước khi nộp hay in. Tệp này mở ra là dùng được ngay:

    Trang "Bảng điểm"  — tiêu đề (đề, mã phòng, giáo viên, ngày) + mỗi em một dòng
    Trang "Từng câu"   — tỉ lệ đúng, phân bổ A/B/C/D, phương án bị nhầm nhiều nhất
    Trang "Chi tiết"   — lưới học sinh × câu (✓ / ✗ / trống) để thấy em nào sai câu nào
"""
from __future__ import annotations

import io
from datetime import datetime, timedelta, timezone

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

VN = timezone(timedelta(hours=7))
DO = "BA2323"
DO_DAM = "7A2218"
VANG = "FDD141"
KEM = "FBF3E6"
XANH = "E6F4EA"
HONG = "FCE8E6"

_vien = Border(*(Side(style="thin", color="E3D3BF"),) * 4)
_dau = Font(bold=True, color="FFFFFF")
_nen_dau = PatternFill("solid", fgColor=DO)
_giua = Alignment(horizontal="center", vertical="center", wrap_text=True)
_trai = Alignment(horizontal="left", vertical="center", wrap_text=True)


def _gio_vn(iso: str | None) -> str:
    if not iso:
        return ""
    try:
        return datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone(VN).strftime("%H:%M %d/%m/%Y")
    except ValueError:
        return ""


def _phut(giay: int | None) -> str:
    if giay is None:
        return ""
    return f"{giay // 60} phút {giay % 60:02d} giây" if giay >= 60 else f"{giay} giây"


def _tieu_de(ws, dong_dau: list[str], so_cot: int) -> int:
    """Vài dòng tiêu đề trộn ô ở đầu trang. Trả số dòng đã dùng."""
    for i, chu in enumerate(dong_dau, 1):
        ws.merge_cells(start_row=i, start_column=1, end_row=i, end_column=so_cot)
        o = ws.cell(i, 1, chu)
        o.font = Font(bold=True, size=15, color=DO_DAM) if i == 1 else Font(italic=True, color="7C5A4A")
        o.alignment = Alignment(horizontal="left", vertical="center")
    return len(dong_dau) + 1


def _hang_dau(ws, dong: int, cot: list[str], rong: list[int]) -> None:
    for j, (ten, w) in enumerate(zip(cot, rong), 1):
        o = ws.cell(dong, j, ten)
        o.font, o.fill, o.alignment, o.border = _dau, _nen_dau, _giua, _vien
        ws.column_dimensions[get_column_letter(j)].width = w
    ws.row_dimensions[dong].height = 30
    ws.freeze_panes = ws.cell(dong + 1, 1)


def tao(bang: dict, *, truc_tiep: bool, xep_hang: dict[str, dict] | None, giao_vien: str | None,
        chi_tiet: list[dict]) -> bytes:
    """bang = kết quả routes/lop_hoc._bang(); xep_hang = {ten: {"diem","hang"}} khi thi
    trực tiếp; chi_tiet = [{"ten","lop","tra_loi": {qid: {"chon","dung"}}}]."""
    p = bang["phong"]
    hs = bang["hoc_sinh"]
    if truc_tiep and xep_hang:
        hs = sorted(hs, key=lambda h: (xep_hang.get(h["ten"], {}).get("hang") or 10 ** 6, h["ten"].lower()))
    ngay = _gio_vn(p.get("tao_luc"))
    dau = [f"BẢNG ĐIỂM — {p['tieu_de']}",
           f"Mã phòng {p['ma']} · {'Thi trực tiếp' if truc_tiep else 'Bài tập'} · {p['so_cau']} câu"
           f"{' · Giáo viên: ' + giao_vien if giao_vien else ''} · Mở lúc {ngay}",
           f"Đã nộp {p.get('so_nop', 0)}/{p.get('so_bai', 0)} em · Xuất từ historiai.org"]

    wb = Workbook()

    # ---------------- Bảng điểm
    ws = wb.active
    ws.title = "Bảng điểm"
    cot = ["STT", "Họ và tên", "Lớp", "Số câu đúng", "Tổng số câu", "Điểm (thang 10)"]
    rong = [6, 30, 9, 12, 12, 14]
    if truc_tiep:
        cot += ["Điểm thi", "Hạng"]
        rong += [11, 8]
    cot += ["Thời gian làm", "Đã nộp", "Nộp lúc"]
    rong += [16, 10, 18]
    d0 = _tieu_de(ws, dau, len(cot))
    _hang_dau(ws, d0, cot, rong)
    for i, h in enumerate(hs, 1):
        diem10 = round(h["so_dung"] * 10 / h["tong"], 2) if h["tong"] else 0
        dong = [i, h["ten"], h["lop"] or "", h["so_dung"], h["tong"], diem10]
        if truc_tiep:
            x = (xep_hang or {}).get(h["ten"], {})
            dong += [x.get("diem"), x.get("hang")]
        dong += [_phut(h["giay_lam"]), "có" if h["da_nop"] else "chưa", _gio_vn(h["nop_luc"])]
        for j, v in enumerate(dong, 1):
            o = ws.cell(d0 + i, j, v)
            o.border = _vien
            o.alignment = _trai if j == 2 else _giua
            if i % 2 == 0:
                o.fill = PatternFill("solid", fgColor=KEM)
        o10 = ws.cell(d0 + i, 6)
        o10.number_format = "0.00"
        o10.font = Font(bold=True, color="1E7B34" if diem10 >= 5 else DO)
    if hs:
        n = d0 + len(hs)
        ws.cell(n + 2, 2, "Điểm trung bình cả phòng").font = Font(bold=True)
        tb = ws.cell(n + 2, 6, f"=ROUND(AVERAGE(F{d0 + 1}:F{n}),2)")
        tb.font, tb.alignment, tb.number_format = Font(bold=True, color=DO_DAM), _giua, "0.00"

    # ---------------- Từng câu
    ws2 = wb.create_sheet("Từng câu")
    cot2 = ["Câu", "Nội dung câu hỏi", "Đáp án đúng", "Số em trả lời", "Tỉ lệ đúng",
            "Chọn A", "Chọn B", "Chọn C", "Chọn D", "Nhầm nhiều nhất"]
    d2 = _tieu_de(ws2, [f"TỪNG CÂU — {p['tieu_de']}",
                        "Câu tỉ lệ đúng dưới 50% tô hồng: nên giảng lại trên lớp."], len(cot2))
    _hang_dau(ws2, d2, cot2, [6, 55, 11, 12, 11, 9, 9, 9, 9, 15])
    for i, c in enumerate(bang["tung_cau"], 1):
        pb = c["phan_bo"]
        tl = c["ti_le_dung"]
        dong = [i, c["question"], c["correct_option"], c["so_tra_loi"],
                f"{tl}%" if tl is not None else "—", pb["A"], pb["B"], pb["C"], pb["D"],
                c["nham_nhieu_nhat"] or ""]
        for j, v in enumerate(dong, 1):
            o = ws2.cell(d2 + i, j, v)
            o.border = _vien
            o.alignment = _trai if j == 2 else _giua
            if tl is not None and tl < 50:
                o.fill = PatternFill("solid", fgColor=HONG)
        ws2.cell(d2 + i, 3).font = Font(bold=True, color="1E7B34")

    # ---------------- Chi tiết
    ws3 = wb.create_sheet("Chi tiết")
    qids = [c["id"] for c in bang["tung_cau"]]
    cot3 = ["Họ và tên", "Lớp"] + [f"Câu {i}" for i in range(1, len(qids) + 1)] + ["Đúng"]
    d3 = _tieu_de(ws3, [f"CHI TIẾT TỪNG EM — {p['tieu_de']}",
                        "✓ đúng · ✗ sai (kèm phương án em chọn) · trống: chưa làm / hết giờ"], len(cot3))
    _hang_dau(ws3, d3, cot3, [28, 9] + [8] * len(qids) + [8])
    for i, e in enumerate(chi_tiet, 1):
        ws3.cell(d3 + i, 1, e["ten"]).border = _vien
        ws3.cell(d3 + i, 2, e["lop"] or "").border = _vien
        dung = 0
        for j, q in enumerate(qids, 3):
            v = (e["tra_loi"] or {}).get(str(q))
            chu, nen = "", None
            if v and v.get("chon"):
                if v.get("dung"):
                    chu, nen = "✓", XANH
                    dung += 1
                else:
                    chu, nen = f"✗ {v['chon']}", HONG
            o = ws3.cell(d3 + i, j, chu)
            o.alignment, o.border = _giua, _vien
            if nen:
                o.fill = PatternFill("solid", fgColor=nen)
        o = ws3.cell(d3 + i, len(qids) + 3, dung)
        o.alignment, o.border, o.font = _giua, _vien, Font(bold=True)

    for w in wb.worksheets:
        w.sheet_view.zoomScale = 110
        w.page_setup.orientation = "landscape"
        w.page_setup.fitToWidth = 1
        w.sheet_properties.pageSetUpPr.fitToPage = True
    ra = io.BytesIO()
    wb.save(ra)
    return ra.getvalue()
