"""Route Chat Vĩ Nhân (AI Historical Chatbot)."""
import json
import time

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_optional
from app.db.session import get_db
from app.models.figure import HistoricalFigure
from app.models.user import User
from app.schemas.chat import ChatRequest, ChatResponse, SpeakRequest, SpeakResponse
from app.core.config import settings
from app.services.ai_chat import generate_reply, stream_reply
from app.services.gioi_han import chan_lam_dung, chan_lam_dung_giong
from app.services import giong_stream, soan_san, su_lieu
from app.services.han_muc_ngay import xin_luot_ai
from app.services.tts import audio_file_path, media_type_for, synthesize


def _audio_url(request: Request, filename: str) -> str:
    """Link công khai tới file audio.

    Sau proxy/tunnel, request.url_for() sinh "http://" vì nginx nhận kết nối nội
    bộ không mã hoá — trang HTTPS sẽ chặn file đó. Đặt PUBLIC_BASE_URL để thoát
    hẳn việc đoán scheme.
    """
    duong_dan = request.url_for("get_chat_audio", filename=filename).path
    goc = settings.PUBLIC_BASE_URL.rstrip("/")
    return f"{goc}{duong_dan}" if goc else str(request.url_for("get_chat_audio", filename=filename))


def _voice_for(figure) -> str:
    """Edge TTS và viXTTS dùng slug nhân vật; ElevenLabs dùng voice_id."""
    if settings.TTS_PROVIDER in ("edge", "vixtts", "vieneu"):
        return figure.slug
    return figure.voice_id or ""

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("", response_model=ChatResponse,
             dependencies=[Depends(chan_lam_dung)])
def chat_with_figure(payload: ChatRequest, request: Request, db: Session = Depends(get_db),
                     user: User | None = Depends(get_current_user_optional)):
    """Trả lời 1 cục (non-stream) + giọng nói. Fallback cho client không hỗ trợ SSE."""
    figure = db.query(HistoricalFigure).filter(
        HistoricalFigure.slug == payload.figure_slug
    ).first()
    if not figure:
        raise HTTPException(404, "Không tìm thấy nhân vật")

    soan = soan_san.tim(figure.slug, payload.message, payload.history)
    if soan:
        result = {"reply": soan["dap"], "audio_url": None, "sources": soan.get("nguon", [])}
    else:
        xin_luot_ai(db, user, request)   # hết lượt miễn phí trong ngày → 402 (Premium bỏ qua)
        ds = su_lieu.chon(figure.slug, payload.message, payload.history)
        result = generate_reply(figure, payload.message, context=su_lieu.dinh_dang(ds) or None,
                                history=payload.history)
        if ds and not result.get("sources"):
            result["sources"] = su_lieu.nguon_da_dung(ds)

    # Sinh giọng nói cho câu trả lời (cache theo hash; lỗi/thiếu key -> bỏ qua)
    audio_name = synthesize(result["reply"], _voice_for(figure))
    if audio_name:
        result["audio_url"] = _audio_url(request, audio_name)

    return ChatResponse(figure_slug=figure.slug, **result)


@router.post("/speak", response_model=SpeakResponse,
             dependencies=[Depends(chan_lam_dung_giong)])
def speak_text(payload: SpeakRequest, request: Request, db: Session = Depends(get_db)):
    """Sinh giọng nói cho ĐÚNG đoạn text đang hiển thị (không gọi LLM).

    Dùng khi người dùng bấm nút phát trên 1 câu trả lời -> tiếng khớp 100% chữ.
    """
    figure = db.query(HistoricalFigure).filter(
        HistoricalFigure.slug == payload.figure_slug
    ).first()
    if not figure:
        raise HTTPException(404, "Không tìm thấy nhân vật")

    audio_url = None
    audio_name = synthesize(payload.text, _voice_for(figure))
    if audio_name:
        audio_url = _audio_url(request, audio_name)
    return SpeakResponse(audio_url=audio_url)


@router.post("/stream", dependencies=[Depends(chan_lam_dung)])
def chat_stream(payload: ChatRequest, request: Request, db: Session = Depends(get_db),
                user: User | None = Depends(get_current_user_optional)):
    """Trả lời theo luồng SSE — chữ hiện dần như ChatGPT (cảm giác real-time).

    Mỗi đoạn text gửi dưới dạng `data: <chunk>\\n\\n`, kết thúc bằng `data: [DONE]`.
    (Giọng nói: client gọi /chat non-stream để lấy audio_url, hoặc bổ sung TTS streaming sau.)
    """
    figure = db.query(HistoricalFigure).filter(
        HistoricalFigure.slug == payload.figure_slug
    ).first()
    if not figure:
        raise HTTPException(404, "Không tìm thấy nhân vật")

    # Câu gợi ý mở đầu cuộc trò chuyện → bản soạn sẵn, không gọi AI (services/soan_san.py).
    soan = soan_san.tim(figure.slug, payload.message, payload.history)
    if soan:
        def tu_ban_soan():
            for m in soan_san.manh(soan["dap"]):
                safe = m.replace("\r", "").replace("\n", "\\n")
                yield f"data: {safe}\n\n"
                time.sleep(0.03)   # hiện dần như đang gõ, không đổ cả khối một lúc
            if soan.get("nguon") and payload.nhan_nguon:
                yield "data: [NGUON]" + json.dumps(soan["nguon"], ensure_ascii=False) + "\n\n"
            yield "data: [DONE]\n\n"

        return StreamingResponse(tu_ban_soan(), media_type="text/event-stream",
                                 headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

    # Từ đây là gọi AI thật. Kiểm hạn mức ngày TRƯỚC khi mở luồng: đã trả StreamingResponse
    # thì không còn đổi được mã trạng thái thành 402 nữa.
    xin_luot_ai(db, user, request)

    # Sử liệu có nguồn liên quan câu hỏi — xem services/su_lieu.py.
    ds = su_lieu.chon(figure.slug, payload.message, payload.history)

    def event_generator():
        for chunk in stream_reply(figure, payload.message, context=su_lieu.dinh_dang(ds) or None,
                                  history=payload.history):
            # escape xuống dòng để không phá khung SSE
            safe = chunk.replace("\r", "").replace("\n", "\\n")
            yield f"data: {safe}\n\n"
        # Nguồn THẬT của sử liệu đã đưa cho mô hình (app hiện dưới câu trả lời).
        # Gửi thành một dòng riêng có tiền tố để app tách ra, không lẫn vào chữ.
        nguon = su_lieu.nguon_da_dung(ds)
        if nguon and payload.nhan_nguon:
            yield "data: [NGUON]" + json.dumps(nguon, ensure_ascii=False) + "\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.post("/speak/stream", response_model=SpeakResponse,
             dependencies=[Depends(chan_lam_dung_giong)])
def speak_stream(payload: SpeakRequest, request: Request, db: Session = Depends(get_db)):
    """Bắt đầu tạo giọng cho MỘT câu và trả ngay đường dẫn phát được khi đang tạo.

    App gọi cho từng câu ngay khi câu đó hiện xong trên màn hình — câu sau được
    tạo trong lúc câu trước đang phát. Xem app/services/giong_stream.py.
    """
    figure = db.query(HistoricalFigure).filter(
        HistoricalFigure.slug == payload.figure_slug
    ).first()
    if not figure:
        raise HTTPException(404, "Không tìm thấy nhân vật")
    giong = _voice_for(figure)
    if settings.TTS_PROVIDER == "none" or not giong or not payload.text.strip():
        return SpeakResponse(audio_url=None)
    ma = giong_stream.bat_dau(giong, payload.text)
    duong_dan = request.url_for("get_chat_audio_stream", ma=ma).path
    goc = settings.PUBLIC_BASE_URL.rstrip("/")
    return SpeakResponse(audio_url=f"{goc}{duong_dan}" if goc
                         else str(request.url_for("get_chat_audio_stream", ma=ma)))


@router.get("/audio/stream/{ma}.mp3", name="get_chat_audio_stream")
def get_chat_audio_stream(ma: str):
    """MP3 của một phiên — phát được ngay khi byte đầu tiên có, không đợi cả câu."""
    if not ma.isalnum() or len(ma) > 64:
        raise HTTPException(404, "Không tìm thấy audio")
    luong = giong_stream.doc(ma)
    if luong is None:
        raise HTTPException(404, "Không tìm thấy audio")
    # Đợi byte đầu tiên TRƯỚC khi trả lời: tạo giọng hỏng thì trả 503 để app đọc
    # bằng giọng trình duyệt, thay vì trả 200 kèm tệp rỗng làm trình phát treo.
    dau = next(luong, None)
    if dau is None:
        raise HTTPException(503, "Chưa tạo được giọng")

    def noi():
        yield dau
        yield from luong

    return StreamingResponse(noi(), media_type="audio/mpeg",
                             # no-store: .mp3 nằm trong danh sách Cloudflare tự lưu đệm —
                             # để nó giữ một luồng đang phát dở là phát cụt cả ngày.
                             # Lưu đệm đã có ở backend (tệp theo mã phiên).
                             headers={"Cache-Control": "no-store", "X-Accel-Buffering": "no"})


@router.get("/audio/{filename}", name="get_chat_audio")
def get_chat_audio(filename: str):
    """Phục vụ file audio TTS đã cache (mp3)."""
    path = audio_file_path(filename)
    if not path:
        raise HTTPException(404, "Không tìm thấy audio")
    return FileResponse(path, media_type=media_type_for(filename))
