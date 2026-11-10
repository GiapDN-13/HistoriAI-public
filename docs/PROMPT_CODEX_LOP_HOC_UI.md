# Prompt cho Codex — làm lại toàn bộ giao diện "Lớp học / Kiểm tra trên lớp"

> Dán nguyên phần dưới dấu `---` vào Codex.
> Repo `git@github.com:GiapDN-13/HistoriAI.git`, nhánh xuất phát **`feat/bang-vang-lop-hoc`**.
> Prompt này **thay** `docs/PROMPT_CODEX_BANG_VANG.md`: bảng vàng nằm trong phạm vi dưới đây.

---

Bạn là kỹ sư Flutter kiêm nhà thiết kế UI/UX, làm cho **HistoriAI**, app học Lịch sử Việt
Nam cho học sinh THCS/THPT. Bản chính chạy trên **web** (historiai.org, Flutter web
CanvasKit, khoảng 95% người dùng); có thêm bản Android. Backend là FastAPI. Viết code,
comment và trao đổi bằng **tiếng Việt**, theo đúng phong cách của repo: tên biến tiếng
Việt không dấu, comment giải thích *vì sao*.

## 1. Mục tiêu

**Làm lại toàn bộ giao diện và trải nghiệm** của tính năng *kiểm tra trên lớp* (kiểu
Kahoot / Quizizz), cho cả **giáo viên** lẫn **học sinh**. Hiện tính năng chạy đúng nhưng
giao diện rời rạc, nhiều chữ, thiếu cảm giác "sân chơi". Bạn cần:

- **Học sinh** (12–17 tuổi, đa số dùng điện thoại): vào phòng trong vài giây, làm bài
  thấy hồi hộp và vui, cuối bài có **bảng vàng** và **giấy vinh danh** đủ đẹp để chụp
  khoe bố mẹ, gửi nhóm lớp.
- **Giáo viên** (thường dùng laptop, chiếu lên máy chiếu): soạn đề nhanh (nhất là dán đề
  AI soạn sẵn), mở phòng, điều khiển trận, xem ai làm tới đâu, xuất bảng điểm. Không
  phải đọc hướng dẫn mới biết làm.
- **Màn chiếu** (máy chiếu lớp học, nhìn từ cuối phòng): chữ to, tương phản cao, đọc
  được từ xa 8 m.

**Chỉ làm giao diện và luồng màn hình.** Không đổi API, không đổi luật chấm điểm hay xếp
hạng, không thêm route backend. Cần dữ liệu backend chưa trả thì **ghi vào PR**, đừng tự
sửa backend.

## 2. Phạm vi: các màn hiện có

Toàn bộ nằm trong `mobile/lib/features/lop_hoc/`. Đọc hết trước khi thiết kế.

| Tệp | Ai dùng | Hiện làm gì |
|---|---|---|
| `vao_phong_screen.dart` (`VaoPhongScreen`) | HS | Nhập mã phòng 6 số (hoặc mở thẳng từ link/QR `/vao/<mã>`), tên, lớp, tự đặt PIN 4 số. Đã đăng nhập thì bỏ qua tên + PIN |
| `lam_bai_screen.dart` (`LamBaiScreen`, `_KetQua`, `_XemLaiCau`) | HS | **Bài tập**: tự làm theo nhịp riêng, mỗi câu có đồng hồ, chọn xong hiện đúng/sai rồi sang câu; nộp xong hiện điểm, bảng vàng, xem lại từng câu |
| `truc_tiep/thi_truc_tiep_screen.dart` (`ThiTrucTiepScreen`) | HS | **Thi trực tiếp**: chờ giáo viên → câu hiện theo nhịp giáo viên → lộ đáp án + top 5 → kết thúc có bục vinh danh, nút giấy vinh danh, xem lại |
| `truc_tiep/man_chieu_screen.dart` (`ManChieuScreen`) | GV, chiếu | Mã QR + danh sách em đã vào → câu hỏi + đồng hồ → phân bổ A/B/C/D + top 5 → bảng xếp hạng chung cuộc |
| `truc_tiep/dieu_khien_screen.dart` (`DieuKhienTrucTiepScreen`) | GV | Nút **Bắt đầu / Kết thúc câu / Câu tiếp / Kết thúc trận sớm**, mở màn chiếu |
| `truc_tiep/widget_truc_tiep.dart` | chung | `ODapAn`, `LuoiDapAn`, `DemNguoc`, `BieuDoPhanBo`, `BangTop`, `BucVinhDanh`, `DaiKetNoi` (dải báo mất kết nối) |
| `truc_tiep/ket_noi_truc_tiep.dart` | chung | WebSocket + dự phòng polling. **Không sửa logic** |
| `giao_vien_screen.dart` (`GiaoVienScreen`, `SoanDeScreen`) | GV | Trang chủ giáo viên: danh sách đề, phòng đã mở, lối vào câu tự soạn và lớp cố định; soạn đề bằng tick chọn câu theo nhóm sự kiện, chọn giây mỗi câu |
| `phong_screen.dart` (`PhongScreen`) | GV | Phòng **bài tập** đang mở: mã + QR + chép link, tab Học sinh / Từng câu, xuất CSV, đóng phòng |
| `mo_rong/cau_rieng_screen.dart` | GV | Danh sách câu tự soạn + form soạn từng câu |
| `mo_rong/nhap_nhieu_cau_screen.dart` | GV | **Dán nhiều câu**: chép prompt cho AI → dán kết quả → xem trước câu hợp lệ / lỗi → lưu |
| `mo_rong/prompt_soan_de.dart` | GV | Văn bản prompt cho AI. **Giữ nguyên nội dung**, chỉ đổi cách trình bày |
| `mo_rong/lop_co_dinh_screen.dart`, `mo_rong/thong_ke_lop_screen.dart` | GV | Lớp cố định (sĩ số, thêm/bỏ em), thống kê nhiều buổi |
| `mo_rong/giu_tai_khoan.dart` | HS | Lời mời "giữ tài khoản" bằng email sau khi làm bài bằng tài khoản nhanh |
| `bang_vang.dart` | HS | `BangVangPhong` (top 10 + dòng của em), `GiayVinhDanhScreen` / `GiayVinhDanh` (giấy 420×620, lưu PNG trên web), `danhHieu()` |
| `tai_tep_web.dart` / `tai_tep_stub.dart` | chung | `taiTep` (CSV), `taiAnh` (PNG). Bản Android trả `false` → nhắc chụp màn hình |
| `lop_hoc_api.dart` (`LopHocApi`) | chung | Mọi lời gọi API. **Không đổi chữ ký hàm**; được thêm getter hoặc hàm tiện ích |

Lối vào từ ngoài: `profile/profile_settings_screen.dart` (mục *LỚP HỌC*: "Vào phòng kiểm
tra", "Quản lý lớp học (giáo viên / quản trị)"), `quiz/quiz_map_screen.dart` (nút vào
phòng), `main.dart` (link `/vao/<mã>`). Được đổi chỗ và cách trình bày lối vào, nhưng
không được làm mất lối vào nào.

## 3. Dữ liệu & quy tắc nghiệp vụ phải giữ

- Vai trò: `student`, `teacher`, `admin` (admin có mọi quyền giáo viên). Học sinh có thể
  là **tài khoản nhanh** (chỉ tên + PIN) hoặc tài khoản thường.
- Đề: 1–60 câu; mỗi câu 15/20/30/45/60/90 giây (backend nhận 10–300). Câu trong kho chung
  có `id` dương, câu giáo viên tự soạn có `id` **âm**.
- Phòng có `che_do` = `bai_tap` hoặc `truc_tiep`. Bài tập có hạn (1 ngày / 7 ngày / tới
  khi giáo viên đóng). Trực tiếp có các pha `cho → dang_hoi → lo_dap_an → … → ket_thuc`.
- **Máy học sinh không bao giờ nhận đáp án trước khi trả lời.** Đừng thiết kế gì đòi điều
  đó.
- Điểm thi trực tiếp: đúng thì `1000·(1 − t/2T)`, nhanh thì nhiều điểm. Bằng điểm thì ai
  tổng thời gian đúng ít hơn đứng trên; bằng cả hai thì **đồng hạng** (1, 2, 2, 4).
- Bảng vàng học sinh (`GET /phong/{ma}/xep-hang`, `LopHocApi.bangVang`): chỉ có sau khi
  nộp bài / hết trận. Trả `top` (tối đa 10, có `la_toi`) và `cua_toi` (`hang`,
  `so_dung`, `diem_10`, `diem`, `vuot_pct`). Mọi trường có thể `null`. Xem docstring
  route `bang_vang_phong` trong `backend/app/api/routes/lop_hoc.py`.
- **Không làm học sinh xấu hổ**: em đứng nửa dưới thì không in thứ hạng to (đã có
  `khoeHang` trong `GiayVinhDanh`; giữ ý này ở mọi màn kết quả).
- Danh hiệu Trạng Nguyên / Bảng Nhãn / Thám Hoa **luôn kèm lời thường** ("Hạng nhất cả
  phòng"): học sinh đã góp ý là chữ cổ quá thì khó hiểu.
- Bảng xếp hạng hiện **tên học sinh tự nhập trong phòng** (không bao giờ hiện email) và
  **ảnh đại diện** của từng bạn. Nhóm sẽ bổ sung trường `avatar_url` (có thể `null`) vào
  mỗi dòng `top` / `cua_toi` của bảng vàng, và vào top của thi trực tiếp. Thiết kế sẵn
  vòng ảnh tròn, kèm dự phòng khi `null`: chữ cái đầu của tên trên nền màu sinh từ tên.
  Học sinh tự quyết có đăng ảnh hay không. Ảnh còn lấy từ bộ ảnh có sẵn
  (`core/anh_dai_dien.dart`), ảnh hỏng hay không tải được thì dùng dự phòng như trên.

## 4. Hướng thiết kế

**Bộ nhận diện "Imperial Light"** (bắt buộc, lấy từ `mobile/lib/core/theme.dart`):

| | |
|---|---|
| Nền kem | `#FDF9F4` · đậm hơn `#FBF3E6` |
| Đỏ son | `#BA2323` · đậm `#7A2218` |
| Vàng | `#D4AF37` · sáng `#FDD141` |
| Cam (nút hành động) | `#E67E22` |
| Chữ | `#2B1410` · nhạt `#7C5A4A` |

- **Font duy nhất**: `PlayfairDisplay` (700, cho tiêu đề), `Montserrat` (600, cho nhãn và
  nút), `Inter` (400, cho nội dung). Không có weight khác. **Không dùng** Georgia hay
  serif hệ thống, vì dấu tiếng Việt bị tách rời. Luôn thử tên dài có dấu, ví dụ "Tôn Nữ
  Hoàng Phương Thảo Nguyên".
- **Hoạ tiết** đã có trong `core/widgets/vietnamese_decorations.dart` (`ChimLacMotif`,
  `DongSonWaveDivider`, `ImperialBorderDecoration`, `RoyalSealStamp`, `DongSonBackground`).
  Dùng lại; không dùng emoji thay hoạ tiết.
- **Bốn ô đáp án** phải phân biệt được bằng **cả màu lẫn hình** (kiểu Kahoot), để học
  sinh mù màu vẫn chơi được và để chỉ tay lên màn chiếu được: "chọn ô tam giác đỏ".
  Cùng một bộ màu và hình ở màn chiếu, máy học sinh và biểu đồ phân bổ.
- **Nhịp và cảm xúc**: đếm ngược rõ, phản hồi đúng/sai tức thì, điểm cộng bay lên, thứ
  hạng thay đổi có chuyển động. Mỗi hiệu ứng ≤ 1,5 s, và **tắt** khi
  `MediaQuery.disableAnimations` hoặc khi người dùng tắt "Hiệu ứng nền"
  (`AppPreferences`).
- **Điện thoại trước**: học sinh bấm bằng ngón cái, ô đáp án tối thiểu 56 px chiều cao,
  không cần cuộn khi đang trả lời.
- **Màn chiếu**: khổ 16:9, chữ câu hỏi ≥ 40 px logic ở 1280×720, mã phòng và QR to ở
  màn chờ. Có nút toàn màn hình (web).
- **Giáo viên**: mỗi màn có **một hành động chính** rõ ràng. Luồng tạo trận lý tưởng chỉ
  khoảng 3 lần bấm: *Soạn/chọn đề → Mở phòng (chọn kiểu) → Bắt đầu*. Nút "Dán nhiều câu
  từ AI" phải dễ thấy ngay từ trang chủ giáo viên. Có trạng thái trống hướng dẫn việc
  tiếp theo ("Chưa có đề — dán đề AI soạn hoặc chọn câu từ kho").
- **Giấy vinh danh**: như bằng khen thật. Có hai khổ, **4:5** (bài đăng Facebook/Zalo) và
  **9:16** (story), chuyển bằng một nút. Ảnh lưu ra giống hệt cái nhìn thấy, nét
  (`pixelRatio` ≥ 3), không dính viền hay nút của app. Thiết kế ở khổ cố định rồi
  `FittedBox` để không tràn chữ.
- **Mất mạng**: dải `DaiKetNoi` và thông báo phải nói bằng lời thường ("Mất kết nối —
  đang thử lại…"), không lộ mã lỗi.
- **Chữ trên giao diện**: tiếng Việt tự nhiên, phi kỹ thuật, xưng "em" với học sinh và
  "thầy cô" với giáo viên như hiện tại.

## 5. Ràng buộc kỹ thuật

- **Không thêm gói native mới.** Máy dựng hiện không dựng được APK, nên mọi thứ phải chạy
  trên web. Gói thuần Dart thì được, nhưng ghi lý do trong PR. Chia sẻ ảnh dùng `taiAnh`.
- **Không sửa**: `backend/`, `ket_noi_truc_tiep.dart` (logic), chữ ký các hàm trong
  `lop_hoc_api.dart`, luồng nộp bài, luật điểm.
- **Không hard-code số liệu** lên màn; mọi số lấy từ API.
- Được tách màn lớn thành nhiều widget hoặc tệp, được gom widget dùng chung vào
  `features/lop_hoc/giao_dien/` (hoặc tên tương tự), miễn import gọn.
- Giữ các tham số `api:` và `ketNoi:` truyền vào màn hình: test dùng chúng để giả máy
  chủ.

## 6. Kiểm tra (phải xanh hết trước khi mở PR)

```bash
cd mobile
C:\src\flutter\bin\flutter.bat analyze --no-fatal-infos   # 0 error, 0 warning
C:\src\flutter\bin\flutter.bat test                       # hiện 168 test, phải xanh hết
```

- Test hiện có của phần này: `test/lop_hoc_test.dart`, `test/lop_hoc_truc_tiep_test.dart`,
  `test/lop_hoc_mo_rong_test.dart`, `test/dat_vao_phong_test.dart`,
  `test/bang_vang_test.dart`. Chúng tìm widget theo **chữ trên màn hình**. Đổi chữ thì sửa
  test cho khớp, nhưng **không được bỏ điều mà test đang kiểm** (vd "không gửi đáp án
  xuống máy học sinh", "hết giờ thì gửi bỏ trống và sang câu sau", "vào lại giữa chừng
  bỏ qua câu đã làm").
- **Thêm test**:
  - Không tràn chữ ở bề ngang 320 / 412 / 1280 cho mọi màn học sinh và màn chiếu, với
    tên dài và khi các trường `null`.
  - Em ngoài top 10 vẫn thấy dòng của mình.
  - Hạng thấp không hiện chữ "Hạng" trên giấy.
  - Tắt hiệu ứng thì không còn animation chạy.
- **Chụp màn hình** (dựng web, chạy với dữ liệu giả) và đính vào PR, khổ điện thoại 412
  và màn chiếu 1280×720:
  - vào phòng,
  - đang làm câu,
  - đúng/sai,
  - kết quả + bảng vàng,
  - giấy vinh danh 2 khổ,
  - màn chờ / câu hỏi / phân bổ / chung cuộc của màn chiếu,
  - trang chủ giáo viên,
  - soạn đề,
  - dán nhiều câu,
  - phòng bài tập.

## 7. Bàn giao

- Làm theo đợt, mỗi đợt một PR vào `feat/bang-vang-lop-hoc`:
  1. bộ widget chung (ô đáp án, đồng hồ, bảng xếp hạng);
  2. luồng học sinh;
  3. màn chiếu + điều khiển;
  4. luồng giáo viên.
- Mỗi PR: mô tả ngắn bằng tiếng Việt (đã đổi gì, vì sao), ảnh trước/sau, danh sách test
  đã thêm.
- Commit nhỏ, thông điệp tiếng Việt.
- Chỗ nào cần dữ liệu backend chưa có thì liệt kê ở cuối PR, kèm ý tưởng route và
  trường cần thêm. Nhóm sẽ làm phần backend.
