"""Bài học theo lộ trình: API chỉ trả bản đã duyệt, slug khớp seed, script nhập đúng định dạng."""
import json
import os
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402
from app.services import lo_trinh  # noqa: E402
from tools import nhap_lo_trinh as nhap  # noqa: E402

seed.run()
client = TestClient(app)

DATA = Path(__file__).resolve().parents[1] / "data"
SLUG_SEED = {e["slug"] for e in json.loads((DATA / "seed_data.json").read_text(encoding="utf-8"))["events"]}


def _su_kien(slug: str) -> dict:
    return {"slug": slug, "ten": slug, "ten_ngan": slug, "muc_tieu": "m", "boi_canh": ["b"],
            "kien_thuc": {"tieu_de": "Kế sách chủ chốt", "y": ["c"]},
            "dien_bien": ["d"], "ket_qua": ["e"], "cau_chot": "chốt"}


@pytest.fixture
def kho(tmp_path, monkeypatch):
    """Tệp lộ trình giả: một bản duyệt, một bản nháp, một bản ghi "true" dạng chuỗi."""
    tep = tmp_path / "lo_trinh.json"
    tep.write_text(json.dumps({"_ghi_chu": "x", "lo_trinh": [
        {"ma": "duyet", "ten": "Đã duyệt", "da_duyet": True, "nguon": "a.docx",
         "su_kien": [_su_kien("bach-dang-938")]},
        {"ma": "nhap", "ten": "Nháp", "da_duyet": False, "nguon": "b.docx",
         "su_kien": [_su_kien("lam-son-1428")]},
        {"ma": "chuoi", "ten": "Chuỗi", "da_duyet": "true", "nguon": "c.docx",
         "su_kien": [_su_kien("quang-trung-1789")]},
    ]}, ensure_ascii=False), encoding="utf-8")
    monkeypatch.setattr(lo_trinh, "TEP", tep)
    lo_trinh._kho.cache_clear()
    yield tep
    lo_trinh._kho.cache_clear()


def test_chi_tra_lo_trinh_da_duyet(kho):
    r = client.get("/api/v1/lo-trinh")
    assert r.status_code == 200
    assert [lt["ma"] for lt in r.json()] == ["duyet"]
    # Trường nội bộ không ra ngoài.
    assert "da_duyet" not in r.json()[0] and "nguon" not in r.json()[0]


def test_tep_hong_thi_tra_rong_khong_loi(kho):
    kho.write_text("{hỏng", encoding="utf-8")
    lo_trinh._kho.cache_clear()
    r = client.get("/api/v1/lo-trinh")
    assert r.status_code == 200 and r.json() == []


def test_tep_that_moi_slug_deu_co_trong_seed():
    """Cả bản nháp: nhóm đổi da_duyet là lên app ngay, slug sai thì bài học mồ côi."""
    tho = json.loads((DATA / "lo_trinh.json").read_text(encoding="utf-8"))
    slug = [sk["slug"] for lt in tho["lo_trinh"] for sk in lt["su_kien"]]
    assert slug
    assert set(slug) <= SLUG_SEED
    assert len(slug) == len(set(slug)), "một trận chỉ thuộc một lộ trình"


def test_api_that_tra_lo_trinh_bach_dang_dung_thu_tu():
    lo_trinh._kho.cache_clear()
    ds = client.get("/api/v1/lo-trinh").json()
    su_kien = {lt["ma"]: [sk["slug"] for sk in lt["su_kien"]] for lt in ds}
    assert su_kien["bach-dang-938__bach-dang-1288"] == [
        "bach-dang-938", "khang-chien-tong-981", "bach-dang-1288"]
    tren_events = {e["slug"] for e in client.get("/api/v1/events").json()}
    for lt in ds:
        for sk in lt["su_kien"]:
            assert sk["slug"] in tren_events
            assert sk["cau_chot"] and sk["muc_tieu"]
            if not sk["khoa"]:      # khách chỉ nhận đủ bài đầu; phần khoá xem test_khoa_premium.py
                assert sk["dien_bien"] and sk["kien_thuc"]["tieu_de"]


def test_api_that_chua_tra_ban_nhap():
    tho = json.loads((DATA / "lo_trinh.json").read_text(encoding="utf-8"))
    nhap_ma = {lt["ma"] for lt in tho["lo_trinh"] if lt["da_duyet"] is not True}
    lo_trinh._kho.cache_clear()
    tra = {lt["ma"] for lt in client.get("/api/v1/lo-trinh").json()}
    assert not (tra & nhap_ma)


# --- Script nhập (tools/nhap_lo_trinh.py) ---------------------------------------------

def _docx(tmp_path: Path, doan: list[str], ten: str = "lo_trinh.docx") -> Path:
    """Tệp .docx tối giản: chỉ word/document.xml, đủ cho script đọc."""
    W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    than = "".join(f"<w:p><w:r><w:t xml:space='preserve'>{escape(d)}</w:t></w:r></w:p>" for d in doan)
    duong = tmp_path / ten
    with zipfile.ZipFile(duong, "w") as z:
        z.writestr("word/document.xml", f"<w:document xmlns:w='{W}'><w:body>{than}</w:body></w:document>")
    return duong


def _tran(so: int, ten: str, c: str = "Kế sách chủ chốt") -> list[str]:
    return [
        f"{so}. {ten}",
        "a) Mục tiêu", "Trình bày được   diễn biến.",
        "b) Bối cảnh và cuộc xâm lược", "- Ý bối cảnh một.", "- Ý bối cảnh hai.",
        f"c) {c}", "- Ý kế sách.",
        "d) Diễn biến trận", "1. Bước một.", "2. Bước hai.",
        "e) Kết quả và câu chốt", "- Thắng lợi.", "- Câu chốt để nhớ: “Câu chốt của trận.”",
        "f) Quiz", "1. Câu hỏi quiz?", "A. x · B. y · C. z · D. t",
    ]


def test_doc_dung_dinh_dang_tai_lieu_nhom(tmp_path, monkeypatch):
    ra = tmp_path / "lo_trinh.json"
    duong = _docx(tmp_path, ["Lộ trình học: Thử", *_tran(1, "Trận Bạch Đằng năm 938"), "---",
                             *_tran(2, "Cuộc kháng chiến chống Tống năm 981", "Vì sao thắng?"),
                             "Đáp án quiz: …", "Trận Bạch Đằng năm 938", "| Câu | 1 |"])
    lt = nhap.nhap(duong, ra=ra)
    assert lt["ma"] == "bach-dang-938__khang-chien-tong-981"
    assert lt["ten"] == "Thử" and lt["da_duyet"] is True and lt["nguon"] == "lo_trinh.docx"
    a, b = lt["su_kien"]
    assert (a["slug"], a["ten_ngan"], b["slug"]) == ("bach-dang-938", "Bạch Đằng 938", "khang-chien-tong-981")
    assert a["muc_tieu"] == "Trình bày được diễn biến."            # chỉ cắt khoảng trắng
    assert a["boi_canh"] == ["Ý bối cảnh một.", "Ý bối cảnh hai."]
    assert b["kien_thuc"] == {"tieu_de": "Vì sao thắng?", "y": ["Ý kế sách."]}
    assert a["dien_bien"] == ["Bước một.", "Bước hai."]
    assert a["ket_qua"] == ["Thắng lợi."]                          # câu chốt tách riêng
    assert a["cau_chot"] == "Câu chốt của trận."                   # bỏ ngoặc kép
    assert "Câu hỏi quiz?" not in json.dumps(lt, ensure_ascii=False)  # quiz không nạp
    assert json.loads(ra.read_text(encoding="utf-8"))["lo_trinh"][0] == lt


def test_tran_khong_co_trong_bang_thi_bao_loi_khong_doan(tmp_path):
    duong = _docx(tmp_path, ["Lộ trình học: Thử", *_tran(1, "Trận Bạch Đằng 938")])  # thiếu "năm"
    with pytest.raises(nhap.LoiTaiLieu, match="chưa có trong bảng TRAN"):
        nhap.nhap(duong, ra=tmp_path / "ra.json")
    assert not (tmp_path / "ra.json").exists()


def test_thieu_muc_thi_bao_loi(tmp_path):
    doan = [d for d in _tran(1, "Trận Bạch Đằng năm 938") if "Câu chốt" not in d]
    with pytest.raises(nhap.LoiTaiLieu, match="Câu chốt"):
        nhap.nhap(_docx(tmp_path, ["Lộ trình học: Thử", *doan]), ra=tmp_path / "ra.json")


def test_ban_nhap_phai_co_co_chua_duyet(tmp_path):
    ra = tmp_path / "ra.json"
    duong = _docx(tmp_path, ["BẢN NHÁP do AI soạn — nhóm kiểm", "Lộ trình học: Nháp",
                             *_tran(1, "Khởi nghĩa Lam Sơn (1418–1427)")])
    with pytest.raises(nhap.LoiTaiLieu, match="BẢN NHÁP"):
        nhap.nhap(duong, ra=ra)
    lt = nhap.nhap(duong, chua_duyet=True, ra=ra)
    assert lt["da_duyet"] is False and lt["su_kien"][0]["slug"] == "lam-son-1428"


def test_chay_lai_thi_thay_dung_lo_trinh_giu_lo_trinh_khac(tmp_path):
    ra = tmp_path / "ra.json"
    bd = _docx(tmp_path, ["Lộ trình học: Bạch Đằng", *_tran(1, "Trận Bạch Đằng năm 938")], "bd.docx")
    ls = _docx(tmp_path, ["BẢN NHÁP", "Lộ trình học: Lam Sơn",
                          *_tran(1, "Khởi nghĩa Lam Sơn (1418–1427)")], "ls.docx")
    nhap.nhap(bd, ra=ra)
    nhap.nhap(ls, chua_duyet=True, ra=ra)
    nhap.nhap(bd, ra=ra)   # chạy lại: không đẻ thêm bản, không mất bản nháp
    ds = json.loads(ra.read_text(encoding="utf-8"))["lo_trinh"]
    assert [(lt["ma"], lt["da_duyet"]) for lt in ds] == [
        ("bach-dang-938__bach-dang-938", True), ("lam-son-1428__lam-son-1428", False)]


def test_mot_tran_khong_duoc_nam_o_hai_lo_trinh(tmp_path):
    ra = tmp_path / "ra.json"
    nhap.nhap(_docx(tmp_path, ["Lộ trình học: A", *_tran(1, "Trận Bạch Đằng năm 938")]), ra=ra)
    with pytest.raises(nhap.LoiTaiLieu, match="đã thuộc lộ trình"):
        nhap.nhap(_docx(tmp_path, ["Lộ trình học: B", *_tran(1, "Trận Bạch Đằng năm 938")]),
                  ma="khac", ra=ra)


def test_bang_ghep_chi_tro_toi_slug_co_trong_seed():
    assert {slug for slug, _ in nhap.TRAN.values()} <= SLUG_SEED
