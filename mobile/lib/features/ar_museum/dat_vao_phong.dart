import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models.dart';

/// "Đặt vào phòng" — mở camera điện thoại và dựng cổ vật ra giữa phòng đúng
/// kích thước thật ngoài đời.
///
/// ĐI QUA SCENE VIEWER, KHÔNG NHÚNG ARCORE
/// ---------------------------------------
/// Scene Viewer là app của Google, hầu hết máy Android đã có sẵn theo Google
/// Play Services for AR. Gọi nó mất một dòng URL; nhúng ARCore vào app mất cả
/// tuần và phải phụ thuộc một gói Flutter cũ. Đổi lại, app **không phải xin
/// quyền camera** — camera do Scene Viewer dùng, không phải HistoriAI.
///
/// `resizable=false` CHÍNH LÀ THỨ LÀM NÊN "KÍCH THƯỚC THẬT"
/// --------------------------------------------------------
/// Mặc định Scene Viewer cho người dùng chụm hai ngón phóng to thu nhỏ model,
/// thành ra "AR" chỉ còn là một món đồ chơi. Khoá lại thì cổ vật đứng đúng cỡ
/// ngoài đời, và người học đo được nó bằng chính thân mình.
///
/// Nhưng khoá kích thước chỉ đúng khi **tệp .glb đã được chuẩn hoá về mét**
/// (xem `tool/chuan_hoa_ti_le.py`) và **`real_scale_meters` đã tra được nguồn
/// thật**. Thiếu một trong hai thì nút này phải biến mất — đó là lý do có
/// [dungDuoc].
///
/// PHẢI LÀ NÚT FLUTTER THUẦN
/// -------------------------
/// Không đặt nút này bên trong `viewer.html`: WebView chặn điều hướng sang
/// lược đồ `intent://` mà Scene Viewer dùng, bấm vào sẽ không có gì xảy ra.
class DatVaoPhong {
  DatVaoPhong._();

  static const _sceneViewer = 'https://arvr.google.com/scene-viewer/1.0';

  /// Cách app thật sự dò và mở một đường dẫn ra ngoài.
  ///
  /// Để thay được (xem [gan]) vì `url_launcher` cần một máy thật hoặc một
  /// binding kênh nền tảng mới trả lời — không tách ra thì bài test không
  /// kiểm chứng được luật ẩn/hiện nút, mà luật ấy mới là phần dễ sai.
  static Future<bool> Function(Uri) _kiemTra = canLaunchUrl;

  /// `LaunchMode.externalApplication` là bắt buộc. Chế độ mặc định có thể mở
  /// đường dẫn trong WebView nội bộ, mà WebView thì không nhảy sang Scene
  /// Viewer được — đúng cái bẫy khiến nút AR phải là nút Flutter thuần.
  static Future<bool> Function(Uri) _mo =
      (u) => launchUrl(u, mode: LaunchMode.externalApplication);

  /// Thay hai hàm trên. Chỉ dùng trong test.
  @visibleForTesting
  static void gan({
    Future<bool> Function(Uri)? kiemTra,
    Future<bool> Function(Uri)? mo,
  }) {
    if (kiemTra != null) _kiemTra = kiemTra;
    if (mo != null) _mo = mo;
  }

  @visibleForTesting
  static void datLaiChoTest() {
    _kiemTra = canLaunchUrl;
    _mo = (u) => launchUrl(u, mode: LaunchMode.externalApplication);
  }

  /// Nền tảng có cửa nào dẫn tới Scene Viewer hay không.
  ///
  /// - **Web**: không. Trình duyệt không tự chạy AR, và link HistoriAI ở Việt
  ///   Nam phần lớn được mở trong trình duyệt nhúng của Zalo/Facebook — chỗ
  ///   hỏng đầu tiên.
  /// - **iOS**: không. Quick Look cần tệp `.usdz`, mà nhóm chưa dựng được
  ///   (công cụ chuyển đổi của Apple chỉ chạy trên máy Mac).
  static bool get hoTroNenTang =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Quá cỡ này thì không đặt vừa một căn phòng, nên không hiện nút.
  ///
  /// Trần nhà thường cao 2,7–3 m. Thuyền chiến Đông Sơn dài 9,5 m: người dùng
  /// chỉ thấy một mảng gỗ khổng lồ xuyên qua tường, không học được gì về kích
  /// thước. Riêng model thuyền còn dựng theo lối cách điệu của hình khắc trống
  /// đồng nên cao tới 6,5 m, trong khi thuyền thật ước chừng 3 m — khoá
  /// `resizable=false` cho nó là dạy sai luôn chiều cao.
  ///
  /// Cọc Bạch Đằng 2,7 m vẫn lọt: cao hơn đầu người chính là điều đáng thấy.
  static const double gioiHanTrongPhongMet = 4.0;

  /// Đường dẫn Scene Viewer cho một cổ vật, hoặc `null` nếu chưa đủ điều kiện
  /// để hứa "kích thước thật".
  ///
  /// Ba điều kiện, thiếu một là `null`:
  /// 1. có tệp `.glb`;
  /// 2. đường dẫn tệp là HTTPS tuyệt đối — Scene Viewer tải tệp bằng chính
  ///    tiến trình của nó, đường dẫn tương đối hay `localhost` của máy phát
  ///    triển đều vô nghĩa với nó;
  /// 3. đã tra được `real_scale_meters` từ nguồn thật;
  /// 4. hiện vật đủ nhỏ để đặt vừa một căn phòng.
  static Uri? diaChi(Artifact a) {
    final tep = a.modelGlbUrl ?? '';
    if (tep.isEmpty || !tep.startsWith('https://')) return null;
    if (!a.coKichThuocThat) return null;
    if ((a.realScaleMeters ?? 0) > gioiHanTrongPhongMet) return null;

    return Uri.parse(_sceneViewer).replace(queryParameters: {
      'file': tep,
      // `ar_preferred`: vào thẳng chế độ AR, máy nào không chạy được thì tự
      // rơi về khung xem 3D thường thay vì báo lỗi.
      'mode': 'ar_preferred',
      'resizable': 'false',
      'title': a.name,
    });
  }

  /// Có nên hiện nút "Đặt vào phòng" cho cổ vật này không.
  ///
  /// Hỏi thật máy xem có app nào nhận được đường dẫn không, chứ không đoán
  /// theo phiên bản Android. Lưu ý: từ Android 11, muốn hỏi được câu này thì
  /// `AndroidManifest.xml` phải khai khối `<queries>` cho
  /// `https://arvr.google.com` — thiếu nó thì câu trả lời luôn là "không" và
  /// nút biến mất trên mọi máy. (Khối đó đã được khai sẵn cùng lúc dựng nền
  /// tảng Android; nếu một ngày nút mất sạch trên mọi máy thì soi lại chỗ ấy
  /// trước tiên.)
  static Future<bool> dungDuoc(Artifact a) async {
    if (!hoTroNenTang) return false;
    final u = diaChi(a);
    if (u == null) return false;
    try {
      return await _kiemTra(u);
    } catch (_) {
      // Dò hỏng thì coi như không có. Không để một ngoại lệ của plugin làm
      // sập phiếu chi tiết cổ vật.
      return false;
    }
  }

  /// Mở Scene Viewer. Trả `false` nếu không mở được, để màn hình còn báo lại
  /// cho người dùng.
  static Future<bool> mo(Artifact a) async {
    final u = diaChi(a);
    if (u == null) return false;
    try {
      return await _mo(u);
    } catch (_) {
      return false;
    }
  }

  /// Câu mô tả kích thước để in dưới nút, ví dụ "cao 0,6 m ngoài đời".
  /// Dùng dấu phẩy thập phân theo cách viết tiếng Việt.
  static String? moTaKichThuoc(Artifact a) {
    final m = a.realScaleMeters;
    if (m == null || m <= 0) return null;
    if (m < 1) return '${(m * 100).round()} cm ngoài đời';
    final s = m.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
    return '${s.replaceAll(RegExp(r'\.$'), '').replaceAll('.', ',')} m ngoài đời';
  }
}
