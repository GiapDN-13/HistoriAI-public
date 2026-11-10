"""Chặn dò mật khẩu và tạo tài khoản rác.

Đo ngày 27/09: sai mật khẩu 12 lần liên tiếp — cả 12 lần đều được xử lý. Mở đường dò
mật khẩu, và tài khoản rác làm bẩn đúng con số "đăng ký" sẽ vào báo cáo tuần.

ĐĂNG NHẬP — CHỈ ĐẾM LẦN SAI
    Đếm mọi lần đăng nhập thì cả lớp chung một wifi (chung một IP) đăng nhập cùng lúc
    sẽ tự chặn nhau. Nên chỉ đếm lần SAI, theo hai khoá:
      • (IP, email): 10 lần sai / 15 phút — dò một tài khoản cụ thể.
      • IP: 150 lần sai / 15 phút — dò rải nhiều tài khoản. Nới rộng vì một lớp
        40 học sinh gõ nhầm mật khẩu vài lần là chuyện thường.
    Đăng nhập đúng thì xoá số lần sai của cặp (IP, email) đó.

ĐĂNG KÝ
      • Theo máy (X-Client-Id): 5 tài khoản / giờ — một người không cần hơn.
      • Theo IP: 60 tài khoản / giờ — đủ cho một lớp đăng ký cùng buổi.

QUÊN MẬT KHẨU
      • Theo email: 3 thư / giờ — không để ai dùng app làm súng bắn thư rác vào
        hộp thư người khác.
      • Theo IP: 20 yêu cầu / giờ; đặt lại (nhập mã): 30 lần / giờ / IP.

Nằm trong bộ nhớ tiến trình như gioi_han.py: khởi động lại là mất số đếm. Đủ để chặn
lạm dụng, không dùng để đo đếm.
"""
from __future__ import annotations

import threading
import time
from collections import deque

from fastapi import HTTPException, Request

from app.services.gioi_han import dia_chi_that

SAI_TAI_KHOAN = (10, 15 * 60)
SAI_IP = (150, 15 * 60)
DK_MAY = (5, 3600)
DK_IP = (60, 3600)
QUEN_EMAIL = (3, 3600)
QUEN_IP = (20, 3600)
DAT_LAI_IP = (30, 3600)


class _Cua:
    def __init__(self) -> None:
        self._khoa = threading.Lock()
        self._hang: dict[str, deque[float]] = {}

    def _don(self, khoa: str, trong: int, bay_gio: float) -> deque[float]:
        h = self._hang.setdefault(khoa, deque())
        while h and bay_gio - h[0] > trong:
            h.popleft()
        return h

    def con_cho(self, khoa: str, muc: tuple[int, int]) -> float:
        """Số giây phải chờ; 0 = được phép. Không ghi lượt."""
        so, trong = muc
        bay_gio = time.monotonic()
        with self._khoa:
            h = self._don(khoa, trong, bay_gio)
            return 0.0 if len(h) < so else trong - (bay_gio - h[0])

    def ghi(self, khoa: str) -> None:
        with self._khoa:
            self._hang.setdefault(khoa, deque()).append(time.monotonic())
            if len(self._hang) > 50_000:            # chặn phình bộ nhớ khi bị dội
                for k in [k for k, h in self._hang.items() if not h][:10_000]:
                    self._hang.pop(k, None)

    def xoa(self, khoa: str) -> None:
        with self._khoa:
            self._hang.pop(khoa, None)

    def dat_lai(self) -> None:
        with self._khoa:
            self._hang.clear()


cua = _Cua()


def _chan(cho: float, loi: str) -> None:
    if cho > 0:
        phut = int(cho // 60) + 1
        raise HTTPException(429, f"{loi} Thử lại sau khoảng {phut} phút.",
                            headers={"Retry-After": str(int(cho) + 1)})


def kiem_dang_nhap(request: Request, email: str) -> tuple[str, str]:
    """Gọi TRƯỚC khi kiểm mật khẩu. Trả về khoá để ghi lần sai/xoá khi đúng."""
    ip = dia_chi_that(request)
    k_tk, k_ip = f"sai:{ip}:{email.strip().lower()}", f"sai-ip:{ip}"
    _chan(cua.con_cho(k_tk, SAI_TAI_KHOAN), "Sai mật khẩu nhiều lần quá.")
    _chan(cua.con_cho(k_ip, SAI_IP), "Có quá nhiều lần đăng nhập sai từ mạng này.")
    return k_tk, k_ip


def ghi_sai(khoa: tuple[str, str]) -> None:
    for k in khoa:
        cua.ghi(k)


def dang_nhap_dung(khoa: tuple[str, str]) -> None:
    cua.xoa(khoa[0])


def kiem_dang_ky(request: Request) -> None:
    ip = dia_chi_that(request)
    may = (request.headers.get("x-client-id") or "").strip()[:64] or f"ip:{ip}"
    _chan(cua.con_cho(f"dk-may:{may}", DK_MAY), "Máy này đã tạo nhiều tài khoản trong giờ qua.")
    _chan(cua.con_cho(f"dk-ip:{ip}", DK_IP), "Mạng này đã tạo nhiều tài khoản trong giờ qua.")
    cua.ghi(f"dk-may:{may}")
    cua.ghi(f"dk-ip:{ip}")


def kiem_quen_mat_khau(request: Request, email: str) -> None:
    ip = dia_chi_that(request)
    k_email, k_ip = f"quen:{email.strip().lower()}", f"quen-ip:{ip}"
    _chan(cua.con_cho(k_ip, QUEN_IP), "Có quá nhiều yêu cầu từ mạng này.")
    _chan(cua.con_cho(k_email, QUEN_EMAIL), "Đã gửi thư cho email này nhiều lần.")
    cua.ghi(k_ip)
    cua.ghi(k_email)


def kiem_dat_lai(request: Request) -> None:
    k = f"dat-lai-ip:{dia_chi_that(request)}"
    _chan(cua.con_cho(k, DAT_LAI_IP), "Thử quá nhiều lần.")
    cua.ghi(k)
