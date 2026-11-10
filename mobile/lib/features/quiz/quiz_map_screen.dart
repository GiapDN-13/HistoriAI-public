import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/chi_dan.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../../data/models.dart';
import 'quiz_play_screen.dart';
import '../lop_hoc/vao_phong_screen.dart';

/// Bản đồ chiến dịch Đấu Trường Sử Việt (Saga Path).
/// Thay thế hoàn toàn thẻ xám lạnh L4 bằng sa bàn chiến dịch hào khí Đại Việt,
/// Sửa hardcode tên người chơi L12, gắn thanh tab dưới L3.
class QuizMapScreen extends StatefulWidget {
  const QuizMapScreen({super.key, this.isTabRoot = true});
  final bool isTabRoot;

  @override
  State<QuizMapScreen> createState() => _QuizMapScreenState();
}

class _QuizMapScreenState extends State<QuizMapScreen> {
  final _api = ApiClient();
  List<HistoricalEvent> _events = [];
  bool _loading = true;
  String? _error;
  String _userName = 'Khách';
  int _userXp = 0;
  int _streak = 0;

  /// Tiến độ thật theo sự kiện (slug → {mastery, quiz_best_score}) từ /me/progress.
  Map<String, Map<String, dynamic>> _tienDo = {};

  final _khoaDiem = GlobalKey();
  final _khoaTranDau = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _daXinChiDan = false;

  /// Gọi từ lúc nội dung được dựng — xem ghi chú cùng tên ở màn Bảo tàng.
  void _chiDan() {
    if (_daXinChiDan || !mounted || _events.isEmpty) return;
    _daXinChiDan = true;
    ChiDan.chay(context, khoa: 'dau-truong-v1', cacBuoc: [
      BuocChiDan(
        khoa: _khoaTranDau,
        tieuDe: 'Mỗi trận một loạt câu hỏi',
        noiDung: 'Thẻ ghi rõ có bao nhiêu câu và mỗi câu bao lâu. Bấm "Vào '
            'trận" là bắt đầu — trả lời sai thì được giảng lại ngay tại chỗ.',
      ),
      BuocChiDan(
        khoa: _khoaDiem,
        tieuDe: 'Điểm dùng để lên danh hiệu',
        noiDung: 'Mỗi câu trả lời đúng LẦN ĐẦU được 10 điểm (làm lại câu đã '
            'đúng thì không cộng nữa). Đủ điểm thì lên danh hiệu mới.',
      ),
    ]);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Lấy thông tin người dùng thật từ backend
    try {
      final me = await _api.get('/auth/me') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _userName =
              (me['full_name'] as String?)?.split(' ').last ?? 'Học sinh';
          _userXp = me['xp'] ?? 0;
          _streak = me['streak'] ?? 0;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userName = 'Khách';
        });
      }
    }

    // Điểm tốt nhất từng trận — để thẻ trận ghi "đã đúng 4/5" thay vì trông như chưa chơi.
    if (_userName != 'Khách') {
      try {
        final rows = await _api.get('/me/progress') as List;
        if (mounted) {
          setState(() => _tienDo = {
                for (final r in rows.cast<Map<String, dynamic>>())
                  if (r['event_slug'] != null) r['event_slug'] as String: r,
              });
        }
      } catch (_) {}
    }

    try {
      final data = await _api.get('/events') as List;
      final events = data.map((e) => HistoricalEvent.fromJson(e)).toList();
      // Chỉ bày trận nào thật sự có câu hỏi. Cờ 'quiz' trong features là ý định,
      // còn quizCount là thực tế — bày một trận rỗng thì người học bấm vào là
      // gặp màn trắng.
      final filtered = events.where((e) {
        if (e.quizCount <= 0) return false;
        if (e.features == null) return true;
        return e.features!.contains('quiz') || e.features == '';
      }).toList();

      if (!mounted) return;
      setState(() {
        _events = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách chiến dịch đấu trường.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            VietnameseFestivalFlag(size: 20),
            SizedBox(width: 8),
            Text(
              'ĐẤU TRƯỜNG SỬ VIỆT',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(width: 8),
            ChimLacMotif(size: 56, color: AppColors.goldBright, flip: true),
          ],
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DongSonBackground(size: 340, opacity: 0.035),
          ),
          const Positioned(
            left: 4,
            bottom: 18,
            child: CommandFlagBackgroundMotif(width: 132, opacity: 0.09),
          ),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _chiDan());
    if (_loading) {
      return const LoadingSkeleton(cardCount: 4, cardHeight: 110);
    }
    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _load,
      );
    }
    if (_events.isEmpty) {
      return const EmptyState(
        title: 'Chưa có chiến dịch',
        message:
            'Kho câu hỏi đang được bổ sung. Trong lúc chờ, hãy xem các mốc ở Dòng thời gian.',
        icon: Icons.emoji_events_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Trạng thái đấu sĩ (Status bar)
          KeyedSubtree(key: _khoaDiem, child: _playerBanner()),
          const SizedBox(height: 18),

          // Lối vào phòng kiểm tra của lớp (thầy cô đưa mã 6 số)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VaoPhongScreen())),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Vào phòng kiểm tra của lớp'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 18),

          // Bản đồ hành trình các chiến dịch (Saga Path)
          const SectionHeader(
            title: 'Hành Trình Chinh Phục',
            subtitle: 'Vượt qua từng trận đánh để lưu danh sử sách',
          ),
          const SizedBox(height: 14),

          // Thẻ trận đầu tiên mang khoá để bộ chỉ dẫn khoét sáng đúng nó.
          for (var i = 0; i < _events.length; i++)
            i == 0
                ? KeyedSubtree(
                    key: _khoaTranDau, child: _campaignNode(_events[i]))
                : _campaignNode(_events[i]),
        ],
      ),
    );
  }

  Widget _playerBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: imperialRedGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: appSoftShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBright, width: 2),
            ),
            child: const CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.redDark,
              child: Icon(Icons.person, color: AppColors.goldBright, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userName == 'Khách'
                      ? 'Chơi thử · Đăng nhập là bài được cộng vào tài khoản'
                      : 'Đấu sĩ Hào khí Đại Việt',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.onRed,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_streak > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: AppColors.goldBright, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$_streak ngày',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          color: AppColors.goldBright,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech_outlined,
                        color: AppColors.goldBright, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '$_userXp Điểm',
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
        ],
      ),
    );
  }

  Widget _campaignNode(HistoricalEvent e) {
    // Thẻ chiến dịch căn trực tiếp theo lề nội dung, không giữ mốc số ẩn.
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => _enterQuiz(e),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh bìa chiến dịch theo đúng tỷ lệ tệp ảnh (2.4:1)
            AspectRatio(
              aspectRatio: e.hasIntegratedBanner ? e.bannerAspectRatio : (16 / 9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(
                    url: e.bannerAsset ?? e.thumbnailUrl,
                    borderRadius: 0,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    semanticLabel: e.hasIntegratedBanner ? e.title : null,
                  ),
                  // Banner đã in sẵn năm và tên trận: bỏ chip năm, tiêu đề đè.
                  if (!e.hasIntegratedBanner) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.redDeepest.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Năm ${e.year > 0 ? e.year : '${e.year.abs()} TCN'}',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldBright,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 10,
                      right: 10,
                      child: Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Thông tin & hành động vào trận.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        // Số câu lấy từ backend. Trước đây ghi cứng "3 câu" cho
                        // mọi trận, trong khi kho thật đã có tới 10 — người học
                        // bị nói sai, mà công soạn câu hỏi cũng bị giấu đi.
                        _CampaignMeta(
                          icon: Icons.help_outline_rounded,
                          label: '${e.quizCount} câu trắc nghiệm',
                          color: AppColors.inkSoft,
                        ),
                        const _CampaignMeta(
                          icon: Icons.timer_outlined,
                          label: '30s/câu',
                          color: AppColors.primary,
                        ),
                        if (_tienDo[e.slug] != null)
                          _CampaignMeta(
                            icon: Icons.emoji_events_rounded,
                            label: 'Tốt nhất ${(_tienDo[e.slug]!['quiz_best_score'] as num?)?.toInt() ?? 0}'
                                '/${e.quizCount} câu',
                            color: ((_tienDo[e.slug]!['mastery'] as num?)?.toInt() ?? 0) >= 100
                                ? AppColors.success
                                : AppColors.cta,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _BattleActionButton(onPressed: () => _enterQuiz(e)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enterQuiz(HistoricalEvent e) async {
    final danhLai = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPlayScreen(
          eventSlug: e.slug,
          eventTitle: e.title,
        ),
      ),
    );
    if (!mounted) return;

    // Người thua bấm "Đánh lại trận này" ở màn kết quả. Vào thẳng lại trận cũ
    // chứ không bắt họ tự đi tìm lại thẻ trên bản đồ — lúc vừa thua là lúc
    // người ta muốn thử lại nhất, đừng chen thêm bước nào vào giữa.
    if (danhLai == true) {
      _enterQuiz(e);
      return;
    }
    // Chơi xong thì điểm và hạng đã đổi, nạp lại cho khỏi hiện số cũ.
    _load();
  }
}

/// Metadata footer giữ nội dung đọc được khi card thu hẹp trên mobile.
class _CampaignMeta extends StatelessWidget {
  const _CampaignMeta({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Hai thanh kiếm chéo vector — tránh phụ thuộc icon package ngoài.
class _CrossedSwordsIcon extends StatelessWidget {
  const _CrossedSwordsIcon({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrossedSwordsPainter(color),
      ),
    );
  }
}

class _CrossedSwordsPainter extends CustomPainter {
  const _CrossedSwordsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bladePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.115
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final guardPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.13
      ..strokeCap = StrokeCap.round;

    void sword(bool mirrored) {
      final x = mirrored ? size.width * 0.70 : size.width * 0.30;
      final tipX = mirrored ? size.width * 0.25 : size.width * 0.75;
      final handleY = size.height * 0.78;
      final guardY = size.height * 0.61;
      final tipY = size.height * 0.14;

      canvas.drawLine(Offset(x, guardY), Offset(tipX, tipY), bladePaint);
      canvas.drawLine(
        Offset(x - size.width * 0.17, guardY),
        Offset(x + size.width * 0.17, guardY),
        guardPaint,
      );
      canvas.drawLine(Offset(x, guardY), Offset(x, handleY), bladePaint);
      canvas.drawCircle(
          Offset(x, handleY), size.width * 0.075, Paint()..color = color);
    }

    sword(false);
    sword(true);
  }

  @override
  bool shouldRepaint(covariant _CrossedSwordsPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// CTA icon-only: giữ vùng chạm 48 px nhưng không chiếm diện tích card.
class _BattleActionButton extends StatelessWidget {
  const _BattleActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Vào trận',
      child: Tooltip(
        message: 'Vào trận',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            width: AppDimensions.minInteractive,
            height: AppDimensions.minInteractive,
            decoration: const ShapeDecoration(
              color: AppColors.primary,
              shape: CircleBorder(),
            ),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              focusColor: AppColors.primaryFocus,
              hoverColor: Colors.white24,
              highlightColor: AppColors.redDark,
              child: const Center(
                child: _CrossedSwordsIcon(
                  color: AppColors.goldBright,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
