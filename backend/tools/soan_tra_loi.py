"""Tạo câu trả lời soạn sẵn cho câu gợi ý — xem app/services/soan_san.py.

Đi đúng đường chat thật: cùng lời nhắc nhập vai, cùng sử liệu có nguồn, cùng luật
chống bịa. Mỗi câu tốn MỘT lượt AI, một lần duy nhất.

    python -m tools.soan_tra_loi            # chỉ tạo câu còn trống
    python -m tools.soan_tra_loi --lam-lai  # tạo lại tất cả

Chạy trên VPS (có khoá LLM trong .env). Tạo xong, người trong nhóm đọc lại
data/tra_loi_soan_san.json; câu nào chưa ổn thì sửa tay trường "dap" là được.
Sửa câu gợi ý trong app (chat_screen.dart) thì phải sửa "hoi" ở đây cho khớp.
"""
from __future__ import annotations

import datetime
import json
import sys
import time

from app.db.session import SessionLocal
from app.models.figure import HistoricalFigure
from app.services import soan_san, su_lieu
from app.services.ai_chat import generate_reply


def main() -> int:
    lam_lai = "--lam-lai" in sys.argv
    kho = json.loads(soan_san.TEP.read_text(encoding="utf-8"))
    db = SessionLocal()
    so_tao = 0
    try:
        for slug, ds in kho.items():
            if slug.startswith("_"):
                continue
            nv = db.query(HistoricalFigure).filter(HistoricalFigure.slug == slug).first()
            if not nv:
                print(f"  bỏ qua {slug}: không có vĩ nhân này")
                continue
            for m in ds:
                if m.get("dap") and not lam_lai:
                    continue
                chon = su_lieu.chon(slug, m["hoi"], None)
                # Groq miễn phí giới hạn token MỖI PHÚT: gọi liền tay câu thứ hai là 429.
                for lan in range(5):
                    kq = generate_reply(nv, m["hoi"], context=su_lieu.dinh_dang(chon) or None)
                    if not any("LLM lỗi" in n for n in kq.get("sources", [])):
                        break
                    print(f"  … {slug}: AI bận, chờ 25 s (lần {lan + 1})")
                    time.sleep(25)
                if any("LLM lỗi" in n for n in kq.get("sources", [])):
                    print(f"  ✗ {slug}: {m['hoi']} — AI lỗi, giữ nguyên")
                    continue
                m["dap"] = kq["reply"]
                m["nguon"] = su_lieu.nguon_da_dung(chon)
                m["tao_luc"] = datetime.date.today().isoformat()
                so_tao += 1
                print(f"  ✓ {slug}: {m['hoi']}  ({len(m['dap'])} ký tự)")
    finally:
        db.close()
    soan_san.TEP.write_text(json.dumps(kho, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"  đã tạo {so_tao} câu → {soan_san.TEP}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
