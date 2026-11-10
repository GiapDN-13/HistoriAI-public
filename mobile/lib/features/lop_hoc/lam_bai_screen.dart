import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'bang_vang.dart';
import 'giao_dien/san_choi.dart';
import 'truc_tiep/widget_truc_tiep.dart';
import 'lop_hoc_api.dart';

/// Học sinh làm bài trong phòng kiểm tra.
///
/// Từng câu một, đếm giờ theo đề; chọn là gửi ngay và KHÔNG sửa được (như thi thật —
/// máy chủ cũng chỉ nhận lần đầu). Vào lại giữa chừng thì bỏ qua các câu đã làm. Hết câu
/// thì nộp; phòng bị đóng giữa chừng cũng nộp phần đã làm. Nộp xong mới thấy đáp án.
class LamBaiScreen extends StatefulWidget {
  const LamBaiScreen(
      {super.key, required this.ma, required this.tieuDe, this.api});

  final String ma;
  final String tieuDe;
  final LopHocApi? api;

  @override
  State<LamBaiScreen> createState() => _LamBaiScreenState();
}

class _LamBaiScreenState extends State<LamBaiScreen> {
  late final LopHocApi _api = widget.api ?? LopHocApi();
  List<Map<String, dynamic>> _cau = [];
  int _i = 0;
  int _giayMoiCau = 30;
  int _conLai = 30;
  Timer? _dem;
  bool _dangGui = false;
  String? _daChon;
  bool? _dung;
  Map<String, dynamic>? _ketQua;
  String? _loi;
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  @override
  void dispose() {
    _dem?.cancel();
    super.dispose();
  }

  Future<void> _tai() async {
    try {
      final d = await _api.layDe(widget.ma);
      final bai = (d['bai'] as Map).cast<String, dynamic>();
      final cau = (d['cau'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      if (bai['da_nop'] == true) {
        await _nop();
        return;
      }
      setState(() {
        _cau = cau;
        _giayMoiCau = (bai['giay_moi_cau'] as num?)?.toInt() ?? 30;
        _i = cau.indexWhere((c) => c['da_chon'] == null);
        _dangTai = false;
      });
      if (_i < 0) {
        await _nop();
      } else {
        _batDau();
      }
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          _loi = e.message;
          _dangTai = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loi = 'Không kết nối được. Kiểm tra mạng rồi mở lại.';
          _dangTai = false;
        });
    }
  }

  void _batDau() {
    _dem?.cancel();
    setState(() {
      _conLai = _giayMoiCau;
      _daChon = null;
      _dung = null;
    });
    _dem = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_conLai <= 1) {
        t.cancel();
        _chon(''); // hết giờ = bỏ trống
      } else {
        setState(() => _conLai--);
      }
    });
  }

  Future<void> _chon(String o) async {
    if (_dangGui || _daChon != null) return;
    _dem?.cancel();
    setState(() {
      _dangGui = true;
      _daChon = o;
    });
    try {
      final dung = await _api.traLoi(widget.ma, _cau[_i]['id'] as int, o);
      if (!mounted) return;
      setState(() => _dung = dung);
    } on ApiException catch (e) {
      if (e.statusCode == 410 || e.statusCode == 409) {
        await _nop(); // phòng đóng / đã nộp: nộp phần đã làm
        return;
      }
      if (!mounted) return;
      setState(() {
        _daChon = null;
        _loi = e.message;
      });
      _batDau();
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _daChon = null;
        _loi = 'Mất kết nối — chọn lại đáp án.';
      });
      _batDau();
      return;
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _loi = null);
    if (_i >= _cau.length - 1) {
      await _nop();
    } else {
      setState(() => _i++);
      _batDau();
    }
  }

  Future<void> _nop() async {
    _dem?.cancel();
    setState(() => _dangTai = true);
    try {
      final kq = await _api.nop(widget.ma);
      if (mounted)
        setState(() {
          _ketQua = kq;
          _dangTai = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loi = 'Chưa nộp được bài. Kiểm tra mạng rồi bấm Nộp lại.';
          _dangTai = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _ketQua != null || _cau.isEmpty,
      onPopInvokedWithResult: (daPop, _) {
        if (!daPop) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Đang làm bài — làm hết hoặc chờ hết giờ từng câu nhé.'),
          ));
        }
      },
      child: KhungLopHoc(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.red,
          foregroundColor: AppColors.goldBright,
          automaticallyImplyLeading: _ketQua != null || _cau.isEmpty,
          title: Text(widget.tieuDe, overflow: TextOverflow.ellipsis),
        ),
        body: _than(),
      ),
    );
  }

  Widget _than() {
    if (_dangTai)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.red));
    if (_ketQua != null) return _KetQua(kq: _ketQua!, ma: widget.ma, api: _api);
    if (_cau.isEmpty || _i < 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_loi ?? 'Không có câu hỏi.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _nop, child: const Text('Nộp lại')),
          ]),
        ),
      );
    }
    final c = _cau[_i];
    final pa = (c['options'] as Map).cast<String, dynamic>();
    return KhungCauHoi(
      dau: Row(children: [
        Text('Câu ${_i + 1}/${_cau.length}', style: AppTypography.labelMedium),
        const Spacer(),
        Text('${_conLai}s',
            style: AppTypography.headingMedium.copyWith(
                color: _conLai <= 5 ? AppColors.danger : AppColors.ink)),
      ]),
      cauHoi: '${c['question']}',
      dapAn: (caoO) => LuoiDapAn(
          caoO: caoO,
          options: pa,
          daChon: _daChon,
          dungDaChon: _dung,
          onChon: _daChon == null ? _chon : null),
      phanHoi: _loi != null
          ? Text(_loi!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.danger))
          : _dung == null
              ? null
              : NhipSanChoi(
                  key: ValueKey('$_i:$_dung'),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            _dung!
                                ? Icons.check_circle_rounded
                                : Icons.info_outline_rounded,
                            color:
                                _dung! ? AppColors.success : AppColors.danger),
                        const SizedBox(width: 8),
                        Text(
                            _dung!
                                ? 'Chính xác!'
                                : (_daChon == '' ? 'Hết giờ' : 'Chưa đúng'),
                            style: AppTypography.labelMedium.copyWith(
                                color: _dung!
                                    ? AppColors.success
                                    : AppColors.danger)),
                      ])),
    );
  }
}

class _KetQua extends StatelessWidget {
  const _KetQua({required this.kq, required this.ma, required this.api});

  final Map<String, dynamic> kq;
  final String ma;
  final LopHocApi api;

  @override
  Widget build(BuildContext context) {
    final cau = (kq['cau'] as List).cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: imperialDarkGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(children: [
            const Text('ĐÃ NỘP BÀI',
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldBright,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text('${kq['so_dung']}/${kq['tong']} câu đúng',
                style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                    color: AppColors.onRed)),
            const SizedBox(height: 4),
            Text('Điểm ${kq['diem_10']} / 10',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: AppColors.onRed.withValues(alpha: .9),
                    fontSize: 16)),
            const SizedBox(height: 8),
            Text(
                'Kết quả đã gửi cho thầy cô. Câu sai đã vào mục "Ôn câu sai" trong Hồ sơ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: AppColors.onRed.withValues(alpha: .8),
                    fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),
        BangVangPhong(ma: ma, api: api),
        const SizedBox(height: 18),
        const Text('XEM LẠI TỪNG CÂU',
            style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        for (final c in cau) _XemLaiCau(c: c),
      ],
    );
  }
}

class _XemLaiCau extends StatelessWidget {
  const _XemLaiCau({required this.c});

  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final pa = (c['options'] as Map).cast<String, dynamic>();
    final dung = c['dung'] == true;
    final chon = '${c['chon'] ?? ''}';
    final dapAn = '${c['correct_option']}';
    final mau = dung ? AppColors.success : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mau.withValues(alpha: .35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${c['question']}',
            style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: AppColors.ink)),
        const SizedBox(height: 6),
        Text('Em chọn: ${chon.isEmpty ? '(hết giờ)' : '$chon. ${pa[chon]}'}',
            style: TextStyle(
                fontFamily: 'Inter', fontWeight: FontWeight.w400, color: mau)),
        if (!dung)
          Text('Đáp án: $dapAn. ${pa[dapAn]}',
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.success)),
        if ((c['explanation'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${c['explanation']}',
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  color: AppColors.inkSoft,
                  fontSize: 13,
                  height: 1.4)),
        ],
      ]),
    );
  }
}
