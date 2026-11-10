"""Service Text-to-Speech (giọng nói nhân vật).

Hỗ trợ 3 nhà cung cấp (chọn qua settings.TTS_PROVIDER):
- "edge"       : Microsoft Edge TTS. Giọng neural tiếng Việt, **miễn phí, không cần API
                 key**, chạy được trên máy không GPU. Đây là lựa chọn mặc định khi deploy.
                 voice = slug nhân vật -> tra trong _EDGE_GIONG.
- "vieneu"     : micro-service VieNeu-TTS chạy CPU trên máy chủ, giọng nhân bản, stream
                 được (xem giong_stream.py). Lỗi/bận → TTS_DU_PHONG.
- "vixtts"     : micro-service viXTTS chạy local trên GPU (tiếng Việt chuẩn, miễn phí).
                 voice = slug nhân vật (vd 'tran-hung-dao') -> file giọng mẫu trong service.
- "elevenlabs" : ElevenLabs API. voice = voice_id.

Chung:
- Làm sạch markdown/emoji trước khi đọc (clean_for_speech).
- Cache theo hash(provider + voice + text) -> không gọi lại.
- Fallback an toàn: lỗi/thiếu cấu hình -> trả None (app vẫn hiển thị text).
"""
import asyncio
import hashlib
import re
from pathlib import Path

import httpx

from app.core.config import settings

_CACHE_DIR = Path(__file__).resolve().parents[2] / settings.AUDIO_CACHE_DIR

# Bỏ markdown + emoji để giọng đọc tự nhiên
_MD_RE = re.compile(r"[*_`#>~]|^\s*[-•]\s+", re.MULTILINE)
_EMOJI_RE = re.compile(
    "[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F000-\U0001F0FF\U00002190-\U000021FF\U00002B00-\U00002BFF]",
    flags=re.UNICODE,
)


def clean_for_speech(text: str) -> str:
    t = _MD_RE.sub("", text)
    t = _EMOJI_RE.sub("", t)
    t = re.sub(r"[ \t]+", " ", t)
    t = re.sub(r"\n{2,}", "\n", t).strip()
    return t


def _cache_path(provider: str, voice: str, text: str, ext: str) -> Path:
    # Tạo thư mục cache nếu chưa có. Thiếu bước này thì mọi provider đều lặng lẽ
    # trả None trên máy mới — lỗi khó truy vì hàm sinh audio nuốt hết ngoại lệ.
    _CACHE_DIR.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha256(f"{provider}|{voice}|{text}".encode("utf-8")).hexdigest()
    return _CACHE_DIR / f"{key}.{ext}"


def _synth_vixtts(text: str, voice: str) -> str | None:
    """Gọi micro-service viXTTS. voice = slug nhân vật. Trả tên file .wav."""
    path = _cache_path("vixtts", voice, text, "wav")
    if path.exists():
        return path.name
    try:
        resp = httpx.post(
            f"{settings.VIXTTS_URL.rstrip('/')}/tts",
            json={"voice": voice, "text": text},
            timeout=settings.TTS_TIMEOUT,
        )
        resp.raise_for_status()
        _CACHE_DIR.mkdir(parents=True, exist_ok=True)
        path.write_bytes(resp.content)
        return path.name
    except httpx.HTTPError:
        return None


def _synth_vieneu(text: str, voice: str) -> str | None:
    """Gọi vieneu_service /tts (cả câu). Lỗi hay đang bận thì trả None để rơi về dự phòng."""
    # "vieneu2": tham số đọc từng giọng đổi 21/10 (vieneu_service THAM_SO) — bỏ lưu đệm cũ.
    path = _cache_path("vieneu2", voice, text, "mp3")
    if path.exists():
        return path.name
    try:
        resp = httpx.post(f"{settings.VIENEU_URL.rstrip('/')}/tts",
                          json={"voice": voice, "text": text}, timeout=settings.TTS_TIMEOUT)
        resp.raise_for_status()
        tam = path.with_suffix(".tam")
        tam.write_bytes(resp.content)
        tam.replace(path)
        return path.name
    except httpx.HTTPError:
        return None


def synth_du_phong(text: str, voice: str) -> str | None:
    """Giọng dự phòng khi VieNeu không phục vụ được. Không bao giờ ném lỗi."""
    if settings.TTS_DU_PHONG == "edge":
        return _synth_edge(text, voice)
    return None


def _synth_elevenlabs(text: str, voice_id: str) -> str | None:
    """Gọi ElevenLabs. voice = voice_id. Trả tên file .mp3."""
    if not settings.ELEVENLABS_API_KEY:
        return None
    path = _cache_path("elevenlabs", voice_id, text, "mp3")
    if path.exists():
        return path.name
    try:
        resp = httpx.post(
            f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}",
            json={
                "text": text,
                "model_id": settings.ELEVENLABS_MODEL,
                "voice_settings": {"stability": 0.65, "similarity_boost": 0.8},
            },
            headers={"xi-api-key": settings.ELEVENLABS_API_KEY, "Accept": "audio/mpeg"},
            timeout=settings.TTS_TIMEOUT,
        )
        resp.raise_for_status()
        _CACHE_DIR.mkdir(parents=True, exist_ok=True)
        path.write_bytes(resp.content)
        return path.name
    except httpx.HTTPError:
        return None


# Edge TTS chỉ có hai giọng tiếng Việt. Để các vĩ nhân không nghe giống hệt nhau,
# mỗi người được chỉnh thêm cao độ và tốc độ — cùng một giọng nền nhưng khác chất.
# Thiếu slug thì rơi về giọng nam mặc định.
_EDGE_NAM = "vi-VN-NamMinhNeural"
_EDGE_NU = "vi-VN-HoaiMyNeural"
_EDGE_GIONG: dict[str, tuple[str, str, str]] = {
    # slug              : (giọng,      cao độ,   tốc độ)
    "tran-hung-dao":     (_EDGE_NAM, "-12Hz", "-10%"),  # lão tướng, trầm và chậm rãi
    "quang-trung":       (_EDGE_NAM, "-4Hz", "+4%"),    # trẻ, dứt khoát
    "le-loi":            (_EDGE_NAM, "-8Hz", "-4%"),
    "ngo-quyen":         (_EDGE_NAM, "-10Hz", "-6%"),
    "nguyen-trai":       (_EDGE_NAM, "-2Hz", "-8%"),    # văn thần, thong thả
    "hai-ba-trung":      (_EDGE_NU, "-2Hz", "+0%"),
}
_EDGE_MAC_DINH = (_EDGE_NAM, "-6Hz", "-4%")


def _synth_edge(text: str, voice: str) -> str | None:
    """Sinh audio bằng Microsoft Edge TTS. Miễn phí, không cần key, không cần GPU."""
    giong, cao_do, toc_do = _EDGE_GIONG.get(voice, _EDGE_MAC_DINH)
    path = _cache_path("edge", voice, text, "mp3")
    if path.exists():
        return path.name
    try:
        import edge_tts  # nhập tại chỗ để thiếu gói cũng không làm sập app
    except ImportError:
        return None
    try:
        async def _chay() -> None:
            com = edge_tts.Communicate(text, giong, pitch=cao_do, rate=toc_do)
            await com.save(str(path))

        asyncio.run(_chay())
    except RuntimeError:
        # Đã nằm trong event loop (route async) — bỏ giọng còn hơn làm hỏng request
        return None
    except Exception:
        # Mất mạng, Microsoft đổi giao thức... — app vẫn phải chạy, chỉ là không có tiếng
        path.unlink(missing_ok=True)
        return None
    return path.name if path.exists() and path.stat().st_size > 0 else None


def synthesize(text: str, voice: str | None) -> str | None:
    """Sinh audio cho `text` với giọng `voice`. Trả tên file (trong AUDIO_CACHE_DIR) hoặc None.

    `voice`: với Edge TTS và viXTTS là slug nhân vật; với ElevenLabs là voice_id.
    """
    if not voice or not text.strip():
        return None
    speech = clean_for_speech(text)
    if not speech:
        return None
    if settings.TTS_PROVIDER == "none":
        return None  # tắt giọng (vd deploy cloud không GPU)
    if settings.TTS_PROVIDER == "edge":
        return _synth_edge(speech, voice)
    if settings.TTS_PROVIDER == "vieneu":
        return _synth_vieneu(speech, voice) or synth_du_phong(speech, voice)
    if settings.TTS_PROVIDER == "vixtts":
        return _synth_vixtts(speech, voice)
    return _synth_elevenlabs(speech, voice)


def audio_file_path(filename: str) -> Path | None:
    """Trả đường dẫn file audio trong cache nếu hợp lệ (cho route phục vụ)."""
    if "/" in filename or "\\" in filename or ".." in filename:
        return None
    p = _CACHE_DIR / filename
    return p if p.exists() else None


def media_type_for(filename: str) -> str:
    return "audio/wav" if filename.endswith(".wav") else "audio/mpeg"
