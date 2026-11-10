"""Xuất kho sử liệu cho Chat Vĩ Nhân từ kết quả kiểm chứng chéo (b4).

VÌ SAO
    Kiểm thật 27/09: hỏi Trần Hưng Đạo "sau trận Bạch Đằng quân giặc ra sao?", mô hình
    đáp "chủ tướng Toa Đô bị bắt" — sai (năm 1288 người bị bắt là Ô Mã Nhi). Sử liệu
    đã nạp cho vĩ nhân chỉ có 8 dòng tiểu sử, không một dòng về các trận đánh, nên mô
    hình phải tự điền. Kho này đưa các mệnh đề CÓ TRÍCH DẪN NGUYÊN VĂN vào chat.

LẤY GÌ
    Mệnh đề của chính vĩ nhân + các sự kiện gắn với vĩ nhân (VI_NHAN bên dưới):
      hạng A (≥2 nguồn độc lập xác nhận) và B (1 nguồn, có câu trích nguyên văn đã
      kiểm) → dùng làm dữ kiện; hạng C (các nguồn mâu thuẫn) → ghi "chưa thống nhất",
      để vĩ nhân nói rõ thay vì chọn đại. Mệnh đề nằm trong da_loai.txt thì bỏ.

DÙNG
    python xuat_su_lieu_chat.py [ra.json]     (mặc định ket_qua/su_lieu_chat.json)
    Rồi chép vào backend/data/su_lieu_chat.json và khởi động lại API.
"""
import json
import pathlib
import sys

GOC = pathlib.Path(__file__).resolve().parent
B4 = GOC / "ket_qua" / "b4"

VI_NHAN = {
    "tran-hung-dao": ["tran-hung-dao", "bach-dang-1288"],
    "quang-trung": ["quang-trung", "quang-trung-1789", "nha-tay-son"],
}

TEN_NGUON = {
    "wikipedia": "Wikipedia tiếng Việt",
    "enwiki": "Wikipedia tiếng Anh",
    "vnsl": "Việt Nam sử lược (Trần Trọng Kim)",
    "wikidata": "Wikidata",
}


def _da_loai() -> set[str]:
    p = GOC / "ket_qua" / "da_loai.txt"
    if not p.exists():
        return set()
    return {d.strip() for d in p.read_text(encoding="utf-8").splitlines() if d.strip()}


def main() -> int:
    ra = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else GOC / "ket_qua" / "su_lieu_chat.json"
    loai = _da_loai()
    kho: dict[str, list[dict]] = {}
    for vi_nhan, thuc_the in VI_NHAN.items():
        da_co: set[str] = set()
        ds: list[dict] = []
        for tt in thuc_the:
            tep = B4 / f"{tt}.json"
            if not tep.exists():
                print(f"  thiếu {tep.name}, bỏ qua")
                continue
            for m in json.loads(tep.read_text(encoding="utf-8")).get("menh_de", []):
                t = (m.get("noi_dung") or "").strip()
                hang = m.get("hang")
                if not t or hang not in ("A", "B", "C") or t in da_co:
                    continue
                if any(t in d for d in loai):
                    continue
                da_co.add(t)
                ds.append({
                    "t": t,
                    "hang": hang,
                    "nguon": TEN_NGUON.get(m.get("nguon"), m.get("nguon") or ""),
                    "url": m.get("url") or "",
                    "su_kien": tt,
                })
        kho[vi_nhan] = ds
        dem = {h: sum(1 for x in ds if x["hang"] == h) for h in "ABC"}
        print(f"  {vi_nhan}: {len(ds)} mệnh đề {dem}")
    ra.write_text(json.dumps(kho, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"  ghi {ra}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
