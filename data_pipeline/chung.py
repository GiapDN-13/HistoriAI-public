"""Phần dùng chung cho mọi bước của đường ống dữ liệu.

Ba thứ ở đây quyết định đường ống có chạy qua đêm một mình được hay không:

GỌI MẠNG LỊCH SỰ
    Mỗi máy chủ nguồn tối đa 1 yêu cầu/giây, User-Agent ghi rõ dự án theo đúng
    chính sách Wikimedia, gặp 429/5xx thì lùi dần. Mọi thứ tải về đều nằm trong
    cache/ — chạy lại không tải lại.

GỌI MÔ HÌNH NGÔN NGỮ CÓ PHANH
    Khoá Groq gói miễn phí chỉ có ~8.000 token/phút và ~1.000 lượt/ngày. Bộ gọi
    tự điều tốc theo token, tự dừng khi chạm trần lượt trong ngày, và tự chờ khi
    chưa có khoá — thay vì chết giữa đêm. Kết quả được cache theo nội dung câu
    lệnh, nên chạy lại một bước đã xong không tốn thêm lượt nào.

GHI TỆP NGUYÊN TỬ
    Ghi ra tệp tạm rồi mới đổi tên. Máy mất điện giữa chừng thì tệp cũ vẫn
    nguyên, không bao giờ còn lại nửa tệp JSON hỏng.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import time
import unicodedata
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

import httpx

GOC = Path(__file__).resolve().parent
CACHE = GOC / "cache"
KET_QUA = GOC / "ket_qua"
for _d in (CACHE, KET_QUA):
    _d.mkdir(parents=True, exist_ok=True)

# Không ghi email vào User-Agent: trang chính sách riêng tư đã đủ để Wikimedia
# liên hệ nếu cần, và không phát tán địa chỉ cá nhân cho bên thứ ba.
UA = "HistoriAI-DataPipeline/0.1 (+https://historiai.anhzap.shop/rieng-tu/)"

# Console Windows mặc định cp1252 — thiếu dòng này thì in tiếng Việt là chết.
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass


# ───────────────────────── nhật ký ─────────────────────────

def ghi_log(*phan: object) -> None:
    dong = f"{datetime.now().strftime('%d/%m %H:%M:%S')}  " + " ".join(str(p) for p in phan)
    print(dong, flush=True)
    with open(KET_QUA / "nhat_ky.log", "a", encoding="utf-8") as f:
        f.write(dong + "\n")


# ───────────────────────── tệp ─────────────────────────

def doc_json(duong_dan: Path, mac_dinh=None):
    if not duong_dan.exists():
        return mac_dinh
    return json.loads(duong_dan.read_text(encoding="utf-8"))


def ghi_json(duong_dan: Path, du_lieu) -> None:
    duong_dan.parent.mkdir(parents=True, exist_ok=True)
    tam = duong_dan.with_suffix(duong_dan.suffix + ".tam")
    tam.write_text(json.dumps(du_lieu, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(tam, duong_dan)


def bam(*phan: str) -> str:
    return hashlib.sha256("\x1f".join(phan).encode("utf-8")).hexdigest()[:20]


# ───────────────────────── chuẩn hoá chữ ─────────────────────────

def nfc(s: str) -> str:
    return unicodedata.normalize("NFC", s or "")


_KHOANG = re.compile(r"\s+")
_NGOAC = str.maketrans({"“": '"', "”": '"', "‘": "'", "’": "'", "–": "-", "—": "-", "‐": "-"})


def chuan_hoa_so_khop(s: str) -> str:
    """Dạng dùng để SO KHỚP câu trích, không dùng để hiển thị.

    Việt Nam sử lược viết theo chính tả 1920, nối âm tiết bằng gạch ngang
    ("Ngô-vương", "Bạch-đằng"). Bỏ gạch nối, gộp khoảng trắng, hạ chữ thường —
    nếu không thì câu trích đúng nguyên văn vẫn bị coi là bịa.
    """
    s = nfc(s).translate(_NGOAC).lower()
    s = re.sub(r"(?<=\w)-(?=\w)", " ", s)
    s = re.sub(r"[\"'«»()\[\]]", "", s)
    return _KHOANG.sub(" ", s).strip(" .,;:")


def cac_so(s: str) -> set[str]:
    """Các con số trong câu — năm, số quân, số thuyền. Dùng để kiểm chéo bằng code."""
    s = nfc(s).replace(".", "").replace(",", "")
    return set(re.findall(r"\d{2,}", s))


def slugify(s: str) -> str:
    s = nfc(s).replace("đ", "d").replace("Đ", "D")
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = re.sub(r"[^a-zA-Z0-9]+", "-", s).strip("-").lower()
    return s[:80]


# ───────────────────────── mạng ─────────────────────────

_lan_cuoi: dict[str, float] = {}
_client = httpx.Client(headers={"User-Agent": UA}, timeout=60, follow_redirects=True)


def tai(url: str, params: dict | None = None, *, dang: str = "json", cache: bool = True):
    """GET có cache, có giới hạn 1 yêu cầu/giây mỗi máy chủ, có lùi dần."""
    khoa = bam(url, json.dumps(params or {}, sort_keys=True))
    tep = CACHE / "http" / f"{khoa}.{ 'json' if dang == 'json' else 'bin' }"
    if cache and tep.exists():
        du = tep.read_bytes()
        return json.loads(du) if dang == "json" else du

    host = urlparse(url).netloc
    for lan in range(6):
        cho = 1.05 - (time.time() - _lan_cuoi.get(host, 0))
        if cho > 0:
            time.sleep(cho)
        _lan_cuoi[host] = time.time()
        try:
            r = _client.get(url, params=params)
        except httpx.HTTPError as e:
            ghi_log("  mạng lỗi", host, type(e).__name__, "— thử lại")
            time.sleep(5 * (lan + 1))
            continue
        if r.status_code == 429 or r.status_code >= 500:
            cho = int(r.headers.get("retry-after", "0") or 0) or 10 * (lan + 1)
            ghi_log(f"  {host} trả {r.status_code}, chờ {cho}s")
            time.sleep(cho)
            continue
        r.raise_for_status()
        tep.parent.mkdir(parents=True, exist_ok=True)
        tep.write_bytes(r.content)
        return r.json() if dang == "json" else r.content
    raise RuntimeError(f"Không tải được {url} sau 6 lần")


# ───────────────────────── mô hình ngôn ngữ ─────────────────────────

class ChuaCoKhoa(Exception):
    """Chưa có khoá riêng cho đường ống. Không dùng khoá của chat — nhóm đã chốt."""


class HetNganSach(Exception):
    """Chạm trần lượt gọi trong ngày. Bước sau chạy tiếp khi sang ngày mới."""


def _doc_env() -> dict:
    tep = GOC / ".env"
    env = {}
    if tep.exists():
        for dong in tep.read_text(encoding="utf-8").splitlines():
            dong = dong.strip()
            if dong and not dong.startswith("#") and "=" in dong:
                k, v = dong.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    return env


class MoHinh:
    def __init__(self, cau_hinh: dict):
        self.ch = cau_hinh
        self._cua_so: list[tuple[float, int]] = []   # (thời điểm, số token) trong 60 giây qua
        # Groq gói miễn phí còn giới hạn TOKEN ĐẦU RA mỗi phút (OTPM = 1.000) — chặt hơn
        # nhiều so với trần tổng token. Không điều tốc theo nó thì lượt nào cũng dính 429.
        self._cua_so_ra: list[tuple[float, int]] = []
        self._tep_ngan_sach = KET_QUA / "ngan_sach.json"

    # -- sổ ngân sách: đếm lượt THẬT đã gọi, theo ngày giờ Việt Nam --
    def _so(self) -> dict:
        hom_nay = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d")
        so = doc_json(self._tep_ngan_sach, {})
        so.setdefault(hom_nay, {"luot": 0, "token": 0})
        return so, hom_nay

    def luot_con_lai(self) -> int:
        so, ngay = self._so()
        return self.ch["tran_luot_moi_ngay"] - so[ngay]["luot"]

    def _ghi_so(self, token: int) -> None:
        so, ngay = self._so()
        so[ngay]["luot"] += 1
        so[ngay]["token"] += token
        ghi_json(self._tep_ngan_sach, so)

    def _dieu_toc(self, uoc_token: int, uoc_ra: int) -> None:
        tran = self.ch["tran_token_moi_phut"]
        tran_ra = self.ch["tran_token_ra_moi_phut"]
        while True:
            bay_gio = time.time()
            self._cua_so = [(t, n) for t, n in self._cua_so if bay_gio - t < 61]
            self._cua_so_ra = [(t, n) for t, n in self._cua_so_ra if bay_gio - t < 61]
            ok_vao = sum(n for _, n in self._cua_so) + uoc_token <= tran or not self._cua_so
            ok_ra = sum(n for _, n in self._cua_so_ra) + uoc_ra <= tran_ra or not self._cua_so_ra
            if ok_vao and ok_ra:
                return
            cu_nhat = min([t for t, _ in self._cua_so] + [t for t, _ in self._cua_so_ra])
            time.sleep(max(1.0, 61 - (bay_gio - cu_nhat)))

    def hoi(self, he_thong: str, nguoi_dung: str, *, toi_da: int = 1500,
            nhan: str = "") -> str:
        khoa_cache = bam(self.ch["mo_hinh"], he_thong, nguoi_dung, str(toi_da))
        tep = CACHE / "llm" / f"{khoa_cache}.json"
        if tep.exists():
            return json.loads(tep.read_text(encoding="utf-8"))["tra_loi"]

        env = _doc_env()
        khoa = env.get("LLM_API_KEY", "")
        if not khoa:
            raise ChuaCoKhoa()
        if self.luot_con_lai() <= 0:
            raise HetNganSach()

        # ước lượng thô: tiếng Việt ~2,5 ký tự/token với các mô hình này
        # Mỗi lượt không được xin quá trần đầu ra/phút — Groq từ chối thẳng, không chờ được
        toi_da = min(toi_da, self.ch["tran_token_ra_moi_phut"] - 50)
        uoc = int((len(he_thong) + len(nguoi_dung)) / 2.5) + toi_da
        self._dieu_toc(uoc, int(toi_da * 0.8))

        url = env.get("LLM_BASE_URL", self.ch["base_url"]).rstrip("/") + "/chat/completions"
        payload = {
            "model": env.get("LLM_MODEL", self.ch["mo_hinh"]),
            "messages": [{"role": "system", "content": he_thong},
                         {"role": "user", "content": nguoi_dung}],
            "temperature": 0.1,
            "max_tokens": toi_da,
        }
        for lan in range(8):
            try:
                r = _client.post(url, json=payload,
                                 headers={"Authorization": f"Bearer {khoa}"}, timeout=120)
            except httpx.HTTPError as e:
                ghi_log("  LLM mạng lỗi", type(e).__name__)
                time.sleep(10 * (lan + 1))
                continue
            if r.status_code == 401:
                raise ChuaCoKhoa()  # khoá sai — xử lý như chưa có khoá, không đốt lượt
            if r.status_code == 429 and "request too large" in r.text.lower():
                raise RuntimeError(f"Yêu cầu quá lớn so với hạn mức [{nhan}]: {r.text[:200]}")
            if r.status_code == 429:
                cho = _giay_cho(r) or 20 * (lan + 1)
                # 429 vì hết lượt NGÀY thì chờ vô ích — dừng hẳn, để vòng ngoài chờ sang ngày
                if "requests per day" in r.text.lower() or "rpd" in r.text.lower():
                    raise HetNganSach()
                ly_do = re.sub(r"\s+", " ", r.text)[:420]
                ghi_log(f"  LLM 429 [{nhan}], chờ {cho:.0f}s — {ly_do}")
                time.sleep(cho)
                continue
            if r.status_code >= 500:
                time.sleep(15 * (lan + 1))
                continue
            if r.status_code >= 400:
                raise RuntimeError(f"LLM trả {r.status_code}: {r.text[:300]}")
            j = r.json()
            tra_loi = j["choices"][0]["message"].get("content") or ""
            tra_loi = re.sub(r"<think>.*?</think>", "", tra_loi, flags=re.S).strip()
            dung = (j.get("usage") or {}).get("total_tokens", uoc)
            ra = (j.get("usage") or {}).get("completion_tokens", toi_da)
            self._cua_so.append((time.time(), dung))
            self._cua_so_ra.append((time.time(), ra))
            self._ghi_so(dung)
            tep.parent.mkdir(parents=True, exist_ok=True)
            tep.write_text(json.dumps({"nhan": nhan, "tra_loi": tra_loi}, ensure_ascii=False),
                           encoding="utf-8")
            return tra_loi
        raise RuntimeError(f"LLM không trả lời sau 8 lần [{nhan}]")

    def hoi_json(self, he_thong: str, nguoi_dung: str, **kw):
        """Như hoi() nhưng bóc JSON ra. Trả None nếu mô hình trả rác — người gọi tự bỏ qua."""
        tra_loi = self.hoi(he_thong + "\n\nChỉ trả về JSON hợp lệ, không giải thích, không markdown.",
                           nguoi_dung, **kw)
        return boc_json(tra_loi)


def _giay_cho(r: httpx.Response) -> float:
    ra = r.headers.get("retry-after")
    if ra:
        try:
            return float(ra)
        except ValueError:
            pass
    m = re.search(r"try again in ([\d.]+)(ms|s|m)", r.text)
    if m:
        so = float(m.group(1))
        return so / 1000 if m.group(2) == "ms" else so * 60 if m.group(2) == "m" else so
    return 0


def boc_json(s: str):
    s = s.strip()
    s = re.sub(r"^```(?:json)?|```$", "", s, flags=re.M).strip()
    # Thử loại ngoặc MỞ TRƯỚC trước. Trước đây luôn thử "[" trước, nên một object
    # như {"thcs": "...", "menh_de_dung": [1, 2]} bị bóc ra thành mảng con [1, 2]
    # — cả 5 tóm tắt vòng 1 hỏng vì thế, và B4 mất cặp khi không có "mau_thuan".
    # Chỉ thử ĐÚNG loại ngoặc ngoài cùng: object hỏng mà lùi sang tìm "[" thì lại
    # bóc ra một mảng con, và người gọi đang chờ dict sẽ vỡ.
    vi_tri = [(s.find(mo), mo, dong) for mo, dong in (("[", "]"), ("{", "}")) if s.find(mo) != -1]
    if not vi_tri:
        return None
    i, mo, dong = min(vi_tri)
    j = s.rfind(dong)
    if j <= i:
        return None
    try:
        return json.loads(s[i:j + 1])
    except json.JSONDecodeError:
        pass
    if mo == "[":
        # Mảng hỏng (vd mô hình quên dấu "{" ở phần tử thứ ba): vớt từng object
        # còn lành thay vì vứt cả mảng — trận Bạch Đằng 938 mất trắng câu hỏi vì thế.
        vot = [o for o in _cac_object(s[i:j + 1]) if isinstance(o, dict)]
        return vot or None
    return None


def _cac_object(s: str) -> list:
    """Các object {...} cân ngoặc ở cấp ngoài cùng của chuỗi, bỏ qua ngoặc nằm trong chuỗi."""
    ra, sau, bat_dau, trong_chuoi, thoat = [], 0, -1, False, False
    for k, c in enumerate(s):
        if trong_chuoi:
            if thoat:
                thoat = False
            elif c == "\\":
                thoat = True
            elif c == '"':
                trong_chuoi = False
            continue
        if c == '"':
            trong_chuoi = True
        elif c == "{":
            if sau == 0:
                bat_dau = k
            sau += 1
        elif c == "}" and sau > 0:
            sau -= 1
            if sau == 0:
                try:
                    ra.append(json.loads(s[bat_dau:k + 1]))
                except json.JSONDecodeError:
                    pass
    return ra


def an_toan(buoc: str, slug: str, viec) -> None:
    """Chạy việc cho MỘT thực thể; lỗi bất ngờ thì ghi nhật ký rồi bỏ qua thực thể đó.

    Hết khoá / hết lượt thì vẫn ném lên để vòng ngoài chờ. Chỉ lỗi lạ (dữ liệu
    kỳ quặc ở một bài) mới bị nuốt — để một bài hỏng không làm dừng cả đêm.
    """
    try:
        viec()
    except (ChuaCoKhoa, HetNganSach):
        raise
    except Exception as loi:  # noqa: BLE001
        import traceback
        ghi_log(f"  {buoc} {slug}: LỖI, bỏ qua thực thể này — {type(loi).__name__}: {loi}")
        with open(KET_QUA / "loi_thuc_the.log", "a", encoding="utf-8") as f:
            f.write(f"{buoc} {slug}\n{traceback.format_exc()}\n")


def bi_loai_tru(tt: dict, ch: dict) -> bool:
    return tt.get("vong") == 2 and tt["slug"] in set(ch.get("vong_2", {}).get("loai_tru") or [])


def doc_cau_hinh() -> dict:
    import yaml
    return yaml.safe_load((GOC / "cau_hinh.yaml").read_text(encoding="utf-8"))
