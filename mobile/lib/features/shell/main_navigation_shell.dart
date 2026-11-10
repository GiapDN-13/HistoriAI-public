import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/ban_moi.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../ar_museum/ar_museum_screen.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../chat/chat_list_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_settings_screen.dart';
import '../quiz/quiz_map_screen.dart';
import '../timeline/timeline_screen.dart';

/// Scope cung cấp quyền truy cập chuyển tab từ bất kỳ widget con nào
class MainNavigationScope extends InheritedWidget {
  const MainNavigationScope({
    super.key,
    required this.currentIndex,
    required this.switchTab,
    required super.child,
  });

  final int currentIndex;
  final ValueChanged<int> switchTab;

  static MainNavigationScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainNavigationScope>();

  @override
  bool updateShouldNotify(MainNavigationScope oldWidget) =>
      currentIndex != oldWidget.currentIndex;
}

/// Shell điều hướng trung tâm 6 tab theo Mục 5.1 SPEC_UI_UX.md.
/// Dùng IndexedStack để giữ nguyên vị trí cuộn trang, bộ lọc và trạng thái của từng tab.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    required this.authService,
    this.initialTab = 0,
  });

  final AuthService authService;
  final int initialTab;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  late Future<String?> _storedToken;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, 5);
    _storedToken = widget.authService.storedToken;
    // Bản cài Android: hỏi tải bản mới nếu có (web tự cập nhật, bỏ qua).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BanMoi.kiem(context);
    });
  }

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  void _openLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(authService: widget.authService),
      ),
    );
  }

  Widget _guestSignInEntry() => FutureBuilder<String?>(
        future: _storedToken,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              (snapshot.data?.isNotEmpty ?? false)) {
            return const SizedBox.shrink();
          }

          return ColoredBox(
            color: AppColors.red,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.redDeepest.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.goldImperial.withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/nav/06_login.svg',
                      width: 27,
                      height: 27,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đang dùng thử',
                            style: TextStyle(
                              color: AppColors.onRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Đăng nhập để lưu tiến độ học',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.onRed,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _openLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.redDeepest,
                        backgroundColor: AppColors.goldBright,
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return DashboardScreen(
          authService: widget.authService,
          onNavigateTab: _switchTab,
        );
      case 1:
        return const TimelineScreen(isTabRoot: true);
      case 2:
        return const QuizMapScreen(isTabRoot: true);
      case 3:
        return const ChatListScreen(isTabRoot: true);
      case 4:
        return const ArMuseumScreen(isTabRoot: true);
      case 5:
      default:
        return ProfileSettingsScreen(authService: widget.authService);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: MainNavigationScope(
        currentIndex: _currentIndex,
        switchTab: _switchTab,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: IndexedStack(
            index: _currentIndex,
            children: List.generate(
              6,
              (index) => TickerMode(
                enabled: index == _currentIndex,
                child: _buildScreen(index),
              ),
            ),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentIndex != 5) _guestSignInEntry(),
              AppBottomNav(
                current: _currentIndex,
                onTap: _switchTab,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
