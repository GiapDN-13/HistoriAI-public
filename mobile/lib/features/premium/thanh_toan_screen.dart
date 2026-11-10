import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'premium_chung.dart';

/// Màn chuyển khoản cho một đơn Premium: mã QR + thông tin tài khoản + đếm
/// ngược, tự hỏi máy chủ xem tiền đã về chưa.
///
/// VÌ SAO HỎI ĐỊNH KỲ MÀ KHÔNG ĐỢI NGƯỜI DÙNG BẤM "TÔI ĐÃ CHUYỂN"
///     SePay báo cho máy chủ khi tiền về — app không có cách nào tự biết. Bắt
///     người dùng bấm xác nhận thì người chưa chuyển cũng bấm được, còn người
///     đã chuyển lại phải đoán lúc nào bấm. Hỏi mỗi 4 giây thì người học thấy
///     "Đã kích hoạt" ngay khi tiền vào mà không cần làm gì thêm.
///
/// Bấm "Xong" sau khi thành công thì đóng màn này trả `true`. Người dùng thoát
/// bằng nút Back cũng được — màn Premium luôn nạp lại tình trạng khi quay về,
/// nên tiền đã về mà họ lỡ bấm Back vẫn thấy Premium đã bật.
class ThanhToanScreen extends StatefulWidget {
  const ThanhToanScreen({super.key, required this.goi});

  final GoiPremium goi;

  @override
  State<ThanhToanScreen> createState() => _ThanhToanScreenState();
}

enum _Buoc { dangTao, cho, thanhCong, hetHan, loi }

/// Một đơn chờ thanh toán — đúng các trường máy chủ trả ở `POST /thanh-toan/don`.
class _Don {
  const _Don({
    required this.ma,
    required this.soTien,
    required this.noiDung,
    required this.nganHang,
    required this.soTk,
    required this.chuTk,
    required this.qr,
    required this.hetHan,
  });

  final String ma;
  final int soTien;
  final String noiDung;
  final String nganHang;
  final String soTk;
  final String chuTk;
  final String qr;
  final DateTime? hetHan;

  static _Don? tuJson(Object? j) {
    if (j is! Map) return null;
    final ma = j['ma_don'];
    final soTien = j['so_tien'];
    final qr = j['qr_chuoi'];
    if (ma is! String || soTien is! num || qr is! String) return null;
    final nh = j['ngan_hang'] is Map ? j['ngan_hang'] as Map : const {};
    return _Don(
      ma: ma,
      soTien: soTien.toInt(),
      // Nội dung chuyển khoản chính là mã đơn — máy chủ dựa vào nó để biết
      // tiền thuộc đơn nào. Thiếu trường thì dùng mã đơn.
      noiDung: (j['noi_dung'] as String?) ?? ma,
      nganHang: '${nh['ten'] ?? ''}',
      soTk: '${nh['so_tk'] ?? ''}',
      chuTk: '${nh['chu_tk'] ?? ''}',
      qr: qr,
      hetHan: docThoiDiem(j['het_han']),
    );
  }
}

class _ThanhToanScreenState extends State<ThanhToanScreen> {
  static const _chuKyHoi = Duration(seconds: 4);

  final _api = ApiClient();

  _Buoc _buoc = _Buoc.dangTao;
  _Don? _don;
  String? _thongBaoLoi;

  /// Đang không hỏi được trạng thái (mất mạng giữa chừng). Báo rõ ra màn hình
  /// thay vì im lặng — người dùng đã chuyển tiền cần biết app chưa kiểm được.
  bool _matMang = false;
  Duration _conLai = Duration.zero;
  DateTime? _premiumDen;

  Timer? _hoiDinhKy;
  Timer? _demNguoc;
  bool _dangHoi = false;

  @override
  void initState() {
    super.initState();
    _taoDon();
  }

  @override
  void dispose() {
    _huyHenGio();
    super.dispose();
  }

  void _huyHenGio() {
    _hoiDinhKy?.cancel();
    _demNguoc?.cancel();
    _hoiDinhKy = null;
    _demNguoc = null;
  }

  Future<void> _taoDon() async {
    _huyHenGio();
    setState(() {
      _buoc = _Buoc.dangTao;
      _thongBaoLoi = null;
      _matMang = false;
    });
    try {
      final res = await _api.post('/thanh-toan/don', {'goi': widget.goi.ma});
      final don = _Don.tuJson(res);
      if (!mounted) return;
      if (don == null) {
        setState(() {
          _buoc = _Buoc.loi;
          _thongBaoLoi = 'Hệ thống trả về đơn không hợp lệ. Hãy thử lại sau ít phút.';
        });
        return;
      }
      setState(() {
        _don = don;
        _buoc = _Buoc.cho;
        _capNhatConLai();
      });
      _batHenGio();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _buoc = _Buoc.loi;
        _thongBaoLoi = e.isConnectionError
            ? 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'
            : switch (e.statusCode) {
                503 => 'Thanh toán chưa được mở. Bạn thử lại sau nhé.',
                401 => 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại rồi thanh toán.',
                _ => e.message,
              };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _buoc = _Buoc.loi;
        _thongBaoLoi = 'Chưa tạo được mã thanh toán. Kiểm tra mạng rồi thử lại.';
      });
    }
  }

  void _batHenGio() {
    _demNguoc = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _buoc != _Buoc.cho) return;
      setState(_capNhatConLai);
      // Hết giờ nhưng tiền có thể vừa về: hỏi máy chủ một lần cuối rồi mới kết luận.
      if (_conLai == Duration.zero) _hoiTrangThai();
    });
    _hoiDinhKy = Timer.periodic(_chuKyHoi, (_) => _hoiTrangThai());
  }

  void _capNhatConLai() {
    final han = _don?.hetHan;
    if (han == null) {
      _conLai = const Duration(days: 1); // không biết hạn → để máy chủ quyết
      return;
    }
    final d = han.difference(DateTime.now());
    _conLai = d.isNegative ? Duration.zero : d;
  }

  Future<void> _hoiTrangThai() async {
    final don = _don;
    if (_dangHoi || don == null || _buoc != _Buoc.cho) return;
    _dangHoi = true;
    try {
      final res = await _api.get('/thanh-toan/don/${don.ma}');
      if (!mounted || _buoc != _Buoc.cho) return;
      final tt = res is Map ? res['trang_thai'] : null;
      if (tt == 'da_tra') {
        _huyHenGio();
        var den = docThoiDiem((res as Map)['premium_den']);
        den ??= await _docPremiumDen();
        if (!mounted) return;
        setState(() {
          _premiumDen = den;
          _matMang = false;
          _buoc = _Buoc.thanhCong;
        });
      } else if (tt == 'het_han' || _conLai == Duration.zero) {
        _huyHenGio();
        setState(() {
          _matMang = false;
          _buoc = _Buoc.hetHan;
        });
      } else if (_matMang) {
        setState(() => _matMang = false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        // Máy chủ không biết đơn này nữa: đừng để người dùng đợi mãi.
        _huyHenGio();
        setState(() => _buoc = _Buoc.hetHan);
      } else if (!_matMang) {
        setState(() => _matMang = true);
      }
    } catch (_) {
      if (mounted && !_matMang) setState(() => _matMang = true);
    } finally {
      _dangHoi = false;
    }
  }

  /// Làm mới hồ sơ để lấy ngày hết hạn khi phản hồi đơn không kèm theo.
  Future<DateTime?> _docPremiumDen() async {
    try {
      final me = await _api.get('/auth/me');
      return me is Map ? docThoiDiem(me['premium_den']) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _chep(String chu, String ten) async {
    await Clipboard.setData(ClipboardData(text: chu));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Đã chép $ten'),
        duration: const Duration(seconds: 2),
      ));
  }

  bool get _laDienThoai =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.red,
          foregroundColor: AppColors.goldBright,
          centerTitle: true,
          title: const Text(
            'CHUYỂN KHOẢN',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: 1.1,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: switch (_buoc) {
            _Buoc.dangTao => [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.red),
                  ),
                ),
              ],
            _Buoc.loi => _giaoDienLoi(),
            _Buoc.hetHan => _giaoDienHetHan(),
            _Buoc.thanhCong => _giaoDienThanhCong(),
            _Buoc.cho => _giaoDienCho(_don!),
          },
        ),
    );
  }

  // ───────────── Chờ chuyển khoản ─────────────

  List<Widget> _giaoDienCho(_Don don) {
    return [
      Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white, // nền trắng: ứng dụng ngân hàng cần tương phản để quét
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold, width: 1.5),
            boxShadow: appSoftShadow,
          ),
          child: Semantics(
            label: 'Mã QR chuyển khoản ${dinhDangTien(don.soTien)} đồng',
            child: QrImageView(
              data: don.qr,
              size: 260,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Center(child: _DongHo(conLai: _conLai, biet: don.hetHan != null)),
      if (_matMang) ...[
        const SizedBox(height: 10),
        const _Khung(
          mau: AppColors.danger,
          bieuTuong: Icons.wifi_off_rounded,
          chu: 'Chưa kiểm tra được trạng thái do mất kết nối. App vẫn tự thử '
              'lại. Nếu bạn đã chuyển khoản, tiền không bị mất.',
        ),
      ],
      if (_laDienThoai) ...[
        const SizedBox(height: 10),
        const Text(
          'Mở app ngân hàng → Quét mã, hoặc chụp màn hình này rồi chọn ảnh QR '
          'trong app ngân hàng.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.inkSoft,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
      const SizedBox(height: 16),
      _DongThongTin(
        nhan: 'Ngân hàng',
        giaTri: don.nganHang,
        onChep: () => _chep(don.nganHang, 'tên ngân hàng'),
      ),
      _DongThongTin(
        nhan: 'Số tài khoản',
        giaTri: don.soTk,
        onChep: () => _chep(don.soTk, 'số tài khoản'),
      ),
      _DongThongTin(
        nhan: 'Chủ tài khoản',
        giaTri: don.chuTk,
        onChep: () => _chep(don.chuTk, 'tên chủ tài khoản'),
      ),
      _DongThongTin(
        nhan: 'Số tiền',
        giaTri: '${dinhDangTien(don.soTien)}đ',
        onChep: () => _chep('${don.soTien}', 'số tiền'),
        noiBat: true,
      ),
      _DongThongTin(
        nhan: 'Nội dung chuyển khoản',
        giaTri: don.noiDung,
        onChep: () => _chep(don.noiDung, 'nội dung chuyển khoản'),
        noiBat: true,
      ),
      const SizedBox(height: 6),
      const _Khung(
        mau: AppColors.goldDark,
        bieuTuong: Icons.info_outline_rounded,
        chu: 'Giữ nguyên nội dung chuyển khoản để hệ thống tự nhận ra. Sửa hay '
            'bỏ nội dung thì Premium sẽ không tự được kích hoạt.',
      ),
      const SizedBox(height: 14),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.gold),
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Đang chờ tiền về — màn này tự cập nhật',
              style: TextStyle(
                  fontFamily: 'Inter', color: AppColors.inkSoft, fontSize: 12.5),
            ),
          ),
        ],
      ),
    ];
  }

  // ───────────── Thành công / hết hạn / lỗi ─────────────

  List<Widget> _giaoDienThanhCong() {
    final den = _premiumDen;
    return [
      const SizedBox(height: 24),
      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 72),
      const SizedBox(height: 14),
      Text(
        den == null
            ? 'Đã kích hoạt Premium'
            : 'Đã kích hoạt Premium đến ${dinhDangNgay(den)}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          color: AppColors.ink,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Cảm ơn bạn. Giờ bạn có thể hỏi vĩ nhân không giới hạn, ôn toàn bộ câu sai '
        'và học trọn bài theo lộ trình.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: 'Inter', color: AppColors.inkSoft, fontSize: 14, height: 1.5),
      ),
      const SizedBox(height: 26),
      NutPremium(
        nhan: 'Xong',
        onTap: () => Navigator.of(context).pop(true),
      ),
    ];
  }

  List<Widget> _giaoDienHetHan() => [
        const SizedBox(height: 24),
        const Icon(Icons.timer_off_rounded, color: AppColors.goldDark, size: 64),
        const SizedBox(height: 14),
        const Text(
          'Mã thanh toán đã hết hạn',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Đừng chuyển tiền vào mã này nữa. Bạn tạo mã mới để thanh toán nhé. '
          'Nếu lỡ chuyển rồi mà Premium chưa lên, hãy nhắn cho nhóm để được hỗ trợ.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Inter', color: AppColors.inkSoft, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 24),
        NutPremium(nhan: 'Tạo mã mới', onTap: _taoDon),
      ];

  List<Widget> _giaoDienLoi() => [
        const SizedBox(height: 24),
        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 60),
        const SizedBox(height: 14),
        Text(
          _thongBaoLoi ?? 'Chưa tạo được mã thanh toán.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Inter', color: AppColors.ink, fontSize: 14.5, height: 1.5),
        ),
        const SizedBox(height: 24),
        NutPremium(nhan: 'Thử lại', onTap: _taoDon),
      ];
}

/// "Mã hết hạn sau 14:52".
class _DongHo extends StatelessWidget {
  const _DongHo({required this.conLai, required this.biet});

  final Duration conLai;
  final bool biet;

  @override
  Widget build(BuildContext context) {
    if (!biet) return const SizedBox.shrink();
    String hai(int n) => n.toString().padLeft(2, '0');
    final phut = conLai.inMinutes;
    final giay = conLai.inSeconds % 60;
    return Text(
      'Mã hết hạn sau ${hai(phut)}:${hai(giay)}',
      style: TextStyle(
        fontFamily: 'Montserrat',
        color: conLai.inMinutes < 2 ? AppColors.danger : AppColors.inkSoft,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Một dòng "nhãn — giá trị — nút chép".
class _DongThongTin extends StatelessWidget {
  const _DongThongTin({
    required this.nhan,
    required this.giaTri,
    required this.onChep,
    this.noiBat = false,
  });

  final String nhan;
  final String giaTri;
  final VoidCallback onChep;
  final bool noiBat;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: noiBat ? AppColors.bgAlt : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: noiBat ? AppColors.gold : AppColors.border,
          width: noiBat ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nhan,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.inkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  giaTri,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.ink,
                    fontSize: noiBat ? 17 : 15,
                    fontWeight: noiBat ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chép $nhan',
            onPressed: onChep,
            icon: const Icon(Icons.copy_rounded,
                size: 19, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Khung nhắc có thanh màu bên trái.
class _Khung extends StatelessWidget {
  const _Khung({required this.mau, required this.bieuTuong, required this.chu});

  final Color mau;
  final IconData bieuTuong;
  final String chu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border(left: BorderSide(color: mau, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(bieuTuong, color: mau, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              chu,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF5C4033),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
