# Kế hoạch mở rộng — App Android, AR cổ vật, nhân vật biết cử động

Đội HistoJourney · lập ngày 21/09/2026

Tài liệu này là kế hoạch thi công. Mọi con số hiện trạng trong đây đều **đo
trực tiếp trên bản đang chạy** (`historiai.anhzap.shop`) hoặc đọc từ mã nguồn,
không ước lượng.

---

## 1. Ba việc muốn làm

1. Đóng gói thành ứng dụng cài được trên điện thoại.
2. Bật camera để xem **cổ vật đúng kích thước thật** ngoài đời.
3. Nhân vật lịch sử **biết cử động** khi trò chuyện.

---

## 2. Bốn quyết định đã chốt, và vì sao

### 2.1 Làm APK, không làm bản web cho điện thoại

Bản web phải tải **10,3 MB trước khi vẽ được pixel đầu tiên** — đo thật:

| Tệp | Dung lượng |
|---|---|
| `canvaskit.wasm` | 5 553 KB |
| `main.dart.js` | 2 887 KB |
| 3 tệp font | 1 876 KB |
| **Tổng** | **10 327 KB** |

Chưa tính ảnh, chân dung, model 3D. Trong lớp học với 4G chia cho mấy chục
máy, đó là 10–20 giây màn trắng.

AR trên web còn tệ hơn: trình duyệt **không tự chạy AR** được, Android bị đá
sang app Scene Viewer, iPhone bị đá sang Quick Look. Và nó **chỉ hoạt động
trên Chrome/Android hoặc Safari/iOS** — trong khi link ở Việt Nam được gửi qua
Zalo và Facebook, mà trình duyệt nhúng của hai app đó chính là chỗ AR hỏng
đầu tiên.

Bản web **vẫn giữ nguyên, không đầu tư thêm**. Nó phục vụ đúng một việc APK
không làm được: người không muốn cài gì, và người dùng iPhone.

### 2.2 Chưa lên CH Play

Tài khoản nhà phát triển 25 USD, cộng với luật **12 người test trong 14 ngày**
áp cho tài khoản cá nhân mở mới. Cả hai đều là cái giá phải trả *trước* khi
nhận được gì.

Phát APK thẳng qua `historiai.anhzap.shop/tai-app` kèm mã QR: **0 đồng, có
ngay, không chờ ai duyệt**. Cái mất duy nhất là màn hình cảnh báo lúc cài và
khả năng người lạ tự tìm thấy app — cả hai đều chưa quan trọng ở giai đoạn này.

Ba đường né 25 USD, để dành khi nào thật sự cần lên cửa hàng:

1. Hỏi giảng viên xem **FPT đã có tài khoản nhà phát triển của trường** chưa.
   Nếu có thì mất cả tiền lẫn luật 12 người — tài khoản tổ chức được miễn.
2. Hỏi xem ai trong nhóm hoặc người nhà **đã có tài khoản Play sẵn**.
3. **Samsung Galaxy Store** — đăng ký miễn phí, mà Samsung chiếm thị phần lớn
   ở Việt Nam.

> Tuyệt đối không lập tài khoản Google ảo cho đủ 12 người. Google dò ra là
> khoá vĩnh viễn tài khoản nhà phát triển.

### 2.3 AR đi qua Scene Viewer, không nhúng ARCore vào app

| Cách | Công | Rủi ro |
|---|---|---|
| ✅ Gọi **Scene Viewer** của Google | ~1 ngày | Gần như không — Google tự bảo trì |
| ARCore trong app qua `ar_flutter_plugin` | ~1 tuần | Gói bản `0.7.3`, cũ và ít người bảo trì |

Scene Viewer nhảy ra ngoài một nhịp, nhưng từ một app đã cài thì cảm giác khác
hẳn từ trình duyệt. Đổi sang AR trong app lúc nào cũng được mà **không phải
làm lại phần dữ liệu** — vì phần đắt là chuẩn hoá kích thước model, không phải
phần gọi AR.

Hệ quả dễ chịu: **app không cần xin quyền camera.** Camera do app Scene Viewer
của Google dùng. Bản khai Data safety sau này cũng nhẹ hơn.

### 2.4 Không dựng lại bố cục desktop

Đầu tư sai chỗ khi mục tiêu là AR trên điện thoại. Để sau kỳ.

---

## 3. Hiện trạng đã kiểm chứng

### Cái đã sẵn sàng

**Mã nguồn không chặn Android.** Mọi phần chỉ chạy được trên web đều đã có sẵn
bản thay thế qua conditional import:

```
glb_viewer.dart    → glb_viewer_stub.dart    / glb_viewer_web.dart
ember_layer.dart   → ember_layer_stub.dart   / ember_layer_web.dart
browser_tts.dart   → browser_tts_stub.dart   / browser_tts_web.dart
ga4.dart           → ga4_stub.dart           / ga4_web.dart
```

`flutter create --platforms=android` xong là biên dịch chạy được ngay. Chỉ
phần xem 3D hiện ra khung giữ chỗ, đó là việc của Giai đoạn 1.

**Bộ xương nhân vật đúng chuẩn người.** Mổ `tran-hung-dao.glb`:

```
skin (rig)   : 1          ← đã có xương
node         : 43
animation    : 0          ← chưa có cử động nào
morph target : không có   ← không nhép miệng được
generator    : Tripo
```

Tên xương: `Root → Hip → Waist → Spine01 → Spine02 → NeckTwist01/02 → Head`,
`L/R_Clavicle → Upperarm → Forearm → Hand`, `L/R_Thigh → Calf → Foot → ToeBase`.
Đây là phân cấp chuẩn, **Mixamo retarget được**.

### Cái còn thiếu

**Cổ vật chưa có kích thước thật** — 8 trên 9 bỏ trống, nên tính năng "kích
thước thật" hôm nay *không thể đúng*:

| Cổ vật | `real_scale_meters` | `.usdz` |
|---|---|---|
| trong-dong-dong-son | 0.6 | — |
| coc-bach-dang-1288 | **trống** | — |
| thuyen-chien-dong-son | **trống** | — |
| kiem-dong-son | **trống** | — |
| trong-dong-khai-quat | **trống** | — |
| trong-dong-hoa-van | **trống** | — |
| nghe-den-vua-dinh | **trống** | — |
| rong-co-loa | **trống** | — |
| hu-tien-dong | **trống** | — |

**Rig thiếu hai thứ:**

- **Không có xương ngón tay** (`L_Hand` là một khối) → cử chỉ thô, không chỉ
  được bằng ngón trỏ.
- **Không có xương hàm, không có morph target** → **nhép miệng là không làm
  được** nếu không nặn thêm trong Blender.

**Model nhân vật vẫn nằm ở GitHub Pages**
(`giapdn-13.github.io/historiai-app/models/`) chứ chưa về VPS như cổ vật —
phần 3D nhân vật đang phụ thuộc một nơi nhóm không quản lý cùng lúc với
backend.

---

## 4. Giai đoạn 1 — Dựng app Android (1–2 ngày)

Mở khoá cả ba việc. Làm trước tất cả.

### 1.1 Sinh nền tảng Android

```bash
cd mobile
C:\src\flutter\bin\flutter.bat create --platforms=android --org com.histojourney .
C:\src\flutter\bin\flutter.bat build apk --debug   # phải xanh ngay lần đầu
```

Tên gói sẽ là `com.histojourney.historiai`. **Chọn một lần rồi không đổi** —
đổi tên gói sau khi phát hành là người dùng phải gỡ đi cài lại.

*Xong khi:* APK debug cài được lên một máy Android thật và mở tới màn hình
đăng nhập.

### 1.2 Sửa manifest — ba chỗ bắt buộc

Trong `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- 1. Flutter CHỈ thêm quyền này cho bản debug. Thiếu ở đây thì bản release
        cài xong mọi lời gọi mạng đều chết lặng — rất khó truy. -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- 2. Android 11+ giấu các app khác. Thiếu khối này thì không dò được
        Scene Viewer có hay không, nút AR sẽ báo sai. -->
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="https" android:host="arvr.google.com"/>
  </intent>
</queries>

<!-- 3. "optional" để máy không hỗ trợ AR vẫn cài được app bình thường. -->
<meta-data android:name="com.google.ar.core" android:value="optional"/>
```

Trong `android/app/build.gradle`: đặt `minSdk = 24` (Scene Viewer cần Android
7.0 trở lên).

*Xong khi:* bản release cài lên máy, đăng nhập được, quiz chạy được.

### 1.3 Cho bộ xem 3D chạy trên Android

Thay `glb_viewer_stub.dart` bằng bản dùng **WebView nạp chính `viewer.html`
đã chạy tốt trên web**. Không dùng `model_viewer_plus` nhúng trực tiếp — ghi
chú trong `glb_viewer.dart` đã nói rõ cách đó từng ra ô trống.

Dùng lại đúng URL cũ nên không phải kiểm thử lại phần render:

```
https://historiai.anhzap.shop/viewer.html?model=<slug>
```

*Xong khi:* mở Bảo tàng trên điện thoại, chạm một cổ vật, model xoay được
bằng ngón tay.

### 1.4 Gom model nhân vật về VPS

Tải 2 tệp từ GitHub Pages, nén bằng `gltf-transform optimize` như đã làm với
cổ vật, đưa lên `/home/giapdn/historiai/web/models/`, cập nhật `model_url`
trong `seed_data.json` sang `{ASSET}/models/<slug>.glb`.

*Xong khi:* `giapdn-13.github.io` không còn xuất hiện trong nhật ký mạng của
app.

---

## 5. Giai đoạn 2 — AR cổ vật kích thước thật (2–3 ngày)

Phần lớn công là **tra cứu sử liệu, không phải lập trình**.

### 2.1 Tra kích thước thật cho 9 cổ vật

Điền `real_scale_meters` trong `backend/data/seed_data.json` — ghi **chiều lớn
nhất của hiện vật, đơn vị mét**.

Nguồn tra: hồ sơ **Bảo vật quốc gia**, trang Bảo tàng Lịch sử Quốc gia, biển
chú thích hiện vật tại bảo tàng.

> **Không được ước lượng bằng mắt.** Sai kích thước thì tính năng này phản tác
> dụng: người học sẽ nhớ sai kích thước cổ vật, còn tệ hơn là không có gì. Mỗi
> con số phải kèm nguồn, ghi vào `mobile/assets/brand/CREDITS.md`.

### 2.2 Chuẩn hoá tỉ lệ tệp .glb về mét

Model tải từ Sketchfab có tỉ lệ tuỳ ý. Viết `mobile/tool/chuan_hoa_ti_le.py`
(hoặc script Node dùng `@gltf-transform/core`): đọc kích thước bao của model,
nhân tỉ lệ nút gốc sao cho chiều lớn nhất đúng bằng `real_scale_meters`.

*Xong khi:* mở `viewer.html` với thước đo, trống đồng cao đúng 0,6 m.

### 2.3 Nút "Đặt vào phòng"

Nút Flutter thuần — **không** phải nút trong WebView, vì WebView chặn điều
hướng `intent://`. Gọi bằng `url_launcher`:

```
https://arvr.google.com/scene-viewer/1.0
  ?file=https://historiai.anhzap.shop/models/<slug>.glb
  &mode=ar_preferred
  &resizable=false          ← CHÍNH CHỖ NÀY khoá kích thước thật
  &title=<tên cổ vật>
```

`resizable=false` là thứ biến nó thành "kích thước thật" — người dùng không
phóng to thu nhỏ được, cổ vật đứng đúng cỡ ngoài đời.

Chỉ hiện nút khi máy có Scene Viewer. Máy không có thì ẩn, đừng hiện nút chết.

### 2.4 Đo lường

Thêm sự kiện `ar_view` vào danh mục trong `backend/app/services/analytics.py`
và bắn khi người dùng bấm nút.

### 2.5 iOS — hoãn

Cần tệp `.usdz`, mà công cụ chuyển đổi chính thức của Apple chỉ chạy trên máy
Mac. Vì kỳ này phát APK cho Android, **để lại giai đoạn sau**.

---

## 6. Giai đoạn 3 — Phát hành APK (nửa ngày)

### 3.1 Tạo khoá ký

```bash
keytool -genkey -v -keystore historiai-release.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias historiai
```

> ⚠ **Mất tệp khoá hoặc quên mật khẩu là vĩnh viễn không cập nhật được app
> dưới cùng danh tính nữa** — người dùng phải gỡ đi cài lại từ đầu. Cất vào
> Drive riêng của nhóm, ít nhất hai người giữ. **Không commit vào repo**, kể
> cả repo private.

Thêm `android/key.properties` vào `.gitignore`.

### 3.2 Xuất bản cài

```bash
C:\src\flutter\bin\flutter.bat build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=https://historiai.anhzap.shop
```

`--split-per-abi` cắt dung lượng khoảng một nửa. Phát bản `arm64-v8a` — gần
như mọi điện thoại Android từ 2017 trở lại đây đều dùng.

Dự kiến **25–30 MB**, tải qua 4G chừng nửa phút.

### 3.3 Trang tải

Trang tĩnh `tai-app/index.html` trên VPS, theo bộ nhận diện Imperial Light:
mã QR, nút tải, và **hướng dẫn 3 bước qua màn hình cảnh báo "nguồn không xác
định"** — thiếu phần hướng dẫn này là mất kha khá người ngay ở bước cài.

*Xong khi:* một người ngoài nhóm quét QR và cài xong mà không cần hỏi gì.

---

## 7. Giai đoạn 4 — Nhân vật biết cử động (~1 tuần)

### 4.1 Nạp cử động vào bộ xương sẵn có

Trong Blender: nhập `tran-hung-dao.glb`, ánh xạ xương sang chuẩn Mixamo (làm
tay một lần, lần sau dùng lại), tải về 5 đoạn từ mixamo.com (miễn phí):

| Đoạn | Dùng khi |
|---|---|
| `dung_tho` | mặc định, lặp vô hạn |
| `chao` | mở đầu cuộc trò chuyện |
| `giang_giai` | đang trả lời (lặp) |
| `chi_tay` | nhắc tới địa danh, trận đánh |
| `nghiem_nghi` | nói về mất mát, hy sinh |

Retarget, xuất lại `.glb` có `animations`, nén, đưa lên VPS.

*Xong khi:* `viewer.html?model=tran-hung-dao&anim=chao` chạy đúng đoạn đó.

### 4.2 Cho LLM chọn cử chỉ

Thêm vào `persona_prompt` trong `seed_data.json`: yêu cầu mở đầu mỗi câu trả
lời bằng đúng một thẻ `[chao]`, `[giang_giai]`, `[chi_tay]`, `[nghiem_nghi]`.
Phía Flutter cắt thẻ ra **trước khi hiển thị và trước khi đưa sang TTS**, rồi
ánh xạ sang tên đoạn cử động.

> Bắt buộc coi thẻ là **tuỳ chọn**: không có thẻ thì rơi về `giang_giai`.
> Persona hiện đã mang khối "SỬ LIỆU CỐT LÕI"; thêm ràng buộc định dạng có thể
> làm model lơ là phần sử liệu. Nếu thấy độ chính xác tụt thì bỏ thẻ, chuyển
> sang đoán cử chỉ từ dấu câu.

### 4.3 Thiết kế né chỗ rig còn thiếu

Rig không có xương hàm và không có morph target, nên **không nhép miệng được**.
Hai cách né, làm cả hai:

- **Đóng khung ngang tầm 3/4 người, không cận mặt.** Ở cỡ màn hình điện thoại,
  không ai nhận ra miệng không động nếu không zoom vào mặt.
- **Gật đầu nhẹ theo biên độ âm thanh** — đủ tạo cảm giác đang nói.

Nhép miệng thật cần nặn morph target trong Blender rồi dùng Rhubarb Lip Sync
(miễn phí, chạy ngoại tuyến) sinh khẩu hình từ chính tệp audio đã cache. Ghép
rất vừa với hệ cache TTS hiện có, nhưng **để sau kỳ**.

---

## 8. Việc cố tình không làm kỳ này

| Việc | Vì sao |
|---|---|
| Camera đọc mặt người dùng để nhân vật phản ứng | Công gấp mấy lần, khác biệt cảm nhận trên màn hình điện thoại gần như bằng không |
| Nhép miệng thật | Cần nặn lại model; xem 4.3 để biết cách né |
| Dựng lại bố cục desktop | Sai trọng tâm khi mục tiêu là AR trên điện thoại |
| App iOS | Không có máy Mac; bản web kèm Quick Look phục vụ tạm |
| ARCore nhúng trong app | Gói Flutter tương ứng cũ và ít bảo trì |
| Lên CH Play | Xem mục 2.2 |

---

## 9. Rủi ro

| Rủi ro | Dấu hiệu sớm | Cách xử |
|---|---|---|
| Không tra được kích thước thật của vài cổ vật | Tra 2 giờ không ra nguồn | Ẩn nút AR riêng cổ vật đó. **Không đoán bừa** |
| Retarget Mixamo ra tư thế méo | Thấy ngay ở đoạn đầu tiên | Giảm còn 2 đoạn: `dung_tho` và `giang_giai` |
| Bản release chết mạng mà debug thì chạy | API nào cũng lỗi sau khi cài bản release | Thiếu `INTERNET` trong manifest — xem 1.2 |
| WebView Android không render `.glb` | Ô trống ở Bảo tàng | Thử `model_viewer_plus`; vẫn hỏng thì rơi về ảnh bìa kèm nút AR |
| Thẻ cử chỉ làm LLM nói sai sử | Trả lời sai nhiều hơn trước | Bỏ thẻ, đoán cử chỉ từ dấu câu |
| Mất tệp khoá ký | — | Không cứu được. Sao lưu ngay khi tạo |

---

## 10. Thứ tự và phụ thuộc

```
GĐ1 Android  ──┬──> GĐ2 AR cổ vật  ──> GĐ3 Phát hành APK
   (1–2 ngày)  │      (2–3 ngày)          (nửa ngày)
               └──> GĐ4 Cử động nhân vật
                      (~1 tuần)
```

GĐ2 và GĐ4 chạy song song được nếu chia hai người. Một người làm tuần tự thì
khoảng **2 tuần** là có app cài từ QR, AR cổ vật đúng kích thước thật, và nhân
vật biết cử động.

**Việc chia được cho người không code:** tra kích thước 9 cổ vật (2.1), viết
hướng dẫn cài cho trang tải (3.3), gom 12 người thử app và ghi lại phản hồi.

---

## 11. Bảng nghiệm thu

- [ ] APK release cài được trên ít nhất 3 máy Android khác nhau
- [ ] Không còn lời gọi nào ra `giapdn-13.github.io`
- [ ] Bảo tàng: chạm cổ vật thì model xoay được bằng ngón tay
- [ ] Nút "Đặt vào phòng" mở Scene Viewer, cổ vật đứng đúng cỡ ngoài đời
- [ ] Máy không hỗ trợ AR: nút ẩn đi, app không lỗi
- [ ] Mỗi kích thước cổ vật đều có nguồn ghi trong `CREDITS.md`
- [ ] Chat: nhân vật đứng thở khi im, đổi cử chỉ khi trả lời
- [ ] Bảng đo lường ghi nhận `ar_view`
- [ ] Rút mạng giữa chừng: Bảo tàng vẫn mở được, chỉ chat và quiz báo chờ
- [ ] Khoá ký đã sao lưu ngoài repo, ít nhất hai người giữ
- [ ] `flutter analyze` 0 lỗi, `flutter test` và `pytest` đều xanh
