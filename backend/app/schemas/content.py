"""Schema trả về nội dung: sự kiện, nhân vật, hiện vật, quiz."""
from typing import Literal

from pydantic import BaseModel


class EventOut(BaseModel):
    id: int
    slug: str
    title: str
    year: int
    period: str | None = None
    era: str | None = None
    summary: str | None = None
    cinematic_video_url: str | None = None
    thumbnail_url: str | None = None
    features: str | None = None
    # Số câu hỏi thật trong kho, để thẻ Đấu trường khỏi phải đoán.
    quiz_count: int = 0
    # Do đường ống làm giàu dữ liệu điền; sự kiện chưa qua đường ống thì rỗng.
    summary_thcs: str | None = None
    summary_thpt: str | None = None
    grades: str | None = None
    curriculum: list[dict] | None = None
    sources: list[dict] | None = None

    class Config:
        from_attributes = True


class FigureOut(BaseModel):
    id: int
    slug: str
    name: str
    title: str | None = None
    period: str | None = None
    portrait_url: str | None = None
    model_url: str | None = None
    knowledge_boundary: str | None = None
    is_featured: bool
    unlock_level: int
    sources: list[dict] | None = None

    class Config:
        from_attributes = True


class ArtifactOut(BaseModel):
    id: int
    slug: str
    name: str
    period: str | None = None
    description: str | None = None
    model_glb_url: str | None = None
    model_usdz_url: str | None = None
    thumbnail_url: str | None = None
    real_scale_meters: str | None = None
    sources: list[dict] | None = None

    class Config:
        from_attributes = True


class QuizQuestionOut(BaseModel):
    id: int
    question: str
    option_a: str
    option_b: str
    option_c: str
    option_d: str
    difficulty: int
    # correct_option KHÔNG trả ra ngoài để tránh lộ đáp án

    class Config:
        from_attributes = True


class QuizAnswer(BaseModel):
    question_id: int
    selected_option: str  # 'A' | 'B' | 'C' | 'D'; rỗng khi hết giờ


class QuizCheckAnswer(BaseModel):
    question_id: int
    # Rỗng = hết giờ chưa chọn: vẫn chấm (sai) để app hiện đáp án đúng + lời giải.
    selected_option: Literal["A", "B", "C", "D", ""]


class QuizCheckResult(BaseModel):
    question_id: int
    correct: bool
    # Trả kèm từ 21/10 (góp ý: "chọn sai không hiện đáp án đúng cũng như giải thích").
    # Chỉ có SAU khi đã chọn — câu hỏi tải về vẫn không kèm đáp án.
    correct_option: str
    explanation: str | None = None


class QuizSubmitResult(BaseModel):
    question_id: int
    correct: bool
    correct_option: str
    explanation: str | None = None
    xp: int = 0   # XP thật nhận được cho câu này (0 nếu sai hoặc đã từng đúng trước đó)


# --- Bài học theo lộ trình (app/services/lo_trinh.py) ---
# Không trả `da_duyet` và `nguon`: API chỉ có bản đã duyệt, còn tên tệp tài liệu là
# chuyện nội bộ của nhóm.

class KienThucOut(BaseModel):
    tieu_de: str   # đúng tiêu đề mục c) của tài liệu: "Kế sách chủ chốt", "Vì sao…?"
    y: list[str]


class SuKienLoTrinhOut(BaseModel):
    slug: str
    ten: str
    ten_ngan: str
    muc_tieu: str
    boi_canh: list[str]
    kien_thuc: KienThucOut
    dien_bien: list[str]
    ket_qua: list[str]
    cau_chot: str
    # Bài sau của bản thường: chỉ có mục tiêu + câu chốt, các mục còn lại để trống.
    khoa: bool = False


class LoTrinhOut(BaseModel):
    ma: str
    ten: str
    su_kien: list[SuKienLoTrinhOut]
