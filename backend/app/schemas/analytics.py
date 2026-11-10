"""Schema cho hệ đo lường: nhận event từ app và trả số liệu tổng hợp."""
from datetime import datetime

from pydantic import BaseModel, Field


class TrackEventIn(BaseModel):
    """Một hành vi người dùng do app gửi lên."""

    name: str = Field(..., min_length=1, max_length=64)
    client_id: str = Field(..., min_length=1, max_length=64)
    session_id: str = Field(..., min_length=1, max_length=64)
    platform: str = Field("web", max_length=16)
    target: str | None = Field(None, max_length=128)
    value: int | None = None
    params: dict | None = None
    client_ts: datetime | None = None


class TrackBatchIn(BaseModel):
    """Gói nhiều event gửi một lượt để đỡ tốn request."""

    events: list[TrackEventIn] = Field(..., min_length=1, max_length=50)


class TrackResult(BaseModel):
    accepted: int              # số event đã ghi
    rejected: int              # số event bị bỏ vì tên ngoài danh mục
    unknown: list[str] = []    # tên bị bỏ — để bắt lỗi gõ sai lúc phát triển
