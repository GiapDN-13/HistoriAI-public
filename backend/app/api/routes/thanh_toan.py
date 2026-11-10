"""Thanh toán Premium qua chuyển khoản VietQR + webhook SePay.

Chi tiết cách cấu hình ở docs/THANH_TOAN_SEPAY.md; logic ở services/thanh_toan.py.
"""
import hmac

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_current_user_optional
from app.core.config import settings
from app.db.session import get_db
from app.models.thanh_toan import DonThanhToan, GiaoDichNganHang
from app.models.user import User
from app.services import thanh_toan as tt
from app.services import vietqr
from app.services.ngay_hoc import iso_utc

router = APIRouter(prefix="/thanh-toan", tags=["thanh-toan"])


def quan_tri(current: User = Depends(get_current_user)) -> User:
    if current.role != "admin":
        raise HTTPException(403, "Chức năng này chỉ dành cho quản trị.")
    return current


class TaoDon(BaseModel):
    goi: str = Field(min_length=1, max_length=16)


class XacNhanTay(BaseModel):
    ma_don: str = Field(min_length=1, max_length=16)


@router.get("/goi")
def danh_sach_goi(user: User | None = Depends(get_current_user_optional)):
    return {"bat": tt.da_bat(), "goi": tt.danh_sach_goi(user)}


@router.post("/don")
def tao_don(payload: TaoDon, db: Session = Depends(get_db), current: User = Depends(get_current_user)):
    if not tt.da_bat():
        raise HTTPException(503, "Thanh toán chưa được bật. Bạn vui lòng quay lại sau hoặc liên hệ nhóm HistoriAI nhé.")
    goi = tt.tim_goi(payload.goi)
    if goi is None:
        raise HTTPException(400, "Gói không tồn tại.")
    if goi["ma"] == tt.GOI_THU["ma"] and not tt.la_quan_tri(current):
        raise HTTPException(403, "Gói này chỉ dành cho quản trị.")

    don = tt.tao_don(db, current, goi)
    return {
        "ma_don": don.ma_don,
        "so_tien": don.so_tien,
        "noi_dung": don.ma_don,   # nội dung chuyển khoản chính là mã đơn — SePay tìm mã này
        "ngan_hang": {"ten": settings.THANH_TOAN_TEN_NH, "so_tk": settings.THANH_TOAN_SO_TK,
                      "chu_tk": settings.THANH_TOAN_CHU_TK},
        "qr_chuoi": vietqr.dung_chuoi(settings.THANH_TOAN_BIN, settings.THANH_TOAN_SO_TK,
                                      don.so_tien, don.ma_don),
        "het_han": iso_utc(don.het_han),
        "trang_thai": tt.trang_thai_don(don),
    }


@router.get("/don/{ma_don}")
def xem_don(ma_don: str, db: Session = Depends(get_db), current: User = Depends(get_current_user)):
    don = db.query(DonThanhToan).filter(DonThanhToan.ma_don == ma_don.strip().upper()).first()
    # Đơn của người khác trả 404 chứ không 403: không cho dò xem mã đơn nào đang tồn tại.
    if don is None or (don.user_id != current.id and current.role != "admin"):
        raise HTTPException(404, "Không tìm thấy đơn.")
    trang_thai = tt.trang_thai_don(don)
    chu = db.get(User, don.user_id) if don.user_id else None
    return {
        "ma_don": don.ma_don,
        "trang_thai": trang_thai,
        "so_tien": don.so_tien,
        "premium_den": iso_utc(chu.premium_den) if chu and trang_thai == "da_tra" else None,
    }


@router.post("/sepay")
async def webhook_sepay(request: Request, db: Session = Depends(get_db)):
    """SePay gọi vào đây mỗi khi có biến động số dư. Không đăng nhập — xác thực bằng khoá.

    Sau khi xác thực xong LUÔN trả 200 {"success": true}, kể cả giao dịch không khớp
    đơn nào: SePay gửi lại tới khi nhận được 200, mà giao dịch lạ có gửi lại cả trăm
    lần cũng không tự khớp. Giao dịch lạ được lưu `chua_khop` để quản trị xử lý tay.
    """
    khoa = settings.SEPAY_WEBHOOK_KEY
    tieu_de = request.headers.get("authorization", "")
    # Chưa đặt khoá thì từ chối hết — khoá rỗng mà so khớp "Apikey " là mở toang cửa.
    if not khoa or not hmac.compare_digest(tieu_de.strip().encode(), f"Apikey {khoa}".encode()):
        raise HTTPException(401, "Sai khoá xác thực.")

    try:
        du_lieu = await request.json()
    except ValueError:
        raise HTTPException(400, "Nội dung không phải JSON.")
    # Không có id thì không thể chống nhận trùng — thà từ chối rõ ràng còn hơn nhận mù.
    if not isinstance(du_lieu, dict) or isinstance(du_lieu.get("id"), bool) \
            or not isinstance(du_lieu.get("id"), int):
        raise HTTPException(400, "Thiếu mã giao dịch (id).")

    tt.xu_ly_giao_dich(db, du_lieu)
    return {"success": True}


@router.post("/xac-nhan-tay")
def xac_nhan_tay(payload: XacNhanTay, db: Session = Depends(get_db), _: User = Depends(quan_tri)):
    """Quản trị đánh dấu đã trả khi SePay chưa bật hoặc giao dịch không tự khớp."""
    don = tt.xac_nhan_tay(db, payload.ma_don)
    if don is None:
        raise HTTPException(404, "Không tìm thấy đơn.")
    chu = db.get(User, don.user_id) if don.user_id else None
    return {"ma_don": don.ma_don, "trang_thai": "da_tra",
            "premium_den": iso_utc(chu.premium_den) if chu else None}


@router.get("/giao-dich-chua-khop")
def giao_dich_chua_khop(db: Session = Depends(get_db), _: User = Depends(quan_tri)):
    ds = (db.query(GiaoDichNganHang).filter(GiaoDichNganHang.trang_thai == "chua_khop")
          .order_by(GiaoDichNganHang.id.desc()).limit(50).all())
    return [{"id": g.id, "sepay_id": g.sepay_id, "so_tien": g.so_tien, "noi_dung": g.noi_dung,
             "ngay_gd": g.ngay_gd, "ma_don": g.ma_don, "nhan_luc": iso_utc(g.nhan_luc)}
            for g in ds]
