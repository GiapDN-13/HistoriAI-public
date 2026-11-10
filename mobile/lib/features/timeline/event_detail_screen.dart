import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/analytics.dart';
import '../../core/app_preferences.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/cinematic_player.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../../data/ghi_nho.dart';
import '../../data/lo_trinh_hoc.dart';
import '../../data/models.dart';
import '../chat/mo_chat.dart';
import '../premium/premium_chung.dart';
import '../premium/premium_screen.dart';
import '../quiz/quiz_play_screen.dart';

/// Màn hình Chi tiết Sự kiện Lịch sử (Mục 5.2 SPEC_UI_UX.md).
/// Sửa lỗi L9: người dùng bấm vào thẻ sự kiện sẽ mở màn này với Hero transition.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.event});
  final HistoricalEvent event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  /// Bài học theo lộ trình của trận này; null = chưa tải xong, trận chưa có lộ trình
  /// đã duyệt, hoặc tải hỏng — khi đó mục bài học ẩn đi, không báo lỗi: phần còn lại
  /// của màn vẫn dùng được và đây chỉ là nội dung thêm.
  ViTriBaiHoc? _baiHoc;

  @override
  void initState() {
    super.initState();
    // Bắt buộc ghi nhận eventOpen theo Mục 5.2 và Mục 9
    Analytics.instance.log(Ev.eventOpen, target: widget.event.slug);
    _taiBaiHoc();
  }

  Future<void> _taiBaiHoc() async {
    final v = await KhoLoTrinh.timBai(widget.event.slug);
    if (mounted && v != null) setState(() => _baiHoc = v);
  }

  /// Mở màn Premium từ khung "bài học đầy đủ dành cho Premium". Quay lại là tải lại
  /// bài: người học có thể vừa mua (hoặc vừa đăng nhập), khi đó bài phải mở ngay chứ
  /// không chờ tới lần mở app sau.
  Future<void> _xemPremium() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PremiumScreen()),
    );
    KhoLoTrinh.lamMoi();
    if (mounted) await _taiBaiHoc();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final feats = (e.features ?? '')
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();

    final hasQuiz = feats.contains('quiz') || feats.isEmpty;
    final hasChat = feats.contains('chat');
    final hasCinematic = feats.contains('cinematic');

    // Câu chốt: ưu tiên bản từ API /lo-trinh — tài liệu nhóm đã duyệt, sửa tài liệu
    // rồi chạy lại tools/nhap_lo_trinh.py là app đổi theo, không cần phát hành bản mới.
    // `ghi_nho.dart` chỉ còn là DỰ PHÒNG khi API chưa có: máy chủ cũ chưa có
    // /lo-trinh, mất mạng, hoặc đang chờ tải xong.
    final chotApi = _baiHoc?.bai.cauChot.trim() ?? '';
    final cauChot = chotApi.isNotEmpty ? chotApi : ghiNhoNhanh[e.slug];
    // Banner 2,4:1 đã in sẵn tên trận, năm (góc trái) và triều đại (góc phải).
    // Cho nó nằm trọn ngay dưới thanh công cụ: nút quay lại không đè chip năm in
    // trong ảnh, không phủ gradient, và tiêu đề chỉ hiện khi đã cuộn thu gọn.
    final banner = e.bannerAsset;
    final tieuDe = Text(
      e.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'PlayfairDisplay',
        color: AppColors.goldBright,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        shadows: [
          Shadow(color: Colors.black87, blurRadius: 6),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // AppBar dạng Sliver với ảnh bìa Hero lớn
          SliverAppBar(
            expandedHeight: banner == null
                ? 240
                : kToolbarHeight +
                    MediaQuery.sizeOf(context).width / e.bannerAspectRatio,
            pinned: true,
            backgroundColor: AppColors.red,
            leading: IconButton(
              tooltip: 'Quay lại dòng thời gian',
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.redDeepest.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back,
                    color: AppColors.goldBright, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              // Có banner thì tiêu đề chỉ hiện trên thanh đã thu gọn — chừa chỗ cho
              // nút quay lại như thanh công cụ thường, kẻo chữ đè lên nút.
              titlePadding: banner == null
                  ? const EdgeInsets.fromLTRB(16, 0, 16, 14)
                  : const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 16),
              title: banner == null ? tieuDe : _ChiHienKhiThuGon(child: tieuDe),
              background: banner != null
                  ? Padding(
                      padding: EdgeInsets.only(
                          top: MediaQuery.paddingOf(context).top +
                              kToolbarHeight),
                      child: CoverImage(
                        url: banner,
                        heroTag: 'event_${e.slug}',
                        borderRadius: 0,
                        width: double.infinity,
                        height: double.infinity,
                        semanticLabel: e.title,
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        CoverImage(
                          url: e.thumbnailUrl,
                          heroTag: 'event_${e.slug}',
                          borderRadius: 0,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        // Gradient phủ tối để chữ tiêu đề luôn đọc rõ ràng
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                                AppColors.redDeepest.withValues(alpha: 0.85),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Nội dung chi tiết sự kiện
          SliverToBoxAdapter(
            child: DongSonBackground(
              size: 300,
              opacity: 0.035,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Năm và thời kỳ / triều đại
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: appSoftShadow,
                          ),
                          child: Text(
                            'Năm ${e.year > 0 ? e.year : '${e.year.abs()} TCN'}',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              color: AppColors.goldBright,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (e.period != null && e.period!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.bgAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              e.period!,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                color: AppColors.inkSoft,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Tóm tắt lịch sử
                    const Text(
                      'TỔNG QUAN SỰ KIỆN',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: appSoftShadow,
                      ),
                      // Đổi lớp ở Hồ sơ là tóm tắt đổi theo ngay, không cần mở lại màn.
                      child: ValueListenableBuilder<int?>(
                        valueListenable: AppPreferences.lopHoc,
                        builder: (_, lop, __) => Text(
                          e.tomTatCho(lop) ??
                              'Dữ liệu đang được cập nhật thêm từ kho tư liệu lịch sử Đại Việt.',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            height: 1.6,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),

                    if (cauChot != null) ...[
                      const SizedBox(height: 14),
                      _GhiNho(cauChot),
                    ],

                    if (_baiHoc != null) ...[
                      const SizedBox(height: 24),
                      _BaiHocLoTrinh(_baiHoc!, onXemPremium: _xemPremium),
                    ],

                    if (e.chuongTrinhHopLe.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _ChuongTrinh(e.chuongTrinhHopLe),
                    ],

                    if (!hasCinematic && phimDangDung.contains(e.slug)) ...[
                      const SizedBox(height: 24),
                      _PhimDangDung(slug: e.slug, tieuDe: e.title),
                    ],

                    const SizedBox(height: 24),

                    // Trình phát thước phim. Chỉ tải video khi người dùng bấm —
                    // một thước phim nặng trên trăm MB.
                    if (hasCinematic) ...[
                      const Text(
                        'THƯỚC PHIM LỊCH SỬ 3D',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Poster giữ ảnh máy chủ (16:9, vừa khung phim). Thử banner
                      // 2,4:1 thì khung 16:9 cắt mất hai mép — chữ "Bạch" in trong
                      // ảnh mất chữ B, chip năm bị xén — và dòng "Xem thước phim
                      // lịch sử" nằm đè lên tên trận in sẵn.
                      CinematicPlayer(
                        url: e.cinematicVideoUrl ?? '',
                        eventSlug: e.slug,
                        posterUrl: e.thumbnailUrl,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Các hành động dẫn tiếp
                    const Text(
                      'TRẢI NGHIỆM TƯƠNG TÁC',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.red,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (hasQuiz) ...[
                      AppButton(
                        label: 'Tham gia Đấu Trường Quiz',
                        icon: Icons.emoji_events_outlined,
                        fullWidth: true,
                        variant: AppButtonVariant.primary,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuizPlayScreen(
                                eventSlug: e.slug,
                                eventTitle: e.title,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (hasChat) ...[
                      AppButton(
                        label: viNhanCuaSuKien.containsKey(e.slug)
                            ? 'Đàm đạo cùng ${viNhanCuaSuKien[e.slug]!.$2}'
                            : 'Đàm đạo cùng Vĩ Nhân thời kỳ này',
                        icon: Icons.forum_outlined,
                        fullWidth: true,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => moChatTheoSuKien(context, e.slug),
                      ),
                    ],

                    if (e.sources.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _NguonTuLieu(e.sources),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiêu đề thanh trên chỉ hiện ở quãng cuối khi cuộn thu gọn. Lúc mở rộng, tên
/// trận đã in to trên banner ngay bên dưới — hiện thêm là chữ chồng chữ.
class _ChiHienKhiThuGon extends StatelessWidget {
  const _ChiHienKhiThuGon({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    if (s == null) return child;
    final quang = s.maxExtent - s.minExtent;
    final thuGon = quang <= 0
        ? 1.0
        : ((s.maxExtent - s.currentExtent) / quang).clamp(0.0, 1.0);
    // Banner mờ dần ở quãng cuối (FlexibleSpaceBar tự làm); tiêu đề hiện theo.
    return Opacity(
      opacity: ((thuGon - 0.7) / 0.3).clamp(0.0, 1.0),
      child: child,
    );
  }
}

/// Câu chốt để nhớ của trận (tài liệu lộ trình của nhóm — lấy từ /lo-trinh, dự phòng
/// `data/ghi_nho.dart`).
class _GhiNho extends StatelessWidget {
  const _GhiNho(this.cau);
  final String cau;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('ghi-nho-nhanh'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: AppColors.gold, width: 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.bookmark_outline_rounded, size: 18, color: AppColors.goldDark),
            SizedBox(width: 6),
            Text('GHI NHỚ NHANH',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.goldDark,
                )),
          ]),
          const SizedBox(height: 6),
          Text(cau,
              style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 14.5, height: 1.55, color: AppColors.ink)),
        ]),
      );
}

/// "Bài học theo lộ trình": bài đầy đủ của trận theo tài liệu nhóm soạn bám SGK
/// (xem `data/lo_trinh_hoc.dart`).
///
/// Mặc định GẬP, chỉ hiện Mục tiêu: màn này vốn dài (tóm tắt, phim, quiz, chat), bày
/// hết bài học ra là đẩy nút Đấu trường xuống tận đáy. Người muốn học kỹ bấm một lần
/// là thấy đủ.
class _BaiHocLoTrinh extends StatefulWidget {
  const _BaiHocLoTrinh(this.viTri, {required this.onXemPremium});
  final ViTriBaiHoc viTri;
  final VoidCallback onXemPremium;

  @override
  State<_BaiHocLoTrinh> createState() => _BaiHocLoTrinhState();
}

const _chuBaiHoc = TextStyle(
    fontFamily: 'Inter', fontSize: 14.5, height: 1.55, color: AppColors.ink);

class _BaiHocLoTrinhState extends State<_BaiHocLoTrinh> {
  bool _moRong = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.viTri;
    final b = v.bai;
    final ds = v.loTrinh.suKien;
    return Column(
      key: const Key('bai-hoc-lo-trinh'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BÀI HỌC THEO LỘ TRÌNH',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.red,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: appSoftShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cho người học biết trận này đứng ở đâu trong chuỗi bài, học trước
              // học sau thế nào — đúng thứ tự tài liệu nhóm soạn.
              Text.rich(
                key: const Key('lo-trinh-vi-tri'),
                TextSpan(children: [
                  const TextSpan(text: 'Theo lộ trình: '),
                  for (var i = 0; i < ds.length; i++) ...[
                    TextSpan(
                      text: ds[i].tenNgan,
                      style: i == v.chiSo
                          ? const TextStyle(fontWeight: FontWeight.w700, color: AppColors.red)
                          : null,
                    ),
                    if (i < ds.length - 1) const TextSpan(text: ' → '),
                  ],
                  TextSpan(text: ' (bài ${v.soBai}/${v.tongSoBai})'),
                ]),
                style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 13, height: 1.45, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 12),
              _MucBaiHoc('Mục tiêu', Text(b.mucTieu, style: _chuBaiHoc)),
              // Bài khoá: máy chủ chỉ gửi Mục tiêu + câu chốt, không có gì để "xem đầy
              // đủ" — thay nút bằng khung nói rõ phần còn lại dành cho Premium.
              if (b.khoa)
                KhungBaiHocKhoa(onXemPremium: widget.onXemPremium)
              else if (!_moRong)
                TextButton.icon(
                  key: const Key('lo-trinh-mo-rong'),
                  onPressed: () => setState(() => _moRong = true),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Xem bài học đầy đủ'),
                )
              else ...[
                if (b.boiCanh.isNotEmpty) _MucBaiHoc('Bối cảnh', _DauCham(b.boiCanh)),
                if (b.kienThuc.y.isNotEmpty)
                  _MucBaiHoc(
                    b.kienThuc.tieuDe.isEmpty ? 'Kiến thức cần nhớ' : b.kienThuc.tieuDe,
                    _DauCham(b.kienThuc.y),
                  ),
                if (b.dienBien.isNotEmpty)
                  _MucBaiHoc('Diễn biến cần nhớ', _DanhSo(b.dienBien)),
                if (b.ketQua.isNotEmpty) _MucBaiHoc('Kết quả', _DauCham(b.ketQua)),
                TextButton.icon(
                  key: const Key('lo-trinh-thu-gon'),
                  onPressed: () => setState(() => _moRong = false),
                  icon: const Icon(Icons.expand_less_rounded),
                  label: const Text('Thu gọn'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Khung thay cho nút "Xem bài học đầy đủ" ở bài lộ trình bị khoá (bản thường, bài thứ
/// 2 trở đi của lộ trình). Nói nhẹ nhàng, không chặn gì khác trên màn: Mục tiêu, Ghi
/// nhớ nhanh, quiz, chat vẫn dùng bình thường.
class KhungBaiHocKhoa extends StatelessWidget {
  const KhungBaiHocKhoa({super.key, required this.onXemPremium});
  final VoidCallback onXemPremium;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('lo-trinh-khoa'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: .6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.goldDark),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bài học đầy đủ (bối cảnh, diễn biến, kết quả) dành cho Premium',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NutPremium(nhan: 'Xem Premium', onTap: onXemPremium),
          ],
        ),
      );
}

/// Một phần của bài học: tiêu đề nhỏ + nội dung.
class _MucBaiHoc extends StatelessWidget {
  const _MucBaiHoc(this.tieuDe, this.noiDung);
  final String tieuDe;
  final Widget noiDung;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tieuDe,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.redDark,
              )),
          const SizedBox(height: 4),
          noiDung,
        ]),
      );
}

class _DauCham extends StatelessWidget {
  const _DauCham(this.ds);
  final List<String> ds;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final y in ds)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ', style: TextStyle(fontSize: 14.5, height: 1.55, color: AppColors.gold)),
                Expanded(child: Text(y, style: _chuBaiHoc)),
              ]),
            ),
        ],
      );
}

/// Diễn biến đánh số theo đúng thứ tự tài liệu — thứ tự ở đây chính là kiến thức.
class _DanhSo extends StatelessWidget {
  const _DanhSo(this.ds);
  final List<String> ds;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < ds.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 24,
                  child: Text('${i + 1}.',
                      style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          height: 1.6,
                          fontWeight: FontWeight.w700,
                          color: AppColors.red)),
                ),
                Expanded(child: Text(ds[i], style: _chuBaiHoc)),
              ]),
            ),
        ],
      );
}

/// Khung "Phim đang được dựng" cho trận đã có phim gốc nhưng chưa xong (xem
/// `data/ghi_nho.dart::phimDangDung`). Ảnh bìa ở `assets/phim_sap_co/<slug>.jpg` do
/// Codex vẽ; chưa có thì nền đỏ son.
class _PhimDangDung extends StatelessWidget {
  const _PhimDangDung({required this.slug, required this.tieuDe});
  final String slug;
  final String tieuDe;

  @override
  Widget build(BuildContext context) => ClipRRect(
        key: const Key('phim-dang-dung'),
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(
              'assets/phim_sap_co/$slug.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.red, AppColors.redDeepest],
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: .75)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.goldBright,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('PHIM ĐANG ĐƯỢC DỰNG',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.redDeepest,
                          letterSpacing: .6,
                        )),
                  ),
                  const SizedBox(height: 6),
                  Text('Nhóm đang dựng thước phim về $tieuDe.',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('Trong lúc chờ, đọc tóm tắt và làm quiz ở dưới nhé.',
                      style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12.5)),
                ],
              ),
            ),
          ]),
        ),
      );
}

/// "Học ở đâu trên lớp": lớp và chủ đề theo Chương trình GDPT 2018.
class _ChuongTrinh extends StatelessWidget {
  const _ChuongTrinh(this.ds);
  final List<CurriculumRef> ds;

  @override
  Widget build(BuildContext context) {
    // Một lớp có thể gắn nhiều chủ đề — mỗi lớp hiện một dòng là đủ.
    final theoLop = <int, CurriculumRef>{};
    for (final c in ds) {
      theoLop.putIfAbsent(c.lop, () => c);
    }
    final lop = theoLop.keys.toList()..sort();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.school_outlined, size: 18, color: AppColors.red),
              SizedBox(width: 6),
              Text(
                'HỌC TRÊN LỚP',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final l in lop)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Lớp $l',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldBright,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _viet(theoLop[l]!.chuDe),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Tiêu đề chủ đề trong văn bản chương trình viết HOA toàn bộ — đọc trên
  /// điện thoại rất nặng. Hạ về chữ thường, giữ hoa chữ đầu và tên riêng hay gặp.
  static String _viet(String s) {
    if (s.toUpperCase() != s) return s;
    var t = s.toLowerCase();
    const rieng = ['việt nam', 'đại việt', 'đông nam á', 'mông – nguyên', 'lam sơn',
        'tây sơn', 'biển đông', 'hồ chí minh', 'tổ quốc', 'cách mạng tháng tám'];
    for (final r in rieng) {
      t = t.replaceAll(r, r.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' '));
    }
    // Hạ chữ thường làm số La Mã thành "thế kỉ vii" — trả lại chữ hoa.
    t = t.replaceAllMapped(RegExp(r'(thế k[ỉỷ]) ([ivxlc]+)\b'),
        (m) => '${m[1]} ${m[2]!.toUpperCase()}');
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }
}

/// Nguồn tư liệu và giấy phép. CC BY-SA bắt buộc ghi nguồn nơi người dùng thấy
/// được — mục này là nghĩa vụ, không phải trang trí.
class _NguonTuLieu extends StatelessWidget {
  const _NguonTuLieu(this.ds);
  final List<SourceRef> ds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NGUỒN TƯ LIỆU',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.red,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tóm tắt biên soạn từ các nguồn dưới đây. Câu hỏi soạn từ các nguồn này '
          'chỉ dùng những dữ kiện được ít nhất hai nguồn độc lập xác nhận.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, height: 1.45, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 8),
        for (final n in ds)
          InkWell(
            onTap: n.url == null
                ? null
                : () => launchUrl(Uri.parse(n.url!), mode: LaunchMode.externalApplication),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.menu_book_outlined, size: 16, color: AppColors.gold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: n.ten,
                          style: TextStyle(
                            color: n.url == null ? AppColors.ink : AppColors.cta,
                            decoration: n.url == null ? null : TextDecoration.underline,
                          ),
                        ),
                        if (n.giayPhep != null)
                          TextSpan(
                            text: '  · ${n.giayPhep}',
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                      ]),
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
