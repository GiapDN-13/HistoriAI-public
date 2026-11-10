"""Chạy toàn bộ đường ống, tự chờ, tự chạy tiếp — để máy chủ làm một mình qua đêm.

THỨ TỰ
    B0 → B1 (vòng 1) → B2 → [B3 → B4 → B5 → B6 → B7 nạp] cho vòng 1
       → B1 (vòng 2, cần mô hình) → B2 → [B3 → … → B7 nạp] cho vòng 2
    Vòng 1 đi hết tới app TRƯỚC, để mô-đun đang demo được làm dày sớm nhất,
    không phải đợi vòng 2 vốn cần 2–3 đêm vì trần lượt gọi.

KHI GẶP TRỞ NGẠI
    Chưa có khoá    → ghi nhật ký một lần, 10 phút thử lại một lần.
    Hết lượt ngày   → ngủ tới 00:05 hôm sau rồi chạy tiếp từ chỗ dừng.
    Lỗi bất ngờ     → ghi nhật ký kèm vết lỗi, 15 phút sau thử lại; 5 lần liền
                      thì dừng hẳn để không lặp vô tận.
    Mọi bước đều bỏ qua phần đã làm, nên "chạy lại" luôn an toàn.

Khi xong hẳn: ghi ket_qua/XONG.
"""
from __future__ import annotations

import secrets
import shutil
import sys
import time
import traceback
from datetime import datetime, timedelta
from pathlib import Path

import b0_khung_chuong_trinh as b0
import b1_danh_sach_thuc_the as b1
import b2_thu_thap as b2
import b3_trich_menh_de as b3
import b4_kiem_chung_cheo as b4
import b5_sinh_noi_dung as b5
import b6_cong_chat_luong as b6
import b7_xuat_seed as b7
from chung import KET_QUA, ChuaCoKhoa, HetNganSach, doc_cau_hinh, doc_json, ghi_log

TREN_VPS = Path("/home/giapdn/historiai/web").exists()


def dang_bao_cao() -> None:
    """Đưa trang duyệt lên một đường dẫn khó đoán, không có trong sơ đồ trang."""
    if not TREN_VPS:
        return
    tep_ma = KET_QUA / "duong_dan_bao_cao.txt"
    if not tep_ma.exists():
        tep_ma.write_text(f"noi-bo/duyet-{secrets.token_urlsafe(9)}", encoding="utf-8")
    duong = tep_ma.read_text(encoding="utf-8").strip()
    dich = Path("/home/giapdn/historiai/web") / duong
    dich.mkdir(parents=True, exist_ok=True)
    shutil.copy(KET_QUA / "hang_cho" / "bao_cao.html", dich / "index.html")
    ghi_log(f"Trang duyệt: https://historiai.anhzap.shop/{duong}/")


def b1_chi_vong_1() -> None:
    goc = b1.doc_cau_hinh

    def ch():
        c = goc()
        c["vong_2"]["bat"] = False
        return c
    b1.doc_cau_hinh = ch
    try:
        b1.main()
    finally:
        b1.doc_cau_hinh = goc


def mot_vong(vong: int) -> None:
    b3.main(vong)
    b4.main(vong)
    b5.main(vong)
    b6.main(vong)
    # Chỉ nạp vào app khi người duyệt đã đồng ý (cau_hinh.yaml: nap_vao_app).
    # Không có cờ này thì deploy backend mới là nội dung tự lên app trước khi duyệt.
    nap = TREN_VPS and bool(doc_cau_hinh().get("nap_vao_app", False))
    b7.main(nap_vao_app=nap)
    dang_bao_cao()
    ghi_log(f"=== VÒNG {vong} ĐÃ XONG — " + ("đã nạp vào app" if nap else "CHƯA nạp, chờ duyệt") + " ===")


def chay() -> None:
    ch = doc_cau_hinh()
    trang_thai = doc_json(KET_QUA / "trang_thai.json", {})
    b0.main()                     # rẻ, chạy lại mỗi lần để nhận đối chiếu OCR khi OCR xong
    b1_chi_vong_1()
    b2.main()
    if not trang_thai.get("vong_1"):
        mot_vong(1)
        trang_thai["vong_1"] = datetime.now().isoformat(timespec="seconds")
        from chung import ghi_json
        ghi_json(KET_QUA / "trang_thai.json", trang_thai)
    if ch["vong_2"]["bat"] and not trang_thai.get("vong_2"):
        b1.main()                 # đề xuất sự kiện vòng 2 — cần mô hình
        b2.main()
        mot_vong(2)
        trang_thai["vong_2"] = datetime.now().isoformat(timespec="seconds")
        from chung import ghi_json
        ghi_json(KET_QUA / "trang_thai.json", trang_thai)


def main() -> None:
    da_bao_khoa = False
    loi_lien = 0
    while True:
        try:
            chay()
            (KET_QUA / "XONG").write_text(datetime.now().isoformat(timespec="seconds"), encoding="utf-8")
            ghi_log("=== ĐƯỜNG ỐNG ĐÃ CHẠY XONG ===")
            return
        except ChuaCoKhoa:
            loi_lien = 0
            if not da_bao_khoa:
                ghi_log("Chưa có khoá LLM riêng trong data_pipeline/.env — chờ, 10 phút thử lại một lần")
                da_bao_khoa = True
            time.sleep(600)
        except HetNganSach:
            loi_lien = 0
            mai = (datetime.now() + timedelta(days=1)).replace(hour=0, minute=5, second=0)
            ghi_log(f"Hết lượt gọi trong ngày — ngủ tới {mai:%d/%m %H:%M} rồi chạy tiếp")
            time.sleep(max(60, (mai - datetime.now()).total_seconds()))
        except Exception:
            loi_lien += 1
            ghi_log(f"LỖI (lần {loi_lien}):\n" + traceback.format_exc())
            if loi_lien >= 5:
                ghi_log("5 lỗi liên tiếp — dừng hẳn, cần người xem")
                sys.exit(1)
            time.sleep(900)


if __name__ == "__main__":
    main()
