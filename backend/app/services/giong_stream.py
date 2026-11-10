"""Phát giọng nói theo luồng: bắt đầu tạo NGAY khi app xin, phát được khi đang tạo.

LUỒNG
    1. App POST một câu → `bat_dau()` trả mã phiên và khởi chạy luồng nền tạo
       giọng, ghi dần MP3 ra `<mã>.mp3.part`.
    2. Thẻ <audio> của app GET `/chat/audio/stream/<mã>.mp3` → `doc()` đọc đuổi
       theo tệp đang ghi, nên tiếng đầu ra sau ~0,6 s thay vì đợi cả câu (~7 s).
    3. Xong thì đổi tên thành `<mã>.mp3`: lần sau (hoặc người khác hỏi đúng câu
       đó) phát thẳng từ tệp.

VÌ SAO TÁCH POST VÀ GET
    Thẻ <audio> chỉ biết GET. Và tách ra thì app POST được câu 2, 3 ngay khi chữ
    về — chúng được tạo trong lúc câu 1 đang phát, tới lượt là có sẵn.

XẾP HÀNG CHỜ VIENEU — KHÔNG NHẢY SANG GIỌNG KHÁC (sửa 27/09)
    VieNeu tạo tuần tự và từ chối (503) khi có quá VIENEU_MAX_CHO câu. App xin mọi câu
    của một câu trả lời gần như cùng lúc (để câu sau có sẵn khi câu trước phát xong),
    nên trước đây câu 3 trở đi bị 503 → rơi sang Edge = GIỌNG MẶC ĐỊNH, nghe như nhân
    vật đổi giọng giữa chừng. Giờ mọi câu xếp hàng qua `_cua_vieneu` (một câu một lúc,
    theo thứ tự xin) và gặp 503 thì thử lại, tới CHO_VIENEU_S mới chịu dùng dự phòng.

DỰ PHÒNG
    VieNeu hỏng thật / chờ quá lâu → tạo cả câu bằng TTS_DU_PHONG (Edge) rồi phát.
    Bản dự phòng lưu ở `<mã>.dp.mp3`, KHÔNG phải `<mã>.mp3`: trước đây lưu chung tên
    nên câu đó mãi mãi phát giọng mặc định, kể cả khi VieNeu đã rảnh.
    Cả hai hỏng → phiên báo lỗi, route trả 503, app tự đọc bằng giọng trình duyệt.

Mã phiên = băm(provider + giọng + câu): cùng câu cùng giọng dùng chung một tệp.
"""
from __future__ import annotations

import hashlib
import shutil
import threading
import time
from collections import OrderedDict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterator

import httpx

from app.core.config import settings
from app.services import tts

KHOI = 16 * 1024
TOI_DA_PHIEN = 500          # giữ trong bộ nhớ; quá thì bỏ phiên cũ nhất (tệp vẫn còn)
CHO_TOI_DA_S = 120          # đọc đuổi quá lâu không có dữ liệu mới thì thôi
CHO_VIENEU_S = 90           # chờ tới lượt VieNeu tối đa bấy nhiêu giây rồi mới dùng dự phòng
PHIEN_DU_PHONG_S = 300      # bản dự phòng chỉ dùng lại trong 5 phút, sau đó thử VieNeu lại

# Một câu một lúc: VieNeu chạy CPU tuần tự, gửi song song chỉ tổ bị 503. Semaphore của
# CPython đánh thức theo thứ tự chờ → câu xin trước được tạo trước.
_cua_vieneu = threading.Semaphore(1)


@dataclass
class Phien:
    ma: str
    voice: str
    text: str
    xong: threading.Event = field(default_factory=threading.Event)
    # Đã ghi hết byte vào .part (chưa chắc đã đổi tên). Người đọc dựa vào cờ này để
    # biết khi nào dừng — nếu đợi `xong` thì trên Windows sẽ kẹt nhau: không đổi tên
    # được tệp đang mở, mà người đọc thì giữ tệp mở tới khi `xong`.
    ghi_xong: threading.Event = field(default_factory=threading.Event)
    loi: str | None = None
    nguon: str = ""          # "vieneu" | "du_phong" | "cache"
    tao_luc: float = field(default_factory=time.time)


_phien: "OrderedDict[str, Phien]" = OrderedDict()
_khoa = threading.Lock()


def _thu_muc() -> Path:
    d = tts._CACHE_DIR
    d.mkdir(parents=True, exist_ok=True)
    return d


def ma_phien(voice: str, text: str) -> str:
    # "stream2": đổi 27/09 để bỏ lưu đệm cũ — trong đó lẫn nhiều câu giọng Edge lưu nhầm tên.
    # "stream3": đổi 21/10 khi đổi tham số đọc từng giọng (vieneu_service/server.py THAM_SO)
    # — câu đã lưu đệm đọc theo tham số cũ, không đổi khoá thì vẫn phát giọng cũ.
    return hashlib.sha256(f"stream3|{settings.TTS_PROVIDER}|{voice}|{text}".encode()).hexdigest()[:32]


def tep_xong(ma: str) -> Path:
    return _thu_muc() / f"{ma}.mp3"


def tep_dang_ghi(ma: str) -> Path:
    return _thu_muc() / f"{ma}.mp3.part"


def tep_du_phong(ma: str) -> Path:
    return _thu_muc() / f"{ma}.dp.mp3"


def _stream_mot_lan(p: Phien) -> int:
    """Một lượt gọi vieneu_service, ghi vào .part. Trả mã HTTP (0 = lỗi kết nối)."""
    part = tep_dang_ghi(p.ma)
    try:
        with httpx.stream("POST", f"{settings.VIENEU_URL.rstrip('/')}/tts/stream",
                          json={"voice": p.voice, "text": p.text},
                          timeout=httpx.Timeout(settings.TTS_TIMEOUT, connect=3.0)) as r:
            if r.status_code != 200:
                return r.status_code
            with open(part, "wb") as f:
                for b in r.iter_bytes(KHOI):
                    f.write(b)
                    f.flush()
        return 200 if part.stat().st_size > 0 else 0
    except (httpx.HTTPError, OSError):
        return 0


def _tao_vieneu(p: Phien) -> bool:
    """Xếp hàng rồi stream từ VieNeu. True nếu có đủ tiếng GIỌNG NHÂN VẬT.

    Bận (503, vd người khác cũng đang nghe) thì đợi rồi thử lại chứ không bỏ cuộc —
    câu này thường chưa tới lượt phát, chờ vài giây còn hơn đổi giọng."""
    han = time.time() + CHO_VIENEU_S
    if not _cua_vieneu.acquire(timeout=CHO_VIENEU_S):
        return False
    try:
        while True:
            ma = _stream_mot_lan(p)
            if ma == 200:
                return True
            tep_dang_ghi(p.ma).unlink(missing_ok=True)
            if ma != 503 or time.time() > han:
                return False
            time.sleep(0.5)
    finally:
        _cua_vieneu.release()


def _doi_ten(p: Phien) -> None:
    part, dich = tep_dang_ghi(p.ma), tep_xong(p.ma)
    if not part.exists():
        return
    for _ in range(100):             # Windows: đợi người đọc đóng tệp (Linux đổi tên được ngay)
        try:
            part.replace(dich)
            return
        except PermissionError:
            time.sleep(0.1)


def _chay(p: Phien) -> None:
    try:
        if settings.TTS_PROVIDER == "vieneu" and _tao_vieneu(p):
            p.ghi_xong.set()
            _doi_ten(p)
            p.nguon = "vieneu"
            return
        # Không stream được (bận, lỗi, hoặc đang dùng nhà cung cấp khác) → tạo cả câu
        tep_dang_ghi(p.ma).unlink(missing_ok=True)
        if settings.TTS_PROVIDER != "vieneu":
            ten = tts.synthesize(p.text, p.voice)
            dich = tep_xong(p.ma)            # nhà cung cấp chính → lưu đệm bình thường
        else:
            ten = tts.synth_du_phong(p.text, p.voice)
            dich = tep_du_phong(p.ma)        # giọng dự phòng → KHÔNG giữ tên chính
        if ten:
            shutil.copyfile(tts._CACHE_DIR / ten, dich)
            p.nguon = "du_phong"
        else:
            p.loi = "không tạo được giọng"
    except Exception as e:  # noqa: BLE001 — luồng nền không được chết im lặng
        p.loi = f"{type(e).__name__}: {e}"
    finally:
        p.ghi_xong.set()
        p.xong.set()


def bat_dau(voice: str, text: str) -> str:
    """Khởi chạy (nếu chưa) việc tạo giọng cho câu này. Trả mã phiên ngay lập tức."""
    text = tts.clean_for_speech(text)
    ma = ma_phien(voice, text)
    with _khoa:
        cu = _phien.get(ma)
        # Phiên dự phòng đã cũ thì bỏ, thử lại VieNeu — có thể nó đã rảnh.
        het_han_dp = (cu is not None and cu.nguon == "du_phong" and cu.xong.is_set()
                      and time.time() - cu.tao_luc > PHIEN_DU_PHONG_S)
        if cu is not None and not cu.loi and not het_han_dp:
            _phien.move_to_end(ma)
            return ma
        p = Phien(ma, voice, text)
        if tep_xong(ma).exists():
            p.nguon = "cache"
            p.xong.set()
        _phien[ma] = p
        while len(_phien) > TOI_DA_PHIEN:
            _phien.popitem(last=False)
    if not p.xong.is_set():
        threading.Thread(target=_chay, args=(p,), daemon=True, name=f"giong-{ma[:8]}").start()
    return ma


def doc(ma: str) -> Iterator[bytes] | None:
    """Byte MP3 của phiên — đọc đuổi theo tệp đang ghi. None nếu không biết mã này."""
    xong = tep_xong(ma)
    with _khoa:
        p = _phien.get(ma)
    if p is None:
        return _doc_tep(xong) if xong.exists() else None

    def duoi() -> Iterator[bytes]:
        # Chờ tệp xuất hiện (.part khi stream, tệp xong, hoặc bản dự phòng)
        dp = tep_du_phong(ma)
        bat_dau_cho = time.time()
        while not (xong.exists() or tep_dang_ghi(ma).exists()
                   or (p.nguon == "du_phong" and dp.exists())):
            if p.xong.is_set() or time.time() - bat_dau_cho > CHO_TOI_DA_S:
                break
            time.sleep(0.03)
        if xong.exists():
            yield from _doc_tep(xong)
            return
        if p.nguon == "du_phong" and dp.exists():
            yield from _doc_tep(dp)
            return
        part = tep_dang_ghi(ma)
        f = None
        for _ in range(40):
            try:
                f = open(part, "rb")
                break
            except FileNotFoundError:
                break
            except PermissionError:
                # Windows: tệp đang bị xoá/đổi tên dở (lượt VieNeu hỏng dọn .part) — chờ chút
                time.sleep(0.05)
        if f is None:
            # Vừa kịp đổi tên thành tệp xong, hoặc chuyển sang bản dự phòng
            if xong.exists():
                yield from _doc_tep(xong)
            elif dp.exists():
                yield from _doc_tep(dp)
            return
        # Đọc bằng cùng một handle: trên Linux đổi tên tệp không làm hỏng handle đang mở,
        # nên đọc tiếp tới hết dù .part đã thành .mp3.
        with f:
            lan_cuoi = time.time()
            while True:
                b = f.read(KHOI)
                if b:
                    lan_cuoi = time.time()
                    yield b
                    continue
                if p.ghi_xong.is_set():
                    rest = f.read()
                    if rest:
                        yield rest
                    return
                if time.time() - lan_cuoi > CHO_TOI_DA_S:
                    return
                time.sleep(0.03)

    return duoi()


def _doc_tep(path: Path) -> Iterator[bytes]:
    with open(path, "rb") as f:
        while b := f.read(KHOI):
            yield b


def trang_thai(ma: str) -> Phien | None:
    with _khoa:
        return _phien.get(ma)
