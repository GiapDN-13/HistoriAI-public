# viXTTS Service — TTS tiếng Việt + voice clone (có streaming)

Micro-service riêng cho giọng nói nhân vật HistoriAI. Dùng **viXTTS** (fine-tune XTTS-v2 cho tiếng Việt) — đọc tiếng Việt chuẩn, clone giọng từ mẫu, **miễn phí**, chạy local trên GPU.

## Vì sao tách riêng?
viXTTS cần môi trường Python riêng (coqui-tts + torch CUDA, model ~2GB) + GPU. Tách thành service để backend chính (FastAPI) gọi qua HTTP, không phụ thuộc.

## Cài đặt (một lần)
```bash
conda create -n vixtts python=3.10 -y
conda activate vixtts
pip install coqui-tts==0.24.1 vinorm underthesea huggingface_hub fastapi "uvicorn[standard]"
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu121

# tải model viXTTS (~2GB) về thư mục ../../vixtts_model
hf download capleaf/viXTTS --local-dir ../../vixtts_model
```

## Giọng nhân vật
Đặt file giọng mẫu (wav, ~10-60s, rõ, không ồn) vào `voices/<slug>.wav`:
- `voices/tran-hung-dao.wav`
- `voices/quang-trung.wav`

Tên file = `figure.slug` trong DB. Thêm nhân vật mới = thêm 1 file wav.

## Chạy
```bash
conda activate vixtts
python server.py            # cổng 8500 (đổi qua VIXTTS_PORT)
```

## API
| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/health` | trạng thái + danh sách giọng |
| POST | `/tts` | `{voice, text}` → WAV hoàn chỉnh |
| POST | `/tts/stream` | `{voice, text}` → stream WAV theo chunk (real-time, TTFB ~vài ms) |

## Kết nối với backend HistoriAI
Trong `backend/.env`:
```
TTS_PROVIDER=vixtts
VIXTTS_URL=http://127.0.0.1:8500
```
Backend `app/services/tts.py` tự gọi sang service này. Đổi `TTS_PROVIDER=elevenlabs` để quay lại ElevenLabs.

> ⚠️ Model (`vixtts_model/`) và file giọng `.wav` KHÔNG commit lên git (nặng) — xem .gitignore.
