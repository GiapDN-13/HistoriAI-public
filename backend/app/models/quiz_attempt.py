"""Lịch sử làm bài quiz của người dùng."""
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, func

from app.db.session import Base


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    event_id = Column(Integer, ForeignKey("historical_events.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("quiz_questions.id"), nullable=False)
    selected_option = Column(String(1), nullable=False)
    is_correct = Column(Boolean, nullable=False)
    # Mã một lượt nộp bài — gom các câu cùng nộp một lần thành một dòng "lịch sử làm bài".
    # Dòng cũ (trước 27/09) không có mã: gom theo sự kiện + phút nộp.
    lan_nop = Column(String(32), nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
