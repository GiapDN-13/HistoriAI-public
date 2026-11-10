"""Bộ chặn lạm dụng cho các endpoint gọi LLM.

Loại mã này hỏng ngầm rất dễ: nới tay quá thì không chặn được ai, siết quá thì
chặn nhầm cả lớp đang ngồi chung wifi mà không ai báo lỗi cho mình biết.
"""
import pytest
from fastapi import HTTPException

from app.services import gioi_han as G


@pytest.fixture(autouse=True)
def _sach():
    G.bo_gioi_han.dat_lai()
    yield
    G.bo_gioi_han.dat_lai()


NGAY = "2026-09-22"


def _goi(may="may-A", ip="1.2.3.4", ngay=NGAY):
    G.bo_gioi_han.xin_luot(may, ip, ngay)


def test_dung_binh_thuong_thi_khong_bi_chan():
    for _ in range(G.MAY_PHUT.so_luot):
        _goi()


def test_vuot_muc_phut_thi_bi_chan_kem_so_giay_cho():
    for _ in range(G.MAY_PHUT.so_luot):
        _goi()
    with pytest.raises(HTTPException) as e:
        _goi()
    assert e.value.status_code == 429
    # Phải nói rõ chờ bao lâu, nếu không client chỉ biết thử lại mù.
    assert "Retry-After" in e.value.headers
    assert int(e.value.headers["Retry-After"]) > 0


def test_may_khac_khong_bi_va_lay():
    """Một người bị chặn thì người bên cạnh vẫn hỏi được."""
    for _ in range(G.MAY_PHUT.so_luot):
        _goi(may="may-A")
    with pytest.raises(HTTPException):
        _goi(may="may-A")
    _goi(may="may-B")  # không được ném


def test_ca_lop_chung_mot_wifi_van_dung_duoc():
    """Ba mươi máy khác nhau, cùng một IP, mỗi máy hỏi hai câu.

    Đây đúng là hình dạng của một buổi demo trên lớp. Siết theo IP mà quên
    trường hợp này là người thứ hai giơ điện thoại lên đã bị chặn.
    """
    for i in range(30):
        _goi(may=f"may-{i}", ip="cung-mot-wifi")
        _goi(may=f"may-{i}", ip="cung-mot-wifi")


def test_doi_ma_may_lien_tuc_van_bi_IP_chan():
    """Kẻ lạm dụng sinh client_id mới mỗi lần gọi — lớp IP phải bắt được."""
    with pytest.raises(HTTPException) as e:
        for i in range(G.IP_PHUT.so_luot + 5):
            _goi(may=f"gia-mao-{i}", ip="9.9.9.9")
    assert e.value.status_code == 429


def test_tran_ngay_bao_ve_han_muc_nha_cung_cap():
    _goi()  # để bộ đếm nhận ngày hôm nay trước, rồi mới đẩy nó lên trần
    G.bo_gioi_han._dem_ngay = G.TRAN_NGAY
    with pytest.raises(HTTPException) as e:
        _goi(may="may-moi-tinh", ip="8.8.8.8")
    assert e.value.status_code == 429
    assert "ngày mai" in e.value.detail


def test_sang_ngay_moi_thi_dem_lai_tu_dau():
    _goi()
    G.bo_gioi_han._dem_ngay = G.TRAN_NGAY
    _goi(ngay="2026-09-23")  # không được ném
    assert G.bo_gioi_han.da_dung_hom_nay == 1


class _Gia:
    """Request giả, chỉ đủ phần bộ chặn cần đọc."""

    def __init__(self, headers, host="127.0.0.1"):
        self.headers = {k.lower(): v for k, v in headers.items()}
        self.client = type("C", (), {"host": host})()


def test_uu_tien_IP_that_tu_Cloudflare():
    """CF-Connecting-IP do Cloudflare ghi ở biên, người ngoài không giả được.

    X-Forwarded-For thì ai cũng tự thêm vào được, nên chỉ dùng khi không có
    cái trên — và chỉ lấy phần tử đầu.
    """
    assert G.dia_chi_that(_Gia({
        "CF-Connecting-IP": "203.0.113.7",
        "X-Forwarded-For": "1.1.1.1, 2.2.2.2",
    })) == "203.0.113.7"

    assert G.dia_chi_that(_Gia({
        "X-Forwarded-For": "203.0.113.9, 10.0.0.1",
    })) == "203.0.113.9"

    assert G.dia_chi_that(_Gia({}, host="192.168.1.5")) == "192.168.1.5"


def test_khong_gui_ma_may_thi_bi_gop_theo_IP():
    """Client cũ và mọi công cụ dòng lệnh rơi vào nhánh này — nhóm cần siết nhất."""
    r = _Gia({}, host="5.5.5.5")
    for _ in range(G.MAY_PHUT.so_luot):
        G.chan_lam_dung(r)
    with pytest.raises(HTTPException):
        G.chan_lam_dung(r)
