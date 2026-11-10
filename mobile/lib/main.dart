import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/app_preferences.dart';
import 'core/analytics.dart';
import 'core/nguon_truy_cap.dart';
import 'core/api_client.dart';
import 'core/lo_trinh_dau.dart';
import 'core/theme.dart';
import 'core/widgets/mobile_frame.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/splash_screen.dart';
import 'features/lop_hoc/vao_phong_screen.dart';

/// Mã phòng trong đường dẫn web "/vao/123456" (link trong QR). Ngoài web: null.
String? _maPhongTuLink() {
  if (!kIsWeb) return null;
  final m = RegExp(r'^/vao/(\d{6})/?$').firstMatch(Uri.base.path);
  return m?.group(1);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.load();
  await LoTrinhDau.khoiDong();
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER_ERROR: ${details.exception}');
    debugPrint('STACK_TRACE: ${details.stack}');
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_stories_rounded,
                  color: AppColors.red, size: 36),
              const SizedBox(height: 12),
              Text('Trang này chưa hiển thị được',
                  textAlign: TextAlign.center,
                  style: AppTypography.headingSmall
                      .copyWith(color: AppColors.ink)),
              const SizedBox(height: 8),
              const Text('Hãy quay lại hoặc thử mở lại màn hình.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  };
  if (_sentryDsn.isEmpty) {
    runApp(const HistoriAIApp());
    return;
  }
  await SentryFlutter.init(caiSentry, appRunner: () => runApp(const HistoriAIApp()));
}

/// Theo dõi lỗi — dựng kèm `--dart-define=SENTRY_DSN=...` mới bật; trống = tắt hẳn.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Người dùng phần lớn là học sinh vị thành niên nên gửi ÍT nhất có thể:
/// không thông tin cá nhân, không ảnh chụp màn hình, không đo hiệu năng.
/// (Nhớ bật "Prevent Storing of IP Addresses" trong cài đặt dự án Sentry.)
@visibleForTesting
void caiSentry(SentryFlutterOptions o) {
  o
    ..dsn = _sentryDsn
    ..environment = 'production'
    ..sendDefaultPii = false
    ..attachScreenshot = false
    ..tracesSampleRate = 0
    ..beforeSend = locSuKienSentry;
}

/// Bỏ header và chuỗi truy vấn (?key= của dashboard, mã nguồn utm) khỏi sự kiện.
/// App không bao giờ gọi Sentry.configureScope(setUser) nên sự kiện không mang
/// danh tính người dùng.
@visibleForTesting
SentryEvent? locSuKienSentry(SentryEvent e, Hint _) {
  final req = e.request;
  return e.copyWith(
    request: req == null
        ? null
        : SentryRequest(
            url: req.url?.split('?').first,
            method: req.method,
          ),
  );
}

class HistoriAIApp extends StatefulWidget {
  const HistoriAIApp({super.key});

  @override
  State<HistoriAIApp> createState() => _HistoriAIAppState();
}

class _HistoriAIAppState extends State<HistoriAIApp> {
  late final ApiClient _apiClient;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _authService = AuthService(_apiClient);
    // Bật đo lường trước khi vẽ màn đầu tiên, rồi ghi ngay một lượt mở app.
    // app_open mang theo nguồn truy cập: "nguon" là nguồn ĐẦU TIÊN của máy này
    // (tính công cho kênh đã mang người dùng về), "nguon_phien" là của lần mở này.
    Analytics.instance.khoiDong(_apiClient).then((_) async {
      final n = await NguonTruyCap.docVaNho();
      Analytics.instance.log(Ev.appOpen, them: {
        ...n.dauTien.thanhParams(),
        'nguon_phien': n.hienTai.nguon,
        'lan_dau': n.lanDau,
      });
    });
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: MaterialApp(
        title: 'HistoriAI',
        debugShowCheckedModeBanner: false,
        theme: buildHistoriAITheme(),
        // Trên web/desktop màn rộng: bọc app trong khung điện thoại (max-width)
        // để giao diện không bị kéo giãn full-width. Trên mobile: hiển thị bình thường.
        builder: (context, child) => FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: MobileFrame(child: child ?? const SizedBox()),
        ),
        // Quét QR phòng kiểm tra (historiai.org/vao/<mã>) → vào thẳng màn vào phòng, bỏ qua
        // màn chờ và hướng dẫn: học sinh trong lớp cần vào bài ngay.
        home: _maPhongTuLink() != null
            ? VaoPhongScreen(authService: _authService, ma: _maPhongTuLink())
            : SplashScreen(authService: _authService),
      ),
    );
  }
}
