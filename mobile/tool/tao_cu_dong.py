#!/usr/bin/env python3
"""Ghi các đoạn cử động vào tệp .glb nhân vật lịch sử.

VÌ SAO VIẾT TAY THAY VÌ DÙNG BLENDER/MIXAMO
    Model do Tripo dựng đã có sẵn bộ xương người chuẩn (Root → Hip → Waist →
    Spine01/02 → Neck → Head, tay chân đủ cặp) nhưng KHÔNG có đoạn cử động nào.
    Nạp mocap từ Mixamo thì phải cài Blender và đăng nhập tài khoản Adobe —
    hai thứ nhóm không có. Mà thứ cần ở đây chỉ là cử động nhỏ: thở, gật đầu,
    đưa tay khi giảng giải. Loại đó soạn bằng hàm sin lại mượt hơn mocap ghép
    vụng, và quan trọng hơn: nằm trong repo nên sửa được, chạy lại được.

    Cử động LỚN (đi, múa võ) thì cách này sẽ lộ ra cứng. Đừng dùng cho việc đó.

RIG NÀY THIẾU GÌ
    Không có xương ngón tay (bàn tay là một khối) → không chỉ trỏ bằng ngón.
    Không có xương hàm, không có morph target → KHÔNG nhép miệng được.

HỆ TRỤC VÀ DẤU (đo từ chính tệp, không đoán)
    +Y  lên trên
    +Z  sang phải nhân vật   (vai trái ở -Z, vai phải ở +Z)
    +X  hướng nhân vật nhìn  (mặt trước ứng với góc 90° của model-viewer)

    Quay quanh VAI  dấu DƯƠNG = cúi RA TRƯỚC (Spine01 +25° đưa đầu tới 9,2 cm)
    Quay quanh DOC  dấu DƯƠNG = quay đầu sang PHẢI nhân vật
    Quay quanh NHIN dấu DƯƠNG = nghiêng sang PHẢI

    Lần đầu tôi đoán ngược dấu VAI, thành ra nhân vật ngả ra sau khi lẽ ra
    phải cúi chào — mà nhìn ảnh tĩnh thì gần như không phân biệt được. Muốn
    đổi dấu thì đo lại, đừng đoán.

VÌ SAO KHÔNG CÓ CỬ ĐỘNG TAY
    Trần Hưng Đạo khoác áo choàng phủ kín hai cánh tay. Đã thử: cho bàn tay
    trái đi 22 cm mà ảnh dựng ra không thấy khác gì, lại thêm nguy cơ cánh tay
    xuyên qua tấm áo. Toàn bộ biểu cảm dồn vào THÂN và ĐẦU — phần nhô lên trên
    tấm áo, tức phần người xem thật sự nhìn thấy.

CÁCH LÀM
    Mỗi kênh cử động là một hàm theo thời gian chuẩn hoá t ∈ [0,1], trả về số
    ĐỘ quay quanh một trục trong không gian thế giới. Script tự đổi sang hệ
    toạ độ cục bộ của từng xương — đây là phần dễ sai nhất nếu làm tay, vì
    glTF lưu phép quay theo hệ của xương cha chứ không theo hệ thế giới.

    Đoạn lặp bắt buộc có f(0) == f(1), nếu không mỗi vòng sẽ giật một cái.

DÙNG
    python tool/tao_cu_dong.py <vào.glb> <ra.glb>
"""
import json
import math
import pathlib
import struct
import sys

import numpy as np

for _luong in (sys.stdout, sys.stderr):
    try:
        _luong.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

# ---------------------------------------------------------------- trục thế giới
TRUC = {
    "VAI": np.array([0.0, 0.0, 1.0]),   # trục vai — quay quanh nó là CÚI/NGỬA
    "DOC": np.array([0.0, 1.0, 0.0]),   # trục dọc — quay quanh nó là QUAY TRÁI/PHẢI
    "NHIN": np.array([1.0, 0.0, 0.0]),  # trục nhìn — quay quanh nó là NGHIÊNG
}

TAU = 2 * math.pi


def _nhip(t, chu_ky=1.0, lech=0.0):
    """Sóng sin tuần hoàn, đảm bảo khép kín khi chu_ky là số nguyên."""
    return math.sin(TAU * chu_ky * t + lech)


def _mot_lan(t, dinh=0.35):
    """Đường cong lên rồi về 0, dùng cho đoạn chạy một lần (chào, gật).

    Lên nhanh, giữ, xuống chậm — giống nhịp người thật hơn hình sin cân xứng.
    """
    if t <= dinh:
        x = t / dinh
        return 0.5 - 0.5 * math.cos(math.pi * x)
    x = (t - dinh) / (1.0 - dinh)
    return 0.5 + 0.5 * math.cos(math.pi * x)


# ---------------------------------------------------------------- các đoạn
# (tên xương, trục, hàm độ theo t)
CU_DONG = {
    # Đứng thở — đoạn mặc định, lặp vô hạn. Biên độ cố tình nhỏ: chỉ cần người
    # xem KHÔNG thấy đây là bức tượng, chứ không cần thấy nhân vật ngọ nguậy.
    # Quá tay là thành đang tập thể dục.
    "dung_tho": dict(thoi_luong=5.0, lap=True, kenh=[
        ("Spine01",     "VAI",  lambda t:  1.8 * _nhip(t)),
        ("Spine02",     "VAI",  lambda t:  1.2 * _nhip(t)),
        ("NeckTwist01", "VAI",  lambda t: -1.4 * _nhip(t)),     # bù lại, đầu đứng yên
        ("Head",        "DOC",  lambda t:  3.0 * _nhip(t, 0.5)),
        ("Head",        "NHIN", lambda t:  1.2 * _nhip(t, 1, math.pi / 3)),
        ("Hip",         "NHIN", lambda t:  1.0 * _nhip(t, 0.5)),  # chuyển trọng tâm
        ("L_Upperarm",  "NHIN", lambda t: -1.6 * _nhip(t, 1, math.pi / 4)),
        ("R_Upperarm",  "NHIN", lambda t:  1.6 * _nhip(t, 1, math.pi / 4)),
    ]),

    # Đang giảng giải — lặp trong lúc nhân vật trả lời. Chuyển động của người
    # đang nói: hơi xoay người, đầu đảo nhẹ, thỉnh thoảng nhấn bằng một cái gật.
    "giang_giai": dict(thoi_luong=3.2, lap=True, kenh=[
        ("Spine02",     "DOC",  lambda t:  6.0 * _nhip(t)),
        ("Spine01",     "DOC",  lambda t:  2.0 * _nhip(t)),
        ("NeckTwist01", "DOC",  lambda t: -3.0 * _nhip(t)),
        ("Head",        "DOC",  lambda t:  9.0 * _nhip(t, 1, math.pi / 5)),
        ("Spine01",     "VAI",  lambda t:  2.6 * _nhip(t, 2)),
        ("Head",        "VAI",  lambda t:  4.2 * _nhip(t, 2, math.pi / 6)),
        ("Head",        "NHIN", lambda t:  1.8 * _nhip(t, 1)),
    ]),

    # Chào mở đầu — cúi người, chạy một lần. Nhắm tới đầu đi tới khoảng 16 cm
    # trên model cao 1,0 đơn vị, tương đương một cái cúi chào thật sự chứ
    # không phải cái gật.
    "chao": dict(thoi_luong=2.6, lap=False, kenh=[
        ("Spine01",     "VAI",  lambda t: 30.0 * _mot_lan(t)),
        ("Spine02",     "VAI",  lambda t: 18.0 * _mot_lan(t)),
        ("NeckTwist01", "VAI",  lambda t: 14.0 * _mot_lan(t)),
        ("Head",        "VAI",  lambda t:  8.0 * _mot_lan(t)),
    ]),

    # Nghiêm nghị — dùng khi nói về mất mát, hy sinh. Cúi đầu chậm rồi ngẩng.
    "nghiem_nghi": dict(thoi_luong=4.2, lap=False, kenh=[
        ("NeckTwist01", "VAI",  lambda t: 15.0 * _mot_lan(t, 0.45)),
        ("Head",        "VAI",  lambda t:  9.0 * _mot_lan(t, 0.45)),
        ("Spine02",     "VAI",  lambda t:  5.0 * _mot_lan(t, 0.45)),
        ("Spine01",     "DOC",  lambda t: -2.4 * _mot_lan(t, 0.45)),
    ]),

    # Gật đầu — dùng khi người học trả lời đúng. Ngắn, dứt khoát, tắt dần.
    "gat_dau": dict(thoi_luong=1.3, lap=False, kenh=[
        ("NeckTwist01", "VAI",  lambda t: 12.0 * math.sin(TAU * t) * (1 - t)),
        ("Head",        "VAI",  lambda t:  7.0 * math.sin(TAU * t) * (1 - t)),
    ]),
}

FPS = 24


# ---------------------------------------------------------------- glTF
def _doc_glb(duong):
    d = pathlib.Path(duong).read_bytes()
    if d[:4] != b"glTF":
        raise SystemExit(f"  LỖI: {duong} không phải tệp .glb")
    js = binc = None
    off = 12
    while off < len(d):
        ln, ty = struct.unpack_from("<II", d, off)
        than = d[off + 8: off + 8 + ln]
        if ty == 0x4E4F534A:
            js = json.loads(than.decode("utf-8"))
        elif ty == 0x004E4942:
            binc = bytearray(than)
        off += 8 + ln
    if js is None or binc is None:
        raise SystemExit("  LỖI: tệp .glb thiếu khối JSON hoặc BIN")
    return js, binc


def _ghi_glb(duong, js, binc):
    jsb = json.dumps(js, separators=(",", ":")).encode("utf-8")
    jsb += b" " * ((4 - len(jsb) % 4) % 4)
    binb = bytes(binc) + b"\x00" * ((4 - len(binc) % 4) % 4)
    tong = 12 + 8 + len(jsb) + 8 + len(binb)
    with open(duong, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, tong))
        f.write(struct.pack("<II", len(jsb), 0x4E4F534A) + jsb)
        f.write(struct.pack("<II", len(binb), 0x004E4942) + binb)


def _ma_tran(n):
    t = np.array(n.get("translation", [0, 0, 0]), float)
    q = np.array(n.get("rotation", [0, 0, 0, 1]), float)
    s = np.array(n.get("scale", [1, 1, 1]), float)
    m = np.eye(4)
    m[:3, :3] = _q_sang_r(q) * s
    m[:3, 3] = t
    return m


def _q_sang_r(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


def _q_tu_truc(truc, goc_rad):
    v = truc / np.linalg.norm(truc)
    s = math.sin(goc_rad / 2)
    return np.array([v[0] * s, v[1] * s, v[2] * s, math.cos(goc_rad / 2)])


def _q_nhan(a, b):
    """a ⊗ b — áp b trước, rồi a."""
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    ])


def _them_accessor(js, binc, du_lieu, kieu, so_thanh_phan):
    """Nối mảng float vào cuối buffer rồi khai báo accessor, trả về chỉ số."""
    while len(binc) % 4:
        binc.append(0)
    offset = len(binc)
    mang = np.asarray(du_lieu, dtype=np.float32).reshape(-1)
    binc.extend(mang.tobytes())

    js.setdefault("bufferViews", []).append({
        "buffer": 0, "byteOffset": offset, "byteLength": len(mang) * 4,
    })
    bv = len(js["bufferViews"]) - 1

    a = {
        "bufferView": bv, "componentType": 5126,  # FLOAT
        "count": len(mang) // so_thanh_phan, "type": kieu,
    }
    if kieu == "SCALAR":  # glTF bắt buộc min/max cho accessor thời gian
        a["min"] = [float(mang.min())]
        a["max"] = [float(mang.max())]
    js.setdefault("accessors", []).append(a)
    return len(js["accessors"]) - 1


def tao(vao, ra):
    js, binc = _doc_glb(vao)
    nodes = js["nodes"]
    ten = [n.get("name", "") for n in nodes]
    chi_so = {t: i for i, t in enumerate(ten)}

    cha = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            cha[c] = i

    def r_the_gioi(i):
        """Phần quay của ma trận thế giới, tính từ tư thế nghỉ."""
        m = _ma_tran(nodes[i])
        while i in cha:
            i = cha[i]
            m = _ma_tran(nodes[i]) @ m
        r = m[:3, :3]
        # bỏ tỉ lệ để còn lại đúng phép quay
        for c in range(3):
            n_ = np.linalg.norm(r[:, c])
            if n_ > 1e-9:
                r[:, c] /= n_
        return r

    js.setdefault("animations", [])
    thieu = set()

    for ten_doan, spec in CU_DONG.items():
        dai = spec["thoi_luong"]
        so_khung = max(2, int(round(dai * FPS)) + 1)
        thoi_gian = [i * dai / (so_khung - 1) for i in range(so_khung)]

        # gộp nhiều kênh cùng trỏ vào một xương thành một chuỗi quay
        theo_xuong = {}
        for ten_xuong, ten_truc, ham in spec["kenh"]:
            if ten_xuong not in chi_so:
                thieu.add(ten_xuong)
                continue
            theo_xuong.setdefault(chi_so[ten_xuong], []).append((ten_truc, ham))

        kenh_ra, sampler_ra = [], []
        for nut, ds in theo_xuong.items():
            q_nghi = np.array(nodes[nut].get("rotation", [0, 0, 0, 1]), float)
            r_cha = r_the_gioi(cha[nut]) if nut in cha else np.eye(3)
            r_cha_nghich = r_cha.T  # ma trận quay: nghịch đảo = chuyển vị

            khung = []
            for k in range(so_khung):
                t = k / (so_khung - 1)
                q = q_nghi.copy()
                for ten_truc, ham in ds:
                    goc = math.radians(ham(t))
                    if abs(goc) < 1e-7:
                        continue
                    # Đổi trục thế giới sang hệ của xương CHA. Bỏ bước này là
                    # nhân vật cúi ngang hoặc xoắn người — sai kiểu rất khó đoán.
                    truc_cha = r_cha_nghich @ TRUC[ten_truc]
                    q = _q_nhan(_q_tu_truc(truc_cha, goc), q)
                q /= np.linalg.norm(q)
                khung.append(q)

            i_vao = _them_accessor(js, binc, thoi_gian, "SCALAR", 1)
            i_ra = _them_accessor(js, binc, np.array(khung), "VEC4", 4)
            sampler_ra.append({"input": i_vao, "output": i_ra,
                               "interpolation": "LINEAR"})
            kenh_ra.append({"sampler": len(sampler_ra) - 1,
                            "target": {"node": nut, "path": "rotation"}})

        js["animations"].append({
            "name": ten_doan, "samplers": sampler_ra, "channels": kenh_ra,
        })
        print(f"  {ten_doan:12s} {dai:4.1f}s  {so_khung:3d} khung  "
              f"{len(kenh_ra)} xương  {'lặp' if spec['lap'] else 'một lần'}")

    if thieu:
        print(f"  CẢNH BÁO: rig không có xương {sorted(thieu)} — đã bỏ qua.")

    js["buffers"][0]["byteLength"] = len(binc) + ((4 - len(binc) % 4) % 4)
    _ghi_glb(ra, js, binc)
    cu = pathlib.Path(vao).stat().st_size
    moi = pathlib.Path(ra).stat().st_size
    print(f"  → {ra}  ({cu/1024:.0f} KB → {moi/1024:.0f} KB)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    tao(sys.argv[1], sys.argv[2])
