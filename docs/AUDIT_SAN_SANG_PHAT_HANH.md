# Audit: còn thiếu gì để dùng thật

Rà ngày 22/09/2026 trên bản đang chạy tại `historiai.anhzap.shop`.
Mọi kết luận dưới đây đều **kiểm chứng trực tiếp**, không suy đoán từ mã.

---

## Tóm tắt

| | Số mục |
|---|---|
| 🔴 Chặn phát hành thật | **5** |
| 🟠 Nên sửa trước khi có người dùng thật | **6** |
| 🟡 Nợ kỹ thuật, không gấp | **4** |

Ba mục nặng nhất: **không có bản sao lưu nào**, **bảng vàng là tên bịa**, và
**endpoint xếp hạng phát họ tên thật cho bất kỳ ai không cần đăng nhập**.

---

## 🔴 Chặn phát hành thật

### 1. Cơ sở dữ liệu KHÔNG được sao lưu

Toàn bộ tài khoản, lịch sử làm bài và số liệu đo lường nằm trong **một tệp
SQLite 221 KB** tại `/home/giapdn/historiai/data/historiai.db`.

Máy chủ *có* cron sao lưu, nhưng nó sao lưu **dự án khác**:

```
/home/giapdn/deploy-files/backup.sh
  → sqlite3 "$APP/prisma/dev.db" ".backup ..."      ← Dream Makers Image
```

`historiai.db` không xuất hiện ở bất kỳ đâu trong script đó. Ổ đĩa hỏng hoặc
lỡ tay `rm` là mất sạch, không có đường lùi.

**Sửa:** thêm HistoriAI vào script sao lưu sẵn có. Dùng `sqlite3 .backup` chứ
đừng `cp` thẳng tệp đang được ghi — script hiện tại đã làm đúng cách đó cho dự
án kia, chỉ việc lặp lại.

### 2. Bảng vàng là tên bịa

Màn hình chính hiện "Minh Trí 280đ · Hoàng Nam 350đ · Lan Anh 210đ" — **ba cái
tên viết cứng trong mã** (`dashboard_screen.dart:1214-1218`).

Trớ trêu là backend **đã có** endpoint thật chạy tốt:

```
GET /api/v1/leaderboard?limit=5
  #1 Man              xp=110
  #2 Kiem Thu Quiz    xp=100
  #3 Đặng Nguyên Giáp xp=0
```

Không màn nào gọi nó. Người dùng thật leo hạng sẽ không bao giờ thấy tên mình,
và ba cái tên kia không bao giờ đổi — ai dùng vài ngày là nhận ra.

Cùng loại: dòng "Báo cáo phụ huynh tuần này: Con đã hoàn thành xuất sắc các mốc
lịch sử" (`dashboard_screen.dart:176`) cũng là câu cố định, không đọc dữ liệu.

### 3. Endpoint xếp hạng phát họ tên thật, không cần đăng nhập

```
curl https://historiai.anhzap.shop/api/v1/leaderboard   → 200, kèm full_name
```

Sản phẩm nhắm **học sinh THCS/THPT**, tức phần lớn là trẻ vị thành niên. Phát
danh sách họ tên thật cho bất kỳ ai biết đường dẫn là chuyện không nên có,
tách rời mọi yêu cầu pháp lý.

**Sửa:** bắt đăng nhập, và trả **tên hiển thị rút gọn** (ví dụ "Giáp Đ.") chứ
không phải họ tên đầy đủ. Bảng vàng không cần biết đủ tên ai mới vui được.

### 4. Không có chính sách quyền riêng tư, không có cách xoá tài khoản

Rà toàn bộ `mobile/`, `web/`, `docs/`: **không có** trang chính sách quyền
riêng tư, không có điều khoản sử dụng, không có endpoint xoá tài khoản.

App đang thu: email, họ tên, mật khẩu, lịch sử làm bài, và **252 sự kiện đo
lường hành vi**. Với người dùng vị thành niên, nói rõ thu gì và cho phép rút
lui là mức tối thiểu — chưa bàn tới việc Google Play **bắt buộc** cả hai thứ
này nếu sau đó nhóm muốn lên cửa hàng.

### 5. CI đang đỏ, và đỏ vì tôi

```
Mobile CI  develop  failure
  Because historiai depends on webview_flutter >=4.11.0
  which requires SDK version >=3.6.0, version solving failed.
```

Workflow ghim `flutter-version: "3.24.x"` (Dart 3.5.4), còn `webview_flutter`
tôi thêm ở GĐ1 cần Dart ≥ 3.6. Máy tôi chạy Flutter 3.41.6 nên không thấy.

Nghĩa là **từ GĐ1 tới giờ không lần nào CI xanh** — mọi thay đổi đều chỉ được
kiểm trên máy tôi. Backend CI vẫn xanh.

**Sửa:** nâng `flutter-version` trong `.github/workflows/mobile.yml` cho khớp
bản đang dùng.

---

## 🟠 Nên sửa trước khi có người dùng thật

### 6. "Quên mật khẩu?" là nút chết

Bấm vào chỉ hiện thông báo *"Tính năng đang được hoàn thiện. Vui lòng liên hệ
quản trị viên lớp học."* Backend không có endpoint đặt lại mật khẩu nào.

Người quên mật khẩu = mất tài khoản vĩnh viễn, mất cả tiến độ học. Ở quy mô
một lớp thì còn xoay được; phát ra ngoài thì không.

### 7. ~~CORS mở cho mọi tên miền~~ — ĐÍNH CHÍNH: production vốn đã đúng

Mục này ban đầu tôi đánh giá nặng tay vì chỉ nhìn mặc định `"*"` trong
`config.py`. Kiểm lại trên bản chạy thật thì **`.env` đã đặt đúng tên miền**,
và origin lạ KHÔNG nhận được `access-control-allow-origin`:

```
Origin: https://ke-xau.example     → không có access-control-allow-origin
Origin: https://historiai.anhzap.shop → access-control-allow-origin: đúng nó
```

Trình duyệt sẽ chặn origin lạ. **Không có lỗ hổng.**

Thứ đáng sửa là **giá trị mặc định trong mã**: `CORS_ORIGINS = "*"` ghép với
`allow_credentials=True` là tổ hợp bị đặc tả CORS cấm, nên ai dựng bản mới mà
quên đặt biến môi trường sẽ chạy với cấu hình sai mà không biết. Đã đổi mặc
định thành localhost.

### 8. Không có theo dõi lỗi

Không có Sentry hay tương đương ở cả hai phía. App hỏng trên máy người dùng thì
nhóm **không biết** — trừ khi người đó chịu khó nhắn tin.

Với một sản phẩm sắp phát ra ngoài, đây là thứ rẻ nhất mang lại nhiều thông tin
nhất. Sentry có gói miễn phí đủ dùng.

### 9. Phiên đăng nhập 7 ngày, không có cách thu hồi

`ACCESS_TOKEN_EXPIRE_MINUTES = 60*24*7`. Token JWT không có danh sách thu hồi,
nên "đăng xuất" chỉ xoá token ở máy người dùng — token đó vẫn dùng được cho tới
khi hết hạn. Mất điện thoại là mất bảy ngày.

### 10. Ghi công giấy phép không hiện cho người dùng

Chín mô hình 3D dùng giấy phép **CC BY / CC BY-SA** từ Sketchfab. Giấy phép đó
**bắt buộc ghi công ở nơi người dùng thấy được**. Hiện phần ghi công nằm trong
`mobile/assets/brand/CREDITS.md` — một tệp trong mã nguồn, người dùng không bao
giờ mở.

**Sửa:** một màn "Nguồn tư liệu" trong app, dẫn từ hộp tài khoản.

### 11. Nội dung còn mỏng và chưa ai thẩm định

- Chỉ Bạch Đằng 938 có thước phim. Bốn trận còn lại: `cinematic_video_url` trỏ
  vào tệp **không tồn tại**.
- Lam Sơn 1428 mới có 5 câu quiz, trong khi ba trận kia có 10.
- Ba cổ vật chưa có kích thước thật nên nút AR bị ẩn.
- **Toàn bộ câu trả lời của nhân vật lịch sử chưa được người có chuyên môn rà.**
  Đã siết bằng khối "SỬ LIỆU CỐT LÕI" và nhiệt độ thấp, nhưng mô hình ngôn ngữ
  vẫn chế được — và sai sử trong một sản phẩm dạy sử là lỗi nặng nhất có thể.

---

## 🟡 Nợ kỹ thuật, không gấp

### 12. SQLite cho nhiều người dùng đồng thời

221 KB, 3 người dùng — hiện chưa sao. SQLite khoá toàn bộ tệp khi ghi, nên khi
vài chục người cùng nộp bài sẽ bắt đầu thấy chậm. Chuyển sang PostgreSQL khi
nào thật sự cần, đừng làm sớm.

### 13. Không có Alembic

Đổi cấu trúc bảng đang phải nhờ `_ensure_column()` viết tay trong `seed.py`.
Chạy được, nhưng không lùi lại được và không có lịch sử.

### 14. iOS chưa có gì

Không có bản cài, không có tệp `.usdz` nên AR trên iPhone không chạy. Người
dùng iPhone hiện chỉ có bản web.

### 15. Giới hạn gọi LLM nằm trong bộ nhớ tiến trình

Khởi động lại dịch vụ là mất sạch số đếm. Đủ để chặn lạm dụng, không đủ để tính
tiền. Chuyển sang Redis khi nào cần chính xác.

---

## Cái đang làm tốt

Ghi lại để khỏi sửa nhầm thứ không hỏng:

- **API chạy dưới systemd** (`Restart=always`, `enabled`) — sống sót khi khởi
  động lại máy. Cloudflared cũng vậy.
- **Mật khẩu có kiểm tra độ dài** (tối thiểu 8 ký tự, thử `"1"` bị chặn).
- **Các endpoint riêng tư đều đòi token**: `/me/progress`, `/auth/me`,
  `/analytics/*` đều trả 401. Chỉ `/leaderboard` là lọt.
- **Đã chặn lạm dụng `/chat`** theo máy, theo IP và trần ngày.
- **Điểm và tiến độ lưu thật**, kiểm chứng qua nhiều phiên.
- **129 test tự động** (90 Flutter + 39 backend), analyze 0 lỗi 0 cảnh báo.

---

## Thứ tự đề xuất

Xếp theo *thiệt hại nếu bỏ qua* chia cho *công bỏ ra*:

| # | Việc | Công |
|---|---|---|
| 1 | Thêm `historiai.db` vào script sao lưu sẵn có | 15 phút |
| 2 | Bắt đăng nhập cho `/leaderboard` + rút gọn tên hiển thị | 30 phút |
| 3 | Nâng phiên bản Flutter trong CI cho hết đỏ | 10 phút |
| 4 | Nối bảng vàng vào endpoint thật, bỏ ba cái tên bịa | 1 giờ |
| 5 | Trang chính sách quyền riêng tư + endpoint xoá tài khoản | nửa ngày |
| 6 | Màn "Nguồn tư liệu" hiện ghi công giấy phép | 1 giờ |
| 7 | Đặt lại mật khẩu qua email | 1 ngày |
| 8 | Gắn Sentry hai phía | 2 giờ |

Bốn việc đầu **gộp lại chưa tới hai tiếng** mà gỡ được ba trong năm mục chặn
phát hành.
