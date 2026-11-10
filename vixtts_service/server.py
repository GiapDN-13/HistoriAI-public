# -*- coding: utf-8 -*-
"""Micro-service viXTTS — TTS tiếng Việt + voice clone, có streaming.

Chạy trong conda env 'vixtts' (đã cài coqui-tts 0.24.1 + torch CUDA):
    conda activate vixtts
    cd HistoriAI/vixtts_service
    python server.py            # mặc định cổng 8500

Endpoint:
    GET  /health
    POST /tts         {voice, text}      -> trả file WAV hoàn chỉnh
    POST /tts/stream  {voice, text}      -> stream audio/wav theo chunk (real-time)

Giọng (voice) = tên file trong ./voices/<voice>.wav (vd 'tran-hung-dao').
"""
import io
import json
import os
import struct
import wave
from pathlib import Path

os.environ.pop("SSL_CERT_FILE", None)
os.environ.setdefault("PYTHONUTF8", "1")

import torch
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse, Response
from pydantic import BaseModel

from TTS.tts.configs.xtts_config import XttsConfig
from TTS.tts.models.xtts import Xtts
import TTS.tts.layers.xtts.tokenizer as _tk

# ---- cấu hình ----
BASE = Path(__file__).resolve().parent
MODEL_DIR = os.environ.get("VIXTTS_MODEL", str(BASE.parent.parent / "vixtts_model"))
VOICES_DIR = BASE / "voices"
SAMPLE_RATE = 24000

# ---- patch tokenizer hỗ trợ tiếng Việt ----
_orig_pre = _tk.VoiceBpeTokenizer.preprocess_text
def _pre_vi(self, txt, lang):
    if lang == "vi":
        return _tk.multilingual_cleaners(txt, "en")
    return _orig_pre(self, txt, lang)
_tk.VoiceBpeTokenizer.preprocess_text = _pre_vi

# ---- nạp model 1 lần ----
print("Loading viXTTS model from", MODEL_DIR)
_raw = json.load(open(os.path.join(MODEL_DIR, "config.json"), encoding="utf-8"))
_config = XttsConfig()
_config.model_args.update(_raw.get("model_args", {}))
if "audio" in _raw:
    for k, v in _raw["audio"].items():
        setattr(_config.audio, k, v)
_model = Xtts.init_from_config(_config)
_model.load_checkpoint(_config, checkpoint_dir=MODEL_DIR, use_deepspeed=False)
_DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
if _DEVICE == "cuda":
    _model.cuda()
try:
    _model.tokenizer.char_limits["vi"] = 250
except Exception:
    pass
print("Model loaded on", _DEVICE)

# ---- cache speaker latents theo giọng (tính 1 lần) ----
_latent_cache: dict[str, tuple] = {}


def _get_latents(voice: str):
    if voice in _latent_cache:
        return _latent_cache[voice]
    ref = VOICES_DIR / f"{voice}.wav"
    if not ref.exists():
        raise HTTPException(404, f"Không có giọng '{voice}' (thiếu {ref.name})")
    gpt_latent, speaker_emb = _model.get_conditioning_latents(
        audio_path=str(ref), gpt_cond_len=30, max_ref_length=60)
    _latent_cache[voice] = (gpt_latent, speaker_emb)
    return _latent_cache[voice]


def _float_to_pcm16(chunk) -> bytes:
    """Tensor/np float [-1,1] -> bytes PCM16."""
    import numpy as np
    arr = chunk.detach().cpu().numpy() if hasattr(chunk, "detach") else np.asarray(chunk)
    arr = np.clip(arr, -1.0, 1.0)
    return (arr * 32767).astype("<i2").tobytes()


def _wav_header(n_bytes: int) -> bytes:
    """Header WAV cho streaming (dùng kích thước lớn để player chấp nhận)."""
    return (b"RIFF" + struct.pack("<I", 0xFFFFFFFF) + b"WAVE"
            + b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16)
            + b"data" + struct.pack("<I", 0xFFFFFFFF))


app = FastAPI(title="viXTTS Service")


class TTSReq(BaseModel):
    voice: str
    text: str


@app.get("/health")
def health():
    return {"status": "ok", "device": _DEVICE, "voices": [p.stem for p in VOICES_DIR.glob("*.wav")]}


@app.post("/tts")
def tts(req: TTSReq):
    """Sinh full WAV (non-stream)."""
    gpt_latent, speaker_emb = _get_latents(req.voice)
    out = _model.inference(req.text, "vi", gpt_latent, speaker_emb,
                           temperature=0.3, enable_text_splitting=False)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(_float_to_pcm16(torch.tensor(out["wav"])))
    return Response(content=buf.getvalue(), media_type="audio/wav")


@app.post("/tts/stream")
def tts_stream(req: TTSReq):
    """Stream audio theo chunk (real-time) — WAV PCM16."""
    gpt_latent, speaker_emb = _get_latents(req.voice)

    def gen():
        yield _wav_header(0)
        stream = _model.inference_stream(
            req.text, "vi", gpt_latent, speaker_emb,
            temperature=0.3, enable_text_splitting=False, stream_chunk_size=20)
        for chunk in stream:
            yield _float_to_pcm16(chunk)

    return StreamingResponse(gen(), media_type="audio/wav")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=int(os.environ.get("VIXTTS_PORT", 8500)))
