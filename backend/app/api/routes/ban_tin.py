"""Bản tin tuần cho phụ huynh: tạo link (cần đăng nhập) và trang xem (công khai).

Số liệu tính ở services/ban_tin.py; ở đây chỉ ghép HTML.

TRANG XEM LÀ HTML TĨNH, KHÔNG PHẢI MÀN TRONG APP
    Bố mẹ bấm link trong Zalo → mở trong trình duyệt của Zalo, máy thường là điện
    thoại cũ, mạng 4G. Bản web Flutter nặng vài MB và phải tải xong mới hiện chữ;
    một trang HTML vài KB, CSS viết liền, không script thì mở là đọc được — và in
    ra giấy được nếu bố mẹ muốn.

MỌI CHỮ LẤY TỪ CSDL ĐỀU QUA html.escape
    Tên do học sinh tự đặt, câu hỏi có thể do giáo viên soạn hoặc dán từ AI. Trang
    này mở bằng một link ai cũng có — một thẻ <script> lọt qua là chạy trên máy phụ
    huynh dưới tên miền của mình.
"""
from __future__ import annotations

from datetime import datetime, timezone
from html import escape

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.db.session import get_db
from app.models.user import User
from app.services.ban_tin import (
    DIEM_MOI_CAU,
    HAN_LINK,
    BanTin,
    GoiY,
    MaHetHan,
    MaKhongHopLe,
    doc_ma,
    tao_ma,
    tinh_ban_tin,
)
from app.services.gioi_han import bo_gioi_han_ban_tin, dia_chi_that
from app.services.ngay_hoc import GIO_VN
from app.services.thanh_toan import GOI

router = APIRouter(tags=["ban-tin"])

# Link mang quyền xem — đừng để trình duyệt/proxy lưu lại hay gửi theo Referer.
_DAU_TRANG = {
    "Cache-Control": "no-store, private",
    "X-Robots-Tag": "noindex, nofollow",
    "Referrer-Policy": "no-referrer",
}


@router.post("/me/ban-tin/link")
def tao_link(request: Request, current: User = Depends(get_current_user)):
    """Link bản tin tuần gửi phụ huynh. Không lưu gì: link tự mang chữ ký và hạn."""
    het_han = datetime.now(timezone.utc).replace(microsecond=0) + HAN_LINK
    ma = tao_ma(current.id, het_han)
    duong_dan = request.url_for("xem_ban_tin", ma=ma).path
    # Máy chủ thật chạy uvicorn --proxy-headers nên request.base_url đã là https://
    # của tên miền người gọi. PUBLIC_BASE_URL (nếu đặt) vẫn thắng — cùng quy ước với
    # link giọng đọc trong routes/chat.py.
    goc = settings.PUBLIC_BASE_URL.rstrip("/") or str(request.base_url).rstrip("/")
    return {"url": f"{goc}{duong_dan}", "het_han": het_han.isoformat()}


@router.get("/ban-tin/{ma}", response_class=HTMLResponse, name="xem_ban_tin")
def xem_ban_tin(ma: str, request: Request, db: Session = Depends(get_db)):
    """Trang bản tin cho phụ huynh — KHÔNG cần đăng nhập (phụ huynh không có tài khoản)."""
    ip = dia_chi_that(request)
    try:
        bo_gioi_han_ban_tin.xin_luot(f"ip:{ip}", ip, datetime.now(GIO_VN).strftime("%Y-%m-%d"))
    except HTTPException as e:
        return _trang_bao(
            "Mở hơi nhanh",
            "Trang vừa được mở nhiều lần liền. Bố mẹ chờ khoảng một phút rồi tải lại nhé.",
            429, them_dau=e.headers)

    bay_gio = datetime.now(timezone.utc)
    try:
        user_id, het_han = doc_ma(ma, bay_gio)
    except MaHetHan:
        return _trang_bao(
            "Link bản tin đã hết hạn",
            "Mỗi link bản tin xem được 14 ngày. Bố mẹ nhờ con mở app HistoriAI, vào "
            "Tài khoản → Gửi bản tin tuần cho phụ huynh để lấy link mới.", 410)
    except MaKhongHopLe:
        return _trang_khong_mo_duoc()
    user = db.get(User, user_id)
    if user is None:                       # tài khoản đã xoá
        return _trang_khong_mo_duoc()
    return HTMLResponse(ve_ban_tin(tinh_ban_tin(db, user, bay_gio), het_han), headers=_DAU_TRANG)


def _trang_khong_mo_duoc() -> HTMLResponse:
    return _trang_bao(
        "Không mở được bản tin",
        "Link này không đúng — có thể bị chép thiếu vài ký tự. Bố mẹ nhờ con mở app "
        "HistoriAI, vào Tài khoản → Gửi bản tin tuần cho phụ huynh rồi gửi lại link.", 404)


# ---------------------------------------------------------------- ghép HTML

def _e(s) -> str:
    return escape("" if s is None else str(s), quote=True)


def _ngay(dt: datetime, nam: bool = True) -> str:
    d = dt.astimezone(GIO_VN)
    return f"{d.day:02d}/{d.month:02d}/{d.year}" if nam else f"{d.day:02d}/{d.month:02d}"


def _khoang_ngay(bt: BanTin) -> str:
    cung_nam = bt.tu_ngay.year == bt.den_ngay.year
    return f"Từ {_ngay(bt.tu_ngay, nam=not cung_nam)} đến {_ngay(bt.den_ngay)}"


def _dong_lop(lop: list[tuple[int, str | None]]) -> str:
    if not lop:
        return ""
    co_chu_de = [(l, c) for l, c in lop if c]
    if not co_chu_de:   # chỉ biết lớp, chưa có chủ đề chương trình
        return f'<p class="lop">Học trên lớp: {_e(", ".join(f"Lớp {l}" for l, _ in lop))}</p>'
    return "".join(f'<p class="lop">Học trên lớp: Lớp {l} – {_e(c)}</p>' for l, c in co_chu_de)


def _o_so(so: str, nhan: str, phu: str = "") -> str:
    phu_html = f"<small>{_e(phu)}</small>" if phu else ""
    return f'<div class="o"><b>{_e(so)}</b><span>{_e(nhan)}</span>{phu_html}</div>'


def _goi_y_html(g: GoiY | None, tuan_trong: bool) -> str:
    if g is None:
        return ""
    ten = f"<strong>{_e(g.ten)}</strong>"
    if g.la_on_lai:
        cau = (f"Con đã làm quiz đủ các trận hiện có. Tuần sau, cùng con làm lại {ten} "
               "để nâng mức thông thạo.")
    elif tuan_trong:
        cau = f"Gợi ý để bắt đầu: {ten}."
    else:
        cau = f"{ten} — trận tiếp theo trên dòng thời gian mà con chưa làm."
    tieu_de = "Gợi ý cho con" if tuan_trong else "Tuần sau nên học"
    return (f'<section class="the tiep"><h2>{tieu_de}</h2><p>{cau}</p>{_dong_lop(g.lop)}'
            '<p class="phu">Trong app: vào Đấu trường, chọn trận này để làm quiz.</p></section>')


def _khung_premium(bt: BanTin) -> str:
    """Thay cho "Cùng con ôn lại" và "Tuần sau nên học" khi tài khoản của con chưa Premium.

    Chỉ nói SỐ câu sai, không lộ câu nào. Cố ý không có nút hay link thanh toán: trang
    này là link công khai bố mẹ nhận qua Zalo, mà tiền chỉ nên đi qua màn Premium trong
    app (đúng tài khoản, đúng đơn). Bố mẹ đọc rồi nhắn con là đủ.
    """
    gia = f"{GOI['thang']['so_tien']:,}".replace(",", ".")
    if bt.so_cau_sai > 0:
        co_gi = f"{bt.so_cau_sai} câu con làm sai kèm đáp án và gợi ý bài tuần sau"
    else:
        co_gi = "gợi ý bài tuần sau"
    return (
        '<section class="the khoa"><h2>Có thêm trong bản đầy đủ</h2>'
        f"<p>Bản tin đầy đủ có thêm {co_gi} — dành cho tài khoản Premium ({gia}đ/tháng). "
        "Con mở app → Tài khoản → HistoriAI Premium để nâng cấp.</p>"
        '<p class="phu">Các phần còn lại của bản tin vẫn đủ như mọi tuần.</p></section>')


_CSS = """
:root{--nen:#FDF9F4;--nen2:#FBF3E6;--do:#BA2323;--do-dam:#7A2218;--vang:#D4AF37;
--chu:#2B1410;--chu-nhat:#7C5A4A;--vien:#EDE0CF}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%;text-size-adjust:100%}
body{margin:0;background:var(--nen);color:var(--chu);
font:16px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif}
.trang{max-width:640px;margin:0 auto;padding:0 16px 32px}
h1,h2,h3{font-family:"Times New Roman",Times,serif;line-height:1.25;margin:0}
.dau{background:linear-gradient(135deg,var(--do-dam),var(--do));color:var(--nen2);
margin:0 -16px 18px;padding:22px 20px 20px;border-bottom:3px solid var(--vang)}
.dau .nhan{margin:0 0 6px;font-size:12px;letter-spacing:.12em;font-weight:700;color:var(--vang)}
.dau h1{font-size:26px;color:#FFF}
.dau .ngay{margin:8px 0 0;font-size:14px;opacity:.92}
.the{background:#FFF;border:1px solid var(--vien);border-radius:14px;padding:16px;margin:0 0 14px}
h2{font-size:21px;color:var(--do-dam);margin-bottom:10px}
h3{font-size:18px;color:var(--chu)}
.phu{color:var(--chu-nhat);font-size:14px;margin:6px 0 0}
.luoi{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
.o{background:var(--nen2);border-radius:12px;padding:10px 12px}
.o b{display:block;font-family:"Times New Roman",Times,serif;font-size:26px;line-height:1.1;color:var(--do)}
.o span{display:block;font-size:13.5px;color:var(--chu)}
.o small{display:block;font-size:12.5px;color:var(--chu-nhat)}
.tran{border-top:1px solid var(--vien);padding:12px 0 2px}
.tran:first-of-type{border-top:0;padding-top:0}
.lop{margin:4px 0 0;font-size:14.5px;color:var(--chu-nhat)}
.so-tran{display:flex;flex-wrap:wrap;justify-content:space-between;gap:4px 12px;margin:8px 0 6px;font-size:14.5px}
.thanh{height:8px;border-radius:8px;background:var(--nen2);overflow:hidden;
-webkit-print-color-adjust:exact;print-color-adjust:exact}
.thanh i{display:block;height:100%;background:var(--vang)}
ol.on{margin:0;padding:0;list-style:none;counter-reset:c}
ol.on li{counter-increment:c;border-top:1px solid var(--vien);padding:12px 0 2px}
ol.on li:first-child{border-top:0;padding-top:4px}
ol.on .hoi{margin:0;font-weight:600}
ol.on .hoi::before{content:"Câu " counter(c) ". ";color:var(--do)}
.dap{margin:6px 0 0;padding:6px 10px;border-left:3px solid var(--vang);background:var(--nen2);border-radius:0 8px 8px 0}
.giai{margin:6px 0 0;font-size:14.5px;color:var(--chu-nhat)}
.trong p{margin:0 0 8px}
.tiep strong{color:var(--do-dam)}
.khoa{background:var(--nen2);border-style:dashed}
footer{margin-top:22px;padding-top:14px;border-top:1px solid var(--vien);font-size:13.5px;color:var(--chu-nhat);text-align:center}
footer p{margin:0 0 4px}
a{color:var(--do)}
@media (min-width:480px){.luoi{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media print{
body{background:#FFF;font-size:12pt}
.trang{max-width:none;padding:0}
.dau{background:none;color:var(--chu);margin:0 0 12px;padding:0 0 10px;border-bottom:2px solid var(--vang)}
.dau h1{color:var(--do-dam)}
.dau .nhan{color:var(--do)}
.luoi{grid-template-columns:repeat(3,minmax(0,1fr))}
.the,.tran,ol.on li{break-inside:avoid}
.the{border-color:#CCC}
}
"""


def _khung(tieu_de: str, than: str) -> str:
    return (
        '<!doctype html><html lang="vi"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<meta name="robots" content="noindex, nofollow">'
        '<meta name="referrer" content="no-referrer">'
        f"<title>{_e(tieu_de)}</title><style>{_CSS}</style></head>"
        f'<body><main class="trang">{than}</main></body></html>'
    )


def _chan_trang(het_han: datetime | None) -> str:
    han = f"<p>Link có hạn tới {_ngay(het_han)}.</p>" if het_han else ""
    return ("<footer><p>Bản tin do HistoriAI tạo từ bài con đã làm trong app.</p>"
            '<p><a href="https://historiai.org">https://historiai.org</a></p>'
            f"{han}</footer>")


def _trang_bao(tieu_de: str, loi: str, ma: int, them_dau: dict | None = None) -> HTMLResponse:
    than = (f'<header class="dau"><p class="nhan">HISTORIAI · BẢN TIN PHỤ HUYNH</p>'
            f"<h1>{_e(tieu_de)}</h1></header>"
            f'<section class="the"><p>{_e(loi)}</p></section>{_chan_trang(None)}')
    return HTMLResponse(_khung(tieu_de, than), status_code=ma,
                        headers={**_DAU_TRANG, **(them_dau or {})})


def ve_ban_tin(bt: BanTin, het_han: datetime) -> str:
    tieu_de = f"Bản tin học Lịch sử tuần này của {bt.ten}"
    phan = [
        '<header class="dau"><p class="nhan">HISTORIAI · BẢN TIN PHỤ HUYNH</p>'
        f'<h1>{_e(tieu_de)}</h1><p class="ngay">{_e(_khoang_ngay(bt))}</p></header>'
    ]

    if bt.trong:
        chuoi = (f"<p>Chuỗi ngày học hiện tại: {bt.streak} ngày.</p>" if bt.streak else "")
        phan.append(
            '<section class="the trong"><h2>Tuần này</h2>'
            "<p>Con chưa làm bài nào trong app trong 7 ngày qua. Không sao cả — bố mẹ có thể "
            "nhắc con thử một trận, làm xong bản tin sẽ có số liệu ngay.</p>"
            f"{chuoi}</section>")
        phan.append(_goi_y_html(bt.goi_y, tuan_trong=True) if bt.day_du else _khung_premium(bt))
    else:
        o = [
            _o_so(str(bt.so_tran), "trận đã làm"),
            _o_so(str(bt.so_cau), "câu đã trả lời"),
            _o_so(str(bt.so_dung), "câu đúng"),
            _o_so(f"{bt.ti_le}%", "tỉ lệ đúng"),
            _o_so(f"{bt.streak} ngày", "chuỗi ngày học", "số ngày liền nhau con có học"),
            _o_so(str(bt.cau_moi_dung), "câu mới đúng lần đầu",
                  f"+{bt.diem_moi} điểm (mỗi câu {DIEM_MOI_CAU} điểm)" if bt.cau_moi_dung else ""),
        ]
        phan.append(f'<section class="the"><h2>Tổng kết tuần</h2><div class="luoi">{"".join(o)}</div>'
                    "</section>")

        tran = []
        for t in bt.cac_tran:
            tt = max(0, min(100, t.thong_thao))
            tran.append(
                f'<article class="tran"><h3>{_e(t.ten)}</h3>{_dong_lop(t.lop)}'
                f'<div class="so-tran"><span>Tuần này: đúng {t.dung}/{t.tong} câu</span>'
                f"<span>Thông thạo hiện tại: {tt}%</span></div>"
                f'<div class="thanh" role="img" aria-label="Thông thạo {tt}%">'
                f'<i style="width:{tt}%"></i></div></article>')
        phan.append(f'<section class="the"><h2>Con đã học gì</h2>{"".join(tran)}</section>')

        if bt.day_du and bt.on_lai:
            cau = []
            for c in bt.on_lai:
                dap = f"{c.dap_an}. {c.noi_dung_dap_an}" if c.noi_dung_dap_an else c.dap_an
                giai = f'<p class="giai">{_e(c.loi_giai)}</p>' if c.loi_giai else ""
                tran_cua = f'<p class="phu">{_e(c.ten_tran)}</p>' if c.ten_tran else ""
                cau.append(f'<li><p class="hoi">{_e(c.cau_hoi)}</p>'
                           f'<p class="dap">Đáp án đúng: <strong>{_e(dap)}</strong></p>'
                           f"{giai}{tran_cua}</li>")
            phan.append(
                '<section class="the"><h2>Cùng con ôn lại</h2>'
                '<p class="phu" style="margin:0 0 8px">Những câu con làm sai trong tuần và '
                "chưa làm đúng lại. Bố mẹ có thể hỏi lại con các câu này.</p>"
                f'<ol class="on">{"".join(cau)}</ol></section>')

        phan.append(_goi_y_html(bt.goi_y, tuan_trong=False) if bt.day_du else _khung_premium(bt))

    phan.append(_chan_trang(het_han))
    return _khung(tieu_de, "".join(phan))
