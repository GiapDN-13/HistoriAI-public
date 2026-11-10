# Đợt 3/4 — màn chiếu

Bố trí màn chiếu 16:9: sảnh QR lớn, câu hỏi rõ, phân bổ + top cùng khung; điều khiển có một hành động chính.

## Phạm vi và thứ tự ghép

PR vào `feat/bang-vang-lop-hoc`. Ghép theo thứ tự 1 → 2 → 3 → 4.
Các nhánh xếp chồng, nên PR sau còn chứa đợt trước khi chưa ghép; diff sẽ thu gọn sau khi ghép.
Không sửa backend, API, kết nối, prompt AI, luật điểm hay nộp bài; không thêm gói.

## Kiểm tra

- `flutter analyze --no-fatal-infos`: 0 error, 0 warning.
- `flutter test`: 194 test xanh trên nhánh này.
- Test thêm: Mọi pha học sinh/màn chiếu ở 320/412/1280, câu hỏi máy chiếu ≥40 px và giảm chuyển động.
- Bản tích hợp cuối: 202 test xanh; dựng web phát hành và web QA thành công.

## Ảnh trước/sau

Ảnh dùng dữ liệu giả và tên dài có dấu. Ảnh trước ở c9e0e8c; ảnh sau là bản tích hợp bốn đợt.

Trước:

![Trước](https://raw.githubusercontent.com/GiapDN-13/HistoriAI/feat/lop-hoc-ui-4-giao-vien/output/playwright/lop-hoc-ui/truoc-chieu-phan-bo-1280.png)

Sau:

![Sau](https://raw.githubusercontent.com/GiapDN-13/HistoriAI/feat/lop-hoc-ui-4-giao-vien/output/playwright/lop-hoc-ui/chieu-phan-bo-1280.png)

[Toàn bộ ảnh 412 / 1280×720, hai khổ giấy và nhật ký QA](https://github.com/GiapDN-13/HistoriAI/blob/feat/lop-hoc-ui-4-giao-vien/docs/LOP_HOC_UI_KIEM_TRA.md).
Chưa đo máy chiếu vật lý ở 8 m; chưa dựng APK.

## Dữ liệu backend cần xác nhận

Không cần route mới. Bảo đảm `avatar_url` nullable và `avatar` (mã ảnh có sẵn) trong
`top`/`cua_toi` của `GET /phong/{ma}/xep-hang`, và `top`/`bang_xep_hang` của
`GET /phong/{ma}/truc-tiep` / gói WebSocket `trang_thai`.
Danh sách sảnh `hoc_sinh` có thể dùng cùng trường. Thiếu/hỏng ảnh thì UI dự phòng chữ cái;
không cần gửi thêm đáp án trước khi học sinh trả lời.

