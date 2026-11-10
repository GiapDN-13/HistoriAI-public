# HistoriAI 🏛️

> Nền tảng EdTech học Lịch sử Việt Nam qua **AI · 3D · AR · Gamification**
> Dự án **HistoJourney** (EXE101_02, FPT University Đà Nẵng)

App di động giúp học sinh "nhìn – nghe – tương tác" với lịch sử thay vì học vẹt, gồm 4 tính năng lõi: **3D Cinematic + Timeline · Chat Vĩ Nhân (AI) · Đấu Trường Sử Việt (Quiz) · AR Museum**.

---

## 📁 Cấu trúc repo (monorepo)

```
HistoriAI/
├── backend/              # API FastAPI (Python)
│   ├── app/
│   │   ├── core/         # config, security (JWT, bcrypt)
│   │   ├── db/           # session + seed dữ liệu
│   │   ├── models/       # bảng SQLAlchemy (user, event, figure, quiz, artifact)
│   │   ├── schemas/      # Pydantic (request/response)
│   │   ├── services/     # logic AI chat (mock → LLM thật)
│   │   ├── api/routes/   # auth, content, quiz, chat
│   │   └── main.py       # khởi động app
│   ├── data/seed_data.json  # nội dung "Hào khí Đại Việt"
│   ├── tests/            # smoke test (pytest)
│   ├── requirements.txt
│   └── Dockerfile
├── mobile/               # App Flutter (Dart)
│   └── lib/
│       ├── core/         # theme, api_client
│       ├── data/         # model dữ liệu
│       └── features/     # dashboard, timeline, chat, quiz, ar_museum
├── docs/3D_ASSET_GUIDE.md   # hướng dẫn bàn giao 3D (Design ⇄ Tech)
├── .github/workflows/    # CI/CD (backend.yml, mobile.yml)
├── docker-compose.yml    # chạy backend + Postgres bằng 1 lệnh
└── CONTRIBUTING.md       # quy trình Git, phân công
```

---

## 🛠️ Yêu cầu cài đặt

| Công cụ | Phiên bản | Dùng cho |
|---|---|---|
| Python | 3.12+ | backend |
| Docker Desktop | mới nhất | DB + chạy nhanh (khuyến nghị) |
| Flutter SDK | 3.22+ | mobile app |
| Git | — | clone & cộng tác |

---

## 🚀 Cách 1 — Chạy backend nhanh nhất (Docker, KHUYẾN NGHỊ)

Chỉ cần Docker, **không cần cài Python/Postgres thủ công**:

```bash
git clone <repo-url>
cd HistoriAI
docker compose up --build
```

→ Lệnh này tự: dựng Postgres, seed dữ liệu "Hào khí Đại Việt", chạy API.
- API: <http://localhost:8000>
- Swagger (thử API ngay trên trình duyệt): <http://localhost:8000/docs>
- Health check: <http://localhost:8000/health>

Dừng: `Ctrl+C` rồi `docker compose down` (thêm `-v` để xoá luôn DB).

---

## 🐍 Cách 2 — Chạy backend thủ công (không Docker)

```bash
cd HistoriAI/backend

# 1. Tạo môi trường ảo
python -m venv .venv
# Windows:  .venv\Scripts\activate
# macOS/Linux:  source .venv/bin/activate

# 2. Cài thư viện
pip install -r requirements.txt

# 3. Cấu hình môi trường
cp .env.example .env        # rồi sửa .env nếu cần

# 4a. Dùng PostgreSQL (cần có Postgres chạy sẵn), HOẶC
# 4b. Dùng SQLite cho nhanh (không cần cài DB):
#     đặt trong .env:  DATABASE_URL=sqlite:///./historiai.db

# 5. Nạp dữ liệu mẫu
python -m app.db.seed

# 6. Chạy server
uvicorn app.main:app --reload
```

### Seed dữ liệu (clone DB nội dung)

```bash
python -m app.db.seed
```
- Idempotent — chạy lại nhiều lần không tạo trùng.
- Sửa nội dung trong `backend/data/seed_data.json` rồi chạy lại để cập nhật.
- Kết quả: 4 sự kiện · 2 nhân vật · 1 hiện vật · 3 câu quiz.

---

## 📱 Cách 3 — Chạy Flutter app

```bash
cd HistoriAI/mobile
flutter pub get
flutter run        # chọn thiết bị/emulator
```

**Quan trọng — trỏ app vào backend:** sửa `baseUrl` hoặc truyền khi chạy:
```bash
# Android emulator (mặc định 10.0.2.2 = localhost của máy host)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# iOS simulator / web
flutter run --dart-define=API_BASE_URL=http://localhost:8000

# Thiết bị thật (thay bằng IP máy chạy backend, cùng WiFi)
flutter run --dart-define=API_BASE_URL=http://192.168.1.x:8000
```

Build APK để demo (cài trực tiếp lên điện thoại Android):
```bash
flutter build apk --release
# file ở: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔌 API chính (prefix `/api/v1`)

| Method | Endpoint | Mô tả |
|---|---|---|
| POST | `/auth/register` | Đăng ký |
| POST | `/auth/login` | Đăng nhập → JWT |
| GET | `/auth/me` | Thông tin user (cần token) |
| GET | `/events` | Danh sách sự kiện (Timeline) |
| GET | `/events/{slug}` | Chi tiết 1 sự kiện |
| GET | `/figures` | Nhân vật (Chat Vĩ Nhân) |
| GET | `/artifacts` | Hiện vật 3D (AR Museum) |
| GET | `/quiz/{event_slug}` | Câu hỏi quiz |
| POST | `/quiz/submit` | Chấm điểm |
| POST | `/chat` | Chat với nhân vật (mock khi chưa có LLM key) |

Thử tất cả tại **Swagger UI: `/docs`**.

---

## 🤖 Tích hợp AI (Chat Vĩ Nhân)

Mặc định chạy **chế độ mock** (không cần API key) để demo offline.
Khi có khoá, điền vào `.env`:
```
LLM_API_KEY=sk-...
ELEVENLABS_API_KEY=...
```
Rồi hoàn thiện `backend/app/services/ai_chat.py` (đã có sẵn TODO + khung RAG/GraphRAG).

---

## ✅ CI/CD (GitHub Actions)

Tự chạy khi push / mở PR:
- **`backend.yml`**: cài deps → `pytest` (SQLite) → build Docker image.
- **`mobile.yml`**: `flutter analyze` → `flutter test` → `flutter build apk`.

Chạy test cục bộ trước khi push:
```bash
cd backend && pytest -q
cd mobile && flutter analyze && flutter test
```

---

## 🎨 Bàn giao Asset 3D

Xem **[docs/3D_ASSET_GUIDE.md](docs/3D_ASSET_GUIDE.md)** — designer xuất `.glb`/`.usdz`/`.mp4` đúng chuẩn, tech móc nối qua URL trong `seed_data.json`.

## 🌿 Git Workflow

Quy trình nhánh (Git Flow gọn) cho cả đội:

| Nhánh | Vai trò |
|---|---|
| `master` | Code ổn định, demo được. **Không push thẳng** — chỉ merge từ `develop` qua PR. |
| `develop` | Nhánh tích hợp chính. Mọi PR tính năng merge vào đây. |
| `feature/<tên>` | Mỗi tính năng/người một nhánh. VD: `feature/quiz-screen` |
| `docs/<tên>` | Cập nhật tài liệu. VD: `docs/git-workflow-readme` |

**Vòng đời một tính năng:**

```bash
# 1. Luôn bắt đầu từ develop mới nhất
git checkout develop && git pull

# 2. Tạo nhánh riêng
git checkout -b feature/ten-tinh-nang

# 3. Code + tự kiểm thử cục bộ (pytest / flutter test phải xanh)

# 4. Commit theo Conventional Commits (tiếng Anh, không icon)
git commit -m "feat(quiz): add campaign map screen"

# 5. Push và mở Pull Request vào develop
git push -u origin feature/ten-tinh-nang
gh pr create --base develop          # hoặc mở PR trên web
```

**Quy ước commit** — `type(scope): mô tả ngắn` (tiếng Anh, không dùng icon):

| type | Dùng khi |
|---|---|
| `feat` | thêm tính năng mới |
| `fix` | sửa lỗi |
| `docs` | thay đổi tài liệu |
| `refactor` | tái cấu trúc, không đổi hành vi |
| `test` | thêm/sửa test |
| `chore` | việc lặt vặt (cấu hình, dependency) |

**Luật review & merge (branch protection):**
- PR vào `master` **bắt buộc** được trưởng nhóm (`@GiapDN-13`, theo [CODEOWNERS](.github/CODEOWNERS)) approve.
- CI (test + build) phải xanh mới merge được.
- Khuyến nghị **Squash and merge** để lịch sử gọn — mỗi PR thành 1 commit.
- Dùng `Closes #<số issue>` trong commit/PR để issue tự đóng khi merge.

---

## 🤝 Cộng tác

Xem **[CONTRIBUTING.md](CONTRIBUTING.md)** — phân công chi tiết theo vai trò từng thành viên.

---

## 🔧 Troubleshooting

| Vấn đề | Nguyên nhân | Cách khắc phục |
|---|---|---|
| `docker compose up` seed thất bại | Postgres chưa sẵn sàng | Healthcheck tự động đợi DB; nếu vẫn lỗi chạy lại `docker compose up` |
| Port 8000/5432 đã dùng | Service khác chiếm cổng | Dừng service đó hoặc đổi port trong `docker-compose.yml` |
| `bcrypt` import error | Thiếu deps hệ thống | Docker dùng image slim nên không gặp; chạy native thì cài `pip install bcrypt` |
| Flutter không thấy backend | Sai API_BASE_URL | Android emulator: `http://10.0.2.2:8000`; iOS: `http://localhost:8000`; thiết bị thật: IP máy host |
| SQLite file bị lock | Test CI tạo ci_test.db | `rm -f backend/ci_test.db` rồi chạy lại |

---

*HistoriAI — "Chạm vào lịch sử Việt Nam." · Đội HistoJourney 2026*
