"""Chặn lạm dụng cho các endpoint gọi LLM.

VÌ SAO CẦN
    `/chat` và `/chat/stream` không yêu cầu đăng nhập — cố ý, vì bắt tạo tài
    khoản trước khi được hỏi thử một câu là chặn đúng nhóm người ta muốn thu
    hút. Nhưng từ lúc có trang tải công khai kèm mã QR thì ai tìm ra tên miền
    cũng gọi thẳng được endpoint LLM.

    Hạn mức Groq bản miễn phí là hạn mức CỨNG. Một người viết vòng lặp là chat
    chết cho tất cả mọi người, và chết đúng lúc đang demo — mà nhìn từ ngoài
    chỉ thấy "app lỗi", không ai đoán ra nguyên nhân.

BA LỚP, TỪ HẸP TỚI RỘNG
    1. Theo máy (`X-Client-Id`)  — lớp chính, công bằng nhất.
    2. Theo địa chỉ IP           — bắt kẻ đổi client_id mỗi lần gọi. Phải nới
       tay vì cả lớp học ngồi chung một wifi là chung một IP.
    3. Trần toàn hệ mỗi ngày     — lưới cuối bảo vệ hạn mức Groq. Thà cả nhà
       cùng hết lượt lúc nửa đêm còn hơn cháy hạn mức lúc 9 giờ sáng hôm demo.

GIỚI HẠN NÀY NẰM TRONG BỘ NHỚ TIẾN TRÌNH
    Khởi động lại là mất sạch số đếm, và chạy nhiều tiến trình thì mỗi tiến
    trình đếm riêng. Chấp nhận được: đây là cái chặn lạm dụng, không phải cái
    đo đếm để tính tiền. Khi nào cần chính xác thì chuyển sang Redis.
"""
from __future__ import annotations

import os
import threading
import time
from collections import deque
from dataclasses import dataclass, field

from fastapi import HTTPException, Request


@dataclass
class Muc:
    """Số lượt tối đa trong một khoảng thời gian."""

    so_luot: int
    trong_giay: int


# Một câu hỏi tử tế mất vài giây để đọc câu trả lời, nên 8 lượt/phút đã là
# nhanh hơn người thật rất nhiều mà vẫn không cản ai đang dùng bình thường.
MAY_PHUT = Muc(8, 60)
MAY_GIO = Muc(60, 3600)
# Cả lớp chung một wifi: nới rộng, chỉ để bắt kẻ đổi client_id liên tục.
#
# Con số phải chịu được hình dạng thật của một buổi demo: bốn chục máy sau
# cùng một NAT, mỗi máy hỏi vài câu trong cùng một phút. Bản đầu tôi đặt 40 —
# test `test_ca_lop_chung_mot_wifi_van_dung_duoc` bắt được ngay: người thứ hai
# mươi mốt giơ điện thoại lên là bị chặn, mà chặn im lặng.
IP_PHUT = Muc(150, 60)
IP_GIO = Muc(1200, 3600)

# Trần ngày toàn hệ — lưới cuối bảo vệ hạn mức nhà cung cấp LLM. Đặt được qua
# biến môi trường vì mỗi nhà cung cấp một hạn mức, và hạn mức thì hay đổi.
TRAN_NGAY = int(os.getenv("LLM_TRAN_NGAY", "3000"))

# GIỌNG ĐỌC ĐẾM RIÊNG (sửa 28/09). Trước đây /speak/stream dùng chung 8 lượt/phút
# với /chat, mà app xin giọng cho TỪNG CÂU của câu trả lời: một câu trả lời 8 câu
# là hết lượt → từ câu thứ 9 máy chủ trả 429 → app đọc bằng giọng trình duyệt,
# nghe như vĩ nhân "đổi giọng giữa chừng". Tệ hơn, câu hỏi chat kế tiếp trong
# phút đó cũng bị chặn "Con hỏi nhanh quá". Giọng không tốn lượt LLM (VieNeu chạy
# trên VPS, câu trùng lấy từ lưu đệm) nên nới rộng và không tính vào trần ngày.
GIONG_MAY_PHUT = Muc(60, 60)
GIONG_MAY_GIO = Muc(600, 3600)
GIONG_IP_PHUT = Muc(600, 60)
GIONG_IP_GIO = Muc(6000, 3600)

# BẢN TIN PHỤ HUYNH (routes/ban_tin.py) — trang công khai, mở bằng link gửi qua Zalo,
# không gọi LLM. Chỉ đếm theo IP: phụ huynh không có X-Client-Id. 30 lượt/phút là
# thừa cho một gia đình bấm đi bấm lại, mà vẫn chặn được ai dội trang (mỗi lượt đọc
# cả lịch sử làm bài của một học sinh). Không tính vào trần ngày của chat.
BAN_TIN_PHUT = Muc(30, 60)
BAN_TIN_GIO = Muc(300, 3600)


@dataclass
class _So:
    dau: dict[str, deque[float]] = field(default_factory=dict)


class BoGioiHan:
    def __init__(self, may: tuple[Muc, Muc] = (MAY_PHUT, MAY_GIO),
                 ip: tuple[Muc, Muc] = (IP_PHUT, IP_GIO),
                 co_tran_ngay: bool = True) -> None:
        self._muc_may = list(may)
        self._muc_ip = list(ip)
        self._co_tran_ngay = co_tran_ngay
        self._khoa = threading.Lock()
        self._theo_may = _So()
        self._theo_ip = _So()
        self._ngay_hien_tai = ""
        self._dem_ngay = 0

    @staticmethod
    def _con_lai(hang: deque[float], muc: Muc, bay_gio: float) -> float:
        """Số giây phải chờ, 0 nghĩa là được phép."""
        while hang and bay_gio - hang[0] > muc.trong_giay:
            hang.popleft()
        if len(hang) < muc.so_luot:
            return 0.0
        return muc.trong_giay - (bay_gio - hang[0])

    def _kiem(self, kho: _So, khoa: str, mucs: list[Muc], bay_gio: float) -> float:
        hang = kho.dau.setdefault(khoa, deque())
        for m in mucs:
            cho = self._con_lai(hang, m, bay_gio)
            if cho > 0:
                return cho
        return 0.0

    def _don_rac(self, bay_gio: float) -> None:
        """Bỏ những khoá đã im lặng quá lâu, kẻo từ điển phình mãi."""
        for kho, han in ((self._theo_may, self._muc_may[-1]), (self._theo_ip, self._muc_ip[-1])):
            cu = [k for k, h in kho.dau.items()
                  if not h or bay_gio - h[-1] > han.trong_giay]
            for k in cu:
                kho.dau.pop(k, None)

    def xin_luot(self, may: str, ip: str, ngay: str) -> None:
        """Ghi nhận một lượt, hoặc ném 429 kèm số giây cần chờ."""
        bay_gio = time.monotonic()
        with self._khoa:
            if ngay != self._ngay_hien_tai:
                self._ngay_hien_tai = ngay
                self._dem_ngay = 0
                self._don_rac(bay_gio)

            if self._co_tran_ngay and self._dem_ngay >= TRAN_NGAY:
                raise HTTPException(
                    429,
                    "Hôm nay các vị tiền nhân đã đàm đạo hết lượt. "
                    "Con hãy quay lại vào ngày mai nhé.",
                    headers={"Retry-After": "3600"},
                )

            cho = max(
                self._kiem(self._theo_may, may, self._muc_may, bay_gio),
                self._kiem(self._theo_ip, ip, self._muc_ip, bay_gio),
            )
            if cho > 0:
                raise HTTPException(
                    429,
                    "Con hỏi nhanh quá, ta chưa kịp ngẫm. "
                    f"Hãy chờ {int(cho) + 1} giây rồi hỏi lại.",
                    headers={"Retry-After": str(int(cho) + 1)},
                )

            self._theo_may.dau[may].append(bay_gio)
            self._theo_ip.dau[ip].append(bay_gio)
            self._dem_ngay += 1

    # --- dùng trong test ---
    def dat_lai(self) -> None:
        with self._khoa:
            self._theo_may = _So()
            self._theo_ip = _So()
            self._ngay_hien_tai = ""
            self._dem_ngay = 0

    @property
    def da_dung_hom_nay(self) -> int:
        return self._dem_ngay


bo_gioi_han = BoGioiHan()
bo_gioi_han_giong = BoGioiHan(may=(GIONG_MAY_PHUT, GIONG_MAY_GIO),
                              ip=(GIONG_IP_PHUT, GIONG_IP_GIO), co_tran_ngay=False)
bo_gioi_han_ban_tin = BoGioiHan(may=(BAN_TIN_PHUT, BAN_TIN_GIO),
                                ip=(BAN_TIN_PHUT, BAN_TIN_GIO), co_tran_ngay=False)


def dia_chi_that(request: Request) -> str:
    """IP thật của người gọi, đọc qua các lớp proxy.

    Thứ tự có chủ đích: Cloudflare đặt CF-Connecting-IP và người ngoài không
    giả được (nó bị ghi đè ở biên). X-Forwarded-For thì AI cũng tự thêm được,
    nên chỉ dùng khi không có cái trên, và chỉ lấy phần tử ĐẦU.
    """
    cf = request.headers.get("cf-connecting-ip")
    if cf:
        return cf.strip()
    xff = request.headers.get("x-forwarded-for")
    if xff:
        return xff.split(",")[0].strip()
    real = request.headers.get("x-real-ip")
    if real:
        return real.strip()
    return request.client.host if request.client else "khong-ro"


def chan_lam_dung(request: Request) -> None:
    """Dependency cho các route gọi LLM."""
    ip = dia_chi_that(request)
    # Không có X-Client-Id thì lấy IP làm khoá máy luôn: client cũ và mọi công
    # cụ dòng lệnh đều rơi vào nhánh này, và đó đúng là nhóm cần siết nhất.
    may = (request.headers.get("x-client-id") or "").strip()[:64] or f"ip:{ip}"
    ngay = time.strftime("%Y-%m-%d")
    bo_gioi_han.xin_luot(may, ip, ngay)


def chan_lam_dung_giong(request: Request) -> None:
    """Dependency cho các route tạo giọng — sổ đếm riêng, xem GIONG_MAY_PHUT."""
    ip = dia_chi_that(request)
    may = (request.headers.get("x-client-id") or "").strip()[:64] or f"ip:{ip}"
    bo_gioi_han_giong.xin_luot(may, ip, time.strftime("%Y-%m-%d"))
