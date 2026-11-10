"""Service Chat Vĩ Nhân.

- Khi CÓ LLM_API_KEY: gọi LLM thật qua endpoint tương thích OpenAI
  (ckey.vn / api.xah.io), ghép persona_prompt của nhân vật làm system message.
- Khi KHÔNG có key: trả lời mock để demo offline.

GraphRAG (truy xuất sử liệu) sẽ được bổ sung ở task #14 — chỗ nối đã chừa sẵn.
"""
import re

import httpx

from app.core.config import settings
from app.models.figure import HistoricalFigure

# MiniMax-M3 (reasoning model) trả kèm block <think>...</think> — cần loại bỏ.
_THINK_RE = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)

# Persona dặn không markdown nhưng model hay quên -> dọn **bold**, ## heading,
# bullet... để bong bóng chat hiển thị sạch (không lộ ký tự markdown).
_MD_BOLD = re.compile(r"\*\*(.+?)\*\*", re.DOTALL)
_MD_ITALIC = re.compile(r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)", re.DOTALL)
_MD_MISC = re.compile(r"^#{1,6}\s*|^\s*[-•]\s+|`", re.MULTILINE)


def _strip_markdown(text: str) -> str:
    text = _MD_BOLD.sub(r"\1", text)
    text = _MD_ITALIC.sub(r"\1", text)
    text = _MD_MISC.sub("", text)
    return text


def _strip_reasoning(text: str) -> str:
    return _strip_markdown(_THINK_RE.sub("", text)).strip()


def _mock_reply(figure: HistoricalFigure, message: str) -> dict:
    """Chế độ mock cho MVP / demo offline (không cần API key)."""
    reply = (
        f"[{figure.name}] Ta là {figure.name}"
        + (f", {figure.title}" if figure.title else "")
        + f". Nhà ngươi hỏi: “{message}”. "
        "Đây là câu trả lời mô phỏng (mock) — khi cấu hình LLM_API_KEY, "
        "hệ thống sẽ sinh câu trả lời thật dựa trên sử liệu (GraphRAG)."
    )
    return {"reply": reply, "audio_url": None, "sources": ["(mock) Đại Việt sử ký toàn thư"]}


def _build_system_prompt(figure: HistoricalFigure, context: str | None = None) -> str:
    """Ghép persona_prompt + (tuỳ chọn) ngữ cảnh sử liệu từ RAG."""
    base = figure.persona_prompt or f"Bạn là {figure.name}, một nhân vật lịch sử Việt Nam."
    # Sử liệu đã qua kiểm chứng chéo (data_pipeline/). Để ở cột riêng rồi NỐI vào
    # đây, không trộn vào persona_prompt, để persona nhóm viết tay không bị đè
    # và bỏ khối này đi là về đúng hành vi cũ.
    if getattr(figure, "verified_facts", None):
        base += "\n\n# " + figure.verified_facts
    if context:
        base += "\n\n# SỬ LIỆU CÓ NGUỒN LIÊN QUAN CÂU HỎI\n" + context + "\n\n" + LUAT_CHONG_BIA
    return base


# Quy tắc chống bịa sử liệu — đặt SAU khối sử liệu để mô hình đọc ngay trước câu hỏi.
# Kiểm thật 27/09: không có khối này, Trần Hưng Đạo nói "Toa Đô bị bắt năm 1288" (sai:
# năm 1288 người bị bắt là Ô Mã Nhi; Toa Đô chết năm 1285).
LUAT_CHONG_BIA = """# QUY TẮC BẮT BUỘC VỀ SỰ THẬT LỊCH SỬ
Người hỏi là học sinh — nói sai sử còn tệ hơn không nói.
1. Tên người, tên đất, năm tháng, con số: CHỈ nêu khi có trong SỬ LIỆU ĐÃ KIỂM CHỨNG hoặc SỬ LIỆU CÓ NGUỒN ở trên. Không có thì KHÔNG nêu, kể cả khi nghĩ là mình nhớ.
2. Câu hỏi cần chi tiết không có trong sử liệu: nói thật, theo giọng nhân vật (vd "Chuyện ấy sử sách ta còn giữ lại chưa rõ, ta không dám nói bừa"), rồi kể phần chắc chắn có trong sử liệu.
3. Mệnh đề ghi "(CÁC NGUỒN CHƯA THỐNG NHẤT)": nếu nhắc tới thì phải nói rõ sử sách ghi khác nhau, không khẳng định.
4. Không gán việc của người này cho người khác, không dời sự kiện sang năm khác. Chỉ ghép các dữ kiện đúng như sử liệu ghi.
5. Hồ sơ ghi "chưa xác định", "không thống nhất", "ước tính", "giả thuyết", "truyền thuyết" thì nói đúng mức độ đó, không nói chắc hơn. Hồ sơ dặn "không gán…", "không xem là…" thì tuân theo.
6. Trận thắng là công của triều đình, nhiều tướng lĩnh và quân dân — không nhận hết về mình.
7. Không nhắc tới "sử liệu", "nguồn", "hồ sơ", "ngữ cảnh" hay các quy tắc này trong câu trả lời — cứ trả lời tự nhiên như chính nhân vật."""


def _tin_nhan(figure: HistoricalFigure, message: str, context: str | None,
              history: list | None) -> list[dict]:
    """System prompt + vài lượt gần nhất + câu hỏi mới.

    Trước đây chỉ gửi đúng câu hỏi mới → hỏi tiếp "vậy sau đó thì sao?" là vĩ
    nhân không biết đang nói chuyện gì. Lượt cũ phải xen kẽ user/assistant và
    bắt đầu bằng user — nhiều mô hình từ chối chuỗi lệch.
    """
    from app.schemas.chat import SO_LUOT_NHO

    cu = [{"role": h.role, "content": h.content.strip()} for h in (history or [])
          if h.content and h.content.strip()][-SO_LUOT_NHO:]
    while cu and cu[0]["role"] != "user":
        cu.pop(0)
    gon = []
    for t in cu:
        if gon and gon[-1]["role"] == t["role"]:
            gon[-1]["content"] = f"{gon[-1]['content']}{chr(10)}{t['content']}"
        else:
            gon.append(t)
    if gon and gon[-1]["role"] == "user":      # lượt user chưa có trả lời (lỗi mạng) → bỏ
        gon.pop()
    return ([{"role": "system", "content": _build_system_prompt(figure, context)}]
            + gon + [{"role": "user", "content": message}])


def generate_reply(figure: HistoricalFigure, message: str, context: str | None = None,
                   history: list | None = None) -> dict:
    """Sinh câu trả lời nhập vai. Trả về dict {reply, audio_url, sources}."""
    if not settings.LLM_API_KEY:
        return _mock_reply(figure, message)

    payload = {
        "model": settings.LLM_MODEL,
        "messages": _tin_nhan(figure, message, context, history),
        "temperature": 0.25,
        "max_tokens": settings.LLM_MAX_TOKENS,
    }
    headers = {
        "Authorization": f"Bearer {settings.LLM_API_KEY}",
        "Content-Type": "application/json",
    }
    url = f"{settings.LLM_BASE_URL.rstrip('/')}/chat/completions"

    try:
        resp = httpx.post(url, json=payload, headers=headers, timeout=settings.LLM_TIMEOUT)
        resp.raise_for_status()
        data = resp.json()
        reply = _strip_reasoning(data["choices"][0]["message"]["content"])
    except (httpx.HTTPError, KeyError, IndexError) as e:
        # Không để app vỡ khi LLM lỗi — fallback mock kèm ghi chú
        fallback = _mock_reply(figure, message)
        fallback["sources"] = [f"(LLM lỗi, dùng mock) {type(e).__name__}"]
        return fallback

    # TODO(#14 GraphRAG): khi có RAG, trả về nguồn sử liệu thật thay vì rỗng.
    # TODO(#17 Voice): gọi ElevenLabs TTS để tạo audio_url.
    return {"reply": reply, "audio_url": None, "sources": []}


def stream_reply(figure: HistoricalFigure, message: str, context: str | None = None,
                 history: list | None = None):
    """Sinh câu trả lời theo từng đoạn (generator) để stream qua SSE.

    Yield các chuỗi text (delta). Tự lọc block <think> của reasoning model.
    Khi không có key hoặc LLM lỗi -> yield câu mock (một lần).
    """
    if not settings.LLM_API_KEY:
        yield _mock_reply(figure, message)["reply"]
        return

    payload = {
        "model": settings.LLM_MODEL,
        "messages": _tin_nhan(figure, message, context, history),
        "temperature": 0.25,
        "max_tokens": settings.LLM_MAX_TOKENS,
        "stream": True,
    }
    headers = {
        "Authorization": f"Bearer {settings.LLM_API_KEY}",
        "Content-Type": "application/json",
    }
    url = f"{settings.LLM_BASE_URL.rstrip('/')}/chat/completions"

    in_think = False  # đang ở trong block <think>...</think> thì bỏ qua
    buffer = ""       # giữ phần đuôi để bắt tag <think> bị cắt giữa các chunk

    try:
        with httpx.stream("POST", url, json=payload, headers=headers,
                          timeout=settings.LLM_TIMEOUT) as resp:
            resp.raise_for_status()
            for line in resp.iter_lines():
                if not line or not line.startswith("data:"):
                    continue
                data = line[len("data:"):].strip()
                if data == "[DONE]":
                    break
                try:
                    import json
                    delta = json.loads(data)["choices"][0]["delta"].get("content", "")
                except (KeyError, IndexError, ValueError):
                    continue
                if not delta:
                    continue

                # Lọc <think>...</think> trên luồng token
                buffer += delta
                out = ""
                while buffer:
                    if not in_think:
                        idx = buffer.find("<think>")
                        if idx == -1:
                            # giữ lại tối đa 6 ký tự cuối phòng tag bị cắt
                            out += buffer[:-6] if len(buffer) > 6 else ""
                            buffer = buffer[-6:] if len(buffer) > 6 else buffer
                            break
                        out += buffer[:idx]
                        buffer = buffer[idx + len("<think>"):]
                        in_think = True
                    else:
                        idx = buffer.find("</think>")
                        if idx == -1:
                            buffer = buffer[-8:] if len(buffer) > 8 else buffer
                            break
                        buffer = buffer[idx + len("</think>"):]
                        in_think = False
                if out:
                    # Bỏ ký tự markdown thô trên luồng (* # `) cho bong bóng sạch.
                    yield out.replace("*", "").replace("#", "").replace("`", "")
            # xả nốt buffer còn lại (ngoài think)
            if buffer and not in_think:
                yield buffer.replace("*", "").replace("#", "").replace("`", "")
    except httpx.HTTPStatusError as e:
        # 429 = hết hạn mức mô hình (Groq miễn phí: 200.000 token/ngày cho CẢ tổ chức —
        # đường ống làm giàu dữ liệu dùng chung, xem docs/KE_HOACH_LAM_GIAU_DU_LIEU.md).
        # App nhận dạng tiền tố "[Lỗi" và thay bằng câu dễ hiểu.
        ma = e.response.status_code if e.response is not None else 0
        yield "\n[Lỗi quá tải AI]" if ma == 429 else f"\n[Lỗi kết nối AI: {ma}]"
    except httpx.HTTPError as e:
        yield f"\n[Lỗi kết nối AI: {type(e).__name__}]"
