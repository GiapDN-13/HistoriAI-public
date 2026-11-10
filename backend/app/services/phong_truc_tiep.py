"""Chế độ TRỰC TIẾP của phòng kiểm tra (giai đoạn 2, kiểu Kahoot).

LUỒNG
    cho ──bat_dau──▶ dang_hoi(câu 0) ──ket_thuc_cau / hết giờ / cả lớp đã trả lời──▶ lo_dap_an
         lo_dap_an ──cau_tiep──▶ dang_hoi(câu i+1) … câu cuối ──cau_tiep──▶ ket_thuc
    Bất kỳ lúc nào: ket_thuc (giáo viên dừng sớm, hoặc đóng phòng bằng route giai đoạn 1).

TRẠNG THÁI Ở ĐÂU
    CSDL (PhongThi.pha / cau_hien_tai / cau_bat_dau_luc + BaiThi.tra_loi) là NGUỒN THẬT.
    Bộ nhớ tiến trình chỉ giữ thứ mất đi cũng không sao: danh sách WebSocket đang nối và
    hẹn giờ tự kết thúc câu. Máy chủ khởi động lại giữa câu → máy các em tự nối lại →
    `kiem_het_gio` thấy câu đã quá giờ thì khoá câu, chưa quá thì đặt lại hẹn giờ phần
    còn lại. Chạy MỘT tiến trình uvicorn nên không cần Redis; chạy nhiều tiến trình thì
    phần phát tin (không phải phần dữ liệu) sẽ sai — ghi ở đây để ai mở rộng biết.

ĐIỂM TỐC ĐỘ (công thức như Kahoot)
    Đúng:  diem = round(1000 × (1 − t / (2T)))   t = mili-giây từ lúc câu mở tới lúc máy
           chủ NHẬN câu trả lời (kẹp trong [0, T]), T = giay_moi_cau × 1000.
           → đúng ngay lập tức ≈ 1000 điểm, đúng ở giây cuối = 500 điểm.
    Sai / bỏ trống / hết giờ: 0 điểm.
    Đo t ở máy chủ chứ không tin đồng hồ máy em (đồng hồ điện thoại lệch cả giây, lại
    sửa được). Em mạng chậm thiệt vài chục điểm — chấp nhận được, công bằng hơn tin máy.

KHÔNG LỘ ĐÁP ÁN
    Gói tin cho học sinh chỉ có `dap_an`, `phan_bo`, đúng/sai của em khi pha đã là
    lo_dap_an / ket_thuc. Test chặn hồi quy: tests/test_lop_hoc_truc_tiep.py.
"""
from __future__ import annotations

import asyncio
import json
import logging
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

from fastapi import WebSocket
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.api.routes.quiz import XP_PER_CORRECT_BASE, _calc_level
from app.db.session import SessionLocal
from app.models.lop_hoc import BaiThi, DeKiemTra, PhongThi
from app.services.cau_trong_de import nap_cau
from app.models.quiz_attempt import QuizAttempt
from app.models.user import User
from app.services.ngay_hoc import ghi_ngay_hoc

log = logging.getLogger(__name__)

# Chờ thêm sau khi đồng hồ về 0 rồi mới khoá câu: gói tin của em bấm ở giây cuối còn
# đang trên đường qua Cloudflare. Không có khoảng này thì em bấm "kịp" vẫn bị tính trễ.
GIAY_CHO_TRE = 1.0
DIEM_TOI_DA = 1000
TOP = 5
LENH = ("bat_dau", "ket_thuc_cau", "cau_tiep", "ket_thuc")


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: datetime | None) -> datetime | None:
    if dt is not None and dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


class LoiTrucTiep(Exception):
    """Lỗi nghiệp vụ — route đổi thành HTTP 4xx, WebSocket đổi thành gói {"loai": "loi"}."""

    def __init__(self, ma_http: int, thong_bao: str):
        super().__init__(thong_bao)
        self.ma_http = ma_http
        self.thong_bao = thong_bao


def diem_toc_do(dung: bool, ms: int, giay_moi_cau: int) -> int:
    if not dung:
        return 0
    tong = max(1, giay_moi_cau * 1000)
    ms = min(max(ms, 0), tong)
    return round(DIEM_TOI_DA * (1 - ms / (2 * tong)))


# ================================================================ phần đồng bộ (CSDL)
# Mọi hàm dưới đây nhận Session, chạy trong luồng phụ (run_in_threadpool) để không chặn
# vòng lặp sự kiện đang giữ 40 WebSocket.

def _doc_cau(db: Session, ids: list[int]) -> dict[int, object]:
    """MỌI chỗ đọc câu hỏi của đề trong chế độ trực tiếp đi qua đây. Trả {id: câu} — câu
    có question, option_a..d, correct_option, explanation, event_id.

    Để một chỗ vì giai đoạn 3 thêm câu RIÊNG của giáo viên (id ÂM trong cau_ids, đọc bằng
    app/services/cau_trong_de.nap_cau): khi gộp chỉ cần trỏ hàm này sang nap_cau."""
    # Gộp 28/09: trỏ sang nap_cau — câu riêng của giáo viên (id âm) thi trực tiếp được.
    return nap_cau(db, ids)


def _lay(db: Session, ma: str) -> tuple[PhongThi, DeKiemTra]:
    p = db.query(PhongThi).filter(PhongThi.ma == ma).first()
    if p is None or p.che_do != "truc_tiep":
        raise LoiTrucTiep(404, "Không có phòng thi trực tiếp nào mang mã này.")
    return p, db.get(DeKiemTra, p.de_id)


def _han(p: PhongThi, d: DeKiemTra) -> datetime | None:
    """Mốc khoá câu đang hỏi (đã cộng khoảng chờ trễ)."""
    bd = _aware(p.cau_bat_dau_luc)
    if p.pha != "dang_hoi" or bd is None:
        return None
    return bd + timedelta(seconds=d.giay_moi_cau + GIAY_CHO_TRE)


def _tong_diem(b: BaiThi) -> int:
    return sum(int(v.get("diem") or 0) for v in (b.tra_loi or {}).values())


def _xep_hang(bai: list[BaiThi]) -> list[dict]:
    """Điểm cao trước; bằng điểm thì ai tổng thời gian trả lời ĐÚNG ít hơn đứng trên.
    Bằng cả hai thì cùng hạng (xếp hạng kiểu thi đấu 1, 2, 2, 4)."""
    dong = []
    for b in bai:
        tl = (b.tra_loi or {}).values()
        dong.append({"user_id": b.user_id, "ten": b.ten_hien, "lop": b.lop, "diem": _tong_diem(b),
                     "so_dung": sum(1 for v in tl if v.get("dung")),
                     "_ms": sum(int(v.get("ms") or 0) for v in tl if v.get("dung"))})
    dong.sort(key=lambda h: (-h["diem"], h["_ms"], h["ten"].lower()))
    for i, h in enumerate(dong):
        truoc = dong[i - 1] if i else None
        h["hang"] = truoc["hang"] if truoc and (truoc["diem"], truoc["_ms"]) == (h["diem"], h["_ms"]) else i + 1
    for h in dong:
        del h["_ms"]
    return dong


def _ket_thuc_tran(db: Session, p: PhongThi, d: DeKiemTra) -> None:
    """Hết trận: nộp bài cho mọi em + ghi lịch sử học, rồi đóng phòng.

    Cùng luật với nop_bai của giai đoạn 1 (routes/lop_hoc.py) — sửa bên này nhớ xem bên
    kia: mỗi câu đã trả lời thành một QuizAttempt (vào "Lịch sử học", câu sai vào "Ôn câu
    sai"), XP chỉ cộng cho câu đúng LẦN ĐẦU, lan_nop = "phong-<mã>".
    """
    bay_gio = _utcnow()
    cau = _doc_cau(db, d.cau_ids)
    for b in db.query(BaiThi).filter(BaiThi.phong_id == p.id, BaiThi.nop_luc.is_(None)).all():
        b.nop_luc = bay_gio
        tl = b.tra_loi or {}
        if not tl:
            continue
        user = db.get(User, b.user_id)
        if user is None:
            continue
        da_dung = {qid for (qid,) in db.query(QuizAttempt.question_id).filter(
            QuizAttempt.user_id == user.id, QuizAttempt.is_correct.is_(True),
            QuizAttempt.question_id.in_(b.thu_tu)).distinct().all()}
        xp = 0
        for qid in b.thu_tu:
            v = tl.get(str(qid))
            # id âm = câu riêng của giáo viên (giai đoạn 3): không thuộc kho chung → không
            # ghi QuizAttempt, không cộng XP (vẫn tính điểm trận và vào bảng CSV).
            if v is None or qid < 0 or qid not in cau:
                continue
            db.add(QuizAttempt(user_id=user.id, event_id=cau[qid].event_id, question_id=qid,
                               selected_option=(v.get("chon") or "")[:1], is_correct=bool(v.get("dung")),
                               lan_nop=f"phong-{p.ma}"))
            if v.get("dung") and qid not in da_dung:
                xp += XP_PER_CORRECT_BASE
        if xp:
            user.xp = (user.xp or 0) + xp
            user.level = _calc_level(user.xp)
        ghi_ngay_hoc(user)
    p.pha = "ket_thuc"
    p.cau_bat_dau_luc = None
    if p.dang_mo:
        p.dang_mo = False
        p.dong_luc = bay_gio


def kiem_het_gio(db: Session, ma: str, bay_gio: datetime | None = None) -> bool:
    """Tự chuyển pha khi đồng hồ đã quyết định thay giáo viên. True = có đổi (cần phát tin).

    Gọi ở MỌI lối đọc trạng thái (WebSocket nối, hỏi lại định kỳ, hẹn giờ) — nhờ vậy dù
    hẹn giờ trong bộ nhớ mất vì máy chủ khởi động lại, câu vẫn khoá đúng lúc."""
    p, d = _lay(db, ma)
    bay_gio = bay_gio or _utcnow()
    han = _han(p, d)
    if han is not None and bay_gio >= han:
        p.pha = "lo_dap_an"
        db.commit()
        return True
    # Giáo viên đóng phòng bằng nút giai đoạn 1 giữa trận → coi như kết thúc
    if p.pha != "ket_thuc" and not p.dang_mo:
        _ket_thuc_tran(db, p, d)
        db.commit()
        return True
    return False


def dieu_khien(db: Session, ma: str, gv_id: int, lenh: str, tu_cau: int | None) -> bool:
    """Lệnh của giáo viên. `tu_cau` = câu giáo viên ĐANG THẤY khi bấm: bấm đúp "Câu tiếp",
    hay hai máy (điện thoại + máy chiếu) cùng bấm, chỉ chuyển một câu chứ không nhảy hai.
    Trả True nếu trạng thái đổi."""
    p, d = _lay(db, ma)
    if p.giao_vien_id != gv_id:
        raise LoiTrucTiep(404, "Không tìm thấy phòng.")
    if lenh not in LENH:
        raise LoiTrucTiep(422, "Lệnh không hợp lệ.")
    kiem_het_gio(db, ma)
    n = len(d.cau_ids or [])
    if tu_cau is not None and p.cau_hien_tai is not None and tu_cau != p.cau_hien_tai:
        return False                       # lệnh cũ — màn giáo viên đang chậm một nhịp
    doi = False
    if lenh == "bat_dau" and p.pha == "cho":
        if n == 0:
            raise LoiTrucTiep(409, "Đề không có câu nào.")
        p.pha, p.cau_hien_tai, p.cau_bat_dau_luc = "dang_hoi", 0, _utcnow()
        doi = True
    elif lenh == "ket_thuc_cau" and p.pha == "dang_hoi":
        p.pha = "lo_dap_an"
        doi = True
    elif lenh == "cau_tiep" and p.pha == "lo_dap_an":
        if (p.cau_hien_tai or 0) + 1 < n:
            p.pha, p.cau_hien_tai, p.cau_bat_dau_luc = "dang_hoi", (p.cau_hien_tai or 0) + 1, _utcnow()
        else:
            _ket_thuc_tran(db, p, d)
        doi = True
    elif lenh == "ket_thuc" and p.pha != "ket_thuc":
        _ket_thuc_tran(db, p, d)
        doi = True
    if doi:
        db.commit()
    return doi


def tra_loi(db: Session, ma: str, user_id: int, cau_so: int, chon: str,
            bay_gio: datetime | None = None) -> dict:
    """Học sinh chọn đáp án cho câu đang hỏi. Mỗi câu một lần (như giai đoạn 1).

    Trả {"chon", "so_da_tra_loi", "so_hoc_sinh", "ca_lop_xong"} — KHÔNG có đúng/sai:
    em chỉ biết khi giáo viên lộ đáp án, như Kahoot (không thì em bấm xong quay sang mách
    bạn)."""
    bay_gio = bay_gio or _utcnow()
    p, d = _lay(db, ma)
    if chon not in ("A", "B", "C", "D"):
        raise LoiTrucTiep(422, "Đáp án phải là A, B, C hoặc D.")
    han = _han(p, d)
    if p.pha != "dang_hoi" or p.cau_hien_tai != cau_so:
        raise LoiTrucTiep(409, "Câu này đã đóng.")
    if han is None or bay_gio >= han:
        raise LoiTrucTiep(409, "Hết giờ mất rồi.")
    b = db.query(BaiThi).filter(BaiThi.phong_id == p.id, BaiThi.user_id == user_id).first()
    if b is None:
        raise LoiTrucTiep(403, "Em chưa vào phòng này.")
    qid = d.cau_ids[cau_so]
    tl = dict(b.tra_loi or {})
    if str(qid) not in tl:
        q = _doc_cau(db, [qid]).get(qid)
        ms = int((bay_gio - _aware(p.cau_bat_dau_luc)).total_seconds() * 1000)
        dung = q is not None and q.correct_option.upper() == chon
        tl[str(qid)] = {"chon": chon, "dung": dung, "ms": max(ms, 0),
                        "diem": diem_toc_do(dung, ms, d.giay_moi_cau)}
        b.tra_loi = tl                          # gán lại để SQLAlchemy biết cột JSON đã đổi
        b.so_dung = sum(1 for v in tl.values() if v.get("dung"))
        db.commit()
    so_da, so_hs = _dem_tra_loi(db, p, qid)
    return {"chon": tl[str(qid)]["chon"], "so_da_tra_loi": so_da, "so_hoc_sinh": so_hs,
            "ca_lop_xong": so_hs > 0 and so_da >= so_hs}


def _dem_tra_loi(db: Session, p: PhongThi, qid: int) -> tuple[int, int]:
    bai = db.query(BaiThi.tra_loi).filter(BaiThi.phong_id == p.id).all()
    return sum(1 for (tl,) in bai if str(qid) in (tl or {})), len(bai)


@dataclass
class Anh:
    """Ảnh chụp trạng thái một phòng: phần chung + phần riêng từng học sinh.
    Dựng MỘT lần rồi cắt cho từng người nhận — 40 em không phải 40 lượt đọc CSDL."""
    chung: dict
    gv: dict
    hs: dict[int, dict] = field(default_factory=dict)

    def cho_gv(self) -> dict:
        return {**self.chung, **self.gv, "vai": "gv"}

    def cho_hs(self, user_id: int) -> dict:
        return {**self.chung, "vai": "hs", "cua_toi": self.hs.get(user_id)}


def chup(db: Session, ma: str, bay_gio: datetime | None = None) -> Anh:
    bay_gio = bay_gio or _utcnow()
    p, d = _lay(db, ma)
    n = len(d.cau_ids or [])
    bai = db.query(BaiThi).filter(BaiThi.phong_id == p.id).order_by(BaiThi.id).all()
    lo = p.pha in ("lo_dap_an", "ket_thuc")
    chung: dict = {"loai": "trang_thai", "ma": p.ma, "tieu_de": d.tieu_de, "pha": p.pha,
                   "cau_so": p.cau_hien_tai, "tong_cau": n, "giay_moi_cau": d.giay_moi_cau,
                   "so_hoc_sinh": len(bai), "t_phat": int(time.time() * 1000),
                   # Số thứ tự của ảnh (micro-giây lúc chụp). Hai gói có thể tới lệch thứ tự
                   # (một gói phát cho cả lớp, một gói trả riêng cho máy vừa nối lại) → app
                   # bỏ gói có `phien` nhỏ hơn gói đã hiện, khỏi nháy về câu cũ.
                   "phien": time.time_ns() // 1000}
    q, qid = None, None
    if p.cau_hien_tai is not None and p.cau_hien_tai < n and p.pha in ("dang_hoi", "lo_dap_an"):
        qid = d.cau_ids[p.cau_hien_tai]       # id THEO ĐỀ (câu riêng GĐ3 mang id âm) — khoá của tra_loi
        q = _doc_cau(db, [qid]).get(qid)
    if q is not None:
        chung["cau"] = {"id": qid, "question": q.question,
                        "options": {"A": q.option_a, "B": q.option_b, "C": q.option_c, "D": q.option_d}}
        chon = [(b.tra_loi or {}).get(str(qid)) for b in bai]
        chung["so_da_tra_loi"] = sum(1 for v in chon if v)
        han = _han(p, d)
        if han is not None:
            # Gửi SỐ MI-GIÂY CÒN LẠI thay vì giờ tuyệt đối: đồng hồ máy em lệch vẫn đếm đúng.
            con = (han - bay_gio).total_seconds() - GIAY_CHO_TRE
            chung["con_lai_ms"] = max(0, int(con * 1000))
        if lo:
            phan_bo = {"A": 0, "B": 0, "C": 0, "D": 0}
            for v in chon:
                if v and v.get("chon") in phan_bo:
                    phan_bo[v["chon"]] += 1
            chung.update(dap_an=q.correct_option.upper(), phan_bo=phan_bo, giai_thich=q.explanation)
    hang = _xep_hang(bai)
    from app.services.anh_tai_len import cua_nhieu_nguoi
    anh = cua_nhieu_nguoi(db, [h["user_id"] for h in hang]) if lo else {}
    def _dong(h):
        return {**{k: h[k] for k in ("ten", "lop", "diem", "hang", "so_dung")},
                **anh.get(h["user_id"], {"avatar": None, "avatar_url": None})}
    if lo:
        chung["top"] = [_dong(h) for h in hang[:TOP]]
    from app.api.routes.lop_hoc import _link     # nhập muộn: routes/lop_hoc nạp sau service này
    gv = {"link": _link(p.ma),
          "hoc_sinh": [{"user_id": b.user_id, "ten": b.ten_hien, "lop": b.lop} for b in bai]}
    if p.pha == "ket_thuc":
        gv["bang_xep_hang"] = [_dong(h) for h in hang]
    theo_id = {h["user_id"]: h for h in hang}
    hs: dict[int, dict] = {}
    for b in bai:
        v = (b.tra_loi or {}).get(str(qid)) if q is not None else None
        rieng: dict = {"ten": b.ten_hien, "da_chon": v.get("chon") if v else None}
        if lo:
            h = theo_id[b.user_id]
            rieng.update(tong_diem=h["diem"], hang=h["hang"], so_dung=h["so_dung"],
                         dung=bool(v and v.get("dung")) if q is not None else None,
                         diem_cau=int(v.get("diem") or 0) if v else 0)
        hs[b.user_id] = rieng
    return Anh(chung=chung, gv=gv, hs=hs)


def kiem_va_chup(db: Session, ma: str) -> tuple[bool, Anh]:
    doi = kiem_het_gio(db, ma)
    return doi, chup(db, ma)


def xac_thuc(db: Session, ma: str, token: str | None) -> tuple[int, str, dict | None]:
    """Mã đăng nhập → (user_id, vai "gv"|"hs", payload). Kiểm đủ ba lớp như route REST
    (chữ ký + hạn, sổ thu hồi, đời mã) — dùng lại đúng hàm của app/api/deps.py."""
    from app.api.deps import _nguoi_dung_tu_ma
    kq = _nguoi_dung_tu_ma(token, db) if token else None
    if kq is None:
        raise LoiTrucTiep(401, "Phiên đăng nhập đã hết hạn. Hãy vào lại phòng.")
    user, payload = kq
    return user.id, vai_cua(db, ma, user.id), payload


def vai_cua(db: Session, ma: str, user_id: int) -> str:
    """Giáo viên chủ phòng → "gv"; em đã vào phòng (qua POST /phong/{ma}/vao) → "hs"."""
    p, _ = _lay(db, ma)
    if p.giao_vien_id == user_id:
        return "gv"
    if db.query(BaiThi.id).filter(BaiThi.phong_id == p.id, BaiThi.user_id == user_id).first():
        return "hs"
    raise LoiTrucTiep(403, "Em chưa vào phòng này.")


def _voi_db(ham, *args, **kw):
    """Chạy một hàm nghiệp vụ trên phiên CSDL riêng (mỗi luồng phụ một phiên)."""
    db = SessionLocal()
    try:
        return ham(db, *args, **kw)
    finally:
        db.close()


async def chay(ham, *args, **kw):
    return await run_in_threadpool(_voi_db, ham, *args, **kw)


# ================================================================ phần bất đồng bộ (kết nối)

@dataclass(eq=False)          # so sánh theo danh tính → bỏ được vào set
class KetNoi:
    ws: WebSocket
    user_id: int
    vai: str
    token: str
    kiem_luc: float = field(default_factory=time.monotonic)


class Phong:
    """Những gì CHỈ sống trong bộ nhớ cho một phòng: kết nối, hẹn giờ, khoá."""

    def __init__(self, ma: str):
        self.ma = ma
        self.ket_noi: set[KetNoi] = set()
        self.khoa = asyncio.Lock()     # tuần tự hoá thay đổi trạng thái của MỘT phòng
        self.hen: asyncio.Task | None = None
        self.hen_cho: tuple | None = None          # (pha, cau_so) mà hẹn giờ đang canh
        self.bao_gv: asyncio.Task | None = None
        # (lúc chụp, ảnh) gần nhất — chỉ dùng lại cho lối ĐỌC trong lam_moi; mọi thay đổi
        # trạng thái (lệnh, trả lời) đều chạy dưới khoá và xoá nó đi.
        self.anh_dem: tuple[float, Anh] | None = None

    # ---- phát tin ----
    async def _gui(self, kn: KetNoi, tin: dict) -> bool:
        try:
            await asyncio.wait_for(kn.ws.send_text(json.dumps(tin, ensure_ascii=False)), timeout=5)
            return True
        except Exception:                   # máy em tắt màn hình, mạng rớt… — bỏ kết nối đó
            self.ket_noi.discard(kn)
            return False

    async def phat(self, anh: Anh, chi_gv: bool = False) -> None:
        dich = [kn for kn in list(self.ket_noi) if kn.vai == "gv" or not chi_gv]
        await asyncio.gather(*(self._gui(kn, anh.cho_gv() if kn.vai == "gv" else anh.cho_hs(kn.user_id))
                               for kn in dich))

    async def gui_mot(self, kn: KetNoi, anh: Anh) -> None:
        await self._gui(kn, anh.cho_gv() if kn.vai == "gv" else anh.cho_hs(kn.user_id))

    def so_dang_noi(self) -> list[int]:
        return sorted({kn.user_id for kn in self.ket_noi if kn.vai == "hs"})

    # ---- dồn tin cho giáo viên ----
    def hen_bao_gv(self) -> None:
        """Em vào sảnh / em trả lời → màn giáo viên cập nhật. 40 em bấm trong cùng một giây
        thì dồn thành MỘT lần dựng trạng thái mỗi 0,3 giây thay vì 40 lần."""
        if self.bao_gv is None or self.bao_gv.done():
            self.bao_gv = asyncio.create_task(self._bao_gv())

    async def _bao_gv(self) -> None:
        await asyncio.sleep(0.3)
        try:
            _, anh = await self.anh_moi()
            anh.gv["dang_noi"] = self.so_dang_noi()
            await self.phat(anh, chi_gv=True)
        except Exception:
            log.exception("báo giáo viên phòng %s", self.ma)

    # ---- hẹn giờ khoá câu ----
    def dat_hen(self, anh: Anh) -> None:
        """Đặt (hoặc giữ) hẹn giờ khoá câu theo ảnh trạng thái mới nhất."""
        c = anh.chung
        khoa = (c["pha"], c["cau_so"])
        if c["pha"] != "dang_hoi" or "con_lai_ms" not in c:
            self.huy_hen()
            return
        if self.hen_cho == khoa and self.hen and not self.hen.done():
            return
        self.huy_hen()
        self.hen_cho = khoa
        self.hen = asyncio.create_task(self._het_gio(c["con_lai_ms"] / 1000 + GIAY_CHO_TRE + 0.05))

    def huy_hen(self) -> None:
        if self.hen and not self.hen.done() and self.hen is not asyncio.current_task():
            self.hen.cancel()
        self.hen, self.hen_cho = None, None

    async def _het_gio(self, giay: float) -> None:
        await asyncio.sleep(giay)
        try:
            await self.lam_moi()
        except Exception:
            log.exception("hẹn giờ phòng %s", self.ma)

    async def lam_moi(self, phat_luon: bool = False) -> Anh:
        """Kiểm hết giờ → nếu đổi pha thì phát cho mọi máy. Trả ảnh mới nhất."""
        doi, anh = await self.anh_moi()
        self.dat_hen(anh)
        if doi or phat_luon:
            anh.gv["dang_noi"] = self.so_dang_noi()
            await self.phat(anh)
        return anh

    async def anh_moi(self) -> tuple[bool, Anh]:
        yeu_cau_luc = time.monotonic()
        async with self.khoa:
            # 40 em nối cùng lúc (vào sảnh, hay cả lớp nối lại sau khi máy chủ khởi động lại)
            # → xếp hàng chờ khoá. Ảnh nào chụp SAU lúc mình xếp hàng thì dùng chung, khỏi
            # chụp lại: đo bằng tools/kiem_tai_truc_tiep.py, không dùng chung thì lệnh "Bắt
            # đầu" bấm ngay sau đó phải chờ ~5 ms × số em mới tới lượt.
            if self.anh_dem is not None and self.anh_dem[0] >= yeu_cau_luc:
                doi, anh = False, self.anh_dem[1]
            else:
                chup_luc = time.monotonic()
                doi, anh = await chay(kiem_va_chup, self.ma)
                self.anh_dem = (chup_luc, anh)
        return doi, anh

    async def doi_trang_thai(self, ham, *args) -> tuple[object, Anh]:
        """Chạy một thay đổi trạng thái dưới khoá rồi chụp ảnh mới NGAY trong khoá — nhờ
        vậy ảnh luôn theo đúng thứ tự thay đổi."""
        async with self.khoa:
            self.anh_dem = None
            kq = await chay(ham, self.ma, *args)
            chup_luc = time.monotonic()
            anh = await chay(chup, self.ma)
            self.anh_dem = (chup_luc, anh)
        return kq, anh


class QuanLy:
    def __init__(self):
        self._phong: dict[str, Phong] = {}
        self._vong = None

    def lay(self, ma: str) -> Phong:
        # TestClient mở vòng lặp sự kiện mới cho mỗi lần chạy; khoá/hẹn giờ của vòng cũ
        # không dùng được ở vòng mới → làm lại sạch. Trên uvicorn chỉ có một vòng.
        vong = asyncio.get_running_loop()
        if vong is not self._vong:
            self._phong, self._vong = {}, vong
        if ma not in self._phong:
            self._phong[ma] = Phong(ma)
        return self._phong[ma]

    def neu_co(self, ma: str) -> Phong | None:
        try:
            vong = asyncio.get_running_loop()
        except RuntimeError:
            return None
        return self._phong.get(ma) if vong is self._vong else None


quan_ly = QuanLy()


async def thuc_hien_lenh(ma: str, gv_id: int, lenh: str, tu_cau: int | None) -> Anh:
    ph = quan_ly.lay(ma)
    doi, anh = await ph.doi_trang_thai(dieu_khien, gv_id, lenh, tu_cau)
    ph.dat_hen(anh)
    if doi:
        anh.gv["dang_noi"] = ph.so_dang_noi()
        await ph.phat(anh)
    return anh


async def nhan_tra_loi(ma: str, user_id: int, cau_so: int, chon: str) -> dict:
    ph = quan_ly.lay(ma)
    async with ph.khoa:
        ph.anh_dem = None
        kq = await chay(tra_loi, ma, user_id, cau_so, chon)
    if kq["ca_lop_xong"]:
        # Cả lớp đã trả lời → khỏi bắt cả lớp ngồi chờ hết giờ
        doi, anh = await ph.doi_trang_thai(tu_ket_thuc_cau, cau_so)
        ph.dat_hen(anh)
        if doi:
            anh.gv["dang_noi"] = ph.so_dang_noi()
            await ph.phat(anh)
    else:
        ph.hen_bao_gv()
    return kq


def tu_ket_thuc_cau(db: Session, ma: str, cau_so: int) -> bool:
    p, _ = _lay(db, ma)
    if p.pha == "dang_hoi" and p.cau_hien_tai == cau_so:
        p.pha = "lo_dap_an"
        db.commit()
        return True
    return False
