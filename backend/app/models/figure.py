"""Nhân vật lịch sử dùng cho tính năng Chat Vĩ Nhân."""
from sqlalchemy import JSON, Column, Integer, String, Text, Boolean

from app.db.session import Base


class HistoricalFigure(Base):
    __tablename__ = "historical_figures"

    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String, unique=True, index=True, nullable=False)  # tran-hung-dao
    name = Column(String, nullable=False)                          # Trần Hưng Đạo
    title = Column(String)                                         # Quốc Công Tiết Chế
    period = Column(String)                                        # Nhà Trần · 1228–1300
    portrait_url = Column(String)
    model_url = Column(String)           # URL model 3D .glb (avatar Chat + AR)
    knowledge_boundary = Column(String)  # Mốc kiến thức tối đa của persona lịch sử
    persona_prompt = Column(Text)        # system prompt mô tả tính cách để LLM nhập vai
    voice_id = Column(String)            # id giọng ElevenLabs
    is_featured = Column(Boolean, default=False)
    unlock_level = Column(Integer, default=1)
    # Khối sử liệu ≥ 2 nguồn xác nhận, nối vào persona khi chat (data_pipeline/).
    # Tách cột để không ghi đè persona_prompt nhóm viết tay.
    verified_facts = Column(Text)
    sources = Column(JSON)
