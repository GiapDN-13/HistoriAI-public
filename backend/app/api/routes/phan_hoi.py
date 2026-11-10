"""Nhận phản hồi người dùng gửi từ app (số sao, NPS, lời góp ý, trận muốn thêm)."""
from datetime import datetime, timedelta, timezone
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field, field_validator, model_validator
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_optional
from app.db.session import get_db
from app.models.phan_hoi import PhanHoi
from app.models.user import User
from app.schemas.auth import lam_sach_nhan

router = APIRouter(prefix="/phan-hoi", tags=["phan-hoi"])

TOI_DA_MOI_NGAY = 10   # một máy gửi quá 10 lần/ngày là spam, không phải góp ý


class PhanHoiIn(BaseModel):
    diem: int | None = Field(None, ge=1, le=5)
    nps: int | None = Field(None, ge=0, le=10)
    gop_y: str | None = Field(None, max_length=1000)
    ngu_canh: Literal["quiz", "chat", "ho-so", "khac"] = "khac"
    target: str | None = Field(None, max_length=128)
    nguon: str | None = None
    kenh: str | None = None
    chien_dich: str | None = None
    noi_dung: str | None = None
    nen_tang: str | None = Field(None, max_length=16)
    # Slug trận/chủ đề muốn thêm. Không đối chiếu với danh sách cố định: danh sách
    # nằm ở app, thêm chip mới không phải sửa máy chủ. Chỉ chặn độ dài — app cho
    # chọn tối đa 3, nhận tới 5 cho bản app sau; slug dài nhất hiện là 27 ký tự,
    # 5 × 32 + 4 dấu phẩy vẫn lọt cột VARCHAR(200).
    muon_them: list[Annotated[str, Field(max_length=32)]] | None = Field(None, max_length=5)

    @field_validator("nguon", "kenh", "chien_dich", "noi_dung")
    @classmethod
    def _sach(cls, v):
        return lam_sach_nhan(v)

    @field_validator("gop_y")
    @classmethod
    def _gon(cls, v):
        v = (v or "").strip()
        return v or None

    @field_validator("muon_them")
    @classmethod
    def _sach_ds(cls, v):
        # Cùng luật làm sạch với nguồn → không còn dấu phẩy, nối/tách lại an toàn.
        sach: list[str] = []
        for x in v or []:
            s = lam_sach_nhan(x)
            if s and s not in sach:
                sach.append(s)
        return sach or None

    @model_validator(mode="after")
    def _co_noi_dung(self):
        if self.diem is None and self.nps is None and not self.gop_y and not self.muon_them:
            raise ValueError("Phản hồi trống")
        return self


@router.post("", status_code=201)
def gui_phan_hoi(
    payload: PhanHoiIn,
    db: Session = Depends(get_db),
    current: User | None = Depends(get_current_user_optional),
    x_client_id: str | None = Header(None),
):
    """Không bắt buộc đăng nhập: phần lớn người thử sản phẩm chưa có tài khoản."""
    ma_may = (x_client_id or "khong-ro")[:64]
    gan_day = db.query(PhanHoi).filter(
        PhanHoi.client_id == ma_may,
        PhanHoi.created_at >= datetime.now(timezone.utc) - timedelta(days=1),
    ).count()
    if gan_day >= TOI_DA_MOI_NGAY:
        raise HTTPException(429, "Bạn đã gửi nhiều góp ý hôm nay — cảm ơn bạn, mai gửi tiếp nhé.")
    db.add(PhanHoi(client_id=ma_may, user_id=current.id if current else None,
                   muon_them=",".join(payload.muon_them) if payload.muon_them else None,
                   **payload.model_dump(exclude={"muon_them"})))
    db.commit()
    return {"ok": True}
