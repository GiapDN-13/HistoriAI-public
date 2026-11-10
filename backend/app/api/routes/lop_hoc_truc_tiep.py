"""Lớp học giai đoạn 2 — chế độ TRỰC TIẾP (kiểu Kahoot). Logic: app/services/phong_truc_tiep.py.

Mở phòng như giai đoạn 1 nhưng gửi `che_do: "truc_tiep"` (POST /lop/phong). Học sinh vào
phòng y như cũ (POST /phong/{ma}/vao — tên + PIN) rồi nối WebSocket để ngồi sảnh chờ.

WEBSOCKET   /ws/phong/{ma}
    Trình duyệt không gắn được header Authorization vào WebSocket, còn để mã đăng nhập
    trên URL (?token=) thì nó nằm lại trong nhật ký nginx/Cloudflare. Nên: nối xong, gói
    ĐẦU TIÊN phải là {"loai": "xac_thuc", "token": "<JWT>"} trong vòng 10 giây.

    Máy gửi lên                                     Máy chủ gửi xuống
    {"loai":"xac_thuc","token"}                     {"loai":"trang_thai", …} — trọn trạng thái,
    {"loai":"tra_loi","cau_so","chon"}      (hs)        cắt riêng cho từng người (xem chup())
    {"loai":"dieu_khien","lenh","tu_cau"}   (gv)    {"loai":"da_nhan","cau_so","chon"} (hs)
         lenh: bat_dau | ket_thuc_cau |             {"loai":"loi","thong_bao"}
               cau_tiep | ket_thuc                  {"loai":"pong"}
    {"loai":"ping"}  — app gửi 25 giây/lần: Cloudflare cắt kết nối im lặng quá 100 giây.

    Đóng với mã 4401 (hết phiên) / 4403 (không thuộc phòng) / 4404 (không có phòng):
    app KHÔNG tự nối lại với ba mã này.

DỰ PHÒNG KHI WEBSOCKET HỎNG (mạng trường chặn, proxy cũ…) — app hỏi lại định kỳ:
    GET  /phong/{ma}/truc-tiep              trạng thái (cùng dạng gói "trang_thai")
    POST /phong/{ma}/truc-tiep/tra-loi      {"cau_so", "chon"}
    POST /lop/phong/{ma}/truc-tiep          {"lenh", "tu_cau"} (giáo viên)
    Ba route này đi cùng đường với WebSocket (cùng khoá phòng, cùng phát tin), nên một em
    đang hỏi định kỳ vẫn chơi chung trận với các em đang nối WebSocket.
"""
from __future__ import annotations

import asyncio
import json
import time

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field

from app.api.deps import get_current_user
from app.models.user import User
from app.services import phong_truc_tiep as tt

router = APIRouter(tags=["lop-hoc-truc-tiep"])

KIEM_LAI_PHIEN_GIAY = 60      # đăng xuất ở máy khác → tối đa 1 phút sau kết nối này mới bị cắt
CHO_XAC_THUC_GIAY = 10
MA_DONG = {401: 4401, 403: 4403, 404: 4404}


def _http(e: tt.LoiTrucTiep) -> HTTPException:
    return HTTPException(e.ma_http, e.thong_bao)


# ---------------------------------------------------------------- dự phòng REST

class TraLoiTT(BaseModel):
    cau_so: int = Field(ge=0)
    chon: str = Field(pattern=r"^[ABCD]$")


class LenhTT(BaseModel):
    lenh: str = Field(pattern=r"^(bat_dau|ket_thuc_cau|cau_tiep|ket_thuc)$")
    tu_cau: int | None = None


async def _anh_cho(ma: str, user_id: int) -> dict:
    vai = await tt.chay(tt.vai_cua, ma, user_id)
    anh = await tt.quan_ly.lay(ma).lam_moi()      # lối đọc cũng kiểm hết giờ (khôi phục sau khởi động lại)
    return anh.cho_gv() if vai == "gv" else anh.cho_hs(user_id)


@router.get("/phong/{ma}/truc-tiep")
async def trang_thai(ma: str, current: User = Depends(get_current_user)):
    try:
        return await _anh_cho(ma, current.id)
    except tt.LoiTrucTiep as e:
        raise _http(e)


@router.post("/phong/{ma}/truc-tiep/tra-loi")
async def tra_loi(ma: str, payload: TraLoiTT, current: User = Depends(get_current_user)):
    try:
        await tt.chay(tt.vai_cua, ma, current.id)
        kq = await tt.nhan_tra_loi(ma, current.id, payload.cau_so, payload.chon)
    except tt.LoiTrucTiep as e:
        raise _http(e)
    return {"loai": "da_nhan", "cau_so": payload.cau_so, "chon": kq["chon"]}


@router.post("/lop/phong/{ma}/truc-tiep")
async def dieu_khien(ma: str, payload: LenhTT, current: User = Depends(get_current_user)):
    try:
        if await tt.chay(tt.vai_cua, ma, current.id) != "gv":
            raise tt.LoiTrucTiep(404, "Không tìm thấy phòng.")
        anh = await tt.thuc_hien_lenh(ma, current.id, payload.lenh, payload.tu_cau)
    except tt.LoiTrucTiep as e:
        raise _http(e)
    return anh.cho_gv()


# ---------------------------------------------------------------- WebSocket

async def _gui(ws: WebSocket, tin: dict) -> None:
    await ws.send_text(json.dumps(tin, ensure_ascii=False))


@router.websocket("/ws/phong/{ma}")
async def ws_phong(ws: WebSocket, ma: str):
    await ws.accept()
    try:
        dau = json.loads(await asyncio.wait_for(ws.receive_text(), timeout=CHO_XAC_THUC_GIAY))
        token = dau.get("token") if isinstance(dau, dict) and dau.get("loai") == "xac_thuc" else None
        user_id, vai, _ = await tt.chay(tt.xac_thuc, ma, token)
    except tt.LoiTrucTiep as e:
        await _gui(ws, {"loai": "loi", "thong_bao": e.thong_bao})
        await ws.close(code=MA_DONG.get(e.ma_http, 4400))
        return
    except (asyncio.TimeoutError, ValueError, WebSocketDisconnect):
        try:
            await ws.close(code=4401)
        except Exception:
            pass
        return

    ph = tt.quan_ly.lay(ma)
    kn = tt.KetNoi(ws=ws, user_id=user_id, vai=vai, token=token)
    ph.ket_noi.add(kn)
    try:
        anh = await ph.lam_moi()                 # nối lại giữa chừng → nhận ngay đúng câu hiện tại
        anh.gv["dang_noi"] = ph.so_dang_noi()
        await ph.gui_mot(kn, anh)
        if vai == "hs":
            ph.hen_bao_gv()                      # sảnh của giáo viên hiện thêm tên em
        while True:
            try:
                tin = json.loads(await ws.receive_text())
                if not isinstance(tin, dict):
                    raise ValueError
            except ValueError:
                await _gui(ws, {"loai": "loi", "thong_bao": "Gói tin không đọc được."})
                continue
            if time.monotonic() - kn.kiem_luc > KIEM_LAI_PHIEN_GIAY:
                try:
                    await tt.chay(tt.xac_thuc, ma, kn.token)
                    kn.kiem_luc = time.monotonic()
                except tt.LoiTrucTiep as e:
                    await _gui(ws, {"loai": "loi", "thong_bao": e.thong_bao})
                    await ws.close(code=MA_DONG.get(e.ma_http, 4400))
                    return
            loai = tin.get("loai")
            try:
                if loai == "ping":
                    await _gui(ws, {"loai": "pong"})
                elif loai == "tra_loi" and vai == "hs":
                    cau_so, chon = tin.get("cau_so"), tin.get("chon")
                    if not isinstance(cau_so, int) or not isinstance(chon, str):
                        raise tt.LoiTrucTiep(422, "Thiếu câu hoặc đáp án.")
                    kq = await tt.nhan_tra_loi(ma, user_id, cau_so, chon)
                    await _gui(ws, {"loai": "da_nhan", "cau_so": cau_so, "chon": kq["chon"]})
                elif loai == "dieu_khien" and vai == "gv":
                    tu_cau = tin.get("tu_cau")
                    await tt.thuc_hien_lenh(ma, user_id, str(tin.get("lenh")),
                                            tu_cau if isinstance(tu_cau, int) else None)
                elif loai == "lam_moi":
                    anh = await ph.lam_moi()
                    anh.gv["dang_noi"] = ph.so_dang_noi()
                    await ph.gui_mot(kn, anh)
                else:
                    raise tt.LoiTrucTiep(400, "Lệnh không dành cho em.")
            except tt.LoiTrucTiep as e:
                await _gui(ws, {"loai": "loi", "thong_bao": e.thong_bao})
    except WebSocketDisconnect:
        pass
    except Exception:
        tt.log.exception("websocket phòng %s", ma)
    finally:
        ph.ket_noi.discard(kn)
        if vai == "hs":
            ph.hen_bao_gv()
