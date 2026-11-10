# SPEC — Thay máu UI/UX HistoriAI

> Tài liệu giao việc cho agent thực hiện. Đọc hết trước khi sửa dòng code đầu tiên.
> Mọi đường dẫn tính từ `mobile/` trừ khi ghi rõ khác.

**Ngày lập:** 15/09/2026 · **Mốc phải xong:** trước buổi demo tuần 10
**Trạng thái hiện tại đã khảo sát:** 7/11 màn hình chạy thật, ảnh chụp và lỗi cụ thể ở mục 2.

---

## 0. TL;DR — làm gì trong một đoạn

Giữ **đỏ son · vàng hoàng gia · nền kem** làm bản sắc, còn lại dựng lại thoải mái. Việc
bắt buộc: dẹp bảng màu navy/xám đang lạc điệu ở Quiz và Chat, đưa font thương hiệu vào
app, sửa thanh tab dưới đang **giả** (bấm tab nào cũng chỉ quay lại màn trước), Việt hoá
toàn bộ chữ, lấp khoảng trống mênh mông ở các màn ít dữ liệu, thêm **chế độ trình chiếu**
cho buổi demo. Không đổi API, không đổi luồng nghiệp vụ, **không được làm mất hệ đo lường**
vừa gắn xong.

Ngoài phần bắt buộc đó thì **được toàn quyền sáng tạo** — bố cục, chuyển động, chất liệu,
màn mới. Mục 16 là ngân hàng ý tưởng để chọn, không phải danh sách việc phải làm. Mục 1.2
nói rõ ranh giới; mục 1.3 là ba câu hỏi để tự phân xử khi phân vân.

**Đọc theo thứ tự:** mục 1 (ranh giới) → mục 2 (16 lỗi đang có) → mục 16 (ý tưởng) →
mục 14 (bắt tay làm).

---

## 1. Ranh giới — cái gì cấm, cái gì tự do

Tài liệu này **mô tả vấn đề cần giải, không kê đơn từng pixel**. Phần lớn giải pháp cụ thể
bên dưới là *điểm khởi hành*, không phải mệnh lệnh. Nếu nghĩ ra cách hay hơn thì làm cách
hay hơn — chỉ cần không chạm vào 8 điều dưới đây và giải thích được lựa chọn trong mô tả
commit.

### 1.1 Tám điều bất di bất dịch

| # | Ràng buộc | Vì sao |
|---|---|---|
| R1 | **Không sửa gì trong `backend/`** | Backend đang chạy thật trên Render, 28 test xanh. Việc này thuần UI. |
| R2 | **Không đổi chữ ký API, không đổi `lib/data/models.dart`** | Đổi là vỡ tầng dữ liệu, ngoài phạm vi. |
| R3 | **Giữ đủ 12 lời gọi `Analytics.instance.log`** (mục 9) | Hệ đo lường vừa làm xong; mất một lời gọi là tuần 10 thiếu số. |
| R4 | **`flutter analyze` không được có `error` hay `warning` mới** | Hiện tại: 0 error, 0 warning, 55 info (đều là `withOpacity` cũ). |
| R5 | **`flutter test` phải xanh** | Trong đó 5 test chặn hồi quy cho đo lường. Thêm test mới thì càng tốt. |
| R6 | **Đỏ son · vàng hoàng gia · nền kem vẫn phải là ba màu người ta nhớ về app** | Slide, landing page và dashboard đo lường đều theo bảng này. Cách *dùng* ba màu đó thì tự do. |
| R7 | **Toàn bộ chữ hiển thị bằng tiếng Việt** | Người dùng là học sinh THCS/THPT, người trả tiền là phụ huynh 35–50 tuổi. |
| R8 | **Không hứa tính năng chưa có** | Nút không được mời gọi thứ bấm vào không xảy ra. Xem L10, L11. |

### 1.2 Được toàn quyền quyết định

Không cần hỏi ai, cứ làm nếu thấy tốt hơn:

- **Bố cục mọi màn hình.** Mục 11 là gợi ý. Muốn dựng lại từ đầu một màn thì dựng.
- **Thêm màn mới** phục vụ luồng đang có (chi tiết sự kiện, hồ sơ, onboarding, báo cáo phụ huynh…).
- **Hệ chuyển động và chuyển cảnh**, miễn tôn trọng mục 12 và không làm chậm máy yếu.
- **Chất liệu và hoa văn** — nền, viền, kết cấu, hình minh hoạ (xem mục 16 để lấy ý tưởng).
- **Mở rộng bảng màu** theo quy tắc ở 3.1.
- **Thư viện mới** theo quy tắc ở mục 4.
- **Cấu trúc thư mục `lib/`**, tên widget, cách tách file.
- **Bỏ qua một gợi ý trong tài liệu này** nếu có lý do tốt hơn — ghi lý do vào commit.

### 1.3 Thước đo cuối cùng

Khi phân vân giữa hai phương án, chọn phương án thắng ở ba câu này, theo thứ tự:

1. **Một học sinh lớp 8 mở app lần đầu có hiểu ngay phải làm gì không?**
2. **Phụ huynh nhìn vào có thấy đáng 39.000đ/tháng không?** — họ trả tiền, mà hiện app
   chưa có gì nói với họ.
3. **Chiếu lên máy chiếu trong 5 phút demo có gây được ấn tượng không?**

Đẹp mà rối thì thua. Đúng chuẩn mà nhạt cũng thua.

---

## 2. Hiện trạng — 16 lỗi đã quan sát trực tiếp

Đây không phải phỏng đoán: đã chạy app web thật với dữ liệu seed và chụp từng màn.

### Nhóm A — Kiến trúc điều hướng

**L1. Thanh tab dưới là tab giả.**
`AppBottomNav` chỉ điều hướng thật ở Dashboard (`dashboard_screen.dart:151-160`).
Ở ba màn còn lại, bấm **bất kỳ** tab nào cũng chỉ `Navigator.maybePop`:

- `timeline_screen.dart:66`
- `ar_museum_screen.dart:70`
- `chat_list_screen.dart:69`

Hậu quả thật: đang ở Timeline, bấm "Sages" → về Dashboard chứ không sang Chat.

**L2. Chỉ báo tab active sai.** Dashboard đặt `current: 0`, mà 0 là "Timeline". Nên mở app
lên đã thấy tab Timeline sáng dù đang ở Dashboard. Dashboard **không có** tab của riêng nó.

**L3. Quiz không có thanh tab.** `quiz_map_screen.dart` và `quiz_play_screen.dart` không
gắn `AppBottomNav`, trong khi Museum/Chat/Timeline thì có. Khung màn hình nhảy khi chuyển.

### Nhóm B — Hệ màu và kiểu chữ

**L4. Ba bảng màu đá nhau trong cùng một app.**

| Vùng | Màu đang dùng | Ở đâu |
|---|---|---|
| Kem · đỏ son · vàng (đúng) | `#FDF9F4` `#BA2323` `#D4AF37` | Dashboard, Timeline, Museum |
| Navy lạc điệu | `#1A1A2E` | chip lọc (`app_scaffold.dart:80`), hero card Chat list |
| Xám lạnh lạc điệu | `#2C2C3E` | thẻ chiến dịch Quiz map, 4 ô đáp án Quiz play |

Nhìn liền mạch thì Quiz và Chat list như của một app khác.

**L5. App không dùng font thương hiệu.** `theme.dart` không đặt `fontFamily` → toàn bộ app
chạy Roboto mặc định, trong khi bộ nhận diện quy định Playfair Display (tiêu đề) ·
Montserrat (nhãn) · Inter (nội dung). Slide và app không khớp nhau.

**L6. Chữ nghiêng trên nút bấm.** `FontStyle.italic` xuất hiện 11 chỗ, gồm mọi nút CTA
chính (`theme.dart:123`, `login_screen.dart:101,115,177,247`,
`register_screen.dart:118,132,165,232`, `chat_screen.dart:475`). Chữ đậm + nghiêng + nền
gradient cam là tổ hợp khó đọc, và bộ nhận diện không có kiểu nghiêng.

**L7. Hai màu đỏ song song.** `red = #C0392B` và `redDeep = #BA2323` dùng lẫn lộn.
CLAUDE.md chốt đỏ son là `#BA2323`.

### Nhóm C — Nội dung và mật độ

**L8. Timeline phí một nửa chiều ngang.** Bố cục zig-zag để thẻ so le hai bên, nửa còn lại
của mỗi hàng trống trơn. Bốn sự kiện phải cuộn gần ba màn hình.

**L9. Thẻ sự kiện trên Timeline không bấm được.** `_eventCard()` không có `onTap`
(`timeline_screen.dart:165`). Thẻ có ảnh, có nút play, có tag — nhìn như bấm được nhưng
bấm không ra gì. Đây cũng là lý do event `event_open` chưa có chỗ gọi.

**L10. Nút "Xem AR" nhưng chưa có AR.** `ar_museum_screen.dart` mời "Xem AR", thực tế mới
xoay được model 3D, chưa có AR qua camera.

**L11. Nút mic to nhất màn chat nhưng không hoạt động.** Trong `chat_screen.dart`, nút mic
tròn màu cam là phần tử nổi bật nhất thanh nhập liệu, mà chỉ là UI — bấm không ghi âm.

**L12. Chuỗi hardcode sai dữ liệu.**
- `quiz_map_screen.dart:184` — tên người chơi ghi cứng `'Minh Anh'`, hiện cả khi đang là khách.
- `dashboard_screen.dart:287` — thẻ "Tiếp tục học" ghi cứng `'Chiến dịch Điện Biên Phủ'`,
  trong khi nội dung của kỳ này là mô-đun *Hào khí Đại Việt* (Bạch Đằng 938 · 1288,
  Lam Sơn 1428, Quang Trung 1789, Trống đồng Đông Sơn).

**L13. Ảnh minh hoạ rỗng khắp nơi.** `thumbnailUrl` được parse trong
`lib/data/models.dart:23,105` nhưng **không màn nào dùng**. Mọi thumbnail hiện chỉ là một
icon xám trên nền gradient — Timeline, Dashboard, Museum đều vậy.

**L14. Khoảng trống lớn ở màn ít dữ liệu.** Chat list (1 nhân vật + 1 thẻ khoá), Quiz map
(1 chiến dịch), Quiz play (nửa dưới trống), Login (nội dung dồn giữa, không logo) — tất cả
để lại 40–60% màn hình trống.

### Nhóm D — Chi tiết

**L15. Trộn Anh–Việt.** Cần Việt hoá: `Sign In`, `Need An Account? Sign Up`,
`Timeline · Museum · Quest · Sages · Profile`, `3D Cinema`, `AI Chat`, `FEATURED`,
`0 Day Streak`, `Level`, `XP`, `Mastery`, `0 pts`.

**L16. Thanh audio hiện cả khi chưa phát**, kèm sóng âm tĩnh vẽ sẵn — trông như đang có
audio trong khi chưa có gì.

---

## 3. Design tokens — nguồn duy nhất

Viết lại `lib/core/theme.dart`. Đây là bảng chốt, **không tự thêm màu ngoài bảng**.

### 3.1 Màu

```dart
// NỀN
bg          #FDF9F4   // kem chủ đạo, nền mọi màn
bgAlt       #FBF3E6   // kem đậm — nền chip không active, vùng phân đoạn
card        #FFFFFF   // mặt thẻ
border      #EDE0CF   // viền thẻ, đường phân cách
divider     #F0E6D8   // đường kẻ mảnh trong thẻ

// ĐỎ SON — màu chính
red         #BA2323   // header, thẻ nổi bật, nhấn mạnh   (BỎ #C0392B)
redDark     #7A2218   // trạng thái nhấn, chữ trên nền nhạt
redDeepest  #3A140E   // NỀN TỐI DUY NHẤT — thay toàn bộ navy và xám lạnh

// VÀNG
gold        #D4AF37   // viền trang trí, biểu tượng
goldBright  #FDD141   // chữ/biểu tượng trên nền đỏ, tab đang chọn

// CAM — chỉ dành cho hành động chính
cta         #E67E22
ctaLight    #F39C12

// CHỮ
ink         #2B1410   // chữ chính trên nền kem
inkSoft     #7C5A4A   // chữ phụ
inkMuted    #A08877   // chú thích, placeholder
onRed       #FBF3E6   // chữ trên nền đỏ

// TRẠNG THÁI
success     #1E8449   // đáp án đúng  (đậm hơn #27AE60 cũ để đạt tương phản)
danger      #BA2323   // đáp án sai — dùng lại đỏ son
```

**Quy tắc thay màu lạc điệu (L4):**
- Mọi `AppColors.navy` và `AppColors.surfaceDark` → `redDeepest #3A140E`.
- **Xoá hẳn hai hằng `navy` và `surfaceDark` khỏi `theme.dart`** để không ai dùng lại.
- Chip lọc **không** active: nền `bgAlt`, viền `border`, chữ `inkSoft` — *không* dùng nền tối.
- Chip lọc active: nền `goldBright`, chữ `ink`.

**Được mở rộng bảng màu**, với ba điều kiện:
1. Màu mới phải **cùng gia đình sắc độ** với bảng trên — ngả ấm (đỏ, cam, vàng, nâu, kem).
   Một sắc xanh lá trầm kiểu sơn mài thì được; xanh dương lạnh thì không, vì đó chính là
   thứ đang làm Quiz lạc điệu.
2. Khai trong `theme.dart` như một hằng có tên, **không rải mã hex trong màn hình**.
3. Đạt tương phản WCAG AA với nền nó nằm lên.

Cụ thể, cứ thêm nếu cần: các nấc trung gian của đỏ và kem, một sắc mực nâu cho đường kẻ,
màu phủ (overlay) cho ảnh. Bảng ở trên là **xương sống, không phải hàng rào**.

**Bắt buộc kiểm tương phản.** Mọi cặp chữ/nền phải đạt WCAG AA (4.5:1 chữ thường,
3:1 chữ ≥ 18px hoặc ≥ 14px đậm). Cặp cần kiểm kỹ: `goldBright` trên `red`,
`inkMuted` trên `bg`, chữ trắng trên `cta`.

### 3.2 Kiểu chữ

Ba họ font, **nhúng file `.ttf` vào `assets/fonts/`** — xem mục 4 để biết vì sao không
tải qua mạng.

| Vai trò | Font | Dùng ở đâu |
|---|---|---|
| Tiêu đề | Playfair Display 700 | Tên màn hình, tiêu đề thẻ lớn, số liệu nổi bật |
| Nhãn | Montserrat 600 | Nhãn nút, chip, tab, tag |
| Nội dung | Inter 400/500/600 | Toàn bộ phần còn lại |

Thang cỡ chữ (đặt trong `TextTheme`, màn hình gọi qua `Theme.of(context).textTheme`,
**không hardcode `TextStyle` rải rác** như hiện nay):

```
displayLarge   32/1.15  Playfair 700   số liệu dẫn đầu
headlineMedium 24/1.2   Playfair 700   tiêu đề màn hình
titleLarge     19/1.25  Playfair 700   tiêu đề thẻ
titleMedium    16/1.3   Inter 600      tiêu đề mục
bodyLarge      15/1.5   Inter 400      nội dung chính
bodyMedium     14/1.5   Inter 400      nội dung phụ
labelLarge     14/1.2   Montserrat 600 chữ trên nút
labelSmall     12/1.2   Montserrat 600 chip, tag, nhãn tab
```

**Cấm `FontStyle.italic` trên nút và nhãn.** Chỉ được dùng nghiêng cho trích dẫn lời nhân
vật lịch sử (ví dụ câu giới thiệu trong thẻ vĩ nhân).

### 3.3 Hình khối

```
Bo góc:    thẻ 14  ·  nút 12  ·  chip 999  ·  ô nhập 12  ·  bảng/sheet 20 (chỉ bo trên)
Khoảng:    thang 4 — dùng 4, 8, 12, 16, 20, 24, 32
Lề màn:    16 hai bên
Đổ bóng:   một mức duy nhất — y+2, blur 8, đen 6%. BỎ mọi bóng gắt kiểu blur 16 alpha 35%
Viền:      1px màu border. Không viền + bóng cùng lúc trên một thẻ
Chiều cao: nút chính 52 · ô nhập 52 · vùng bấm nhỏ nhất 44×44
```

---

## 4. Thư viện được phép

**Được thêm:**

| Gói | Dùng để | Ghi chú |
|---|---|---|
| `go_router` | Điều hướng shell + URL đẹp trên web | `/timeline`, `/chat`, `/quiz`… thay vì luôn `/#` |
| `cached_network_image` | Ảnh thumbnail có cache + placeholder | Sửa L13 |
| `shimmer` | Khung xương lúc tải | Sửa mục 8.2 |

**Được thêm gói khác ngoài bảng**, nếu đạt cả bốn:
1. Còn được bảo trì (có bản phát hành trong 12 tháng qua) và **chạy được trên Flutter web**
   — nhiều gói native lặng lẽ hỏng ở web, mà web là nền tảng duy nhất đang chạy.
2. Không kéo theo phụ thuộc nặng, không đòi cấu hình riêng cho Android/iOS.
3. `flutter build web --release` vẫn chạy và `flutter test` vẫn xanh sau khi thêm.
4. Ghi một dòng lý do vào `pubspec.yaml` ngay cạnh gói đó.

Gợi ý những gói hợp việc này: `flutter_animate` (chuyển động khai báo, gọn),
`flutter_svg` (hoa văn vector), `confetti` (ăn mừng khi hoàn thành chiến dịch),
`google_fonts` (chỉ ở chế độ nhúng — đọc đoạn dưới).

**Vẫn không nên thêm:** UI kit bên thứ ba áp đặt phong cách riêng (`getwidget`,
`flutter_neumorphic`…) vì chúng ghi đè bộ nhận diện; và state management mới khi
`provider` đã có sẵn.

**Về font — đọc kỹ:** *không* dùng `google_fonts` ở chế độ tải runtime. Nó kéo font từ
`fonts.gstatic.com` lúc chạy; mạng hội trường chậm hoặc chặn là buổi demo tuần 10 hiện
font hệ thống, sai hẳn nhận diện. Tải sẵn file `.ttf` về `assets/fonts/`, khai trong
`pubspec.yaml`, không phụ thuộc mạng. Nếu vẫn muốn dùng gói `google_fonts` thì bắt buộc
`GoogleFonts.config.allowRuntimeFetching = false` **và** nhúng file.

Đã có sẵn trong `pubspec.yaml`, cứ dùng: `provider`, `shared_preferences`, `http`,
`audioplayers`, `web`, `video_player`, `model_viewer_plus`.

---

## 5. Kiến trúc điều hướng mới

### 5.1 Sáu tab, một shell

Điều hướng chính dùng một shell giữ 6 tab bằng `IndexedStack`, để trạng thái cuộn và bộ lọc
của từng tab được giữ lại khi chuyển qua lại.

| # | Tab | Nhãn tiếng Việt | Màn gốc |
|---|---|---|---|
| 0 | Trang chủ | **Trang chủ** | `DashboardScreen` |
| 1 | Dòng thời gian | **Dòng thời gian** | `TimelineScreen` |
| 2 | Đấu trường | **Đấu trường** | `QuizMapScreen` |
| 3 | Vĩ nhân | **Vĩ nhân** | `ChatListScreen` |
| 4 | Bảo tàng | **Bảo tàng** | `ArMuseumScreen` |
| 5 | Tài khoản | **Tài khoản** | `ProfileSettingsScreen` |

Tab **Tài khoản** hiển thị hồ sơ người học, cài đặt ứng dụng, trợ giúp và quản lý phiên đăng nhập.
Nút avatar trên Trang chủ mở cùng tab này.

**Yêu cầu bắt buộc:**
- Chuyển tab giữ nguyên vị trí cuộn và bộ lọc của tab cũ (dùng `IndexedStack`).
- Tab đang mở phải sáng đúng ở mọi màn, kể cả màn con.
- Xoá sạch mọi `onTap: (i) => Navigator.maybePop(context)` — sau khi làm xong, lệnh
  `grep -rn "maybePop" lib/` không được trả về dòng nào trong ngữ cảnh thanh tab.
- Màn con (Chat với một vĩ nhân, Quiz đang chơi, Chi tiết sự kiện) ẩn thanh tab và hiện nút quay lại.
### 5.2 Màn chi tiết sự kiện — màn mới

Sửa L9: thẻ trên Timeline phải bấm được, mở `EventDetailScreen` mới
(`lib/features/timeline/event_detail_screen.dart`).

Nội dung màn: ảnh bìa · năm và triều đại · tóm tắt · và **các lối đi tiếp** tuỳ theo
trường `features` của sự kiện (`cinematic,ar,chat,quiz`):
- có `quiz` → nút "Làm bài" mở thẳng `QuizPlayScreen` của sự kiện đó
- có `chat` → nút "Hỏi vĩ nhân"
- có `cinematic` → chỗ đặt trình phát video (**để trống có chủ đích**, xem mục 10)

Ngay khi màn này mở, gọi:
```dart
Analytics.instance.log(Ev.eventOpen, target: event.slug);
```
Đây là event đã có sẵn trong danh mục nhưng chưa ai gọi.

---

## 6. Chế độ trình chiếu

Cho buổi demo tuần 10 chiếu máy chiếu. Hiện `MobileFrame` khoá cứng 430px, chiếu lên màn
lớn thành một dải hẹp giữa nền kem.

**Yêu cầu:**
- Giữ nguyên khung điện thoại cho người dùng thường (mặc định không đổi gì).
- Bật chế độ trình chiếu bằng **query param `?present=1`** trên URL — cách này tiện nhất
  khi chiếu, không phải bấm mò trên sân khấu. Kèm một nút nhỏ góc dưới phải để bật/tắt.
- Khi bật: khung điện thoại phóng theo chiều cao cửa sổ (giữ đúng tỷ lệ, tối đa 2×), nền
  quanh khung chuyển sang `redDeepest` để hình nổi bật, ẩn nút bật/tắt sau 3 giây không
  chạm.
- Không được đụng vào bố cục bên trong khung — chỉ phóng to. Bố cục phải giống hệt lúc
  chạy trên điện thoại thật, nếu không thì demo không phản ánh sản phẩm.

Đặt trong `lib/core/widgets/mobile_frame.dart`, giữ nguyên tên widget.

---

## 7. Thư viện thành phần

Tạo `lib/core/widgets/` các thành phần dùng lại, thay cho việc mỗi màn tự dựng như hiện nay.

Đây là **sàn tối thiểu, không phải trần**. Cần thêm thành phần nào thì cứ thêm; đổi tên
hay gộp/tách khác đi cũng được, miễn không còn cảnh mỗi màn tự chế một kiểu thẻ và nút
như hiện tại.

| Widget | Thay cho | Yêu cầu |
|---|---|---|
| `AppButton` | `CtaButton` | 3 biến thể: `primary` (gradient cam), `secondary` (viền đỏ, nền trong), `ghost` (chỉ chữ). Có trạng thái `loading` và `disabled`. **Không nghiêng.** |
| `AppCard` | các `Container` rải rác | Nền `card`, viền `border`, bo 14, một mức bóng |
| `SectionHeader` | tiêu đề mục ở Dashboard/Museum | Tiêu đề + nút "Xem tất cả" tuỳ chọn |
| `FilterPill` | bản navy hiện tại | Theo quy tắc màu ở 3.1 |
| `StatTile` | 3 ô Level/XP/Mastery | Nhãn tiếng Việt + số + biểu tượng |
| `EmptyState` | (chưa có) | Biểu tượng + một câu giải thích + một hành động. Xem 8.1 |
| `LoadingSkeleton` | vòng xoay hiện tại | Khung xương theo hình dạng nội dung sắp hiện |
| `ErrorState` | thông báo lỗi rải rác | Câu tiếng Việt không kỹ thuật + nút "Thử lại" |
| `CoverImage` | thumbnail rỗng | Nhận `thumbnailUrl`, có placeholder và fallback. Sửa L13 |

---

## 8. Trạng thái rỗng, tải, lỗi

Đây là phần đang thiếu hẳn và là nguyên nhân chính của L14.

### 8.1 Rỗng
Mỗi danh sách rỗng phải có `EmptyState` với câu tiếng Việt cụ thể, **không** để trắng:

| Màn | Khi nào | Câu gợi ý |
|---|---|---|
| Đấu trường | Chưa có chiến dịch mở khoá | "Chưa có chiến dịch nào mở. Học một mốc lịch sử ở Dòng thời gian để mở khoá." |
| Vĩ nhân | Danh sách trống | "Chưa có vĩ nhân nào. Kéo xuống để tải lại." |
| Bảo tàng | Không có hiện vật khớp bộ lọc | "Không có hiện vật nào thuộc nhóm này." |
| Trang chủ | Chưa học gì | "Bạn chưa bắt đầu mốc nào. Chọn một trận đánh để vào học." |

**Thẻ khoá** ("Mở khoá ở Cấp 2") hiện chiếm một khối xám lớn. Thu lại thành một dòng gọn,
có biểu tượng ổ khoá và ghi rõ **cần làm gì** để mở, thay vì chỉ nói mức cấp.

### 8.2 Đang tải
Thay `CircularProgressIndicator` giữa màn bằng khung xương đúng hình dạng nội dung.
Lý do thực tế: backend chạy Render gói free, **lần gọi đầu mất 30–50 giây** do server
đang ngủ. Một vòng xoay đứng im nửa phút thì người dùng tưởng hỏng.

Kèm theo: nếu quá **8 giây** chưa có dữ liệu, hiện thêm dòng chữ nhỏ
"Máy chủ đang khởi động, chờ một chút…". Đây là ràng buộc thật của hạ tầng, phải nói với
người dùng chứ không giấu.

### 8.3 Lỗi
Câu chữ **phi kỹ thuật**, đúng như quy ước của nhóm: viết "Chưa lưu được điểm của bạn"
chứ không viết "submit trả 401". Luôn có nút "Thử lại".

---

## 9. Không được phá hệ đo lường

Hệ đo lường vừa gắn xong ngày 15/09. Thay UI là lúc dễ vô tình xoá nhất — mất một lời gọi
là tuần 10 thiếu số của cả một tính năng.

**12 lời gọi phải còn nguyên sau khi làm xong:**

| File | Event |
|---|---|
| `lib/main.dart` | `appOpen` |
| `lib/features/auth/auth_service.dart` | `loginSuccess`, `signupSuccess` |
| `lib/features/auth/register_screen.dart` | `signupStart` |
| `lib/features/timeline/timeline_screen.dart` | `timelineView` |
| `lib/features/quiz/quiz_play_screen.dart` | `quizStart`, `quizSubmit` |
| `lib/features/quiz/quiz_result_screen.dart` | `quizResultView` |
| `lib/features/chat/chat_screen.dart` | `chatOpen`, `chatMessageSent`, `chatVoicePlay` |
| `lib/features/ar_museum/ar_museum_screen.dart` | `arOpen` |

**Phải thêm mới:**

| Chỗ | Event | Ghi chú |
|---|---|---|
| `EventDetailScreen` mở ra | `Ev.eventOpen` + `target: slug` | Màn mới ở 5.2 |

Danh mục tên event nằm ở `lib/core/analytics.dart` (`class Ev`) và phải khớp
`backend/app/services/analytics.py` (`EVENT_NAMES`) — **không đổi tên nào**, không thêm
tên mới ở phía Flutter mà không sửa backend (backend lặng lẽ bỏ tên lạ).

Chi tiết cách hoạt động: `docs/DO_LUONG.md`.

---

## 10. Giới hạn về tính năng

Đây là ranh giới **chức năng**, không phải ranh giới sáng tạo. Giao diện cho những thứ
dưới đây thì cứ thiết kế thoải mái — chỉ đừng làm phần lõi kỹ thuật của chúng, và đừng
để nút bấm hứa điều chưa xảy ra (R8).

| Việc | Được làm đến đâu |
|---|---|
| Trình phát video cinematic | **Thiết kế đầy đủ chỗ đặt** trong màn chi tiết sự kiện — khung tỉ lệ 16:9, ảnh bìa, nút phát, trạng thái "sắp có". Không gắn `video_player` thật. |
| AR qua camera | Đổi "Xem AR" → **"Xem mô hình 3D"** (L10). Phần xoay 3D đang chạy thì cứ làm đẹp thêm. |
| Nút mic trong chat | Ghi âm chưa làm. Hạ xuống thứ yếu, hoặc bỏ, hoặc **để lại kèm nhãn "sắp có"** — miễn là bấm vào không im lặng không phản hồi (L11). |
| Màn Premium / thanh toán | **Được dựng màn giới thiệu gói** (nội dung: 39.000đ/tháng, quyền lợi) và gắn hai event `premium_view` / `premium_cta_click` đang chờ sẵn. Nút mua thì dẫn tới màn "sắp mở", không làm luồng thanh toán. |
| Nội dung lịch sử | Lấy từ API. **Không tự viết thêm sự kiện, nhân vật hay câu quiz mới** — sai một chi tiết sử trong app dạy sử là hỏng nặng hơn xấu một cái nút. Cần nội dung thì hỏi nhóm. |
| Backend, schema | Không đụng (R1, R2). |

---

## 11. Từng màn — vấn đề cần giải

> Mục này liệt kê **vấn đề đã quan sát được** ở mỗi màn, kèm một cách giải khả dĩ. Cách
> giải là gợi ý; vấn đề mới là thứ bắt buộc phải xử lý. Nghĩ ra cách hay hơn thì cứ làm,
> miễn vấn đề biến mất. Mục 16 có thêm ý tưởng cho từng màn.

### 11.1 Đăng nhập / Đăng ký
- Thêm logo (`assets/brand/logo.png`) và một câu định vị sản phẩm phía trên form — hiện
  màn trống trơn, không nói được đây là app gì.
- Việt hoá: "Đăng nhập", "Chưa có tài khoản? Đăng ký", "Xem thử không cần đăng nhập".
- Bỏ chữ nghiêng ở nút (L6).
- Lỗi hiển thị ngay dưới ô nhập tương ứng, không phải một dòng đỏ chung chung.
- Giữ nguyên lối "Xem thử không cần đăng nhập" — đây là đường demo chính.

### 11.2 Trang chủ
- Bỏ hardcode "Chiến dịch Điện Biên Phủ" (L12), lấy mốc học dở thật từ `/me/progress`.
  Chưa có tiến độ thì hiện `EmptyState` ở 8.1.
- Việt hoá 3 ô chỉ số: `Level` → **Cấp**, `XP` → **Điểm**, `Mastery` → **Thông thạo**;
  `0 Day Streak` → **"Chuỗi 0 ngày"**.
- Lưới "Khám Phá": nhãn tiếng Việt — "Phim 3D", "Bảo tàng 3D", "Hỏi vĩ nhân", "Đấu trường".
- Ảnh bìa thẻ "Tiếp tục học" dùng `CoverImage` với `thumbnailUrl` thật (L13).

### 11.3 Dòng thời gian
- **Bỏ bố cục zig-zag** (L8). Dùng một cột: dải thời gian mảnh bên trái, thẻ chiếm gần hết
  chiều ngang bên phải. Bốn sự kiện phải nằm gọn trong khoảng một màn rưỡi.
- **Thẻ bấm được** → mở `EventDetailScreen` (L9), kèm hiệu ứng chạm.
- Ảnh bìa thật qua `CoverImage`.
- Tag tiếng Việt: `3D Cinema` → **Phim 3D**, `AI Chat` → **Hỏi vĩ nhân**, `Quiz` → **Quiz**.
- Chip lọc theo quy tắc màu mới (bỏ navy).

### 11.4 Đấu trường (Quiz map + Quiz play)
- **Bỏ toàn bộ thẻ xám lạnh** `#2C2C3E` (L4) → nền `card` trắng có viền, hoặc `redDeepest`
  nếu cần thẻ tối.
- Bỏ hardcode `'Minh Anh'` (L12) — lấy tên thật, khách thì hiện "Khách".
- Gắn thanh tab dưới cho Quiz map (L3). Quiz **đang chơi** thì ẩn tab (5.1).
- Bốn ô đáp án: nền trắng, viền, chữ `ink`. Chọn đúng → viền + nền nhạt `success`;
  chọn sai → `danger`. **Không dùng màu làm tín hiệu duy nhất** — kèm biểu tượng ✓ / ✕.
- Đồng hồ đếm ngược: dưới 5 giây đổi sang `danger` **và** rung nhẹ, không chỉ đổi màu.
- Việt hoá `0 pts` → **"0 điểm"**.
- Lấp nửa dưới trống của Quiz play: đưa khối câu hỏi và đáp án giãn đều theo chiều cao.

### 11.5 Vĩ nhân (Chat list + Chat)
- Hero card đầu màn: bỏ navy → `redDeepest` hoặc `red`.
- `FEATURED` → **"Nổi bật"**.
- Thẻ khoá gọn lại theo 8.1.
- Trong phòng chat: bong bóng người dùng và bong bóng vĩ nhân phải **khác nhau rõ** về nền
  và căn lề; hiện chỉ thấy bong bóng vĩ nhân màu đỏ.
- Thanh audio **chỉ hiện khi có audio** (L16), sóng âm tĩnh thì bỏ hoặc thay bằng thanh
  tiến trình thật.
- Nút mic hạ xuống thứ yếu, nút gửi thành hành động chính (L11).
- Giữ nguyên toàn bộ logic streaming và TTS — chỉ đụng phần nhìn.

### 11.6 Bảo tàng
- "Xem AR" → **"Xem mô hình 3D"** (L10).
- Lưới bộ sưu tập: khi chỉ có 1–2 hiện vật thì đừng để ô trống nửa hàng — dùng danh sách
  ngang hoặc thẻ rộng hết hàng.
- Ảnh bìa thật qua `CoverImage`.
- Giữ nguyên `turntable_viewer.dart` và `glb_viewer` — phần xoay 3D đang chạy được.

---

## 12. Khả năng tiếp cận

- Vùng bấm nhỏ nhất **44×44** — nhiều biểu tượng hiện dưới mức này.
- Không dùng màu làm tín hiệu duy nhất: đúng/sai, khoá/mở, tab active đều phải có thêm
  biểu tượng hoặc chữ.
- Chữ nhỏ nhất **12px**; nội dung chính từ 15px (người trả tiền là phụ huynh 35–50 tuổi).
- App phải dùng được khi hệ thống phóng cỡ chữ lên 130% mà không vỡ bố cục hay cắt chữ.
- Mọi biểu tượng chỉ-có-icon phải có `Semantics(label: ...)` tiếng Việt.

---

## 13. Tiêu chí nghiệm thu

Chạy được bằng lệnh, không tranh cãi cảm tính.

```bash
cd mobile

# 1. Không lỗi, không cảnh báo mới
C:\src\flutter\bin\flutter.bat analyze --no-fatal-infos

# 2. Toàn bộ test xanh (9 test)
C:\src\flutter\bin\flutter.bat test

# 3. Giữ đủ 13 lời gọi đo lường (12 cũ + eventOpen mới)
grep -rc "Analytics.instance.log" lib/ --include=*.dart | awk -F: '{s+=$2} END {print s}'
# phải >= 13

# 4. Sạch màu lạc điệu — cả 3 lệnh phải không ra kết quả
grep -rn "1A1A2E\|2C2C3E" lib/
grep -rn "AppColors.navy\|AppColors.surfaceDark" lib/
grep -rn "C0392B" lib/

# 5. Sạch chữ nghiêng trên nút
grep -rn "FontStyle.italic" lib/           # chỉ được còn ở trích dẫn lời nhân vật

# 6. Sạch tab giả
grep -rn "maybePop" lib/                   # không còn trong ngữ cảnh thanh tab

# 7. Sạch hardcode sai dữ liệu
grep -rn "Minh Anh\|Điện Biên Phủ" lib/    # không ra kết quả

# 8. Thumbnail đã được dùng
grep -rn "thumbnailUrl" lib/features/      # phải ra kết quả

# 9. Build web chạy được
C:\src\flutter\bin\flutter.bat build web --release --base-href /
```

### Số liệu gốc để đối chiếu

Đo lúc 15/09/2026, trước khi sửa. Cột phải là đích phải đạt.

| Lệnh đếm | Hiện tại | Sau khi xong |
|---|---|---|
| `Analytics.instance.log` | 12 | **≥ 13** |
| `1A1A2E\|2C2C3E` | 3 | **0** |
| `AppColors.navy\|AppColors.surfaceDark` | 3 | **0** |
| `C0392B` | 4 | **0** |
| `FontStyle.italic` | 11 | **≤ 2** (chỉ trích dẫn lời nhân vật) |
| `maybePop` | 3 | **0** trong ngữ cảnh thanh tab |
| `Minh Anh\|Điện Biên Phủ` | 2 | **0** |
| `thumbnailUrl` trong `lib/features/` | 0 | **> 0** |
| `flutter analyze` | 0 error · 0 warning · 55 info | **0 error · 0 warning** |
| `flutter test` | 9 xanh | **9 xanh** (hoặc hơn) |

**Nghiệm thu bằng mắt** — chụp màn hình 6 màn ở hai chế độ (khung điện thoại + trình
chiếu), đối chiếu:
- [ ] Không màn nào còn mảng navy/xám lạnh
- [ ] Thanh tab chuyển đúng màn ở **mọi** màn, tab active sáng đúng
- [ ] Bấm thẻ trên Dòng thời gian mở được màn chi tiết
- [ ] Không còn chữ tiếng Anh trong giao diện
- [ ] Màn ít dữ liệu không còn khoảng trống quá nửa màn hình
- [ ] `?present=1` phóng khung đúng tỷ lệ, bố cục bên trong không đổi

---

## 14. Thứ tự thực hiện

**Mỗi bước một commit riêng, chạy test trước khi sang bước sau.** Đừng gộp tất cả vào một
lần sửa khổng lồ — không ai review nổi và hỏng thì không biết hỏng ở đâu.

Thứ tự dưới đây tối ưu cho việc *không tự dẫm chân mình*: nền móng trước, bề mặt sau. Đổi
thứ tự được, miễn giữ nguyên nguyên tắc đó.

| Bước | Việc | Xong khi |
|---|---|---|
| 0 | **Chạy app hiện tại và tự đi hết các màn** trước khi sửa gì. Chốt hướng thiết kế, chọn ý từ mục 16, ghi lại lựa chọn | Có một ghi chú ngắn về hướng đã chọn |
| 1 | Design tokens: viết lại `theme.dart`, nhúng font, xoá `navy`/`surfaceDark`/`#C0392B` | Lệnh 4 và 5 ở mục 13 sạch. App vẫn chạy dù còn xấu |
| 2 | Thư viện thành phần (mục 7) — dựng widget, chưa thay màn | `flutter analyze` sạch |
| 3 | Kiến trúc điều hướng (mục 5) + màn chi tiết sự kiện | Lệnh 6 sạch, bấm thẻ Timeline mở được màn mới |
| 4 | Làm lại từng màn (mục 11 + ý đã chọn ở mục 16): Trang chủ → Dòng thời gian → Đấu trường → Vĩ nhân → Bảo tàng → Đăng nhập | Ảnh chụp từng màn |
| 5 | Trạng thái rỗng/tải/lỗi (mục 8) | Thử ngắt mạng, thử tài khoản mới tinh |
| 6 | Chế độ trình chiếu (mục 6) + rà khả năng tiếp cận (mục 12) | Toàn bộ mục 13 |
| 7 | Màn mới nếu còn thời gian: báo cáo phụ huynh, nếm thử trước đăng ký, giới thiệu Premium | Ảnh chụp + event đo lường đã gắn |

**Cách chạy app để tự kiểm tra:**

```bash
# Backend, cửa sổ 1 — CORS phải trỏ đúng cổng web, xem mục 15
cd backend
DATABASE_URL="sqlite:///./demo.db" SECRET_KEY=dev CORS_ORIGINS="http://localhost:8099" \
  python -m app.db.seed
DATABASE_URL="sqlite:///./demo.db" SECRET_KEY=dev CORS_ORIGINS="http://localhost:8099" \
  uvicorn app.main:app --port 8000

# Web, cửa sổ 2 — chạy lệnh build bằng PowerShell, không phải Git Bash
cd mobile
C:\src\flutter\bin\flutter.bat build web --release --base-href / --dart-define=API_BASE_URL=http://127.0.0.1:8000
cd build/web && python -m http.server 8099
```

Dữ liệu seed có 4 sự kiện, 2 vĩ nhân (1 bị khoá), 1 hiện vật, 3 câu quiz — **đúng mức ít
ỏi này là điều kiện thử tốt nhất** cho trạng thái rỗng ở mục 8.

---

## 15. Cạm bẫy đã biết

Những chỗ đã mất thời gian một lần rồi, đừng vấp lại.

**Font serif và dấu tiếng Việt.** Georgia và `ui-serif` **không có glyph** cho ký tự tiếng
Việt dựng sẵn (ố, ế, ấ, ề). Trình duyệt lấy chữ nền một font, mượn dấu font khác, ra kết
quả kiểu "Sô ́ liệu" — dấu rời hẳn khỏi chữ. Không phải lỗi encoding. Fallback serif phải
là `"Noto Serif", "Times New Roman"`. Đã vấp khi làm dashboard đo lường.

**Timer sống sót qua widget test.** `Analytics` gom event rồi gửi sau 2 giây. Widget test
nào dựng `HistoriAIApp` mà không gọi `Analytics.instance.datLaiChoTest()` trong `setUp()`
sẽ hỏng với lỗi "A Timer is still pending". Xem `test/widget_test.dart`.

**Splash quay vô hạn.** Màn splash có hào quang animation lặp mãi, nên `pumpAndSettle` sẽ
treo. Test phải bơm khung theo mốc thời gian — xem cách làm sẵn trong `test/widget_test.dart`.

**Flutter không nằm trên PATH.** Luôn gọi đầy đủ `C:\src\flutter\bin\flutter.bat`.

**Git Bash nuốt dấu `/`.** `flutter build web --base-href /` chạy trong Git Bash bị đổi
thành đường dẫn Windows và báo lỗi. Chạy lệnh build bằng PowerShell.

**CORS.** Backend đang để `CORS_ORIGINS=*` kèm `allow_credentials=True` — tổ hợp này bị
trình duyệt từ chối theo spec. Khi chạy web local trỏ vào backend local, đặt
`CORS_ORIGINS=http://localhost:<cổng>` cụ thể.

**Render ngủ.** Backend gói free ngủ sau 15 phút, request đầu mất 30–50 giây. Đây là lý do
mục 8.2 bắt buộc có khung xương và dòng chữ báo chờ.

---

## 16. Ngân hàng ý tưởng

Đây là **thực đơn, không phải danh sách việc**. Chọn cái nào thấy đáng, bỏ cái nào thấy
gượng, nghĩ ra cái tốt hơn thì càng quý. Mỗi ý có ghi công sức ước lượng (S / M / L) và
lý do nó đáng làm.

Nguyên tắc xuyên suốt: **lấy chất liệu từ chính nội dung lịch sử đang dạy**, đừng mượn
phong cách app nước ngoài rồi dán màu đỏ vàng lên. Trống đồng, cọc Bạch Đằng, giấy dó,
dấu triện, bia tiến sĩ — kho hình ảnh này vừa đẹp vừa đúng chủ đề, và không app EdTech
nào khác có.

---

### 16.1 Bản sắc thị giác

**a) Hoa văn trống đồng làm kết cấu nền** · S
Nền kem hiện phẳng lì. Lấy mô-típ chim Lạc / vòng tròn đồng tâm trên mặt trống Đông Sơn,
vẽ SVG, đặt ở **độ mờ 3–5%** làm nền cho vùng header hoặc chân màn. Đủ để cảm thấy chất
Việt, không đủ để cản đọc. Trống đồng Đông Sơn vốn đã là một trong năm mốc nội dung.

**b) Dấu triện thay dấu tích** · S
Mốc đã học xong đóng một **con dấu triện vuông màu đỏ son** hơi lệch trục, như dấu đóng
trên văn bản cổ, thay cho dấu ✓ tròn quen thuộc. Rẻ, độc, và ăn ngay vào bảng màu.

**c) Cọc Bạch Đằng làm thanh tiến độ** · M
Thanh tiến độ vẽ như một hàng cọc gỗ cắm xuống nước, cọc sáng dần theo phần trăm. Gắn
thẳng với trận đánh mở đầu mô-đun. Dùng ở tiến độ mốc học và tiến độ quiz.

**d) Chất giấy dó cho thẻ nội dung** · S
Thay mặt thẻ trắng phẳng bằng một sắc kem có vân giấy rất nhẹ. Ấm hơn, hợp chủ đề hơn,
gần như không tốn gì.

**e) Khung tranh cho chân dung vĩ nhân** · M
Ảnh chân dung hiện là hình vuông bo góc. Đóng khung bằng đường viền vàng mảnh có góc
trang trí kiểu khung hoành phi. Nâng hẳn cảm giác trang trọng của phần Chat.

---

### 16.2 Dòng thời gian

**f) Mốc thế kỷ dính khi cuộn** · M
Khi cuộn, nhãn thế kỷ ("Thế kỷ X", "Thế kỷ XV") dính lại đầu màn rồi đẩy nhau đi. Người
học luôn biết mình đang ở đâu trong dòng lịch sử — đúng mục đích của một timeline, mà bản
zig-zag hiện tại không làm được.

**g) Dải sông chảy dọc thay đường kẻ** · M
Trục dọc hiện là một đường thẳng vàng. Vẽ thành dòng sông uốn nhẹ — sông Bạch Đằng là
mạch xuyên suốt mô-đun. Các mốc là bến đỗ trên sông.

**h) Mở thẻ thành màn chi tiết** · M
Dùng `Hero` để ảnh bìa trên thẻ nở ra thành ảnh đầu màn chi tiết. Flutter làm việc này rất
gọn, và nó khiến điều hướng có cảm giác liền mạch thay vì nhảy cóc.

**i) Chế độ "trục thời gian thu nhỏ"** · L
Nút thu toàn bộ 5 mốc về một màn duy nhất, dạng trục ngang nén lại. Hữu ích khi thuyết
trình: một hình cho thấy trọn mô-đun.

---

### 16.3 Chat với vĩ nhân — phần mạnh nhất của sản phẩm

**j) Ba thẻ câu hỏi gợi ý, luôn hiện** · S · **đáng làm nhất nhóm này**
Rào cản lớn nhất của học sinh trước ô chat trống là *không biết hỏi gì*. Hiện chỉ có một
gợi ý nằm ở màn danh sách. Đặt 3 thẻ câu hỏi ngay trên ô nhập, đổi theo ngữ cảnh sự kiện,
bấm là gửi luôn. Cải thiện tỉ lệ dùng thật sự, và đo được ngay bằng `chat_message_sent`.

**k) Lời vĩ nhân trên nền giấy sắc phong** · M
Thay bong bóng chat bo tròn bằng một khối nền giấy cổ có viền hoa văn mảnh. Lời người
dùng vẫn là bong bóng thường. Sự tương phản giữa "mình" và "người xưa" trở thành một phần
của trải nghiệm chứ không chỉ là căn trái–phải.

**l) Chân dung phản ứng theo trạng thái** · M
Lúc AI đang soạn câu trả lời, chân dung khẽ chuyển (thở nhẹ, mắt chớp, hoặc quầng sáng
vàng lan ra). Hiện chỉ có ba chấm nhấp nháy. Đây là khoảnh khắc chờ lâu nhất trong app —
đáng để làm cho dễ chịu.

**m) Đưa nguồn sử liệu lên thành điểm tin cậy** · S
Đã có sẵn `source_chip.dart` mà chưa nổi bật. Với phụ huynh, "AI nói có dẫn nguồn" là
khác biệt lớn so với một chatbot bịa. Cho chip nguồn một chỗ đứng đàng hoàng dưới mỗi câu
trả lời.

**n) Nút "Nghe kể" thay biểu tượng loa** · S
TTS tiếng Việt là thứ nhóm đã làm được và hiếm app nào có. Đừng giấu sau một icon loa nhỏ
— gọi thẳng là "Nghe ngài kể", đặt cạnh câu trả lời.

---

### 16.4 Game hoá — Đấu trường

**o) Bản đồ hành trình thay danh sách thẻ** · L · **ấn tượng nhất khi demo**
Quiz map hiện là danh sách thẻ dọc. Chuyển thành **con đường có các trạm nối nhau** như
hành trình, mỗi trạm là một chiến dịch, trạm chưa mở thì mờ. Học sinh hiểu ngay "đi hết
đường này là xong mô-đun". Đây là bố cục đã được chứng minh với đúng lứa tuổi này.

**p) Bảng vàng bia tiến sĩ cho màn kết quả** · M
Màn kết quả quiz dựng theo hình bia tiến sĩ Văn Miếu: tên người học khắc lên bia, điểm số
bên dưới. Vừa là phần thưởng, vừa dạy thêm một biểu tượng văn hoá. Ảnh chụp màn này chia
sẻ được — kênh lan truyền tự nhiên.

**q) Chuỗi ngày học thành ngọn đuốc** · S
"0 Day Streak" hiện là một chip cam nhạt nhoà. Đổi thành ngọn đuốc cháy, tắt dần nếu bỏ
lỡ. Cùng một dữ liệu, khác hẳn sức nặng cảm xúc.

**r) Huy hiệu triều đại sưu tầm** · M
Học xong mốc nào thì nhận huy hiệu triều đại đó (Ngô, Trần, Hậu Lê, Tây Sơn). Bộ sưu tập
hiện ở hồ sơ, ô trống thấy rõ. Động lực hoàn thành mạnh hơn nhiều so với một con số XP.

**s) Phản hồi tức thì khi trả lời** · S
Đáp án đúng: dấu triện đỏ đóng xuống, `+10 XP` bay lên. Sai: rung nhẹ, hiện ngay đáp án
đúng kèm một câu giải thích. Hiện đang lặng lẽ chuyển câu — mất trắng khoảnh khắc học
hiệu quả nhất.

**t) Đồng hồ đếm ngược thành nhịp trống trận** · M
Dưới 5 giây, viền màn hình đập theo nhịp. Nếu làm âm thanh thì một tiếng trống trận nhỏ —
kèm nút tắt tiếng, và mặc định **tắt**.

---

### 16.5 Phụ huynh — điểm mù lớn nhất hiện nay

Phụ huynh 35–50 tuổi là **người trả 39.000đ/tháng**, mà toàn bộ app hiện không có một màn
nào nói với họ. Đây là khoảng trống có giá trị kinh doanh cao nhất trong danh sách này.

**u) Màn "Tuần này con học gì"** · M · **đề xuất mạnh nhất cả tài liệu**
Một màn tóm tắt: số phút học, mốc đã xong, điểm quiz, chủ đề con hỏi nhiều nhất. Dữ liệu
**đã có sẵn** trong `/me/progress`, `/leaderboard` và bảng `analytics_events` — không cần
backend mới. Đây chính là thứ biến "app con chơi" thành "khoản đáng trả tiền".

**v) Thẻ khoe chia sẻ được** · M
Nút xuất một tấm thẻ vuông đẹp: "Con đã chinh phục Bạch Đằng 1288 · 9/10 điểm", theo bộ
nhận diện. Phụ huynh gửi Zalo cho ông bà. Kênh tăng trưởng rẻ nhất có thể có, và gắn
thẳng với chiến lược B2C.

**w) Màn giới thiệu Premium tử tế** · M
Hai event `premium_view` và `premium_cta_click` đang chờ sẵn trong danh mục đo lường mà
chưa có chỗ gọi. Dựng màn nói rõ 39.000đ/tháng được gì, viết cho phụ huynh đọc chứ không
phải học sinh. Nút mua dẫn tới "sắp mở" (mục 10).

---

### 16.6 Lần đầu mở app

**x) Nếm thử trước khi đăng ký** · M
Hiện mở app là đâm thẳng vào màn Sign In — người lạ không biết đây là app gì. Cho họ
**hỏi thử vĩ nhân một câu** hoặc **trả lời một câu quiz** ngay, rồi mới mời đăng ký để lưu
tiến độ. Lối "Xem thử không cần đăng nhập" đã có sẵn, chỉ là đang nằm khuất phía dưới.

**y) Màn đăng nhập phải nói được app này là gì** · S
Thêm logo, một câu định vị, và ảnh nền gợi chủ đề. Màn hiện tại trống trơn, không có gì
níu người ta ở lại.

---

### 16.7 Chuyển động

**z) Ba khoảnh khắc đáng đầu tư, chỉ ba** · M
Đừng rải animation khắp nơi. Dồn vào ba chỗ có sức nặng cảm xúc nhất:
1. Thẻ sự kiện nở ra thành màn chi tiết (ý h)
2. Dấu triện đóng xuống khi trả lời đúng (ý s)
3. Điểm XP đếm tăng ở màn kết quả

Mọi chuyển động khác giữ dưới 200ms và dùng đường cong chuẩn. Bắt buộc tôn trọng
`MediaQuery.disableAnimationsOf(context)` — có học sinh nhạy cảm với chuyển động.

---

### 16.8 Chế độ đêm — nếu còn thời gian

**aa) "Imperial Night"** · L
Học sinh học buổi tối. Một bản tối lấy nền nâu sẫm `#2B1410`, vàng hoàng gia nổi lên, đỏ
son giữ vai trò nhấn — nghe rất hợp với chủ đề, và bảng màu hiện có sẵn nguyên liệu.
Xếp cuối vì tốn công kiểm tương phản lại toàn bộ, và mốc tuần 10 quan trọng hơn.

---

### 16.9 Ba thứ đừng làm, dù nghe hấp dẫn

| Đừng | Vì sao |
|---|---|
| Hoa văn nền đậm quá 5% | Chữ tiếng Việt nhiều dấu, nền rối là mất chữ. Đo bằng tương phản, đừng đo bằng mắt. |
| Nhạc nền tự động phát | Học sinh hay mở app trong lớp hoặc thư viện. Nếu có âm thanh thì mặc định **tắt**. |
| Hiệu ứng 3D/parallax nặng ở màn danh sách | Máy học sinh phần lớn yếu. Đây là app web — mọi thứ chạy qua canvas, tụt khung hình rất nhanh. |

---

### 16.10 Nếu chỉ kịp làm năm thứ

Xếp theo tỉ lệ *giá trị / công sức*:

1. **(j)** Ba thẻ câu hỏi gợi ý trong chat — rẻ nhất, tác động thẳng vào tính năng mạnh nhất
2. **(u)** Màn "Tuần này con học gì" — chạm đúng người trả tiền, dữ liệu đã có sẵn
3. **(o)** Bản đồ hành trình cho Đấu trường — ăn hình nhất khi demo tuần 10
4. **(s)** Phản hồi tức thì khi trả lời quiz — rẻ, và cải thiện hiệu quả học thật sự
5. **(x)** Nếm thử trước khi đăng ký — gỡ rào cản lớn nhất ở lần mở app đầu tiên

---

## 17. Tài liệu liên quan

| File | Nội dung |
|---|---|
| `CLAUDE.md` (thư mục `EXE201/`) | Bối cảnh môn học, định hướng kinh doanh, quy ước viết |
| `docs/DO_LUONG.md` | Hệ đo lường — danh mục event, cách thêm event mới |
| `mobile/lib/core/theme.dart` | Bộ nhận diện hiện tại (sẽ viết lại ở bước 1) |
| `docs/3D_ASSET_GUIDE.md` | Quy ước asset 3D |
| `docs/DEPLOY.md` | Cách deploy |

**Về thiết kế: đừng hỏi, cứ quyết.** Chọn phương án bạn cho là tốt nhất, ghi lý do vào
commit, nhóm xem kết quả rồi góp ý sau. Vòng lặp đó nhanh hơn hỏi trước nhiều.

**Về hai thứ này thì phải hỏi nhóm:** nội dung lịch sử (sự kiện, nhân vật, câu quiz, số
liệu) và cam kết tính năng (nút nào hứa điều gì). Nói sai một chi tiết lịch sử trong sản
phẩm dạy sử thì hỏng nặng hơn là xấu một cái nút.
