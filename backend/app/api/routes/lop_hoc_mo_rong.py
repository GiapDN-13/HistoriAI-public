"""Lớp học giai đoạn 3 — xem app/models/lop_hoc_mo_rong.py.

CÂU TỰ SOẠN (giáo viên)
    GET    /lop/cau-rieng              câu của mình (không kèm câu đã xoá)
    POST   /lop/cau-rieng              soạn câu mới
    PATCH  /lop/cau-rieng/{id}         sửa. Câu đã có học sinh trả lời thì không đổi được
                                       đáp án đúng (bài cũ đã chấm theo đáp án cũ)
    DELETE /lop/cau-rieng/{id}         xoá; câu đã nằm trong đề thì chỉ ẩn
    Câu riêng hiện ở đầu GET /lop/kho-cau (nhóm "Câu tôi tự soạn", id âm) → soạn đề trộn
    được câu kho + câu riêng bằng đúng màn soạn đề cũ.

LỚP CỐ ĐỊNH (giáo viên)
    GET    /lop/lop-hoc                các lớp + sĩ số + số buổi
    POST   /lop/lop-hoc                tạo lớp ("8A2")
    PATCH  /lop/lop-hoc/{id}           đổi tên
    DELETE /lop/lop-hoc/{id}           xoá lớp (danh sách lớp); phòng + bài giữ nguyên, thành phòng lẻ
    GET    /lop/lop-hoc/{id}           danh sách học sinh
    POST   /lop/lop-hoc/{id}/thanh-vien          thêm tay một em theo tên
    DELETE /lop/lop-hoc/{id}/thanh-vien/{tv_id}  bỏ một em khỏi danh sách
    POST   /lop/phong/{ma}/gan-lop     gắn (hoặc gỡ) một phòng đã mở với lớp — dùng cho phòng
                                       mở trước khi có lớp; học sinh đã làm bài được ghi nhận
    GET    /lop/lop-hoc/{id}/thong-ke  thống kê nhiều buổi: điểm TB từng buổi, tiến bộ từng em,
                                       câu và sự kiện cả lớp yếu nhất
    Mở phòng cho lớp: POST /lop/phong kèm "lop_id" (routes/lop_hoc.py).

HỌC SINH
    POST   /auth/giu-tai-khoan         tài khoản nhanh (tên + PIN) thêm email thật + mật khẩu →
                                       giữ nguyên bài thi, XP, lịch sử (cùng một dòng users)

QUYỀN RIÊNG TƯ: mọi truy vấn của giáo viên đều lọc theo giao_vien_id của chính họ — giáo
viên chỉ thấy học sinh đã vào phòng của mình hoặc do mình thêm vào lớp của mình.
"""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, EmailStr, Field, field_validator
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.routes.lop_hoc import MIEN_EMAIL_NHANH, _con_mo, _phong_cua_gv, _phong_out, giao_vien
from app.core.security import generate_token_pair, hash_password
from app.db.session import get_db
from app.models.event import HistoricalEvent
from app.models.lop_hoc import BaiThi, DeKiemTra, PhongThi
from app.models.lop_hoc_mo_rong import CauRieng, LopHoc, ThanhVienLop
from app.models.user import User
from app.schemas.auth import Token
from app.services.cau_trong_de import cau_ra, la_cau_rieng, ma_trong_de, nap_cau
from app.services.gioi_han_dang_nhap import kiem_dang_ky
from app.services.lop_co_dinh import ghi_thanh_vien, lop_cua_gv
from app.services import nhap_cau
from app.services.ngay_hoc import iso_utc

router = APIRouter(tags=["lop-hoc"])

TOI_DA_CAU_RIENG = 1000      # mỗi giáo viên — chặn phình CSDL nếu tài khoản bị lạm dụng
TOI_DA_LOP = 50
TOI_DA_THANH_VIEN = 100


def _gon(v: str | None) -> str | None:
    v = " ".join((v or "").split())
    return v or None


# ================================================================ câu tự soạn

class CauRiengVao(BaseModel):
    question: str = Field(min_length=5, max_length=1000)
    option_a: str = Field(min_length=1, max_length=300)
    option_b: str = Field(min_length=1, max_length=300)
    option_c: str = Field(min_length=1, max_length=300)
    option_d: str = Field(min_length=1, max_length=300)
    correct_option: str = Field(pattern=r"^[ABCDabcd]$")
    explanation: str | None = Field(default=None, max_length=2000)
    event_slug: str | None = Field(default=None, max_length=80)   # gắn sự kiện — để thống kê theo sự kiện
    difficulty: int = Field(default=1, ge=1, le=3)

    @field_validator("question", "option_a", "option_b", "option_c", "option_d")
    @classmethod
    def khong_rong(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Không được để trống")
        return v

    @field_validator("explanation", "event_slug")
    @classmethod
    def gon(cls, v: str | None) -> str | None:
        return (v or "").strip() or None


class CauRiengSua(BaseModel):
    """Trường nào không gửi thì giữ nguyên. event_slug gửi null = bỏ gắn sự kiện."""
    question: str | None = Field(default=None, min_length=5, max_length=1000)
    option_a: str | None = Field(default=None, min_length=1, max_length=300)
    option_b: str | None = Field(default=None, min_length=1, max_length=300)
    option_c: str | None = Field(default=None, min_length=1, max_length=300)
    option_d: str | None = Field(default=None, min_length=1, max_length=300)
    correct_option: str | None = Field(default=None, pattern=r"^[ABCDabcd]$")
    explanation: str | None = Field(default=None, max_length=2000)
    event_slug: str | None = Field(default=None, max_length=80)
    difficulty: int | None = Field(default=None, ge=1, le=3)


def _su_kien(db: Session, slug: str | None) -> int | None:
    if not slug:
        return None
    e = db.query(HistoricalEvent).filter(HistoricalEvent.slug == slug).first()
    if not e:
        raise HTTPException(404, "Không tìm thấy sự kiện để gắn.")
    return e.id


def _kiem_phuong_an(c) -> None:
    pa = [" ".join(x.split()).lower() for x in (c.option_a, c.option_b, c.option_c, c.option_d)]
    if len(set(pa)) < 4:
        raise HTTPException(422, "Bốn phương án phải khác nhau.")


def _cau_out(c: CauRieng, ten_sk: dict[int, tuple[str, str]], da_dung: bool = False) -> dict:
    o = cau_ra(c, ma_trong_de(c))
    sk = ten_sk.get(c.event_id)
    o.update({"cau_rieng_id": c.id, "explanation": c.explanation,
              "event_slug": sk[0] if sk else None, "event_title": sk[1] if sk else None,
              "da_dung_trong_de": da_dung, "tao_luc": iso_utc(c.tao_luc)})
    return o


def _ten_su_kien(db: Session) -> dict[int, tuple[str, str]]:
    return {e.id: (e.slug, e.title) for e in db.query(HistoricalEvent).all()}


def _de_cua_gv(db: Session, gv_id: int) -> list[DeKiemTra]:
    return db.query(DeKiemTra).filter(DeKiemTra.giao_vien_id == gv_id).all()


def _cau_cua_gv(db: Session, cid: int, gv: User) -> CauRieng:
    c = db.query(CauRieng).filter(CauRieng.id == cid, CauRieng.giao_vien_id == gv.id,
                                  CauRieng.an.is_(False)).first()
    if not c:
        raise HTTPException(404, "Không tìm thấy câu hỏi.")
    return c


def _da_co_tra_loi(db: Session, gv_id: int, ma: int) -> bool:
    de_ids = [d.id for d in _de_cua_gv(db, gv_id) if ma in (d.cau_ids or [])]
    if not de_ids:
        return False
    phong_ids = [i for (i,) in db.query(PhongThi.id).filter(PhongThi.de_id.in_(de_ids)).all()]
    if not phong_ids:
        return False
    khoa = str(ma)
    return any(khoa in (tl or {}) for (tl,) in db.query(BaiThi.tra_loi).filter(BaiThi.phong_id.in_(phong_ids)).all())


@router.get("/lop/cau-rieng")
def ds_cau_rieng(gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    dang_dung = {i for d in _de_cua_gv(db, gv.id) for i in (d.cau_ids or []) if la_cau_rieng(i)}
    ten_sk = _ten_su_kien(db)
    return [_cau_out(c, ten_sk, ma_trong_de(c) in dang_dung)
            for c in db.query(CauRieng).filter(CauRieng.giao_vien_id == gv.id, CauRieng.an.is_(False))
            .order_by(CauRieng.id.desc()).all()]


TOI_DA_MOI_LAN_NHAP = 100


class NhapNhieuCau(BaseModel):
    van_ban: str = Field(min_length=1, max_length=200_000)
    event_slug: str | None = Field(default=None, max_length=80)   # gắn chung cho cả lô
    luu: bool = False     # False = chỉ xem trước; True = lưu những câu hợp lệ


@router.post("/lop/cau-rieng/nhap")
def nhap_nhieu_cau(payload: NhapNhieuCau, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    """Dán nhiều câu một lúc (soạn tay hoặc nhờ AI theo prompt trong HDSD).

    Hai bước: xem trước (luu=false) để giáo viên thấy câu nào đọc được, câu nào lỗi
    và vì sao; rồi lưu (luu=true) — chỉ câu hợp lệ được lưu, câu lỗi bỏ qua."""
    cac = nhap_cau.doc(payload.van_ban)
    if not cac:
        raise HTTPException(422, 'Không đọc được câu nào. Mỗi câu cần bắt đầu bằng "Câu 1:" '
                                 'và có 4 dòng A. B. C. D. cùng dòng "Đáp án: …".')
    if len(cac) > TOI_DA_MOI_LAN_NHAP:
        raise HTTPException(422, f"Mỗi lần dán tối đa {TOI_DA_MOI_LAN_NHAP} câu (đang có {len(cac)}).")
    su_kien = _su_kien(db, (payload.event_slug or "").strip() or None)
    ra, hop_le = [], []
    for i, c in enumerate(cac, 1):
        loi = nhap_cau.ly_do_loi(c)
        ra.append({"so": i, **c, "loi": loi})
        if loi is None:
            hop_le.append(c)
    da_luu = 0
    if payload.luu and hop_le:
        con = TOI_DA_CAU_RIENG - db.query(CauRieng).filter(CauRieng.giao_vien_id == gv.id).count()
        if len(hop_le) > con:
            raise HTTPException(409, f"Chỉ còn chỗ cho {max(con, 0)} câu (tối đa {TOI_DA_CAU_RIENG} câu mỗi thầy cô).")
        for c in hop_le:
            db.add(CauRieng(giao_vien_id=gv.id, event_id=su_kien, question=c["question"],
                            option_a=c["option_a"], option_b=c["option_b"], option_c=c["option_c"],
                            option_d=c["option_d"], correct_option=c["correct_option"],
                            explanation=c["explanation"] or None, difficulty=1))
        db.commit()
        da_luu = len(hop_le)
    return {"cau": ra, "hop_le": len(hop_le), "loi": len(ra) - len(hop_le), "da_luu": da_luu}


@router.post("/lop/cau-rieng", status_code=201)
def tao_cau_rieng(payload: CauRiengVao, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    if db.query(CauRieng).filter(CauRieng.giao_vien_id == gv.id).count() >= TOI_DA_CAU_RIENG:
        raise HTTPException(409, f"Mỗi thầy cô soạn được tối đa {TOI_DA_CAU_RIENG} câu.")
    _kiem_phuong_an(payload)
    c = CauRieng(giao_vien_id=gv.id, event_id=_su_kien(db, payload.event_slug), question=payload.question,
                 option_a=payload.option_a, option_b=payload.option_b, option_c=payload.option_c,
                 option_d=payload.option_d, correct_option=payload.correct_option.upper(),
                 explanation=payload.explanation, difficulty=payload.difficulty)
    db.add(c)
    db.commit()
    db.refresh(c)
    return _cau_out(c, _ten_su_kien(db))


@router.patch("/lop/cau-rieng/{cid}")
def sua_cau_rieng(cid: int, payload: CauRiengSua, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    c = _cau_cua_gv(db, cid, gv)
    doi = payload.model_fields_set
    if "correct_option" in doi and payload.correct_option and payload.correct_option.upper() != c.correct_option \
            and _da_co_tra_loi(db, gv.id, ma_trong_de(c)):
        # Bài đã chấm theo đáp án cũ — đổi đáp án làm bảng điểm cũ và bài xem lại của học
        # sinh vênh nhau. Sửa chữ (lỗi chính tả) thì vẫn cho.
        raise HTTPException(409, "Câu này đã có học sinh trả lời nên không đổi được đáp án đúng. "
                                 "Hãy soạn một câu mới.")
    for truong in ("question", "option_a", "option_b", "option_c", "option_d"):
        if truong in doi and getattr(payload, truong) is not None:
            v = getattr(payload, truong).strip()
            if not v:
                raise HTTPException(422, "Không được để trống câu hỏi hay phương án.")
            setattr(c, truong, v)
    if "correct_option" in doi and payload.correct_option:
        c.correct_option = payload.correct_option.upper()
    if "explanation" in doi:
        c.explanation = (payload.explanation or "").strip() or None
    if "event_slug" in doi:
        c.event_id = _su_kien(db, (payload.event_slug or "").strip() or None)
    if "difficulty" in doi and payload.difficulty:
        c.difficulty = payload.difficulty
    _kiem_phuong_an(c)
    c.sua_luc = datetime.now(timezone.utc)
    db.commit()
    db.refresh(c)
    return _cau_out(c, _ten_su_kien(db))


@router.delete("/lop/cau-rieng/{cid}")
def xoa_cau_rieng(cid: int, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    c = _cau_cua_gv(db, cid, gv)
    ma = ma_trong_de(c)
    if any(ma in (d.cau_ids or []) for d in _de_cua_gv(db, gv.id)):
        # Còn đề dùng câu này → chỉ ẩn: bảng theo dõi phòng cũ, bài xem lại của học sinh
        # vẫn cần nội dung câu. Không hiện trong kho nữa, không đưa được vào đề mới.
        c.an = True
        db.commit()
        return {"da_xoa": True, "chi_an": True}
    db.delete(c)
    db.commit()
    return {"da_xoa": True, "chi_an": False}


# ================================================================ lớp cố định

class LopVao(BaseModel):
    ten: str = Field(min_length=1, max_length=40)

    @field_validator("ten")
    @classmethod
    def gon(cls, v: str) -> str:
        v = _gon(v)
        if not v:
            raise ValueError("Đặt tên lớp")
        return v


class ThanhVienVao(BaseModel):
    ten: str = Field(min_length=2, max_length=60)

    @field_validator("ten")
    @classmethod
    def gon(cls, v: str) -> str:
        v = _gon(v)
        if not v or len(v) < 2:
            raise ValueError("Họ tên quá ngắn")
        return v


class GanLop(BaseModel):
    lop_id: int | None = None       # null = gỡ phòng khỏi lớp


def _lop(db: Session, lop_id: int, gv: User) -> LopHoc:
    lop = lop_cua_gv(db, lop_id, gv.id)
    if not lop:
        raise HTTPException(404, "Không tìm thấy lớp.")
    return lop


def _trung_ten_lop(db: Session, gv_id: int, ten: str, tru_id: int | None = None) -> bool:
    q = db.query(LopHoc).filter(LopHoc.giao_vien_id == gv_id, func.lower(LopHoc.ten) == ten.lower())
    if tru_id is not None:
        q = q.filter(LopHoc.id != tru_id)
    return q.first() is not None


def _lop_out(db: Session, lop: LopHoc) -> dict:
    return {"id": lop.id, "ten": lop.ten, "tao_luc": iso_utc(lop.tao_luc),
            "si_so": db.query(ThanhVienLop).filter(ThanhVienLop.lop_id == lop.id).count(),
            "so_buoi": db.query(PhongThi).filter(PhongThi.lop_id == lop.id).count()}


@router.get("/lop/lop-hoc")
def ds_lop(gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    return [_lop_out(db, l) for l in db.query(LopHoc).filter(LopHoc.giao_vien_id == gv.id).order_by(LopHoc.ten).all()]


@router.post("/lop/lop-hoc", status_code=201)
def tao_lop(payload: LopVao, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    if db.query(LopHoc).filter(LopHoc.giao_vien_id == gv.id).count() >= TOI_DA_LOP:
        raise HTTPException(409, f"Mỗi thầy cô tạo được tối đa {TOI_DA_LOP} lớp.")
    if _trung_ten_lop(db, gv.id, payload.ten):
        raise HTTPException(409, "Thầy cô đã có lớp mang tên này.")
    lop = LopHoc(giao_vien_id=gv.id, ten=payload.ten)
    db.add(lop)
    db.commit()
    db.refresh(lop)
    return _lop_out(db, lop)


@router.patch("/lop/lop-hoc/{lop_id}")
def doi_ten_lop(lop_id: int, payload: LopVao, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    lop = _lop(db, lop_id, gv)
    if _trung_ten_lop(db, gv.id, payload.ten, tru_id=lop.id):
        raise HTTPException(409, "Thầy cô đã có lớp mang tên này.")
    lop.ten = payload.ten
    db.commit()
    return _lop_out(db, lop)


@router.delete("/lop/lop-hoc/{lop_id}", status_code=204)
def xoa_lop(lop_id: int, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    """Xoá danh sách lớp. Phòng và bài thi KHÔNG xoá — đó là điểm của học sinh, giáo viên
    có thể còn cần (CSV); phòng chỉ trở lại thành phòng lẻ."""
    lop = _lop(db, lop_id, gv)
    db.query(PhongThi).filter(PhongThi.lop_id == lop.id).update({PhongThi.lop_id: None}, synchronize_session=False)
    db.query(ThanhVienLop).filter(ThanhVienLop.lop_id == lop.id).delete(synchronize_session=False)
    db.delete(lop)
    db.commit()
    return None


@router.get("/lop/lop-hoc/{lop_id}")
def chi_tiet_lop(lop_id: int, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    lop = _lop(db, lop_id, gv)
    phong_ids = [i for (i,) in db.query(PhongThi.id).filter(PhongThi.lop_id == lop.id).all()]
    so_bai: dict[int, int] = {}
    if phong_ids:
        for (uid,) in db.query(BaiThi.user_id).filter(BaiThi.phong_id.in_(phong_ids)).all():
            so_bai[uid] = so_bai.get(uid, 0) + 1
    tv = db.query(ThanhVienLop).filter(ThanhVienLop.lop_id == lop.id).all()
    tv.sort(key=lambda t: t.ten_hien.lower())
    return {**_lop_out(db, lop), "thanh_vien": [
        {"id": t.id, "ten": t.ten_hien, "cach": t.cach, "da_vao_phong": t.user_id is not None,
         "so_buoi_lam": so_bai.get(t.user_id, 0) if t.user_id else 0}
        for t in tv]}


@router.post("/lop/lop-hoc/{lop_id}/thanh-vien", status_code=201)
def them_thanh_vien(lop_id: int, payload: ThanhVienVao, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    lop = _lop(db, lop_id, gv)
    tv = db.query(ThanhVienLop).filter(ThanhVienLop.lop_id == lop.id).all()
    if len(tv) >= TOI_DA_THANH_VIEN:
        raise HTTPException(409, f"Một lớp tối đa {TOI_DA_THANH_VIEN} em.")
    if any(t.ten_hien.lower() == payload.ten.lower() for t in tv):
        raise HTTPException(409, "Lớp đã có em mang tên này. Thêm chữ để phân biệt (vd \"An B\").")
    t = ThanhVienLop(lop_id=lop.id, user_id=None, ten_hien=payload.ten, cach="tay")
    db.add(t)
    db.commit()
    return {"id": t.id, "ten": t.ten_hien, "cach": t.cach, "da_vao_phong": False, "so_buoi_lam": 0}


@router.delete("/lop/lop-hoc/{lop_id}/thanh-vien/{tv_id}", status_code=204)
def bo_thanh_vien(lop_id: int, tv_id: int, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    lop = _lop(db, lop_id, gv)
    n = db.query(ThanhVienLop).filter(ThanhVienLop.id == tv_id, ThanhVienLop.lop_id == lop.id).delete(
        synchronize_session=False)
    if not n:
        raise HTTPException(404, "Không tìm thấy học sinh trong lớp.")
    db.commit()
    return None


@router.post("/lop/phong/{ma}/gan-lop")
def gan_lop(ma: str, payload: GanLop, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    p, d = _phong_cua_gv(ma, gv, db)
    if payload.lop_id is not None:
        _lop(db, payload.lop_id, gv)
    p.lop_id = payload.lop_id
    # Phòng mở trước khi có lớp: các em đã làm bài được ghi nhận vào lớp luôn.
    for b in db.query(BaiThi).filter(BaiThi.phong_id == p.id).all():
        ghi_thanh_vien(db, p.lop_id, b.user_id, b.ten_hien)
    db.commit()
    return _phong_out(p, d)


def _diem_10(b: BaiThi) -> float:
    tong = len(b.thu_tu or [])
    return round((b.so_dung or 0) * 10 / tong, 2) if tong else 0.0


@router.get("/lop/lop-hoc/{lop_id}/thong-ke")
def thong_ke_lop(lop_id: int, gv: User = Depends(giao_vien), db: Session = Depends(get_db)):
    """Thống kê các buổi kiểm tra của một lớp.

    Bài được TÍNH khi: em đã nộp, hoặc phòng đã đóng mà em có trả lời ít nhất một câu
    (bài tập về nhà nhiều em làm xong quên bấm nộp). Em vào phòng mà không làm câu nào
    thì coi như vắng buổi đó, không tính 0 điểm — kéo điểm trung bình xuống vì một em
    mở nhầm link là sai với thực tế lớp.
    """
    lop = _lop(db, lop_id, gv)
    ds_phong = (db.query(PhongThi).filter(PhongThi.lop_id == lop.id, PhongThi.giao_vien_id == gv.id)
                .order_by(PhongThi.tao_luc, PhongThi.id).all())
    tv = db.query(ThanhVienLop).filter(ThanhVienLop.lop_id == lop.id).all()
    ten_hs: dict[object, str] = {t.user_id if t.user_id else f"tay-{t.id}": t.ten_hien for t in tv}

    buoi, diem_hs = [], {}           # diem_hs: {user_id: {chỉ số buổi: điểm}}
    cau_tk: dict[int, list[int]] = {}  # {id câu trong đề: [số trả lời, số đúng]}
    for i, p in enumerate(ds_phong):
        d = db.get(DeKiemTra, p.de_id)
        bai = db.query(BaiThi).filter(BaiThi.phong_id == p.id).all()
        con_mo = _con_mo(p)
        tinh = [b for b in bai if b.nop_luc is not None or (not con_mo and b.tra_loi)]
        for b in tinh:
            diem_hs.setdefault(b.user_id, {})[i] = _diem_10(b)
            ten_hs.setdefault(b.user_id, b.ten_hien)
            for k, v in (b.tra_loi or {}).items():
                c = cau_tk.setdefault(int(k), [0, 0])
                c[0] += 1
                c[1] += 1 if v.get("dung") else 0
        ds_diem = [_diem_10(b) for b in tinh]
        buoi.append({"ma": p.ma, "tieu_de": d.tieu_de if d else "", "ngay": iso_utc(p.tao_luc),
                     "dang_mo": con_mo, "so_bai": len(bai), "so_tinh": len(tinh),
                     "diem_tb": round(sum(ds_diem) / len(ds_diem), 2) if ds_diem else None})

    hoc_sinh = []
    for khoa, ten in ten_hs.items():
        theo_buoi = diem_hs.get(khoa, {}) if isinstance(khoa, int) else {}
        diem = [theo_buoi.get(i) for i in range(len(buoi))]
        co = [x for x in diem if x is not None]
        hoc_sinh.append({"ten": ten, "diem": diem, "so_buoi": len(co),
                         "diem_tb": round(sum(co) / len(co), 2) if co else None,
                         # tiến bộ: buổi gần nhất so với buổi đầu tiên em có mặt
                         "thay_doi": round(co[-1] - co[0], 2) if len(co) >= 2 else None})
    hoc_sinh.sort(key=lambda h: h["ten"].lower())

    cau = nap_cau(db, list(cau_tk))
    ten_sk = {e.id: e.title for e in db.query(HistoricalEvent).all()}
    cau_yeu, theo_sk = [], {}
    for qid, (so_tl, so_dung) in cau_tk.items():
        q = cau.get(qid)
        if q is None or not so_tl:
            continue
        cau_yeu.append({"id": qid, "question": q.question, "rieng": la_cau_rieng(qid),
                        "su_kien": ten_sk.get(q.event_id), "so_tra_loi": so_tl,
                        "ti_le_dung": round(so_dung * 100 / so_tl)})
        if q.event_id in ten_sk:
            s = theo_sk.setdefault(q.event_id, [0, 0])
            s[0] += so_tl
            s[1] += so_dung
    cau_yeu.sort(key=lambda c: (c["ti_le_dung"], -c["so_tra_loi"]))
    su_kien_yeu = sorted(({"su_kien": ten_sk[eid], "so_tra_loi": a, "ti_le_dung": round(b * 100 / a)}
                          for eid, (a, b) in theo_sk.items() if a), key=lambda s: s["ti_le_dung"])
    return {"lop": _lop_out(db, lop), "buoi": buoi, "hoc_sinh": hoc_sinh,
            "cau_yeu": cau_yeu[:10], "su_kien_yeu": su_kien_yeu}


# ================================================================ giữ tài khoản nhanh

class GiuTaiKhoan(BaseModel):
    email: EmailStr
    mat_khau: str
    ho_ten: str | None = Field(default=None, max_length=60)

    @field_validator("mat_khau")
    @classmethod
    def du_manh(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Mật khẩu phải có ít nhất 8 ký tự")
        return v

    @field_validator("ho_ten")
    @classmethod
    def ten_gon(cls, v: str | None) -> str | None:
        v = _gon(v)
        if v is not None and len(v) < 2:
            raise ValueError("Họ tên quá ngắn")
        return v


def la_tai_khoan_nhanh(u: User) -> bool:
    return (u.email or "").lower().endswith("@" + MIEN_EMAIL_NHANH)


@router.post("/auth/giu-tai-khoan", response_model=Token)
def giu_tai_khoan(payload: GiuTaiKhoan, request: Request, current: User = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    """Nâng tài khoản nhanh (tên + PIN, email tổng hợp) thành tài khoản đầy đủ.

    Sửa NGAY TRÊN dòng users đang có — không tạo tài khoản mới rồi chuyển dữ liệu — nên
    bài thi, XP, chuỗi ngày học, lịch sử làm bài giữ nguyên mà không phải chép gì.

    Cùng giới hạn tốc độ với đăng ký: về bản chất đây là tạo ra một tài khoản đăng nhập
    được bằng email, không để thành lối tắt tạo tài khoản rác.
    """
    if not la_tai_khoan_nhanh(current):
        raise HTTPException(400, "Tài khoản này đã có email rồi.")
    kiem_dang_ky(request)
    email = str(payload.email).strip()
    if email.lower().endswith("@" + MIEN_EMAIL_NHANH):
        raise HTTPException(422, "Hãy dùng email thật của em hoặc của phụ huynh.")
    if db.query(User.id).filter(func.lower(User.email) == email.lower()).first():
        raise HTTPException(400, "Email này đã có tài khoản HistoriAI. Hãy dùng email khác, "
                                 "hoặc đăng nhập bằng email đó.")
    current.email = email
    current.hashed_password = hash_password(payload.mat_khau)
    current.co_mat_khau = True
    if payload.ho_ten:
        current.full_name = payload.ho_ten
    # PIN 4 số chỉ đủ giữ một bài thi trong một phòng (có chặn đoán). Tài khoản giờ có
    # email thật, lịch sử, có thể cả thông tin phụ huynh — không để PIN còn là cửa vào.
    # Muốn vào lại phòng: đăng nhập bằng email, app nhận ra bài cũ theo tài khoản.
    db.query(BaiThi).filter(BaiThi.user_id == current.id).update({BaiThi.pin_bam: None},
                                                                 synchronize_session=False)
    # Mã đăng nhập cũ (cấp lúc vào phòng) hết hiệu lực; máy này nhận mã mới.
    current.token_version = (current.token_version or 0) + 1
    tokens = generate_token_pair(str(current.id), current.token_version)
    current.refresh_token = tokens["refresh_token"]
    db.commit()
    return Token(**tokens)
