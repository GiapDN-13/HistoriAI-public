"""Chống bịa sử liệu: chọn đúng mệnh đề có nguồn, gửi nguồn thật, quy tắc có trong lời dặn."""
import os

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402
from app.services import su_lieu  # noqa: E402
from app.services.ai_chat import LUAT_CHONG_BIA, _build_system_prompt  # noqa: E402

seed.run()
client = TestClient(app)


def _ton_tai(ds, chu):
    return any(chu in m["t"] for m in ds)


def test_hoi_tuong_bi_bat_thi_lay_dung_menh_de_o_ma_nhi():
    """Lỗi thật 27/09: mô hình nói "Toa Đô bị bắt" vì không có sử liệu trận 1288."""
    ds = su_lieu.chon("tran-hung-dao", "Sau trận Bạch Đằng năm 1288 những tướng giặc nào bị bắt?")
    assert _ton_tai(ds, "bắt Ô Mã Nhi"), [m["t"] for m in ds]
    assert len(ds) <= su_lieu.SO_MENH_DE
    assert len(su_lieu.dinh_dang(ds)) < 3800, "giữ ngữ cảnh ~1.000 token (hạn mức Groq)"


def test_hoi_noi_tiep_van_tim_dung_cho_nho_luot_truoc():
    ls = [{"role": "user", "content": "Ngài đánh trận Bạch Đằng năm nào?"},
          {"role": "assistant", "content": "Năm 1288 ta đánh tan thủy quân Ô Mã Nhi."}]
    ds = su_lieu.chon("tran-hung-dao", "Vậy sau đó thì sao?", ls)
    assert _ton_tai(ds, "Ô Mã Nhi")


def test_cau_chao_hoi_van_co_nen_hang_a():
    ds = su_lieu.chon("tran-hung-dao", "Chào ngài")
    assert ds and all(m["hang"] in ("K", "A") for m in ds)


def test_menh_de_mau_thuan_ghi_ro_chua_thong_nhat():
    ds = su_lieu.chon("tran-hung-dao", "Toa Đô chết thế nào?")
    chu = su_lieu.dinh_dang(ds)
    assert "(CÁC NGUỒN CHƯA THỐNG NHẤT) Toa Đô trúng tên chết" in chu
    assert "Wikipedia" not in su_lieu.nguon_da_dung([m for m in ds if m["hang"] == "C"])


def test_vi_nhan_khong_co_kho_thi_khong_them_gi():
    assert su_lieu.chon("khong-ton-tai", "bất kỳ") == []


def test_quy_tac_chong_bia_nam_trong_loi_dan():
    class NV:
        persona_prompt, verified_facts, name = "Ta là Trần Hưng Đạo.", None, "Trần Hưng Đạo"
    p = _build_system_prompt(NV(), "- Trần Hưng Đạo bắt sống Ô Mã Nhi. [Wikipedia tiếng Việt]")
    assert "SỬ LIỆU CÓ NGUỒN" in p and LUAT_CHONG_BIA in p
    assert p.index("bắt sống Ô Mã Nhi") < p.index("QUY TẮC BẮT BUỘC")


def test_stream_gui_nguon_that_truoc_done():
    """Không có khoá LLM (CI) → trả lời mock, nhưng dòng nguồn vẫn phải có và đúng thứ tự."""
    than = {"figure_slug": "tran-hung-dao", "message": "Ngài bắt sống những ai năm 1288?"}
    r = client.post("/api/v1/chat/stream", json={**than, "nhan_nguon": True})
    dong = [d[6:] for d in r.text.splitlines() if d.startswith("data: ")]
    assert dong[-1] == "[DONE]"
    assert dong[-2].startswith("[NGUON]") and "Wikipedia tiếng Việt" in dong[-2]
    # Bản cài cũ không xin → không gửi, kẻo nó in nguyên chữ ra màn hình
    cu = client.post("/api/v1/chat/stream", json=than)
    assert "[NGUON]" not in cu.text


def test_go_khong_dau_van_tim_dung():
    """Học sinh hay gõ không dấu."""
    ds = su_lieu.chon("tran-hung-dao", "ngai bat song nhung ai nam 1288")
    assert _ton_tai(ds, "Ô Mã Nhi")
    ds = su_lieu.chon("quang-trung", "ton si nghi mang bao nhieu quan")
    assert ds[0]["t"].startswith("Tôn Sĩ Nghị mang khoảng 29 vạn quân")


def test_ho_so_nhom_duoc_uu_tien_va_giu_luu_y_dien_giai():
    """Hồ sơ nhóm (KNB/) đứng trên mệnh đề tự động; lưu ý "không gán…" phải tới được mô hình."""
    ds = su_lieu.chon("tran-hung-dao", "Ngài chỉ huy trận Đông Bộ Đầu năm 1258 thế nào?")
    assert ds[0]["hang"] == "K"
    assert _ton_tai(ds, "không gán cho ông quyền chỉ huy trực tiếp")
    chu = su_lieu.dinh_dang(ds)
    assert chu.index("Hồ sơ nhân vật do nhóm biên soạn") < chu.index("Trích từ nguồn khác") \
        if "Trích từ nguồn khác" in chu else True
    assert "Hồ sơ nhân vật (nhóm HistoriAI biên soạn)" in su_lieu.nguon_da_dung(ds)


def test_quang_trung_ngay_xuat_quan_lay_tu_ho_so():
    ds = su_lieu.chon("quang-trung", "Ngài xuất quân ra Bắc ngày nào?")
    assert _ton_tai(ds, "Ngày 22 tháng 12 năm 1788, tại núi Bân")
