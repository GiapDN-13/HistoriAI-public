"""Tạo (hoặc cập nhật) tài khoản QUẢN TRỊ của nhóm — chạy trên máy chủ.

Quản trị = mọi quyền giáo viên + mở khoá mọi vĩ nhân, không lên bảng vàng.
Đăng nhập bằng tên ngắn (không cần "@historiai.org").

    TEN=admhistorijor MAT_KHAU='...' python -m tools.tao_quan_tri

Mật khẩu đọc từ biến môi trường, KHÔNG ghi vào mã hay tài liệu.
Đổi mật khẩu: chạy lại lệnh với mật khẩu mới (mọi phiên cũ bị đăng xuất).
"""
from __future__ import annotations

import os
import sys

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models.user import User


def main() -> int:
    ten = os.environ.get("TEN", "").strip()
    mk = os.environ.get("MAT_KHAU", "")
    if not ten or "@" in ten or len(mk) < 6:
        print("  Cần TEN (không có @) và MAT_KHAU (≥ 6 ký tự).")
        return 1
    email = f"{ten}@historiai.org"
    db = SessionLocal()
    try:
        u = db.query(User).filter(User.email == email).first()
        moi = u is None
        if moi:
            u = User(email=email, full_name="Quản trị HistoriAI", nguon="noi-bo")
            db.add(u)
        u.hashed_password = hash_password(mk)
        u.role = "admin"
        u.co_mat_khau = True
        u.token_version = (u.token_version or 0) + (0 if moi else 1)
        db.commit()
        print(f"  {'đã tạo' if moi else 'đã cập nhật'} tài khoản quản trị: {ten} (id {u.id})")
    finally:
        db.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
