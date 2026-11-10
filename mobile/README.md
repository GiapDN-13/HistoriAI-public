# HistoriAI — app Flutter (web + Android)

App học Lịch sử Việt Nam: trò chuyện với vĩ nhân (giọng nhân bản), dòng thời gian,
đấu quiz theo chương trình GDPT 2018, cổ vật 3D xem kích thước thật.

- Bản web: **https://historiai.org** (cài được như ứng dụng trên máy tính — biểu tượng
  "Cài đặt ứng dụng" trên thanh địa chỉ Chrome/Edge)
- Bản cài Android: **https://historiai.org/tai-app/**
- iPhone: chưa có bản cài, dùng bản web.

## Chạy và kiểm tra

Flutter **không nằm trên PATH** ở máy nhóm — gọi thẳng:

```bash
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat analyze --no-fatal-infos
C:\src\flutter\bin\flutter.bat test
C:\src\flutter\bin\flutter.bat run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Dựng bản phát hành

```bash
# Web — xong thì gắn mã băm vào main.dart.js (Flutter không tự làm, Cloudflare giữ .js 4 giờ)
flutter build web --release --dart-define=API_BASE_URL=https://historiai.org
python tool/danh_dau_phien_ban.py

# Android — TĂNG số sau dấu + trong `version:` (pubspec.yaml) trước, rồi:
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://historiai.org
python tool/dong_goi_ban_cai.py --ghi-chu "Sửa lỗi…"   # sinh cả phien-ban.json
```

**Luôn** thêm `--dart-define=GOOGLE_CLIENT_ID=448131888572-n4ed1hlvfk8deavifgv8u1j8fjp97ag9.apps.googleusercontent.com`
vào hai lệnh dựng — thiếu là nút "Tiếp tục với Google" biến mất (client ID web, không phải bí mật).
Và **luôn** thêm `--dart-define=SENTRY_DSN=<DSN của project Sentry>`
(project `historiai-app` — DSN không phải bí mật) để giữ theo dõi lỗi.
App Android (từ 0.2.0) đọc `tai-app/phien-ban.json` và hỏi người dùng tải bản mới
khi số build ở đó lớn hơn bản đang chạy. Xem `../docs/BAT_EMAIL_VA_SENTRY.md`.

Bản cài Android ký bằng khoá phát hành (`android/key.properties`, không nằm trong git).
Đừng dựng bằng khoá gỡ lỗi rồi phát ra ngoài — Android từ chối cài đè khi chữ ký khác nhau.

## Công cụ trong `tool/`

| Tệp | Việc |
|---|---|
| `danh_dau_phien_ban.py` | Gắn mã băm vào `main.dart.js` sau khi dựng web |
| `dong_goi_ban_cai.py` | Đặt tên APK theo phiên bản, dựng `build/tai-app/` |
| `tao_anh_chia_se.py` | Dựng ảnh xem trước khi chia sẻ link (`web/og-image.png`, 1200×630) |
| `tao_cu_dong.py` | Soạn các đoạn cử động cho mô hình 3D nhân vật |
| `chuan_hoa_ti_le.py` | Chuẩn hoá tỉ lệ mô hình cổ vật về mét |

## Tài liệu liên quan

- Đo lường, nguồn khách, phản hồi: `../docs/DO_LUONG.md`, `../docs/LINK_THEO_KENH.md`
- Đặc tả giao diện: `../docs/SPEC_UI_UX.md`
