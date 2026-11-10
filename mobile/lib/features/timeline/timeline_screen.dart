import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../../data/models.dart';
import 'event_detail_screen.dart';
import 'widgets/animated_timeline_node.dart';

/// 3D Cinematic Timeline — Dòng thời gian lịch sử một cột tinh tế.
/// Khắc phục hoàn toàn lỗi zig-zag L8, thẻ bấm mở màn chi tiết L9,
/// ảnh bìa thật qua CoverImage L13, và xoá tab giả L1.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, this.isTabRoot = true});
  final bool isTabRoot;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _api = ApiClient();
  final _scrollController = ScrollController();
  final _revealedSlugs = <String>{};
  final _nodeKeys = <String, GlobalKey>{};
  final _lineProgressBySlug = <String, double>{};
  List<HistoricalEvent> _events = [];
  bool _viewportUpdateScheduled = false;
  bool _loading = true;
  String? _error;
  String? _era;

  /// Lọc theo lớp (null = mọi lớp). Lọc ngay trên máy: danh sách sự kiện nhỏ,
  /// không đáng thêm một tham số truy vấn nữa ở backend.
  int? _lop;
  Map<String, double> _learningProgressBySlug = const {};

  List<HistoricalEvent> get _hienThi => _lop == null
      ? _events
      : _events.where((e) => e.lopHoc.contains(_lop)).toList();

  /// Chỉ hiện những lớp thật sự có sự kiện — nút "Lớp 9" mà bấm vào trống trơn
  /// thì người dùng tưởng app lỗi.
  List<int> get _cacLop {
    final s = <int>{for (final e in _events) ...e.lopHoc}.toList()..sort();
    return s;
  }

  static const _eras = [null, 'co-dai', 'phong-kien', 'hien-dai'];
  static const _labels = {
    null: 'Tất cả mốc',
    'co-dai': 'Thời Cổ Đại',
    'phong-kien': 'Thời Phong Kiến',
    'hien-dai': 'Thời Cận - Hiện Đại',
  };

  @override
  void initState() {
    super.initState();
    // Bắt buộc giữ lời gọi đo lường Ev.timelineView
    Analytics.instance.log(Ev.timelineView);
    _scrollController.addListener(_scheduleViewportUpdate);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_scheduleViewportUpdate)
      ..dispose();
    super.dispose();
  }

  void _scheduleViewportUpdate() {
    if (_viewportUpdateScheduled || !mounted) return;
    _viewportUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdateScheduled = false;
      if (mounted) _updateViewportMotion();
    });
  }

  void _updateViewportMotion() {
    final viewportContext =
        _scrollController.position.context.notificationContext;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;

    final revealHead = viewportBox.localToGlobal(Offset.zero).dy +
        viewportBox.size.height * 0.82;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    var changed = false;

    for (final event in _hienThi) {
      final box = _nodeKeys[event.slug]?.currentContext?.findRenderObject()
          as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      if (top < revealHead && bottom > viewportTop) {
        changed = _revealedSlugs.add(event.slug) || changed;
      }
      final progress = ((revealHead - top) / box.size.height).clamp(0.0, 1.0);
      final previous = _lineProgressBySlug[event.slug] ?? 0;
      if ((progress - previous).abs() > 0.025) {
        _lineProgressBySlug[event.slug] = progress;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = _era != null ? '/events?era=$_era' : '/events';
      final data = await _api.get(path) as List;
      final events = data.map((e) => HistoricalEvent.fromJson(e)).toList();
      final progressBySlug = await _loadLearningProgress();
      if (!mounted) return;
      setState(() {
        _events = events;
        _learningProgressBySlug = progressBySlug;
        _loading = false;
        for (final event in events) {
          _nodeKeys.putIfAbsent(event.slug, GlobalKey.new);
        }
      });
      _scheduleViewportUpdate();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Không thể tải dữ liệu dòng thời gian. Vui lòng kiểm tra kết nối mạng.';
          _loading = false;
        });
      }
    }
  }

  /// Tận dụng endpoint tiến độ hiện có khi người dùng đã đăng nhập.
  /// Khách hoặc lỗi mạng vẫn xem Timeline bình thường với trạng thái 0%.
  Future<Map<String, double>> _loadLearningProgress() async {
    if (!_api.isSignedIn) return const {};
    try {
      final data = await _api.get('/me/progress') as List;
      return {
        for (final entry in data.whereType<Map>())
          if (entry['event_slug'] is String)
            entry['event_slug'] as String:
                ((entry['mastery'] as num?)?.toDouble() ?? 0) / 100,
      };
    } on ApiException {
      return const {};
    }
  }

  double? _progressFor(HistoricalEvent event) =>
      event.learningProgress ?? _learningProgressBySlug[event.slug];

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
            Text('DÒNG THỜI GIAN'),
            SizedBox(width: 8),
            VietnameseFestivalFlag(size: 18),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: DongSonBackground(
        size: 320,
        opacity: 0.035,
        child: Column(
          children: [
            _filterRow(),
            if (_cacLop.isNotEmpty) _locLopRow(),
            const DongSonWaveDivider(
                color: AppColors.gold, height: 12, opacity: 0.40),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _filterRow() => Container(
        color: AppColors.bg,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _eras.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => FilterPill(
            label: _labels[_eras[i]]!,
            active: _era == _eras[i],
            onTap: () {
              setState(() => _era = _eras[i]);
              _load();
            },
          ),
        ),
      );

  Widget _locLopRow() => Container(
        color: AppColors.bg,
        height: 48,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _cacLop.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final lop = i == 0 ? null : _cacLop[i - 1];
            return FilterPill(
              label: lop == null ? 'Mọi lớp' : 'Lớp $lop',
              active: _lop == lop,
              onTap: () {
                setState(() => _lop = lop);
                _scheduleViewportUpdate();
              },
            );
          },
        ),
      );

  Widget _body() {
    if (_loading) {
      return const LoadingSkeleton(cardCount: 4, cardHeight: 120);
    }
    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _load,
      );
    }
    if (_events.isNotEmpty && _hienThi.isEmpty) {
      return EmptyState(
        title: 'Chưa có sự kiện cho lớp $_lop',
        message: 'Trong giai đoạn này chưa có sự kiện nào gắn với chương trình lớp $_lop.',
        actionLabel: 'Xem mọi lớp',
        onAction: () => setState(() => _lop = null),
      );
    }
    if (_events.isEmpty) {
      return EmptyState(
        title: 'Chưa có sự kiện',
        message: 'Không tìm thấy sự kiện nào trong giai đoạn này.',
        actionLabel: 'Xem tất cả mốc',
        onAction: () {
          setState(() => _era = null);
          _load();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: _hienThi.length,
        itemBuilder: (_, i) =>
            _timelineNode(i, _hienThi[i], i == _hienThi.length - 1),
      ),
    );
  }

  Widget _timelineNode(int index, HistoricalEvent e, bool isLast) {
    return KeyedSubtree(
      key: _nodeKeys.putIfAbsent(e.slug, GlobalKey.new),
      child: AnimatedTimelineNode(
        key: ValueKey(e.slug),
        revealed: _revealedSlugs.contains(e.slug),
        lineProgress: _lineProgressBySlug[e.slug] ?? 0,
        isLast: isLast,
        child: _eventCard(e),
      ),
    );
  }

  Widget _eventCard(HistoricalEvent e) {
    final feats = (e.features ?? '')
        .split(',')
        .map((s) => s.trim().toLowerCase())
        // "timeline" là cờ nội bộ (sự kiện có trên dòng thời gian), không phải tính
        // năng — trước đây hiện nguyên chữ tiếng Anh "timeline" trên thẻ.
        .where((s) => s.isNotEmpty && s != 'timeline')
        .toList();

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: e),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh bìa Hero với banner chuẩn theo tỷ lệ của tệp ảnh (2.4:1)
          AspectRatio(
            aspectRatio: e.hasIntegratedBanner ? e.bannerAspectRatio : (16 / 9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(
                  url: e.bannerAsset ?? e.thumbnailUrl,
                  heroTag: 'event_${e.slug}',
                  borderRadius: 0,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: e.hasIntegratedBanner ? e.title : null,
                ),
                // Banner đã in sẵn năm, triều đại và tên trận — vẽ thêm chip và
                // tiêu đề lên là chữ chồng chữ. Chỉ ảnh máy chủ mới cần phần đè.
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
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: appSoftShadow,
                      ),
                      child: Text(
                        'Năm ${e.year > 0 ? e.year : '${e.year.abs()} TCN'}',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldBright,
                        ),
                      ),
                    ),
                  ),
                  if (e.period != null && e.period!.isNotEmpty)
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          e.period!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Nội dung tóm tắt & tag tính năng
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Học ở lớp nào trên trường — góp ý phụ huynh 04/10: "chưa biết rõ
                // từng bài trong app liên quan đến phần kiến thức nào con đang học".
                if (e.lopHoc.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.school_outlined,
                          size: 14, color: AppColors.red),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Học trên lớp: ${e.lopHoc.map((l) => 'Lớp $l').join(' · ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  e.summary ??
                      'Chạm để tìm hiểu chi tiết về diễn biến và chiến công lịch sử.',
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
                LearningProgressIndicator(progress: _progressFor(e)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Các tag tương tác Việt hoá (Mục 11.3)
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: feats.map((f) {
                          String label = f;
                          IconData icon = Icons.star_outline;
                          if (f == 'cinematic') {
                            label = 'Phim 3D';
                            icon = Icons.movie_outlined;
                          } else if (f == 'chat') {
                            label = 'Hỏi vĩ nhân';
                            icon = Icons.forum_outlined;
                          } else if (f == 'quiz') {
                            label = 'Quiz';
                            icon = Icons.emoji_events_outlined;
                          } else if (f == 'ar') {
                            label = 'Mô hình 3D';
                            icon = Icons.view_in_ar;
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.bgAlt,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 12, color: AppColors.red),
                                const SizedBox(width: 4),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Chi tiết',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 11, color: AppColors.red),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
