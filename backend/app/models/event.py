"""Sự kiện lịch sử trên dòng thời gian (Timeline + 3D Cinematic)."""
from sqlalchemy import JSON, Column, Integer, String, Text

from app.db.session import Base


class HistoricalEvent(Base):
    __tablename__ = "historical_events"

    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String, unique=True, index=True, nullable=False)  # vd: bach-dang-1288
    title = Column(String, nullable=False)                         # Chiến thắng Bạch Đằng
    year = Column(Integer, nullable=False)                         # 1288 (âm = trước CN)
    period = Column(String)                                        # Nhà Trần
    era = Column(String)                                           # co-dai | phong-kien | hien-dai
    summary = Column(Text)
    cinematic_video_url = Column(String)   # MP4 render sẵn trên CDN
    thumbnail_url = Column(String)
    features = Column(String)              # CSV: cinematic,ar,chat,quiz
    # --- Do đường ống làm giàu dữ liệu điền (data_pipeline/). Cột riêng, không
    # ghi đè `summary` nhóm viết tay. ---
    summary_thcs = Column(Text)            # tóm tắt cho lớp 6–9
    summary_thpt = Column(Text)            # tóm tắt cho lớp 10–12
    grades = Column(String)                # CSV các lớp liên quan: "7,11"
    curriculum = Column(JSON)              # [{ma, cap, lop, chu_de}] theo CT GDPT 2018
    sources = Column(JSON)                 # [{ten, url, phien_ban, giay_phep}]
