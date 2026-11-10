import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../../data/models.dart';
import 'chat_screen.dart';

/// Màn chọn nhân vật (Hội Thoại Vĩ Nhân) — theo phong cách Imperial của HistoriAI.
/// Khắc phục lỗi mảng màu navy L4, Việt hoá L15, khung viền hoành phi, xoá tab giả L1.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, this.isTabRoot = true});
  final bool isTabRoot;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _api = ApiClient();
  List<Figure> _figures = [];

  /// Cấp hiện tại của người dùng. Chưa nạp được thì coi như Cấp 1 — thà khoá
  /// nhầm một lúc còn hơn mở nhầm rồi người ta bấm vào lại lỗi.
  int _capCuaToi = 1;
  bool _loading = true;
  String? _error;
  int _era = 0;

  /// Nhãn triều đại LẤY TỪ DỮ LIỆU (phần trước dấu "·" của period, vd "Nhà Trần").
  /// Trước đây ghi cứng "Thời Trần / Thời Lê / Thời Tây Sơn" trong khi dữ liệu ghi
  /// "Nhà Trần · …" — nên bấm bộ lọc nào cũng ra danh sách rỗng.
  List<String> get _eras => [
        'Tất cả triều đại',
        ...{
          for (final f in _figures)
            if ((f.period ?? '').trim().isNotEmpty) _trieuDai(f),
        },
      ];

  static String _trieuDai(Figure f) => (f.period ?? '').split('·').first.trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get('/figures') as List;
      if (!mounted) return;
      setState(() {
        _figures = data.map((e) => Figure.fromJson(e)).toList();
        _loading = false;
      });

      // Cấp thật của người dùng, để biết ai đã mở khoá được ai.
      //
      // Trước đây `isLocked` chỉ xem `unlockLevel > 1` mà KHÔNG hỏi người dùng
      // đang ở cấp mấy — nghĩa là Quang Trung khoá vĩnh viễn, leo tới Cấp 10
      // cũng không mở, thẻ vẫn ghi "Cần đạt Cấp 2" và chạm vào không phản hồi.
      try {
        final me = await _api.get('/auth/me') as Map<String, dynamic>;
        if (mounted) {
          setState(() => _capCuaToi = me['role'] == 'admin'
              ? 1 << 20 // quản trị: mở khoá mọi vĩ nhân
              : (me['level'] as num?)?.toInt() ?? 1);
        }
      } catch (_) {
        // Khách chưa đăng nhập: giữ Cấp 1.
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách vĩ nhân. Vui lòng thử lại sau.';
        _loading = false;
      });
    }
  }

  List<Figure> get _filtered {
    final eras = _eras;
    if (_era == 0 || _era >= eras.length) return _figures;
    final key = eras[_era];
    return _figures.where((f) => _trieuDai(f) == key).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ChimLacMotif(size: 56, color: AppColors.goldBright),
            SizedBox(width: 8),
            Text('HỘI THOẠI VĨ NHÂN'),
            SizedBox(width: 8),
            ChimLacMotif(size: 56, color: AppColors.goldBright, flip: true),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: DongSonBackground(
        size: 320,
        opacity: 0.035,
        child: _loading
            ? const LoadingSkeleton(cardCount: 3, cardHeight: 140)
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _content(),
      ),
    );
  }

  Widget _content() {
    final list = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Thẻ Hero đỏ son & đỏ thẫm hoàng cung (sửa lỗi mảng navy L4)
          _heroBanner(),
          const SizedBox(height: 18),

          // Bộ lọc triều đại
          _eraFilter(),
          const SizedBox(height: 16),

          if (list.isEmpty)
            const EmptyState(
              title: 'Chưa có vĩ nhân',
              message: 'Chưa có dữ liệu nhân vật thuộc triều đại này.',
            )
          else
            ...list.map(_figureCard),

          const SizedBox(height: 16),
          _historicalQuote(),
        ],
      ),
    );
  }

  Widget _heroBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          gradient: imperialDarkGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: appSoftShadow,
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.4), width: 1),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.14,
                child: const DongSonBackground(size: 160),
              ),
            ),
            Column(
              children: [
                const Text(
                  'Đàm Đạo Cùng Tiền Nhân',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    color: AppColors.goldBright,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Trực tiếp trò chuyện và lắng nghe chia sẻ từ các vị anh hùng dân tộc',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.onRed,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: const [
                    _HeroBadge('Giọng nói AI'),
                    _HeroBadge('Phản hồi tức thì'),
                    _HeroBadge('Chuẩn sử học'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

  Widget _eraFilter() => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _eras.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => FilterPill(
            label: _eras[i],
            active: _era == i,
            onTap: () => setState(() => _era = i),
          ),
        ),
      );

  Widget _figureCard(Figure f) {
    final isLocked = f.unlockLevel > _capCuaToi;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: isLocked ? null : () => _openChat(f),
        child: Row(
          children: [
            // Khung tranh chân dung viền hoành phi vàng
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold, width: 1.8),
                boxShadow: appSoftShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: f.faceAsset != null
                    ? Image.asset(f.faceAsset!, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.redDark,
                        child: const Icon(Icons.person,
                            color: AppColors.goldBright, size: 36),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Thông tin nhân vật
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.name,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (f.isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.goldBright,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NỔI BẬT',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    f.title ?? 'Danh nhân lịch sử',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.red,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    f.period ?? '',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  if (f.knowledgeBoundary?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.history_edu_outlined,
                            size: 14, color: AppColors.goldDark),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Phạm vi tri thức: ${f.knowledgeBoundary}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isLocked) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.lock_rounded,
                            size: 14, color: AppColors.inkMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Cần đạt Cấp ${f.unlockLevel} ở Đấu Trường để mở khoá',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (!isLocked)
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 15, color: AppColors.red),
          ],
        ),
      ),
    );
  }

  void _openChat(Figure f) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          figureSlug: f.slug,
          figureName: f.name,
          figureTitle: f.title,
          period: f.period,
        ),
      ),
    );
  }

  Widget _historicalQuote() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.format_quote_rounded, color: AppColors.gold, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '"Dân ta phải biết sử ta, cho tường gốc tích nước nhà Việt Nam."',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      );
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          color: AppColors.goldBright,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
