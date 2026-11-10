"""Nạp câu hỏi của một đề — câu kho (id dương) lẫn câu giáo viên tự soạn (id âm).

VÌ SAO ID ÂM
    DeKiemTra.cau_ids, BaiThi.thu_tu, khoá của BaiThi.tra_loi đều là id câu kiểu số.
    Câu riêng nằm bảng riêng (xem app/models/lop_hoc_mo_rong.py), id của nó có thể trùng
    id câu kho. Mã hoá câu riêng thành -CauRieng.id thì hai loại không bao giờ đụng
    nhau, mà không phải đổi kiểu cột hay dữ liệu đã có của giai đoạn 1.

Mọi chỗ trong lớp học cần đọc câu của đề đi qua `nap_cau`, không query thẳng
QuizQuestion — để câu riêng chấm được, hiện được trên bảng theo dõi như câu kho.
"""
from __future__ import annotations

from sqlalchemy.orm import Session

from app.models.lop_hoc_mo_rong import CauRieng
from app.models.quiz import QuizQuestion


def la_cau_rieng(qid: int) -> bool:
    return qid < 0


def ma_trong_de(c: CauRieng) -> int:
    """id của câu riêng khi nằm trong đề."""
    return -c.id


def nap_cau(db: Session, ids) -> dict[int, object]:
    """{id trong đề: câu}. Câu kho là QuizQuestion, câu riêng là CauRieng — hai loại có
    cùng tên thuộc tính (question, option_a…d, correct_option, explanation, event_id).
    Câu riêng đã ẩn (giáo viên xoá sau khi đã dùng) vẫn nạp: bài cũ phải xem lại được."""
    ids = list(ids or [])
    duong = [i for i in ids if i > 0]
    am = [-i for i in ids if i < 0]
    ra: dict[int, object] = {}
    if duong:
        ra.update({q.id: q for q in db.query(QuizQuestion).filter(QuizQuestion.id.in_(duong)).all()})
    if am:
        ra.update({-c.id: c for c in db.query(CauRieng).filter(CauRieng.id.in_(am)).all()})
    return ra


def cau_ra(c, ma: int) -> dict:
    """Một câu (kho hoặc riêng) theo dạng kho câu cho giáo viên — CÓ đáp án."""
    return {"id": ma, "question": c.question,
            "options": {"A": c.option_a, "B": c.option_b, "C": c.option_c, "D": c.option_d},
            "correct_option": c.correct_option.upper(), "difficulty": c.difficulty,
            "rieng": la_cau_rieng(ma)}


def nhom_cau_rieng_cho_kho(db: Session, giao_vien_id: int) -> list[dict]:
    """Nhóm "Câu tôi tự soạn" đặt đầu kho câu khi soạn đề. Chỉ câu của giáo viên này."""
    cau = (db.query(CauRieng).filter(CauRieng.giao_vien_id == giao_vien_id, CauRieng.an.is_(False))
           .order_by(CauRieng.id).all())
    if not cau:
        return []
    return [{"event_slug": "cau-rieng", "event_title": "Câu tôi tự soạn", "year": None, "rieng": True,
             "cau": [cau_ra(c, ma_trong_de(c)) for c in cau]}]


def cau_hop_le_cho_gv(db: Session, ids: list[int], giao_vien_id: int) -> bool:
    """Mọi id đều có thật; câu riêng phải của CHÍNH giáo viên này và chưa bị xoá.
    Không kiểm chỗ này thì giáo viên đoán id là mượn được câu (kèm đáp án) của người khác."""
    duong = [i for i in ids if i > 0]
    am = [-i for i in ids if i < 0]
    if duong and db.query(QuizQuestion.id).filter(QuizQuestion.id.in_(duong)).count() != len(set(duong)):
        return False
    if am and db.query(CauRieng.id).filter(
            CauRieng.id.in_(am), CauRieng.giao_vien_id == giao_vien_id,
            CauRieng.an.is_(False)).count() != len(set(am)):
        return False
    return True
