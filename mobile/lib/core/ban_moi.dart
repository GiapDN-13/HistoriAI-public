import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tai_ban_cai_stub.dart' if (dart.library.io) 'tai_ban_cai_io.dart';
import 'theme.dart';

/// Báo cho người dùng bản cài Android khi đã có bản mới.
///
/// VÌ SAO CẦN
///   Bản web tự cập nhật mỗi lần tải trang, còn APK cài tay thì không: người đã
///   cài dùng mãi bản cũ, gặp lỗi đã sửa từ lâu mà nhóm không hề biết.
///
/// CÁCH LÀM
///   `tool/dong_goi_ban_cai.py` sinh `tai-app/phien-ban.json` cùng lúc với APK.
///   Mở app, bản Android đọc tệp đó rồi so số `build` với số bản đang chạy
///   (phần sau dấu + của `version:` trong pubspec.yaml — NHỚ tăng mỗi lần phát hành).
///   Mỗi bản mới chỉ hỏi một lần; `bat_buoc: true` thì lần mở nào cũng hỏi.
///   Mọi lỗi (mất mạng, tệp chưa có) đều im lặng — không bao giờ chặn người dùng.
///
/// TỰ TẢI VÀ MỞ MÀN CÀI (từ 0.5.2)
///   `phien-ban.json` có thêm link bản cài theo loại máy (`apk.arm64` / `apk.arm32`).
///   Bấm "Tải và cài": app tải về thư mục cache của mình, rồi mở trình cài đặt của
///   Android (kênh `historiai/cai_dat` trong MainActivity.kt) — người dùng chỉ bấm
///   "Cài đặt". Lần đầu Android hỏi có cho HistoriAI cài ứng dụng không. Hỏng bước
///   nào thì mở trang tải như cũ.
class BanMoi {
  BanMoi._();

  static const _khoaDaBao = 'ban_moi_da_bao';
  static bool _daKiem = false;

  /// Số build thật, bỏ phần Flutter cộng thêm khi dựng tách theo loại máy
  /// (--split-per-abi: arm32 +1000, arm64 +2000, x86_64 +4000). PackageInfo trả
  /// nguyên versionCode (vd 2009), phien-ban.json ghi 2000 + n — so phần dư mới đúng.
  @visibleForTesting
  static int buildThat(int versionCode) => versionCode % 1000;

  /// Thông tin bản mới cần báo, hoặc null nếu không cần báo.
  @visibleForTesting
  static ThongTinBanMoi? canBao({
    required int buildDangChay,
    required Map<String, dynamic> duLieu,
    required int? daBaoBuild,
  }) {
    buildDangChay = buildThat(buildDangChay);
    final soGhi = (duLieu['build'] as num?)?.toInt();
    final build = soGhi == null ? null : buildThat(soGhi);
    final link = duLieu['link'] as String?;
    if (build == null || link == null || build <= buildDangChay) return null;
    final batBuoc = duLieu['bat_buoc'] == true;
    if (!batBuoc && daBaoBuild == build) return null;
    final apk = <String, BanCai>{};
    final tho = duLieu['apk'];
    if (tho is Map) {
      tho.forEach((k, v) {
        final url = v is Map ? v['url'] : null;
        if (url is String && _nguonTinCay(url)) {
          apk['$k'] = BanCai(url, (v['byte'] as num?)?.toInt());
        }
      });
    }
    return ThongTinBanMoi(
      phienBan: duLieu['phien_ban'] as String? ?? '',
      build: build,
      link: link,
      ghiChu: duLieu['ghi_chu'] as String?,
      batBuoc: batBuoc,
      apk: apk,
    );
  }

  /// Chỉ tải bản cài từ chính historiai.org qua https.
  static bool _nguonTinCay(String url) {
    final u = Uri.tryParse(url);
    return u != null && u.scheme == 'https' && u.host == 'historiai.org';
  }

  /// Bản cài hợp với máy: ưu tiên 64-bit, không thì 32-bit. Null nếu không có bản hợp
  /// (vd máy x86) — khi đó mở trang tải.
  @visibleForTesting
  static BanCai? chonBanCai(List<String> abi, Map<String, BanCai> apk) {
    if (abi.contains('arm64-v8a') && apk['arm64'] != null) return apk['arm64'];
    if (abi.contains('armeabi-v7a') && apk['arm32'] != null) return apk['arm32'];
    return null;
  }

  static const _kenh = MethodChannel('historiai/cai_dat');

  /// Gọi một lần sau khi vào màn chính. Web và iOS bỏ qua.
  static Future<void> kiem(BuildContext context) async {
    if (_daKiem || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _daKiem = true;
    try {
      const goc = String.fromEnvironment('API_BASE_URL',
          defaultValue: 'https://historiai.org');
      final uri = Uri.parse(
          '$goc/tai-app/phien-ban.json?t=${DateTime.now().millisecondsSinceEpoch}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final duLieu =
          (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
      final info = await PackageInfo.fromPlatform();
      final prefs = await SharedPreferences.getInstance();
      final tt = canBao(
        buildDangChay: int.tryParse(info.buildNumber) ?? 0,
        duLieu: duLieu,
        daBaoBuild: prefs.getInt(_khoaDaBao),
      );
      if (tt == null || !context.mounted) return;
      await prefs.setInt(_khoaDaBao, tt.build);
      if (!context.mounted) return;
      await _hoi(context, tt);
    } catch (_) {
      // im lặng: kiểm bản mới hỏng không được làm hỏng app
    }
  }

  /// Trang tải bản cài — dùng cho nút "Tải app Android" trên bản web.
  static final trangTai = Uri.parse('https://historiai.org/tai-app/');

  /// Người dùng tự bấm "Kiểm tra bản mới" (bản cài Android). Khác [kiem]: luôn trả lời,
  /// kể cả khi đã là bản mới nhất hoặc mất mạng — bấm mà im re là tưởng nút hỏng.
  static Future<void> kiemThuCong(BuildContext context) async {
    final tinNhan = ScaffoldMessenger.of(context);
    try {
      const goc = String.fromEnvironment('API_BASE_URL',
          defaultValue: 'https://historiai.org');
      final res = await http
          .get(Uri.parse('$goc/tai-app/phien-ban.json?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception();
      final duLieu = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
      final info = await PackageInfo.fromPlatform();
      final tt = canBao(
        buildDangChay: int.tryParse(info.buildNumber) ?? 0,
        duLieu: {...duLieu, 'bat_buoc': false},
        daBaoBuild: null,
      );
      if (!context.mounted) return;
      if (tt == null) {
        tinNhan.showSnackBar(SnackBar(
            content: Text('Bạn đang dùng bản mới nhất (${info.version}).')));
        return;
      }
      await _hoi(context, tt);
    } catch (_) {
      tinNhan.showSnackBar(const SnackBar(
          content: Text('Chưa kiểm tra được — kiểm tra mạng rồi thử lại.')));
    }
  }

  static Future<void> _hoi(BuildContext context, ThongTinBanMoi tt) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !tt.batBuoc,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Đã có bản mới ${tt.phienBan}'.trim()),
        content: Text(
          (tt.ghiChu?.isNotEmpty ?? false)
              ? tt.ghiChu!
              : 'Bản mới sửa lỗi và thêm nội dung. Tải về rồi cài đè lên bản cũ — '
                  'tài khoản và tiến độ học vẫn giữ nguyên.',
        ),
        actions: [
          if (!tt.batBuoc)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Để sau'),
            ),
          FilledButton(
            onPressed: () {
              if (tt.apk.isNotEmpty && !kIsWeb) {
                Navigator.pop(ctx);
                _taiVaCai(context, tt);
                return;
              }
              launchUrl(Uri.parse(tt.link),
                  mode: LaunchMode.externalApplication);
              if (!tt.batBuoc) Navigator.pop(ctx);
            },
            child: Text(tt.apk.isNotEmpty && !kIsWeb ? 'Tải và cài' : 'Tải bản mới'),
          ),
        ],
      ),
    );
  }

  /// Có quyền cài chưa; chưa thì giải thích, mở công tắc, chờ người dùng quay lại
  /// app rồi kiểm lại. False nếu người dùng thôi hoặc vẫn chưa bật.
  static Future<bool> _coQuyenCai(BuildContext context) async {
    Future<bool> co() async =>
        (await _kenh.invokeMethod<bool>('choPhepCai')) ?? true;
    // Quay lại mà vẫn chưa bật (bấm nhầm, quên) thì hỏi lại chứ không im lặng.
    for (var lan = 0;; lan++) {
      if (await co()) return true;
      if (!context.mounted) return false;
      final di = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(lan == 0 ? 'Cho phép HistoriAI cài bản mới' : 'Chưa bật quyền cài'),
          content: Text('${lan == 0 ? 'Lần đầu, Android cần bạn cho phép một lần:' : 'Máy vẫn chưa cho HistoriAI cài bản mới. Thử lại:'}\n\n'
              '1. Bấm "Mở cài đặt"\n'
              '2. Bật "Cho phép từ nguồn này" (máy tiếng Anh: "Allow from this source")\n'
              '3. Bấm quay lại — màn cài sẽ hiện ra.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Để sau')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true), child: const Text('Mở cài đặt')),
          ],
        ),
      );
      if (di != true) return false;
      final quayLai = Completer<void>();
      final nghe = AppLifecycleListener(onResume: () {
        if (!quayLai.isCompleted) quayLai.complete();
      });
      try {
        await _kenh.invokeMethod('moQuyenCai');
        await quayLai.future.timeout(const Duration(minutes: 10));
      } catch (_) {
        return false;
      } finally {
        nghe.dispose();
      }
    }
  }

  static void _moTrangTai(ThongTinBanMoi tt) =>
      launchUrl(Uri.parse(tt.link), mode: LaunchMode.externalApplication);

  /// Tải bản cài (có thanh tiến độ, huỷ được) rồi mở trình cài đặt của Android.
  static Future<void> _taiVaCai(BuildContext context, ThongTinBanMoi tt) async {
    BanCai? ban;
    String? thuMuc;
    try {
      final abi = ((await _kenh.invokeMethod<List>('abi')) ?? const []).cast<String>();
      ban = chonBanCai(abi, tt.apk);
      thuMuc = await _kenh.invokeMethod<String>('thuMuc');
    } catch (_) {}
    if (ban == null || thuMuc == null) {
      _moTrangTai(tt);
      return;
    }
    if (!context.mounted) return;
    final tienDo = ValueNotifier<double?>(null);
    var huy = false;
    final ketQua = showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Đang tải bản ${tt.phienBan}'.trim()),
        content: ValueListenableBuilder<double?>(
          valueListenable: tienDo,
          builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: v),
            const SizedBox(height: 10),
            Text(v == null
                ? 'Đang kết nối…'
                : '${(v * 100).round()}%'
                    '${ban!.byte != null ? ' · ${(ban.byte! / 1048576).toStringAsFixed(0)} MB' : ''}'),
            const SizedBox(height: 6),
            const Text('Tải xong, máy sẽ hỏi "Cài đặt" — bấm để cài đè, dữ liệu giữ nguyên.',
                style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              huy = true;
              Navigator.pop(ctx);
            },
            child: const Text('Huỷ'),
          ),
        ],
      ),
    );
    var dongHop = false;
    ketQua.whenComplete(() => dongHop = true);
    try {
      final duongDan = await taiBanCai(
        url: ban.url,
        thuMuc: thuMuc,
        build: tt.build,
        tongByte: ban.byte,
        tienDo: (v) => tienDo.value = v,
        daHuy: () => huy,
      );
      if (context.mounted && !dongHop) Navigator.of(context, rootNavigator: true).pop();
      if (!await _coQuyenCai(context)) return;
      await _kenh.invokeMethod('cai', {'duong_dan': duongDan});
    } catch (_) {
      if (huy) return;
      if (context.mounted && !dongHop) Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Chưa tải được bản mới'),
          content: const Text('Mạng có thể bị ngắt giữa chừng. Thử lại, hoặc mở trang tải '
              'để tải bằng trình duyệt.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Để sau')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _moTrangTai(tt);
              },
              child: const Text('Mở trang tải'),
            ),
          ],
        ),
      );
    }
    // Không dispose tienDo: hộp tiến độ có thể còn đang chạy hiệu ứng đóng.
  }
}

class BanCai {
  const BanCai(this.url, this.byte);
  final String url;
  final int? byte;
}

class ThongTinBanMoi {
  const ThongTinBanMoi({
    required this.phienBan,
    required this.build,
    required this.link,
    this.ghiChu,
    this.batBuoc = false,
    this.apk = const {},
  });

  final String phienBan;
  final int build;
  final String link;
  final String? ghiChu;
  final bool batBuoc;

  /// Bản cài theo loại máy ('arm64' / 'arm32'); rỗng với phien-ban.json cũ.
  final Map<String, BanCai> apk;
}
