"""Câu hỏi quiz cho Đấu Trường Sử Việt."""
from sqlalchemy import JSON, Column, ForeignKey, Integer, String, Text

from app.db.session import Base


class QuizQuestion(Base):
    __tablename__ = "quiz_questions"

    id = Column(Integer, primary_key=True, index=True)
    event_id = Column(Integer, ForeignKey("historical_events.id"))
    question = Column(Text, nullable=False)
    option_a = Column(String, nullable=False)
    option_b = Column(String, nullable=False)
    option_c = Column(String, nullable=False)
    option_d = Column(String, nullable=False)
    correct_option = Column(String, nullable=False)  # 'A' | 'B' | 'C' | 'D'
    explanation = Column(Text)
    difficulty = Column(Integer, default=1)          # 1 dễ → 3 khó
    # --- Do đường ống làm giàu dữ liệu điền. Câu nhóm viết tay để trống. ---
    curriculum_ref = Column(Text)        # yêu cầu cần đạt mà câu hỏi phục vụ
    source_claims = Column(JSON)         # [{noi_dung, trich_dan, url}] — căn cứ của đáp án
    grade_min = Column(Integer)          # lớp thấp nhất học tới nội dung này
