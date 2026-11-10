"""Bản tin tuần cho phụ huynh — link gửi bố mẹ qua Zalo, mở không cần đăng nhập.

Góp ý gốc của một phụ huynh: "chưa biết rõ từng bài trong app liên quan đến phần
kiến thức nào con đang học trên lớp". Những điều không được hỏng:
  • link tự mang quyền xem → sửa một ký tự hay quá hạn là phải bị từ chối;
  • số liệu tuần khớp đúng bài con đã nộp, theo NGÀY GIỜ VIỆT NAM;
  • trang công khai → không lộ email, mọi chữ từ CSDL đều được escape.
"""
import os
import uuid
from datetime import datetime, timedelta, timezone
from urllib.parse import urlsplit

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db import seed  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.event import HistoricalEvent  # noqa: E402
from app.models.progress import UserProgress  # noqa: E402
from app.models.quiz import QuizQuestion  # noqa: E402
from app.models.quiz_attempt import QuizAttempt  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import ban_tin  # noqa: E402

seed.run()
client = TestClient(app)
MK = "12345678"
LINK = "/api/v1/me/ban-tin/link"


def _tk(ten: str = "Nguyễn Văn An"):
    email = f"bt{uuid.uuid4().hex[:8]}@test.com"
    client.post("/api/v1/auth/register", json={"email": email, "full_name": ten, "password": MK},
                headers={"X-Client-Id": uuid.uuid4().hex})
    ma = client.post("/api/v1/auth/login", data={"username": email, "password": MK}).json()["access_token"]
    db = SessionLocal()
    try:
        uid = db.query(User.id).filter(User.email == email).scalar()
    finally:
        db.close()
    return email, uid, {"Authorization": f"Bearer {ma}"}


def _cau(slug: str, n: int):
    """n câu đầu của một trận: [(id, đáp án đúng, một đáp án sai)]."""
    db = SessionLocal()
    try:
        e = db.query(HistoricalEvent).filter_by(slug=slug).one()
        ds = db.query(QuizQuestion).filter_by(event_id=e.id).order_by(QuizQuestion.id).limit(n).all()
        return [(q.id, q.correct_option.upper(), next(o for o in "ABCD" if o != q.correct_option.upper()))
                for q in ds]
    finally:
        db.close()


def _nop(h, cap):
    r = client.post("/api/v1/quiz/submit", headers=h,
                    json=[{"question_id": q, "selected_option": c} for q, c in cap])
    assert r.status_code == 200, r.text


def _duong_dan(h) -> str:
    r = client.post(LINK, headers=h)
    assert r.status_code == 200, r.text
    return urlsplit(r.json()["url"]).path


def _tinh(uid: int, bay_gio: datetime | None = None, day_du: bool = True) -> ban_tin.BanTin:
    """Mặc định tính bản ĐẦY ĐỦ: phần lớn test ở đây kiểm số liệu, không kiểm khoá Premium."""
    db = SessionLocal()
    try:
        return ban_tin.tinh_ban_tin(db, db.get(User, uid), bay_gio or datetime.now(timezone.utc),
                                    day_du=day_du)
    finally:
        db.close()


def _len_premium(uid: int, ngay: int = 30) -> None:
    db = SessionLocal()
    try:
        db.get(User, uid).premium_den = (datetime.now(timezone.utc) + timedelta(days=ngay)).replace(tzinfo=None)
        db.commit()
    finally:
        db.close()


def _lui_ngay(uid: int, ngay: int) -> None:
    """Đẩy mọi lượt làm bài hiện có của người này về `ngay` ngày trước."""
    db = SessionLocal()
    try:
        for a in db.query(QuizAttempt).filter(QuizAttempt.user_id == uid).all():
            a.created_at = (datetime.now(timezone.utc) - timedelta(days=ngay)).replace(tzinfo=None)
        db.commit()
    finally:
        db.close()


# ---------- link ----------

def test_link_mo_duoc_khong_can_dang_nhap_va_khong_lo_email():
    email, _, h = _tk()
    r = client.post(LINK, headers=h)
    assert r.status_code == 200
    url, het_han = r.json()["url"], datetime.fromisoformat(r.json()["het_han"])
    assert "/api/v1/ban-tin/" in url
    con_lai = het_han - datetime.now(timezone.utc)
    assert timedelta(days=13, hours=23) < con_lai <= timedelta(days=14), "hạn 14 ngày"

    trang = client.get(urlsplit(url).path)          # không gửi Authorization
    assert trang.status_code == 200
    assert trang.headers["content-type"].startswith("text/html")
    assert "no-store" in trang.headers["cache-control"]
    t = trang.text
    assert "Bản tin học Lịch sử tuần này của An" in t, "chỉ hiện tên gọi"
    assert "Nguyễn Văn" not in t
    assert email not in t and email.split("@")[0] not in t, "trang công khai không được lộ email"
    assert '<meta name="robots" content="noindex' in t and '<meta name="viewport"' in t
    assert "Bản tin do HistoriAI tạo từ bài con đã làm trong app." in t
    assert "https://historiai.org" in t
    assert f"Link có hạn tới {het_han.astimezone(ban_tin.GIO_VN):%d/%m/%Y}" in t


def test_tao_link_phai_dang_nhap():
    assert client.post(LINK).status_code == 401


def test_ma_sua_mot_ky_tu_bi_tu_choi():
    _, _, h = _tk()
    duong_dan = _duong_dan(h)
    goc, ma = duong_dan.rsplit("/", 1)
    assert client.get(duong_dan).status_code == 200
    dau = ma.index(".")
    # đầu mã, ký tự cuối phần thân (chứa bit đệm base64), đầu chữ ký, cuối chữ ký
    for i in (0, dau - 1, dau + 1, len(ma) - 1):
        thay = "A" if ma[i] != "A" else "B"
        sai = ma[:i] + thay + ma[i + 1:]
        r = client.get(f"{goc}/{sai}")
        assert r.status_code == 404, f"sửa ký tự {i} vẫn mở được"
        assert "Không mở được bản tin" in r.text
    for rac in ("abc", "a.b", ma + "x", ma.replace(".", ""), "đ" + ma[1:]):
        assert client.get(f"{goc}/{rac}").status_code == 404, rac


def test_ma_het_han_bi_tu_choi():
    _, uid, _ = _tk()
    bay_gio = datetime.now(timezone.utc)
    cu = ban_tin.tao_ma(uid, bay_gio - timedelta(minutes=1))
    r = client.get(f"/api/v1/ban-tin/{cu}")
    assert r.status_code == 410 and "đã hết hạn" in r.text
    moi = ban_tin.tao_ma(uid, bay_gio + ban_tin.HAN_LINK)
    assert ban_tin.doc_ma(moi, bay_gio)[0] == uid
    with pytest.raises(ban_tin.MaHetHan):
        ban_tin.doc_ma(moi, bay_gio + timedelta(days=15))
    # chữ ký đúng nhưng tài khoản không còn
    assert client.get(f"/api/v1/ban-tin/{ban_tin.tao_ma(10**9, bay_gio + timedelta(days=1))}").status_code == 404


# ---------- số liệu ----------

def test_so_lieu_tuan_dung_voi_bai_da_nop():
    _, uid, h = _tk()
    (q1, d1, s1), (q2, d2, s2), (q3, d3, s3), (q4, d4, _) = _cau("bach-dang-938", 4)
    (q5, d5, s5), = _cau("khang-chien-tong-981", 1)

    _nop(h, [(q1, d1), (q2, s2)])            # 10 ngày trước: q1 đúng, q2 sai
    _lui_ngay(uid, 10)
    _nop(h, [(q1, d1), (q2, d2), (q3, s3), (q4, d4)])   # tuần này, trận 938
    _nop(h, [(q5, s5)])                                  # tuần này, trận 981

    bt = _tinh(uid)
    assert (bt.so_tran, bt.so_cau, bt.so_dung, bt.ti_le) == (2, 5, 3, 60)
    assert bt.cau_moi_dung == 2, "q2 (sai từ trước, nay mới đúng) và q4; q1 đã đúng từ 10 ngày trước"
    assert bt.diem_moi == 20
    assert bt.streak == 1

    assert [t.slug for t in bt.cac_tran] == ["bach-dang-938", "khang-chien-tong-981"], "xếp theo năm"
    t938, t981 = bt.cac_tran
    assert (t938.dung, t938.tong, t981.dung, t981.tong) == (3, 4, 0, 1)
    db = SessionLocal()
    try:
        tt = {p.event_id: p.mastery for p in db.query(UserProgress).filter_by(user_id=uid)}
        e938 = db.query(HistoricalEvent).filter_by(slug="bach-dang-938").one()
        assert t938.thong_thao == tt[e938.id] > 0, "mức thông thạo hiện tại của trận"

        on = {c.cau_hoi: c for c in bt.on_lai}
        assert len(bt.on_lai) == 2
        for qid, dung in ((q3, d3), (q5, d5)):
            q = db.get(QuizQuestion, qid)
            assert on[q.question].dap_an == dung
            assert on[q.question].noi_dung_dap_an == getattr(q, f"option_{dung.lower()}")

        # Tuần sau: trận kế tiếp theo năm (sau 981) mà con chưa làm
        da_lam = {e938.id, db.query(HistoricalEvent.id).filter_by(slug="khang-chien-tong-981").scalar()}
        co_cau = {eid for (eid,) in db.query(QuizQuestion.event_id).distinct()}
        mong = min((e for e in db.query(HistoricalEvent).all()
                    if e.id in co_cau and e.id not in da_lam and e.year > 981), key=lambda e: e.year)
        assert bt.goi_y is not None and bt.goi_y.ten == mong.title and not bt.goi_y.la_on_lai
    finally:
        db.close()

    _len_premium(uid)
    t = client.get(_duong_dan(h)).text
    for chu in ("Tổng kết tuần", "Con đã học gì", "Cùng con ôn lại", "Tuần sau nên học",
                "đúng 3/4 câu", "+20 điểm"):
        assert chu in t, chu


def test_sai_roi_lam_dung_lai_khong_vao_on_lai():
    _, uid, h = _tk()
    (q1, d1, s1), (q2, d2, s2) = _cau("bach-dang-1288", 2)
    _nop(h, [(q1, s1)])
    _nop(h, [(q1, d1)])                 # ôn lại đúng → rời danh sách
    _nop(h, [(q2, s2)])
    _nop(h, [(q2, d2)])
    _nop(h, [(q2, s2)])                 # đúng rồi lại sai → vẫn phải ôn
    bt = _tinh(uid)
    db = SessionLocal()
    try:
        assert [c.cau_hoi for c in bt.on_lai] == [db.get(QuizQuestion, q2).question]
    finally:
        db.close()
    assert bt.cau_moi_dung == 2


def test_tuan_tinh_theo_gio_viet_nam():
    """Mở lúc 8 giờ sáng 21/10 (giờ VN) → tuần là 15/10–21/10, bắt đầu 0 giờ 15/10 giờ VN
    = 17 giờ 14/10 giờ UTC (CSDL lưu UTC)."""
    _, uid, _ = _tk()
    (q1, d1, _), (q2, d2, s2) = _cau("lam-son-1428", 2)
    bay_gio = datetime(2026, 10, 21, 1, 0, tzinfo=timezone.utc)
    db = SessionLocal()
    try:
        e = db.query(HistoricalEvent).filter_by(slug="lam-son-1428").one()
        for qid, chon, dung, luc in (
            (q1, d1, True, datetime(2026, 10, 14, 16, 59)),   # 23:59 ngày 14/10 giờ VN — ngoài tuần
            (q2, s2, False, datetime(2026, 10, 14, 17, 1)),   # 00:01 ngày 15/10 giờ VN — trong tuần
            (q2, d2, True, datetime(2026, 10, 21, 2, 0)),     # sau lúc mở link — chưa xảy ra
        ):
            db.add(QuizAttempt(user_id=uid, event_id=e.id, question_id=qid, selected_option=chon,
                               is_correct=dung, lan_nop="thu-gio", created_at=luc))
        db.commit()
    finally:
        db.close()
    bt = _tinh(uid, bay_gio)
    assert bt.tu_ngay.date().isoformat() == "2026-10-15" and bt.den_ngay.date().isoformat() == "2026-10-21"
    assert (bt.so_cau, bt.so_dung, bt.cau_moi_dung) == (1, 0, 0)
    assert len(bt.on_lai) == 1, "lần làm đúng sau lúc mở link không được tính"


def test_tuan_trong_van_co_trang_va_goi_y_bat_dau():
    _, uid, h = _tk()
    _len_premium(uid)
    r = client.get(_duong_dan(h))
    assert r.status_code == 200
    t = r.text
    assert "chưa làm bài nào" in t and "Gợi ý để bắt đầu" in t
    assert "Cùng con ôn lại" not in t and "Tổng kết tuần" not in t
    db = SessionLocal()
    try:
        co_cau = {eid for (eid,) in db.query(QuizQuestion.event_id).distinct()}
        dau = min((e for e in db.query(HistoricalEvent).all() if e.id in co_cau), key=lambda e: (e.year, e.id))
    finally:
        db.close()
    assert dau.title in t, "chưa làm trận nào → gợi ý trận sớm nhất"


def test_hoc_tren_lop_bo_dong_chuong_trinh_tach_hong():
    _, _, h = _tk()
    (q1, d1, _), = _cau("bach-dang-938", 1)
    db = SessionLocal()
    e = db.query(HistoricalEvent).filter_by(slug="bach-dang-938").one()
    cu = e.curriculum, e.grades
    try:
        e.curriculum = [
            {"ma": "THCS-6-07", "cap": "THCS", "lop": 6,
             "chu_de": "VIỆT NAM TỪ KHOẢNG THẾ KỈ VII TRƯỚC CÔNG NGUYÊN ĐẾN ĐẦU THẾ KỈ X"},
            {"ma": "THCS-8-04", "cap": "THCS", "lop": 8, "chu_de": "XVIII"},     # tách hỏng
        ]
        db.commit()
        _nop(h, [(q1, d1)])
        t = client.get(_duong_dan(h)).text
        assert "Học trên lớp: Lớp 6 – Việt Nam từ khoảng thế kỉ VII trước công nguyên đến đầu thế kỉ X" in t
        assert "Lớp 8" not in t and "XVIII" not in t
    finally:
        e.curriculum, e.grades = cu
        db.commit()
        db.close()


def test_chu_de_va_lop_tren_truong():
    assert ban_tin.chu_de_de_doc("VIỆT NAM TỪ ĐẦU THẾ KỈ X ĐẾN ĐẦU THẾ KỈ XVI") == \
        "Việt Nam từ đầu thế kỉ X đến đầu thế kỉ XVI"
    assert ban_tin.chu_de_de_doc("Chủ đề đã viết thường") == "Chủ đề đã viết thường"
    e = HistoricalEvent(curriculum=[
        {"lop": 7, "chu_de": "ĐẠI VIỆT THỜI LÊ SƠ"},
        {"lop": 7, "chu_de": "MỘT CHỦ ĐỀ KHÁC CỦA LỚP 7"},     # mỗi lớp một dòng
        {"lop": 10, "chu_de": "XV"},
        {"lop": 0, "chu_de": "THIẾU LỚP NÊN BỎ"},
    ], grades="7,10")
    assert ban_tin.lop_tren_truong(e) == [(7, "Đại Việt thời lê sơ")]
    assert ban_tin.lop_tren_truong(HistoricalEvent(curriculum=None, grades="11, 6")) == [(6, None), (11, None)]
    assert ban_tin.ten_goi("  Nguyễn   Văn An ") == "An" and ban_tin.ten_goi("") == "con"


# ---------- an toàn ----------

def test_chu_trong_csdl_duoc_escape():
    _, uid, h = _tk()
    db = SessionLocal()
    e = db.query(HistoricalEvent).filter_by(slug="quang-trung-1789").one()
    q = QuizQuestion(event_id=e.id, question='Câu <script>alert(2)</script> & "x"?',
                     option_a="<b>A</b>", option_b="Đáp <i>đúng</i>", option_c="C", option_d="D",
                     correct_option="B", explanation="<img src=x onerror=alert(3)>")
    db.add(q)
    u = db.get(User, uid)
    u.full_name = "Trần <script>alert(1)</script>"
    db.commit()
    try:
        _len_premium(uid)      # mục "Cùng con ôn lại" (chứa câu hỏi) chỉ hiện với Premium
        _nop(h, [(q.id, "A")])
        t = client.get(_duong_dan(h)).text
        assert "<script" not in t and "<img" not in t and "<i>" not in t
        assert "&lt;script&gt;alert(1)&lt;/script&gt;" in t, "tên gọi được escape"
        assert "Câu &lt;script&gt;alert(2)&lt;/script&gt; &amp; &quot;x&quot;?" in t
        assert "B. Đáp &lt;i&gt;đúng&lt;/i&gt;" in t
        assert "&lt;img src=x onerror=alert(3)&gt;" in t
    finally:
        db.query(QuizAttempt).filter(QuizAttempt.question_id == q.id).delete()
        db.delete(q)
        db.commit()
        db.close()


def test_trang_cong_khai_gioi_han_30_luot_moi_phut():
    for _ in range(30):
        assert client.get("/api/v1/ban-tin/khong-dung").status_code == 404
    r = client.get("/api/v1/ban-tin/khong-dung")
    assert r.status_code == 429 and r.headers.get("retry-after")
    assert r.headers["content-type"].startswith("text/html") and "chờ khoảng một phút" in r.text


# ---------- khoá theo Premium ----------

def _hai_cau_sai(h):
    """Trận 938: 1 câu đúng, 2 câu sai → bản tin có 2 câu cần ôn. Trả nội dung hai câu sai."""
    (q1, d1, _), (q2, _, s2), (q3, _, s3) = _cau("bach-dang-938", 3)
    _nop(h, [(q1, d1), (q2, s2), (q3, s3)])
    db = SessionLocal()
    try:
        return [db.get(QuizQuestion, q).question for q in (q2, q3)]
    finally:
        db.close()


def test_ban_tin_thuong_chi_co_so_cau_sai_khong_co_noi_dung():
    _, uid, h = _tk()
    cau_sai = _hai_cau_sai(h)
    t = client.get(_duong_dan(h)).text

    # Phần ai cũng có vẫn đủ.
    for chu in ("Tổng kết tuần", "Con đã học gì", "đúng 1/3 câu"):
        assert chu in t, chu
    # Hai mục Premium biến mất, thay bằng một khung nói SỐ THẬT.
    assert "Cùng con ôn lại" not in t and "Tuần sau nên học" not in t
    assert "Bản tin đầy đủ có thêm 2 câu con làm sai kèm đáp án và gợi ý bài tuần sau" in t
    assert "dành cho tài khoản Premium (39.000đ/tháng)" in t
    assert "Tài khoản → HistoriAI Premium" in t
    # Không lộ nội dung câu, đáp án, lời giải; không có nút/liên kết thanh toán.
    for c in cau_sai:
        assert c not in t
    assert "Đáp án đúng" not in t
    assert "<button" not in t and "thanh-toan" not in t
    assert t.count("<a ") == 1, "chỉ còn link historiai.org ở chân trang"
    # Số liệu tính ra cũng không chứa nội dung câu.
    bt = _tinh(uid, day_du=False)
    assert bt.on_lai == [] and bt.goi_y is None and bt.so_cau_sai == 2


def test_ban_tin_thuong_dem_het_cau_sai_khong_cat_o_nam():
    _, uid, h = _tk()
    qs = _cau("bach-dang-938", 7)
    _nop(h, [(q, s) for q, _, s in qs])             # sai cả 7 câu
    assert len(_tinh(uid, day_du=True).on_lai) == 5, "bản đủ vẫn giới hạn 5 câu như trước"
    assert "thêm 7 câu con làm sai" in client.get(_duong_dan(h)).text


def test_ban_tin_thuong_khong_co_cau_sai_thi_khung_chi_noi_goi_y():
    _, _, h = _tk()
    (q1, d1, _), = _cau("bach-dang-938", 1)
    _nop(h, [(q1, d1)])
    t = client.get(_duong_dan(h)).text
    assert "Bản tin đầy đủ có thêm gợi ý bài tuần sau — dành cho tài khoản Premium" in t
    assert "câu con làm sai" not in t


def test_ban_tin_tuan_trong_cua_nguoi_thuong_cung_co_khung():
    _, _, h = _tk()
    t = client.get(_duong_dan(h)).text
    assert "chưa làm bài nào" in t and "Gợi ý để bắt đầu" not in t
    assert "dành cho tài khoản Premium" in t


def test_ban_tin_premium_co_du_hai_muc():
    _, uid, h = _tk()
    cau_sai = _hai_cau_sai(h)
    _len_premium(uid)
    t = client.get(_duong_dan(h)).text
    assert "Cùng con ôn lại" in t and "Tuần sau nên học" in t
    for c in cau_sai:
        assert c in t
    assert "Đáp án đúng" in t
    assert "dành cho tài khoản Premium" not in t


def test_ban_tin_quan_tri_xem_du_nhu_premium():
    _, uid, h = _tk()
    _hai_cau_sai(h)
    db = SessionLocal()
    try:
        db.get(User, uid).role = "admin"
        db.commit()
    finally:
        db.close()
    t = client.get(_duong_dan(h)).text
    assert "Cùng con ôn lại" in t and "Tuần sau nên học" in t


def test_ban_tin_kiem_premium_luc_mo_link_khong_luc_tao_link():
    """Cùng một link: lúc con còn Premium mở ra đủ; hết hạn thì mở lại là khoá; mua lại thì mở."""
    _, uid, h = _tk()
    _hai_cau_sai(h)
    _len_premium(uid)
    duong_dan = _duong_dan(h)
    assert "Cùng con ôn lại" in client.get(duong_dan).text
    _len_premium(uid, ngay=-1)                      # hết hạn hôm qua
    t = client.get(duong_dan).text
    assert "Cùng con ôn lại" not in t and "thêm 2 câu con làm sai" in t
    _len_premium(uid, ngay=30)
    assert "Cùng con ôn lại" in client.get(duong_dan).text
