"""Bản tin tuần cho phụ huynh — học sinh bấm một nút, gửi link cho bố mẹ qua Zalo.

VÌ SAO
    Người dùng là học sinh, người trả tiền là phụ huynh. Góp ý của một phụ huynh:
    "chưa biết rõ từng bài trong app liên quan đến phần kiến thức nào con đang học
    trên lớp". Bản tin trả lời đúng câu đó: tuần này con làm trận nào, đúng bao
    nhiêu câu, câu nào còn sai, và trận đó ứng với lớp mấy, chủ đề gì trên trường.

LINK KHÔNG TRẠNG THÁI
    Phụ huynh không có tài khoản, nên link phải tự mang quyền xem. Mã = base64url
    của "user_id.het_han" + chữ ký HMAC-SHA256 bằng SECRET_KEY. Không cần bảng mới,
    không cần migrate. Đổi lại: không thu hồi riêng được một link — muốn chặn thì
    chờ hết hạn (14 ngày) hoặc đổi SECRET_KEY (đổi là mọi người phải đăng nhập lại).

PHẦN DÀNH CHO PREMIUM
    Tổng kết tuần, các trận đã học và "Học trên lớp" ai cũng có. Hai mục "Cùng con ôn
    lại" và "Tuần sau nên học" chỉ có khi tài khoản của con đang Premium (hoặc quản
    trị). Kiểm LÚC PHỤ HUYNH MỞ LINK, không lúc tạo link: Premium hết hạn là bản tin
    link cũ cũng khoá lại, vừa mua là link cũ mở đủ ngay. Với bản thường, máy chủ KHÔNG
    đưa nội dung câu sai hay tên trận gợi ý vào `BanTin` — chỉ đưa SỐ câu sai — nên
    không có đường nào lộ ra HTML dù ai sửa phần ghép.

SỐ LIỆU TÍNH LÚC MỞ LINK
    "7 ngày gần nhất" tính tới lúc phụ huynh MỞ link, không phải lúc con tạo link:
    tuần sau bố mẹ mở lại link cũ (còn hạn) là thấy tuần mới, khỏi xin link khác.
    Ngày theo giờ Việt Nam: bài làm lúc 6 giờ sáng không bị tính sang hôm trước chỉ
    vì CSDL lưu giờ UTC (xem services/ngay_hoc.py).

Phần này là hàm thuần (nhận `db`, `user`, `bay_gio`) để test được với giờ cố định.
Ghép HTML nằm ở routes/ban_tin.py.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import re
from dataclasses import dataclass, field
from datetime import datetime, time, timedelta, timezone

from sqlalchemy.orm import Session

from app.api.routes.quiz import XP_PER_CORRECT_BASE
from app.core.config import settings
from app.models.event import HistoricalEvent
from app.models.progress import UserProgress
from app.models.quiz import QuizQuestion
from app.models.quiz_attempt import QuizAttempt
from app.models.user import User
from app.services.ngay_hoc import GIO_VN, streak_hien_tai
from app.services.thanh_toan import duoc_xem_day_du

HAN_LINK = timedelta(days=14)
SO_NGAY = 7
TOI_DA_ON_LAI = 5
# Điểm cho mỗi câu mới đúng lần đầu — lấy thẳng hằng số của /quiz/submit để bản tin
# không bao giờ nói một số điểm khác với số app đã cộng.
DIEM_MOI_CAU = XP_PER_CORRECT_BASE

_UTC_SOM_NHAT = datetime.min.replace(tzinfo=timezone.utc)


# ---------------------------------------------------------------- mã trong link

class MaKhongHopLe(Exception):
    """Mã sai chữ ký, sai dạng, hoặc bị chép thiếu ký tự."""


class MaHetHan(Exception):
    """Mã đúng chữ ký nhưng đã quá hạn."""


def _b64(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode("ascii")


def _ky(phan_dau: str) -> str:
    # Ký trên CHUỖI base64 chứ không trên byte đã giải mã: bộ giải mã base64 của
    # Python bỏ qua ký tự lạ và bit đệm, nên hai chuỗi khác nhau có thể ra cùng một
    # byte — sửa một ký tự mà chữ ký vẫn khớp. Tiền tố "ban-tin|" tách hẳn chữ ký
    # này khỏi mọi chỗ khác dùng chung SECRET_KEY (mã đăng nhập JWT).
    tin = b"ban-tin|" + phan_dau.encode("ascii")
    return _b64(hmac.new(settings.SECRET_KEY.encode("utf-8"), tin, hashlib.sha256).digest())


def tao_ma(user_id: int, het_han: datetime) -> str:
    phan_dau = _b64(f"{int(user_id)}.{int(het_han.timestamp())}".encode("ascii"))
    return f"{phan_dau}.{_ky(phan_dau)}"


_DANG_THAN = re.compile(r"^(\d{1,12})\.(\d{1,12})$")


def doc_ma(ma: str, bay_gio: datetime) -> tuple[int, datetime]:
    """Trả (user_id, hạn). Ném MaKhongHopLe / MaHetHan."""
    if not ma or len(ma) > 200 or ma.count(".") != 1:
        raise MaKhongHopLe()
    phan_dau, chu_ky = ma.split(".")
    if not phan_dau or not chu_ky:
        raise MaKhongHopLe()
    # So bằng byte: compare_digest với str chỉ nhận ASCII, mà đường dẫn thì ai
    # cũng gõ được chữ có dấu vào.
    if not hmac.compare_digest(_ky_an_toan(phan_dau).encode(), chu_ky.encode("utf-8")):
        raise MaKhongHopLe()
    try:
        than = base64.urlsafe_b64decode(phan_dau + "=" * (-len(phan_dau) % 4)).decode("ascii")
    except (ValueError, UnicodeDecodeError) as e:
        raise MaKhongHopLe() from e
    m = _DANG_THAN.match(than)
    if not m:
        raise MaKhongHopLe()
    het_han = datetime.fromtimestamp(int(m[2]), timezone.utc)
    if het_han <= _aware(bay_gio):
        raise MaHetHan()
    return int(m[1]), het_han


def _ky_an_toan(phan_dau: str) -> str:
    try:
        return _ky(phan_dau)
    except UnicodeEncodeError:
        return ""          # chữ có dấu trong mã: chắc chắn sai, nhưng vẫn đi qua compare_digest


# ---------------------------------------------------------------- chữ hiển thị

def ten_goi(ho_ten: str | None) -> str:
    """Chỉ tên gọi (chữ cuối): "Nguyễn Văn An" → "An". Link có thể bị chuyển tiếp
    trong nhóm Zalo gia đình — không cần đủ họ tên, càng không cần email."""
    phan = (ho_ten or "").split()
    return phan[-1] if phan else "con"


# Tên riêng hay gặp trong tiêu đề chủ đề — giữ hoa sau khi hạ chữ thường.
# Cùng danh sách với `_viet` trong mobile/lib/features/timeline/event_detail_screen.dart.
_TEN_RIENG = ("việt nam", "đại việt", "đông nam á", "mông – nguyên", "lam sơn",
              "tây sơn", "biển đông", "hồ chí minh", "tổ quốc", "cách mạng tháng tám")
_THE_KI = re.compile(r"(thế k[ỉỷ]) ([ivxlc]+)\b")


def chu_de_de_doc(s: str) -> str:
    """Tiêu đề chủ đề trong văn bản chương trình viết HOA toàn bộ — đọc trên điện
    thoại rất nặng. Hạ về chữ thường kiểu câu, giữ hoa tên riêng và số La Mã sau
    "thế kỉ" (hạ xuống thì thành "thế kỉ xviii")."""
    s = s.strip()
    if s.upper() != s:
        return s
    t = s.lower()
    for r in _TEN_RIENG:
        t = t.replace(r, " ".join(w[:1].upper() + w[1:] for w in r.split(" ")))
    t = _THE_KI.sub(lambda m: f"{m[1]} {m[2].upper()}", t)
    return t[:1].upper() + t[1:]


def lop_tren_truong(e: HistoricalEvent) -> list[tuple[int, str | None]]:
    """[(lớp, chủ đề)] — mỗi lớp một dòng, theo chương trình GDPT 2018.

    Bỏ dòng đường ống tách hỏng từ PDF chương trình (chủ đề chỉ còn "XVIII"): dưới 3
    chữ là mảnh vụn, giống `HistoricalEvent.chuongTrinhHopLe` bên app. Không có chủ
    đề hợp lệ thì lùi về cột `grades` (chỉ biết lớp, không biết chủ đề).
    """
    theo_lop: dict[int, str] = {}
    for c in e.curriculum or []:
        if not isinstance(c, dict):
            continue
        try:
            lop = int(c.get("lop") or 0)
        except (TypeError, ValueError):
            continue
        chu_de = str(c.get("chu_de") or "").strip()
        if lop <= 0 or len(chu_de.split()) < 3:
            continue
        theo_lop.setdefault(lop, chu_de_de_doc(chu_de))
    if theo_lop:
        return sorted(theo_lop.items())
    lop_csv = {int(x) for x in (e.grades or "").split(",") if x.strip().isdigit()}
    return [(lop, None) for lop in sorted(lop_csv) if lop > 0]


# ---------------------------------------------------------------- số liệu tuần

@dataclass
class TranTrongTuan:
    slug: str
    ten: str
    nam: int
    lop: list[tuple[int, str | None]]
    dung: int
    tong: int
    thong_thao: int          # mức thông thạo HIỆN TẠI (0–100), không chỉ của tuần


@dataclass
class CauOnLai:
    cau_hoi: str
    dap_an: str              # "B"
    noi_dung_dap_an: str
    loi_giai: str | None
    ten_tran: str | None


@dataclass
class GoiY:
    ten: str
    nam: int
    lop: list[tuple[int, str | None]]
    la_on_lai: bool = False  # đã làm đủ mọi trận → gợi ý làm lại trận thông thạo thấp nhất


@dataclass
class BanTin:
    ten: str
    tu_ngay: datetime        # 0 giờ (giờ VN) ngày đầu khoảng
    den_ngay: datetime       # lúc mở link (giờ VN)
    so_tran: int = 0
    so_cau: int = 0
    so_dung: int = 0
    ti_le: int = 0
    streak: int = 0
    cau_moi_dung: int = 0
    diem_moi: int = 0
    cac_tran: list[TranTrongTuan] = field(default_factory=list)
    on_lai: list[CauOnLai] = field(default_factory=list)
    goi_y: GoiY | None = None
    day_du: bool = True      # False = bản thường: on_lai rỗng, goi_y None
    so_cau_sai: int = 0      # số câu cần ôn (kể cả khi on_lai bị giấu hoặc cắt ở 5)

    @property
    def trong(self) -> bool:
        return self.so_cau == 0


def _aware(dt: datetime | None) -> datetime | None:
    """SQLite trả datetime không múi giờ (đã là UTC) — gắn UTC để so được."""
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _luc(a: QuizAttempt) -> datetime:
    return _aware(a.created_at) or _UTC_SOM_NHAT


def tinh_ban_tin(db: Session, user: User, bay_gio: datetime,
                 day_du: bool | None = None) -> BanTin:
    """`day_du=None` → tự xem tài khoản có Premium/quản trị tại `bay_gio` không. Mặc định
    là KHOÁ: quên truyền thì thiếu mục, chứ không lộ mục."""
    bay_gio = _aware(bay_gio)
    if day_du is None:
        day_du = duoc_xem_day_du(user, bay_gio)
    nay_vn = bay_gio.astimezone(GIO_VN)
    moc = datetime.combine(nay_vn.date() - timedelta(days=SO_NGAY - 1), time.min, tzinfo=GIO_VN)
    bt = BanTin(ten=ten_goi(user.full_name), tu_ngay=moc, den_ngay=nay_vn,
                streak=streak_hien_tai(user, nay_vn.date()), day_du=day_du)

    # Cả lịch sử (không chỉ tuần này): "đúng lần đầu" và "đã làm đúng lại chưa" phải
    # nhìn cả những lượt trước tuần. Một học sinh có vài trăm dòng — đọc hết là nhẹ.
    lich_su = sorted(
        (a for a in db.query(QuizAttempt).filter(QuizAttempt.user_id == user.id).all()
         if _luc(a) <= bay_gio),
        key=lambda a: (_luc(a), a.id),
    )
    tuan = [a for a in lich_su if _luc(a) >= moc]

    su_kien = {e.id: e for e in db.query(HistoricalEvent).all()}

    if tuan:
        bt.so_cau = len(tuan)
        bt.so_dung = sum(1 for a in tuan if a.is_correct)
        bt.ti_le = round(bt.so_dung * 100 / bt.so_cau)
        bt.so_tran = len({a.event_id for a in tuan})

        # Câu mới đúng lần đầu = lần đúng ĐẦU TIÊN rơi vào tuần này. Cùng luật cộng
        # điểm của /quiz/submit: điểm chỉ cộng cho lần đầu đúng mỗi câu.
        dung_dau: dict[int, datetime] = {}
        for a in lich_su:
            if a.is_correct and a.question_id not in dung_dau:
                dung_dau[a.question_id] = _luc(a)
        bt.cau_moi_dung = sum(1 for t in dung_dau.values() if t >= moc)
        bt.diem_moi = bt.cau_moi_dung * DIEM_MOI_CAU

        thong_thao = {
            p.event_id: p.mastery or 0
            for p in db.query(UserProgress).filter(UserProgress.user_id == user.id).all()
        }
        theo_tran: dict[int, list[QuizAttempt]] = {}
        for a in tuan:
            theo_tran.setdefault(a.event_id, []).append(a)
        for eid, ds in theo_tran.items():
            e = su_kien.get(eid)
            if e is None:
                continue
            bt.cac_tran.append(TranTrongTuan(
                slug=e.slug, ten=e.title, nam=e.year, lop=lop_tren_truong(e),
                dung=sum(1 for a in ds if a.is_correct), tong=len(ds),
                thong_thao=int(thong_thao.get(eid, 0)),
            ))
        bt.cac_tran.sort(key=lambda t: t.nam)

        # "Cùng con ôn lại": sai trong tuần mà SAU ĐÓ chưa làm đúng lại — tức lần làm
        # gần nhất của câu đó còn sai, và lần đó nằm trong tuần.
        cuoi: dict[int, QuizAttempt] = {}
        for a in lich_su:
            cuoi[a.question_id] = a
        sai = sorted((a for a in cuoi.values() if not a.is_correct and _luc(a) >= moc),
                     key=lambda a: (_luc(a), a.id), reverse=True)
        cau = {q.id: q for q in db.query(QuizQuestion).filter(
            QuizQuestion.id.in_([a.question_id for a in sai])).all()} if sai else {}
        # Đếm trên mọi câu còn trong kho (không cắt ở 5): khung Premium báo SỐ THẬT.
        bt.so_cau_sai = sum(1 for a in sai if a.question_id in cau)
        for a in sai:
            if not day_du:             # bản thường chỉ biết số, không đọc nội dung câu
                break
            q = cau.get(a.question_id)
            if q is None:              # câu đã bị gỡ khỏi kho
                continue
            dap = (q.correct_option or "").strip().upper()[:1]
            bt.on_lai.append(CauOnLai(
                cau_hoi=q.question,
                dap_an=dap,
                noi_dung_dap_an=getattr(q, f"option_{dap.lower()}") if dap in ("A", "B", "C", "D") else "",
                loi_giai=(q.explanation or "").strip() or None,
                ten_tran=su_kien[q.event_id].title if q.event_id in su_kien else None,
            ))
            if len(bt.on_lai) >= TOI_DA_ON_LAI:
                break

    if day_du:
        bt.goi_y = _goi_y(db, su_kien, lich_su, tuan, user)
    return bt


def _goi_y(db: Session, su_kien: dict[int, HistoricalEvent], lich_su: list[QuizAttempt],
           tuan: list[QuizAttempt], user: User) -> GoiY | None:
    """Trận kế tiếp theo năm mà con chưa làm quiz.

    Mốc là trận muộn nhất con làm trong tuần (tuần trống thì trận muộn nhất từng
    làm): học theo dòng thời gian, đi tiếp về sau. Hết trận phía sau thì quay về
    trận sớm nhất còn chưa làm. Chưa làm trận nào → trận sớm nhất, để bắt đầu.
    Chỉ tính trận có câu hỏi — gợi ý một trận không có quiz là gợi ý suông.
    """
    co_cau = {eid for (eid,) in db.query(QuizQuestion.event_id).distinct().all()}
    cac_tran = sorted((e for e in su_kien.values() if e.id in co_cau), key=lambda e: (e.year, e.id))
    if not cac_tran:
        return None
    da_lam = {a.event_id for a in lich_su}
    nam_cua = {e.id: e.year for e in cac_tran}
    neo_tu = [nam_cua[a.event_id] for a in (tuan or lich_su) if a.event_id in nam_cua]
    neo = max(neo_tu) if neo_tu else None

    chua_lam = [e for e in cac_tran if e.id not in da_lam]
    if chua_lam:
        phia_sau = [e for e in chua_lam if neo is None or e.year > neo]
        e = (phia_sau or chua_lam)[0]
        return GoiY(ten=e.title, nam=e.year, lop=lop_tren_truong(e))

    # Đã làm đủ mọi trận: gợi ý làm lại trận thông thạo thấp nhất (chưa đạt 100%).
    thong_thao = {p.event_id: p.mastery or 0 for p in db.query(UserProgress)
                  .filter(UserProgress.user_id == user.id).all()}
    con_thieu = [e for e in cac_tran if thong_thao.get(e.id, 0) < 100]
    if not con_thieu:
        return None
    e = min(con_thieu, key=lambda e: (thong_thao.get(e.id, 0), e.year))
    return GoiY(ten=e.title, nam=e.year, lop=lop_tren_truong(e), la_on_lai=True)
