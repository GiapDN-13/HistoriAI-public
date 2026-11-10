# Demo local có giọng nói (viXTTS)

Web public (`giapdn-13.github.io/historiai-app`) chạy backend trên Render free — **không có giọng** (viXTTS cần GPU). Để demo **có giọng đặc trưng từng tướng**, chạy local theo hướng dẫn dưới.

## Cách chạy (1 bước)

**Windows:** double-click `scripts\demo_local.bat`
**Git Bash:** `bash scripts/demo_local.sh`

Script tự mở 3 thành phần:
| # | Thành phần | Cổng | Ghi chú |
|---|---|---|---|
| 1 | viXTTS (giọng nói, GPU) | 8500 | conda env `vixtts`, nạp model ~30-60s |
| 2 | Backend API (SQLite + LLM thật + TTS) | 8000 | tự seed dữ liệu |
| 3 | App web | 8080 | trỏ tới backend local |

Sau đó mở **Chrome → http://localhost:8080**.

## Lưu ý
- **Chờ viXTTS nạp model xong (~30-60s)** rồi mới chat để có tiếng. Lần chat đầu sẽ hơi chậm (sinh giọng).
- Cần: conda env `vixtts` đã cài, model ở `../vixtts_model`, GPU CUDA.
- LLM key đọc từ `backend/.env` (đã có sẵn).
- Tắt: đóng 3 cửa sổ cmd (Windows) hoặc Ctrl+C (bash).

## Khắc phục sự cố
- **Không có tiếng:** kiểm tra cửa sổ "viXTTS" đã in `Model loaded on cuda` chưa; thử lại sau khi nạp xong.
- **Chat báo lỗi:** kiểm tra `backend/.env` có `LLM_API_KEY` và còn credit.
- **Sau khi build lại cho Render:** marker `.local_demo` mất → lần chạy demo sau script tự build lại bản local (đúng ý).
