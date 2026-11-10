import 'package:flutter/material.dart';

import '../theme.dart';
import 'glb_viewer_stub.dart'
    if (dart.library.js_interop) 'glb_viewer_web.dart' as impl;

/// Hiển thị model 3D `.glb` thật.
///
/// Trên **web**: nhúng `viewer.html?model=<slug>` qua iframe (dùng Google
/// model-viewer từ CDN — đã kiểm chứng render ổn định, không bị ô trống như
/// `model_viewer_plus` nhúng trực tiếp).
///
/// Viewer và các tệp `.glb` nay nằm trên CHÍNH tên miền của sản phẩm
/// (`mobile/web/viewer.html` + `mobile/web/models/`). Trước đây chúng ở một
/// repo GitHub Pages khác, nghĩa là phần 3D phụ thuộc nơi nhóm không quản lý
/// cùng lúc với backend.
///
/// Trên **mobile** (chưa build tới): tạm hiển thị poster + thông báo. Khi làm
/// app mobile sẽ chuyển sang `model_viewer_plus`/AR thật.
/// Tay cầm để đổi đoạn cử động của model đang hiển thị.
///
/// Đổi bằng lệnh chứ không nạp lại trang: nạp lại là tải lại model gần 900 KB
/// và chớp trắng ngay giữa cuộc trò chuyện.
class GlbViewerController {
  void Function(String ten, bool motLan)? _goi;

  /// Gọi trước khi viewer kịp nạp xong thì lệnh rơi vào hư không — đó là ý
  /// muốn: viewer tự chạy `dung_tho` khi nạp xong.
  void cuDong(String ten, {bool motLan = false}) => _goi?.call(ten, motLan);

  /// Phần dựng viewer của từng nền tảng tự đăng ký vào đây, và gỡ ra bằng
  /// `noiVao(null)` khi bị huỷ.
  void noiVao(void Function(String ten, bool motLan)? f) => _goi = f;
}

class GlbViewer extends StatelessWidget {
  const GlbViewer({
    super.key,
    required this.slug,
    this.viewerBase = const String.fromEnvironment(
      'VIEWER_URL',
      defaultValue: 'https://historiai.org/viewer.html',
    ),
    this.poster,
    this.quayNgangDo = 0,
    this.tuXoay = true,
    this.cuDongDau,
    this.dieuKhien,
  });

  /// Slug nhân vật -> viewer.html?model=<slug> nạp models/<slug>.glb.
  final String slug;

  /// URL trang viewer.html đã deploy.
  final String viewerBase;

  /// Ảnh poster fallback (vd chân dung) khi không render được 3D.
  final ImageProvider? poster;

  /// Góc quay ngang ban đầu, tính bằng độ. Model nhân vật quay lưng về phía
  /// máy ảnh mặc định nên phải truyền 180.
  final double quayNgangDo;

  /// Có để model tự xoay vòng hay không. Tắt cho nhân vật đang trò chuyện.
  final bool tuXoay;

  /// Đoạn cử động chạy ngay khi nạp xong. Null thì viewer tự chọn `dung_tho`.
  final String? cuDongDau;

  /// Truyền vào để đổi đoạn cử động về sau.
  final GlbViewerController? dieuKhien;

  @override
  Widget build(BuildContext context) {
    return impl.buildGlbView(
      dieuKhien: dieuKhien,
      url: '$viewerBase?model=$slug'
          '${quayNgangDo == 0 ? '' : '&quay=${quayNgangDo.round()}'}'
          '${tuXoay ? '' : '&tuxoay=0'}'
          '${cuDongDau == null ? '' : '&anim=$cuDongDau'}',
      fallback: _fallback(),
    );
  }

  Widget _fallback() => Container(
        color: const Color(0xFFEFE7D8),
        alignment: Alignment.center,
        child: poster != null
            ? Image(image: poster!, fit: BoxFit.contain)
            : const Icon(Icons.threed_rotation,
                color: AppColors.gold, size: 64),
      );
}
