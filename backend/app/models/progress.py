"""Tiến độ học tập của người dùng theo từng sự kiện."""
from sqlalchemy import Column, Integer, ForeignKey, DateTime, func

from app.db.session import Base


class UserProgress(Base):
    __tablename__ = "user_progress"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    event_id = Column(Integer, ForeignKey("historical_events.id"), nullable=False)
    mastery = Column(Integer, default=0)        # 0–100 %
    quiz_best_score = Column(Integer, default=0)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
