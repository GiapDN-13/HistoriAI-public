"""Gom tất cả model để Alembic/SQLAlchemy nhận diện khi tạo bảng."""
from app.models.user import User
from app.models.event import HistoricalEvent
from app.models.figure import HistoricalFigure
from app.models.quiz import QuizQuestion
from app.models.artifact import Artifact
from app.models.progress import UserProgress
from app.models.quiz_attempt import QuizAttempt
from app.models.analytics import AnalyticsEvent
from app.models.phan_hoi import PhanHoi
from app.models.phien import MaDatLai, TokenThuHoi
from app.models.lop_hoc import BaiThi, DeKiemTra, PhongThi
from app.models.lop_hoc_mo_rong import CauRieng, LopHoc, ThanhVienLop
from app.models.thanh_toan import DonThanhToan, GiaoDichNganHang, LuotChatNgay

__all__ = [
    "User",
    "HistoricalEvent",
    "HistoricalFigure",
    "QuizQuestion",
    "Artifact",
    "UserProgress",
    "QuizAttempt",
    "AnalyticsEvent",
    "PhanHoi",
    "TokenThuHoi",
    "MaDatLai",
    "DeKiemTra",
    "PhongThi",
    "BaiThi",
    "CauRieng",
    "LopHoc",
    "ThanhVienLop",
    "DonThanhToan",
    "GiaoDichNganHang",
    "LuotChatNgay",
]
