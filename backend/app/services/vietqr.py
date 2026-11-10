"""Dựng chuỗi VietQR (EMVCo / NAPAS 247) để app vẽ thành mã QR chuyển khoản.

Loại QR ĐỘNG (trường 01 = "12"): mã gắn sẵn số tiền và nội dung, người trả chỉ
quét rồi bấm xác nhận — không phải gõ tay số tài khoản hay mã đơn (gõ sai mã đơn
là tiền về mà không biết cộng cho ai).

Mỗi trường là `<id 2 số><độ dài 2 số><giá trị>`; độ dài đếm theo KÝ TỰ.
    00  phiên bản định dạng       "01"
    01  loại khởi tạo             "12" (động)
    38  tài khoản thụ hưởng       gồm 00 GUID "A000000727" (NAPAS)
                                       01 gồm 00 BIN ngân hàng + 01 số tài khoản
                                       02 dịch vụ "QRIBFTTA" (chuyển nhanh về tài khoản)
    53  tiền tệ                   "704" (VND)
    54  số tiền
    58  quốc gia                  "VN"
    62  thông tin bổ sung         gồm 08 = nội dung chuyển khoản
    63  CRC16-CCITT (0xFFFF) của TOÀN BỘ chuỗi phía trước kể cả "6304"
"""
from __future__ import annotations

GUID_NAPAS = "A000000727"
DICH_VU_CHUYEN_NHANH_TAI_KHOAN = "QRIBFTTA"


def crc16_ccitt(du_lieu: str) -> str:
    """CRC16-CCITT/FALSE: đa thức 0x1021, khởi tạo 0xFFFF, không đảo bit. 4 ký tự hex HOA."""
    crc = 0xFFFF
    for byte in du_lieu.encode("utf-8"):
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return f"{crc:04X}"


def _truong(ma: str, gia_tri: str) -> str:
    # Độ dài tối đa 99 vì chỉ có 2 chữ số; vượt là chuỗi hỏng im lặng nên ném lỗi ngay.
    if len(gia_tri) > 99:
        raise ValueError(f"Trường {ma} dài {len(gia_tri)} ký tự, tối đa 99")
    return f"{ma}{len(gia_tri):02d}{gia_tri}"


def dung_chuoi(bin_nh: str, so_tk: str, so_tien: int, noi_dung: str) -> str:
    if not (bin_nh.isdigit() and len(bin_nh) == 6):
        raise ValueError("BIN ngân hàng phải gồm đúng 6 chữ số")
    if not so_tk or not so_tk.isalnum():
        raise ValueError("Số tài khoản không hợp lệ")
    if so_tien <= 0:
        raise ValueError("Số tiền phải lớn hơn 0")

    ben_huong = _truong("38", (
        _truong("00", GUID_NAPAS)
        + _truong("01", _truong("00", bin_nh) + _truong("01", so_tk))
        + _truong("02", DICH_VU_CHUYEN_NHANH_TAI_KHOAN)
    ))
    chuoi = (
        _truong("00", "01")
        + _truong("01", "12")
        + ben_huong
        + _truong("53", "704")
        + _truong("54", str(int(so_tien)))
        + _truong("58", "VN")
        + _truong("62", _truong("08", noi_dung))
        + "6304"
    )
    return chuoi + crc16_ccitt(chuoi)
