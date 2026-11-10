"""Kiểm tải chế độ TRỰC TIẾP: N học sinh (mặc định 40 — một lớp đông) nối WebSocket vào một
phòng, trả lời ngẫu nhiên; đo độ trễ PHÁT CÂU → MÁY EM NHẬN CÂU.

KHÔNG chạy trong CI (tên tệp không bắt đầu bằng test_, nằm ngoài tests/). Chạy tay:

    # cửa sổ 1 — máy chủ local, CSDL riêng để không bẩn dữ liệu thật
    cd backend
    rm -f kiem_tai.db
    DATABASE_URL=sqlite:///./kiem_tai.db SECRET_KEY=kiem-tai MA_GIAO_VIEN=ma-kiem-tai LLM_API_KEY= \
        python -m app.db.seed
    DATABASE_URL=sqlite:///./kiem_tai.db SECRET_KEY=kiem-tai MA_GIAO_VIEN=ma-kiem-tai LLM_API_KEY= \
        uvicorn app.main:app --port 8000

    # cửa sổ 2
    python tools/kiem_tai_truc_tiep.py --goc http://127.0.0.1:8000 --so-hs 40 --ma-gv ma-kiem-tai

ĐO GÌ
    phát → nhận   từ lúc máy giáo viên GỬI lệnh (bat_dau / cau_tiep) tới lúc từng máy em nhận
                  gói "trang_thai" của câu mới. Cùng một máy nên cùng đồng hồ — không lệch.
    trả lời → đã nhận   từ lúc em gửi đáp án tới lúc nhận gói "da_nhan" (gồm ghi CSDL).
    lộ đáp án     từ lúc em CUỐI CÙNG trả lời tới lúc cả lớp nhận đáp án (máy chủ tự lộ khi
                  cả lớp đã trả lời).
Chạy local nên KHÔNG tính đường mạng thật (Cloudflare + wifi trường cộng thêm ~50–300 ms);
con số này đo phần máy chủ + CSDL có theo kịp 40 em cùng bấm hay không.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import random
import statistics
import time
import uuid

import httpx
import websockets


def pct(xs: list[float], p: float) -> float:
    if not xs:
        return float("nan")
    k = sorted(xs)
    return k[min(len(k) - 1, int(round(p / 100 * (len(k) - 1))))]


def tom_tat(ten: str, xs: list[float]) -> str:
    if not xs:
        return f"{ten:<22} (không có mẫu)"
    return (f"{ten:<22} n={len(xs):>4}  p50={pct(xs, 50):7.1f} ms  p95={pct(xs, 95):7.1f} ms  "
            f"max={max(xs):7.1f} ms  tb={statistics.mean(xs):7.1f} ms")


class HocSinh:
    def __init__(self, ten: str, tok: str):
        self.ten, self.tok = ten, tok
        self.ws = None
        self.nhan_cau: dict[int, float] = {}      # cau_so → thời điểm nhận câu (time.time)
        self.nhan_lo: dict[int, float] = {}
        self.tu_chup: list[float] = []            # máy chủ chụp trạng thái → máy em nhận
        self.tre_tra_loi: list[float] = []
        self.gui_luc: dict[int, float] = {}       # cau_so → lúc gửi đáp án
        self.loi: list[str] = []


async def vong_hs(hs: HocSinh, url: str, tre_toi_da: float, xong: asyncio.Event):
    async with websockets.connect(url, max_size=2**20, open_timeout=20) as ws:
        hs.ws = ws
        await ws.send(json.dumps({"loai": "xac_thuc", "token": hs.tok}))
        gui_luc = hs.gui_luc
        async for raw in ws:
            t = json.loads(raw)
            bay_gio = time.time()
            if t.get("loai") == "trang_thai":
                cs, pha = t.get("cau_so"), t.get("pha")
                if pha == "dang_hoi" and cs not in hs.nhan_cau:
                    hs.nhan_cau[cs] = bay_gio
                    hs.tu_chup.append(bay_gio * 1000 - t["t_phat"])
                    if "dap_an" in t:
                        hs.loi.append("LỘ ĐÁP ÁN trước khi kết thúc câu!")

                    async def tra_loi(cs=cs):
                        await asyncio.sleep(random.uniform(0.2, tre_toi_da))
                        gui_luc[cs] = time.time()
                        await ws.send(json.dumps({"loai": "tra_loi", "cau_so": cs, "chon": random.choice("ABCD")}))
                    asyncio.create_task(tra_loi())
                elif pha == "lo_dap_an" and cs not in hs.nhan_lo:
                    hs.nhan_lo[cs] = bay_gio
                elif pha == "ket_thuc":
                    xong.set()
                    return
            elif t.get("loai") == "da_nhan":
                cs = t["cau_so"]
                if cs in gui_luc:
                    hs.tre_tra_loi.append((bay_gio - gui_luc[cs]) * 1000)
            elif t.get("loai") == "loi":
                hs.loi.append(t.get("thong_bao", ""))


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--goc", default="http://127.0.0.1:8000")
    ap.add_argument("--so-hs", type=int, default=40)
    ap.add_argument("--so-cau", type=int, default=5)
    ap.add_argument("--ma-gv", required=True, help="MA_GIAO_VIEN đang đặt trên máy chủ")
    ap.add_argument("--tre-toi-da", type=float, default=4.0, help="em suy nghĩ tối đa bao nhiêu giây")
    a = ap.parse_args()
    api = a.goc.rstrip("/") + "/api/v1"
    ws_goc = api.replace("http://", "ws://").replace("https://", "wss://")

    async with httpx.AsyncClient(timeout=60) as kh:
        email = f"kiemtai-{uuid.uuid4().hex[:8]}@test.com"
        await kh.post(f"{api}/auth/register", json={"email": email, "full_name": "GV kiểm tải", "password": "12345678"},
                      headers={"X-Client-Id": uuid.uuid4().hex})
        gv_tok = (await kh.post(f"{api}/auth/login", data={"username": email, "password": "12345678"})).json()["access_token"]
        h = {"Authorization": f"Bearer {gv_tok}"}
        r = await kh.post(f"{api}/auth/lam-giao-vien", json={"ma": a.ma_gv}, headers=h)
        r.raise_for_status()
        kho = (await kh.get(f"{api}/lop/kho-cau", headers=h)).json()
        ids = [q["id"] for sk in kho for q in sk["cau"]][: a.so_cau]
        de = (await kh.post(f"{api}/lop/de", json={"tieu_de": "Kiểm tải", "cau_ids": ids, "giay_moi_cau": 20},
                            headers=h)).json()
        ma = (await kh.post(f"{api}/lop/phong", json={"de_id": de["id"], "che_do": "truc_tiep"}, headers=h)).json()["ma"]
        print(f"Phòng {ma} · {len(ids)} câu · {a.so_hs} học sinh")

        t0 = time.perf_counter()

        async def vao(i):
            r = await kh.post(f"{api}/phong/{ma}/vao", json={"ho_ten": f"Học sinh {i:02d}", "pin": "1234"},
                              headers={"X-Client-Id": uuid.uuid4().hex})
            r.raise_for_status()
            return HocSinh(f"Học sinh {i:02d}", r.json()["access_token"])
        ds = await asyncio.gather(*(vao(i) for i in range(a.so_hs)))
        print(f"{a.so_hs} em vào phòng (REST, có băm PIN) trong {time.perf_counter() - t0:.1f} s")

    url = f"{ws_goc}/ws/phong/{ma}"
    xong = asyncio.Event()
    t0 = time.perf_counter()
    viec = [asyncio.create_task(vong_hs(hs, url, a.tre_toi_da, xong)) for hs in ds]

    phat_luc: dict[int, float] = {}
    async with websockets.connect(url) as gv:
        await gv.send(json.dumps({"loai": "xac_thuc", "token": gv_tok}))
        # chờ cả lớp nối vào sảnh
        while True:
            t = json.loads(await asyncio.wait_for(gv.recv(), 60))
            if t.get("loai") == "trang_thai" and len(t.get("dang_noi", [])) >= a.so_hs:
                break
        print(f"{a.so_hs} WebSocket nối + xác thực xong trong {time.perf_counter() - t0:.1f} s")

        for cs in range(len(ids)):
            phat_luc[cs] = time.time()
            lenh = "bat_dau" if cs == 0 else "cau_tiep"
            await gv.send(json.dumps({"loai": "dieu_khien", "lenh": lenh, "tu_cau": None if cs == 0 else cs - 1}))
            while True:                                  # đợi máy chủ tự lộ đáp án (cả lớp đã trả lời)
                t = json.loads(await asyncio.wait_for(gv.recv(), 60))
                if t.get("loai") == "trang_thai" and t.get("pha") == "lo_dap_an" and t.get("cau_so") == cs:
                    break
            await asyncio.sleep(0.5)                     # đợi gói lộ đáp án tới hết máy em
        await gv.send(json.dumps({"loai": "dieu_khien", "lenh": "cau_tiep", "tu_cau": len(ids) - 1}))
        await asyncio.wait_for(xong.wait(), 30)
        while True:
            t = json.loads(await asyncio.wait_for(gv.recv(), 30))
            if t.get("pha") == "ket_thuc":
                bxh = t["bang_xep_hang"]
                break
    await asyncio.gather(*viec, return_exceptions=True)

    phat_nhan = [(hs.nhan_cau[cs] - phat_luc[cs]) * 1000 for hs in ds for cs in phat_luc if cs in hs.nhan_cau]
    tra_loi = [x for hs in ds for x in hs.tre_tra_loi]
    lo = []
    for cs in phat_luc:
        cuoi = max((hs.gui_luc.get(cs, 0) for hs in ds), default=0)    # em cuối cùng bấm
        lo += [(hs.nhan_lo[cs] - cuoi) * 1000 for hs in ds if cs in hs.nhan_lo]
    thieu = sum(1 for hs in ds for cs in phat_luc if cs not in hs.nhan_cau)
    loi = [f"{hs.ten}: {e}" for hs in ds for e in hs.loi]

    print()
    print(tom_tat("phát → nhận câu", phat_nhan))
    print(tom_tat("  (máy chủ chụp → nhận)", [x for hs in ds for x in hs.tu_chup]))
    for cs in phat_luc:
        xs = [(hs.nhan_cau[cs] - phat_luc[cs]) * 1000 for hs in ds if cs in hs.nhan_cau]
        print("   " + tom_tat(f"câu {cs + 1}", xs))
    print(tom_tat("trả lời → đã nhận", tra_loi))
    print(tom_tat("em cuối bấm → lộ đáp án", lo))
    print(f"Máy không nhận được câu: {thieu} · lỗi: {len(loi)}")
    for e in loi[:10]:
        print("   ", e)
    print(f"Bảng xếp hạng chung cuộc: {len(bxh)} em · nhất {bxh[0]['ten']} {bxh[0]['diem']} điểm")


if __name__ == "__main__":
    asyncio.run(main())
