# Deploy HistoriAI cho cả team xem & tương tác

Bản deploy free: **Auth, Quiz, Timeline, AR, Chat (mock)** chạy thật.
Giọng nói viXTTS bị tắt (cloud free không có GPU) — chạy local khi cần demo giọng.

## Phần 1 — Backend lên Render.com (1 lần, ~10 phút)

1. Vào https://render.com → đăng nhập bằng **GitHub** (tài khoản GiapDN-13).
2. **New +** → **Blueprint**.
3. Chọn repo **GiapDN-13/HistoriAI** (branch `develop` hoặc `master`).
4. Render đọc `render.yaml` → tự dựng **historiai-api** + **historiai-db** (Postgres free).
5. Bấm **Apply** → chờ build ~3-5 phút.
6. Xong có URL, dạng: `https://historiai-api.onrender.com`
   - Kiểm tra: mở `<URL>/health` thấy `{"status":"ok"}` là OK.
   - Thử API: `<URL>/docs` (Swagger).

> Lưu ý free tier: service "ngủ" sau 15 phút không dùng, request đầu chờ ~30-50s rồi chạy lại bình thường.

## Phần 2 — Flutter web (cho team xem giao diện + tương tác)

Sau khi có URL backend, build web trỏ vào nó:
```bash
cd HistoriAI/mobile
flutter build web --release --dart-define=API_BASE_URL=https://historiai-api.onrender.com
```
Thư mục kết quả: `build/web/`.

Đưa lên mạng (chọn 1):
- **Vercel/Netlify**: kéo-thả thư mục `build/web` → có link ngay.
- **GitHub Pages**: đẩy `build/web` lên 1 repo public (như đã làm với landing).

→ Gửi link cho team. Mọi người đăng ký/đăng nhập, làm quiz, xem timeline, chat (mock) được.

## Bật lại giọng nói (khi demo)
Trên máy có GPU: chạy `vixtts_service/` (xem README), rồi backend đặt
`TTS_PROVIDER=vixtts` + `VIXTTS_URL=http://...`. Hoặc dùng ElevenLabs:
`TTS_PROVIDER=elevenlabs` + `ELEVENLABS_API_KEY=...`.
