# Rà soát phản hồi người dùng — 21/10/2026

Nhánh `feat/xu-ly-phan-hoi` (tách từ `host-tam`, tức đã gồm #74–#80).

## Nguồn

Phản hồi trong app (bảng `phan_hoi`, đọc qua `/analytics/summary`): **25 lượt**, trong đó
**19 lượt có viết góp ý** (04/10 → 17/10). Sao trung bình **4,09/5**; NPS **+20**
(10 người chấm). Toàn bộ là phản hồi thật — đợt dữ liệu mẫu 18/10 chỉ đổ vào
`analytics_events`, không đụng `phan_hoi`.

Nguồn khác: không có tệp khảo sát/góp ý nào khác trong thư mục dự án. Tài liệu
`Lộ-trình-học-giai-đoạn-Bạch-Đằng.docx` của nhóm được dùng làm nội dung (xem mục 6).

## Bảng xử lý

| # | Góp ý (rút gọn) | Ngày | Xử lý |
|---|---|---|---|
| 1 | Đấu trường: ấn đáp án phải một lúc mới hiện đáp án | 17/10 | ✅ Ô vừa bấm đổi màu + vòng quay "đang chấm" **ngay lúc bấm** (trước đây đứng im chờ mạng) |
| 2 | Đấu trường: chọn sai không hiện đáp án đúng, không giải thích | 05/10 | ✅ Máy chủ `/quiz/check` trả kèm đáp án đúng + lời giải. Sai/hết giờ → tô xanh đáp án đúng, thẻ giải thích, **chờ bấm "Câu tiếp theo"** (trước đây tự sang câu sau 1,4 giây). Màn hướng dẫn vốn đã hứa "sai thì được giảng lại ngay" |
| 3 | Điều hướng giật lag, không mượt | 04/10 | ✅ Tìm ra nguyên nhân bằng đo đạc (mục 4): lớp hạt lửa trang trí là iframe nhúng ở ~15 màn. Bỏ khỏi nền dùng chung, chỉ giữ ở trang chủ, **mặc định tắt trên điện thoại** |
| 4 | Hướng dẫn đầu nhiều chữ, bỏ qua thì không hiểu XP và streak | 17/10 | ✅ Mỗi trang hướng dẫn còn một câu. Chạm chip "Chuỗi … ngày", ô Cấp/Điểm hoặc dấu ? ở thẻ danh hiệu → bảng "Điểm, cấp và chuỗi ngày" (luật khớp máy chủ) |
| 5 | Mới vào không biết nên xem video, quiz hay chat trước | 17/10 | ✅ Thẻ **"Bắt đầu từ đây"** đầu trang chủ: 3 bước cùng trận Bạch Đằng 938 (xem phim → hỏi Trần Hưng Đạo → làm quiz), tự tích khi làm xong, ẩn được |
| 6 | Từ "sử hoá" quá (mưu lược, binh pháp tiền nhân, đồng sinh…) | 04/10 | ✅ Giữ tên danh hiệu nhưng thêm nghĩa dễ hiểu ngay dưới ("Đồng Sinh — Học trò mới vào học"); đổi chữ ở thẻ trang chủ, câu khen/chê trong quiz, nút kết quả ("Nhận giấy khen", "Về danh sách trận") |
| 7 | Giữ chuỗi vài ngày rồi không biết học tiếp bài nào | 04/10 | ✅ "Tiếp tục học" chuyển sang trận kế khi đã đạt ≥ 70% (trước đây phải 100%). Màn kết quả quiz có nút **"Học tiếp: <trận sau>"** |
| 8 | Mốc sử hôm nay: đọc xong muốn hỏi thêm mà không có chỗ bấm | 04/10 | ✅ Chạm cả thẻ để mở; nút "Học mốc này" luôn hiện (trước đây nấp sau mũi tên); mốc có vĩ nhân thì thêm nút "Hỏi Trần Hưng Đạo/Quang Trung" — câu hỏi điền sẵn, chưa gửi |
| 9 | Phụ huynh: chưa biết bài nào ứng với kiến thức con học trên lớp | 04/10 | ✅ Thẻ dòng thời gian ghi "Học trên lớp: Lớp 6 · Lớp 11". Màn chi tiết thêm **"Ghi nhớ nhanh"** (câu chốt từ tài liệu lộ trình của nhóm — 938, 981, 1288). Ẩn các dòng chương trình bị lỗi dữ liệu (mục 5) |
| 10 | iPhone chưa tải được app | 04/10 | ✅ Web trên iPhone hiện thẻ "Dùng trên iPhone như một app" + hướng dẫn 3 bước "Thêm vào MH chính" (trước đây iPhone thấy thẻ tải bản **Android**). Trang `/tai-app/` thêm mục iPhone. Bản cài iOS thật: ❌ cần tài khoản Apple Developer |
| 11 | Video mới có Bạch Đằng | 04/10 | ◐ Ba trận đã có phim gốc chờ design (Quang Trung, Lam Sơn, Tống 981) hiện khung "Phim đang được dựng" — không hứa ngày. Ảnh bìa giao Codex. **Phim thật: chờ nhóm design** |
| 12 | Nội dung còn ít / muốn nhiều sự kiện hơn (3 lượt, có phụ huynh nói nếu trả phí) | 04/10 | ❌ Cần nhóm: đường ống vòng 2 đang dừng vì hết khoá Groq. Đây là góp ý lặp nhiều nhất — liên quan trực tiếp quyết định Premium |
| 13 | Giọng vĩ nhân hơi đơ, cần nhấn nhá, hào hùng | 04/10 | ❌ Chưa làm: cần thử tham số/giọng mẫu VieNeu trên VPS và nghe so sánh — để nhóm nghe duyệt, không tự đổi |
| 14 | Bảo tàng 3D hay, muốn thêm hiện vật + thông tin | 04/10 | ❌ Cần nhóm: thêm mô hình + nội dung hiện vật |
| 15–19 | Khen: giao diện đẹp, AI không bịa, tạo câu hỏi cho giáo viên tiện, streak tạo động lực | | Giữ nguyên. Khi đổi chữ đã cố giữ "chất lịch sử nhưng không cũ" mà người dùng khen |

## 4. Đo độ giật (góp ý #3)

Bản dựng web trên máy, khung 412×880 kiểu điện thoại, Chrome giả lập CPU chậm 4 lần,
**chặn mọi lệnh gọi API** (không chạm historiai.org). Đo thời gian giữa các khung hình
khi cuộn trang chủ và đổi qua lại 6 tab:

| | Iframe trên trang | Mỗi khung (TB) | ≈ hình/giây | Khung chậm nhất |
|---|---|---|---|---|
| **Trước** — bật hạt lửa (như bản đang chạy) | 6 | 33–36 ms | ~28 | 153 ms |
| **Sau** — điện thoại (hạt lửa mặc định tắt) | 0 | 21–22 ms | ~46 | 49 ms |
| **Sau** — máy tính (hạt lửa bật, chỉ còn ở trang chủ) | 1 | 32 ms | ~31 | 48 ms |

Nguyên nhân: `DongSonBackground` (nền trống đồng dùng ở ~15 màn) nhúng kèm một iframe
CSS hạt lửa; lướt qua các tab là tích dần lên 6 iframe. Đã bỏ khỏi nền dùng chung; trang
chủ còn một lớp, **mặc định tắt trên Android/iOS**, bật lại ở Tài khoản › Tuỳ chỉnh.

### Sửa thêm khi kiểm bằng mắt

- Thanh đầu màn quiz: "Sa bàn tác chiến / Kế sách 2/10 / Sĩ khí / Liên hoàn" → "Đấu
  trường / Câu 2/10 / Phong độ / Đúng liền".
- Thẻ dòng thời gian hiện nguyên chữ tiếng Anh "timeline" → ẩn (cờ nội bộ).
- Mục "Học trên lớp" viết "thế kỉ vii" (hạ chữ thường cả số La Mã) → "thế kỉ VII".
- Bảng hướng dẫn iPhone tràn khi màn thấp → cuộn được (test bắt được).

## 5. Lỗi dữ liệu chương trình học — cần nhóm duyệt sửa trên VPS

Đường ống tách PDF chương trình GDPT 2018 bị hỏng vài dòng:

- **Lam Sơn 1428** gắn `THCS-8-04` với chủ đề chỉ còn chữ "XVIII" (thật ra là "văn hoá,
  tôn giáo thế kỉ XVI–XVIII" — không liên quan Lam Sơn) → lọc Lớp 8 bị lệch. App giờ
  ẩn dòng có chủ đề dưới 3 chữ; **nên xoá hẳn dòng này trong CSDL**.
- Lam Sơn 1428 gắn `THPT-10-08` "Thực hành lịch sử" — chung chung, nên bỏ.
- `scholarly_rank.dart` ghi Cử Nhân là "đỗ thi Hội" — sai (Cử nhân đỗ thi Hương). Đã sửa
  dòng chức danh và chiếu thư.

## 6. Nội dung lấy từ tài liệu nhóm

`Lộ-trình-học-giai-đoạn-Bạch-Đằng.docx`: lấy nguyên văn 3 "câu chốt để nhớ" vào mục
**Ghi nhớ nhanh** (`mobile/lib/data/ghi_nho.dart`) và thứ tự lộ trình 938 → 981 → 1288
cho gợi ý học tiếp. 30 câu quiz trong tài liệu (10 câu/trận) **đã có sẵn** trong kho
câu hỏi — không cần nạp thêm.

## 7. Giao Codex

`docs/PROMPT_CODEX_PHAN_HOI_21-10.md` — chỉ vẽ ảnh, code đã nối sẵn (chưa có ảnh thì
hiện biểu tượng):
1. Ảnh bước 1 "Xem phim" cho thẻ Bắt đầu từ đây.
2. 7 huy hiệu danh hiệu.
3. 3 ảnh bìa "Phim đang được dựng".
4. Nén ảnh biểu tượng có sẵn (0,5–1,1 MB/tệp → ≤ 150 KB).

## Tương thích & triển khai

- App mới + máy chủ cũ: `/quiz/check` cũ không trả đáp án → app hiện như trước; hết giờ
  gửi lựa chọn rỗng bị 422 → app tự sang câu như cũ. Không hỏng.
- App cũ + máy chủ mới: trường thêm vào bị bỏ qua. Không hỏng.
- Kiểm: **172 test máy chủ** (1 mới), **215 test app** (13 mới ở
  `test/xu_ly_phan_hoi_test.dart`), `flutter analyze` không lỗi/cảnh báo. Đã dựng bản web
  chạy với máy chủ + CSDL mẫu trên máy và soi bằng mắt: trang chủ, bảng điểm, quiz chọn
  sai, dòng thời gian, chi tiết sự kiện, trang chủ khi giả lập iPhone.
- Triển khai cần: merge chuỗi PR (#74–#80 → nhánh này), cập nhật backend trên VPS +
  `tool/phat_hanh.py web`. SSH VPS hiện đòi xác nhận Tailscale.
