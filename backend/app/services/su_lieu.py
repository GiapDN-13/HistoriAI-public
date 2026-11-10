"""Chọn sử liệu CÓ NGUỒN đưa vào chat, để vĩ nhân không phải tự điền.

Hai kho, gộp lại khi nạp:
  • data/ho_so_nhom.json — HỒ SƠ NHÂN VẬT do nhóm biên soạn (tools/nap_ho_so_nhom.py),
    hạng "K", ƯU TIÊN CAO NHẤT: người biên soạn đã đối chiếu và ghi sẵn lưu ý diễn giải.
  • data/su_lieu_chat.json — mệnh đề tự động của đường ống làm giàu dữ liệu
    (data_pipeline/xuat_su_lieu_chat.py): hạng A/B có trích dẫn nguyên văn, hạng C
    (nguồn mâu thuẫn) ghi là "chưa thống nhất".

CHỌN THẾ NÀO
    Không nhét cả ~150 mệnh đề vào mỗi câu hỏi — hạn mức Groq miễn phí tính theo token,
    và dùng chung với đường ống. Chấm điểm từng mệnh đề theo đặc trưng trùng với câu
    hỏi (+ 2 lượt trước, để "vậy sau đó thì sao?" vẫn tìm đúng chỗ), lấy SO_MENH_DE
    mệnh đề cao nhất (~700 token).
      • Đặc trưng = âm tiết + CẶP ÂM TIẾT + năm. Tiếng Việt đơn âm tiết, nên cặp
        ("ô mã", "bắt sống") bắt tên riêng và ý tốt hơn âm tiết lẻ.
      • Nhân độ hiếm (IDF) trong kho của vĩ nhân: "bạch đằng" có ở nửa số mệnh đề nên
        gần như không phân biệt được gì — thiếu IDF thì câu hỏi có chữ "Bạch Đằng" chỉ
        lấy về toàn câu chung chung, sót đúng câu "bắt sống Ô Mã Nhi".
    Không có mệnh đề nào khớp (chào hỏi, lạc đề) → vài mệnh đề hạng A làm nền.
"""
from __future__ import annotations

import json
import math
import re
import unicodedata
from functools import lru_cache
from pathlib import Path

KHO = Path(__file__).resolve().parents[2] / "data" / "su_lieu_chat.json"
HO_SO = Path(__file__).resolve().parents[2] / "data" / "ho_so_nhom.json"
SO_MENH_DE = 22
SO_NEN = 6
# Ý của hồ sơ nhóm dài hơn mệnh đề đường ống — chặn tổng độ dài để giữ ~1.000 token.
TOI_DA_KY_TU = 3000
DIEM_HO_SO = 1.5   # nhân điểm cho ý của hồ sơ nhóm: cùng mức khớp thì hồ sơ nhóm thắng

# Âm tiết quá phổ biến, khớp nhau chẳng nói lên gì
_BO = {
    "là", "và", "của", "có", "được", "trong", "các", "những", "một", "cho", "với",
    "đã", "không", "thì", "ta", "ngài", "con", "năm", "này", "đó", "khi", "ra", "vào",
    "gì", "nào", "sao", "thế", "như", "để", "bị", "về", "từ", "sau", "trước", "người",
    "vậy", "hỏi", "ạ", "nhỉ", "à",
}

# Câu hỏi về "kết cục", "quân giặc" thường không chứa đúng chữ trong sử liệu ("bắt
# sống", "tan", "Nguyên"). Mở rộng nhẹ — chỉ THÊM đặc trưng, không bỏ bớt.
_MO_RONG = {
    "giặc": "nguyên mông thanh tống",
    "sao": "bắt sống đánh tan thua chạy",
    "kết": "bắt sống đánh tan thua chạy",
    "thắng": "đánh tan bắt sống",
    "thua": "đánh tan bắt sống bỏ chạy",
}

_IDF: dict[str, dict[str, float]] = {}


def _bo_dau(s: str) -> str:
    s = unicodedata.normalize("NFD", s.lower().replace("đ", "d"))
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def _am_tiet(s: str) -> list[str]:
    """Âm tiết ĐÃ BỎ DẤU: học sinh hay gõ không dấu ("bat song o ma nhi"). So cả hai
    phía sau khi bỏ dấu thì câu có dấu vẫn khớp như cũ, câu không dấu cũng khớp."""
    return re.findall(r"[0-9a-z]+", _bo_dau(s))


_BO = {_bo_dau(w) for w in _BO}
_MO_RONG = {_bo_dau(k): _bo_dau(v) for k, v in _MO_RONG.items()}

def _dac_trung(s: str) -> set[str]:
    at = _am_tiet(s)
    don = {w for w in at if w not in _BO and len(w) > 1}
    cap = {f"{a} {b}" for a, b in zip(at, at[1:]) if not (a in _BO or b in _BO)}
    so = {w for w in at if w.isdigit() and len(w) >= 3}          # năm: 1288, 1789
    return don | cap | so


def _cau_hoi(cau: str) -> set[str]:
    at = set(_am_tiet(cau))
    them = " ".join(v for k, v in _MO_RONG.items() if k in at)
    return _dac_trung(cau) | _dac_trung(them)


def _doc(p: Path) -> dict[str, list[dict]]:
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


@lru_cache(maxsize=1)
def _kho() -> dict[str, list[dict]]:
    d: dict[str, list[dict]] = {}
    for p in (HO_SO, KHO):            # hồ sơ nhóm đứng trước
        for slug, ds in _doc(p).items():
            d.setdefault(slug, []).extend(ds)
    for slug, ds in d.items():
        df: dict[str, int] = {}
        for m in ds:
            # Tên mục của hồ sơ nhóm ("Trận Bạch Đằng (1288) › Bố trí và diễn biến")
            # cũng là đặc trưng: câu hỏi về trận nào tìm đúng đoạn của trận đó.
            m["_dt"] = _dac_trung(m["t"] + " " + m.get("muc", ""))
            for k in m["_dt"]:
                df[k] = df.get(k, 0) + 1
        n = len(ds) or 1
        _IDF[slug] = {k: math.log((n + 1) / (v + 0.5)) for k, v in df.items()}
    return d


def _noi_dung(h) -> str:
    if isinstance(h, dict):
        return h.get("content") or ""
    return getattr(h, "content", "") or ""


def chon(slug: str, cau_hoi: str, lich_su: list | None = None) -> list[dict]:
    """Các mệnh đề liên quan nhất tới câu hỏi (và 2 lượt gần nhất)."""
    ds = _kho().get(slug) or []
    if not ds:
        return []
    idf = _IDF.get(slug, {})
    q = _cau_hoi(cau_hoi)
    q_cu = _cau_hoi(" ".join(_noi_dung(h) for h in (lich_su or [])[-2:]))

    def w(k: str) -> float:
        return idf.get(k, 1.0) * (2.0 if (" " in k or k.isdigit()) else 1.0)

    diem = []
    for i, m in enumerate(ds):
        # câu hỏi hiện tại nặng gấp đôi lượt cũ
        d = 2 * sum(w(k) for k in m["_dt"] & q) + sum(w(k) for k in m["_dt"] & q_cu)
        if d > 1.0:
            if m["hang"] == "K":
                d *= DIEM_HO_SO
            elif m["hang"] == "A":
                d += 0.5
            diem.append((d, -i, m))
    diem.sort(key=lambda x: (x[0], x[1]), reverse=True)
    chon_: list[dict] = []
    tong = 0
    for _, _, m in diem:
        dai = len(m["t"]) + len(_muc_ngan(m))
        if len(chon_) >= SO_MENH_DE or tong + dai > TOI_DA_KY_TU:
            continue
        chon_.append(m)
        tong += dai
    if len(chon_) < SO_NEN:
        # Không khớp gì (chào hỏi, lạc đề): hồ sơ nhóm phần "Hồ sơ nhân vật" làm nền,
        # không có hồ sơ thì dùng mệnh đề hạng A.
        for m in ds:
            if m["hang"] in ("K", "A") and m not in chon_:
                chon_.append(m)
            if len(chon_) >= SO_NEN:
                break
    return chon_


def _muc_ngan(m: dict) -> str:
    """Chỉ giữ 2 cấp tiêu đề cuối ("Trận Bạch Đằng (1288) › Kết quả") — đủ ngữ cảnh,
    đỡ tốn token hơn cả chuỗi đầy đủ."""
    muc = m.get("muc") or ""
    return " › ".join(muc.split(" › ")[-2:])


def dinh_dang(ds: list[dict]) -> str:
    ho_so = [m for m in ds if m["hang"] == "K"]
    khac = [m for m in ds if m["hang"] != "K"]
    dong = []
    if ho_so:
        dong.append("## Hồ sơ nhân vật do nhóm biên soạn (ƯU TIÊN — mâu thuẫn với nguồn khác thì theo phần này)")
        for m in ho_so:
            dong.append(f"- ({_muc_ngan(m)}) {m['t']}" if m.get("muc") else f"- {m['t']}")
    if khac:
        if ho_so:
            dong.append("## Trích từ nguồn khác")
        for m in khac:
            if m["hang"] == "C":
                dong.append(f"- (CÁC NGUỒN CHƯA THỐNG NHẤT) {m['t']}")
            else:
                dong.append(f"- {m['t']} [{m['nguon']}]")
    return "\n".join(dong)


def nguon_da_dung(ds: list[dict]) -> list[str]:
    ra: list[str] = []
    for m in ds:
        if m["hang"] != "C" and m["nguon"] and m["nguon"] not in ra:
            ra.append(m["nguon"])
    return ra
