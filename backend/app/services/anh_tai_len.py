"""Ảnh đại diện người dùng tự tải lên.

HIỆN CÔNG KHAI — quyết định của nhóm (05/10): người dùng đa số đã lớn (THCS/THPT), có
đăng ảnh hay không là quyền của các bạn. Ảnh hiện ở hồ sơ, bảng vàng, bảng xếp hạng
và phòng thi. Vì ai cũng xem được nên vẫn giữ:
    - Máy chủ MỞ và VẼ LẠI ảnh (Pillow) thay vì cất nguyên tệp: ảnh CÔNG KHAI không còn
      EXIF (vị trí GPS, loại máy, giờ chụp), và tệp lạ giả đuôi ảnh không lọt qua được.

THỐNG KÊ NỘI BỘ (quyết định của nhóm 05/10, đã có cam kết với phía nhà trường):
    Trước khi bỏ EXIF, đọc VỊ TRÍ THÔ + LOẠI MÁY để biết người dùng ở vùng nào, dùng máy gì.
    Toạ độ LÀM TRÒN 1 chữ số thập phân (~11 km, cỡ quận/huyện) NGAY khi đọc — toạ độ
    chính xác không bao giờ được ghi xuống. Chỉ máy chủ giữ (users.vi_tri_anh,
    users.may_anh), không trả về trong API nào cho người khác. Đã ghi trong trang
    Quyền riêng tư (mobile/web/rieng-tu/index.html) — sửa ở đây nhớ sửa ở đó.
    - Cắt vuông giữa, thu về 320×320 JPEG — đủ nét cho vòng tròn, mỗi ảnh ~20–40 KB.
    - Đổi ảnh / chọn lại ảnh có sẵn / xoá tài khoản → xoá tệp cũ ngay.

Lưu ở backend/media/anh_dai_dien/ (gitignore). Trên VPS thư mục này cần vào bản sao
lưu đêm cùng CSDL.
"""
from __future__ import annotations

import io
import secrets
from pathlib import Path

THU_MUC = Path(__file__).resolve().parents[2] / "media" / "anh_dai_dien"
TIEN_TO = "tl-"                 # users.avatar = "tl-<mã>" (≤ 40 ký tự)
TOI_DA_BYTE = 8 * 1024 * 1024   # ảnh điện thoại mới ~3–6 MB
TOI_DA_DIEM_ANH = 50_000_000    # chặn "bom giải nén" (ảnh nhỏ nhưng khai kích thước khổng lồ)
CANH = 320
DINH_DANG = {"JPEG", "PNG", "WEBP", "GIF", "MPO"}   # MPO = ảnh chụp từ một số máy Samsung/iPhone


class AnhKhongHopLe(ValueError):
    pass


def la_anh_tai_len(avatar: str | None) -> bool:
    return bool(avatar) and avatar.startswith(TIEN_TO)


def tep_cua(avatar: str) -> Path | None:
    ma = avatar[len(TIEN_TO):]
    if not ma.isalnum():
        return None
    return THU_MUC / f"{ma}.jpg"


def _so(x) -> float:
    """Một thành phần độ/phút/giây trong EXIF (Rational hoặc tuple tử/mẫu) → số thực."""
    if isinstance(x, tuple):
        return x[0] / x[1] if x[1] else 0.0
    return float(x)


def doc_thong_tin(anh) -> dict:
    """{"vi_tri": "16.1,108.2" | None, "may": "Samsung SM-A536E" | None} từ EXIF ảnh gốc.

    Toạ độ làm tròn ~11 km NGAY TẠI ĐÂY. Ảnh không có EXIF (ảnh chụp màn hình, ảnh đã qua
    Zalo/Facebook — các app đó tự xoá EXIF) thì trả None, không đoán."""
    ra = {"vi_tri": None, "may": None}
    try:
        exif = anh.getexif()
    except Exception:  # noqa: BLE001 — EXIF hỏng không được làm hỏng việc đổi ảnh
        return ra
    hang, may = (exif.get(0x010F) or "").strip(), (exif.get(0x0110) or "").strip()
    if may:
        ra["may"] = (may if hang and may.lower().startswith(hang.lower()) else f"{hang} {may}".strip())[:80]
    try:
        gps = exif.get_ifd(0x8825)
        if gps.get(2) and gps.get(4):
            lat = sum(_so(v) / 60 ** i for i, v in enumerate(gps[2]))
            lon = sum(_so(v) / 60 ** i for i, v in enumerate(gps[4]))
            lat = -lat if str(gps.get(1, "N")).upper().startswith("S") else lat
            lon = -lon if str(gps.get(3, "E")).upper().startswith("W") else lon
            if -90 <= lat <= 90 and -180 <= lon <= 180 and (lat, lon) != (0, 0):
                ra["vi_tri"] = f"{round(lat, 1)},{round(lon, 1)}"
    except Exception:  # noqa: BLE001
        pass
    return ra


def xu_ly(du_lieu: bytes) -> tuple[bytes, dict]:
    """Ảnh thô → (JPEG 320×320 sạch, thông tin thô cho thống kê nội bộ).
    Ném AnhKhongHopLe kèm lý do tiếng Việt."""
    from PIL import Image, ImageOps, UnidentifiedImageError

    if len(du_lieu) > TOI_DA_BYTE:
        raise AnhKhongHopLe("Ảnh lớn quá 8 MB — chọn ảnh khác nhé.")
    Image.MAX_IMAGE_PIXELS = TOI_DA_DIEM_ANH
    try:
        anh = Image.open(io.BytesIO(du_lieu))
        if anh.format not in DINH_DANG:
            raise AnhKhongHopLe("Chỉ nhận ảnh JPG, PNG, WEBP hoặc GIF.")
        anh.load()
    except AnhKhongHopLe:
        raise
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError, ValueError):
        raise AnhKhongHopLe("Tệp này không phải ảnh, hoặc ảnh bị hỏng.") from None
    thong_tin = doc_thong_tin(anh)              # ĐỌC TRƯỚC khi vẽ lại (vẽ lại là mất EXIF)
    anh = ImageOps.exif_transpose(anh)          # ảnh chụp dọc vẫn đứng đúng chiều
    anh = ImageOps.fit(anh.convert("RGB"), (CANH, CANH), method=Image.LANCZOS)
    ra = io.BytesIO()
    anh.save(ra, "JPEG", quality=86, optimize=True)   # lưu mới: không mang theo EXIF
    return ra.getvalue(), thong_tin


def luu(jpeg: bytes) -> str:
    THU_MUC.mkdir(parents=True, exist_ok=True)
    ma = secrets.token_hex(12)
    (THU_MUC / f"{ma}.jpg").write_bytes(jpeg)
    return TIEN_TO + ma


def xoa(avatar: str | None) -> None:
    if la_anh_tai_len(avatar):
        p = tep_cua(avatar)
        if p is not None:
            p.unlink(missing_ok=True)


def url(avatar: str | None) -> str | None:
    """Đường dẫn ảnh tải lên (tương đối, app ghép với địa chỉ máy chủ). Ảnh trong bộ có
    sẵn hoặc chưa đặt ảnh → None: app tự vẽ từ mã `avatar`."""
    if not la_anh_tai_len(avatar):
        return None
    # KHÔNG có đuôi .jpg: nginx có khối riêng cho *.jpg (ảnh tĩnh của web) đứng trước
    # khối /api/ → đường dẫn đuôi .jpg không bao giờ tới được API (404 của nginx, 05/10).
    return f"/api/v1/anh-dai-dien/{avatar[len(TIEN_TO):]}"


def cua_nhieu_nguoi(db, user_ids) -> dict[int, dict]:
    """{user_id: {"avatar": mã, "avatar_url": url|None}} — cho bảng vàng / bảng xếp hạng."""
    from app.models.user import User
    ids = {i for i in user_ids if i}
    if not ids:
        return {}
    return {u.id: {"avatar": u.avatar, "avatar_url": url(u.avatar)}
            for u in db.query(User.id, User.avatar).filter(User.id.in_(ids)).all()}
