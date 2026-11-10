# Mobile-first UI/UX Implementation Plan

## Làm lại kiểm tra trên lớp — Imperial Light

Mục tiêu: học sinh vào nhanh, chơi rõ nhịp, nhận bảng vàng và giấy đẹp;
thầy cô soạn/mở/điều khiển dễ hiểu, màn chiếu đọc được từ xa.
Giữ API, WebSocket, cách nộp, điểm và đồng hạng; không sửa backend.

Tệp: `mobile/lib/features/lop_hoc/**`, test lớp học, bộ dữ liệu giả và
ảnh web tại `output/playwright/`; giữ mọi lối vào ngoài tính năng.

- [x] Đọc toàn bộ lớp học, theme, ảnh đại diện, test và hợp đồng bảng vàng.
- [x] Đợt 1: widget chung, màu + hình, đồng hồ, ảnh và bảng xếp hạng.
- [x] Đợt 2: vào phòng, bài tập/trực tiếp, bảng vàng, giấy 4:5 và 9:16.
- [x] Đợt 3: màn chiếu 16:9, toàn màn hình và điều khiển.
- [x] Đợt 4: trang giáo viên, chọn đề, dán AI, phòng, lớp và thống kê.
- [x] Test hẹp từng đợt; bổ sung tên dài/null/320/412/1280, ngoài top,
      giấy hạng thấp, tắt animation; chạy analyze và toàn bộ test.
- [x] Dựng web dữ liệu giả; chụp/kiểm ảnh học sinh 412, màn chiếu 1280×720.
- [x] Commit theo đợt; bốn PR có mô tả, ảnh và yêu cầu backend: #77 → #78 → #79 → #80.

Thiết kế: nền giấy kem, đỏ son/gold cho sân chơi và vinh danh, cam cho CTA;
PlayfairDisplay 700, Montserrat 600, Inter 400. Hình đáp án A tam giác đỏ,
B thoi vàng đậm, C tròn lục, D vuông nâu; không phụ thuộc màu để báo đúng/sai.
Phản hồi 600 ms, bảng hạng 350 ms; khi tắt hiệu ứng dựng trực tiếp widget tĩnh.
Màn chơi có đáp án ở vùng dưới để bấm bằng ngón cái; câu dài được chứa trong
vùng riêng. Giáo viên dùng vùng nội dung giới hạn chiều rộng, CTA rõ ở đáy.

Hoàn tất khi analyze 0 error/warning, toàn bộ test xanh, không mất lối vào,
không sửa phần cấm, ảnh được kiểm và hồ sơ PR ghi trung thực phần còn thiếu.

## Goal

Implement the highest-impact findings from `UI_UX_AUDIT.md` for mobile users while preserving API signatures, data models, analytics calls, and presentation mode behavior.

## Files

- `mobile/lib/main.dart` — branded widget error and keyboard focus behavior
- `mobile/lib/core/widgets/app_scaffold.dart` — labeled mobile bottom navigation
- `mobile/lib/features/shell/main_navigation_shell.dart` — preserve tab state
- `mobile/lib/features/onboarding/huong_dan_screen.dart` — accurate feature copy and reduced motion
- `mobile/lib/features/ar_museum/ar_museum_screen.dart` — scrollable artifact details
- `mobile/lib/features/dashboard/dashboard_screen.dart` — compact mobile rank header
- `mobile/lib/features/quiz/quiz_play_screen.dart` and `quiz_result_screen.dart` — keyboard-friendly choices and useful answer review
- `mobile/lib/features/auth/register_screen.dart` and chat widgets — keyboard/tap accessibility
- `mobile/lib/features/auth/splash_screen.dart`, `mobile/lib/features/quiz/**` — reduced-motion behavior
- `mobile/lib/features/timeline/event_detail_screen.dart` and shared controls — Vietnamese tooltips
- `mobile/web/index.html`, `manifest.json` — installed app/browser title
- `mobile/lib/core/widgets/app_scaffold.dart` — compact vector tab icons and legible labels
- `mobile/lib/features/shell/main_navigation_shell.dart` — guest sign-in row above the six tabs
- `mobile/lib/features/profile/profile_settings_screen.dart` — learner profile and app preferences
- `mobile/lib/core/app_preferences.dart`, `mobile/lib/core/widgets/ember_layer.dart` — saved background effect preference
- `mobile/lib/main.dart` — load app preferences before first frame
- `docs/SPEC_UI_UX.md` — update navigation model to six tabs
- `mobile/assets/icons/nav/*.svg` — account icon and login symbol
- `mobile/pubspec.yaml` / `pubspec.lock` — SVG rendering dependency
- `mobile/assets/icons/nav/*.svg` — simplify and recolor navigation symbols for small mobile sizes

## Steps

- [x] Review project SPEC and completed UI/UX audit.
- [x] Fix mobile navigation, global error presentation, and onboarding claims.
- [x] Fix mobile content overflow and improve quiz review and keyboard interactions.
- [x] Respect reduced motion in touched looping animations and quiz result effects.
- [x] Add Vietnamese tooltips to icon-only controls in the primary flows.
- [x] Run static analysis and build; capture the 375px mobile navigation screenshot.
- [x] Inspect and integrate the six supplied SVG icons.
- [x] Add a guest sign-in row above the bottom tabs and refine icon/label sizing and active states.
- [x] Analyze, build and screenshot the updated 375px guest state; source-check the signed-in hide condition.
- [x] Replace monochrome traced tab icons with compact multicolor vectors; preserve detail colors in Flutter.
- [x] Rebuild and review the 375px screenshot after recoloring.
- [x] Restore the original 3D PNG artwork for the five existing navigation tabs and review at 375px.
- [x] Add a sixth profile tab with a custom icon matching the original 3D gold artwork.
- [x] Build a mobile profile and app settings screen using existing account/session data.
- [x] Build web and screenshot the six-tab profile flow at 375px.
- [x] Replace the flat profile medallion with a 3D scholar bust that matches the original icon artwork.
- [x] Shorten the timeline tab label to prevent a lone-word wrap.
- [x] Rebuild and review the 375px and 430px navigation/profile previews.

## Done criteria

- Six navigation tabs and primary profile/settings interactions remain usable at 375px.
- Long artifact content can be reached by scrolling and no stack trace appears in the UI.
- No API/model changes or analytics calls are removed.
- Flutter analysis/build complete; guest navigation and profile screenshots reviewed at 375px (`output/playwright/mobile-nav-original-icons-375.png`, `output/playwright/mobile-profile-settings-guest-375.png`). The signed-in profile state depends on the backend `/auth/me` endpoint and was not available in this preview.
- Current scholar profile previews reviewed at 375px and 430px (`output/playwright/mobile-profile-settings-scholar-375.png`, `output/playwright/mobile-profile-settings-scholar-430.png`).
