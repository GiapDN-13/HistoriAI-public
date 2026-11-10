# Quy trình làm việc nhóm — HistoJourney

## Nhánh Git (Git Flow gọn)

| Nhánh | Mục đích |
|---|---|
| `master` | Code ổn định, demo được, là bản đang deploy lên historiai.org. **Không push thẳng** — chỉ merge từ `develop` qua PR. |
| `develop` | Nhánh tích hợp chính. PR merge vào đây. |
| `feature/<tên>` | Mỗi tính năng/người 1 nhánh. VD: `feature/quiz-screen` |

## Phân công gợi ý (theo vai trò trong proposal)

| Người | Vai trò | Khu vực code |
|---|---|---|
| Giáp (CEO) | điều phối, AI | `backend/app/services/ai_chat.py` |
| Mẫn (CTO) | backend + hạ tầng | `backend/`, CI/CD, deploy |
| Quang (CPO) | AI tri thức (RAG) | `backend/app/services/`, GraphRAG |
| Nhung (CDO) | thiết kế 3D/UI | asset 3D, `docs/3D_ASSET_GUIDE.md`, UI Flutter |
| Thư (CMO) | nội dung lịch sử | `backend/data/seed_data.json` (sự kiện, quiz) |
| Duy (CFO) | kiểm thử, tài liệu | viết test, kiểm thử app |

## Vòng đời 1 tính năng

1. `git checkout develop && git pull`
2. `git checkout -b feature/ten-tinh-nang`
3. Code + tự test cục bộ
4. `git push -u origin feature/ten-tinh-nang`
5. Mở Pull Request vào `develop` → CI tự chạy (test + build)
6. 1 người review → merge

## Quy ước commit

```
feat: thêm màn quiz
fix: sửa lỗi load timeline
docs: cập nhật README
```

## Trước khi mở PR — tự kiểm

- Backend: `cd backend && pytest -q` phải xanh
- Mobile: `cd mobile && flutter analyze && flutter test` phải xanh
