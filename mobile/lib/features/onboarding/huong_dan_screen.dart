import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics.dart';
import '../../core/theme.dart';
import '../../core/widgets/vietnamese_decorations.dart';

/// Màn hướng dẫn hiện đúng MỘT lần, lúc mở app lần đầu.
///
/// VÌ SAO CẦN
///     Người mở app lần đầu — kể cả hội đồng chấm — rơi thẳng vào màn đăng
///     nhập rồi tới bảng điều khiển dày đặc thẻ, không biết sản phẩm này làm
///     được gì. Ba thứ mạnh nhất (trò chuyện với vĩ nhân, đặt cổ vật ra giữa
///     phòng, đấu trường) đều nằm sau vài lần chạm, nên phần lớn người dùng
///     không bao giờ thấy.
///
/// ĐO ĐƯỢC
///     Mỗi trang bắn `onboarding_view` kèm số trang, nên biết người ta bỏ
///     ngang ở đâu. Bỏ qua và học xong đều có sự kiện riêng.
class HuongDanScreen extends StatefulWidget {
  const HuongDanScreen({super.key, required this.khiXong});

  /// Gọi khi người dùng học xong hoặc bấm bỏ qua.
  final VoidCallback khiXong;

  /// Khoá lưu trong SharedPreferences.
  ///
  /// Công khai để test dùng chung một hằng số — chép lại chuỗi ở hai nơi thì
  /// đổi một nơi là test lặng lẽ kiểm thứ khác.
  static const khoaDaXem = 'da_xem_huong_dan_v1';

  /// Đã xem lần nào chưa.
  ///
  /// Lỗi đọc bộ nhớ (trình duyệt ẩn danh) thì coi như ĐÃ xem: thà bỏ lỡ phần
  /// hướng dẫn còn hơn bắt người ta xem lại mỗi lần mở app.
  static Future<bool> daXem() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(khoaDaXem) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> danhDauDaXem() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(khoaDaXem, true);
    } catch (_) {
      // Không lưu được thì thôi, lần sau hiện lại — phiền nhưng không hỏng.
    }
  }

  @override
  State<HuongDanScreen> createState() => _HuongDanScreenState();
}

class _Trang {
  const _Trang(this.anh, this.tieuDe, this.moTa);

  final String anh;
  final String tieuDe;
  final String moTa;
}

const _duong = 'assets/figures3d/item_transparent/';

// Mỗi trang MỘT câu ngắn — góp ý 17/10: "phần hướng dẫn ban đầu hơi nhiều chữ,
// mình thường bấm bỏ qua". Điểm/chuỗi ngày giải thích ngay ở trang chủ (chạm vào
// con số) thay vì nhồi vào đây.
const _cacTrang = <_Trang>[
  _Trang(
    '${_duong}isolate_the_warrior_helmet_and_speech_bubble_icon_on_a_completely_clean_solid.png',
    'Hỏi thẳng người trong cuộc',
    'Hỏi Trần Hưng Đạo, Quang Trung bằng tiếng Việt, nghe các ngài trả lời.',
  ),
  _Trang(
    '${_duong}isolate_only_the_ancient_bronze_drum_icon_from_top_right_an_ancient_dong_son.png',
    'Đặt cổ vật ra giữa phòng',
    'Xoay trống đồng Đông Sơn và các cổ vật 3D, nhìn từng góc.',
  ),
  _Trang(
    '${_duong}isolate_only_the_golden_arena_quiz_trophy_icon_from_bottom_right_golden.png',
    'Làm quiz ở Đấu trường',
    'Mỗi câu đúng +10 điểm. Sai thì được giải thích ngay.',
  ),
  _Trang(
    '${_duong}isolate_only_the_scroll_timeline_icon_from_top_left_an_ancient_vietnamese.png',
    'Đi dọc dòng thời gian',
    'Các trận lớn từ Bạch Đằng 938 đến Quang Trung 1789. Chưa biết bắt đầu '
        'từ đâu? Trang chủ có sẵn 3 bước.',
  ),
];

class _HuongDanScreenState extends State<HuongDanScreen> {
  final _trangCtl = PageController();
  int _trang = 0;

  @override
  void initState() {
    super.initState();
    Analytics.instance.log(Ev.onboardingView, value: 1);
  }

  @override
  void dispose() {
    _trangCtl.dispose();
    super.dispose();
  }

  void _doiTrang(int i) {
    setState(() => _trang = i);
    Analytics.instance.log(Ev.onboardingView, value: i + 1);
  }

  Future<void> _ketThuc({required bool boQua}) async {
    Analytics.instance.log(
      boQua ? Ev.onboardingSkip : Ev.onboardingDone,
      value: _trang + 1,
    );
    await HuongDanScreen.danhDauDaXem();
    widget.khiXong();
  }

  void _tiep() {
    if (_trang >= _cacTrang.length - 1) {
      _ketThuc(boQua: false);
      return;
    }
    _trangCtl.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuoi = _trang >= _cacTrang.length - 1;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DongSonBackground(
        size: 380,
        opacity: 0.04,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _ketThuc(boQua: true),
                  child: const Text(
                    'Bỏ qua',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.inkSoft,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _trangCtl,
                  onPageChanged: _doiTrang,
                  itemCount: _cacTrang.length,
                  itemBuilder: (_, i) => _noiDung(_cacTrang[i], i),
                ),
              ),
              _chamTrang(),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: _nutTiep(cuoi),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noiDung(_Trang t, int i) {
    // Khoá theo chỉ số trang để mỗi lần lật là chạy lại hoạt hoạ từ đầu;
    // thiếu key thì Flutter dùng lại widget cũ và trang sau hiện ra đứng im.
    return _HienDan(
      key: ValueKey(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ThoNhe(
              child: Image.asset(
                t.anh,
                height: 190,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.auto_stories_rounded,
                  size: 120,
                  color: AppColors.gold,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              t.tieuDe,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                color: AppColors.primary,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.moTa,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.inkSoft,
                fontSize: 14.5,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chamTrang() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_cacTrang.length, (i) {
        final dang = i == _trang;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: dang ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: dang
                ? AppColors.primary
                : AppColors.gold.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _nutTiep(bool cuoi) {
    return Semantics(
      button: true,
      label: cuoi ? 'Bắt đầu' : 'Tiếp tục',
      child: InkWell(
        onTap: _tiep,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: ctaGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.cta.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            cuoi ? 'Bắt đầu' : 'Tiếp tục',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nội dung trồi lên và hiện dần khi trang xuất hiện.
class _HienDan extends StatefulWidget {
  const _HienDan({super.key, required this.child});

  final Widget child;

  @override
  State<_HienDan> createState() => _HienDanState();
}

class _HienDanState extends State<_HienDan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  )..forward();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duong = CurvedAnimation(parent: _ctl, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: duong,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(duong),
        child: widget.child,
      ),
    );
  }
}

/// Hình minh hoạ thở nhè nhẹ — đủ để trang không trông như ảnh chụp màn hình.
class _ThoNhe extends StatefulWidget {
  const _ThoNhe({required this.child});

  final Widget child;

  @override
  State<_ThoNhe> createState() => _ThoNheState();
}

class _ThoNheState extends State<_ThoNhe> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctl.stop();
      _ctl.value = 0;
    } else if (!_ctl.isAnimating) {
      _ctl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, con) {
        final t = Curves.easeInOut.transform(_ctl.value);
        return Transform.translate(
          offset: Offset(0, -6 * t),
          child: Transform.scale(scale: 1 + 0.015 * t, child: con),
        );
      },
      child: widget.child,
    );
  }
}
