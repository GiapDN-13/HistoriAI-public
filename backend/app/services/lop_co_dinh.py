"""Ghi nhận học sinh vào lớp cố định (xem app/models/lop_hoc_mo_rong.py).

Tách khỏi route để app/api/routes/lop_hoc.py (vào phòng) và lop_hoc_mo_rong.py (gắn
phòng cũ vào lớp) cùng gọi mà không import vòng.
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from app.models.lop_hoc import PhongThi
from app.models.lop_hoc_mo_rong import CauRieng, LopHoc, ThanhVienLop


def ghi_thanh_vien(db: Session, lop_id: int | None, user_id: int, ten: str) -> None:
    """Em vào một phòng của lớp → là thành viên lớp. Gọi lại nhiều lần không sao.

    Giáo viên đã thêm tay tên em (chưa có tài khoản) thì NỐI vào dòng đó chứ không tạo
    dòng mới — không thì danh sách lớp có hai "Nguyễn Văn An", sĩ số sai.
    """
    if not lop_id:
        return
    if db.query(ThanhVienLop.id).filter(ThanhVienLop.lop_id == lop_id,
                                        ThanhVienLop.user_id == user_id).first():
        return
    ten_thuong = " ".join(ten.split()).lower()
    cho = next((t for t in db.query(ThanhVienLop).filter(ThanhVienLop.lop_id == lop_id,
                                                         ThanhVienLop.user_id.is_(None)).all()
                if " ".join(t.ten_hien.split()).lower() == ten_thuong), None)
    if cho is not None:
        cho.user_id = user_id
    else:
        db.add(ThanhVienLop(lop_id=lop_id, user_id=user_id, ten_hien=ten[:60], cach="phong"))
    db.flush()


def lop_cua_gv(db: Session, lop_id: int, giao_vien_id: int) -> LopHoc | None:
    return db.query(LopHoc).filter(LopHoc.id == lop_id, LopHoc.giao_vien_id == giao_vien_id).first()


def xoa_du_lieu_mo_rong(db: Session, uid: int) -> None:
    """Gọi từ auth.xoa_tai_khoan. Giáo viên: câu tự soạn + lớp + danh sách lớp xoá hẳn.
    Học sinh: tên em trong danh sách lớp của các thầy cô cũng xoá (tên thật em tự gõ)."""
    lop_ids = [i for (i,) in db.query(LopHoc.id).filter(LopHoc.giao_vien_id == uid).all()]
    if lop_ids:
        db.query(ThanhVienLop).filter(ThanhVienLop.lop_id.in_(lop_ids)).delete(synchronize_session=False)
        db.query(PhongThi).filter(PhongThi.lop_id.in_(lop_ids)).update({PhongThi.lop_id: None},
                                                                       synchronize_session=False)
        db.query(LopHoc).filter(LopHoc.id.in_(lop_ids)).delete(synchronize_session=False)
    db.query(ThanhVienLop).filter(ThanhVienLop.user_id == uid).delete(synchronize_session=False)
    db.query(CauRieng).filter(CauRieng.giao_vien_id == uid).delete(synchronize_session=False)
