# Hệ đo lường người dùng

Ghi lại người dùng làm gì trong app, để đến lúc báo cáo có số thật mà phân tích
thay vì đoán.

Mỗi hành vi được gửi tới **hai nơi cùng lúc**:

| Nơi | Vai trò | Khi nào có số |
|---|---|---|
| Backend của nhóm (`POST /analytics/track`) | Nguồn chính, dựng trang dashboard | Ngay lập tức |
| Google Analytics 4 | Đối chiếu, xem retention có sẵn của Google | Trễ 24–48h |

Không có GA4 thì hệ vẫn chạy đủ — GA4 chỉ bật khi build có truyền mã đo.

---

## Xem số ở đâu

```
https://<địa-chỉ-backend>/api/v1/analytics/dashboard?key=<ANALYTICS_KEY>
```

Trang này theo bộ nhận diện Imperial Light, chụp màn hình bỏ thẳng vào slide được.
Có sẵn: số người hoạt động, phễu 6 bậc, biểu đồ theo ngày, nội dung được mở nhiều
nhất, và bảng số kèm theo từng biểu đồ.

Chạy máy nhà:

```bash
cd backend
DATABASE_URL="sqlite:///./demo.db" SECRET_KEY=dev uvicorn app.main:app --reload
# rồi mở http://127.0.0.1:8000/api/v1/analytics/dashboard
```

Muốn lấy số thô để tự vẽ biểu đồ trong Excel:

```
GET /api/v1/analytics/summary?days=30&key=<ANALYTICS_KEY>
```

### Khoá xem số liệu

`ANALYTICS_KEY` trong `.env`. **Để trống là ai biết URL cũng xem được** — chỉ chấp
nhận khi chạy máy nhà. Khi deploy phải đặt; `render.yaml` đã cấu hình Render tự
sinh sẵn một khoá, xem trong tab Environment của service.

---

## Danh mục hành vi

Backend **từ chối tên ngoài danh mục** này, để mỗi người không đặt một kiểu rồi
đến lúc gộp số thì không khớp. Sửa danh mục ở hai chỗ, phải khớp nhau:

- `backend/app/services/analytics.py` → `EVENT_NAMES`
- `mobile/lib/core/analytics.dart` → `class Ev`

| Tên | Ghi khi nào | `target` | `value` |
|---|---|---|---|
| `app_open` | Mở app | — | — |
| `signup_start` | Bấm nút tạo tài khoản | — | — |
| `signup_success` | Tạo tài khoản xong | — | — |
| `login_success` | Đăng nhập xong | — | — |
| `timeline_view` | Mở dòng thời gian | — | — |
| `event_open` | Mở chi tiết một sự kiện | slug sự kiện | — |
| `video_play` | Bấm phát video cinematic | slug sự kiện | số giây |
| `ar_open` | Mở một hiện vật 3D | slug hiện vật | — |
| `ar_view` | Bấm "Đặt vào phòng" — rời app sang Scene Viewer để dựng cổ vật ra giữa phòng đúng kích thước thật | slug hiện vật | — |
| `chat_open` | Mở phòng chat vĩ nhân | slug vĩ nhân | — |
| `chat_message_sent` | Gửi một câu hỏi | slug vĩ nhân | số ký tự |
| `chat_voice_play` | Bấm nghe giọng nói | slug vĩ nhân | — |
| `quiz_start` | Vào màn chơi quiz | slug sự kiện | — |
| `quiz_submit` | Nộp bài quiz | slug sự kiện | số câu đúng |
| `quiz_result_view` | Xem màn kết quả | — | điểm |
| `premium_view` | Xem giới thiệu gói Premium | — | — |
| `premium_cta_click` | Bấm nút mua gói | — | — |

### Bốn tên chưa có chỗ gọi

`event_open`, `video_play`, `premium_view`, `premium_cta_click` đã nằm sẵn trong
danh mục nhưng **chưa màn hình nào gọi**, vì tính năng tương ứng chưa làm:

- Thẻ sự kiện trên dòng thời gian hiện chưa bấm được (chưa có `onTap`) → gắn
  `event_open` khi làm màn chi tiết sự kiện.
- Chưa có trình phát video → gắn `video_play` khi gắn player vào dòng thời gian.
- Chưa có màn giới thiệu Premium → gắn hai event doanh thu khi làm màn đó.

Bậc cuối của phễu vì thế đang bằng 0. Không phải lỗi — chưa có nút để bấm.

### Đọc `ar_view` cho đúng

`ar_view` **chỉ bắn được từ máy Android có Scene Viewer**, và chỉ với những cổ
vật đã tra được kích thước thật (nút tự ẩn cho các cổ vật còn lại — xem
`mobile/assets/brand/CREDITS.md`). Vì thế đừng so `ar_view` với `ar_open` như
một tỉ lệ chuyển đổi: mẫu số của hai bên khác nhau. Cách đọc đúng là lọc
`platform = 'android'` trước, rồi mới so.

---

## Thêm một hành vi mới

1. Thêm tên vào `EVENT_NAMES` (backend) **và** `class Ev` (Flutter). Thiếu một
   bên là backend lặng lẽ bỏ event đó.
2. Nếu nó thuộc một bậc của phễu, thêm vào `FUNNEL_STEPS`.
3. Gọi ở màn hình:

```dart
Analytics.instance.log(Ev.videoPlay, target: event.slug, value: soGiay);
```

Gọi được ở bất cứ đâu, không cần `await`, không bao giờ ném lỗi.

---

## Bật Google Analytics 4

1. Tạo property GA4 → lấy mã đo dạng `G-XXXXXXXXXX`.
2. Build web kèm mã:

```bash
flutter build web --release --base-href / \
  --dart-define=API_BASE_URL=https://<backend> \
  --dart-define=GA4_ID=G-XXXXXXXXXX
```

Không truyền `GA4_ID` thì nhánh GA4 nằm im, app vẫn đo đủ qua backend.
GA4 chỉ chạy trên web; bản Android/iOS cần Firebase Analytics, chưa làm.

---

## Cách hoạt động bên trong

**Hai định danh, đừng nhầm:**

- `client_id` — máy/trình duyệt, lưu bền trong `shared_preferences`. Nhờ nó đếm
  được người hoạt động và tỉ lệ quay lại, **kể cả người chưa đăng nhập** (phần lớn
  người thử sản phẩm là nhóm này).
- `session_id` — sinh mới mỗi lần mở app, dùng để đếm phiên.

Có đăng nhập thì backend gắn thêm `user_id`, nối được số đo với XP và tiến độ.

**Gửi theo lô.** App gom event rồi gửi mỗi 2 giây, hoặc gửi ngay khi đủ 10 cái.
Gửi hỏng thì event nằm lại hàng đợi, đi kèm lô sau — nhưng **không tự thử lại theo
vòng**, vì như vậy là dội request vào server đang chết. Hàng đợi tối đa 200, quá thì
bỏ cái cũ nhất.

**Không bao giờ làm hỏng app.** Mọi lỗi mạng đều bị nuốt, không có `await` nào chặn
giao diện. Server đo lường sập thì người dùng vẫn chat và chơi quiz bình thường.

**Không thu thập nội dung người dùng.** Câu hỏi gửi cho vĩ nhân chỉ được ghi lại
*độ dài*, không ghi chữ. Có test chặn điều này (`mobile/test/analytics_test.dart`).

**Múi giờ.** Mọi con số "theo ngày" quy về UTC+7, để buổi học lúc 9h tối không bị
đẩy sang ngày hôm sau.

---

## Chạy test

```bash
cd backend
DATABASE_URL="sqlite:///./ci_test.db" SECRET_KEY=ci-secret python -m pytest -q

cd ../mobile
C:\src\flutter\bin\flutter.bat test
```

Widget test phải gọi `Analytics.instance.datLaiChoTest()` trong `setUp()`, nếu không
timer gửi-theo-lô còn sống lúc bài test kết thúc và Flutter báo hỏng.

---

## Giới hạn đang có

- **Chưa có màn hình xin phép người dùng.** Hiện chỉ đo hành vi ẩn danh (không tên,
  không email, không nội dung chat). Nếu sau này đo thêm gì thuộc về cá nhân thì
  phải hỏi ý người dùng trước.
- **Tổng hợp bằng Python**, đọc hết event trong khoảng rồi mới đếm. Chạy tốt ở quy
  mô vài nghìn event; quá vài trăm nghìn thì phải chuyển sang bảng tổng hợp sẵn
  theo ngày.
- **Bảng `analytics_events` chưa có cơ chế dọn.** Nên xoá event cũ hơn 6 tháng khi
  dữ liệu bắt đầu nhiều.
- **Đóng tab ngay sau một thao tác** có thể mất tối đa 2 giây event cuối.
