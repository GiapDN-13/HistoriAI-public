# Bật gửi email (quên mật khẩu) và theo dõi lỗi (Sentry)

Code đã có sẵn trên máy chủ, chỉ cần điền cấu hình. Chưa điền thì:
- "Quên mật khẩu?" báo *"Tính năng gửi thư đang tạm tắt…"* (không hỏng gì khác).
- Sentry tắt hẳn, không gửi gì đi.

---

## 1. Email — Gmail của team

> Mật khẩu ứng dụng **chỉ gõ trên VPS**, không dán vào chat, không commit.

1. Đăng nhập Gmail của team → <https://myaccount.google.com/security> → bật **Xác minh 2 bước**.
2. Vào <https://myaccount.google.com/apppasswords> → đặt tên `HistoriAI` → **Tạo** → chép chuỗi 16 ký tự.
3. Trên máy mình:
   ```bash
   ssh giapdn@100.65.123.107
   nano ~/historiai/backend/.env
   ```
   Thêm vào cuối:
   ```
   SMTP_USER=tengmailcuateam@gmail.com
   SMTP_PASSWORD=chuoi16kytu     # bỏ dấu cách
   SMTP_TEN=HistoriAI
   ```
   Lưu (Ctrl+O, Enter, Ctrl+X), rồi khởi động lại API:
   ```bash
   kill $(systemctl show -p MainPID --value historiai)   # systemd tự bật lại sau 5 giây
   ```
4. Thử: mở <https://historiai.org/dat-lai-mat-khau/>, nhập email tài khoản của mình → thư tới (xem cả Thư rác).

Giới hạn Gmail thường: ~500 thư/ngày — dư cho quên mật khẩu. Máy chủ tự chặn 3 thư/giờ cho mỗi email.

## 2. Sentry — theo dõi lỗi

1. Tạo tài khoản miễn phí ở <https://sentry.io> (gói Developer).
2. Tạo **2 project**:
   - `historiai-api` — nền tảng **FastAPI**
   - `historiai-app` — nền tảng **Flutter**
3. Mỗi project: **Settings → Security & Privacy** → bật **Prevent Storing of IP Addresses**
   và **Data Scrubber** (người dùng phần lớn là học sinh vị thành niên).
4. Lấy **DSN** của từng project (Settings → Client Keys). DSN không phải bí mật
   (nó nằm sẵn trong app phát ra), gửi cho người dựng bản là được.
5. Backend: thêm vào `~/historiai/backend/.env` dòng `SENTRY_DSN=<DSN của historiai-api>`, rồi khởi động lại như bước 1.3.
6. App: dựng lại web và APK kèm DSN:
   ```bash
   flutter build web --release --dart-define=API_BASE_URL=https://historiai.org --dart-define=SENTRY_DSN=<DSN historiai-app>
   flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://historiai.org --dart-define=SENTRY_DSN=<DSN historiai-app>
   ```
   APK mới thì **tăng số build** trong `pubspec.yaml` (`0.2.0+2` → `0.2.1+3`) để máy đã cài được báo.

Đã cố ý **không** gửi: thân request (chữ chat, mật khẩu), header đăng nhập, chuỗi truy vấn (`?key=` dashboard), ảnh chụp màn hình, đo hiệu năng. Xem `backend/app/core/theo_doi_loi.py` và `mobile/lib/main.dart`.

## 3. Header bảo mật (một lần, cần sudo)

```bash
scp docs/ap-header-bao-mat.sh giapdn@100.65.123.107:~/
ssh -t giapdn@100.65.123.107 'sudo bash ~/ap-header-bao-mat.sh'
```
Kịch bản tự sao lưu, `nginx -t` lỗi thì tự khôi phục; chạy lại nhiều lần không sao.

## 4. Phát hành bản cài Android mới

1. Tăng `version:` trong `mobile/pubspec.yaml` — **số sau dấu `+` bắt buộc tăng**.
2. `flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://historiai.org`
3. `python tool/dong_goi_ban_cai.py --ghi-chu "Sửa lỗi…"` (thêm `--bat-buoc` nếu bản cũ hỏng nặng)
4. Chép `build/tai-app/*` lên `~/historiai/web/tai-app/`. Máy đã cài bản ≥ 0.2.0 sẽ được hỏi tải bản mới ở lần mở app kế tiếp.
   (Bản 0.1.0 không có chức năng này — người dùng bản đó phải tự tải lại một lần.)

## 5. Đăng nhập bằng Google

Code đã có (`/auth/google`, nút "Tiếp tục với Google" ở màn đăng nhập và đăng ký).
Nút **ẩn** tới khi dựng app kèm client ID; máy chủ trả 503 tới khi điền `GOOGLE_CLIENT_IDS`.

1. <https://console.cloud.google.com> (đăng nhập Gmail của team) → **Tạo project** `HistoriAI`.
2. **APIs & Services → OAuth consent screen** (Google Auth Platform):
   - User type **External**, tên app `HistoriAI`, email hỗ trợ = Gmail team, logo (tuỳ).
   - Authorized domain: `historiai.org`. Trang quyền riêng tư: `https://historiai.org/rieng-tu/`.
   - Scopes: chỉ `openid`, `email`, `profile` (mặc định — không cần duyệt của Google).
   - Bấm **Publish app** (chuyển khỏi "Testing"), không thì chỉ tài khoản trong danh sách test đăng nhập được.
3. **Credentials → Create credentials → OAuth client ID**, tạo **2 cái**:
   - **Web application** — Authorized JavaScript origins: `https://historiai.org`
     (thêm `http://localhost:8080` nếu muốn thử trên máy). → chép **Client ID**.
   - **Android** — Package name `com.histojourney.historiai`,
     SHA-1 `93:24:F9:A7:B4:5E:46:C9:CF:B9:10:9D:FB:A2:DB:8A:83:AF:91:4B` (khoá phát hành, lấy từ APK 0.2.0).
     Client ID Android không cần chép đi đâu — Google tự khớp theo tên gói + SHA-1.
4. Gửi **Client ID loại Web** cho người dựng bản (không phải bí mật). Không cần client secret.
5. Máy chủ: thêm `GOOGLE_CLIENT_IDS=<client ID web>` vào `~/historiai/backend/.env`, khởi động lại (mục 1.3).
6. Dựng lại web + APK kèm `--dart-define=GOOGLE_CLIENT_ID=<client ID web>` (APK tăng số build).

Người đăng ký bằng Google có mật khẩu ngẫu nhiên; muốn đăng nhập bằng mật khẩu thì dùng "Quên mật khẩu?".
Email Google trùng tài khoản cũ → vào đúng tài khoản cũ (Google đã xác minh email).
