# Audit trải nghiệm: app dùng có sướng không

Rà ngày 23/09/2026 trên bản đang chạy tại `historiai.anhzap.shop`, bằng cách
**ngồi bấm thật** — đăng nhập `kiemthu.quiz@anhzap.shop`, chơi trọn hai ván quiz
(một thua, một thắng), trò chuyện với Trần Hưng Đạo, xem thước phim, xoay cổ vật,
ngắt mạng giữa chừng, và thu nhỏ màn hình về 360 px.

Bản audit này **không lặp lại** `docs/AUDIT_SAN_SANG_PHAT_HANH.md` (hạ tầng, bảo
mật, dữ liệu, pháp lý). Ở đây chỉ nói về **cảm giác khi dùng**.

Mọi dòng dưới đây đều là thứ tôi tự nhìn thấy trên màn hình. Chỗ nào chỉ suy ra
từ mã, tôi ghi rõ.

---

## 1. Kết luận một dòng

**Chưa lên production thật được** — người mở app lần đầu bị **kẹt cứng ở màn
hướng dẫn** (bấm "Bắt đầu" hay "Bỏ qua" đều không đi đâu, phải tải lại trang mới
thoát); và xuyên suốt sản phẩm, app **làm xong việc rồi không nói gì** — thắng
quiz không reo, trả lời đúng không báo, bấm nút không phản hồi.

---

## 2. Bảng xếp hạng thiếu sót

Xếp theo *người dùng thật mất gì* chia cho *công bỏ ra*.

| # | Chỗ nào | Thấy gì | Đáng ra phải thế nào | Mức | Công |
|---|---|---|---|---|---|
| 1 | Hướng dẫn 4 trang, lần mở app đầu tiên | Bấm **"Bắt đầu"** (trang 4) hoặc **"Bỏ qua"** (trang 1): màn hình **đứng yên**. Chờ 4,5 giây, bấm 3 lần, vẫn nguyên trang cũ. Kiểm `localStorage` thì `flutter.da_xem_huong_dan_v1` **đã** được ghi `true` → nút có chạy, chỉ là không chuyển màn. Phải F5 mới ra được màn đăng nhập | Bấm xong là sang màn đăng nhập | 🔴 chặn | 15 phút |
| 2 | Hội thoại vĩ nhân → thẻ **Quang Trung** | Thẻ khoá, ghi *"Cần đạt Cấp 2 ở Đấu Trường để mở khoá"*. Tài khoản của tôi **đang là Cấp 2** (`/auth/me` trả `level: 2`, màn hình chính hiện "Cấp 2"). Thẻ vẫn khoá. Chạm vào: **không có gì xảy ra**, không rung, không báo | Đủ cấp thì mở; chưa đủ thì chạm vào phải nói còn thiếu bao nhiêu | 🔴 chặn | 30 phút |
| 3 | Đăng nhập sai mật khẩu | Hiện **"Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại."** Máy chủ thật ra trả câu đúng rồi: `{"detail":{"error":{"message":"Sai email hoặc mật khẩu"}}}` — app vứt đi vì bộ đọc lỗi chỉ hiểu `detail` dạng chuỗi/mảng, không hiểu dạng object (`core/api_client.dart:192-211`) | "Sai email hoặc mật khẩu" | 🔴 chặn | 20 phút |
| 4 | **Toàn app** — mọi thông báo dạng SnackBar | Thông báo **có trong cây trợ năng** nhưng **không hiện trên màn hình**: nó nằm dưới thanh điều hướng / ô nhập. Đo được: sau khi bấm "Xem lại hướng dẫn", chuỗi *"Đã bật lại chỉ dẫn…"* tồn tại trong cây từ mốc 450 ms tới 3000 ms, còn ảnh chụp cùng lúc thì **không thấy gì**. 7 chỗ trong mã dùng SnackBar → 7 chỗ người dùng tưởng nút chết | Thông báo phải nổi lên trên thanh điều hướng | 🔴 chặn | 30 phút (sửa 1 chỗ, hết cả 7) |
| 5 | Chat vĩ nhân, hỏi dồn | Chạm gợi ý 10 lần liên tiếp → **4–5 bong bóng trả lời rỗng tuếch**, trắng trơn, chỉ còn cái huy hiệu *"Đại Việt Sử Ký Toàn Thư"* bên dưới. Câu cuối **không có trả lời nào**. Chờ thêm 6 giây: vẫn rỗng. Máy chủ lúc đó trả 429 kèm câu rất hay — *"Con hỏi nhanh quá, ta chưa kịp ngẫm. Hãy chờ 16 giây rồi hỏi lại."* — app không dùng | Hiện đúng câu của máy chủ, kèm đếm ngược; hoặc khoá ô nhập khi đang chờ | 🔴 chặn | 1 giờ |
| 6 | Đấu trường — **trả lời đúng** | Chụp màn hình **120 ms** sau khi chạm: đã sang câu kế. Không ô xanh, không dấu tích, không chữ "Đúng rồi", không âm thanh | Một nhịp 300–500 ms tô xanh đáp án đúng | 🟠 nên sửa | 2 giờ |
| 7 | Đấu trường — **trả lời sai** | Y hệt: nhảy thẳng sang câu kế. Chỉ có một trái tim mờ đi ở góc trên. **Không nói sai ở đâu, không hiện đáp án đúng, không giảng gì cả.** Trong khi màn hướng dẫn hứa *"sai thì được giảng lại ngay"* và chỉ dẫn tại chỗ cũng hứa *"trả lời sai thì được giảng lại ngay tại chỗ"* | Tô đỏ đáp án đã chọn, tô xanh đáp án đúng, hiện lời giảng, có nút "Tiếp" | 🟠 nên sửa | 3 giờ |
| 8 | Màn kết quả quiz | Xem mục 3 bên dưới | | 🟠 nên sửa | 4 giờ |
| 9 | Đấu trường, sau khi chơi xong | Thắng 2 ván (+20 rồi +90), quay về bản đồ chiến dịch: **vẫn ghi "100 Điểm"**, thẻ Bạch Đằng 938 **không có dấu đã chinh phục, không có điểm cao nhất**. Máy chủ lúc đó đã là 210. Màn hình chính thì cập nhật đúng (210, 90%) | Bản đồ nạp lại khi quay về | 🟠 nên sửa | 30 phút |
| 10 | Bằng khen chia sẻ ("Sắc Ban Khắc Tên") | Ghi **"Tích luỹ 350 Điểm Công Đức Sử Học"**. Điểm thật của tôi là **210**. Số 350 viết cứng trong mã (`core/widgets/royal_edict_scroll.dart:534`). Đây là thứ học sinh chụp màn hình gửi vào nhóm lớp | Lấy điểm thật | 🟠 nên sửa | 10 phút |
| 11 | Bằng khen ("Sắc Ban Khởi Thắng") | Ghi *"kế sách bày binh chuẩn xác **đạt điểm tối đa**!"* trong khi tôi được **9/10** | Câu chữ đổi theo kết quả | 🟠 nên sửa | 20 phút |
| 12 | Nút **"Sao Chép Vinh Quy"** | Chạm: **không có gì cả**. Móc `navigator.clipboard.writeText` mới thấy nó **có** chép thật (chuỗi *"Ta là Sĩ tử Đại Việt, đã đỗ đạt danh hiệu…"*). Người dùng chạm lại lần nữa vì tưởng hỏng. Nguyên nhân là mục #4 | "Đã sao chép" hiện lên | 🟠 nên sửa | (gộp #4) |
| 13 | **"Xem lại hướng dẫn"** trong hộp tài khoản | Chạm: hộp đóng lại, **không có gì khác**. Thực tế nó **có** xoá dấu đã xem (kiểm chứng: vào Bảo tàng thì chỉ dẫn 1/3 chạy lại thật). Nguyên nhân là mục #4 | Báo "Đã bật lại chỉ dẫn" | 🟠 nên sửa | (gộp #4) |
| 14 | Chat vĩ nhân, rời màn rồi quay lại | **Mất sạch lịch sử.** Quay lại chỉ còn câu chào. Cả cuộc đàm đạo vừa xong biến mất | Giữ lại hội thoại | 🟠 nên sửa | nửa ngày |
| 15 | Bảo tàng → chạm cổ vật | Phiếu chi tiết **bị cắt đáy và không cuộn được**. Ở 360×740, nút "Xem lớn toàn màn hình" bị cắt một nửa và **"Phục Dựng Cổ Vật" nằm hẳn ngoài màn hình**. Thử cuộn bằng bánh xe và thử kéo tay: phiếu đứng im. Ở 1600×860 cũng bị cắt, chạm vào nút không ăn | Phiếu cuộn được, hoặc cao theo nội dung | 🟠 nên sửa | 1 giờ |
| 16 | **"Nghe ngài kể"** trong chat | Chạm: màn hình **không đổi gì suốt 3 giây**. Xem mạng thì nó **có** gọi `POST /api/v1/chat/speak`, và endpoint đó mất **1,3 giây** mới trả về link mp3 | Nút đổi sang trạng thái đang tải, rồi thành "Dừng" khi phát | 🟠 nên sửa | 2 giờ |
| 17 | Mở app lần đầu (bộ nhớ trống) | **Màn kem trắng trơn**, không logo, không vòng xoay, không chữ. Trên mạng Fast 3G kéo dài vài giây. `mobile/web/index.html` không có khối chờ nào — chỉ đặt `background: #fdf9f4` | Logo + một dòng "Đang khơi lại trang sử…" | 🟠 nên sửa | 1 giờ |
| 18 | Một tab lỡ lỗi mạng | Ngắt mạng rồi vào Vĩ nhân → màn lỗi (đẹp). **Bật mạng lại, quay về tab đó: vẫn là màn lỗi.** Không tự thử lại. Phải tự tìm nút "Thử lại". Bấm "Thử lại" cũng **không có trạng thái đang thử** — chỉ gợn sóng rồi thôi | Tự thử lại khi có mạng; nút hiện vòng xoay khi đang gọi | 🟠 nên sửa | 2 giờ |
| 19 | Thước phim Bạch Đằng 938 | Bấm quay lại giữa lúc đang xem: **video vẫn chạy** (đo được `paused:false, currentTime 95,4s` tại mốc 2 giây sau khi đã sang màn danh sách). Vào lại thì **mất chỗ đang xem, chạy lại từ 0** | Dừng ngay khi rời màn; nhớ vị trí | 🟠 nên sửa | 1 giờ |
| 20 | Thước phim Bạch Đằng 938 | Tệp nặng **132 MB**, dài **24 phút 26 giây**. Trước khi bấm không thấy ghi thời lượng hay dung lượng ở đâu | Ghi thời lượng lên hình xem trước; cảnh báo khi dùng 4G | 🟠 nên sửa | 30 phút |
| 21 | Thẻ sự kiện ở Dòng thời gian / Đấu trường / đầu màn chi tiết | Chữ **đè lên nhau**: dòng chìm "938 · Trận Bạch Đằng" và dòng đậm "Trận Bạch Đằng 938" nằm chồng, đọc rối. Thấy ở cả 5 thẻ, cả trên màn chi tiết sự kiện | Dời tiêu đề xuống, hoặc bỏ chữ chìm | 🟠 nên sửa | 30 phút |
| 22 | Thẻ sự kiện ở Dòng thời gian | Giữa các nhãn tiếng Việt ("Phim 3D", "Quiz") có nhãn **`timeline`** — chữ Anh, viết thường, lấy thẳng từ cơ sở dữ liệu | Dịch hoặc ẩn | 🟡 đánh bóng | 15 phút |
| 23 | Màn chi tiết sự kiện, sau khi cuộn | Mũi tên quay lại **đè lên tiêu đề**: đọc ra "…n Bạch Đằng 938" | Chừa lề cho tiêu đề | 🟡 đánh bóng | 15 phút |
| 24 | Màn Premium | **3 trong 4** dòng quyền lợi có **vòng tròn rỗng** thay vì biểu tượng. Chỉ "Bảo tàng đầy đủ" có hình | Thêm 3 biểu tượng | 🟡 đánh bóng | 20 phút |
| 25 | Ô mật khẩu ở màn đăng nhập | Thuộc tính `autocomplete="off"` → trình quản lý mật khẩu không lưu được. Chữ nhắc ghi **"Mật khẩu phải từ 6 ký tự trở lên"** trong khi máy chủ đòi **8**. Lỗi cũ còn nằm đó sau khi đã gõ đủ 14 ký tự | `autocomplete="current-password"`; sửa số 6 thành 8; xoá lỗi khi gõ lại | 🟡 đánh bóng | 20 phút |
| 26 | Thanh điều hướng dưới | **5 biểu tượng vẽ tay, không một chữ nào.** Trống đồng / cuộn thư / cúp / mũ trụ / bình gốm ở cỡ ~40 px, khó phân biệt ngay | Thêm nhãn nhỏ dưới mỗi biểu tượng | 🟡 đánh bóng | 30 phút |
| 27 | Huy hiệu "Chuỗi 0 ngày" trên màn hình chính | Chơi 3 ván trong cùng ngày, xem thước phim, trò chuyện — vẫn **"Chuỗi 0 ngày"**. `/auth/me` cũng trả `streak: 0` | Tăng khi có hoạt động, hoặc bỏ hẳn nếu chưa làm | 🟡 đánh bóng | 2 giờ |
| 28 | Hộp tài khoản | **"Đăng xuất" không hỏi lại**, và ba mục "Xem lại hướng dẫn" / "Đóng" / "Đăng xuất" cùng một kiểu chữ nhỏ, hai mục đỏ như nhau | Hỏi xác nhận; tách "Đăng xuất" ra | 🟡 đánh bóng | 20 phút |
| 29 | Hướng dẫn trang 2 và trang 4 | Hứa *"bật camera đặt nó ra sàn nhà đúng kích thước thật"* (bản web **không có** nút AR) và *"mỗi mốc một thước phim"* (**chỉ 1/5** mốc có phim) | Sửa câu chữ cho khớp bản đang chạy | 🟡 đánh bóng | 20 phút |
| 30 | "Chiến Tích Vang Dội" ở màn hình chính | Chạm dòng "Chiến thắng Bạch Đằng năm 938" → nhảy sang **danh sách Dòng thời gian**, không mở đúng sự kiện đó, cũng không cuộn tới nó | Mở thẳng màn chi tiết sự kiện | 🟡 đánh bóng | 30 phút |
| 31 | Màn hẹp 360 px | Chữ bị cắt: **"Cần đạt Cấp 2 ở Đấu Trường để mở"** (mất chữ "khoá"), **"PHẨM HÀM K…"**, **"Phạm vi tri thức: đến kho…"**, mô tả cổ vật co còn **"Biểu tượ…"** | Cho xuống dòng thay vì cắt | 🟡 đánh bóng | 1 giờ |
| 32 | Bảo tàng — "Thuyền chiến Đông Sơn" | Mô hình 3D là khối **đỏ–xanh dương trơn, chưa có vân bề mặt**, lạc hẳn so với trống đồng và cọc gỗ bên cạnh | Thay mô hình hoặc bỏ khỏi danh sách | 🟡 đánh bóng | — |
| 33 | Sân khấu 3D (chat + bảo tàng) | Nền **trắng tinh** giữa giao diện màu kem — trông như một lỗ thủng trên trang | Đổi nền sang `#FDF9F4` | 🟡 đánh bóng | 15 phút |
| 34 | Tiêu đề tab trình duyệt | Ghi **`historiai`**, chữ thường, mặc định của Flutter | "HistoriAI — Học sử Việt" | 🟡 đánh bóng | 5 phút |

---

## 3. Khoảnh khắc chết

Những chỗ lẽ ra người dùng phải *cảm thấy gì đó*, mà app im lặng.

### 3.1 Thắng một ván quiz — khoảnh khắc đáng ăn mừng nhất

Trả lời đúng 9/10 câu Bạch Đằng, giữ nguyên 3 mạng, chuỗi liên hoàn 9, sĩ khí 95%.
Chạm đáp án cuối. Chụp màn hình ngay sau đó:

- Màn kết quả **đã dựng xong hoàn toàn**: con dấu "CHINH PHỤC HOÀN THÀNH", chữ
  "BẢNG VÀNG KHẮC TÊN", số **+90**, "9 / 10 câu đúng".
- **Không có pháo giấy, không có tia sáng, không có ánh vàng loé.**
- **Không có âm thanh.** Tôi móc sẵn `new Audio()`, `AudioContext.createBufferSource`
  và `navigator.vibrate` trước khi chạm: sau khi thắng, cả ba **rỗng** —
  `{"audio":[],"vib":[]}`. Không một tiếng trống, không một tiếng chuông.
- **Không rung.**
- Không có bước chuyển nào giữa câu hỏi cuối và màn kết quả — quiz biến mất, kết
  quả hiện ra, hết.

Trong mã *có* một hoạt hoạ phóng to huy hiệu (`Curves.elasticOut`, 700 ms) và một
vòng đếm số điểm (`quiz_result_screen.dart:46-75`) — nhưng cái người dùng nhận
được vẫn là một trang tĩnh, không tiếng động, không ăn mừng.

**So sánh: thua một ván** cũng ra đúng cái khung ấy, chỉ đổi chữ thành "RÈN LUYỆN
LẠI" và đổi biểu tượng thành mũi tên quay vòng. Thắng và thua **cảm giác giống
nhau**.

### 3.2 Màn kết quả không cho chơi lại

Tiêu đề to đùng ghi **"RÈN LUYỆN LẠI"**, nhưng dưới đó chỉ có đúng một nút:
**"Về Bản Đồ Chiến Dịch"**. Muốn đánh lại phải quay ra bản đồ rồi tự tìm lại trận.

### 3.3 Điểm số nói dối khi thua giữa chừng

Thua ở câu 5 (hết 3 mạng). Màn kết quả ghi **"2 / 10 câu đúng"** — trong khi tôi
mới được hỏi **5 câu**. Học sinh đọc ra 20%, thực tế là 2/5.

### 3.4 Lời giảng đến muộn và thiếu một nửa

Phần "Xem giải thích từng câu hỏi" có nội dung rất tốt (chuẩn sử, viết gọn), nhưng:
- Nó **gập sẵn**, phải chủ động mở ra mới thấy.
- Nó chỉ ghi *"Câu hỏi 3: Chưa đúng"* rồi tới lời giảng — **không nhắc lại câu
  hỏi, không nói tôi đã chọn gì, không nói đáp án đúng là gì.** Sau 10 câu thì
  chẳng ai nhớ "câu hỏi 3" là câu nào.

### 3.5 Trả lời đúng — không được khen một lần nào

Xuyên suốt 15 câu tôi trả lời trong hai ván, **không một lần** app nói tôi đúng.
Dấu hiệu duy nhất là thanh "Sĩ khí" nhích 5% và có lúc hiện huy hiệu "Liên hoàn n".
Phải nhìn rất kỹ mới nhận ra.

### 3.6 Lên hạng, cộng điểm — không ai chúc mừng

Điểm đi từ 100 → 210, mức thông thạo Bạch Đằng 938 từ 80% → 90%, dòng "Còn 200
Điểm để thăng hàm" đổi thành "Còn 90 Điểm". Tất cả **đổi lặng lẽ** khi tôi quay
về màn hình chính. Không có con số chạy lên, không có thanh tiến độ trườn tới.

### 3.7 Bấm nút mà không biết chuyện gì vừa xảy ra

| Nút | Thực tế nó có làm gì không | Người dùng thấy gì |
|---|---|---|
| "Sao Chép Vinh Quy" | **Có** — đã chép chuỗi khoe thành tích vào bộ nhớ tạm | Không gì |
| "Xem lại hướng dẫn" | **Có** — đã xoá dấu đã xem, chỉ dẫn chạy lại thật | Không gì |
| Nút micro trong chat | **Không** — tính năng chưa làm | Không gì (trên điện thoại không có tooltip) |
| "Nghe ngài kể" | **Có** — gọi `/chat/speak`, mất 1,3 giây | Không gì trong suốt 1,3 giây đó |
| Thẻ Quang Trung (khoá) | **Không** — `onTap: null` | Không gì |
| Dòng "Chiến thắng Bạch Đằng 938" ở màn chính | Có, nhưng **nhảy sai chỗ** | Bật sang danh sách Dòng thời gian |

### 3.8 Đăng nhập thành công — không một lời chào

Bấm "Đăng nhập", màn đăng nhập biến mất, bảng điều khiển hiện ra. Không hiệu ứng,
không "Chào mừng trở lại". Cũng không có vòng xoay nào trong lúc chờ máy chủ.

---

## 4. Trạng thái còn thiếu

✅ có xử lý · ⚠️ có nhưng lỗi · ❌ chưa có · — không áp dụng

| Màn | Đang tải | Rỗng / chưa có dữ liệu | Lỗi mạng |
|---|---|---|---|
| Khởi động app | ❌ màn kem trắng trơn, không logo không vòng xoay | — | ❌ |
| Hướng dẫn 4 trang | — | — | — |
| Đăng nhập | ❌ không thấy vòng xoay khi đang gọi máy chủ | ✅ kiểm tra từng ô, câu tiếng Việt rõ | ⚠️ sai mật khẩu lại báo "Phiên đăng nhập đã hết hạn" |
| Màn hình chính | ❌ | — (luôn có dữ liệu mẫu) | ❌ chưa thử được ra màn lỗi |
| Dòng thời gian | ❌ | ❌ | ❌ vào từ tab khác không thấy màn lỗi |
| Chi tiết sự kiện | ✅ *"Đang mở thước phim…"* + vòng xoay | ❌ (4/5 sự kiện không có phim, không nói gì) | ❌ |
| Đấu trường (bản đồ) | ❌ | ❌ | ✅ biểu tượng mây gạch + *"Không thể tải danh sách chiến dịch đấu trường."* + "Thử lại" |
| Đấu trường (đang chơi) | — | — | ❌ chưa rõ nếu mất mạng giữa ván |
| Kết quả quiz | — | — | ❌ |
| Vĩ nhân (danh sách) | ❌ | ✅ *"Chưa có vĩ nhân — Chưa có dữ liệu nhân vật thuộc triều đại này."* | ✅ + "Thử lại", **nhưng kẹt ở màn lỗi sau khi có mạng lại** |
| Chat | ✅ ba chấm "…" trong lúc chờ | — | ⚠️ ra **bong bóng rỗng** khi bị giới hạn tốc độ |
| Giọng nói ("Nghe ngài kể") | ❌ im lặng 1,3 giây | — | ❌ |
| Nhân vật 3D trong chat | ❌ (mất ~3 giây, không báo) | — | ❌ |
| Bảo tàng (danh sách) | ❌ | ❌ | ✅ *"Không thể nạp dữ liệu bảo tàng. Vui lòng kiểm tra mạng."* + "Thử lại" |
| Bảo tàng (phiếu cổ vật) | ❌ | — | ❌ |
| Premium | — | — | ❌ |

Ba nút "Thử lại" đều **không có trạng thái đang thử lại** — bấm chỉ thấy gợn sóng.

---

## 5. Cái đang làm tốt

Ghi lại để nhóm khỏi sửa nhầm thứ không hỏng.

- **Màn lỗi mạng ba tab lớn giống hệt nhau và đều tử tế.** Đấu trường, Vĩ nhân,
  Bảo tàng đều có biểu tượng đám mây gạch chéo, một câu tiếng Việt nói rõ hỏng
  cái gì, và nút "Thử lại" to rõ. Đây là phần làm chỉn chu nhất của cả sản phẩm.
- **Chỉ dẫn tại chỗ (coach mark) rất tốt.** Khoét sáng đúng widget đang nói tới,
  có số trang 1/2 · 1/3, có "Bỏ qua" và "Tiếp", câu cuối là "Đã hiểu". Chạy trên
  cả ba màn Đấu trường, Chat, Bảo tàng. Xoá dấu đã xem rồi mở lại: chạy lại thật.
- **Trạng thái rỗng của bộ lọc triều đại.** Chọn "Thời Lê" (chưa có nhân vật nào)
  ra đúng một màn "Chưa có vĩ nhân" kèm biểu tượng, không phải màn trắng.
- **Kiểm tra ô nhập ở màn đăng nhập.** Bỏ trống rồi bấm: viền đỏ + "Vui lòng nhập
  email của bạn" ngay dưới ô. Câu chữ tiếng Việt tự nhiên.
- **Thanh trạng thái khi đang chơi quiz rất có không khí.** Ba trái tim, đồng hồ
  đếm ngược, "Kế sách 7/10", thanh "Sĩ khí" đổi chữ theo mức — *"Vững vàng thế
  trận"* → *"Sĩ khí hừng hực tiến công"* → *"Hào khí Đông A ngút trời!"* — kèm
  huy hiệu "Liên hoàn n". Đây là thứ hiếm, giữ nguyên.
- **Ba chấm chờ trong chat** hiện đúng lúc (đo được ở mốc 750–1500 ms).
- **Thước phim chạy thật, có trạng thái chờ.** "Đang mở thước phim…" kèm vòng
  xoay trên nền hình chờ; hình ảnh dựng lại rất khá.
- **Bằng khen "Sắc Ban Khắc Tên" là điểm sáng thẩm mỹ của cả app** — cuộn giấy,
  ấn triện, câu "Hiền tài là nguyên khí của quốc gia". Đây mới đúng là khoảnh khắc
  ăn mừng; chỉ tiếc nó nằm sau một nút bấm chứ không tự hiện.
- **Màn Premium nói thật.** *"Premium chưa mở bán. Nhóm đang hoàn thiện nội dung
  và muốn biết có bao nhiêu người thật sự cần trước khi thu tiền của ai."* Bấm
  "Tôi muốn dùng Premium" thì nút được **thay bằng** thẻ "Đã ghi nhận. Cảm ơn bạn."
  có dấu tích — đây là mẫu phản hồi đúng, nên nhân rộng ra các nút khác.
- **Nút AR trên web bị ẩn đúng cách**, không phải hiện ra rồi bấm không ăn. Đọc
  cây trợ năng của phiếu cổ vật: chỉ có "Xem lớn toàn màn hình" và "Phục Dựng Cổ
  Vật", không có "Đặt vào phòng".
- **Mô hình 3D chạy thật và tự xoay**; nhân vật trong chat có hoạt hoạ đứng thở
  (so hai ảnh chụp liên tiếp thấy tay và áo choàng đổi tư thế).
- **Bố cục 360 px không vỡ.** Không tràn ngang, không chồng khối, khung điện thoại
  giả tự bỏ đi và app chiếm trọn màn hình. Chỉ có vài chỗ cắt chữ (mục #31).
- **Chat trả lời nhanh, đúng sử và có trích nguồn** — huy hiệu "Đại Việt Sử Ký
  Toàn Thư" và nhãn nhân cách "VẠN KIẾP TIẾT CHẾ" dưới mỗi câu trả lời.

---

## 6. Thứ tự đề xuất

| # | Việc | Gỡ được | Công |
|---|---|---|---|
| 1 | Sửa hướng dẫn không chuyển màn | Người mở app lần đầu hết bị kẹt | 15 phút |
| 2 | Cho SnackBar nổi lên trên thanh điều hướng | 7 nút hết "chết" cùng lúc | 30 phút |
| 3 | Đọc `detail` dạng object trong `api_client` | Hết báo "hết phiên" khi sai mật khẩu; chat hiện đúng câu 429 | 20 phút |
| 4 | So `unlockLevel` với cấp thật của người dùng | Mở lại Quang Trung — một nửa nội dung chat | 30 phút |
| 5 | Bỏ số 350 viết cứng trên bằng khen | Không khoe số bịa ra ngoài | 10 phút |
| 6 | Nạp lại bản đồ Đấu trường khi quay về | Người chơi thấy công sức của mình | 30 phút |
| 7 | Phản hồi đúng/sai tại chỗ + lời giảng ngay | Giữ đúng lời hứa của màn hướng dẫn | 3 giờ |
| 8 | Ăn mừng lúc thắng: pháo giấy + tiếng trống + đếm số + nút "Đánh lại" | Khoảnh khắc đáng nhớ nhất của sản phẩm | 4 giờ |

**Sáu việc đầu gộp lại chưa tới ba tiếng** mà gỡ được toàn bộ bốn mục chặn.
