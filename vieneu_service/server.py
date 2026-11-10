# -*- coding: utf-8 -*-
"""Micro-service VieNeu-TTS — giọng nhân bản cho Chat Vĩ Nhân, chạy CPU trên VPS.

Khác viXTTS (cần GPU trên laptop), dịch vụ này chạy thường trực trên máy chủ nên
giọng nói có mặt cả khi laptop tắt. Đo trên VPS (Ryzen 5 3600, 4 luồng):
tiếng đầu tiên sau ~0,6 s khi stream, RTF ~0,7 (tạo nhanh hơn đọc).

Chạy:
    .venv/bin/python server.py                 # cổng 8510, chỉ nghe 127.0.0.1

Endpoint:
    GET  /health
    POST /tts         {voice, text} -> audio/mpeg hoàn chỉnh
    POST /tts/stream  {voice, text} -> audio/mpeg theo từng mảnh (phát được ngay)

MỘT YÊU CẦU MỘT LÚC
    Đo được: 2 yêu cầu song song đẩy RAM lên 4,7 GB trên máy chủ 9,6 GB chạy
    chung nhiều dịch vụ, và cả hai cùng chậm hơn thời gian thực. Nên xử lý tuần
    tự; quá MAX_CHO yêu cầu đang chờ thì trả 503 ngay để backend chuyển sang
    giọng dự phòng, thay vì bắt người dùng đợi mãi.

Giọng = voices/<slug>.wav (mẫu 5–8 s). Lần đầu nhân bản rồi lưu voices/<slug>.npz
kèm mã băm tệp mẫu — lần sau khởi động nạp thẳng, đổi tệp mẫu thì tự nhân bản lại.
"""
from __future__ import annotations

import hashlib
import io
import logging
import os
import threading
import time
from pathlib import Path

import lameenc
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response, StreamingResponse
from pydantic import BaseModel, Field

BASE = Path(__file__).resolve().parent
VOICES = BASE / "voices"
ONNX_DIR = os.environ.get("VIENEU_ONNX_DIR", str(BASE / "mo_hinh" / "onnx_update"))
THREADS = int(os.environ.get("VIENEU_THREADS", "4"))   # đo: 4 ≈ 6 > 8 trên VPS dùng chung
MAX_CHO = int(os.environ.get("VIENEU_MAX_CHO", "2"))
SR = 48_000
KBPS = 64

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("vieneu")

from vieneu import Vieneu  # noqa: E402  (nạp sau khi cấu hình log)

t0 = time.time()
tts = Vieneu(threads=THREADS, onnx_dir=ONNX_DIR)
log.info("Nạp mô hình %.1fs, %d luồng", time.time() - t0, THREADS)


def _bam(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()[:16]


def nap_giong() -> list[str]:
    ten = []
    for wav in sorted(VOICES.glob("*.wav")):
        slug, npz = wav.stem, wav.with_suffix(".npz")
        bam = _bam(wav)
        if npz.exists():
            z = np.load(npz, allow_pickle=False)
            if str(z["bam"]) == bam:
                tts._preset_voices[slug] = {
                    "description": "", "gender": "", "style": tts.default_style,
                    "speaker_emb": z["speaker_emb"].astype(np.float32),
                    "codes": z["codes"].astype(np.int64) if z["codes"].size else None,
                }
                ten.append(slug)
                continue
        a = time.time()
        tts.add_voice(slug, str(wav))
        v = tts._preset_voices[slug]
        np.savez(npz, bam=np.array(bam), speaker_emb=v["speaker_emb"],
                 codes=v["codes"] if v["codes"] is not None else np.zeros(0, np.int64))
        log.info("Nhân bản giọng %s: %.1fs", slug, time.time() - a)
        ten.append(slug)
    return ten


GIONG = nap_giong()
log.info("Giọng sẵn sàng: %s", GIONG)
tts.infer("Khởi động.", voice=GIONG[0]) if GIONG else None   # làm nóng đồ thị ONNX

# Tham số đọc riêng từng giọng — nhóm nghe so sánh 4 bản và chọn 21/10 (góp ý: giọng
# "hơi đơ, cần nhấn nhá, cảm xúc"). Trần Hưng Đạo: bản điềm đạm; Quang Trung: bản ngắt
# nghỉ dài hơn. Giọng không có ở đây dùng mặc định của VieNeu (temperature 0.8, top_k 25).
# `silence_p` (nghỉ giữa các đoạn) chỉ /tts dùng được; /tts/stream nhận từng câu một.
THAM_SO = {
    "tran-hung-dao": {"temperature": 0.6, "top_k": 20, "silence_p": 0.25},
    "quang-trung": {"temperature": 0.9, "top_k": 35, "silence_p": 0.35},
}


def _tham_so(voice: str, stream: bool) -> dict:
    ts = dict(THAM_SO.get(voice, {}))
    if stream:
        ts.pop("silence_p", None)
    return ts


_khoa = threading.Lock()
_dem_cho = 0
_dem_lock = threading.Lock()


class YeuCau(BaseModel):
    voice: str
    text: str = Field(min_length=1, max_length=2000)


def _kiem(y: YeuCau) -> None:
    if y.voice not in GIONG:
        raise HTTPException(404, f"Không có giọng '{y.voice}'")


def _vao_hang() -> None:
    global _dem_cho
    with _dem_lock:
        if _dem_cho >= MAX_CHO:
            raise HTTPException(503, "TTS đang bận — dùng giọng dự phòng")
        _dem_cho += 1


def _ra_hang() -> None:
    global _dem_cho
    with _dem_lock:
        _dem_cho -= 1


def _pcm16(wav: np.ndarray) -> bytes:
    return (np.clip(np.asarray(wav, dtype=np.float32), -1, 1) * 32767).astype("<i2").tobytes()


def _bo_ma_hoa() -> lameenc.Encoder:
    e = lameenc.Encoder()
    e.set_bit_rate(KBPS)
    e.set_in_sample_rate(SR)
    e.set_channels(1)
    e.set_quality(5)
    return e


app = FastAPI(title="VieNeu-TTS service")


@app.get("/health")
def health():
    return {"ok": True, "giong": GIONG, "dang_cho": _dem_cho, "luong": THREADS,
            "tham_so": THAM_SO}


@app.post("/tts")
def tts_full(y: YeuCau):
    _kiem(y)
    _vao_hang()
    try:
        with _khoa:
            wav = tts.infer(y.text, voice=y.voice, **_tham_so(y.voice, stream=False))
    finally:
        _ra_hang()
    e = _bo_ma_hoa()
    return Response(e.encode(_pcm16(wav)) + e.flush(), media_type="audio/mpeg")


@app.post("/tts/stream")
def tts_stream(y: YeuCau):
    _kiem(y)
    _vao_hang()   # từ chối NGAY khi quá tải, trước khi mở luồng trả lời

    def sinh():
        e = _bo_ma_hoa()
        try:
            with _khoa:
                for manh in tts.infer_stream(y.text, voice=y.voice, **_tham_so(y.voice, stream=True)):
                    b = e.encode(_pcm16(manh))
                    if b:
                        yield bytes(b)
            yield bytes(e.flush())
        finally:
            # Chạy cả khi client ngắt giữa chừng — không bao giờ để khoá bị giữ mãi
            _ra_hang()

    return StreamingResponse(sinh(), media_type="audio/mpeg",
                             headers={"Cache-Control": "no-store", "X-Accel-Buffering": "no"})


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=int(os.environ.get("VIENEU_PORT", "8510")),
                log_level="info")
