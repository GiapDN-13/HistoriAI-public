"""Gom tất cả route con vào một router tổng."""
from fastapi import APIRouter

from app.api.routes import analytics, auth, chat, content, lop_hoc, phan_hoi, progress, quiz
from app.api.routes import lop_hoc_truc_tiep
from app.api.routes import lop_hoc_mo_rong
from app.api.routes import ban_tin
from app.api.routes import lo_trinh
from app.api.routes import thanh_toan

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(auth.anh_router)   # /anh-dai-dien/{ten} — ngoài tiền tố /auth
api_router.include_router(content.router)
api_router.include_router(lo_trinh.router)
api_router.include_router(quiz.router)
api_router.include_router(chat.router)
api_router.include_router(progress.router)
api_router.include_router(analytics.router)
api_router.include_router(phan_hoi.router)
api_router.include_router(lop_hoc.router)
api_router.include_router(lop_hoc_truc_tiep.router)
api_router.include_router(lop_hoc_mo_rong.router)
api_router.include_router(thanh_toan.router)   # Premium: đơn + webhook SePay
api_router.include_router(ban_tin.router)   # /me/ban-tin/link + /ban-tin/{ma} (trang phụ huynh)
