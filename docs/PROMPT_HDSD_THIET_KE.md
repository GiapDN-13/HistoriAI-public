# Prompt — thiết kế bộ Hướng dẫn sử dụng HistoriAI (giáo viên + học sinh)

> Dán nguyên phần dưới dấu `---` vào công cụ thiết kế / tạo ảnh.
> Nội dung lấy từ `docs/HDSD.md` và các tính năng đã chạy tới 05/10/2026.
> ✅ Tên nút đã đối chiếu với giao diện mới (05/10). Ảnh thật: thư mục `EXE201/Anh_HDSD/`.
> ⚠ (cũ) Giao diện lớp học đang được làm lại (Codex). Phần đánh dấu **[CHỜ ẢNH THẬT]** phải
> thay bằng ảnh chụp màn hình thật **sau khi** bản giao diện mới lên historiai.org.

---

Bạn là nhà thiết kế tài liệu hướng dẫn cho **HistoriAI**, nền tảng học Lịch sử Việt Nam
qua AI, quiz và trò chơi hoá, dành cho học sinh THCS/THPT. Hãy thiết kế **hai bộ hướng
dẫn sử dụng** bằng tiếng Việt: một cho **giáo viên**, một cho **học sinh**. Văn bản trong
từng trang đã được viết sẵn bên dưới. **Giữ đúng chữ, nhất là tên nút** (in đậm), vì
người đọc sẽ tìm đúng chữ đó trên app. Được rút gọn câu chữ cho vừa trang, nhưng **không
được thêm tính năng, con số hay lời hứa nào không có trong bản này**.

## A. Phong cách hình ảnh (áp dụng cho cả hai bộ)

- **Bộ nhận diện "Imperial Light"**:
  - Nền kem `#FDF9F4` / `#FBF3E6`.
  - Đỏ son `#BA2323` / `#7A2218`.
  - Vàng `#D4AF37` / `#FDD141`.
  - Cam cho nút hành động `#E67E22`.
  - Chữ nâu đậm `#2B1410`, chữ phụ `#7C5A4A`.
- **Font**:
  - Tiêu đề: **Playfair Display Bold**.
  - Nhãn, số bước: **Montserrat SemiBold**.
  - Nội dung: **Inter**.
  - Chỉ dùng font hiện đúng dấu tiếng Việt. Không dùng Georgia hay font serif hệ thống, vì dấu bị tách rời.
- **Hoạ tiết**:
  - Trống đồng Đông Sơn: vòng tròn đồng tâm, ngôi sao giữa mặt trống.
  - Chim Lạc bay theo hàng.
  - Sóng nước Bạch Đằng, cọc gỗ.
  - Dùng làm viền, nền mờ, góc trang. Không đè lên chữ.
- **Minh hoạ**:
  - Phong cách tranh phẳng, nét mảnh, chất tranh dân gian Đông Hồ hiện đại hoá.
  - Nhân vật là học sinh Việt Nam mặc đồng phục THCS/THPT và thầy cô giáo đứng lớp.
  - Có thể có vĩ nhân (Trần Hưng Đạo, Quang Trung) cách điệu, thân thiện.
  - Tông ấm, tự hào, vui. Không bạo lực, không vũ khí đẫm máu.
- **Ảnh màn hình app**: **không tự vẽ hay bịa giao diện app.**
  - Mỗi chỗ cần ảnh app, đặt **khung điện thoại** (hoặc khung laptop/máy chiếu) có ô trống, ghi nhãn **[CHỜ ẢNH THẬT: <tên màn>]**. Nhóm sẽ chèn ảnh chụp thật.
  - Lý do: giao diện vẽ ra sẽ khác app thật, người đọc tìm không thấy nút.
  - Được vẽ **mũi tên, vòng tròn đánh dấu, số bước** chỉ vào vùng sẽ đặt ảnh.
- **Đọc nhanh**:
  - Mỗi trang một ý chính.
  - Số bước to, tròn, đỏ son.
  - Tối đa khoảng 40 từ chữ chạy mỗi bước.
  - Biểu tượng nhỏ cạnh mỗi lưu ý: 💡 mẹo, ⚠ chú ý.
- Logo chữ **HISTORIAI** (Playfair, đỏ son, giãn chữ) kèm chim Lạc ở đầu hoặc chân trang. Chân trang: `historiai.org`.

## B. Bộ 1 — HDSD cho GIÁO VIÊN

**Khổ A4 dọc**, 9 trang, in được và xem được trên máy tính. Thêm một bản **16:9** cùng
nội dung để chiếu trong buổi tập huấn.

**Trang 1 — Bìa**
- Tiêu đề: **"Kiểm tra trên lớp cùng HistoriAI"**.
- Phụ đề: *"Hướng dẫn cho thầy cô — soạn đề bằng AI, thi như Kahoot, xuất bảng điểm Excel"*.
- Minh hoạ: cô giáo đứng cạnh màn chiếu, cả lớp giơ điện thoại hào hứng; trống đồng mờ phía sau.

**Trang 2 — Bắt đầu trong 1 phút**
1. Mở **historiai.org** trên máy tính hoặc điện thoại. Không cần cài.
2. Đăng ký hoặc đăng nhập: email + mật khẩu, hoặc **Tiếp tục bằng Google**.
3. **Tài khoản → Tôi là giáo viên** → nhập **Mã giáo viên** do nhóm HistoriAI gửi riêng. Chỉ làm một lần.
4. Mục đó đổi thành **Quản lý lớp học (giáo viên)**. Mọi việc dưới đây đều bắt đầu từ đây.
- [CHỜ ẢNH THẬT: Tài khoản → mục LỚP HỌC]
- ⚠ Mã giáo viên chỉ dành cho thầy cô, xin đừng chia sẻ cho học sinh.

**Trang 3 — Soạn đề nhanh bằng AI (cách tiện nhất)**
1. Trên trang **Lớp học**, bấm **Dán nhiều câu từ AI** → **Chép prompt cho AI**.
2. Mở ChatGPT, Gemini hoặc Copilot (bản miễn phí là đủ) → dán prompt → sửa phần trong
   dấu [ ]: số câu, chủ đề hoặc tên bài, lớp → gửi.
3. Chép toàn bộ câu trả lời của AI → quay lại app → dán vào ô → **Bước 3: Xem trước**.
4. App chỉ rõ câu nào dùng được, câu nào lỗi và vì sao → **Lưu**.
- Minh hoạ: luồng 4 ô nối bằng mũi tên **App → AI → App → Đề**, mỗi ô một biểu tượng (chép, AI, dán, đề xong).
- [CHỜ ẢNH THẬT: màn Dán nhiều câu, bước xem trước]
- ⚠ **Thầy cô đọc lại đáp án trước khi lưu. AI cũng có lúc sai.**
- 💡 Tự gõ tay cũng được, miễn đúng mẫu ở khung dưới (vẽ thành thẻ giấy có chữ đánh máy):
  ```
  Câu 1: Trận Bạch Đằng năm 938 do ai chỉ huy?
  A. Ngô Quyền
  B. Lê Hoàn
  C. Trần Hưng Đạo
  D. Lý Thường Kiệt
  Đáp án: A
  Giải thích: Năm 938 Ngô Quyền đánh tan quân Nam Hán trên sông Bạch Đằng.
  ```

**Trang 4 — Ghép thành đề**
- **Soạn đề mới**: đặt tên đề (vd *"Ôn tập Bạch Đằng — 8A2"*) → tick chọn câu. Nhóm
  **Câu tôi tự soạn** nằm đầu danh sách, sau đó là kho câu có sẵn theo từng trận. Có nút
  **Chọn hết**.
- Chọn **thời gian mỗi câu**: 15, 20, 30, 45, 60 hoặc 90 giây → bấm **Lưu đề (… câu)**.
- Một đề tối đa 60 câu.
- 💡 **Lớp của tôi**: tạo lớp cố định, thêm hoặc bỏ học sinh, xem **thống kê theo lớp**
  qua nhiều buổi.
- [CHỜ ẢNH THẬT: màn Soạn đề]

**Trang 5 — Hai kiểu phòng: chọn kiểu nào?**
So sánh hai cột, mỗi cột một minh hoạ nhỏ:

| | **Bài tập** (giao về nhà) | **Thi trực tiếp** (kiểu Kahoot) |
|---|---|---|
| Nhịp | Mỗi em tự làm theo nhịp riêng | Thầy cô chuyển từng câu, cả lớp làm cùng lúc |
| Hạn | 15 phút, một tiết 45 phút, 1 ngày, 7 ngày, hoặc tới khi thầy cô đóng | Trong giờ học |
| Điểm | Số câu đúng, thang 10 | Đúng **và nhanh** thì nhiều điểm hơn, có xếp hạng từng câu |
| Hợp khi | Ôn bài, mạng trường yếu | Khởi động, củng cố cuối tiết, thi đua |

**Trang 6 — Thi trực tiếp trên lớp**
1. Ở đề đã soạn, bấm **Mở phòng** → chọn **Thi trực tiếp** (*Cả lớp cùng chơi, thầy cô chuyển câu*) → **Mở phòng**.
2. Bấm **Mở màn chiếu cho cả lớp** → đưa lên máy chiếu: mã QR, mã 6 số và danh sách em đã vào hiện ở đây.
3. Trên máy của thầy cô, dùng màn điều khiển:
   - **Bắt đầu** khi đủ học sinh;
   - **Kết thúc câu** để hiện đáp án, phân bổ A/B/C/D và top 5;
   - **Câu tiếp** để sang câu sau;
   - hết giờ học thì **Kết thúc trận sớm**.
4. Cuối trận, màn chiếu hiện **bục vinh danh** và **bảng xếp hạng chung cuộc**.
- Minh hoạ: laptop (điều khiển) nối máy chiếu (màn chiếu), học sinh cầm điện thoại.
- [CHỜ ẢNH THẬT: màn chiếu lúc chờ, lúc hiện câu hỏi, lúc chung cuộc]
- 💡 Cho học sinh vào phòng trước 2–3 phút. Nên chạy thử với 2–3 máy trước buổi thật.

**Trang 7 — Giao bài tập**
1. Ở đề đã soạn, bấm **Mở phòng** → chọn **Bài tập** (*Các em tự làm theo nhịp của mình*) → chọn **Hạn làm bài**: **15 phút**, **Một tiết · 45 phút**, **1 ngày**, **7 ngày** hoặc **Tới khi thầy cô đóng** → **Mở phòng**.
2. Gửi cho học sinh **mã QR**, **mã 6 số**, hoặc bấm **Chép link** để dán vào nhóm Zalo/Messenger.
3. Theo dõi trực tiếp:
   - tab **Học sinh**: ai đã vào, làm tới đâu, bao nhiêu điểm;
   - tab **Từng câu**: câu nào cả lớp hay sai.
4. Hết hạn thì **Đóng phòng**. Bài đang làm dở vẫn được chấm theo phần đã làm.
- [CHỜ ẢNH THẬT: màn phòng bài tập]

**Trang 8 — Xuất bảng điểm Excel**
- Bấm **Xuất bảng điểm** → tải về tệp Excel (.xlsx) gồm 3 trang:
  - **Bảng điểm**: tên đề, mã phòng, ngày; mỗi em một dòng với số câu đúng, điểm /10,
    thời gian làm; thi trực tiếp có thêm điểm thi và hạng; dòng điểm trung bình cả phòng.
  - **Từng câu**: tỉ lệ đúng từng câu, số em chọn A/B/C/D, phương án bị nhầm nhiều nhất.
    Câu dưới 50% đúng được tô hồng, nên giảng lại.
  - **Chi tiết**: lưới học sinh × câu, ✓ đúng, ✗ sai (kèm phương án em chọn).
- Minh hoạ: tệp Excel bung ra 3 tab, mỗi tab một biểu tượng.
- [CHỜ ẢNH THẬT: tệp bang-diem-mau.xlsx, nhóm có sẵn]
- ⚠ Trên app Android, bảng điểm được chép vào bộ nhớ tạm để dán vào Excel hoặc Google Sheets. Muốn tải tệp thì dùng bản web.

**Trang 9 — Hỏi nhanh**
- *Học sinh không có tài khoản được không?* Được. Em chỉ cần tên + PIN 4 số ngay trong phòng.
- *Em lỡ tắt trang?* Vào lại cùng mã phòng, nhập lại tên + PIN là làm tiếp.
- *Mạng trường yếu?* Dùng kiểu **Bài tập**: em nào rớt mạng chỉ em đó chậm lại.
- *Gặp lỗi?* Góp ý ngay trong app, hoặc báo nhóm HistoJourney.
- Chân trang: `historiai.org`, chim Lạc.

## C. Bộ 2 — HDSD cho HỌC SINH

**Khổ 9:16 dọc** (để gửi qua Zalo / đăng story), **7 thẻ**, chữ to đọc trên điện thoại.
Thêm một **poster A3** gộp nội dung để dán lớp. Giọng văn xưng **"em"**, vui, ngắn.

**Thẻ 1 — Bìa**
- **"Vào phòng thi Sử — 30 giây là xong!"**
- Minh hoạ: học sinh giơ điện thoại, chim Lạc bay quanh, huy chương vàng lấp lánh.

**Thẻ 2 — Vào phòng**
1. **Quét mã QR** trên màn chiếu. Hoặc mở **historiai.org** → **Tài khoản → Vào phòng kiểm tra** → nhập **mã phòng 6 số** thầy cô đưa.
2. Nhập **Họ và tên**, **Lớp**, rồi **tự đặt mã PIN 4 số**.
3. Bấm **Vào làm bài**.
- [CHỜ ẢNH THẬT: màn Vào phòng]
- ⚠ **Nhớ PIN!** Lỡ tắt trang thì nhập lại tên + PIN là làm tiếp.

**Thẻ 3 — Làm bài**
- Mỗi câu có **đồng hồ đếm ngược**. Chạm vào đáp án em chọn.
- Thi trực tiếp: **đúng và nhanh** thì nhiều điểm hơn. Câu hiện theo nhịp thầy cô.
- Bài tập: em tự làm theo nhịp riêng. Hết giờ một câu thì tự sang câu sau.
- [CHỜ ẢNH THẬT: màn đang làm câu]

**Thẻ 4 — Bảng vàng**
- Làm xong, em thấy **điểm**, **đáp án từng câu**, và **Bảng vàng** của phòng: top bạn
  dẫn đầu, có huy chương vàng, bạc, đồng; dòng của em được đánh dấu.
- Câu sai tự vào mục **Ôn câu sai** trong Tài khoản để ôn lại.
- [CHỜ ẢNH THẬT: Bảng vàng]

**Thẻ 5 — Giấy vinh danh**
- Bấm **Nhận giấy vinh danh của em** → **Lưu ảnh để khoe** → gửi bố mẹ, đăng nhóm lớp!
- Danh hiệu cho 3 bạn dẫn đầu: **Trạng Nguyên** (hạng nhất), **Bảng Nhãn** (hạng nhì),
  **Thám Hoa** (hạng ba). Các bạn khác nhận **Xuất sắc**, **Giỏi**, **Hoàn thành tốt**
  theo điểm, hoặc **Đã hoàn thành** kèm lời động viên.
- Minh hoạ: một tấm giấy khen cách điệu viền đỏ son và vàng, đặt cạnh khung điện thoại
  **[CHỜ ẢNH THẬT: giấy vinh danh]**. Không viết tên hay điểm cụ thể lên tấm minh hoạ.

**Thẻ 6 — Ảnh đại diện & giữ tài khoản**
- **Tài khoản → Sửa họ tên, ảnh đại diện → Tải ảnh của em**, hoặc chọn một ảnh có sẵn.
  Ảnh hiện trên hồ sơ và bảng vàng, các bạn cùng lớp sẽ thấy.
- Muốn giữ điểm và lịch sử lâu dài: **Tài khoản → Giữ tài khoản: thêm email**. Sau đó em
  đăng nhập bằng email + mật khẩu.
- [CHỜ ẢNH THẬT: màn Sửa hồ sơ]

**Thẻ 7 — Học thêm với HistoriAI**
- **Thời gian**: dòng thời gian các trận đánh.
- **Đấu trường**: quiz từng trận.
- **Vĩ nhân**: trò chuyện có giọng nói với Trần Hưng Đạo, Quang Trung.
- **Bảo tàng**: xoay hiện vật 3D.
- 💡 AI có thể sai. Chi tiết nào dùng để làm bài thì em đối chiếu lại sách giáo khoa.
- Cài app: Android vào **historiai.org/tai-app/**. iPhone dùng thẳng **historiai.org**
  trên Safari (**Chia sẻ → Thêm vào MH chính**).

## D. Giao nộp

- Bộ giáo viên: PDF A4 (9 trang) + bản 16:9.
- Bộ học sinh: 7 ảnh PNG 1080×1920 + poster A3 PDF.
- Kèm **tệp gốc chỉnh sửa được**, để nhóm thay các ô [CHỜ ẢNH THẬT] bằng ảnh chụp
  màn hình thật.
- Rà lại: mọi tên nút in đậm khớp đúng chữ trong bản này; mọi dấu tiếng Việt hiển thị
  đúng; không có chi tiết lịch sử nào ngoài các câu mẫu đã cho.
