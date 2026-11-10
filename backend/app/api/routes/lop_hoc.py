"""Chế độ kiểm tra cho lớp học (giai đoạn 1: bài tập) — xem app/models/lop_hoc.py.

GIÁO VIÊN (role = "teacher", nâng bằng mã nhóm phát — POST /auth/lam-giao-vien)
    GET  /lop/kho-cau               kho câu hỏi theo sự kiện, CÓ đáp án (để chọn câu)
    POST /lop/de · GET /lop/de      tạo / liệt kê đề của mình
    POST /lop/phong                 mở phòng cho một đề → mã 6 số (app in thành QR)
    GET  /lop/phong                 các phòng của mình
    GET  /lop/phong/{ma}/bang       bảng theo dõi: từng em + từng câu
    POST /lop/phong/{ma}/dong       đóng phòng (hết nhận bài)
    GET  /lop/phong/{ma}/csv        bảng điểm để vào sổ (Excel mở được tiếng Việt)

HỌC SINH
    GET  /phong/{ma}                thông tin phòng (không cần đăng nhập)
    POST /phong/{ma}/vao            vào phòng: đã đăng nhập thì dùng tài khoản đó; chưa thì
                                    ĐĂNG KÝ NHANH bằng họ tên + PIN 4 số (không email). Vào
                                    lại đúng tên + PIN = lấy lại bài đang làm.
    GET  /phong/{ma}/de             câu hỏi (đã trộn riêng cho em), KHÔNG kèm đáp án
    POST /phong/{ma}/tra-loi        trả lời một câu — mỗi câu một lần, không sửa
    POST /phong/{ma}/nop            nộp bài → điểm + giải thích từng câu

Bài nộp cũng ghi vào lịch sử làm bài thường (QuizAttempt) — nên hiện ở "Lịch sử học",
câu sai vào "Ôn câu sai", và cộng XP theo đúng luật lần-đầu-đúng như quiz thường.
"""
from __future__ import annotations

import csv
import io
import random
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_current_user_optional
from app.api.routes.quiz import XP_PER_CORRECT_BASE, _calc_level
from app.core.config import settings
from app.core.security import generate_token_pair, hash_password, verify_password
from app.db.session import get_db
from app.models.event import HistoricalEvent
from app.models.lop_hoc import BaiThi, DeKiemTra, PhongThi
from app.models.quiz import QuizQuestion
from app.models.quiz_attempt import QuizAttempt
from app.models.user import User
from app.services.gioi_han_dang_nhap import cua, dia_chi_that, _chan
# GĐ3: đề trộn câu kho + câu giáo viên tự soạn (id âm); phòng gắn lớp cố định.
from app.services.cau_trong_de import cau_hop_le_cho_gv, la_cau_rieng, nap_cau, nhom_cau_rieng_cho_kho
from app.services.lop_co_dinh import ghi_thanh_vien, lop_cua_gv
from app.services.ngay_hoc import ghi_ngay_hoc, iso_utc

router = APIRouter(tags=["lop-hoc"])

# Một phòng tin học 2 lớp cùng mạng — ngưỡng riêng, rộng hơn đăng ký thường (60/giờ/IP).
VAO_PHONG_IP = (300, 3600)
SAI_PIN = (8, 15 * 60)          # đoán PIN của bạn cùng lớp: 8 lần sai / 15 phút / (phòng, tên)
MIEN_EMAIL_NHANH = "nhanh.historiai.org"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: datetime | None) -> datetime | None:
    if dt is not None and dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


# ---------------------------------------------------------------- phân quyền

def giao_vien(current: User = Depends(get_current_user)) -> User:
    if current.role not in ("teacher", "admin"):
        raise HTTPException(403, "Chức năng này dành cho giáo viên.")
    return current


class MaGiaoVien(BaseModel):
    ma: str = Field(min_length=1, max_length=64)


@router.post("/auth/lam-giao-vien")
def lam_giao_vien(payload: MaGiaoVien, request: Request, current: User = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    """Nâng tài khoản lên giáo viên bằng mã nhóm phát. So sánh hằng thời gian."""
    k = f"ma-gv:{dia_chi_that(request)}"
    _chan(cua.con_cho(k, (10, 3600)), "Nhập sai mã nhiều lần.")
    if not settings.MA_GIAO_VIEN or not secrets.compare_digest(payload.ma.strip(), settings.MA_GIAO_VIEN):
        cua.ghi(k)
        raise HTTPException(400, "Mã giáo viên chưa đúng. Hãy liên hệ nhóm HistoriAI để nhận mã.")
    if current.role != "admin":      # đừng hạ quyền quản trị xuống giáo viên
        current.role = "teacher"
    db.commit()
    return {"role": current.role}


# ---------------------------------------------------------------- kho câu + đề

@router.get("/lop/kho-cau")
def kho_cau(gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    su_kien = db.query(HistoricalEvent).order_by(HistoricalEvent.year).all()
    cau = db.query(QuizQuestion).all()
    theo_sk: dict[int, list] = {}
    for q in cau:
        theo_sk.setdefault(q.event_id, []).append({
            "id": q.id, "question": q.question,
            "options": {"A": q.option_a, "B": q.option_b, "C": q.option_c, "D": q.option_d},
            "correct_option": q.correct_option.upper(), "difficulty": q.difficulty,
        })
    return nhom_cau_rieng_cho_kho(db, gv.id) + [
        {"event_slug": e.slug, "event_title": e.title, "year": e.year, "cau": theo_sk.get(e.id, [])}
        for e in su_kien if theo_sk.get(e.id)]


class TaoDe(BaseModel):
    tieu_de: str = Field(min_length=2, max_length=120)
    cau_ids: list[int] = Field(min_length=1, max_length=60)
    giay_moi_cau: int = Field(default=30, ge=10, le=300)


def _de_out(d: DeKiemTra) -> dict:
    return {"id": d.id, "tieu_de": d.tieu_de, "so_cau": len(d.cau_ids or []),
            "giay_moi_cau": d.giay_moi_cau, "tao_luc": iso_utc(d.tao_luc)}


@router.post("/lop/de", status_code=201)
def tao_de(payload: TaoDe, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    ids = list(dict.fromkeys(payload.cau_ids))          # bỏ trùng, giữ thứ tự
    if not cau_hop_le_cho_gv(db, ids, gv.id):
        raise HTTPException(400, "Có câu hỏi không còn trong kho.")
    d = DeKiemTra(giao_vien_id=gv.id, tieu_de=" ".join(payload.tieu_de.split()),
                  cau_ids=ids, giay_moi_cau=payload.giay_moi_cau)
    db.add(d)
    db.commit()
    db.refresh(d)
    return _de_out(d)


@router.get("/lop/de")
def ds_de(gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    return [_de_out(d) for d in db.query(DeKiemTra).filter(DeKiemTra.giao_vien_id == gv.id)
            .order_by(DeKiemTra.id.desc()).all()]


# ---------------------------------------------------------------- phòng (giáo viên)

class MoPhong(BaseModel):
    de_id: int
    han_phut: int | None = Field(default=None, ge=5, le=60 * 24 * 14)   # None = mở tới khi giáo viên đóng
    tron_cau: bool = True
    # GĐ2: "truc_tiep" = giáo viên bấm chuyển từng câu (routes/lop_hoc_truc_tiep.py)
    che_do: str = Field(default="bai_tap", pattern=r"^(bai_tap|truc_tiep)$")
    lop_id: int | None = None       # GĐ3: mở cho một lớp cố định → vào thống kê của lớp


def _ma_moi(db: Session) -> str:
    for _ in range(50):
        ma = f"{secrets.randbelow(900000) + 100000}"
        if not db.query(PhongThi.id).filter(PhongThi.ma == ma).first():
            return ma
    raise HTTPException(503, "Chưa tạo được mã phòng, thử lại.")


def _link(ma: str) -> str:
    goc = settings.PUBLIC_BASE_URL.rstrip("/") or "https://historiai.org"
    return f"{goc}/vao/{ma}"


def _con_mo(p: PhongThi) -> bool:
    han = _aware(p.han_chot)
    return bool(p.dang_mo) and (han is None or han > _utcnow())


def _phong_out(p: PhongThi, d: DeKiemTra, so_bai: int = 0, so_nop: int = 0) -> dict:
    return {"ma": p.ma, "link": _link(p.ma), "de_id": d.id, "tieu_de": d.tieu_de,
            "so_cau": len(d.cau_ids or []), "giay_moi_cau": d.giay_moi_cau,
            "dang_mo": _con_mo(p), "han_chot": iso_utc(p.han_chot), "tao_luc": iso_utc(p.tao_luc),
            "so_bai": so_bai, "so_nop": so_nop, "che_do": p.che_do or "bai_tap", "pha": p.pha,
            "lop_id": p.lop_id}


def _phong_cua_gv(ma: str, gv: User, db: Session) -> tuple[PhongThi, DeKiemTra]:
    p = db.query(PhongThi).filter(PhongThi.ma == ma, PhongThi.giao_vien_id == gv.id).first()
    if not p:
        raise HTTPException(404, "Không tìm thấy phòng.")
    return p, db.get(DeKiemTra, p.de_id)


@router.post("/lop/phong", status_code=201)
def mo_phong(payload: MoPhong, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    d = db.query(DeKiemTra).filter(DeKiemTra.id == payload.de_id, DeKiemTra.giao_vien_id == gv.id).first()
    if not d:
        raise HTTPException(404, "Không tìm thấy đề.")
    if payload.lop_id is not None and lop_cua_gv(db, payload.lop_id, gv.id) is None:
        raise HTTPException(404, "Không tìm thấy lớp.")
    truc_tiep = payload.che_do == "truc_tiep"
    # Trực tiếp: cả lớp cùng một câu cùng lúc → không trộn thứ tự; hết trận là đóng → không hạn chót
    p = PhongThi(ma=_ma_moi(db), de_id=d.id, giao_vien_id=gv.id, tron_cau=payload.tron_cau and not truc_tiep,
                 han_chot=_utcnow() + timedelta(minutes=payload.han_phut) if payload.han_phut and not truc_tiep else None,
                 che_do=payload.che_do, pha="cho" if truc_tiep else None, lop_id=payload.lop_id)
    db.add(p)
    db.commit()
    db.refresh(p)
    return _phong_out(p, d)


@router.get("/lop/phong")
def ds_phong(gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    ra = []
    for p in db.query(PhongThi).filter(PhongThi.giao_vien_id == gv.id).order_by(PhongThi.id.desc()).limit(50):
        bai = db.query(BaiThi).filter(BaiThi.phong_id == p.id).all()
        ra.append(_phong_out(p, db.get(DeKiemTra, p.de_id), len(bai), sum(1 for b in bai if b.nop_luc)))
    return ra


@router.post("/lop/phong/{ma}/dong")
def dong_phong(ma: str, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    p, d = _phong_cua_gv(ma, gv, db)
    if p.dang_mo:
        p.dang_mo = False
        p.dong_luc = _utcnow()
        db.commit()
    return _phong_out(p, d)


def _bang(p: PhongThi, d: DeKiemTra, db: Session) -> dict:
    bai = db.query(BaiThi).filter(BaiThi.phong_id == p.id).order_by(BaiThi.id).all()
    cau = nap_cau(db, d.cau_ids)
    tong = len(d.cau_ids)
    hoc_sinh = []
    for b in bai:
        tl = b.tra_loi or {}
        nop, bd = _aware(b.nop_luc), _aware(b.bat_dau)
        hoc_sinh.append({
            "ten": b.ten_hien, "lop": b.lop, "da_lam": len(tl), "so_dung": sum(1 for v in tl.values() if v.get("dung")),
            "tong": tong, "da_nop": nop is not None, "nop_luc": iso_utc(nop),
            "giay_lam": int((nop - bd).total_seconds()) if nop and bd else None,
        })
    # Xếp: đã nộp trước, rồi đúng nhiều, rồi làm nhanh
    hoc_sinh.sort(key=lambda h: (not h["da_nop"], -h["so_dung"], h["giay_lam"] or 10**9))
    tung_cau = []
    for qid in d.cau_ids:
        q = cau.get(qid)
        if q is None:
            continue
        chon = {"A": 0, "B": 0, "C": 0, "D": 0}
        for b in bai:
            v = (b.tra_loi or {}).get(str(qid))
            if v and v.get("chon") in chon:
                chon[v["chon"]] += 1
        so_tl = sum(chon.values())
        dung = chon.get(q.correct_option.upper(), 0)
        sai = {k: v for k, v in chon.items() if k != q.correct_option.upper() and v}
        tung_cau.append({
            "id": qid, "question": q.question, "correct_option": q.correct_option.upper(),
            "options": {"A": q.option_a, "B": q.option_b, "C": q.option_c, "D": q.option_d},
            "so_tra_loi": so_tl, "so_dung": dung, "ti_le_dung": round(dung * 100 / so_tl) if so_tl else None,
            "phan_bo": chon, "nham_nhieu_nhat": max(sai, key=sai.get) if sai else None,
        })
    return {"phong": _phong_out(p, d, len(bai), sum(1 for h in hoc_sinh if h["da_nop"])),
            "hoc_sinh": hoc_sinh, "tung_cau": tung_cau}


@router.get("/lop/phong/{ma}/bang")
def bang_theo_doi(ma: str, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    p, d = _phong_cua_gv(ma, gv, db)
    return _bang(p, d, db)


@router.get("/lop/phong/{ma}/csv")
def xuat_csv(ma: str, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    p, d = _phong_cua_gv(ma, gv, db)
    b = _bang(p, d, db)
    ra = io.StringIO()
    w = csv.writer(ra)
    w.writerow(["Họ tên", "Lớp", "Số câu đúng", "Tổng số câu", "Điểm (thang 10)", "Đã nộp", "Thời gian làm (giây)"])
    for h in b["hoc_sinh"]:
        w.writerow([h["ten"], h["lop"] or "", h["so_dung"], h["tong"],
                    round(h["so_dung"] * 10 / h["tong"], 2) if h["tong"] else 0,
                    "có" if h["da_nop"] else "chưa", h["giay_lam"] if h["giay_lam"] is not None else ""])
    # BOM để Excel nhận đúng UTF-8 (không thì tên tiếng Việt vỡ dấu)
    return Response("﻿" + ra.getvalue(), media_type="text/csv; charset=utf-8",
                    headers={"Content-Disposition": f'attachment; filename="phong-{p.ma}.csv"'})


@router.get("/lop/phong/{ma}/xlsx")
def xuat_excel(ma: str, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    """Bảng điểm dạng Excel thật (.xlsx, 3 trang) — xem services/xuat_excel.py."""
    from app.services import xuat_excel as XE
    from app.services.phong_truc_tiep import _xep_hang
    p, d = _phong_cua_gv(ma, gv, db)
    b = _bang(p, d, db)
    bai = db.query(BaiThi).filter(BaiThi.phong_id == p.id).order_by(BaiThi.id).all()
    truc_tiep = p.che_do == "truc_tiep"
    xh = {h["ten"]: h for h in _xep_hang(bai)} if truc_tiep else None
    tep = XE.tao(b, truc_tiep=truc_tiep, xep_hang=xh, giao_vien=gv.full_name,
                 chi_tiet=[{"ten": x.ten_hien, "lop": x.lop, "tra_loi": x.tra_loi} for x in bai])
    return Response(tep, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    headers={"Content-Disposition": f'attachment; filename="bang-diem-{p.ma}.xlsx"'})


# ---------------------------------------------------------------- học sinh

def _phong(ma: str, db: Session) -> tuple[PhongThi, DeKiemTra]:
    p = db.query(PhongThi).filter(PhongThi.ma == ma.strip()).first()
    if not p:
        raise HTTPException(404, "Không có phòng nào mang mã này. Kiểm tra lại mã.")
    return p, db.get(DeKiemTra, p.de_id)


@router.get("/phong/{ma}")
def xem_phong(ma: str, db: Session = Depends(get_db)):
    p, d = _phong(ma, db)
    gv = db.get(User, p.giao_vien_id)
    return {"ma": p.ma, "tieu_de": d.tieu_de, "so_cau": len(d.cau_ids), "giay_moi_cau": d.giay_moi_cau,
            "dang_mo": _con_mo(p), "han_chot": iso_utc(p.han_chot),
            "giao_vien": (gv.full_name if gv else "") or "", "che_do": p.che_do or "bai_tap"}


class VaoPhong(BaseModel):
    ho_ten: str | None = Field(default=None, max_length=60)
    lop: str | None = Field(default=None, max_length=20)
    pin: str | None = Field(default=None, pattern=r"^\d{4}$")

    @field_validator("ho_ten", "lop")
    @classmethod
    def gon(cls, v: str | None) -> str | None:
        v = " ".join((v or "").split())
        return v or None


def _bai_out(b: BaiThi, d: DeKiemTra) -> dict:
    tl = b.tra_loi or {}
    return {"ten": b.ten_hien, "lop": b.lop, "da_lam": len(tl), "tong": len(d.cau_ids),
            "da_nop": b.nop_luc is not None, "giay_moi_cau": d.giay_moi_cau}


@router.post("/phong/{ma}/vao")
def vao_phong(ma: str, payload: VaoPhong, request: Request, db: Session = Depends(get_db),
              current: User | None = Depends(get_current_user_optional)):
    p, d = _phong(ma, db)
    ip = dia_chi_that(request)

    if current is not None:
        user = current
        b = db.query(BaiThi).filter(BaiThi.phong_id == p.id, BaiThi.user_id == user.id).first()
        ten = payload.ho_ten or user.full_name
    else:
        if not payload.ho_ten or len(payload.ho_ten) < 2 or not payload.pin:
            raise HTTPException(422, "Nhập họ tên (ít nhất 2 chữ) và mã PIN 4 số.")
        ten = payload.ho_ten
        # Vào lại: cùng phòng + cùng tên (không phân biệt hoa thường) + đúng PIN
        cu = [b for b in db.query(BaiThi).filter(BaiThi.phong_id == p.id, BaiThi.pin_bam.isnot(None)).all()
              if b.ten_hien.lower() == ten.lower()]
        b = None
        if cu:
            k = f"pin:{p.ma}:{ten.lower()}"
            _chan(cua.con_cho(k, SAI_PIN), "Sai PIN nhiều lần quá.")
            b = next((x for x in cu if verify_password(payload.pin, x.pin_bam)), None)
            if b is None:
                cua.ghi(k)
                raise HTTPException(409, "Tên này đã có bạn dùng trong phòng. Nếu là em, nhập đúng PIN "
                                         "đã đặt; nếu không, thêm chữ để phân biệt (vd \"An 8A2\").")
            user = db.get(User, b.user_id)
        else:
            user = None

    if b is None:
        if not _con_mo(p):
            raise HTTPException(410, "Phòng đã đóng, không nhận bài mới.")
        # Băm PIN TRƯỚC khi ghi CSDL: bcrypt mất ~0,25 s, băm sau flush() là giữ khoá ghi
        # SQLite suốt lúc đó → 40 em quét QR cùng lúc thì các em sau dính "database is
        # locked" (đo bằng tools/kiem_tai_truc_tiep.py, 27/09).
        pin_bam = hash_password(payload.pin) if current is None else None
        if current is None:
            _chan(cua.con_cho(f"vao-ip:{ip}", VAO_PHONG_IP), "Mạng này đã vào phòng quá nhiều lần.")
            cua.ghi(f"vao-ip:{ip}")
            # Tài khoản nhanh: email tổng hợp (cột email bắt buộc & duy nhất), không ai
            # đăng nhập bằng email này được — chỉ vào lại qua phòng + tên + PIN.
            user = User(email=f"hs-{secrets.token_hex(6)}@{MIEN_EMAIL_NHANH}", full_name=ten,
                        hashed_password=hash_password(secrets.token_urlsafe(24)), co_mat_khau=False,
                        role="student", nguon="lop-hoc", kenh=p.ma)
            db.add(user)
            db.flush()
        thu_tu = list(d.cau_ids)
        if p.tron_cau:
            random.Random(f"{p.ma}:{user.id}").shuffle(thu_tu)
        b = BaiThi(phong_id=p.id, user_id=user.id, ten_hien=ten, lop=payload.lop,
                   pin_bam=pin_bam,
                   thu_tu=thu_tu, tra_loi={})
        db.add(b)

    ghi_thanh_vien(db, p.lop_id, user.id, b.ten_hien)     # GĐ3: vào phòng của lớp = thành viên lớp
    tokens = generate_token_pair(str(user.id), user.token_version or 0)
    db.commit()
    return {"access_token": tokens["access_token"], "token_type": "bearer",
            "tai_khoan_nhanh": (user.email or "").endswith("@" + MIEN_EMAIL_NHANH),
            "bai": _bai_out(b, d)}


def _bai_cua_toi(ma: str, user: User, db: Session) -> tuple[PhongThi, DeKiemTra, BaiThi]:
    p, d = _phong(ma, db)
    b = db.query(BaiThi).filter(BaiThi.phong_id == p.id, BaiThi.user_id == user.id).first()
    if not b:
        raise HTTPException(403, "Em chưa vào phòng này.")
    return p, d, b


def _chan_truc_tiep(p: PhongThi, ca_khi_ket_thuc: bool = True) -> None:
    """Phòng trực tiếp: câu hỏi đi theo nhịp giáo viên qua lop_hoc_truc_tiep.py. Để các route
    bài tập mở thì em nào cũng xem trước / trả lời trước được cả đề."""
    if p.che_do == "truc_tiep" and (ca_khi_ket_thuc or p.pha != "ket_thuc"):
        raise HTTPException(409, "Phòng này thi trực tiếp — câu hỏi hiện theo nhịp thầy cô.")


@router.get("/phong/{ma}/de")
def lay_de(ma: str, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    p, d, b = _bai_cua_toi(ma, current, db)
    _chan_truc_tiep(p)
    cau = nap_cau(db, b.thu_tu)
    tl = b.tra_loi or {}
    return {"bai": _bai_out(b, d), "dang_mo": _con_mo(p), "cau": [
        {"id": qid, "question": cau[qid].question,
         "options": {"A": cau[qid].option_a, "B": cau[qid].option_b, "C": cau[qid].option_c, "D": cau[qid].option_d},
         "da_chon": (tl.get(str(qid)) or {}).get("chon")}
        for qid in b.thu_tu if qid in cau]}


class TraLoi(BaseModel):
    question_id: int
    chon: str = Field(pattern=r"^[ABCD]?$")     # rỗng = hết giờ


@router.post("/phong/{ma}/tra-loi")
def tra_loi(ma: str, payload: TraLoi, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    p, d, b = _bai_cua_toi(ma, current, db)
    _chan_truc_tiep(p)
    if b.nop_luc:
        raise HTTPException(409, "Em đã nộp bài rồi.")
    if not _con_mo(p):
        raise HTTPException(410, "Phòng đã đóng.")
    if payload.question_id not in b.thu_tu:
        raise HTTPException(404, "Câu này không có trong bài.")
    tl = dict(b.tra_loi or {})
    khoa = str(payload.question_id)
    if khoa in tl:                               # mỗi câu một lần — như thi thật
        return {"dung": tl[khoa]["dung"], "da_tra_loi_truoc": True}
    q = nap_cau(db, [payload.question_id]).get(payload.question_id)
    if q is None:
        raise HTTPException(404, "Câu này không còn.")
    dung = bool(payload.chon) and q.correct_option.upper() == payload.chon
    tl[khoa] = {"chon": payload.chon, "dung": dung}
    b.tra_loi = tl                               # gán lại để SQLAlchemy biết JSON đã đổi
    b.so_dung = sum(1 for v in tl.values() if v.get("dung"))
    db.commit()
    return {"dung": dung, "da_tra_loi_truoc": False}


@router.post("/phong/{ma}/nop")
def nop_bai(ma: str, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    p, d, b = _bai_cua_toi(ma, current, db)
    _chan_truc_tiep(p, ca_khi_ket_thuc=False)   # hết trận thì gọi được: để xem lại đáp án + giải thích
    cau = nap_cau(db, b.thu_tu)
    tl = b.tra_loi or {}
    if b.nop_luc is None:
        b.nop_luc = _utcnow()
        # Ghi vào lịch sử làm bài thường + XP lần-đầu-đúng (như /quiz/submit)
        da_dung = {qid for (qid,) in db.query(QuizAttempt.question_id).filter(
            QuizAttempt.user_id == current.id, QuizAttempt.is_correct.is_(True),
            QuizAttempt.question_id.in_(b.thu_tu)).distinct().all()}
        xp = 0
        for qid in b.thu_tu:
            v = tl.get(str(qid))
            # Câu giáo viên tự soạn KHÔNG vào lịch sử làm bài thường: quiz_attempts trỏ về
            # kho chung, và "Ôn câu sai"/lịch sử là chỗ công khai — câu chưa qua kiểm duyệt
            # nội dung không được lọt ra đó. Cũng không cộng XP (XP gắn với kho đã duyệt).
            if v is None or qid not in cau or la_cau_rieng(qid):
                continue
            db.add(QuizAttempt(user_id=current.id, event_id=cau[qid].event_id, question_id=qid,
                               selected_option=(v.get("chon") or "")[:1], is_correct=bool(v.get("dung")),
                               lan_nop=f"phong-{p.ma}"))
            if v.get("dung") and qid not in da_dung:
                xp += XP_PER_CORRECT_BASE
        if xp:
            current.xp = (current.xp or 0) + xp
            current.level = _calc_level(current.xp)
        if tl:
            ghi_ngay_hoc(current)
        db.commit()
    return {"bai": _bai_out(b, d), "so_dung": b.so_dung, "tong": len(b.thu_tu),
            "diem_10": round(b.so_dung * 10 / len(b.thu_tu), 2) if b.thu_tu else 0,
            "cau": [{"id": qid, "question": cau[qid].question,
                     "options": {"A": cau[qid].option_a, "B": cau[qid].option_b,
                                 "C": cau[qid].option_c, "D": cau[qid].option_d},
                     "chon": (tl.get(str(qid)) or {}).get("chon"),
                     "dung": bool((tl.get(str(qid)) or {}).get("dung")),
                     "correct_option": cau[qid].correct_option.upper(),
                     "explanation": cau[qid].explanation}
                    for qid in b.thu_tu if qid in cau]}


# ---------------------------------------------------------------- bảng vàng cho học sinh

SO_DONG_BANG_VANG = 10


@router.get("/phong/{ma}/xep-hang")
def bang_vang_phong(ma: str, current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Bảng vàng của phòng cho HỌC SINH (giáo viên đã có bảng đầy đủ ở /lop/phong/{ma}/bang).

    Chỉ em đã nộp bài (bài tập) / phòng đã hết trận (trực tiếp) mới xem được — xem
    giữa chừng là biết bạn khác làm tới đâu. Trả top 10 + hạng của chính em, để
    màn kết quả vẽ bảng vàng và giấy vinh danh."""
    from app.services.phong_truc_tiep import _xep_hang
    p, d, b = _bai_cua_toi(ma, current, db)
    truc_tiep = p.che_do == "truc_tiep"
    if truc_tiep and p.pha != "ket_thuc":
        raise HTTPException(409, "Hết trận mới có bảng vàng.")
    if not truc_tiep and b.nop_luc is None:
        raise HTTPException(409, "Nộp bài xong mới xem được bảng vàng.")
    tong_cau = len(d.cau_ids or [])
    bai = db.query(BaiThi).filter(BaiThi.phong_id == p.id).all()
    if truc_tiep:
        dong = _xep_hang(bai)
    else:
        dong = []
        for x in bai:
            nop, bd = _aware(x.nop_luc), _aware(x.bat_dau)
            if nop is None:
                continue
            dong.append({"user_id": x.user_id, "ten": x.ten_hien, "lop": x.lop, "so_dung": x.so_dung or 0,
                         "_giay": int((nop - bd).total_seconds()) if bd else 10 ** 9})
        dong.sort(key=lambda h: (-h["so_dung"], h["_giay"], h["ten"].lower()))
        for i, h in enumerate(dong):
            t = dong[i - 1] if i else None
            h["hang"] = t["hang"] if t and (t["so_dung"], t["_giay"]) == (h["so_dung"], h["_giay"]) else i + 1
        for h in dong:
            g = h.pop("_giay")
            h["giay_lam"] = g if g < 10 ** 9 else None
    toi = next((h for h in dong if h["user_id"] == current.id), None)
    n = len(dong)
    from app.services.anh_tai_len import cua_nhieu_nguoi
    anh = cua_nhieu_nguoi(db, [h["user_id"] for h in dong[:SO_DONG_BANG_VANG]] + [current.id])
    khong_anh = {"avatar": None, "avatar_url": None}

    def ra(h):
        o = {k: v for k, v in h.items() if k != "user_id"}
        o["la_toi"] = h["user_id"] == current.id
        o.update(anh.get(h["user_id"], khong_anh))
        return o

    gv = db.get(User, p.giao_vien_id)
    so_dung = toi["so_dung"] if toi else (b.so_dung or 0)
    return {
        "tieu_de": d.tieu_de, "che_do": p.che_do, "giao_vien": gv.full_name if gv else None,
        "ngay": iso_utc(_aware(b.nop_luc) or _utcnow()), "tong_hoc_sinh": n, "tong_cau": tong_cau,
        "top": [ra(h) for h in dong[:SO_DONG_BANG_VANG]],
        "cua_toi": {
            "ten": b.ten_hien, "lop": b.lop, "hang": toi["hang"] if toi else None,
            **anh.get(current.id, khong_anh),
            "so_dung": so_dung, "diem": toi.get("diem") if toi else None,
            "diem_10": round(so_dung * 10 / tong_cau, 2) if tong_cau else 0,
            # % bạn trong phòng đứng sau em — để giấy vinh danh nói "vượt X% các bạn"
            "vuot_pct": round(sum(1 for h in dong if toi and h["hang"] > toi["hang"]) * 100 / (n - 1))
            if toi and n > 1 else None,
        },
    }
