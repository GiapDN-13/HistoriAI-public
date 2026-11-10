import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics.dart';
import '../theme.dart';

/// Chỉ dẫn tại chỗ: khoét sáng đúng thứ đang nói tới rồi giải thích nó.
///
/// VÌ SAO KHÔNG DỪNG Ở MÀN GIỚI THIỆU ĐẦU APP
///     Bốn trang giới thiệu lúc mở app nói được app LÀM GÌ, nhưng không nói
///     được LÀM THẾ NÀO. Người dùng vào Bảo tàng vẫn không biết chạm vào cổ
///     vật thì xoay được, vào Đấu trường vẫn không biết ba trái tim kia là số
///     mạng. Những thứ đó phải nói đúng lúc người ta đang nhìn vào chúng.
///
/// CÁCH DÙNG
/// ```dart
/// final _khoaNut = GlobalKey();
/// ...
/// ChiDan.chay(context, khoa: 'bao-tang-v1', cacBuoc: [
///   BuocChiDan(khoa: _khoaNut, tieuDe: '...', noiDung: '...'),
/// ]);
/// ```
///
/// NGUYÊN TẮC
///     Không bao giờ được chặn người dùng. Thiếu widget đích, chưa dựng xong,
///     hay nằm ngoài màn hình thì BỎ QUA bước đó chứ không báo lỗi và cũng
///     không hiện một ô trống lơ lửng.
class BuocChiDan {
  const BuocChiDan({
    required this.khoa,
    required this.tieuDe,
    required this.noiDung,
    this.boTronKhung = 14,
    this.leKhoet = 8,
  });

  /// Khoá của widget được chỉ tới.
  final GlobalKey khoa;

  final String tieuDe;
  final String noiDung;

  /// Bo tròn ô khoét sáng, nên khớp với bo tròn của chính widget đích.
  final double boTronKhung;

  /// Nới ô khoét rộng ra mỗi bên, để viền vàng không đè lên nội dung.
  final double leKhoet;
}

class ChiDan {
  ChiDan._();

  static const _tienTo = 'chi_dan_';

  /// Đang có một chuỗi chỉ dẫn trên màn hình — chuỗi khác phải chờ.
  static bool _dangHien = false;

  /// Test dựng rồi huỷ màn giữa chừng, hộp chỉ dẫn không kịp đóng — đặt lại cờ.
  @visibleForTesting
  static void datLaiChoTest() => _dangHien = false;

  /// Màn của [context] đang được nhìn thấy không.
  ///
  /// Vỏ điều hướng dựng SẴN cả 6 tab trong một IndexedStack và tắt TickerMode của
  /// tab ẩn. Trước 27/09 chỉ dẫn không xét điều này: mở app lần đầu là chỉ dẫn của
  /// Bảo tàng và Đấu trường cùng hiện CHỒNG lên trang chủ, chỉ vào chỗ không có gì.
  static bool _dangThay(BuildContext context) =>
      context.mounted && TickerMode.valuesOf(context).enabled;

  static Future<bool> daXem(String khoa) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool('$_tienTo$khoa') ?? false;
    } catch (_) {
      // Không đọc được bộ nhớ thì coi như đã xem — thà thiếu chỉ dẫn còn hơn
      // bắt người ta xem lại mỗi lần mở màn.
      return true;
    }
  }

  static Future<void> danhDauDaXem(String khoa) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('$_tienTo$khoa', true);
    } catch (_) {}
  }

  /// Xoá mọi dấu đã xem — dùng cho nút "Xem lại hướng dẫn".
  static Future<void> xoaHet() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final k
          in p.getKeys().where((k) => k.startsWith(_tienTo)).toList()) {
        await p.remove(k);
      }
    } catch (_) {}
  }

  /// Chạy một chuỗi chỉ dẫn nếu màn này chưa từng chỉ.
  ///
  /// [batBuoc] = true thì chạy kể cả đã xem (nút "Xem lại hướng dẫn").
  static Future<void> chay(
    BuildContext context, {
    required String khoa,
    required List<BuocChiDan> cacBuoc,
    bool batBuoc = false,
    Duration doTre = const Duration(milliseconds: 550),
  }) async {
    if (cacBuoc.isEmpty) return;
    if (!batBuoc && await daXem(khoa)) return;
    // Tab đang ẩn (hoặc chỉ dẫn khác đang hiện) thì CHỜ, tới lúc người dùng mở
    // tab này mới chỉ — chứ không bỏ: màn gọi chay() đúng một lần.
    while (!_dangThay(context) || _dangHien) {
      if (!context.mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!context.mounted) return;

    // Chờ màn dựng xong và hoạt hoạ vào màn chạy hết, nếu không thì đo được
    // toạ độ của widget lúc nó còn đang trượt vào — ô khoét sẽ lệch.
    await Future.delayed(doTre);
    if (!context.mounted) return;
    if (!_dangThay(context) || _dangHien) {
      // Người dùng vừa rời tab trong lúc chờ — thử lại từ đầu.
      return chay(context,
          khoa: khoa, cacBuoc: cacBuoc, batBuoc: batBuoc, doTre: doTre);
    }

    // Thử lại vài nhịp trước khi bỏ cuộc.
    //
    // Widget đích có thể chưa có mặt ở nhịp đầu: dữ liệu vừa về mà khung hình
    // chưa vẽ, hoặc màn nằm trong một tab chưa từng được dựng. Đã gặp thật —
    // chỉ dẫn Bảo tàng lặng lẽ không chạy vì `initState` của nó nổ ngay lúc
    // dựng vỏ điều hướng, khi cây widget còn chưa tồn tại.
    var conLai = <BuocChiDan>[];
    for (var lan = 0; lan < 10; lan++) {
      conLai = cacBuoc.where((b) => _viTri(b.khoa) != null).toList();
      if (conLai.isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 300));
      if (!context.mounted) return;
    }
    if (conLai.isEmpty) return;

    Analytics.instance.log(Ev.chiDanView, target: khoa, value: 1);
    _dangHien = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        useSafeArea: false,
        builder: (_) => _LopChiDan(khoa: khoa, cacBuoc: conLai),
      );
    } finally {
      _dangHien = false;
    }
    await danhDauDaXem(khoa);
  }

  /// Vị trí của widget đích, quy về hệ toạ độ của [goc].
  ///
  /// [goc] PHẢI là hộp chứa lớp phủ, không được bỏ trống khi vẽ. App bọc trong
  /// MobileFrame nên hộp thoại nằm lọt trong khung điện thoại giữa màn, trong
  /// khi localToGlobal trả toạ độ theo TOÀN CỬA SỔ — lệch nhau đúng bằng lề
  /// trái của khung. Bỏ qua chuyện này thì ô sáng bị vẽ ra ngoài khung và
  /// người dùng chỉ thấy một màn tối thui, không hiểu chuyện gì đang xảy ra.
  static Rect? _viTri(GlobalKey k, {RenderObject? goc}) {
    final ctx = k.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return null;
    if (goc != null && !goc.attached) return null;
    final tren = ro.localToGlobal(Offset.zero, ancestor: goc);
    final r = tren & ro.size;
    if (r.width <= 0 || r.height <= 0) return null;
    if (r.top.isNaN || r.left.isNaN) return null;
    return r;
  }
}

class _LopChiDan extends StatefulWidget {
  const _LopChiDan({required this.khoa, required this.cacBuoc});

  final String khoa;
  final List<BuocChiDan> cacBuoc;

  @override
  State<_LopChiDan> createState() => _LopChiDanState();
}

class _LopChiDanState extends State<_LopChiDan>
    with SingleTickerProviderStateMixin {
  int _i = 0;

  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _tiep() {
    if (_i >= widget.cacBuoc.length - 1) {
      Analytics.instance.log(Ev.chiDanDone, target: widget.khoa, value: _i + 1);
      Navigator.of(context).pop();
      return;
    }
    setState(() => _i++);
    Analytics.instance.log(Ev.chiDanView, target: widget.khoa, value: _i + 1);
    _ctl.forward(from: 0);
  }

  void _boQua() {
    Analytics.instance.log(Ev.chiDanSkip, target: widget.khoa, value: _i + 1);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final buoc = widget.cacBuoc[_i];
    // Quy toạ độ về hộp chứa lớp phủ, không phải toàn cửa sổ — xem ghi chú ở
    // ChiDan._viTri.
    final hop = Overlay.of(context).context.findRenderObject();
    final o = ChiDan._viTri(buoc.khoa, goc: hop);
    if (o == null) {
      // Widget biến mất giữa chừng (danh sách cuộn, dữ liệu nạp lại). Đi tiếp
      // ở khung sau thay vì hiện một ô khoét sai chỗ.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tiep());
      return const SizedBox.shrink();
    }
    final khoet = o.inflate(buoc.leKhoet);
    final man = hop is RenderBox && hop.hasSize
        ? hop.size
        : MediaQuery.of(context).size;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Chạm ra ngoài cũng đi tiếp — người dùng hay chạm đại để đóng.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tiep,
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (_, __) => CustomPaint(
                  painter: _ManChe(
                    khoet: khoet,
                    boTron: buoc.boTronKhung,
                    tienDo: Curves.easeOut.transform(_ctl.value),
                  ),
                ),
              ),
            ),
          ),
          _bongGiaiThich(buoc, khoet, man),
        ],
      ),
    );
  }

  Widget _bongGiaiThich(BuocChiDan buoc, Rect khoet, Size man) {
    const rong = 300.0;
    const chieuCaoUoc = 190.0;
    // Đặt dưới ô khoét nếu còn chỗ, không thì đặt lên trên. Không bao giờ để
    // bóng đè lên chính thứ đang chỉ.
    final duoi = khoet.bottom + chieuCaoUoc + 24 < man.height;
    final top = duoi ? khoet.bottom + 14 : null;
    final bottom = duoi ? null : man.height - khoet.top + 14;
    var left = khoet.center.dx - rong / 2;
    left = left.clamp(14.0, (man.width - rong - 14).clamp(14.0, man.width));

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      width: rong,
      child: FadeTransition(
        opacity: _ctl,
        child: SlideTransition(
          position: Tween(
            begin: Offset(0, duoi ? -0.04 : 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOut)),
          child: _the(buoc),
        ),
      ),
    );
  }

  Widget _the(BuocChiDan buoc) {
    final tong = widget.cacBuoc.length;
    final cuoi = _i >= tong - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x552B1410), blurRadius: 22, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            buoc.tieuDe,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            buoc.noiDung,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.inkSoft,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${_i + 1}/$tong',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  color: AppColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!cuoi)
                TextButton(
                  onPressed: _boQua,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                  ),
                  child: const Text(
                    'Bỏ qua',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: cuoi ? 'Đã hiểu' : 'Tiếp',
                child: InkWell(
                  onTap: _tiep,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: ctaGradient,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      cuoi ? 'Đã hiểu' : 'Tiếp',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Màn che tối toàn màn hình, khoét một ô sáng quanh thứ đang được chỉ.
class _ManChe extends CustomPainter {
  _ManChe({required this.khoet, required this.boTron, required this.tienDo});

  final Rect khoet;
  final double boTron;
  final double tienDo;

  @override
  void paint(Canvas canvas, Size size) {
    final toanMan = Rect.fromLTWH(0, 0, size.width, size.height);
    final o = RRect.fromRectAndRadius(khoet, Radius.circular(boTron));

    // Khoét bằng fillType evenOdd: một đường bao cả màn hình, một đường bao ô
    // sáng — phần giao nhau không được tô.
    final che = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(toanMan)
      ..addRRect(o);
    canvas.drawPath(
      che,
      Paint()..color = const Color(0xFF2B1410).withValues(alpha: 0.80 * tienDo),
    );

    // Viền vàng quanh ô sáng, kèm một vòng loang nhẹ để mắt bắt được ngay.
    canvas.drawRRect(
      o,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.goldBright.withValues(alpha: tienDo),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          khoet.inflate(5 * tienDo), Radius.circular(boTron + 5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.goldBright.withValues(alpha: 0.35 * tienDo),
    );
  }

  @override
  bool shouldRepaint(_ManChe cu) =>
      cu.khoet != khoet || cu.tienDo != tienDo || cu.boTron != boTron;
}
