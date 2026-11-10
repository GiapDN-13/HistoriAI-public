# Audit UI/UX HistoriAI

Ngày rà: 25/09/2026  
Phạm vi: toàn bộ Flutter app, web 1440 px và mobile 375 px, giao diện hiện tại, motion theo hướng nổi bật.  
Phương pháp: chạy build web bằng Chrome headless, chụp màn hình, kiểm tra bàn phím, đọc toàn bộ màn hình và component UI liên quan, đối chiếu audit trải nghiệm ngày 23/09.

## Kết luận

HistoriAI đã có bản sắc thị giác tốt và khác biệt rõ: đỏ son, vàng, nền giấy, Playfair Display và họa tiết Việt Nam được dùng nhất quán. Login và Dashboard ở 375 px có chất lượng trình diễn tốt.

Điểm yếu chính hiện nằm ở kiến trúc trải nghiệm: bản desktop chỉ là khung điện thoại 430 px, điều hướng tab làm mất trạng thái, một số thao tác chính không dùng được bằng bàn phím, bottom sheet hiện vật vẫn có thể bị cắt, và hệ motion mới chỉ hỗ trợ reduced motion ở một phần nhỏ. Một số lời hứa trong onboarding vẫn vượt quá tính năng thực tế.

## Điểm thiết kế

| Hạng mục | Điểm / 10 | Nhận xét |
|---|---:|---|
| Màu sắc | 8.5 | Bản sắc mạnh, token tập trung; một vài cặp màu chữ nhỏ chưa đạt tương phản AA. |
| Phân cấp chữ | 8.0 | Ba font có vai trò rõ; còn nhiều chữ 10–11.5 px và tiêu đề bị cắt. |
| Nhịp khoảng cách | 7.5 | Thang 4 px khá nhất quán; một số màn dùng nhiều giá trị riêng. |
| Tính nhất quán component | 7.0 | `AppButton`, `AppCard`, `ErrorState` tốt; vẫn còn nhiều `GestureDetector` và nút tự dựng. |
| Responsive | 4.5 | Mobile ổn; desktop bỏ trống phần lớn màn hình và không tận dụng chiều ngang. |
| Chủ đề | 7.0 | Light theme hoàn chỉnh và có chủ ý; chưa có dark mode, không phải nhu cầu cấp thiết. |
| Motion | 6.0 | Có nhiều hiệu ứng có cá tính; thiếu quy tắc chung và reduced motion chưa bao phủ hết. |
| Accessibility | 4.5 | Có Semantics ở component chính; bàn phím, focus và nhãn nút biểu tượng còn thiếu. |
| Mật độ thông tin | 7.5 | Dashboard giàu thông tin nhưng vẫn đọc được; một số thẻ mobile bị ép chữ. |
| Độ hoàn thiện | 6.5 | Trạng thái lỗi thống nhất; boot, retry, chi tiết quiz và một số modal chưa hoàn thiện. |
| **Tổng** | **6.7** | **Đủ gây ấn tượng khi demo mobile; chưa đạt chất lượng web desktop và accessibility để phát hành rộng.** |

## Phát hiện ưu tiên

### P0 — sửa trước khi phát hành rộng

1. **Các thao tác cốt lõi không dùng được bằng bàn phím.** `FocusHighlightStrategy.alwaysTouch` ép toàn app vào chế độ focus cảm ứng; các đáp án quiz, mở chi tiết kết quả, nghe audio và một số liên kết đăng nhập dùng `GestureDetector` thay vì control có semantics và keyboard activation.
   - `mobile/lib/main.dart:12`
   - `mobile/lib/features/quiz/quiz_play_screen.dart:581`
   - `mobile/lib/features/quiz/quiz_result_screen.dart:162`
   - `mobile/lib/features/chat/chat_screen.dart:430`
   - `mobile/lib/features/chat/widgets/audio_bar.dart:93`
   - `mobile/lib/features/auth/register_screen.dart:318`
   - Sửa: dùng `InkWell`/`TextButton`/`FocusableActionDetector`, giữ hit target tối thiểu 44–48 px, thêm nhãn semantics và trạng thái selected/expanded.

2. **Phiếu chi tiết hiện vật vẫn có thể bị cắt và không cuộn.** Bottom sheet đầu tiên không bật `isScrollControlled`, chứa `Column(mainAxisSize: min)`, viewer cao 220 px và tối đa bốn nút. Đây là lỗi đã được quan sát ở cả màn 360×740 và desktop trong audit trước.
   - `mobile/lib/features/ar_museum/ar_museum_screen.dart:502`
   - `mobile/lib/features/ar_museum/ar_museum_screen.dart:511`
   - `mobile/lib/features/ar_museum/ar_museum_screen.dart:521`
   - Sửa: `isScrollControlled: true`, `DraggableScrollableSheet` hoặc `SingleChildScrollView`, giới hạn viewer theo chiều cao khả dụng.

3. **Onboarding vẫn hứa tính năng chưa có đầy đủ.** Trang 2 nói bật camera đặt cổ vật đúng kích thước thật dù web không hỗ trợ; trang 4 nói mỗi mốc có một thước phim dù dữ liệu hiện chỉ hoàn thiện một phần.
   - `mobile/lib/features/onboarding/huong_dan_screen.dart:77`
   - `mobile/lib/features/onboarding/huong_dan_screen.dart:90`
   - Sửa nội dung theo khả năng của từng nền tảng và chỉ giới thiệu nội dung đã có.

4. **Màn lỗi kỹ thuật lộ stack trace cho người dùng.** Khi widget lỗi, app đổi sang màn đen chứa exception và stack trace, phá vỡ toàn bộ trải nghiệm và làm lộ chi tiết triển khai.
   - `mobile/lib/main.dart:18`
   - `mobile/lib/main.dart:26`
   - Sửa: màn lỗi mang thương hiệu, câu giải thích ngắn, nút tải lại; chỉ log chi tiết ở môi trường debug/monitoring.

### P1 — ảnh hưởng lớn đến trải nghiệm

5. **Web desktop không phải layout desktop.** Từ 455 px trở lên, toàn app vẫn bị khóa trong khung rộng 430 px. Ở 1440 px, khoảng 70% chiều ngang không mang thông tin.
   - `mobile/lib/core/widgets/mobile_frame.dart:68`
   - `mobile/lib/core/widgets/mobile_frame.dart:74`
   - `mobile/lib/core/widgets/mobile_frame.dart:102`
   - Sửa: giữ khung điện thoại cho `?present=1`; web thường dùng layout 2 cột hoặc max width 960–1120 px, sidebar/rail điều hướng và vùng nội dung thích ứng.

6. **Chuyển tab làm mất trạng thái.** Comment nói dùng `IndexedStack`, nhưng implementation tạo lại một màn hình theo `_currentIndex`. Vị trí cuộn, bộ lọc và dữ liệu tạm bị mất khi đổi tab.
   - `mobile/lib/features/shell/main_navigation_shell.dart:31`
   - `mobile/lib/features/shell/main_navigation_shell.dart:89`
   - Sửa: khởi tạo năm màn một lần và dùng `IndexedStack`/`Offstage` cùng `TickerMode`.

7. **Bottom navigation khó đoán vì chỉ có hình.** Năm ảnh 3D không có nhãn nhìn thấy; nhãn chỉ tồn tại trong semantics. Người mới phải thử để biết từng biểu tượng làm gì.
   - `mobile/lib/core/widgets/app_scaffold.dart:18`
   - `mobile/lib/core/widgets/app_scaffold.dart:103`
   - Sửa: hiện nhãn 10–11 px dưới icon, hoặc ít nhất hiện nhãn của tab đang chọn. Giảm độ chi tiết icon để silhouette rõ hơn.

8. **Reduced motion chỉ bao phủ một phần hệ hiệu ứng.** Tiện ích đã có nhưng chỉ được dùng tại một số widget. Splash quay liên tục, onboarding “thở”, sóng âm, quiz timer, kết quả và phục dựng cổ vật vẫn tự chạy khi người dùng tắt animation.
   - `mobile/lib/core/utils/motion_preferences.dart:5`
   - `mobile/lib/features/auth/splash_screen.dart:30`
   - `mobile/lib/features/onboarding/huong_dan_screen.dart:337`
   - `mobile/lib/features/chat/widgets/voice_wave.dart:22`
   - `mobile/lib/features/chat/widgets/audio_bar.dart:45`
   - `mobile/lib/features/quiz/quiz_play_screen.dart:147`
   - `mobile/lib/features/quiz/quiz_result_screen.dart:48`
   - `mobile/lib/features/ar_museum/artifact_restore_dialog.dart:89`
   - Sửa: một `MotionPolicy` chung; reduced mode giữ trạng thái cuối, bỏ lặp, bỏ shake/parallax/confetti và rút chuyển màn về crossfade ngắn.

9. **Trạng thái khởi động web là nền kem trống.** `index.html` không có logo, tiến trình hoặc thông báo trước khi Flutter khởi tạo; CanvasKit và font tải chậm sẽ tạo cảm giác app bị treo.
   - `mobile/web/index.html:38`
   - `mobile/web/index.html:68`
   - Sửa: shell HTML nhẹ với logo, “Đang khơi lại trang sử…” và progress indeterminate; xóa shell khi Flutter render frame đầu tiên.

10. **Dashboard ép chữ ở mobile.** Ảnh 375 px xác nhận “PHẨM HÀM KHOA CỬ” bị cắt. Dòng điểm cần để thăng hàm cũng chỉ cho một dòng.
    - `mobile/lib/features/dashboard/dashboard_screen.dart:624`
    - `mobile/lib/features/dashboard/dashboard_screen.dart:730`
    - Sửa: bỏ ellipsis cho nhãn ngắn, cho wrap hai dòng hoặc đổi bố cục nút “Chiếu Thư” xuống hàng ở dưới 390 px.

11. **Kết quả quiz thiếu ngữ cảnh học lại.** Mỗi dòng chỉ ghi “Câu hỏi n: đúng/sai” và lời giải; model có `correctOption` nhưng màn hình không hiện câu hỏi, đáp án người dùng chọn hoặc đáp án đúng.
    - `mobile/lib/data/models.dart:220`
    - `mobile/lib/features/quiz/quiz_result_screen.dart:225`
    - `mobile/lib/features/quiz/quiz_result_screen.dart:238`
    - Sửa: lưu snapshot câu hỏi và lựa chọn trong kết quả; hiển thị câu hỏi, “Bạn chọn…”, “Đáp án đúng…” và lời giải.

12. **Nút icon thiếu nhãn hỗ trợ và tooltip.** Có 19 `IconButton` nhưng chỉ một phần có tooltip. Các nút quay lại, đóng dialog, âm lượng và gửi chat là ví dụ dễ gặp.
    - `mobile/lib/features/timeline/event_detail_screen.dart:51`
    - `mobile/lib/features/chat/chat_screen.dart:514`
    - `mobile/lib/features/chat/chat_screen.dart:732`
    - `mobile/lib/core/widgets/cinematic_player.dart:237`
    - `mobile/lib/core/widgets/strategem_collection_dialog.dart:108`
    - Sửa: tooltip tiếng Việt cụ thể cho toàn bộ nút chỉ có icon; kiểm tra tên được đọc bởi screen reader.

### P2 — đánh bóng

13. **Tương phản của chữ phụ hơi thiếu.** `inkMuted #896F62` trên `bg #FDF9F4` đạt khoảng 4.44:1, thấp hơn AA 4.5:1 cho chữ thường; `gold #D4AF37` trên nền kem chỉ khoảng 2.01:1 nên không dùng cho chữ hoặc icon mang thông tin.
    - `mobile/lib/core/theme.dart:25`
    - `mobile/lib/core/theme.dart:36`
    - Sửa: làm `inkMuted` tối hơn một nấc; dùng `goldDark` cho nội dung, giữ vàng sáng cho trang trí và bề mặt tối.

14. **Tên tab trình duyệt và PWA chưa đúng thương hiệu.** Tiêu đề và tên Apple vẫn là `historiai` chữ thường.
    - `mobile/web/index.html:30`
    - `mobile/web/index.html:36`
    - Sửa: “HistoriAI — Học sử Việt”.

15. **Các trạng thái lỗi tốt nhưng retry chưa truyền đạt tiến trình.** Năm màn dùng chung `ErrorState`, đây là điểm tốt; nút “Thử lại” nên chuyển sang loading để tránh bấm lặp và báo cho người dùng biết request đã bắt đầu.
    - `mobile/lib/core/widgets/app_widgets.dart:596`
    - `mobile/lib/core/widgets/app_widgets.dart:628`

16. **Hệ component chưa được dùng đến cùng.** `AppButton` có semantics, focus, hover và hit target tốt, nhưng nhiều màn vẫn tự dựng nút bằng `GestureDetector`/`Container`, tạo chênh lệch hành vi và accessibility.
    - `mobile/lib/core/widgets/app_widgets.dart:65`
    - `mobile/lib/core/widgets/app_widgets.dart:86`

## Hướng motion đề xuất

Mục tiêu là cảm giác “sử thi, có nghi lễ” nhưng thao tác vẫn nhanh.

| Lớp motion | Thời lượng | Áp dụng |
|---|---:|---|
| Phản hồi thao tác | 120–220 ms | Nhấn nút, chọn tab, chọn đáp án, hover/focus. |
| Chuyển trạng thái | 240–420 ms | Mở thẻ, đổi tab, timeline reveal, mở chi tiết. |
| Khoảnh khắc thành tựu | 700–1.600 ms | Thắng quiz, lên cấp, phục dựng cổ vật, nhận sắc phong. |
| Chuyển động nền | 3–8 s, biên độ nhỏ | Tàn lửa, logo thở, sóng âm; chỉ chạy khi có ý nghĩa và dừng khi offscreen. |

Ưu tiên hiệu ứng:

1. Tab active nâng nhẹ 4 px, viền vàng chạy 180 ms và nội dung crossfade 220 ms; giữ nguyên state của tab.
2. Timeline dùng shared hero từ thẻ sang ảnh bìa, node xuất hiện theo scroll; reduced motion hiện ngay.
3. Quiz giữ feedback 1,4 giây hiện có, bổ sung đáp án đúng và lời giải ngay tại chỗ trước nút “Tiếp”.
4. Kết quả quiz dùng chuỗi nghi lễ: ấn triện → điểm chạy → pháo giấy; cho phép bỏ qua bằng thao tác chạm.
5. Chat chỉ chạy waveform khi audio thực sự phát; trạng thái tạo giọng dùng skeleton/progress riêng.
6. Bảo tàng dùng drag/rotate trực tiếp cho hiện vật, glow theo tiến độ phục dựng; không chạy animation lặp khi sheet đóng.

## Ma trận màn hình

| Khu vực | Trạng thái |
|---|---|
| Splash / Onboarding | Bản sắc tốt; thiếu reduced motion, onboarding còn hứa quá tính năng. |
| Login / Register | Bố cục 375 px tốt, CTA rõ; register còn control tự dựng và icon thiếu tooltip. |
| Dashboard | Mật độ tốt, có nét riêng; text truncation ở 375 px, desktop quá hẹp. |
| Timeline / Chi tiết / Video | Hero và cấu trúc nội dung hợp lý; nút icon thiếu nhãn, trạng thái không được giữ khi đổi tab. |
| Quiz map / Play / Result | Hình ảnh có cá tính, feedback đã tốt hơn; đáp án không dùng bàn phím, màn kết quả thiếu ngữ cảnh. |
| Chat list / Chat / Voice | Loading giọng đã có; control nghe và gửi còn thiếu semantics/tooltip, waveform chưa theo reduced motion. |
| Museum / 3D / Restore | Ý tưởng mạnh nhất về mặt demo; bottom sheet chi tiết vẫn có nguy cơ cắt nội dung. |
| Premium | Minh bạch “chưa mở bán”, quyền lợi rõ; nên xem lại bằng chứng giá trị cho phụ huynh. |
| Nguồn tư liệu | Có ích và cần thiết; liên kết ngoài nên có chỉ báo mở trình duyệt ngoài. |

## Thứ tự triển khai đề xuất

1. Accessibility cơ bản: keyboard, focus, semantics, tooltip, reduced motion.
2. Sửa modal hiện vật, onboarding và màn lỗi kỹ thuật.
3. Đổi shell tab sang `IndexedStack`, thêm nhãn bottom nav.
4. Làm layout desktop thích ứng; giữ Presentation Mode riêng cho demo.
5. Hoàn thiện boot/loading/retry và kết quả quiz.
6. Chuẩn hóa motion theo bốn lớp ở trên.

## Ảnh kiểm chứng

- `output/playwright/login-cdp-1440.png`
- `output/playwright/login-cdp-375.png`
- `output/playwright/guest-home-1440.png`
- `output/playwright/guest-home-375.png`
- `output/playwright/login-tab-focus-375.png`
- `output/playwright/timeline-375.png`
- `output/playwright/quiz-map-375.png`
- `output/playwright/chat-list-375.png`
- `output/playwright/museum-375.png`

Các màn cần dữ liệu API đã được kiểm tra trạng thái lỗi trực tiếp; phần nội dung thành công được rà bằng mã nguồn và đối chiếu audit thực địa ngày 23/09. Không có tài khoản production mới nào được tạo và không có dữ liệu người dùng bị thay đổi.
