"""Điểm khởi động ứng dụng FastAPI HistoriAI."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.core.config import settings
from app.db.session import Base, engine
from app.db.migrate_nhe import dam_bao_cot

from app.core.theo_doi_loi import bat_sentry

bat_sentry()   # trước khi tạo app, để bắt cả lỗi lúc khởi động. DSN trống = không làm gì.

# Tạo bảng nếu chưa có (MVP — production nên dùng Alembic migrations)
import app.models  # noqa: F401  (đăng ký tất cả model)
Base.metadata.create_all(bind=engine)
dam_bao_cot()   # thêm cột mới vào bảng cũ — xem app/db/migrate_nhe.py

app = FastAPI(title=settings.PROJECT_NAME, version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.CORS_ORIGINS.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/health", tags=["system"])
def health():
    """Kiểm tra service sống (dùng cho CI/CD & monitoring)."""
    return {"status": "ok", "service": settings.PROJECT_NAME}
