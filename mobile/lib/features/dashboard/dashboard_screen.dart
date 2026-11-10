import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/ban_moi.dart';
import '../../core/chay_nhu_app_stub.dart'
    if (dart.library.js_interop) '../../core/chay_nhu_app_web.dart';
import '../../core/lo_trinh_dau.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/ember_layer.dart';
import '../../core/widgets/giai_thich_diem.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../../data/models.dart';
import '../../core/utils/scholarly_rank.dart';
import '../../core/widgets/daily_history_card.dart';
import '../../core/widgets/royal_edict_scroll.dart';
import '../../core/widgets/scholarly_certificate_dialog.dart';
import '../../core/widgets/strategem_collection_dialog.dart';
import '../auth/auth_service.dart';
import '../premium/premium_screen.dart';
import '../auth/login_screen.dart';
import '../chat/mo_chat.dart';
import '../shell/main_navigation_shell.dart';
import '../timeline/event_detail_screen.dart';
import 'bat_dau_tu_day.dart';
import 'the_cai_iphone.dart';

/// Màn hình chính (Trang Chủ Sử Việt) — chuẩn hoá theo SPEC_UI_UX.md.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.authService,
    this.onNavigateTab,
    this.isTabRoot = true,
  });

  final AuthService authService;
  final ValueChanged<int>? onNavigateTab;
  final bool isTabRoot;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient();
  String _name = 'bạn';

  /// Bảng vàng lấy từ `/leaderboard`. Rỗng = chưa nạp được, khi đó ẩn hẳn thẻ
  /// chứ KHÔNG bịa tên: trước đây chỗ này hiện ba cái tên viết cứng trong mã
  /// ("Minh Trí", "Hoàng Nam", "Lan Anh"), nên người dùng thật leo hạng không
  /// bao giờ thấy tên mình và ba cái tên kia không bao giờ đổi.
  List<Map<String, dynamic>> _bangVang = [];
  int _level = 1;
  int _xp = 0;
  int _streak = 0;
  int _mastery = 0;
  bool _loading = true;
  bool _signedIn = false;

  HistoricalEvent? _continueEvent;
  double _continueProgress = 0;

  /// Đã từng làm quiz của sự kiện [_continueEvent] chưa — quyết định nhãn
  /// "ĐANG HỌC DỞ" hay "GỢI Ý BẮT ĐẦU".
  bool _dangHocDo = false;

  /// Tiến độ thật theo sự kiện từ /me/progress, mới học gần nhất lên đầu.
  List<Map<String, dynamic>> _tienDo = [];
  List<HistoricalEvent> _suKien = [];

  /// Sự kiện kế tiếp theo lộ trình (theo năm) mà người học chưa làm quiz — dùng
  /// cho thẻ "Bắt đầu từ đây" khi đã xong ba bước.
  HistoricalEvent? _suKienTiepTheo;

  /// Mở app đã có tiến độ học thì không phải người mới: không hiện thẻ ba bước.
  bool _daCoTienDoKhiMo = false;

  /// Hạng thật của người xem (dòng la_toi trong /leaderboard).
  int? _hangCuaToi;

  /// Đã tải xong danh sách sự kiện chưa — chưa xong thì KHÔNG hiện "chưa có mốc
  /// học nào" (trước đây hiện nhấp nháy câu đó trong lúc chờ mạng).
  bool _daTaiSuKien = false;

  /// Thẻ "Tải app Android" chỉ hiện trên web, tắt rồi thì thôi (nhớ trên máy).
  bool _anTheTaiApp = true;
  static const _khoaAnTheTai = 'an_the_tai_app';

  @override
  void initState() {
    super.initState();
    _load();
    if (kIsWeb) {
      SharedPreferences.getInstance().then((p) {
        if (mounted) setState(() => _anTheTaiApp = p.getBool(_khoaAnTheTai) ?? false);
      }).catchError((_) {});
    }
  }

  Widget _theTaiApp() => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: .6)),
        ),
        child: Row(children: [
          const Icon(Icons.android_rounded, color: AppColors.success, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Có bản cài cho Android — mở thẳng từ màn hình chính, không cần trình duyệt.',
                style: TextStyle(color: AppColors.ink, fontSize: 13.5)),
          ),
          TextButton(
            onPressed: () => launchUrl(BanMoi.trangTai, mode: LaunchMode.externalApplication),
            child: const Text('Tải app'),
          ),
          IconButton(
            tooltip: 'Ẩn',
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkMuted),
            onPressed: _anTheCai,
          ),
        ]),
      );

  void _anTheCai() {
    setState(() => _anTheTaiApp = true);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_khoaAnTheTai, true))
        .catchError((_) => false);
  }

  Future<void> _load() async {
    try {
      final d = await widget.authService.fetchMe();
      if (!mounted) return;
      setState(() {
        _signedIn = true;
        _name = (d['full_name'] as String?)?.split(' ').last ?? 'bạn';
        _level = d['level'] ?? 1;
        _xp = d['xp'] ?? 0;
        _streak = d['streak'] ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _signedIn = false;
          _loading = false;
        });
      }
    }

    // Khách: bỏ qua các lệnh cần đăng nhập (trước đây gọi vẫn gọi, nhận 3 lỗi 401).
    if (_signedIn) {
      // Lấy tiến độ học thật từ /me/progress (sửa lỗi hardcode L12)
      try {
        final rows = (await _api.get('/me/progress') as List)
            .cast<Map<String, dynamic>>()
          ..sort((a, b) => ('${b['updated_at'] ?? ''}')
              .compareTo('${a['updated_at'] ?? ''}'));
        if (mounted) {
          final total = rows.fold<int>(
              0, (sum, e) => sum + ((e['mastery'] as num?)?.toInt() ?? 0));
          setState(() {
            _daCoTienDoKhiMo = _tienDo.isEmpty &&
                rows.isNotEmpty &&
                LoTrinhDau.daXong.value.isEmpty;
            _tienDo = rows;
            _mastery = rows.isEmpty ? 0 : total ~/ rows.length;
          });
        }
      } catch (_) {}

      // Bảng vàng thật. Hỏng thì để rỗng và ẩn thẻ — thà không có còn hơn bịa.
      try {
        final rows = (await _api.get('/leaderboard?limit=3') as List)
            .cast<Map<String, dynamic>>();
        if (mounted) {
          // Máy chủ nối thêm dòng của người xem nếu nằm ngoài top — bục chỉ lấy 3 dòng đầu.
          final toi = rows.where((d) => d['la_toi'] == true).toList();
          setState(() {
            _bangVang = rows.take(3).toList();
            _hangCuaToi =
                toi.isEmpty ? null : (toi.first['rank'] as num?)?.toInt();
          });
        }
      } catch (_) {}
    }

    // "Tiếp tục học" = sự kiện học GẦN NHẤT mà chưa thông thạo hết (theo updated_at
    // thật). Chưa học gì: gợi ý sự kiện đầu tiên chưa học, tiến độ 0%. Trước đây
    // luôn là sự kiện đầu danh sách, tiến độ mặc định 45%, ép tối thiểu 20%.
    try {
      final eventsData = await _api.get('/events') as List;
      if (mounted) setState(() => _daTaiSuKien = true);
      if (mounted && eventsData.isNotEmpty) {
        final events =
            eventsData.map((e) => HistoricalEvent.fromJson(e)).toList();
        final theoSlug = {for (final e in events) e.slug: e};
        // "Đang học dở" = trận học gần nhất mà điểm quiz còn dưới 70%. Từ 70% trở
        // lên coi như đã nắm, gợi ý sang trận kế tiếp theo năm — góp ý 04/10: "giữ
        // được chuỗi vài ngày rồi mình không biết học tiếp bài nào" (trước đây phải
        // đạt 100% mới được gợi ý trận khác, nên cứ bị mời học lại một trận).
        Map<String, dynamic>? dangHoc;
        final ganNhat = _tienDo
            .where((r) => theoSlug.containsKey(r['event_slug']))
            .firstOrNull;
        if (ganNhat != null &&
            ((ganNhat['mastery'] as num?)?.toInt() ?? 0) < 70) {
          dangHoc = ganNhat;
        }
        final daHoc = {for (final r in _tienDo) r['event_slug']};
        final theoNam = [...events]..sort((a, b) => a.year.compareTo(b.year));
        setState(() {
          _suKien = events;
          _suKienTiepTheo = theoNam
              .where((e) =>
                  e.slug != BatDauTuDay.slugBatDau && !daHoc.contains(e.slug))
              .firstOrNull;
          if (dangHoc != null) {
            _continueEvent = theoSlug[dangHoc['event_slug']];
            _continueProgress =
                (((dangHoc['mastery'] as num?)?.toInt() ?? 0) / 100.0)
                    .clamp(0.0, 1.0);
            _dangHocDo = true;
          } else {
            _continueEvent = theoNam.firstWhere((e) => !daHoc.contains(e.slug),
                orElse: () => theoNam.first);
            _continueProgress = 0;
            _dangHocDo = false;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _daTaiSuKien = true);
    }
  }

  void _switchTab(int tabIndex) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(tabIndex);
    } else {
      MainNavigationScope.of(context)?.switchTab(tabIndex);
    }
  }

  Future<void> _openAccount() async {
    if (!_signedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(authService: widget.authService),
        ),
      );
      if (mounted) _load();
      return;
    }

    _switchTab(5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: EmberLayer()),
          Column(
            children: [
              _header(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.gold,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _streakChip(),
                      const SizedBox(height: 14),
                      if (_suKien.isNotEmpty && !_daCoTienDoKhiMo) ...[
                        BatDauTuDay(
                            suKien: _suKien, suKienTiepTheo: _suKienTiepTheo),
                        const SizedBox(height: 14),
                      ],
                      if (_suKien.isNotEmpty)
                        DailyHistoryCard(
                          suKien: _suKien,
                          onOpen: (e) => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EventDetailScreen(event: e)),
                          ),
                          tenViNhan: (e) => viNhanCuaSuKien[e.slug]?.$2,
                          onHoi: (e) => moChatTheoSuKien(context, e.slug,
                              cauMoDau:
                                  'Ngài kể thêm cho cháu về ${e.title} được không ạ?'),
                        ),
                      const SizedBox(height: 16),
                      _statsRow(),
                      const SizedBox(height: 16),
                      _scholarlyRankCard(),
                      // Web trên iPhone/iPad: hướng dẫn "Thêm vào MH chính" thay cho thẻ
                      // tải bản Android. Đã mở từ màn hình chính rồi thì thôi.
                      if (kIsWeb && !_anTheTaiApp && !dangChayNhuApp()) ...[
                        const SizedBox(height: 12),
                        defaultTargetPlatform == TargetPlatform.iOS
                            ? TheCaiIphone(onAn: _anTheCai)
                            : _theTaiApp(),
                      ],
                      const SizedBox(height: 24),
                      const SectionHeader(
                        title: 'Tiếp tục học',
                        subtitle: 'Mô-đun Hào Khí Đại Việt',
                        leading:
                            ChimLacMotif(size: 56, color: AppColors.redPrimary),
                      ),
                      const SizedBox(height: 12),
                      _continueCard(),
                      const SizedBox(height: 20),
                      const DongSonWaveDivider(
                          color: AppColors.goldImperial,
                          height: 16,
                          opacity: 0.45),
                      const SizedBox(height: 16),
                      const SectionHeader(
                        title: 'Khám Phá Sử Việt',
                        subtitle: 'Học lịch sử qua trải nghiệm trực quan',
                        leading: ChimLacMotif(size: 56, color: AppColors.cta),
                      ),
                      const SizedBox(height: 12),
                      _exploreGrid(),
                      const SizedBox(height: 12),
                      _bangPremium(),
                      const SizedBox(height: 12),
                      _strategemBanner(),
                      const SizedBox(height: 20),
                      const DongSonWaveDivider(
                          color: AppColors.goldImperial,
                          height: 16,
                          opacity: 0.45),
                      const SizedBox(height: 16),
                      const SectionHeader(
                        title: 'Chiến Tích Của Bạn',
                        subtitle: 'Những trận bạn đã làm quiz gần đây',
                        leading: VietnameseFestivalFlag(size: 22),
                      ),
                      const SizedBox(height: 12),
                      _recentList(),
                      const SizedBox(height: 20),
                      const DongSonWaveDivider(
                          color: AppColors.goldImperial,
                          height: 16,
                          opacity: 0.45),
                      const SizedBox(height: 16),
                      const SectionHeader(
                        title: 'Bảng Vàng Thi Đua',
                        subtitle: 'Xếp theo tổng điểm tích luỹ',
                        leading: DoubleFestivalFlags(size: 24),
                      ),
                      const SizedBox(height: 12),
                      if (_bangVang.isNotEmpty) _leaderboardCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: widget.isTabRoot
          ? null
          : AppBottomNav(
              current: 0,
              onTap: (i) => _switchTab(i),
            ),
    );
  }

  Widget _header() => Container(
        decoration: const BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x25000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Nền hoa văn trống đồng Đông Sơn chìm tinh tế
            const Positioned(
              right: -30,
              top: -20,
              width: 240,
              height: 240,
              child: Opacity(
                opacity: 0.12,
                child: DongSonBackground(size: 240),
              ),
            ),
            // Đàn Chim Lạc Đông Sơn sải cánh bay lượn
            const Positioned(
              left: -10,
              top: 48,
              child: ChimLacFlightFlock(
                width: 170,
                color: AppColors.goldBright,
                opacity: 0.22,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            ChimLacMotif(size: 58, color: AppColors.goldBright),
                            SizedBox(width: 8),
                            Text(
                              'HISTORIAI',
                              style: TextStyle(
                                fontFamily: 'PlayfairDisplay',
                                color: AppColors.goldBright,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _openAccount,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.goldBright, width: 1.8),
                                ),
                                child: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.redDark,
                                  child: Icon(Icons.person,
                                      color: AppColors.goldBright, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Chào, $_name',
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Cùng sống lại những trang sử hào hùng Đại Việt',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.onRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  void _giaiThichDiem() => showGiaiThichDiem(context,
      xp: _xp, streak: _streak, daDangNhap: _signedIn);

  Widget _streakChip() => Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          label:
              'Chuỗi $_streak ngày. Chạm để xem chuỗi ngày và điểm dùng để làm gì',
          child: GestureDetector(
            onTap: _giaiThichDiem,
            child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF3B120C),
                Color(0xFF220805),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFFFB300).withValues(alpha: 0.38),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnimatedStreakFire(size: 20),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  text: 'Chuỗi ',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                  children: [
                    TextSpan(
                      text: '$_streak ngày',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.help_outline_rounded,
                  size: 15, color: Color(0xCCFFFFFF)),
            ],
          ),
        ),
          ),
        ),
      );

  Widget _statsRow() => Row(
        children: [
          StatTile(
            label: 'Cấp độ',
            value: _loading ? '—' : 'Cấp $_level',
            icon: Icons.shield_outlined,
            accentColor: AppColors.red,
            onTap: _giaiThichDiem,
          ),
          const SizedBox(width: 10),
          StatTile(
            label: 'Điểm tích luỹ',
            value: _loading ? '—' : '$_xp',
            icon: Icons.military_tech_outlined,
            accentColor: AppColors.gold,
            onTap: _giaiThichDiem,
          ),
          const SizedBox(width: 10),
          StatTile(
            label: 'Thông thạo',
            value: _loading ? '—' : '$_mastery%',
            icon: Icons.workspace_premium_outlined,
            accentColor: AppColors.cta,
          ),
        ],
      );

  Widget _scholarlyRankCard() {
    final rank = ScholarlyRank.fromXp(_xp);
    final progress = rank.progressInCurrentRank(_xp);
    final xpNeeded = rank.xpToNextRank(_xp);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.paperCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldImperial, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldImperial.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Opacity(
              opacity: 0.08,
              child: Icon(rank.icon, size: 110, color: AppColors.goldDark),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.redDeepest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.goldImperial, width: 1.2),
                          ),
                          child: rank.huyHieu(co: 20, mau: AppColors.goldLight),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DANH HIỆU HỌC TẬP',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.redPrimary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                rank.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headingSmall.copyWith(
                                  color: AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                rank.nghia,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Danh hiệu là gì?',
                            icon: const Icon(Icons.help_outline_rounded,
                                size: 18, color: AppColors.goldDark),
                            onPressed: _giaiThichDiem,
                          ),
                          IconButton(
                            tooltip: 'Tạo ảnh khoe danh hiệu (khổ Story 9:16)',
                            icon: const Icon(Icons.share_rounded,
                                size: 18, color: AppColors.goldDark),
                            onPressed: () {
                              showScholarlyCertificateDialog(
                                context,
                                studentName: _name,
                                rankTitle: rank.title,
                                rankStage: rank.stage,
                                xp: _xp,
                                motto: rank.motto,
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton.icon(
                            onPressed: () {
                              showRoyalEdictDialog(
                                context,
                                title: rank.edictTitle,
                                recipient: _name,
                                rankTitle: '${rank.title} • ${rank.stage}',
                                body: rank.edictBody,
                                motto: rank.motto,
                              );
                            },
                            icon: const Icon(Icons.auto_awesome_rounded,
                                size: 14, color: AppColors.goldDark),
                            label: const Text(
                              'Giấy khen',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                                color: AppColors.goldDark,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.goldImperial, width: 1.2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  rank.description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      rank.stage,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        xpNeeded > 0
                            ? 'Còn $xpNeeded điểm để lên danh hiệu mới'
                            : 'Đã đạt danh hiệu cao nhất',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: AppColors.paperCreamDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.goldImperial),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueCard() {
    if (_continueEvent == null && !_loading && _daTaiSuKien) {
      return EmptyState(
        title: 'Chưa có mốc học nào',
        message:
            'Bạn chưa bắt đầu mốc nào. Hãy chọn một trận đánh để vào học ngay.',
        actionLabel: 'Xem Dòng thời gian',
        onAction: () => _switchTab(1),
      );
    }

    // Lúc chưa tải xong thì ghi "Đang tải…", đừng dựng sẵn Bạch Đằng 938: người
    // đang học dở trận khác sẽ thấy thẻ nhảy từ trận này sang trận kia.
    final title = _continueEvent?.title ?? 'Đang tải…';
    final summary = _continueEvent?.summary ?? '';
    final thumbUrl = _continueEvent?.bannerAsset ?? _continueEvent?.thumbnailUrl;
    // Banner đã in sẵn tên trận, năm, triều đại: không phủ gradient, không viết lại
    // tiêu đề bên dưới, và nhãn "GỢI Ý BẮT ĐẦU" chuyển xuống phần chữ cho khỏi
    // đè lên ảnh.
    final coBanner = _continueEvent?.hasIntegratedBanner == true;
    final nhan = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _dangHocDo ? 'ĐANG HỌC DỞ' : 'GỢI Ý BẮT ĐẦU',
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.goldBright,
          letterSpacing: 0.8,
        ),
      ),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () {
        if (_continueEvent != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(event: _continueEvent!),
            ),
          );
        } else {
          _switchTab(1);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: _continueEvent?.bannerAspectRatio ?? (1024 / 426),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(
                  url: thumbUrl,
                  borderRadius: 0,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: coBanner ? title : null,
                ),
                if (!coBanner) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.redDeepest.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(bottom: 10, left: 14, child: nhan),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (coBanner)
                  nhan
                else
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      color: AppColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                SizedBox(height: coBanner ? 8 : 4),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.inkSoft,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _dangHocDo
                          ? 'Thông thạo (điểm quiz cao nhất)'
                          : 'Chưa làm quiz',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.inkSoft),
                    ),
                    Text(
                      '${(_continueProgress * 100).toInt()}%',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cta,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _continueProgress,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.cta),
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Tiếp tục vào bài học',
                  icon: Icons.arrow_forward_rounded,
                  fullWidth: true,
                  onPressed: () {
                    if (_continueEvent != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EventDetailScreen(event: _continueEvent!),
                        ),
                      );
                    } else {
                      _switchTab(1);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exploreGrid() {
    final items = <({
      Key key,
      String assetPath,
      String title,
      String subtitle,
      int tabIndex,
    })>[
      (
        key: const Key('explore-card-timeline'),
        assetPath: 'assets/figures3d/item/'
            'isolate_only_the_scroll_timeline_icon_from_top_left_an_ancient_vietnamese.png',
        title: 'Dòng thời gian',
        subtitle: 'Các trận đánh lớn theo năm',
        tabIndex: 1,
      ),
      (
        key: const Key('explore-card-museum'),
        assetPath: 'assets/figures3d/item/'
            'isolate_only_the_ancient_bronze_drum_icon_from_top_right_an_ancient_dong_son.png',
        title: 'Bảo tàng 3D',
        subtitle: 'Xoay cổ vật, xem từng góc',
        tabIndex: 4,
      ),
      (
        key: const Key('explore-card-chat'),
        assetPath: 'assets/figures3d/item/'
            'isolate_the_warrior_helmet_and_speech_bubble_icon_on_a_completely_clean_solid.png',
        title: 'Hỏi vĩ nhân',
        subtitle: 'Hỏi chuyện nhân vật lịch sử',
        tabIndex: 3,
      ),
      (
        key: const Key('explore-card-quiz'),
        assetPath: 'assets/figures3d/item/'
            'isolate_only_the_golden_arena_quiz_trophy_icon_from_bottom_right_golden.png',
        title: 'Đấu trường',
        subtitle: 'Làm quiz, tích điểm',
        tabIndex: 2,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.72,
      children: [
        for (final item in items)
          Semantics(
            button: true,
            label: 'Mở ${item.title}. ${item.subtitle}',
            onTap: () => _switchTab(item.tabIndex),
            child: ExcludeSemantics(
              child: AppCard(
                key: item.key,
                borderRadius: 18,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                onTap: () => _switchTab(item.tabIndex),
                child: Column(
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            item.assetPath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        color: AppColors.redDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.inkSoft,
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bangPremium() {
    return Semantics(
      button: true,
      label: 'Xem HistoriAI Premium',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.red, AppColors.redDeepest],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
            boxShadow: appSoftShadow,
          ),
          child: const Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: AppColors.goldBright, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HistoriAI Premium',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        color: AppColors.goldBright,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Mở trọn kho sử Việt · 39.000đ/tháng',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFFF3D9C4),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.goldBright, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _strategemBanner() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => showStrategemCollectionDialog(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.redDeepest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.goldImperial, width: 1.2),
            ),
            child: const Icon(Icons.auto_stories_rounded,
                color: AppColors.goldLight, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CẨM NANG KẾ SÁCH',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.redPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.goldImperial,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '6 kế sách',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.redDeepest,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Cách người xưa thắng trận & bài học hôm nay',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.redPrimary),
        ],
      ),
    );
  }

  /// Chiến tích THẬT: sự kiện đã làm quiz, mới nhất trước. Trước đây là ba trận
  /// viết cứng kèm dấu tích xong/chưa giả.
  Widget _recentList() {
    if (_tienDo.isEmpty) {
      return EmptyState(
        title: _signedIn
            ? 'Chưa có chiến tích nào'
            : 'Đăng nhập để lưu chiến tích',
        message: _signedIn
            ? 'Làm quiz một trận bất kỳ — trận đó sẽ hiện ở đây kèm mức thông thạo.'
            : 'Bài quiz bạn làm sẽ được ghi vào tài khoản và hiện ở đây.',
        actionLabel: 'Vào Đấu trường',
        onAction: () => _switchTab(2),
      );
    }
    final recent = [
      for (final r in _tienDo.take(3))
        (
          '${r['event_title'] ?? r['event_slug']}',
          'Thông thạo ${(r['mastery'] as num?)?.toInt() ?? 0}% · '
              'đúng tối đa ${(r['quiz_best_score'] as num?)?.toInt() ?? 0} câu',
          ((r['mastery'] as num?)?.toInt() ?? 0) >= 100,
        ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        children: recent.map((r) {
          return ListTile(
            dense: true,
            leading: Icon(
              r.$3 ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: r.$3 ? AppColors.success : AppColors.inkMuted,
              size: 20,
            ),
            title: Text(
              r.$1,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              r.$2,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.inkSoft,
                  fontSize: 11.5),
            ),
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.inkMuted, size: 18),
            onTap: () => _switchTab(1),
          );
        }).toList(),
      ),
    );
  }

  Widget _leaderboardCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.redDeepest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.goldImperial.withValues(alpha: 0.6), width: 1.5),
        boxShadow: appSoftShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.workspace_premium_rounded,
                  color: AppColors.goldLight, size: 18),
              SizedBox(width: 8),
              Text(
                'BẢNG VÀNG KHOA CỬ THĂNG LONG',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  color: AppColors.goldLight,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Bục thứ 2 – 1 – 3 theo lối xếp bục truyền thống, và chỉ dựng
              // bục nào thật sự có người: ba người đầu tiên của lớp không nên
              // bị ghép cùng hai cái tên ma.
              if (_bangVang.length > 1)
                _bucThat(1, 'Bảng Nhãn', 65,
                    AppColors.onRed.withValues(alpha: 0.45)),
              if (_bangVang.isNotEmpty)
                _bucThat(0, 'Trạng Nguyên', 92, AppColors.goldBright),
              if (_bangVang.length > 2)
                _bucThat(
                    2, 'Thám Hoa', 50, AppColors.onRed.withValues(alpha: 0.35)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.goldBright,
                  child: Icon(Icons.person, size: 16, color: AppColors.redDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _hangCuaToi == null
                        ? _name
                        : '$_name · Hạng $_hangCuaToi của bạn',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$_xp Điểm',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.goldBright,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dựng một bục từ dòng thứ [i] của bảng vàng thật.
  Widget _bucThat(int i, String hang, double cao, Color mau) {
    final d = _bangVang[i];
    return _podium(
      hang,
      (d['ten'] as String?) ?? 'Ẩn danh',
      '${d['xp'] ?? 0}',
      cao,
      mau,
      laToi: d['la_toi'] == true,
    );
  }

  Widget _podium(String rank, String name, String pts, double h, Color color,
      {bool laToi = false}) {
    final isTop1 = rank == 'Trạng Nguyên';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isTop1)
          const Icon(Icons.emoji_events, color: AppColors.goldBright, size: 24),
        Text(
          laToi ? '$name (bạn)' : name,
          style: TextStyle(
            fontFamily: 'Montserrat',
            // Tô vàng dòng của chính người đang xem. Cờ này do backend trả về
            // chứ không so tên — tên đã rút gọn nên so tên là sai khi trùng.
            color: laToi ? AppColors.goldBright : Colors.white,
            fontSize: 11,
            fontWeight: laToi ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$pts đ',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: isTop1
                ? AppColors.goldBright
                : AppColors.onRed.withValues(alpha: 0.8),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 78,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            rank,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: isTop1 ? AppColors.redDark : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ),
      ],
    );
  }
}
