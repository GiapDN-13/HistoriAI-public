# Audit chiều sâu tính năng — 27/09/2026

Rà theo **việc người dùng làm**, không theo code. Mọi mục dưới đây đã đọc code kiểm chứng
(file:dòng ở cuối mỗi mục). Khác với `AUDIT_27-09-2026.md` (bảo mật, vận hành).

**Trạng thái 27/09 tối: đã sửa hết đợt 1–3, phát hành bản 0.3.0** (trừ A10 — xem ghi chú dưới).

Ký hiệu: 🔴 người dùng nhận ra ngay / làm sai lệch số liệu · 🟡 thiếu so với mức tối thiểu · ⚪ trang trí, hứa quá

---

## A. Lỗi và dữ liệu giả — người dùng thấy ngay

| # | Vấn đề | Chỗ |
|---|---|---|
| 🔴 A1 | **Chat không nhớ câu trước.** Mỗi lượt chỉ gửi đúng 1 câu cho mô hình → hỏi "vậy sau đó thì sao?" là vĩ nhân không biết đang nói gì | `backend/app/services/ai_chat.py:112-115` |
| 🔴 A2 | **Khách không chơi được quiz.** `/quiz/check` bắt đăng nhập → khách bấm đáp án bị lỗi, đồng hồ chạy lại, lặp mãi; trong khi bản đồ ghi "Chế độ xem thử" | `backend/app/api/routes/quiz.py:47`, `quiz_play_screen.dart:220-231` |
| 🔴 A3 | **Chuỗi ngày học luôn = 0.** App không gọi `/me/streak`; mà endpoint đó cũng tính sai (dựa vào `updated_at` vừa bị quiz đặt thành hôm nay) | `progress.py:92`, `dashboard_screen.dart:390` |
| 🔴 A4 | **Nguồn trích dẫn giả:** mọi câu trả lời chat gắn cứng "Đại Việt Sử Ký Toàn Thư" | `chat_screen.dart:299` |
| 🔴 A5 | **Trang chủ nhiều số giả:** "Chiến tích" là 3 trận cứng kèm dấu tích giả; "Đang học dở" luôn là sự kiện đầu, % mặc định 45% (ép ≥20%); "Ngày này năm xưa" không đổi theo ngày | `dashboard_screen.dart:103-112, 1034-1039`, `daily_history_card.dart:128-188` |
| 🔴 A6 | **Cày XP vô hạn:** làm lại cùng bộ câu vẫn +10 XP/câu → bảng vàng mất nghĩa | `quiz.py:103-105` |
| 🔴 A7 | **Bộ lọc triều đại ở Chat ra rỗng** (lọc "Thời Trần" nhưng dữ liệu ghi "Nhà Trần…"); bộ lọc "Vũ khí/Cổ vật" ở Bảo tàng không lọc gì | `chat_list_screen.dart:32-37`, `ar_museum_screen.dart:154-168` |
| 🔴 A8 | Nộp quiz lỗi (mất mạng) bị nuốt im lặng → kết quả hiện như đã lưu | `quiz_play_screen.dart:272` |
| ⚪ A9 | "+50 Điểm" (phục chế cổ vật), "Tiếp nhận Sắc phong" chỉ đóng hộp, không cộng/lưu gì | `artifact_restore_dialog.dart:357`, `quiz_result_screen.dart:351` |
| ⚪ A10 | Hai hệ cấp độ lệch nhau: "Cấp" (máy chủ) và "phẩm hàm" (app) theo ngưỡng khác | `quiz.py:29`, `core/utils/scholarly_rank.dart` |
| ⚪ A11 | Mic trong chat chỉ hiện "đang hoàn thiện"; "Top tuần này" thực ra là tổng mọi thời gian; bản đồ quiz nói "học để mở khoá" nhưng không có khoá | `chat_screen.dart:716`, `dashboard_screen.dart:213`, `quiz_map_screen.dart:174` |

## B. Tài khoản & hồ sơ — mỏng

| # | Thiếu | Ghi chú |
|---|---|---|
| 🟡 B1 | **Không sửa được họ tên, ảnh đại diện** | `PATCH /auth/me` chỉ nhận `grade`; ảnh hồ sơ là hình cố định |
| 🟡 B2 | **Không đổi mật khẩu khi đang đăng nhập**; tài khoản Google không đặt được mật khẩu (trừ qua "Quên mật khẩu") | |
| 🟡 B3 | Không biết mình đăng nhập bằng Google hay mật khẩu | `users` không có cột cách đăng nhập |
| 🟡 B4 | **Bài làm lúc là khách mất hẳn khi đăng ký** | gắn với A2 |
| 🟡 B5 | Không hiện ngày tham gia, hạng của mình, thống kê học | `created_at` có nhưng không trả |
| 🟡 B6 | Cài đặt thiếu: liên hệ/trợ giúp, chính sách riêng tư (chỉ có ở màn đăng ký), phiên bản app, "tự đọc câu trả lời" | |

## C. Học tập — có dữ liệu mà không cho xem

| # | Thiếu | Ghi chú |
|---|---|---|
| 🟡 C1 | **Không có lịch sử làm bài, không ôn lại câu sai** | `QuizAttempt` lưu từng câu nhưng không endpoint nào đọc ra |
| 🟡 C2 | Bản đồ quiz không hiện điểm cao nhất / đã qua trận nào | `quiz_best_score` có trong `/me/progress`, không màn nào hiện |
| 🟡 C3 | "Tiếp tục học" không nhớ bài gần nhất | `updated_at` đã có |
| 🟡 C4 | "Đàm đạo cùng vĩ nhân" ở chi tiết sự kiện mở danh sách chung, không mở đúng nhân vật | `event_detail_screen.dart:274-283` |
| 🟡 C5 | Không tìm kiếm, không đánh dấu/yêu thích; đọc bài/xem phim không tính vào tiến độ | |
| 🟡 C6 | **Lịch sử chat mất khi thoát màn**; không sao chép/chia sẻ câu trả lời | `chat_screen.dart:43` |

## D. Nội dung & hứa hẹn

- Chỉ **2 vĩ nhân** (người mới chat được 1 — Quang Trung khoá tới cấp 2), trong khi câu gợi ý có sẵn cho Nguyễn Trãi, Hồ Chí Minh, Võ Nguyên Giáp… (nhánh chết).
- Premium hứa 4 quyền lợi, chưa có quyền nào; nút "Tôi muốn dùng Premium" chỉ đếm, không thu liên hệ. (Chờ nhóm chốt.)
- Hướng dẫn trang 2 hứa "đặt cổ vật ra giữa phòng" — chỉ có trên Android.

---

## Đề xuất thứ tự sửa

**Đợt 1 — sửa cái sai (≈1 ngày):** A1 chat nhớ ngữ cảnh · A2 khách chơi được quiz · A3 streak thật ·
A4 bỏ nguồn giả · A5 thay số giả bằng dữ liệu thật (hoặc ẩn) · A6 chỉ cộng XP lần đầu đúng mỗi câu ·
A7 sửa bộ lọc · A8 báo lỗi khi nộp hỏng · A9–A11 bỏ nhãn hứa suông.

**Đợt 2 — hồ sơ đúng nghĩa (≈1 ngày):** B1 sửa tên + chọn ảnh đại diện (bộ ảnh có sẵn) · B2 đổi/đặt mật khẩu ·
B3 hiện cách đăng nhập · B4 giữ bài làm của khách khi đăng ký · B5 thống kê học (tổng câu, % đúng, ngày tham gia, hạng) · B6.

**Đợt 3 — học sâu (≈1–2 ngày):** C1 lịch sử làm bài + "Ôn câu sai" · C2 điểm cao nhất trên bản đồ ·
C3 "Tiếp tục học" thật · C4 · C6 lưu lịch sử chat theo tài khoản + sao chép.

Cần nhóm quyết: thêm vĩ nhân nào (cần persona + giọng + ảnh), Premium.

---

## Kết quả (27/09, bản 0.3.0)

Đã làm: A1–A9, A11 · B1–B6 · C1–C4, C6. Chưa làm: C5 (tìm kiếm, đánh dấu), thêm vĩ nhân, Premium.

- **A10 không phải lỗi:** "Cấp" (máy chủ, dùng để mở khoá vĩ nhân) và "phẩm hàm" là hai thang khác nhau
  nhưng không mâu thuẫn — Cấp 2 cần ≥100 XP, đúng mốc lên Sĩ Tử. Giữ nguyên.
- **Lịch sử chat lưu trên máy, không lưu máy chủ** — chữ học sinh tự gõ; "Cuộc trò chuyện mới" xoá hẳn.
- **Tài khoản Google tạo TRƯỚC 27/09 19:30** bị coi là có mật khẩu (không phân biệt được) → muốn đặt mật
  khẩu thì dùng "Quên mật khẩu?". Tài khoản Google tạo sau đó hiện đúng "Đặt mật khẩu".
- Phát hiện khi kiểm thật: **chat và đường ống làm giàu dữ liệu dùng chung tổ chức Groq** → chung trần
  200.000 token/ngày; đường ống đã ăn hết, chat hỏng. Đã dừng đường ống; chat báo "quá tải" dễ hiểu.
