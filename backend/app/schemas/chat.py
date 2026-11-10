"""Schema cho Chat Vĩ Nhân."""
from typing import Literal

from pydantic import BaseModel, Field

# Bao nhiêu lượt cũ gửi kèm cho mô hình. Đủ để hiểu "vậy sau đó thì sao?", mà
# không đốt token: mỗi lượt cũ đều bị tính lại ở mỗi câu hỏi mới.
SO_LUOT_NHO = 8


class LuotChat(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(max_length=2000)


class ChatRequest(BaseModel):
    figure_slug: str       # tran-hung-dao
    message: str = Field(min_length=1, max_length=1000)
    # Các lượt TRƯỚC câu hỏi này, cũ → mới. App tự giữ (trên máy), máy chủ không lưu
    # nội dung chat. Nhận nhiều hơn thì chỉ lấy SO_LUOT_NHO lượt cuối.
    history: list[LuotChat] = Field(default_factory=list, max_length=40)
    # App từ 0.3.2 đặt True: hiểu dòng "[NGUON]…" cuối luồng. Bản cài cũ không đặt — gửi
    # dòng đó cho chúng là chúng in nguyên chữ "[NGUON][...]" ra cuối câu trả lời.
    nhan_nguon: bool = False


class ChatResponse(BaseModel):
    figure_slug: str
    reply: str
    audio_url: str | None = None   # URL giọng nói AI Voice (nếu có)
    sources: list[str] = []        # trích dẫn sử liệu (GraphRAG)


class SpeakRequest(BaseModel):
    """Đọc đúng đoạn text đang hiển thị (không gọi LLM) -> tiếng khớp chữ."""
    figure_slug: str
    text: str


class SpeakResponse(BaseModel):
    audio_url: str | None = None
