"""Route xác thực: đăng ký, đăng nhập, đăng xuất, quên mật khẩu, thông tin user."""
import hashlib
import html
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, Request, UploadFile, status
from fastapi.responses import FileResponse
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_payload, get_current_user
from app.core.anh_dai_dien import ANH_DAI_DIEN
from app.core.config import settings
from app.core.security import (
    create_access_token,
    generate_token_pair,
    hash_password,
    verify_password,
)
from app.db.session import get_db
from app.models.analytics import AnalyticsEvent
from app.models.phan_hoi import PhanHoi
from app.models.lop_hoc import BaiThi, DeKiemTra, PhongThi
from app.models.phien import MaDatLai, TokenThuHoi
from app.models.progress import UserProgress
from app.models.quiz_attempt import QuizAttempt
from app.models.thanh_toan import DonThanhToan, LuotChatNgay
from app.models.user import User
from app.services import anh_tai_len, google_dang_nhap, gui_email
from app.services.lop_co_dinh import xoa_du_lieu_mo_rong
from app.services.gioi_han_dang_nhap import (
    dang_nhap_dung,
    ghi_sai,
    kiem_dang_ky,
    kiem_dang_nhap,
    kiem_dat_lai,
    kiem_quen_mat_khau,
)
from app.schemas.auth import (
    DangNhapGoogle,
    DatLaiMatKhau,
    DoiMatKhau,
    ErrorResponse,
    QuenMatKhau,
    RefreshRequest,
    Token,
    UserOut,
    UserRegister,
    UserUpdate,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _error(code: str, message: str, status_code: int = 400):
    """Trả về HTTPException với response body chuẩn hoá."""
    raise HTTPException(status_code, detail=ErrorResponse(error={"code": code, "message": message}).model_dump())


@router.post("/register", response_model=UserOut, status_code=201)
def register(payload: UserRegister, request: Request, db: Session = Depends(get_db)):
    kiem_dang_ky(request)   # chặn tạo tài khoản rác — xem services/gioi_han_dang_nhap.py
    if db.query(User).filter(User.email == payload.email).first():
        _error("EMAIL_EXISTS", "Email đã tồn tại", 400)
    user = User(
        email=payload.email,
        full_name=payload.full_name,
        hashed_password=hash_password(payload.password),
        # KHÔNG lấy vai trò từ người gửi: trước 05/10 ai gọi thẳng API kèm "role":
        # "teacher" là thành giáo viên, khỏi cần mã. Nâng vai trò chỉ qua
        # /auth/lam-giao-vien (có mã) hoặc tools/tao_quan_tri.py trên máy chủ.
        role="student",
        grade=payload.grade,
        nguon=payload.nguon,
        kenh=payload.kenh,
        chien_dich=payload.chien_dich,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return UserOut.tu(user)


@router.post("/login", response_model=Token)
def login(request: Request, form: OAuth2PasswordRequestForm = Depends(),
          db: Session = Depends(get_db)):
    # OAuth2PasswordRequestForm dùng field "username" — ở đây ta truyền email vào đó
    # Tên ngắn không có "@" (vd tài khoản quản trị của nhóm) = <tên>@historiai.org.
    # Không đụng ai khác: mọi email đăng ký đều đã có "@".
    ten = form.username.strip()
    if "@" not in ten:
        ten = f"{ten}@historiai.org"
    khoa = kiem_dang_nhap(request, ten)   # chặn dò mật khẩu: chỉ đếm lần SAI
    user = db.query(User).filter(User.email == ten).first()
    if not user or not verify_password(form.password, user.hashed_password):
        ghi_sai(khoa)
        _error("INVALID_CREDENTIALS", "Sai email hoặc mật khẩu", 401)
    dang_nhap_dung(khoa)
    tokens = generate_token_pair(str(user.id), user.token_version or 0)
    user.refresh_token = tokens["refresh_token"]
    db.commit()
    return Token(**tokens)


@router.post("/google", response_model=Token)
def dang_nhap_google(payload: DangNhapGoogle, request: Request, db: Session = Depends(get_db)):
    """Đăng nhập / đăng ký bằng tài khoản Google — một nút cho cả hai việc.

    Email đã có tài khoản (kể cả tài khoản tạo bằng mật khẩu) → đăng nhập vào
    đúng tài khoản đó. Nối theo email là an toàn vì Google đã xác minh email
    (email_verified), tức người này đúng là chủ hộp thư — cũng là điều kiện để
    đặt lại mật khẩu qua email.

    Email chưa có → tạo tài khoản mới, mật khẩu ngẫu nhiên không ai biết. Muốn
    đăng nhập bằng mật khẩu sau này thì dùng "Quên mật khẩu?" để đặt.
    """
    if not google_dang_nhap.client_ids():
        _error("GOOGLE_OFF", "Đăng nhập bằng Google đang tạm tắt. Hãy dùng email và mật khẩu.", 503)
    try:
        info = google_dang_nhap.kiem(payload.id_token)
    except google_dang_nhap.MaGoogleSai:
        _error("GOOGLE_INVALID", "Không xác minh được tài khoản Google. Hãy thử lại.", 401)
    user = db.query(User).filter(func.lower(User.email) == info["email"]).first()
    moi_tao = user is None
    if moi_tao:
        kiem_dang_ky(request)   # cùng giới hạn tạo tài khoản với đăng ký thường
        user = User(
            email=info["email"],
            full_name=info["ten"] or info["email"].split("@")[0],
            hashed_password=hash_password(secrets.token_urlsafe(32)),
            co_mat_khau=False,          # mật khẩu ngẫu nhiên, chủ tài khoản không biết
            role="student",
            grade=payload.grade,
            nguon=payload.nguon,
            kenh=payload.kenh,
            chien_dich=payload.chien_dich,
        )
        db.add(user)
        db.flush()
    user.google_sub = info["sub"]
    tokens = generate_token_pair(str(user.id), user.token_version or 0)
    user.refresh_token = tokens["refresh_token"]
    db.commit()
    # moi_tao: app ghi signup_success thay vì login_success — phễu đăng ký không hụt
    # những người đăng ký bằng Google.
    return Token(**tokens, moi_tao=moi_tao)


@router.post("/refresh", response_model=Token)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)):
    """Cấp access token mới từ refresh token."""
    user = db.query(User).filter(User.refresh_token == payload.refresh_token).first()
    if not user:
        _error("INVALID_REFRESH_TOKEN", "Refresh token không hợp lệ", 401)
    tokens = generate_token_pair(str(user.id), user.token_version or 0)
    user.refresh_token = tokens["refresh_token"]
    db.commit()
    return Token(**tokens)


@router.post("/logout", status_code=204)
def dang_xuat(
    moi_noi: bool = False,
    kq: tuple[User, dict] = Depends(get_current_payload),
    db: Session = Depends(get_db),
):
    """Thu hồi mã đăng nhập đang dùng. `?moi_noi=true`: thu hồi MỌI mã của tài
    khoản (máy mượn của bạn, máy tính ở trường…) bằng cách tăng đời mã."""
    user, payload = kq
    if moi_noi:
        user.token_version = (user.token_version or 0) + 1
        user.refresh_token = None
    elif payload.get("jti"):
        het_han = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        db.merge(TokenThuHoi(jti=payload["jti"], het_han=het_han))
    # Dọn dòng đã quá hạn — mã tự hết hạn rồi thì không cần sổ thu hồi nữa.
    db.query(TokenThuHoi).filter(TokenThuHoi.het_han < datetime.now(timezone.utc)).delete(
        synchronize_session=False)
    db.commit()
    return None


HAN_MA_DAT_LAI = timedelta(minutes=30)
_TRA_LOI_CHUNG = {"message": "Nếu email này đã đăng ký, thư hướng dẫn sẽ tới trong vài phút. "
                             "Nhớ xem cả mục Thư rác."}


def _bam(ma: str) -> str:
    return hashlib.sha256(ma.encode("utf-8")).hexdigest()


def _thu_dat_lai(ten: str, link: str) -> tuple[str, str]:
    phut = int(HAN_MA_DAT_LAI.total_seconds() // 60)
    van_ban = f"""Chào {ten},

Có người (có thể là bạn) vừa yêu cầu đặt lại mật khẩu HistoriAI cho email này.
Mở link sau để đặt mật khẩu mới — link dùng được một lần, trong {phut} phút:

{link}

Nếu bạn không yêu cầu, cứ bỏ qua thư này. Mật khẩu hiện tại vẫn giữ nguyên.

— Nhóm HistoriAI"""
    t, l = html.escape(ten), html.escape(link, quote=True)
    trang = f"""<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;color:#2B1410;
background:#FDF9F4;padding:28px;border-radius:12px">
<h2 style="color:#BA2323;margin-top:0">Đặt lại mật khẩu HistoriAI</h2>
<p>Chào {t},</p>
<p>Có người (có thể là bạn) vừa yêu cầu đặt lại mật khẩu cho email này.</p>
<p style="text-align:center;margin:28px 0"><a href="{l}" style="background:#BA2323;color:#fff;
padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:bold">Đặt mật khẩu mới</a></p>
<p style="color:#7C5A4A;font-size:14px">Link dùng được một lần, trong {phut} phút.
Nếu bạn không yêu cầu, cứ bỏ qua thư này — mật khẩu hiện tại vẫn giữ nguyên.</p>
<p style="color:#7C5A4A;font-size:14px">— Nhóm HistoriAI</p></div>"""
    return van_ban, trang


@router.post("/quen-mat-khau")
def quen_mat_khau(payload: QuenMatKhau, request: Request, bg: BackgroundTasks,
                  db: Session = Depends(get_db)):
    """Gửi link đặt lại mật khẩu. Luôn trả CÙNG một câu, dù email có tài khoản hay
    không — không để form này thành công cụ dò xem ai đã đăng ký."""
    if not gui_email.da_bat():
        _error("EMAIL_OFF", "Tính năng gửi thư đang tạm tắt. Hãy nhắn fanpage HistoriAI để được hỗ trợ.", 503)
    kiem_quen_mat_khau(request, payload.email)
    user = db.query(User).filter(User.email == payload.email).first()
    if user is not None:
        # Mỗi lần yêu cầu mới làm vô hiệu các mã cũ chưa dùng.
        db.query(MaDatLai).filter(MaDatLai.user_id == user.id, MaDatLai.da_dung.is_(False)).update(
            {MaDatLai.da_dung: True}, synchronize_session=False)
        ma = secrets.token_urlsafe(32)
        db.add(MaDatLai(user_id=user.id, ma_bam=_bam(ma),
                        het_han=datetime.now(timezone.utc) + HAN_MA_DAT_LAI))
        db.commit()
        goc = settings.RESET_URL or f"{settings.PUBLIC_BASE_URL.rstrip('/')}/dat-lai-mat-khau/"
        # Mã đặt sau dấu # : trình duyệt không gửi phần này lên máy chủ, nên mã không
        # nằm trong nhật ký nginx/Cloudflare.
        van_ban, trang = _thu_dat_lai(user.full_name, f"{goc}#ma={ma}")
        bg.add_task(gui_email.gui, user.email, "Đặt lại mật khẩu HistoriAI", van_ban, trang)
    return _TRA_LOI_CHUNG


@router.post("/dat-lai-mat-khau")
def dat_lai_mat_khau(payload: DatLaiMatKhau, request: Request, db: Session = Depends(get_db)):
    kiem_dat_lai(request)
    ban_ghi = db.query(MaDatLai).filter(MaDatLai.ma_bam == _bam(payload.ma)).first()
    het_han = ban_ghi.het_han if ban_ghi else None
    if het_han is not None and het_han.tzinfo is None:       # SQLite trả về không múi giờ
        het_han = het_han.replace(tzinfo=timezone.utc)
    if ban_ghi is None or ban_ghi.da_dung or het_han < datetime.now(timezone.utc):
        _error("RESET_INVALID", "Link đã hết hạn hoặc đã dùng rồi. Hãy yêu cầu gửi lại thư.", 400)
    user = db.get(User, ban_ghi.user_id)
    if user is None:
        _error("RESET_INVALID", "Link đã hết hạn hoặc đã dùng rồi. Hãy yêu cầu gửi lại thư.", 400)
    user.hashed_password = hash_password(payload.mat_khau_moi)
    user.co_mat_khau = True
    # Đổi mật khẩu thì đá văng mọi phiên cũ — lý do hay gặp nhất để đặt lại mật khẩu
    # là nghi có người khác đang dùng tài khoản.
    user.token_version = (user.token_version or 0) + 1
    user.refresh_token = None
    ban_ghi.da_dung = True
    db.commit()
    return {"message": "Đã đổi mật khẩu. Hãy đăng nhập lại bằng mật khẩu mới."}


@router.get("/me", response_model=UserOut)
def me(current: User = Depends(get_current_user)):
    return UserOut.tu(current)


@router.patch("/me", response_model=UserOut)
def cap_nhat_toi(
    payload: UserUpdate,
    current: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Sửa thông tin của chính mình: lớp đang học, họ tên, ảnh đại diện."""
    doi = payload.model_fields_set
    if "grade" in doi:
        current.grade = payload.grade
    if "full_name" in doi and payload.full_name:
        current.full_name = payload.full_name
    if "avatar" in doi:
        if payload.avatar is not None and payload.avatar not in ANH_DAI_DIEN:
            _error("AVATAR_INVALID", "Ảnh đại diện không có trong bộ ảnh.", 422)
        if payload.avatar != current.avatar:
            anh_tai_len.xoa(current.avatar)     # bỏ ảnh tự tải lên cũ, không để tệp mồ côi
        current.avatar = payload.avatar
    db.commit()
    db.refresh(current)
    return UserOut.tu(current)


_luot_tai_anh: dict[int, list[float]] = {}


@router.post("/me/anh-dai-dien", response_model=UserOut)
async def tai_anh_dai_dien(
    anh: UploadFile = File(...),
    current: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Tải ảnh đại diện riêng (multipart, trường `anh`). Máy chủ cắt vuông, thu nhỏ và
    vẽ lại ảnh (bỏ EXIF) — xem services/anh_tai_len.py. Tối đa 20 lần / giờ / người."""
    import time
    bay_gio = time.monotonic()
    gan_day = [t for t in _luot_tai_anh.get(current.id, []) if bay_gio - t < 3600]
    if len(gan_day) >= 20:
        _error("UPLOAD_LIMIT", "Em đổi ảnh nhiều quá — thử lại sau ít phút nhé.", 429)
    du_lieu = await anh.read(anh_tai_len.TOI_DA_BYTE + 1)
    try:
        jpeg, thong_tin = anh_tai_len.xu_ly(du_lieu)
    except anh_tai_len.AnhKhongHopLe as e:
        _error("AVATAR_INVALID", str(e), 422)
    cu = current.avatar
    current.avatar = anh_tai_len.luu(jpeg)
    if thong_tin["vi_tri"]:
        current.vi_tri_anh = thong_tin["vi_tri"]
    if thong_tin["may"]:
        current.may_anh = thong_tin["may"]
    db.commit()
    anh_tai_len.xoa(cu)
    _luot_tai_anh[current.id] = gan_day + [bay_gio]
    db.refresh(current)
    return UserOut.tu(current)


@router.delete("/me/anh-dai-dien", response_model=UserOut)
def go_anh_dai_dien(current: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Gỡ ảnh tự tải lên, quay về ảnh mặc định."""
    cu = current.avatar
    current.avatar = None
    db.commit()
    anh_tai_len.xoa(cu)
    db.refresh(current)
    return UserOut.tu(current)


@router.post("/doi-mat-khau", response_model=Token)
def doi_mat_khau(
    payload: DoiMatKhau,
    request: Request,
    kq: tuple[User, dict] = Depends(get_current_payload),
    db: Session = Depends(get_db),
):
    """Đổi mật khẩu (hoặc ĐẶT lần đầu cho tài khoản tạo bằng Google).

    Có mật khẩu rồi thì phải nhập đúng mật khẩu cũ — mượn máy đang đăng nhập sẵn
    không đủ để chiếm tài khoản. Sai mật khẩu cũ bị đếm chung giới hạn dò mật khẩu.
    Đổi xong: mọi máy khác bị đăng xuất, máy này nhận mã đăng nhập mới.
    """
    user, _ = kq
    if user.co_mat_khau is not False:
        khoa = kiem_dang_nhap(request, user.email)
        if not payload.mat_khau_cu or not verify_password(payload.mat_khau_cu, user.hashed_password):
            ghi_sai(khoa)
            _error("WRONG_PASSWORD", "Mật khẩu hiện tại chưa đúng.", 400)
        dang_nhap_dung(khoa)
    user.hashed_password = hash_password(payload.mat_khau_moi)
    user.co_mat_khau = True
    user.token_version = (user.token_version or 0) + 1
    tokens = generate_token_pair(str(user.id), user.token_version)
    user.refresh_token = tokens["refresh_token"]
    db.commit()
    return Token(**tokens)


@router.delete("/me", status_code=204)
def xoa_tai_khoan(
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    """Người dùng tự xoá tài khoản của mình, không cần hỏi ai.

    VÌ SAO CẦN
        App thu email, họ tên, lịch sử làm bài và hành vi sử dụng của người
        dùng phần lớn là trẻ vị thành niên. Cho người ta rút lui là mức tối
        thiểu — chưa bàn tới việc Google Play bắt buộc phải có đường xoá tài
        khoản nếu sau này nhóm đưa app lên cửa hàng.

    XOÁ THẬT, KHÔNG ĐÁNH DẤU
        Tiến độ học và lịch sử làm bài xoá hẳn cùng tài khoản.

        Riêng sự kiện đo lường thì GỠ LIÊN KẾT chứ không xoá dòng: chúng là
        số liệu tổng hợp ẩn danh (bao nhiêu người mở app, bao nhiêu người làm
        hết quiz), xoá đi là thủng số liệu của cả nhóm mà chẳng bảo vệ thêm
        được gì — sau khi bỏ user_id thì dòng đó không còn chỉ về ai nữa.
    """
    uid = current.id
    anh_tai_len.xoa(current.avatar)
    db.query(UserProgress).filter(UserProgress.user_id == uid).delete(
        synchronize_session=False)
    db.query(QuizAttempt).filter(QuizAttempt.user_id == uid).delete(
        synchronize_session=False)
    db.query(AnalyticsEvent).filter(AnalyticsEvent.user_id == uid).update(
        {AnalyticsEvent.user_id: None}, synchronize_session=False)
    # Phản hồi thì XOÁ HẲN chứ không gỡ liên kết: lời góp ý là chữ người dùng tự gõ,
    # có thể có tên, trường, số điện thoại — không còn là số liệu ẩn danh.
    db.query(PhanHoi).filter(PhanHoi.user_id == uid).delete(synchronize_session=False)
    db.query(MaDatLai).filter(MaDatLai.user_id == uid).delete(synchronize_session=False)
    # Thanh toán: đơn đang chờ xoá hẳn; đơn ĐÃ TRẢ gỡ liên kết nhưng giữ lại làm chứng từ
    # đối soát tiền thật (cùng nguyên tắc với sự kiện đo lường ở trên). Số đếm hỏi chat hết ý nghĩa.
    db.query(DonThanhToan).filter(DonThanhToan.user_id == uid, DonThanhToan.trang_thai != "da_tra"
                                  ).delete(synchronize_session=False)
    db.query(DonThanhToan).filter(DonThanhToan.user_id == uid).update(
        {DonThanhToan.user_id: None}, synchronize_session=False)
    db.query(LuotChatNgay).filter(LuotChatNgay.doi_tuong == f"u:{uid}").delete(
        synchronize_session=False)
    # Lớp học: bài thi của chính em (có tên thật em tự gõ) xoá hẳn. Là giáo viên thì
    # đề, phòng và bài của học sinh trong các phòng ấy cũng xoá theo — không để dữ
    # liệu của cả lớp nằm lại dưới một tài khoản đã không còn.
    db.query(BaiThi).filter(BaiThi.user_id == uid).delete(synchronize_session=False)
    # GĐ3: câu tự soạn, lớp cố định, tên em trong danh sách lớp — trước khi xoá phòng.
    xoa_du_lieu_mo_rong(db, uid)
    phong_ids = [i for (i,) in db.query(PhongThi.id).filter(PhongThi.giao_vien_id == uid).all()]
    if phong_ids:
        db.query(BaiThi).filter(BaiThi.phong_id.in_(phong_ids)).delete(synchronize_session=False)
        db.query(PhongThi).filter(PhongThi.id.in_(phong_ids)).delete(synchronize_session=False)
    db.query(DeKiemTra).filter(DeKiemTra.giao_vien_id == uid).delete(synchronize_session=False)
    db.delete(current)
    db.commit()
    return None


anh_router = APIRouter(tags=["auth"])


@anh_router.get("/anh-dai-dien/{ten}")
def phat_anh_dai_dien(ten: str):
    """Phát ảnh đại diện đã xử lý. Tên = mã ngẫu nhiên (không đuôi — xem anh_tai_len.url);
    đổi ảnh là đổi tên nên cho trình duyệt / Cloudflare giữ lâu thoải mái."""
    ma = ten[:-4] if ten.endswith(".jpg") else ten
    if not ma.isalnum() or len(ma) > 40:
        raise HTTPException(404, "Không có ảnh")
    p = anh_tai_len.tep_cua(anh_tai_len.TIEN_TO + ma)
    if p is None or not p.exists():
        raise HTTPException(404, "Không có ảnh")
    return FileResponse(p, media_type="image/jpeg",
                        headers={"Cache-Control": "public, max-age=31536000, immutable"})
