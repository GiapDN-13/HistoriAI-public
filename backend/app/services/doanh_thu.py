"""Số liệu doanh thu & Premium cho dashboard nội bộ.

Vì sao một hàm riêng thay vì nhét vào `build_summary`: tiền cần đúng từng đồng nên
phải test riêng (xem tests/test_doanh_thu.py), và `analytics.py` đã dài.

Quy ước (đọc kỹ trước khi so với số của ngân hàng)
    • Mọi mốc "ngày" theo GIỜ VIỆT NAM. Đơn trả 23:30 giờ VN là ngày đó, dù lúc ấy
      UTC đã sang ngày hôm sau.
    • "N ngày" = N ngày LỊCH tính cả hôm nay (7 ngày = hôm nay + 6 ngày trước), để
      tổng các cột trong biểu đồ đúng bằng con số ở thẻ.
    • Gói "thu" (2.000đ của quản trị) KHÔNG vào doanh thu, không vào số người mua —
      nó chỉ để thử đường tiền, tính vào sẽ thổi phồng số liệu đem đi báo cáo.
      Đếm riêng ở `so_don_thu`.
    • Số đơn (tạo / trả / hết hạn / tỉ lệ) tính theo ngày TẠO đơn: "trong những đơn
      bắt đầu mua, bao nhiêu % trả xong". Doanh thu thì tính theo ngày TRẢ vì tiền
      về lúc đó — hai nhóm có thể lệch nhau khi đơn tạo hôm qua, trả hôm nay.
    • Người đang có Premium không tính tài khoản quản trị (quản trị được mở khoá mọi
      thứ, và `premium_den` của họ chỉ là dấu vết của gói thử).

Quyền riêng tư: ra ngoài chỉ có tên gọi rút gọn (chữ cuối của họ tên). Không có
email, số tài khoản, user_id; nội dung chuyển khoản bị cắt vì người ta hay ghi
thêm tên mình, số điện thoại vào đó.
"""
from __future__ import annotations

from collections import Counter
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models.thanh_toan import DonThanhToan, GiaoDichNganHang
from app.models.user import User
from app.services.ngay_hoc import GIO_VN
from app.services.thanh_toan import GOI_THU, co_mui_gio

SO_DON_GAN_DAY = 20
SO_GD_CHUA_KHOP = 20
CAT_NOI_DUNG = 60
SAP_HET_HAN = timedelta(days=3)


def _ngay_vn(dt: datetime) -> date:
    return co_mui_gio(dt).astimezone(GIO_VN).date()


def _gio_vn(dt: datetime | None) -> str | None:
    return co_mui_gio(dt).astimezone(GIO_VN).strftime("%d/%m/%Y %H:%M") if dt else None


def _dau_ngay_utc(d: date) -> datetime:
    """0 giờ ngày [d] theo giờ VN, đổi sang UTC để so với cột lưu UTC.

    Phải đổi trước khi đưa vào câu truy vấn: SQLite bỏ qua múi giờ khi so sánh, đưa
    thẳng mốc giờ VN vào là lệch 7 tiếng.
    """
    return datetime.combine(d, time.min, tzinfo=GIO_VN).astimezone(timezone.utc)


def ten_goi_nguoi_mua(full_name: str | None) -> str:
    """Chữ cuối của họ tên ("Nguyễn Văn An" → "An") — người Việt gọi nhau bằng tên."""
    phan = (full_name or "").split()
    return phan[-1] if phan else "Ẩn danh"


def _gop(so_tien: int, so_don: int) -> dict:
    return {"so_tien": so_tien, "so_don": so_don}


def tinh_doanh_thu(db: Session, days: int = 30, den: datetime | None = None) -> dict:
    """Doanh thu & Premium của [days] ngày lịch kết thúc tại [den] (mặc định: bây giờ)."""
    # Về UTC ngay từ đầu: `den` còn được đưa vào câu truy vấn, mà SQLite bỏ qua múi giờ.
    den = co_mui_gio(den or datetime.now(timezone.utc)).astimezone(timezone.utc)
    hom_nay = den.astimezone(GIO_VN).date()
    tu_ngay = hom_nay - timedelta(days=days - 1)

    # --- Đơn đã trả: đọc hết rồi lọc bằng Python (cùng lý do với analytics.py: chạy
    # giống nhau ở SQLite và PostgreSQL; vài nghìn đơn là đủ nhanh).
    da_tra = db.query(DonThanhToan).filter(DonThanhToan.trang_thai == "da_tra").all()
    tinh_tien = [d for d in da_tra if d.goi != GOI_THU["ma"]]
    ngay_tra = {d.id: _ngay_vn(d.tra_luc or d.tao_luc) for d in tinh_tien}

    def tong(n_ngay: int) -> dict:
        moc = hom_nay - timedelta(days=n_ngay - 1)
        trong = [d for d in tinh_tien if moc <= ngay_tra[d.id] <= hom_nay]
        return _gop(sum(d.so_tien for d in trong), len(trong))

    theo_ngay: dict[date, list[int]] = {}
    for d in tinh_tien:
        if tu_ngay <= ngay_tra[d.id] <= hom_nay:
            o = theo_ngay.setdefault(ngay_tra[d.id], [0, 0])
            o[0] += d.so_tien
            o[1] += 1
    # Điền cả ngày không có đơn nào (cột 0 đ): thiếu ngày thì trục thời gian bị nén,
    # nhìn tưởng bán đều.
    bieu_do = [{"ngay": (tu_ngay + timedelta(days=i)).isoformat(),
                "so_tien": theo_ngay.get(tu_ngay + timedelta(days=i), [0, 0])[0],
                "so_don": theo_ngay.get(tu_ngay + timedelta(days=i), [0, 0])[1]}
               for i in range(days)]

    trong_khoang = [d for d in tinh_tien if tu_ngay <= ngay_tra[d.id] <= hom_nay]
    so_don_thu = sum(1 for d in da_tra
                     if d.goi == GOI_THU["ma"] and tu_ngay <= _ngay_vn(d.tra_luc or d.tao_luc) <= hom_nay)

    # --- Đơn theo ngày tạo (không tính gói thử)
    tao_trong = (db.query(DonThanhToan)
                 .filter(DonThanhToan.tao_luc >= _dau_ngay_utc(tu_ngay),
                         DonThanhToan.goi != GOI_THU["ma"])
                 .all())
    tao_trong = [d for d in tao_trong if _ngay_vn(d.tao_luc) <= hom_nay]
    n_tra = sum(1 for d in tao_trong if d.trang_thai == "da_tra")
    # Giống `thanh_toan.trang_thai_don`: "hết hạn" chỉ suy ra lúc đọc, trong CSDL vẫn là "cho".
    n_het_han = sum(1 for d in tao_trong
                    if d.trang_thai != "da_tra" and co_mui_gio(d.het_han) <= den)
    n_cho = len(tao_trong) - n_tra - n_het_han
    ti_le = round(n_tra / len(tao_trong) * 100, 1) if tao_trong else 0.0

    # --- Premium
    khong_phai_qt = or_(User.role.is_(None), User.role != "admin")
    dang_co = (db.query(User.id)
               .filter(User.premium_den > den, khong_phai_qt).count())
    sap_het = (db.query(User.id)
               .filter(User.premium_den > den, User.premium_den <= den + SAP_HET_HAN,
                       khong_phai_qt).count())
    so_lan_mua = Counter(d.user_id for d in tinh_tien if d.goi == "thang" and d.user_id)

    # --- 20 đơn trả gần nhất (kể cả gói thử, có cột gói để phân biệt: quản trị muốn thấy
    # đường tiền thử có chạy không)
    gan_day = sorted(da_tra, key=lambda d: co_mui_gio(d.tra_luc or d.tao_luc),
                     reverse=True)[:SO_DON_GAN_DAY]
    chu = {u.id: u.full_name for u in db.query(User.id, User.full_name)
           .filter(User.id.in_([d.user_id for d in gan_day if d.user_id])).all()}

    # --- Giao dịch tiền vào mà chưa gắn được đơn nào
    chua_khop = (db.query(GiaoDichNganHang).filter(GiaoDichNganHang.trang_thai == "chua_khop")
                 .order_by(GiaoDichNganHang.id.desc()).limit(SO_GD_CHUA_KHOP).all())

    return {
        "hom_nay": tong(1),
        "bay_ngay": tong(7),
        "ba_muoi_ngay": tong(30),
        "trong_khoang": _gop(sum(d.so_tien for d in trong_khoang), len(trong_khoang)),
        "theo_ngay": bieu_do,
        "don": {"da_tao": len(tao_trong), "da_tra": n_tra, "het_han": n_het_han,
                "dang_cho": n_cho, "ti_le_tra": ti_le},
        "so_don_thu": so_don_thu,
        "premium": {"dang_co": dang_co, "sap_het_han": sap_het,
                    "tung_mua": len(so_lan_mua),
                    "mua_lai": sum(1 for n in so_lan_mua.values() if n >= 2)},
        "nguon_tra": {"sepay": sum(1 for d in trong_khoang if d.nguon == "sepay"),
                      "tay": sum(1 for d in trong_khoang if d.nguon == "tay")},
        "don_gan_day": [{"ma_don": d.ma_don, "goi": d.goi, "so_tien": d.so_tien,
                         "gio_tra": _gio_vn(d.tra_luc or d.tao_luc), "nguon": d.nguon,
                         "nguoi_mua": ten_goi_nguoi_mua(chu.get(d.user_id))}
                        for d in gan_day],
        "chua_khop": [{"sepay_id": g.sepay_id, "so_tien": g.so_tien,
                       "noi_dung": (g.noi_dung or "")[:CAT_NOI_DUNG],
                       "gio": _gio_vn(g.nhan_luc), "ma_don": g.ma_don}
                      for g in chua_khop],
    }


def dinh_dang_tien(so_tien: int) -> str:
    """39000 → "39.000" (dấu chấm hàng nghìn kiểu Việt, không phụ thuộc locale máy chủ)."""
    return f"{so_tien:,}".replace(",", ".")
