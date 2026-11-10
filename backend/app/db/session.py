"""Khởi tạo kết nối DB và session SQLAlchemy."""
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import settings

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """Dependency của FastAPI — mở/đóng session cho mỗi request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
