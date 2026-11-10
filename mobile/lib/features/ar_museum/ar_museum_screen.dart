import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/chi_dan.dart';
import '../../core/widgets/glb_viewer.dart';
import '../../core/widgets/turntable_viewer.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../../data/models.dart';
import 'artifact_restore_dialog.dart';
import 'dat_vao_phong.dart';

/// Bảo Tàng 3D — Không gian trưng bày hiện vật và danh nhân lịch sử.
/// Khắc phục L10 ("Xem AR" -> "Xem mô hình 3D"), L13 (CoverImage thumbnail),
/// L14 (cân đối lưới hiện vật không để trống nửa hàng), xoá tab giả L1.
class ArMuseumScreen extends StatefulWidget {
  const ArMuseumScreen({super.key, this.isTabRoot = true});
  final bool isTabRoot;

  @override
  State<ArMuseumScreen> createState() => _ArMuseumScreenState();
}

class _ArMuseumScreenState extends State<ArMuseumScreen> {
  final _api = ApiClient();
  List<Artifact> _artifacts = [];
  List<Figure> _figures = [];
  bool _loading = true;
  String? _error;
  int _filter = 0;

  // Khoá để bộ chỉ dẫn biết khoét sáng vào đâu.
  final _khoaLoc = GlobalKey();
  final _khoaNoiBat = GlobalKey();
  final _khoaLuoi = GlobalKey();

  // Bỏ "Vũ khí" (27/09): dữ liệu cổ vật không có trường loại, bấm vào vẫn ra
  // trống đồng, nghê đá — bộ lọc giả. Thêm lại khi cổ vật có phân loại.
  static const _filters = ['Tất cả', 'Cổ vật', 'Nhân vật 3D'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Đã xin chạy chỉ dẫn chưa (một lần cho mỗi vòng đời màn).
  bool _daXinChiDan = false;

  /// Gọi từ lúc NỘI DUNG được dựng, không phải từ initState.
  ///
  /// initState của màn này nổ ngay lúc dựng vỏ điều hướng, khi tab Bảo tàng
  /// còn chưa từng được hiển thị — lúc đó không có widget nào để khoét sáng,
  /// và vì State được giữ lại nên initState cũng không chạy lần thứ hai.
  void _chiDan() {
    if (_daXinChiDan || !mounted || _artifacts.isEmpty) return;
    _daXinChiDan = true;
    ChiDan.chay(context, khoa: 'bao-tang-v1', cacBuoc: [
      BuocChiDan(
        khoa: _khoaNoiBat,
        tieuDe: 'Chạm để cầm lên xem',
        noiDung: 'Chạm vào cổ vật là mở mô hình 3D. Kéo ngón tay để xoay mọi '
            'hướng, chụm hai ngón để phóng to xem hoa văn.',
      ),
      BuocChiDan(
        khoa: _khoaLuoi,
        tieuDe: 'Chín hiện vật, mỗi cái một câu chuyện',
        noiDung: 'Trống đồng, cọc gỗ Bạch Đằng, kiếm Đông Sơn, nghê đá Hoa Lư… '
            'Mỗi hiện vật có mô tả riêng ở phía dưới mô hình.',
      ),
      BuocChiDan(
        khoa: _khoaLoc,
        tieuDe: 'Lọc theo loại',
        noiDung: 'Tách riêng cổ vật, vũ khí, hay nhân vật lịch sử dựng 3D.',
        boTronKhung: 21,
      ),
    ]);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get('/artifacts') as List;
      List<Figure> figs = [];
      try {
        final fd = await _api.get('/figures') as List;
        figs = fd
            .map((e) => Figure.fromJson(e))
            .where((f) => f.hasModel3D)
            .toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _artifacts = data.map((e) => Artifact.fromJson(e)).toList();
        _figures = figs;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể nạp dữ liệu bảo tàng. Vui lòng kiểm tra mạng.';
          _loading = false;
        });
      }
    }
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
            Text('BẢO TÀNG 3D'),
            SizedBox(width: 8),
            VietnameseFestivalFlag(size: 18),
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _chiDan());
    final featured = _artifacts.isNotEmpty ? _artifacts.first : null;
    final rest = _artifacts.length > 1 ? _artifacts.sublist(1) : <Artifact>[];

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          KeyedSubtree(key: _khoaLoc, child: _filterRow()),
          const SizedBox(height: 16),
          if (featured != null && (_filter == 0 || _filter == 1)) ...[
            KeyedSubtree(key: _khoaNoiBat, child: _featuredCard(featured)),
            const SizedBox(height: 24),
          ],
          if (_filter != 2) ...[
            const SectionHeader(
              title: 'Hiện Vật Tiêu Biểu',
              subtitle: 'Chạm để chiêm ngưỡng chi tiết mô hình',
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _khoaLuoi,
              child: _artifactSection(
                  rest.isEmpty && featured != null ? [featured] : rest),
            ),
            const SizedBox(height: 24),
          ],
          if (_figures.isNotEmpty && (_filter == 0 || _filter == 2)) ...[
            const SectionHeader(
              title: 'Nhân Vật Lịch Sử 3D',
              subtitle: 'Mô hình xoay 360 độ sống động',
            ),
            const SizedBox(height: 12),
            _figureList(),
          ],
        ],
      ),
    );
  }

  Widget _filterRow() => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => FilterPill(
            label: _filters[i],
            active: _filter == i,
            onTap: () => setState(() => _filter = i),
          ),
        ),
      );

  Widget _featuredCard(Artifact a) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => _openArtifact(a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(
                  url: a.thumbnailUrl,
                  borderRadius: 0,
                  width: double.infinity,
                  height: double.infinity,
                ),
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
                  top: 12,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: appSoftShadow,
                    ),
                    child: const Text(
                      'HIỆN VẬT NỔI BẬT',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: AppColors.goldBright,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 14,
                  right: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (a.period != null)
                        Text(
                          a.period!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.onRed.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    a.description ??
                        'Hiện vật mang đậm dấu ấn hào hùng thời dựng nước và giữ nước.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.inkSoft),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Phục dựng cổ vật',
                      icon: const Icon(Icons.auto_fix_high_rounded,
                          color: AppColors.red),
                      onPressed: () => _openRestoreDialog(a),
                    ),
                    const SizedBox(width: 4),
                    // Hiện chưa hiện vật nào có file .glb thật (models/ trên
                    // viewer chỉ có nhân vật), nên nút này mở bảng chi tiết chứ
                    // không dựng 3D. Gọi đúng tên việc nó làm; đổi lại nhãn khi
                    // nào có model hiện vật.
                    AppButton(
                      label: a.hasModel3D ? 'Xem mô hình 3D' : 'Xem chi tiết',
                      height: 38,
                      icon: a.hasModel3D
                          ? Icons.threed_rotation_rounded
                          : Icons.info_outline_rounded,
                      onPressed: () => _openArtifact(a),
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

  Widget _artifactSection(List<Artifact> list) {
    if (list.isEmpty) {
      return const EmptyState(
        title: 'Chưa có hiện vật',
        message: 'Không có hiện vật nào thuộc nhóm này.',
      );
    }

    // Nếu chỉ có 1 hiện vật: vẽ thẻ dài full-width thay vì để nửa ô trống (sửa L14)
    if (list.length == 1) {
      final a = list.first;
      return AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => _openArtifact(a),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CoverImage(url: a.thumbnailUrl, borderRadius: 10),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    a.period ?? 'Thời kỳ dựng nước',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.red),
          ],
        ),
      );
    }

    // Khi có nhiều hơn 1: hiển thị lưới 2 cột
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final a = list[i];
        return AppCard(
          padding: EdgeInsets.zero,
          onTap: () => _openArtifact(a),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: CoverImage(url: a.thumbnailUrl, borderRadius: 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.period ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _figureList() {
    return Column(
      children: _figures.map((f) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            onTap: () => _openFigure3D(f),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: f.faceAsset != null
                        ? Image.asset(f.faceAsset!, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.redDark,
                            child: const Icon(Icons.person,
                                color: AppColors.goldBright)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        f.title ?? 'Danh nhân lịch sử',
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.red),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Xoay 3D',
                  height: 36,
                  variant: AppButtonVariant.secondary,
                  icon: Icons.threed_rotation_rounded,
                  onPressed: () => _openFigure3D(f),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openArtifact(Artifact a) {
    // Bắt buộc ghi nhận event đo lường arOpen theo R3
    Analytics.instance.log(Ev.arOpen, target: a.slug);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Có model thì dựng 3D ngay trong bảng chi tiết, xoay được luôn.
              // Trước đây chỗ này chỉ là một khung gradient với ảnh tĩnh, nên
              // model .glb tải lên máy chủ mà không đường nào xem được.
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: a.hasModel3D
                      ? GlbViewer(slug: a.slug)
                      : DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: imperialDarkGradient,
                          ),
                          child: Center(
                            child: CoverImage(
                                url: a.thumbnailUrl, width: 120, height: 120),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                a.name,
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                a.period ?? 'Thời kỳ lịch sử',
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.red,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                a.description ?? 'Hiện vật lịch sử đang được bảo tồn.',
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.inkSoft,
                    height: 1.45),
              ),
              const SizedBox(height: 20),
              if (a.hasModel3D) ...[
                AppButton(
                  label: 'Xem lớn toàn màn hình',
                  fullWidth: true,
                  variant: AppButtonVariant.primary,
                  icon: Icons.open_in_full_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    _open3DArtifact(a);
                  },
                ),
                const SizedBox(height: 10),
                _nutDatVaoPhong(a),
              ],
              AppButton(
                label: 'Phục Dựng Cổ Vật',
                fullWidth: true,
                variant: a.hasModel3D
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                icon: Icons.auto_fix_high_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  _openRestoreDialog(a);
                },
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Đóng',
                fullWidth: true,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nút "Đặt vào phòng" — mở camera và dựng cổ vật ra giữa phòng đúng kích
  /// thước thật.
  ///
  /// Nút này **tự biến mất** trong ba trường hợp, đều là cố ý:
  /// máy không có Scene Viewer (kể cả web và iPhone), cổ vật chưa có model
  /// `.glb` trên HTTPS, và cổ vật **chưa tra được kích thước thật**. Chi tiết
  /// từng luật nằm trong `DatVaoPhong.dungDuoc`.
  ///
  /// Trong lúc còn đang hỏi máy thì chỗ này để trống chứ không hiện khung chờ:
  /// câu trả lời tới trong vài mili giây, một cái skeleton nhấp nháy rồi biến
  /// mất còn khó chịu hơn là không có gì.
  Widget _nutDatVaoPhong(Artifact a) {
    return FutureBuilder<bool>(
      future: DatVaoPhong.dungDuoc(a),
      builder: (_, snap) {
        if (snap.data != true) return const SizedBox.shrink();

        final co = DatVaoPhong.moTaKichThuoc(a);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppButton(
              label: 'Đặt vào phòng',
              fullWidth: true,
              variant: AppButtonVariant.primary,
              icon: Icons.view_in_ar_rounded,
              onPressed: () => _datVaoPhong(a),
            ),
            if (co != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  'Hiện ra đúng cỡ thật — $co',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Future<void> _datVaoPhong(Artifact a) async {
    // Ghi trước khi rời app: bấm xong là người dùng nhảy sang Scene Viewer,
    // đợi tới lúc quay lại mới ghi thì mất hết số của những người không quay lại.
    Analytics.instance.log(Ev.arView, target: a.slug);

    final xong = await DatVaoPhong.mo(a);
    if (xong || !mounted) return;

    // Tới đây nghĩa là `canLaunchUrl` bảo mở được mà `launchUrl` lại không —
    // hiếm, nhưng im lặng thì người dùng tưởng nút hỏng.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Máy chưa mở được chế độ xem thực tế ảo.'),
      ),
    );
  }

  void _openRestoreDialog(Artifact a) {
    showDialog(
      context: context,
      builder: (_) => ArtifactRestoreDialog(
        artifactTitle: a.name,
        artifactPeriod: a.period ?? 'Bảo vật Đại Việt',
        imageUrl: a.thumbnailUrl,
        description: a.description ??
            'Hiện vật lịch sử nghìn năm mang đậm dấu ấn hào hùng dân tộc.',
      ),
    );
  }

  /// Xem hiện vật ở khổ lớn, xoay tự do. Cùng khuôn với _openFigure3D để hai
  /// loại (hiện vật và nhân vật) cho cùng một trải nghiệm.
  void _open3DArtifact(Artifact a) {
    Analytics.instance.log(Ev.arOpen, target: a.slug);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      a.name,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldBright,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng trình xem mô hình',
                    icon: const Icon(Icons.close, color: AppColors.goldBright),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(child: GlbViewer(slug: a.slug)),
          ],
        ),
      ),
    );
  }

  void _openFigure3D(Figure f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mô Hình 3D: ${f.name}',
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldBright,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng trình chiếu mô hình',
                    icon: const Icon(Icons.close, color: AppColors.goldBright),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              // Ưu tiên model .glb thật: xoay được mọi hướng, đúng như ghi chú
              // ở `hasModel3D`. Trước đây nhánh này bị đảo nên nhân vật có model
              // thật vẫn chỉ hiện sáu tấm ảnh xoay ngang.
              // Không có model thì mới rơi về ảnh xoay.
              child: f.hasModel3D
                  ? GlbViewer(
                      slug: f.slug,
                      // Mặt nhân vật quay về phía trục +X, tương ứng góc 90°
                      // của model-viewer; để mặc định 0° là mở ra thấy hông.
                      //
                      // Con số này phải đo với auto-rotate TẮT và trên đúng
                      // model đang phát hành. Tôi đã đọc sai nó hai lần: một
                      // lần vì chụp màn hình sau khi model đã tự xoay, một lần
                      // vì lẫn ảnh của hai góc với nhau.
                      quayNgangDo: 90,
                      poster: f.portraitAsset != null
                          ? AssetImage(f.portraitAsset!)
                          : null,
                    )
                  : TurntableViewer(frames: f.spinFrames),
            ),
          ],
        ),
      ),
    );
  }
}
