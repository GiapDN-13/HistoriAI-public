"""Thanh toán Premium: gói, đơn, đối soát giao dịch SePay, kích hoạt.

Cách chạy (chi tiết ở docs/THANH_TOAN_SEPAY.md)
    1. App tạo đơn → nhận mã đơn + chuỗi VietQR; người dùng chuyển khoản với
       nội dung = mã đơn.
    2. SePay thấy tiền vào tài khoản → gọi webhook → `xu_ly_giao_dich` tìm mã đơn
       trong nội dung, đủ tiền thì kích hoạt Premium.
    3. App hỏi lại trạng thái đơn tới khi thấy `da_tra`.

Không có đường nào tự trừ tiền hay tự gia hạn: hết 30 ngày là hết, muốn nữa thì
mua lại. Vì thế không phải lưu thẻ hay quyền trừ tiền của phụ huynh.
"""
from __future__ import annotations

import re
import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.thanh_toan import DonThanhToan, GiaoDichNganHang
from app.models.user import User

# Bỏ 0/O/1/I: người ta đọc mã đơn trên màn hình rồi gõ vào ngân hàng, nhầm hai cặp
# này là tiền về mà không khớp đơn nào.
BANG_CHU = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
TIEN_TO = "HAI"
DO_DAI_HAU_TO = 5
MAU_MA_DON = re.compile(rf"{TIEN_TO}[A-Z0-9]{{{DO_DAI_HAU_TO}}}")

HAN_DON = timedelta(minutes=30)

# Một gói duy nhất cho người dùng. "thu" là gói 2.000đ để quản trị thử cả đường tiền
# thật (QR → ngân hàng → SePay → webhook) trước khi mở cho phụ huynh.
GOI = {
    "thang": {"ma": "thang", "ten": "Premium 1 tháng", "so_tien": 39000, "so_ngay": 30},
}
GOI_THU = {"ma": "thu", "ten": "Gói thử 2.000đ", "so_tien": 2000, "so_ngay": 1}


def bay_gio() -> datetime:
    return datetime.now(timezone.utc)


def co_mui_gio(dt: datetime | None) -> datetime | None:
    """SQLite trả datetime không múi giờ (đã là UTC) — so sánh với giờ có múi giờ là lỗi."""
    if dt is not None and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def da_bat() -> bool:
    return bool(settings.THANH_TOAN_BIN and settings.THANH_TOAN_SO_TK and settings.THANH_TOAN_CHU_TK)


def la_quan_tri(user: User | None) -> bool:
    return user is not None and user.role == "admin"


def la_premium(user: User | None, luc: datetime | None = None) -> bool:
    if user is None:
        return False
    den = co_mui_gio(user.premium_den)
    return den is not None and den > (luc or bay_gio())


def duoc_xem_day_du(user: User | None, luc: datetime | None = None) -> bool:
    """Có được mở phần dành cho Premium không (bản tin đầy đủ, ôn hết câu sai, bài lộ trình).

    Quản trị được xem đủ như Premium: tài khoản demo của nhóm phải trình diễn được mọi
    thứ trước hội đồng. Cố ý KHÔNG nhét vào `la_premium` — hàm đó còn quyết `/auth/me`
    báo "đang Premium" và màn Premium hiện "còn N ngày"; quản trị không có hạn nào cả.
    Mọi chỗ khoá nội dung đi qua đây, để luật "ai được xem đủ" chỉ nằm một nơi.
    """
    return la_quan_tri(user) or la_premium(user, luc)


def danh_sach_goi(user: User | None) -> list[dict]:
    ds = list(GOI.values())
    if la_quan_tri(user):
        ds.append(GOI_THU)
    return ds


def tim_goi(ma: str) -> dict | None:
    return GOI.get(ma) or (GOI_THU if ma == GOI_THU["ma"] else None)


def _sinh_ma_don(db: Session) -> str:
    # Không gian 32^5 ≈ 33 triệu mã; trùng gần như không xảy ra nhưng vẫn kiểm,
    # vì hai đơn cùng mã là cộng nhầm Premium cho người khác.
    for _ in range(20):
        ma = TIEN_TO + "".join(secrets.choice(BANG_CHU) for _ in range(DO_DAI_HAU_TO))
        if db.query(DonThanhToan.id).filter(DonThanhToan.ma_don == ma).first() is None:
            return ma
    raise RuntimeError("Không sinh được mã đơn không trùng")


def tao_don(db: Session, user: User, goi: dict) -> DonThanhToan:
    """Đơn mới, hoặc đơn đang chờ còn hạn của chính người này cho cùng gói.

    Trả lại đơn cũ để bấm "Nâng cấp" hai lần không đẻ ra hai mã đơn — người dùng
    đã quét mã đầu mà lại gặp mã thứ hai thì không biết nên chuyển vào cái nào.
    """
    bg = bay_gio()
    cu = (db.query(DonThanhToan)
          .filter(DonThanhToan.user_id == user.id, DonThanhToan.goi == goi["ma"],
                  DonThanhToan.trang_thai == "cho", DonThanhToan.het_han > bg)
          .order_by(DonThanhToan.id.desc()).first())
    if cu is not None:
        return cu
    don = DonThanhToan(ma_don=_sinh_ma_don(db), user_id=user.id, goi=goi["ma"],
                       so_tien=goi["so_tien"], trang_thai="cho", tao_luc=bg, het_han=bg + HAN_DON)
    db.add(don)
    db.commit()
    db.refresh(don)
    return don


def trang_thai_don(don: DonThanhToan, luc: datetime | None = None) -> str:
    """cho | da_tra | het_han. "het_han" chỉ để HIỂN THỊ — trong CSDL đơn vẫn là "cho"
    vì tiền có thể về trễ và khi đó vẫn kích hoạt (xem `xu_ly_giao_dich`)."""
    if don.trang_thai == "da_tra":
        return "da_tra"
    return "het_han" if co_mui_gio(don.het_han) <= (luc or bay_gio()) else "cho"


def _kich_hoat(db: Session, don: DonThanhToan, nguon: str, giao_dich_id: int | None) -> bool:
    """Đánh dấu đã trả và cộng ngày Premium. KHÔNG commit. False nếu đơn đã bị ai đó trả trước.

    Cập nhật có điều kiện `trang_thai == "cho"`: hai giao dịch cùng mã đơn tới cùng lúc
    (hoặc quản trị bấm xác nhận tay đúng lúc webhook về) chỉ một bên thắng, không cộng đôi.
    """
    bg = bay_gio()
    da_doi = db.execute(
        update(DonThanhToan)
        .where(DonThanhToan.id == don.id, DonThanhToan.trang_thai == "cho")
        .values(trang_thai="da_tra", tra_luc=bg, nguon=nguon, giao_dich_id=giao_dich_id)
    ).rowcount
    if not da_doi:
        return False
    user = db.get(User, don.user_id) if don.user_id else None
    if user is None:    # chủ đơn đã xoá tài khoản giữa chừng — không có ai để cộng
        return True
    goc = max(bg, co_mui_gio(user.premium_den) or bg)
    user.premium_den = goc + timedelta(days=(tim_goi(don.goi) or GOI["thang"])["so_ngay"])
    return True


def xac_nhan_tay(db: Session, ma_don: str) -> DonThanhToan | None:
    don = db.query(DonThanhToan).filter(DonThanhToan.ma_don == ma_don.strip().upper()).first()
    if don is None:
        return None
    if don.trang_thai != "da_tra":
        _kich_hoat(db, don, "tay", None)
        db.commit()
        db.refresh(don)
    return don


def gan_giao_dich(db: Session, sepay_id: int, don: DonThanhToan) -> bool:
    """Quản trị đã xác nhận tay đơn [don] bằng khoản tiền SePay [sepay_id]: đánh dấu khoản đó
    là đã khớp để nó rời danh sách "chưa khớp". Chỉ đụng giao dịch còn `chua_khop`; KHÔNG commit."""
    gd = db.query(GiaoDichNganHang).filter(GiaoDichNganHang.sepay_id == sepay_id,
                                           GiaoDichNganHang.trang_thai == "chua_khop").first()
    if gd is None:
        return False
    gd.trang_thai = "da_khop"
    gd.ma_don = don.ma_don
    if don.giao_dich_id is None:
        don.giao_dich_id = gd.id
    return True


def tim_ma_don(*chuoi: str | None) -> list[str]:
    """Mọi mã trông giống mã đơn trong nội dung, theo thứ tự xuất hiện, không phân biệt hoa thường.

    Ngân hàng hay chèn chữ quanh nội dung ("MBVCB.123.HAI4K7Q2.CT tu NGUYEN VAN A"),
    nên phải TÌM chứ không so khớp nguyên chuỗi. Trả cả danh sách vì chữ lạ có thể
    tình cờ chứa "HAI" + 5 ký tự ("THAILAN…") — người gọi thử lần lượt từng mã.
    """
    ra: list[str] = []
    for c in chuoi:
        for m in MAU_MA_DON.findall((c or "").upper()):
            if m not in ra:
                ra.append(m)
    return ra


def _so_nguyen(v) -> int:
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return 0


def xu_ly_giao_dich(db: Session, du_lieu: dict) -> str:
    """Nhận một giao dịch SePay. Trả "da_khop" | "chua_khop" | "bo_qua" | "trung".

    `du_lieu["id"]` phải là số — người gọi (route) đã kiểm.
    """
    sepay_id = int(du_lieu["id"])
    if db.query(GiaoDichNganHang.id).filter(GiaoDichNganHang.sepay_id == sepay_id).first():
        return "trung"   # SePay gửi lại — đã xử lý rồi, tuyệt đối không cộng thêm ngày

    so_tien = _so_nguyen(du_lieu.get("transferAmount"))
    noi_dung = du_lieu.get("content")
    gd = GiaoDichNganHang(
        sepay_id=sepay_id, so_tien=so_tien, noi_dung=noi_dung if isinstance(noi_dung, str) else None,
        ngay_gd=str(du_lieu.get("transactionDate") or "")[:32] or None,
        trang_thai="chua_khop", nhan_luc=bay_gio(), du_lieu=du_lieu,
    )

    if du_lieu.get("transferType") != "in":
        gd.trang_thai = "bo_qua"          # tiền RA khỏi tài khoản: không liên quan đơn nào
    else:
        # "code" là mã SePay tự tách theo cấu hình của họ — thêm vào làm nguồn tìm thứ hai.
        for ma in tim_ma_don(noi_dung if isinstance(noi_dung, str) else None, du_lieu.get("code")):
            don = db.query(DonThanhToan).filter(DonThanhToan.ma_don == ma).first()
            if don is None:
                continue
            gd.ma_don = ma   # ghi lại cả khi thiếu tiền để quản trị biết người này định trả đơn nào
            # ĐƠN ĐÃ HẾT HẠN VẪN KÍCH HOẠT: hạn 30 phút chỉ để dọn đơn bỏ dở và để mã
            # không treo mãi. Nếu tiền thật đã về đúng số thì người ta đã trả rồi — từ
            # chối chỉ vì chuyển chậm là giữ tiền của phụ huynh mà không giao hàng.
            if so_tien < don.so_tien or don.trang_thai != "cho":
                break   # thiếu tiền, hoặc đơn đã được trả (chuyển hai lần) → để quản trị xử lý tay
            db.add(gd)
            try:
                db.flush()
            except IntegrityError:
                db.rollback()
                return "trung"   # hai lần gửi lại cùng id chạy song song: bên kia đã ghi
            if _kich_hoat(db, don, "sepay", gd.id):
                gd.trang_thai = "da_khop"
            break

    if gd.id is None:
        db.add(gd)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        return "trung"
    return gd.trang_thai
