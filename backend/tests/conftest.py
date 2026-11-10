"""Mỗi test bắt đầu với bộ đếm giới hạn sạch.

Các test đăng ký nhiều tài khoản từ cùng một "máy" giả lập (TestClient) — không đặt
lại thì test sau vấp giới hạn "5 tài khoản/giờ" do test trước để lại.
"""
import sys
from pathlib import Path

import pytest

# CI chạy `pytest -q` (không qua `python -m pytest`), nên thư mục backend/ không có sẵn
# trên sys.path — mà conftest được nạp TRƯỚC các tệp test. Thiếu dòng này là CI đỏ
# với "No module named 'app'" dù chạy trên máy vẫn xanh.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.gioi_han import bo_gioi_han, bo_gioi_han_ban_tin, bo_gioi_han_giong  # noqa: E402
from app.services.gioi_han_dang_nhap import cua  # noqa: E402


@pytest.fixture(autouse=True)
def _dat_lai_gioi_han():
    cua.dat_lai()
    bo_gioi_han.dat_lai()
    bo_gioi_han_giong.dat_lai()
    bo_gioi_han_ban_tin.dat_lai()
    yield
