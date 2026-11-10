#!/usr/bin/env python3
"""Chuẩn hoá tỉ lệ tệp .glb về đơn vị mét theo kích thước thật của cổ vật.

VÌ SAO CẦN:
    Model tải từ Sketchfab mang tỉ lệ tuỳ tác giả đặt — cái thì 1 đơn vị = 1cm,
    cái thì nút gốc đã nhân sẵn 6,8 lần. Trên `viewer.html` không ai để ý, vì
    model-viewer tự đóng khung cho vừa màn hình.

    Nhưng AR thì khác. Scene Viewer đặt model ra giữa phòng theo đúng đơn vị
    mét ghi trong tệp, và tham số `resizable=false` khoá luôn không cho người
    dùng phóng to thu nhỏ. Tệp sai tỉ lệ nghĩa là cái trống đồng cao 0,6m hiện
    ra to bằng cái bàn — người học nhớ sai kích thước cổ vật, còn tệ hơn là
    không có tính năng này.

CÁCH LÀM:
    1. Đọc `real_scale_meters` (chiều lớn nhất của hiện vật, mét) trong
       `backend/data/seed_data.json` — một nguồn sự thật duy nhất, không chép
       số ra hai chỗ.
    2. Tính hộp bao của model trong toạ độ thế giới: lấy `min`/`max` của
       accessor POSITION từng primitive, dựng 8 đỉnh hộp, đưa qua ma trận của
       chuỗi nút cha rồi gộp lại.
    3. Nhân `scale` **và** `translation` của mọi nút gốc với
       `real_scale_meters / chiều_lớn_nhất_hiện_tại`. Phải nhân cả translation
       thì phép co giãn mới là co giãn quanh gốc toạ độ — model nhiều nút gốc
       (kiếm Đông Sơn, thuyền chiến) nếu chỉ nhân `scale` sẽ bị rời các mảnh ra.

    Không đụng vào dữ liệu đỉnh, nên phần nén Draco và texture WebP giữ
    nguyên — chỉ khối JSON của glTF thay đổi.

CHẠY LẠI NHIỀU LẦN KHÔNG CỘNG DỒN:
    Lần đầu, tỉ lệ và vị trí gốc của mỗi nút gốc được cất vào
    `node.extras.historiai_chuan_hoa`. Mỗi lần chạy sau đều khôi phục về số gốc
    đó trước rồi mới tính lại từ đầu — chạy 10 lần vẫn ra đúng một kết quả.

DÙNG:
    python tool/chuan_hoa_ti_le.py                  # chuẩn hoá tất cả
    python tool/chuan_hoa_ti_le.py trong-dong-dong-son kiem-dong-son
    python tool/chuan_hoa_ti_le.py --kiem-tra       # chỉ báo cáo, không ghi tệp

    Chạy từ thư mục `mobile/`.
"""
from __future__ import annotations

import json
import math
import pathlib
import struct
import sys

# Console Windows mặc định là cp1252, không có chữ tiếng Việt. Thiếu dòng này
# thì script ghi tệp xong vẫn chết ở câu print và trả mã lỗi.
for _luong in (sys.stdout, sys.stderr):
    try:
        _luong.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

GOC = pathlib.Path(__file__).resolve().parent.parent          # .../mobile
THU_MUC_MODEL = GOC / "web" / "models"
SEED = GOC.parent / "backend" / "data" / "seed_data.json"

KHOA_EXTRAS = "historiai_chuan_hoa"

CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942


# --- Đọc / ghi GLB -----------------------------------------------------

def doc_glb(duong_dan: pathlib.Path) -> tuple[dict, bytes]:
    """Tách tệp .glb thành (khối JSON đã parse, khối nhị phân thô)."""
    raw = duong_dan.read_bytes()
    if raw[:4] != b"glTF":
        raise ValueError(f"{duong_dan.name}: không phải tệp GLB")
    tong = struct.unpack_from("<I", raw, 8)[0]
    js: dict | None = None
    binary = b""
    off = 12
    while off < min(tong, len(raw)):
        do_dai, loai = struct.unpack_from("<II", raw, off)
        than = raw[off + 8: off + 8 + do_dai]
        if loai == CHUNK_JSON:
            js = json.loads(than.decode("utf-8"))
        elif loai == CHUNK_BIN:
            binary = than
        off += 8 + do_dai
    if js is None:
        raise ValueError(f"{duong_dan.name}: không tìm thấy khối JSON")
    return js, binary


def ghi_glb(duong_dan: pathlib.Path, js: dict, binary: bytes) -> None:
    """Dựng lại tệp .glb. Mỗi khối phải dài bội số 4 byte, đệm JSON bằng dấu
    cách và đệm khối nhị phân bằng byte 0 — đúng như đặc tả glTF 2.0."""
    than_json = json.dumps(js, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    than_json += b" " * (-len(than_json) % 4)
    than_bin = binary + b"\x00" * (-len(binary) % 4)

    tong = 12 + 8 + len(than_json) + (8 + len(than_bin) if than_bin else 0)
    ra = bytearray()
    ra += b"glTF" + struct.pack("<II", 2, tong)
    ra += struct.pack("<II", len(than_json), CHUNK_JSON) + than_json
    if than_bin:
        ra += struct.pack("<II", len(than_bin), CHUNK_BIN) + than_bin
    duong_dan.write_bytes(bytes(ra))


# --- Ma trận 4x4 (hàng-chính trong bộ nhớ, nhân theo quy ước cột) ------

def nhan(a: list[float], b: list[float]) -> list[float]:
    """Nhân hai ma trận 4x4 lưu theo thứ tự cột-chính như glTF."""
    ra = [0.0] * 16
    for c in range(4):
        for r in range(4):
            ra[c * 4 + r] = sum(a[k * 4 + r] * b[c * 4 + k] for k in range(4))
    return ra


def ma_tran_nut(nut: dict) -> list[float]:
    """Ma trận cục bộ của một nút: lấy `matrix` nếu có, không thì dựng từ
    translation · rotation · scale theo đúng thứ tự glTF quy định."""
    if "matrix" in nut:
        return list(nut["matrix"])

    tx, ty, tz = nut.get("translation", [0.0, 0.0, 0.0])
    x, y, z, w = nut.get("rotation", [0.0, 0.0, 0.0, 1.0])
    sx, sy, sz = nut.get("scale", [1.0, 1.0, 1.0])

    # Quaternion -> ma trận xoay 3x3
    r = [
        1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w),
        2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w),
        2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y),
    ]
    return [
        r[0] * sx, r[1] * sx, r[2] * sx, 0.0,
        r[3] * sy, r[4] * sy, r[5] * sy, 0.0,
        r[6] * sz, r[7] * sz, r[8] * sz, 0.0,
        tx, ty, tz, 1.0,
    ]


def bien_doi_diem(m: list[float], p: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = p
    return (
        m[0] * x + m[4] * y + m[8] * z + m[12],
        m[1] * x + m[5] * y + m[9] * z + m[13],
        m[2] * x + m[6] * y + m[10] * z + m[14],
    )


# --- Hộp bao -----------------------------------------------------------

def hop_bao(js: dict) -> tuple[list[float], list[float]] | None:
    """Hộp bao của cả cảnh trong toạ độ thế giới.

    Duyệt từ các nút gốc của scene mặc định, dồn ma trận cha xuống con, và với
    mỗi primitive lấy `min`/`max` của accessor POSITION dựng thành 8 đỉnh. Phải
    biến đổi cả 8 đỉnh chứ không chỉ hai điểm min/max: khi nút có phép xoay,
    biến đổi riêng hai điểm đó cho ra hộp sai.
    """
    thap = [math.inf] * 3
    cao = [-math.inf] * 3

    scenes = js.get("scenes") or []
    if not scenes:
        return None
    goc = scenes[js.get("scene", 0)].get("nodes", [])

    def di(chi_so: int, cha: list[float]) -> None:
        nut = js["nodes"][chi_so]
        m = nhan(cha, ma_tran_nut(nut))

        if "mesh" in nut:
            for prim in js["meshes"][nut["mesh"]].get("primitives", []):
                acc_i = prim.get("attributes", {}).get("POSITION")
                if acc_i is None:
                    continue
                acc = js["accessors"][acc_i]
                lo, hi = acc.get("min"), acc.get("max")
                if not lo or not hi:
                    # Không có min/max thì phải giải nén Draco mới biết hộp bao.
                    # Chưa gặp trường hợp này; báo thẳng thay vì tính ra số sai.
                    raise ValueError(
                        f"accessor {acc_i} thiếu min/max — không tính được hộp bao"
                    )
                for i in range(8):
                    p = (
                        hi[0] if i & 1 else lo[0],
                        hi[1] if i & 2 else lo[1],
                        hi[2] if i & 4 else lo[2],
                    )
                    q = bien_doi_diem(m, p)
                    for t in range(3):
                        thap[t] = min(thap[t], q[t])
                        cao[t] = max(cao[t], q[t])

        for con in nut.get("children", []):
            di(con, m)

    don_vi = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]
    for g in goc:
        di(g, don_vi)

    if math.isinf(thap[0]):
        return None
    return thap, cao


# --- Chuẩn hoá ---------------------------------------------------------

def khoi_phuc_goc(js: dict) -> None:
    """Trả mọi nút gốc về tỉ lệ/vị trí ban đầu đã cất trong `extras`.

    Đây là thứ làm script chạy lại không cộng dồn: mỗi lần đều bắt đầu từ tệp
    như lúc chưa ai đụng vào.
    """
    scenes = js.get("scenes") or []
    if not scenes:
        return
    for chi_so in scenes[js.get("scene", 0)].get("nodes", []):
        nut = js["nodes"][chi_so]
        ghi = (nut.get("extras") or {}).get(KHOA_EXTRAS)
        if not ghi:
            continue
        for ten in ("scale", "translation", "matrix"):
            nut.pop(ten, None)
            if ghi.get(ten) is not None:
                nut[ten] = list(ghi[ten])


def nho_goc(nut: dict) -> dict:
    """Cất tỉ lệ/vị trí ban đầu của nút gốc, nếu chưa cất lần nào."""
    extras = nut.setdefault("extras", {})
    if KHOA_EXTRAS not in extras:
        extras[KHOA_EXTRAS] = {
            "scale": list(nut["scale"]) if "scale" in nut else None,
            "translation": list(nut["translation"]) if "translation" in nut else None,
            "matrix": list(nut["matrix"]) if "matrix" in nut else None,
        }
    return extras[KHOA_EXTRAS]


def ap_ti_le(js: dict, he_so: float) -> None:
    """Nhân toàn cảnh với `he_so`, bằng cách sửa mọi nút gốc."""
    scenes = js.get("scenes") or []
    for chi_so in scenes[js.get("scene", 0)].get("nodes", []):
        nut = js["nodes"][chi_so]
        nho_goc(nut)

        if "matrix" in nut:
            # Nhân trái bằng ma trận co giãn: world = S · M · local.
            s = [he_so, 0, 0, 0, 0, he_so, 0, 0, 0, 0, he_so, 0, 0, 0, 0, 1.0]
            nut["matrix"] = nhan(s, nut["matrix"])
            continue

        cu = nut.get("scale", [1.0, 1.0, 1.0])
        nut["scale"] = [v * he_so for v in cu]
        if "translation" in nut:
            nut["translation"] = [v * he_so for v in nut["translation"]]


def doc_kich_thuoc_that() -> dict[str, float]:
    """Đọc `real_scale_meters` từ seed. Ô trống = chưa tra được nguồn, bỏ qua."""
    data = json.loads(SEED.read_text(encoding="utf-8"))
    ra: dict[str, float] = {}
    for a in data.get("artifacts", []):
        tho = (a.get("real_scale_meters") or "").strip()
        if not tho:
            continue
        try:
            met = float(tho)
        except ValueError:
            print(f"  ! {a['slug']}: real_scale_meters không phải số ({tho!r}) — bỏ qua")
            continue
        if met <= 0:
            print(f"  ! {a['slug']}: real_scale_meters phải > 0 — bỏ qua")
            continue
        ra[a["slug"]] = met
    return ra


def main() -> int:
    doi_so = [t for t in sys.argv[1:] if not t.startswith("-")]
    chi_kiem_tra = "--kiem-tra" in sys.argv[1:]

    if not SEED.exists():
        print(f"Không thấy {SEED}")
        return 1

    kich_thuoc = doc_kich_thuoc_that()
    if not kich_thuoc:
        print("Chưa cổ vật nào có real_scale_meters — không có gì để chuẩn hoá.")
        return 0

    chon = set(doi_so) if doi_so else None
    so_sua = 0
    so_bo_qua = 0

    for slug, muc_tieu in sorted(kich_thuoc.items()):
        if chon is not None and slug not in chon:
            continue
        tep = THU_MUC_MODEL / f"{slug}.glb"
        if not tep.exists():
            print(f"  ! {slug}: không thấy {tep.name}")
            so_bo_qua += 1
            continue

        js, binary = doc_glb(tep)

        # Luôn lùi về trạng thái gốc rồi mới đo — nếu không, lần chạy thứ hai
        # sẽ đo trên tệp đã co giãn và nhân tiếp một lần nữa.
        khoi_phuc_goc(js)
        hop = hop_bao(js)
        if hop is None:
            print(f"  ! {slug}: không đọc được hộp bao")
            so_bo_qua += 1
            continue
        thap, cao = hop
        canh = [cao[i] - thap[i] for i in range(3)]
        lon_nhat = max(canh)
        if lon_nhat <= 0:
            print(f"  ! {slug}: hộp bao rỗng")
            so_bo_qua += 1
            continue

        he_so = muc_tieu / lon_nhat
        ap_ti_le(js, he_so)

        # Đo lại để chắc chắn, thay vì tin vào phép nhân.
        thap2, cao2 = hop_bao(js)
        sau = max(cao2[i] - thap2[i] for i in range(3))

        print(
            f"  {slug}: {lon_nhat:.4f} đv → {sau:.4f} m "
            f"(mục tiêu {muc_tieu} m, hệ số ×{he_so:.6g})"
        )
        if abs(sau - muc_tieu) > muc_tieu * 1e-4:
            print(f"    ! lệch quá mức cho phép, KHÔNG ghi tệp")
            so_bo_qua += 1
            continue

        if not chi_kiem_tra:
            ghi_glb(tep, js, binary)
        so_sua += 1

    thieu = [
        s for s in (chon or set())
        if s not in kich_thuoc
    ]
    for s in thieu:
        print(f"  - {s}: chưa có real_scale_meters trong seed, bỏ qua")

    duoi = " (chỉ kiểm tra, không ghi tệp)" if chi_kiem_tra else ""
    print(f"Xong: {so_sua} tệp{duoi}, {so_bo_qua} bỏ qua.")
    return 0 if so_bo_qua == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
