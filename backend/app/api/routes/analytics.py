"""Route hệ đo lường: app gửi hành vi lên, nhóm lấy số liệu xuống."""
import hmac
import json
from pathlib import Path

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, status
from fastapi.responses import HTMLResponse, PlainTextResponse
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_optional
from app.core.config import settings
from app.db.session import get_db
from app.models.analytics import AnalyticsEvent
from app.models.thanh_toan import DonThanhToan
from app.models.user import User
from app.schemas.analytics import TrackBatchIn, TrackResult
from app.services.analytics import EVENT_NAMES, bao_cao_tuan, build_summary
from app.services import thanh_toan as tt
from app.services.analytics_mo_rong import doc_thiet_bi
from app.services.ngay_hoc import iso_utc

router = APIRouter(prefix="/analytics", tags=["analytics"])

ALLOWED_PLATFORMS = {"web", "android", "ios", "other"}
MAX_PARAMS_CHARS = 1000   # params chỉ để ghi chú thêm, không dùng để tổng hợp

DASHBOARD_FILE = Path(__file__).resolve().parents[3] / "static" / "analytics_dashboard.html"


def require_analytics_key(
    key: str | None = Query(None, description="Khoá xem số liệu"),
    x_analytics_key: str | None = Header(None),
) -> None:
    """Chặn người ngoài xem số liệu nhóm.

    Nếu ANALYTICS_KEY để trống thì không chặn — tiện lúc chạy máy nhà,
    nhưng khi deploy nhớ đặt khoá trong .env.
    """
    expected = settings.ANALYTICS_KEY
    if not expected:
        return
    if (key or x_analytics_key) != expected:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sai khoá xem số liệu")


def bat_buoc_khoa_analytics(
    key: str | None = Query(None, description="Khoá xem số liệu"),
    x_analytics_key: str | None = Header(None),
) -> None:
    """Như `require_analytics_key` nhưng KHÔNG mở khi chưa đặt khoá.

    Xem số liệu mà để ngỏ thì chỉ lộ số; còn route này cộng Premium — chưa đặt
    ANALYTICS_KEY mà cho qua là ai biết địa chỉ cũng tự xác nhận đơn để dùng miễn phí.
    """
    expected = settings.ANALYTICS_KEY
    if not expected:
        raise HTTPException(status.HTTP_403_FORBIDDEN,
                            "Chưa đặt ANALYTICS_KEY nên chức năng này đang khoá.")
    if not hmac.compare_digest((key or x_analytics_key or "").encode(), expected.encode()):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sai khoá xem số liệu")


class XacNhanDon(BaseModel):
    ma_don: str = Field(min_length=1, max_length=16)
    # Khoản tiền ngân hàng mà quản trị đang đối chiếu (nếu bấm từ bảng "chưa khớp").
    sepay_id: int | None = None


@router.post("/track", response_model=TrackResult)
def track(
    batch: TrackBatchIn,
    request: Request,
    db: Session = Depends(get_db),
    current: User | None = Depends(get_current_user_optional),
):
    """Ghi nhận hành vi người dùng.

    Không bắt buộc đăng nhập — khách vãng lai cũng phải đếm được, vì phần
    lớn người thử sản phẩm chưa tạo tài khoản. Có token thì gắn thêm
    user_id để nối được với XP/tiến độ.
    """
    accepted = 0
    unknown: list[str] = []
    # Loại máy / hệ điều hành / trình duyệt — chỉ gắn vào app_open (mỗi phiên một lần).
    # Không lưu nguyên User-Agent: chỉ cần nhóm, không cần nhận dạng từng máy.
    thiet_bi = doc_thiet_bi(request.headers.get("user-agent"))

    for e in batch.events:
        if e.name not in EVENT_NAMES:
            # Bỏ qua thay vì báo lỗi: app cũ gửi tên cũ thì cũng không nên
            # làm hỏng cả gói. Tên lạ trả về để nhóm biết mà sửa.
            if e.name not in unknown:
                unknown.append(e.name)
            continue

        params = e.params
        if params is not None and len(json.dumps(params, ensure_ascii=False)) > MAX_PARAMS_CHARS:
            params = {"_bo_qua": "params qua dai"}
        if e.name == "app_open":
            params = {**(params if isinstance(params, dict) else {}), "_tb": thiet_bi}

        db.add(AnalyticsEvent(
            name=e.name,
            client_id=e.client_id[:64],
            session_id=e.session_id[:64],
            user_id=current.id if current else None,
            platform=e.platform if e.platform in ALLOWED_PLATFORMS else "other",
            target=e.target[:128] if e.target else None,
            value=e.value,
            params=params,
            client_ts=e.client_ts,
        ))
        accepted += 1

    db.commit()
    return TrackResult(accepted=accepted, rejected=len(batch.events) - accepted, unknown=unknown)


@router.get("/summary", dependencies=[Depends(require_analytics_key)])
def summary(
    days: int = Query(30, ge=1, le=365, description="Số ngày gần nhất"),
    db: Session = Depends(get_db),
):
    """Số liệu tổng hợp: người hoạt động, phễu, nội dung được xem nhiều."""
    return build_summary(db, days=days)


@router.get("/bao-cao-tuan", response_class=PlainTextResponse,
            dependencies=[Depends(require_analytics_key)])
def bao_cao_tuan_route(db: Session = Depends(get_db)):
    """Bảng Markdown 7 ngày qua so với 7 ngày trước — chép thẳng vào báo cáo tuần."""
    return PlainTextResponse(bao_cao_tuan(db), media_type="text/markdown; charset=utf-8")


@router.get("/events", response_model=list[str])
def known_events():
    """Danh mục tên sự kiện hợp lệ — để app và người viết báo cáo dùng chung."""
    return sorted(EVENT_NAMES)


@router.get("/dashboard", response_class=HTMLResponse,
            dependencies=[Depends(require_analytics_key)])
def dashboard():
    """Trang xem số liệu, mở thẳng bằng trình duyệt."""
    if not DASHBOARD_FILE.exists():
        raise HTTPException(500, "Chưa có file dashboard")
    return HTMLResponse(DASHBOARD_FILE.read_text(encoding="utf-8"))


@router.post("/xac-nhan-don", dependencies=[Depends(bat_buoc_khoa_analytics)])
def xac_nhan_don(payload: XacNhanDon, db: Session = Depends(get_db)):
    """Nút "Xác nhận tay" trên dashboard — cùng việc với `POST /thanh-toan/xac-nhan-tay`,
    nhưng bằng khoá dashboard để quản trị không phải đăng nhập app chỉ để bấm một nút."""
    ma = payload.ma_don.strip().upper()
    truoc = db.query(DonThanhToan.trang_thai).filter(DonThanhToan.ma_don == ma).scalar()
    don = tt.xac_nhan_tay(db, ma)
    if don is None:
        raise HTTPException(404, "Không tìm thấy đơn.")
    # Đơn đã trả từ trước (webhook về trước, hoặc bấm hai lần): xác nhận tay không cộng thêm
    # ngày. Cũng KHÔNG gắn khoản tiền vào đơn: đó có thể là lần chuyển khoản thứ hai của cùng
    # người — phải còn trong danh sách để quản trị tính chuyện hoàn tiền.
    vua_kich_hoat = truoc != "da_tra"
    if vua_kich_hoat and payload.sepay_id is not None:
        tt.gan_giao_dich(db, payload.sepay_id, don)
        db.commit()
    chu = db.get(User, don.user_id) if don.user_id else None
    return {"ma_don": don.ma_don, "trang_thai": "da_tra", "vua_kich_hoat": vua_kich_hoat,
            "premium_den": iso_utc(chu.premium_den) if chu else None}
