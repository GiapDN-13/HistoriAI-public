import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../../data/lo_trinh_hoc.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import 'premium_chung.dart';
import 'thanh_toan_screen.dart';

/// Màn HistoriAI Premium.
///
/// MỘT GÓI, BỐN QUYỀN LỢI
///     Nhóm chốt: một gói 39.000đ cho 30 ngày, trả bằng chuyển khoản QR, không
///     tự gia hạn. Premium mở đúng bốn thứ (xem `DanhSachQuyenLoi`): hỏi vĩ nhân
///     không giới hạn, bản tin phụ huynh đầy đủ, ôn toàn bộ câu sai, trọn bài học
///     theo lộ trình. Phim, bảo tàng… chưa chốt nên màn này KHÔNG được nhắc tới —
///     hứa trước rồi không giao là lỗi nặng hơn thiếu. Quiz, dòng thời gian, phim
///     Bạch Đằng 938 và câu gợi ý soạn sẵn vẫn miễn phí.
///
/// HAI CHẾ ĐỘ
///     `GET /thanh-toan/goi` báo `bat`. Chưa bật (hoặc không gọi được máy chủ)
///     thì giữ nguyên hành vi cũ: nút "Tôi quan tâm" chỉ ghi nhận ý định, không
///     thu đồng nào. Bật rồi mới hiện nút thanh toán thật.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, this.authService});

  /// Cần để mở màn đăng nhập. Không truyền thì tự tạo từ `ApiClient()` dùng
  /// chung — các lối vào Premium (hồ sơ, trang chủ, thẻ hết lượt) không cầm sẵn.
  final AuthService? authService;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _api = ApiClient();
  late final AuthService _auth = widget.authService ?? AuthService(_api);

  bool _dangTai = true;
  bool _bat = false;
  List<GoiPremium> _goi = const [];
  TinhTrangPremium _premium = TinhTrangPremium.khong;
  bool _daQuanTam = false;

  /// Gói đang mở màn chuyển khoản (chặn bấm đúp).
  bool _dangMoThanhToan = false;

  @override
  void initState() {
    super.initState();
    Analytics.instance.log(Ev.premiumView);
    _tai();
  }

  Future<void> _tai() async {
    var bat = false;
    var goi = <GoiPremium>[];
    try {
      final res = await _api.get('/thanh-toan/goi');
      if (res is Map) {
        bat = res['bat'] == true;
        goi = (res['goi'] as List? ?? const [])
            .map(GoiPremium.tuJson)
            .whereType<GoiPremium>()
            .toList();
      }
    } catch (_) {
      // Lỗi mạng hay máy chủ cũ chưa có đường này → coi như chưa mở bán.
      bat = false;
    }
    if (bat && goi.isEmpty) bat = false; // bật mà không có gói nào để bán
    final tinhTrang = bat ? await _docPremium() : TinhTrangPremium.khong;
    if (!mounted) return;
    setState(() {
      _bat = bat;
      _goi = goi;
      _premium = tinhTrang;
      _dangTai = false;
    });
  }

  Future<TinhTrangPremium> _docPremium() async {
    if (!_api.isSignedIn) return TinhTrangPremium.khong;
    try {
      return TinhTrangPremium.tuMe(await _api.get('/auth/me') as Map?);
    } catch (_) {
      return TinhTrangPremium.khong;
    }
  }

  /// Gói chính để bán: "thang", không có thì gói thường đầu tiên.
  GoiPremium? get _goiChinh {
    final thuong = _goi.where((g) => !g.laGoiThu).toList();
    for (final g in thuong) {
      if (g.ma == 'thang') return g;
    }
    return thuong.isEmpty ? null : thuong.first;
  }

  GoiPremium? get _goiThu {
    for (final g in _goi) {
      if (g.laGoiThu) return g;
    }
    return null;
  }

  void _bamQuanTam() {
    if (_daQuanTam) return;
    Analytics.instance.log(Ev.premiumCtaClick);
    setState(() => _daQuanTam = true);
  }

  Future<void> _thanhToan(GoiPremium goi) async {
    if (_dangMoThanhToan) return;
    Analytics.instance.log(Ev.premiumCtaClick, target: goi.ma);
    setState(() => _dangMoThanhToan = true);
    try {
      if (!_api.isSignedIn) {
        // Đơn phải gắn với một tài khoản để biết cộng Premium cho ai.
        final xong = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) =>
              LoginScreen(authService: _auth, quayLaiKhiXong: true),
        ));
        if (!mounted) return;
        if (xong != true || !_api.isSignedIn) return;
        final tt = await _docPremium();
        if (!mounted) return;
        setState(() => _premium = tt);
        // Vừa đăng nhập mà đã là Premium thì để họ thấy ngày hết hạn đã.
        if (tt.la) return;
      }
      await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ThanhToanScreen(goi: goi),
      ));
      if (!mounted) return;
      // Nạp lại dù người dùng thoát bằng Back: tiền có thể đã về trong lúc đó.
      final tt = await _docPremium();
      // Vừa mua xong (hoặc vừa đổi tài khoản): bài lộ trình đã tải lúc còn bản thường
      // phải tải lại, nếu không màn chi tiết vẫn khoá tới hết phiên.
      KhoLoTrinh.lamMoi();
      if (mounted) setState(() => _premium = tt);
    } finally {
      if (mounted) setState(() => _dangMoThanhToan = false);
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
        title: const Text(
          'HISTORIAI PREMIUM',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: DongSonBackground(
        size: 320,
        opacity: 0.03,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            _theGia(),
            const SizedBox(height: 22),
            if (_dangTai)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.red),
                ),
              )
            else if (_bat)
              ..._noiDungBanThat()
            else
              ..._noiDungDoYTinh(),
          ],
        ),
      ),
    );
  }

  // ───────────── Chưa mở bán: chỉ đo ý định ─────────────

  List<Widget> _noiDungDoYTinh() => [
        const _TieuDeMuc('DỰ KIẾN CÓ GÌ'),
        const SizedBox(height: 10),
        const DanhSachQuyenLoi(),
        const SizedBox(height: 18),
        const BangSoSanhPremium(),
        const SizedBox(height: 18),
        _theTrungThuc(),
        const SizedBox(height: 22),
        _nutQuanTam(),
      ];

  /// Nói thẳng là chưa mở bán.
  ///
  /// Giấu chuyện này đi thì người bấm nút sẽ tưởng mình vừa mua, rồi bực khi
  /// không thấy gì đổi — và con số "bao nhiêu người quan tâm" thu được cũng
  /// thành vô nghĩa vì đo nhầm thứ.
  Widget _theTrungThuc() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border(
          left: BorderSide(color: AppColors.gold, width: 4),
        ),
      ),
      child: const Text(
        'Premium chưa mở bán. Nhóm muốn biết có bao nhiêu người thật sự cần '
        'trước khi thu tiền của ai. Bấm nút dưới đây là bạn giúp nhóm trả lời '
        'đúng câu hỏi đó — chưa mất đồng nào.',
        style: TextStyle(
          fontFamily: 'Inter',
          color: Color(0xFF5C4033),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _nutQuanTam() {
    if (_daQuanTam) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 30),
            SizedBox(height: 8),
            Text(
              'Đã ghi nhận. Cảm ơn bạn.',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Khi Premium mở bán, nhóm sẽ báo ngay trong app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.inkSoft,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return NutPremium(nhan: 'Tôi quan tâm', onTap: _bamQuanTam);
  }

  // ───────────── Đã mở bán: thanh toán thật ─────────────

  List<Widget> _noiDungBanThat() {
    final goi = _goiChinh;
    final thu = _goiThu;
    final laPremium = _premium.la;
    final den = _premium.den;
    return [
      if (laPremium) ...[
        _theDangPremium(den),
        const SizedBox(height: 18),
      ],
      const _TieuDeMuc('PREMIUM CÓ GÌ'),
      const SizedBox(height: 10),
      const DanhSachQuyenLoi(),
      const SizedBox(height: 18),
      const _TieuDeMuc('MIỄN PHÍ VÀ PREMIUM'),
      const SizedBox(height: 10),
      const BangSoSanhPremium(),
      const SizedBox(height: 10),
      const Text(
        'Quiz, dòng thời gian, phim Bạch Đằng 938 và câu hỏi gợi ý soạn sẵn vẫn '
        'miễn phí cho mọi người. Thanh toán một lần cho 30 ngày, không tự gia hạn.',
        style: TextStyle(
          fontFamily: 'Inter',
          color: AppColors.inkSoft,
          fontSize: 12.5,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 22),
      if (goi != null)
        NutPremium(
          nhan: laPremium
              ? 'Gia hạn thêm ${goi.soNgay} ngày'
              : 'Thanh toán bằng chuyển khoản',
          dangXuLy: _dangMoThanhToan,
          onTap: () => _thanhToan(goi),
        ),
      if (thu != null) ...[
        const SizedBox(height: 10),
        NutPremium(
          nhan: 'Thử thanh toán ${dinhDangTien(thu.soTien)}đ (quản trị)',
          vienMo: true,
          onTap: _dangMoThanhToan ? null : () => _thanhToan(thu),
        ),
      ],
    ];
  }

  Widget _theDangPremium(DateTime? den) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold, width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: AppColors.gold, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn đang dùng Premium',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  den == null
                      ? 'Bạn đang được mở đủ các quyền lợi Premium.'
                      : 'Premium đến ngày ${dinhDangNgay(den)}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.inkSoft,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _theGia() {
    final goi = _bat ? _goiChinh : null;
    final tien = dinhDangTien(goi?.soTien ?? 39000);
    final ngay = goi?.soNgay ?? 30;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.red, AppColors.redDeepest],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: appSoftShadow,
      ),
      child: Column(
        children: [
          const ChimLacMotif(size: 46, color: AppColors.goldBright),
          const SizedBox(height: 10),
          const Text(
            'Học trọn vẹn hơn với Premium',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: AppColors.goldBright,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          // FittedBox: giá + "đ / 30 ngày" thu nhỏ vừa khung thay vì tràn ở máy 360px
          // hoặc khi người dùng chỉnh cỡ chữ hệ thống lớn.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                tien,
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'đ / $ngay ngày',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFF3D9C4),
                  fontSize: 14,
                ),
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TieuDeMuc extends StatelessWidget {
  const _TieuDeMuc(this.chu);
  final String chu;

  @override
  Widget build(BuildContext context) {
    return Text(
      chu,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}
