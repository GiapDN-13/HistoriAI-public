"""Hiện vật 3D cho AR Museum (Trống đồng, Kiếm Lê Lợi...)."""
from sqlalchemy import JSON, Column, Integer, String, Text

from app.db.session import Base


class Artifact(Base):
    __tablename__ = "artifacts"

    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String, unique=True, index=True, nullable=False)  # trong-dong-dong-son
    name = Column(String, nullable=False)                          # Trống đồng Đông Sơn
    period = Column(String)                                        # Văn Lang
    description = Column(Text)
    model_glb_url = Column(String)    # file .glb (Android/web)
    model_usdz_url = Column(String)   # file .usdz (iOS ARKit)
    thumbnail_url = Column(String)
    real_scale_meters = Column(String)  # vd "0.6" để hiển thị kích thước thật
    sources = Column(JSON)              # nguồn và giấy phép (data_pipeline/)
