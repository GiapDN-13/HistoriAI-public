"""Migrate nhẹ: thêm cột còn thiếu vào bảng đã có (dự án chưa dùng Alembic).

VÌ SAO GỌI LÚC KHỞI ĐỘNG CHỨ KHÔNG CHỈ TRONG SEED
    `Base.metadata.create_all` chỉ tạo bảng MỚI, không thêm cột vào bảng cũ.
    Model có cột mới mà CSDL chưa có thì mọi truy vấn vào bảng đó đều lỗi —
    tức là deploy code mới rồi khởi động lại dịch vụ, trước khi kịp chạy seed,
    là API sập. Gọi ở đây thì thứ tự deploy không còn quan trọng.

Chỉ THÊM cột, cho phép rỗng. Không bao giờ đổi hay xoá cột.
"""
from sqlalchemy import inspect, text

from app.db.session import engine

COT = [
    ("historical_figures", "model_url", "VARCHAR"),
    ("historical_figures", "knowledge_boundary", "VARCHAR"),
    # --- đường ống làm giàu dữ liệu (data_pipeline/) ---
    ("historical_events", "summary_thcs", "TEXT"),
    ("historical_events", "summary_thpt", "TEXT"),
    ("historical_events", "grades", "VARCHAR"),
    ("historical_events", "curriculum", "JSON"),
    ("historical_events", "sources", "JSON"),
    ("quiz_questions", "curriculum_ref", "TEXT"),
    ("quiz_questions", "source_claims", "JSON"),
    ("quiz_questions", "grade_min", "INTEGER"),
    ("historical_figures", "verified_facts", "TEXT"),
    ("historical_figures", "sources", "JSON"),
    ("artifacts", "sources", "JSON"),
    ("users", "grade", "INTEGER"),
    ("users", "nguon", "VARCHAR(40)"),
    ("users", "kenh", "VARCHAR(40)"),
    ("users", "chien_dich", "VARCHAR(40)"),
    ("users", "token_version", "INTEGER NOT NULL DEFAULT 0"),
    ("users", "ngay_hoc_cuoi", "DATE"),
    ("users", "avatar", "VARCHAR(40)"),
    ("users", "vi_tri_anh", "VARCHAR(24)"),   # thống kê nội bộ từ ảnh đại diện (~11 km)
    ("users", "may_anh", "VARCHAR(80)"),
    ("users", "google_sub", "VARCHAR(64)"),
    ("users", "co_mat_khau", "BOOLEAN NOT NULL DEFAULT TRUE"),
    ("quiz_attempts", "lan_nop", "VARCHAR(32)"),
    # --- lớp học giai đoạn 2: chế độ trực tiếp ---
    ("phong_thi", "che_do", "VARCHAR(12) NOT NULL DEFAULT 'bai_tap'"),
    ("phong_thi", "pha", "VARCHAR(12)"),
    ("phong_thi", "cau_hien_tai", "INTEGER"),
    ("phong_thi", "cau_bat_dau_luc", "TIMESTAMP"),   # SQLite lẫn Postgres đều hiểu
    ("phong_thi", "lop_id", "INTEGER"),          # lớp học GĐ3: phòng gắn với lớp cố định
    ("users", "premium_den", "TIMESTAMP WITH TIME ZONE"),   # Premium hết hạn lúc nào (thanh toán SePay)
    ("phan_hoi", "muon_them", "VARCHAR(200)"),   # chip "muốn thêm trận nào" (21/10)
]


def dam_bao_cot() -> None:
    insp = inspect(engine)
    bang = set(insp.get_table_names())
    for ten_bang, cot, kieu in COT:
        if ten_bang not in bang:
            continue
        co = {c["name"] for c in insp.get_columns(ten_bang)}
        if cot not in co:
            with engine.begin() as conn:
                conn.execute(text(f"ALTER TABLE {ten_bang} ADD COLUMN {cot} {kieu}"))
