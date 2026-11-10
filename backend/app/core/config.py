"""Cấu hình tập trung, đọc từ biến môi trường (.env)."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    PROJECT_NAME: str = "HistoriAI API"
    API_V1_PREFIX: str = "/api/v1"

    # Database — mặc định dùng PostgreSQL qua docker-compose
    DATABASE_URL: str = "postgresql://historiai:historiai@localhost:5432/historiai"

    # Bảo mật JWT
    SECRET_KEY: str = "change-me-in-production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 ngày
    ALGORITHM: str = "HS256"

    # Địa chỉ công khai của API (dùng để dựng link file audio trả về client).
    # Để trống = suy ra từ request. Phải ĐẶT khi chạy sau proxy/tunnel: nginx nhận
    # kết nối HTTP nội bộ nên request.url_for() sinh ra "http://", trình duyệt ở
    # trang HTTPS sẽ chặn vì nội dung hỗn hợp.
    PUBLIC_BASE_URL: str = ""

    # CORS — cho phép app mobile / web gọi vào
    # Mặc định CHỈ cho localhost. Đừng để "*" ở đây: ghép với
    # allow_credentials=True là tổ hợp bị đặc tả CORS cấm, và bất kỳ ai dựng
    # bản mới mà quên đặt biến môi trường sẽ chạy với cấu hình sai.
    # Production đặt qua .env: CORS_ORIGINS=https://historiai.anhzap.shop
    CORS_ORIGINS: str = "http://localhost:8080,http://127.0.0.1:8080"

    # Khoá API dịch vụ ngoài (để trống ở MVP, mock nếu chưa có)
    LLM_API_KEY: str = ""
    # Endpoint LLM tương thích OpenAI. Mặc định dùng Groq: miễn phí, không cần
    # thẻ, và nhanh nhất trong nhóm free (chạy trên LPU).
    LLM_BASE_URL: str = "https://api.groq.com/openai/v1"
    LLM_MODEL: str = "qwen/qwen3.8-27b"
    # KHÔNG dùng reasoning model cho chat nhập vai: nó sinh khối <think> phải cắt
    # bỏ, chậm và tốn token cho phần người dùng không bao giờ thấy.
    LLM_TIMEOUT: float = 30.0
    LLM_MAX_TOKENS: int = 800
    # TTS giọng nói nhân vật
    # Chọn nhà cung cấp:
    #   "edge"       — Microsoft Edge TTS: giọng neural tiếng Việt, MIỄN PHÍ, không cần
    #                  key, không cần GPU. Dùng khi deploy lên máy chủ thường.
    #   "vieneu"     — VieNeu-TTS chạy CPU trên chính máy chủ (vieneu_service/), giọng
    #                  nhân bản theo nhân vật, stream được. Lỗi/quá tải → TTS_DU_PHONG.
    #   "vixtts"     — chạy local trên GPU, giọng clone được theo nhân vật
    #   "elevenlabs" — trả phí
    #   "none"       — tắt hẳn giọng
    TTS_PROVIDER: str = "vixtts"
    TTS_TIMEOUT: float = 60.0
    # Thư mục lưu cache audio (tránh gọi lại TTS cho cùng câu -> tiết kiệm)
    AUDIO_CACHE_DIR: str = "audio_cache"

    # --- VieNeu-TTS micro-service (CPU, xem vieneu_service/) ---
    VIENEU_URL: str = "http://127.0.0.1:8510"
    # Nhà cung cấp dùng khi VieNeu lỗi hoặc đang bận ("edge" | "none").
    TTS_DU_PHONG: str = "edge"

    # --- viXTTS micro-service (chạy local trên GPU, xem vixtts_service/) ---
    VIXTTS_URL: str = "http://127.0.0.1:8500"

    # --- ElevenLabs (dự phòng) ---
    ELEVENLABS_API_KEY: str = ""
    ELEVENLABS_MODEL: str = "eleven_multilingual_v2"

    # Khoá xem số liệu đo lường (/analytics/summary và /analytics/dashboard).
    # Để trống = ai biết URL cũng xem được — chỉ chấp nhận khi chạy máy nhà.
    # Khi deploy phải đặt giá trị, rồi mở dashboard kèm ?key=...
    ANALYTICS_KEY: str = ""

    # --- Gửi email (quên mật khẩu) ---
    # Để trống SMTP_USER = tắt tính năng: /auth/quen-mat-khau trả 503 và app hiện
    # hướng dẫn liên hệ nhóm. Gmail: bật xác minh 2 bước rồi tạo "Mật khẩu ứng dụng"
    # (16 ký tự) — KHÔNG dùng mật khẩu Gmail thật. Chỉ đặt trong .env trên máy chủ.
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = ""          # để trống = dùng SMTP_USER (Gmail bắt buộc trùng)
    SMTP_TEN: str = "HistoriAI"
    # Trang đặt lại mật khẩu (web tĩnh, mobile/web/dat-lai-mat-khau/). Để trống =
    # PUBLIC_BASE_URL + "/dat-lai-mat-khau/".
    RESET_URL: str = ""

    # --- Đăng nhập bằng Google — để trống là tắt (/auth/google trả 503) ---
    # "OAuth client ID" loại Web application trong Google Cloud Console. Không phải bí
    # mật (nằm sẵn trong app). Nhiều ID (web + Android) thì ngăn bằng dấu phẩy.
    GOOGLE_CLIENT_IDS: str = ""

    # --- Lớp học: mã để nâng tài khoản lên vai trò giáo viên ---
    # Nhóm phát mã này cho giáo viên dùng thử (không cho tự đăng ký làm giáo viên, kẻo
    # học sinh tự mở phòng). Để trống = không ai nâng được. Chỉ đặt trong .env.
    MA_GIAO_VIEN: str = ""

    # --- Premium: thanh toán chuyển khoản QR qua SePay (docs/THANH_TOAN_SEPAY.md) ---
    # Thiếu BIN, SO_TK hoặc CHU_TK = chưa bật: /thanh-toan/goi trả bat=false và
    # /thanh-toan/don trả 503, app giữ màn cũ. Chỉ đặt trong .env trên máy chủ.
    THANH_TOAN_BIN: str = ""        # mã BIN 6 số của ngân hàng theo NAPAS (970422 = MB Bank)
    THANH_TOAN_TEN_NH: str = ""     # tên ngân hàng để hiện cho người chuyển
    THANH_TOAN_SO_TK: str = ""
    THANH_TOAN_CHU_TK: str = ""
    # Khoá SePay gửi kèm webhook ("Authorization: Apikey <khoá>"). Để trống thì
    # webhook từ chối mọi lời gọi — không bao giờ nhận khi chưa có khoá.
    SEPAY_WEBHOOK_KEY: str = ""

    # Hạn mức hỏi vĩ nhân MỖI NGÀY cho bản miễn phí (Premium không bị giới hạn này).
    # Câu gợi ý soạn sẵn không gọi AI nên không tính.
    CHAT_MIEN_PHI_NGAY: int = 10    # tài khoản đã đăng nhập
    CHAT_KHACH_NGAY: int = 5        # khách chưa đăng nhập

    # --- Theo dõi lỗi (Sentry) — để trống là tắt ---
    SENTRY_DSN: str = ""
    SENTRY_ENV: str = "production"

    # URL gốc lưu asset 3D/video (CDN/Firebase Storage)
    ASSET_BASE_URL: str = "https://storage.example.com/historiai"


settings = Settings()
