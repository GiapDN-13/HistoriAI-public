"""Route bài học theo lộ trình — xem app/services/lo_trinh.py."""
from fastapi import APIRouter, Depends, Response

from app.api.deps import get_current_user_optional
from app.models.user import User
from app.schemas.content import LoTrinhOut
from app.services import lo_trinh
from app.services.thanh_toan import duoc_xem_day_du

router = APIRouter(tags=["content"])


@router.get("/lo-trinh", response_model=list[LoTrinhOut])
def ds_lo_trinh(response: Response, user: User | None = Depends(get_current_user_optional)):
    """Các lộ trình ĐÃ DUYỆT. Công khai như /events: khách chưa đăng nhập cũng học được
    (bài đầu mỗi lộ trình đủ nội dung; bài sau cắt bớt, xem `lo_trinh.da_duyet`)."""
    # Cùng một địa chỉ nhưng nội dung đổi theo người gọi: nếu có lớp đệm nào ở giữa
    # (CDN, trình duyệt) thì không được đưa bản đủ của người Premium cho khách.
    response.headers["Vary"] = "Authorization"
    response.headers["Cache-Control"] = "private, no-cache"
    return lo_trinh.da_duyet(day_du=duoc_xem_day_du(user))
