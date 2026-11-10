# vieneu_service — giọng nhân bản cho Chat Vĩ Nhân (CPU, trên VPS)

VieNeu-TTS v3 Turbo (Apache 2.0), chạy ONNX trên CPU. Khác `vixtts_service/` (cần GPU
trên laptop), dịch vụ này chạy thường trực trên máy chủ nên web vẫn có giọng khi laptop tắt.

## Số đo trên VPS (Ryzen 5 3600, không VNNI → chỉ fp32)

| | 4 luồng |
|---|---|
| Tiếng đầu tiên khi stream | ~0,6 s |
| RTF (thời gian tạo / độ dài âm thanh) | ~0,7 — tạo nhanh hơn đọc |
| RAM sau khi nạp | ~1,2 GB |
| RAM khi 2 yêu cầu song song | đỉnh 4,7 GB → vì vậy xử lý tuần tự |

Tăng lên 8 luồng lại **chậm hơn** (máy dùng chung). Giữ 4.

## Cài

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -c "from huggingface_hub import snapshot_download; \
  snapshot_download('pnnbao-ump/VieNeu-TTS-v3-Turbo', allow_patterns=['onnx_update/*'], local_dir='mo_hinh')"
```

Tải về `local_dir` (tệp thật) chứ không dùng bộ nhớ đệm HF (symlink) — onnxruntime mới
từ chối external data đi qua symlink.

## Chạy như dịch vụ (systemd của user, không cần sudo)

`~/.config/systemd/user/vieneu.service` — xem `vieneu.service` trong thư mục này.

```bash
systemctl --user daemon-reload && systemctl --user enable --now vieneu
curl -s 127.0.0.1:8510/health
```

Backend: `TTS_PROVIDER=vieneu`, `VIENEU_URL=http://127.0.0.1:8510`, `TTS_DU_PHONG=edge`.

## Giọng

`voices/<slug>.wav` — mẫu 5–8 giây, một người nói, ít tạp âm. Slug trùng slug nhân vật.
Lần đầu nhân bản rồi lưu `voices/<slug>.npz`; đổi tệp mẫu thì tự nhân bản lại.
