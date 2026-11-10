# Kiểm tra giao diện lớp học

Bản tích hợp dùng Imperial Light, ba font đúng weight và CTA cam trong phạm vi
lớp học. Giữ API, kết nối, luật điểm/nộp, đồng hạng, ID âm và cả ba lối vào.
Không thêm dependency. Các ảnh dưới dùng dữ liệu giả, không dùng dữ liệu học sinh thật.

## Kiểm tra

- PR vào `feat/bang-vang-lop-hoc`, ghép lần lượt:
  [widget #77](https://github.com/GiapDN-13/HistoriAI/pull/77) (173 test),
  [học sinh #78](https://github.com/GiapDN-13/HistoriAI/pull/78) (179 test),
  [màn chiếu #79](https://github.com/GiapDN-13/HistoriAI/pull/79) (194 test),
  [giáo viên #80](https://github.com/GiapDN-13/HistoriAI/pull/80) (202 test).
  Cả bốn nhánh đã chạy analyze và toàn bộ test độc lập trước khi mở PR.
- `flutter analyze --no-fatal-infos`: 0 error, 0 warning (còn lint mức info).
- `flutter test`: 202 test xanh ở bản tích hợp cuối.
- `flutter build web --no-pub`: dựng được entry phát hành `lib/main.dart`.
- Bản QA: `flutter build web --no-pub -t tool/xem_lop_hoc.dart --output build/xem-lop-hoc`.
- Học sinh 320/412/1280, các pha chờ/hỏi/lộ đáp án/kết thúc; máy chiếu 1280×720,
  câu hỏi 42 px. Kiểm tra thêm 320×568 để đáp án D luôn bấm được.
- Tên dài có dấu, trường null, em ngoài top 10, hạng thấp không có chữ Hạng trên giấy.
- Tắt hiệu ứng bằng tùy chọn app hoặc hệ thống không tạo tween/ticker của hiệu ứng.
- Chọn hết giới hạn 60 và giữ ID âm; dán AI phải xem trước khi lưu, sửa chữ phải xem lại.
- Đổi khổ giấy ở 320/412/1280: boundary luôn 480×600 hoặc 420×746⅔.
- Bấm tải PNG trên web: [4:5](../output/playwright/lop-hoc-ui/giay-45-export.png)
  1440×1800 và [9:16](../output/playwright/lop-hoc-ui/giay-916-export.png) 1260×2240.
  Boundary nằm trong FittedBox, không chứa nút/viền app; pixelRatio 3.

## Ảnh trước/sau

Ảnh trước lấy từ `c9e0e8c` trong checkout riêng; chỉ thêm tham số tiêm API giả ở
VaoPhong/GiaoVien/SoanDe để dùng cùng bộ dữ liệu, không đổi phần dựng giao diện.
Ảnh sau là bản tích hợp cả bốn đợt. Khổ story chưa tồn tại ở bản trước.

| Màn | Trước | Sau |
|---|---|---|
| Vào phòng 412 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-vao-412.png) | [Ảnh](../output/playwright/lop-hoc-ui/vao-412.png) |
| Tên + PIN 412 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-vao-ten-412.png) | [Ảnh](../output/playwright/lop-hoc-ui/vao-ten-412.png) |
| Làm câu 412 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-bai-412.png) | [Ảnh](../output/playwright/lop-hoc-ui/bai-412.png) |
| Đúng 412 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-dung-412.png) | [Ảnh](../output/playwright/lop-hoc-ui/dung-412.png) |
| Sai 412 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-sai-412.png) | [Ảnh](../output/playwright/lop-hoc-ui/sai-412.png) |
| Kết quả trực tiếp + bảng vàng 412 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-ket-qua-412.png) | [Ảnh](../output/playwright/lop-hoc-ui/ket-qua-412.png) |
| Kết quả bài tập 412 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-bai-ket-qua-412.png) | [Ảnh](../output/playwright/lop-hoc-ui/bai-ket-qua-412.png) |
| Giấy 4:5 / khổ cũ 412 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-giay-45-412.png) | [Ảnh](../output/playwright/lop-hoc-ui/giay-45-412.png) |
| Giấy story 412 | Chưa có | [Ảnh](../output/playwright/lop-hoc-ui/giay-916-412.png) |
| Chiếu chờ 1280×720 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-chieu-cho-1280.png) | [Ảnh](../output/playwright/lop-hoc-ui/chieu-cho-1280.png) |
| Chiếu hỏi 1280×720 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-chieu-cau-1280.png) | [Ảnh](../output/playwright/lop-hoc-ui/chieu-cau-1280.png) |
| Chiếu phân bổ 1280×720 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-chieu-phan-bo-1280.png) | [Ảnh](../output/playwright/lop-hoc-ui/chieu-phan-bo-1280.png) |
| Chiếu chung cuộc 1280×720 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-chieu-chung-cuoc-1280.png) | [Ảnh](../output/playwright/lop-hoc-ui/chieu-chung-cuoc-1280.png) |
| Giáo viên 1280×720 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-giao-vien-1280.png) | [Ảnh](../output/playwright/lop-hoc-ui/giao-vien-1280.png) |
| Soạn đề 1280×720 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-soan-de-1280.png) | [Ảnh](../output/playwright/lop-hoc-ui/soan-de-1280.png) |
| Dán AI 1280×720 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-dan-ai-1280.png) | [Ảnh](../output/playwright/lop-hoc-ui/dan-ai-1280.png) |
| Phòng bài tập 1280×720 | [Ảnh](../output/playwright/lop-hoc-ui/truoc-phong-1280.png) | [Ảnh](../output/playwright/lop-hoc-ui/phong-1280.png) |

## Dữ liệu backend

Không cần route mới. UI đã đọc `avatar_url` nullable và `avatar` (mã bộ ảnh sẵn),
có dự phòng chữ cái trên màu sinh từ tên khi không có ảnh hoặc ảnh lỗi.
Nhóm backend cần bảo đảm hai trường xuất hiện trong `top`/`cua_toi` của
`GET /phong/{ma}/xep-hang` và `top`/`bang_xep_hang` của trạng thái trực tiếp
(REST `GET /phong/{ma}/truc-tiep`, gói WebSocket `trang_thai`).
Nếu danh sách sảnh cũng có ảnh, dùng cùng trường trong `hoc_sinh`; thiếu vẫn dùng tên.
Không cần gửi thêm đáp án hoặc điểm tự tính về máy học sinh.

Chưa đo trên máy chiếu thật ở khoảng cách 8 m hoặc dựng APK; QA thực hiện bằng
CanvasKit trên Chrome. Nút toàn màn hình có đường dự phòng F11 khi trình duyệt chặn.
