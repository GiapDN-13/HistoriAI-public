import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anh_dai_dien.dart';
import '../../core/ban_moi.dart';
import '../../core/api_client.dart';
import '../../core/app_preferences.dart';
import '../../core/theme.dart';
import '../../core/widgets/chon_lop.dart';
import '../about/nguon_tu_lieu_screen.dart';
import '../auth/auth_service.dart';
import '../chat/lich_su_chat.dart';
import '../auth/login_screen.dart';
import '../onboarding/huong_dan_screen.dart';
import '../phan_hoi/hoi_phan_hoi.dart';
import '../premium/premium_chung.dart';
import '../premium/premium_screen.dart';
import 'ban_tin_phu_huynh.dart';
import 'doi_mat_khau.dart';
import '../lop_hoc/giao_vien_screen.dart';
import '../lop_hoc/lop_hoc_api.dart';
import '../lop_hoc/mo_rong/giu_tai_khoan.dart';
import '../lop_hoc/vao_phong_screen.dart';
import 'lich_su_hoc_screen.dart';
import 'sua_ho_so_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    required this.authService,
  });

  final AuthService authService;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _thongKe;
  TinhTrangPremium get _premium => TinhTrangPremium.tuMe(_profile);
  String? _phienBan;
  bool _loading = true;
  bool _guest = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _phienBan = '${i.version} (${i.buildNumber})');
    }).catchError((_) {});
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await widget.authService.storedToken;
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _guest = true;
        _profile = null;
        _loading = false;
      });
      return;
    }

    try {
      final profile = await widget.authService.fetchMe();
      if (!mounted) return;
      setState(() {
        _guest = false;
        _profile = profile;
        _loading = false;
      });
      try {
        final tk = await ApiClient().get('/me/thong-ke') as Map;
        if (mounted) setState(() => _thongKe = tk.cast<String, dynamic>());
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guest = false;
        _error = 'Chưa thể tải hồ sơ. Kiểm tra kết nối rồi thử lại.';
        _loading = false;
      });
    }
  }

  /// Mở màn Premium rồi nạp lại hồ sơ: người dùng có thể vừa thanh toán xong.
  Future<void> _moPremium() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => PremiumScreen(authService: widget.authService)),
    );
    if (mounted && !_guest) _loadProfile();
  }

  void _openLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(authService: widget.authService),
      ),
    );
  }

  /// Lịch sử chat chỉ nằm trên máy (không lên máy chủ) — xoá ở đây là mất hẳn.
  Future<void> _xoaLichSuChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá lịch sử trò chuyện?'),
        content: const Text('Mọi cuộc trò chuyện với các vĩ nhân trên máy này sẽ bị xoá '
            'và không khôi phục được. Điểm quiz và tiến độ học không bị ảnh hưởng.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xoá hết')),
        ],
      ),
    );
    if (ok != true) return;
    final so = await LichSuChat.xoaHet();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(so == 0
            ? 'Chưa có cuộc trò chuyện nào để xoá.'
            : 'Đã xoá $so cuộc trò chuyện.')));
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có thể đăng nhập lại bất cứ lúc nào.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !mounted) return;

    await widget.authService.logout();
    if (!mounted) return;
    _openLogin();
  }

  /// Thu hồi mọi phiên của tài khoản — dùng khi lỡ đăng nhập ở máy mượn,
  /// máy phòng tin học của trường.
  Future<void> _signOutEverywhere() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Đăng xuất khỏi mọi thiết bị?'),
        content: const Text(
          'Mọi máy đang đăng nhập tài khoản này (kể cả máy này) sẽ phải đăng nhập lại. '
          'Dùng khi bạn lỡ đăng nhập ở máy mượn hoặc máy ở trường.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất hết'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.authService.logout(moiNoi: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Chưa đăng xuất được các máy khác. Kiểm tra mạng rồi thử lại.'),
      ));
      return;
    }
    if (!mounted) return;
    _openLogin();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Xóa tài khoản?'),
        content: const Text(
          'Tài khoản và toàn bộ tiến độ học sẽ bị xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.authService.xoaTaiKhoan();
      if (!mounted) return;
      _openLogin();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chưa thể xóa tài khoản. Vui lòng thử lại.')),
      );
    }
  }

  Future<void> _suaHoSo() async {
    final daLuu = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => SuaHoSoScreen(
        authService: widget.authService,
        hoTen: _profile?['full_name'] as String? ?? '',
        anh: _profile?['avatar'] as String?,
      ),
    ));
    // Nạp lại cả khi không bấm Lưu: ảnh tự tải lên đã lưu ngay lúc tải.
    if (daLuu == true || mounted) _loadProfile();
  }

  bool get _coQuyenGiaoVien =>
      _profile?['role'] == 'teacher' || _profile?['role'] == 'admin';

  /// Giáo viên → trang quản lý lớp. Chưa là giáo viên → hỏi mã nhóm phát.
  Future<void> _moLopHoc() async {
    if (_coQuyenGiaoVien) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GiaoVienScreen()));
      return;
    }
    final ctl = TextEditingController();
    final ma = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Dành cho giáo viên'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nhập mã giáo viên nhóm HistoriAI đã gửi thầy cô để mở chức năng ra đề, '
              'mở phòng kiểm tra và xem kết quả của lớp.'),
          const SizedBox(height: 12),
          TextField(controller: ctl, autofocus: true, decoration: const InputDecoration(labelText: 'Mã giáo viên')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Xác nhận')),
        ],
      ),
    );
    ctl.dispose();
    if (ma == null || ma.isEmpty || !mounted) return;
    try {
      await LopHocApi().lamGiaoVien(ma);
      if (!mounted) return;
      await _loadProfile();
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GiaoVienScreen()));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _doiMatKhau() async {
    // Tài khoản nhanh có email tổng hợp — đặt mật khẩu cho nó vô ích, phải thêm email thật.
    if (laTaiKhoanNhanh(_profile?['email'] as String?)) return _giuTaiKhoan();
    final coMatKhau = _profile?['co_mat_khau'] != false;
    final ok = await hoiDoiMatKhau(context, widget.authService, coMatKhau: coMatKhau);
    if (ok != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(coMatKhau
          ? 'Đã đổi mật khẩu. Các máy khác đã được đăng xuất.'
          : 'Đã đặt mật khẩu. Giờ bạn đăng nhập được bằng email + mật khẩu.'),
    ));
    _loadProfile();
  }

  /// Tài khoản nhanh (vào phòng kiểm tra bằng tên + PIN) → thêm email thật + mật khẩu.
  Future<void> _giuTaiKhoan() async {
    final ok = await hoiGiuTaiKhoan(context, widget.authService);
    if (ok != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Đã giữ tài khoản. Từ giờ đăng nhập bằng email và mật khẩu vừa đặt.'),
    ));
    _loadProfile();
  }

  void _openGuide() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HuongDanScreen(
          khiXong: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['full_name'] as String? ?? 'Người học HistoriAI';
    final email = _profile?['email'] as String?;
    final level = (_profile?['level'] as num?)?.toInt() ?? 1;
    final xp = (_profile?['xp'] as num?)?.toInt() ?? 0;
    final streak = (_profile?['streak'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        centerTitle: true,
        title: const Text(
          'TÀI KHOẢN',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadProfile,
            color: AppColors.red,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 44),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.red),
                    ),
                  )
                else if (_error != null)
                  _ProfileLoadError(message: _error!, onRetry: _loadProfile)
                else if (_guest)
                  _GuestProfileCard(onLogin: _openLogin)
                else
                  _SignedInProfileCard(
                    name: name,
                    email: email,
                    level: level,
                    xp: xp,
                    streak: streak,
                    anh: _profile?['avatar'] as String?,
                    lienKetGoogle: _profile?['lien_ket_google'] == true,
                    ngayThamGia: _profile?['ngay_tham_gia'] as String?,
                    thongKe: _thongKe,
                    onSua: _suaHoSo,
                    premium: _premium,
                  ),
                if (!_loading && !_guest && _error == null && _premium.canNhacGiaHan()) ...[
                  const SizedBox(height: 14),
                  _NhacGiaHan(ngayConLai: _premium.ngayConLai(), onTap: _moPremium),
                ],
                if (!_loading && !_guest && _error == null && laTaiKhoanNhanh(email)) ...[
                  const SizedBox(height: 14),
                  LoiMoiGiuTaiKhoan(onTap: _giuTaiKhoan),
                ],
                // Bản tin tuần cho phụ huynh — cần tài khoản vì số liệu lấy từ bài đã lưu.
                if (!_loading && !_guest && _error == null) ...[
                  const SizedBox(height: 14),
                  const TheBanTinPhuHuynh(),
                ],
                const SizedBox(height: 22),
                Text('LỚP HỌC', style: _sectionHeading),
                const SizedBox(height: 10),
                _SettingsCard(
                  child: Column(children: [
                    _SettingsLink(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Vào phòng kiểm tra (mã thầy cô đưa)',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => VaoPhongScreen(authService: widget.authService))),
                    ),
                    if (!_loading && !_guest && _error == null) ...[
                      const _SettingsDivider(),
                      _SettingsLink(
                        icon: Icons.co_present_rounded,
                        title: _profile?['role'] == 'admin'
                            ? 'Quản lý lớp học (quản trị)'
                            : _coQuyenGiaoVien
                                ? 'Quản lý lớp học (giáo viên)'
                                : 'Tôi là giáo viên',
                        onTap: _moLopHoc,
                      ),
                    ],
                  ]),
                ),
                if (!_loading && !_guest && _error == null) ...[
                  const SizedBox(height: 22),
                  Text('TÀI KHOẢN', style: _sectionHeading),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    child: Column(
                      children: [
                        _SettingsLink(
                          icon: Icons.history_edu_rounded,
                          title: 'Lịch sử học & ôn câu sai',
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const LichSuHocScreen())),
                        ),
                        const _SettingsDivider(),
                        _SettingsLink(
                          icon: Icons.edit_rounded,
                          title: 'Sửa họ tên, ảnh đại diện',
                          onTap: _suaHoSo,
                        ),
                        const _SettingsDivider(),
                        _SettingsLink(
                          icon: Icons.password_rounded,
                          title: _profile?['co_mat_khau'] == false
                              ? 'Đặt mật khẩu'
                              : 'Đổi mật khẩu',
                          onTap: _doiMatKhau,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('LỚP ĐANG HỌC', style: _sectionHeading),
                const SizedBox(height: 10),
                _SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: ValueListenableBuilder<int?>(
                      valueListenable: AppPreferences.lopHoc,
                      builder: (context, lop, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lop == null
                                ? 'Chưa chọn — tóm tắt hiện bản chung'
                                : (lop >= 10
                                    ? 'Lớp $lop — tóm tắt bản THPT'
                                    : 'Lớp $lop — tóm tắt bản THCS'),
                            style: const TextStyle(
                                color: AppColors.inkSoft, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          ChonLop(
                            lop: lop,
                            onChanged: widget.authService.capNhatLop,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('TÙY CHỈNH ỨNG DỤNG', style: _sectionHeading),
                const SizedBox(height: 10),
                _SettingsCard(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: AppPreferences.emberEffectsEnabled,
                    builder: (context, enabled, _) => SwitchListTile.adaptive(
                      value: enabled,
                      onChanged: AppPreferences.setEmberEffectsEnabled,
                      secondary: const _SettingsIcon(
                        icon: Icons.auto_awesome_rounded,
                        color: AppColors.goldDark,
                      ),
                      title: const Text(
                        'Hiệu ứng nền',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text('Đốm sáng ở trang chủ — tắt nếu máy chạy chậm'),
                      activeTrackColor: AppColors.red,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsCard(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: AppPreferences.tuDoc,
                    builder: (context, bat, _) => SwitchListTile.adaptive(
                      value: bat,
                      onChanged: AppPreferences.setTuDoc,
                      secondary: const _SettingsIcon(
                        icon: Icons.record_voice_over_rounded,
                        color: AppColors.red,
                      ),
                      title: const Text(
                        'Vĩ nhân tự đọc câu trả lời',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text('Tắt nếu đang ở lớp hay nơi cần yên lặng'),
                      activeTrackColor: AppColors.red,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('HỖ TRỢ & THÔNG TIN', style: _sectionHeading),
                const SizedBox(height: 10),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsLink(
                        icon: Icons.menu_book_rounded,
                        title: 'Hướng dẫn sử dụng',
                        onTap: _openGuide,
                      ),
                      const _SettingsDivider(),
                      _SettingsLink(
                        icon: Icons.workspace_premium_rounded,
                        title: 'HistoriAI Premium',
                        onTap: _moPremium,
                      ),
                      const _SettingsDivider(),
                      _SettingsLink(
                        icon: Icons.rate_review_outlined,
                        title: 'Góp ý cho nhóm',
                        onTap: () => hoiPhanHoi(context, nguCanh: 'ho-so', tuDong: false),
                      ),
                      const _SettingsDivider(),
                      _SettingsLink(
                        icon: Icons.menu_book_outlined,
                        title: 'Nguồn tư liệu & bản quyền',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NguonTuLieuScreen(),
                          ),
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsLink(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Quyền riêng tư',
                        onTap: () => launchUrl(
                          Uri.parse('https://historiai.org/rieng-tu/'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsLink(
                        icon: Icons.delete_sweep_outlined,
                        title: 'Xoá lịch sử trò chuyện',
                        onTap: _xoaLichSuChat,
                      ),
                      const _SettingsDivider(),
                      // Web: mời cài bản Android. Bản cài: tự kiểm có bản mới chưa (app chỉ
                      // tự hỏi lúc mở — người dùng cần một nút để chủ động kiểm).
                      if (kIsWeb)
                        _SettingsLink(
                          icon: Icons.android_rounded,
                          title: 'Tải app Android',
                          onTap: () => launchUrl(BanMoi.trangTai,
                              mode: LaunchMode.externalApplication),
                        )
                      else
                        _SettingsLink(
                          icon: Icons.system_update_rounded,
                          title: _phienBan == null
                              ? 'Kiểm tra bản mới'
                              : 'Kiểm tra bản mới (đang dùng ${_phienBan!.split(' ').first})',
                          onTap: () => BanMoi.kiemThuCong(context),
                        ),
                    ],
                  ),
                ),
                if (_phienBan != null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Text('HistoriAI phiên bản $_phienBan',
                        style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                  ),
                ],
                if (!_loading && !_guest) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Đăng xuất'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _signOutEverywhere,
                    icon: const Icon(Icons.devices_other_rounded),
                    label: const Text('Đăng xuất khỏi mọi thiết bị'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkSoft,
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Xóa tài khoản và tiến độ học'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _sectionHeading = TextStyle(
  color: AppColors.inkSoft,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: .7,
);

class _GuestProfileCard extends StatelessWidget {
  const _GuestProfileCard({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: imperialDarkGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: .75)),
          boxShadow: appSoftShadow,
        ),
        child: Column(
          children: [
            Image.asset(
              'assets/icons/nav/07_profile_scholar.png',
              width: 76,
              height: 76,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 12),
            const Text(
              'Hồ sơ người học',
              style: TextStyle(
                color: AppColors.onRed,
                fontFamily: 'PlayfairDisplay',
                fontWeight: FontWeight.w700,
                fontSize: 21,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Đăng nhập để lưu tiến độ và quản lý tài khoản trên mọi thiết bị.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onRed, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onLogin,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.goldBright,
                foregroundColor: AppColors.redDeepest,
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      );
}

class _SignedInProfileCard extends StatelessWidget {
  const _SignedInProfileCard({
    required this.name,
    required this.email,
    required this.level,
    required this.xp,
    required this.streak,
    this.anh,
    this.lienKetGoogle = false,
    this.ngayThamGia,
    this.thongKe,
    this.onSua,
    this.premium = TinhTrangPremium.khong,
  });

  final TinhTrangPremium premium;
  final String name;
  final String? email;
  final int level;
  final int xp;
  final int streak;
  final String? anh;
  final bool lienKetGoogle;
  final String? ngayThamGia;
  final Map<String, dynamic>? thongKe;
  final VoidCallback? onSua;

  static String? _ngay(String? iso) {
    final t = DateTime.tryParse(iso ?? '');
    if (t == null) return null;
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: imperialDarkGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: .75)),
          boxShadow: appSoftShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                AnhDaiDien.vong(anh, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.onRed,
                          fontFamily: 'PlayfairDisplay',
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                        ),
                      ),
                      if (email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onRed,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (lienKetGoogle) 'Đăng nhập bằng Google',
                          if (_ngay(ngayThamGia) != null) 'Tham gia ${_ngay(ngayThamGia)}',
                        ].join(' · '),
                        style: TextStyle(
                          color: AppColors.onRed.withValues(alpha: .8),
                          fontSize: 11.5,
                        ),
                      ),
                      if (premium.la) ...[
                        const SizedBox(height: 8),
                        _HuyHieuPremium(den: premium.den),
                      ],
                    ],
                  ),
                ),
                if (onSua != null)
                  IconButton(
                    tooltip: 'Sửa hồ sơ',
                    onPressed: onSua,
                    icon: const Icon(Icons.edit_rounded, color: AppColors.goldBright),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ProfileStat(
                    icon: Icons.military_tech_rounded,
                    label: 'Cấp độ',
                    value: '$level',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProfileStat(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Chuỗi ngày',
                    value: '$streak ngày',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProfileStat(
                    icon: Icons.stars_rounded,
                    label: 'Điểm tích lũy',
                    value: '$xp XP',
                  ),
                ),
              ],
            ),
            if (thongKe != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ProfileStat(
                      icon: Icons.fact_check_rounded,
                      label: 'Câu đã làm',
                      value: '${thongKe!['tong_cau'] ?? 0}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProfileStat(
                      icon: Icons.percent_rounded,
                      label: 'Tỉ lệ đúng',
                      value: '${thongKe!['ti_le_dung'] ?? 0}%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ProfileStat(
                      icon: Icons.leaderboard_rounded,
                      label: 'Hạng',
                      value: '${thongKe!['hang'] ?? '—'}',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.redDeepest.withValues(alpha: .38),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.goldBright, size: 19),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.onRed, fontSize: 10)),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.goldBright,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.inkMuted, size: 30),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: appSoftShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
      );
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 21),
      );
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        minTileHeight: 56,
        leading: _SettingsIcon(icon: icon, color: AppColors.red),
        title: Text(title,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            )),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
      );
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        indent: 68,
        endIndent: 14,
        color: AppColors.divider,
      );
}


/// Huy hiệu "Premium" kèm ngày hết hạn, đặt trong thẻ hồ sơ.
class _HuyHieuPremium extends StatelessWidget {
  const _HuyHieuPremium({this.den});
  final DateTime? den;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.goldBright,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded,
                size: 15, color: AppColors.redDeepest),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                den == null ? 'Premium' : 'Premium đến ${dinhDangNgay(den!)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  color: AppColors.redDeepest,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

/// 3 ngày cuối của Premium: nhắc gia hạn. Không tự gia hạn nên phải nhắc —
/// im lặng thì tới lúc hết người học mới biết vì bị chặn lượt hỏi.
class _NhacGiaHan extends StatelessWidget {
  const _NhacGiaHan({required this.ngayConLai, required this.onTap});
  final int ngayConLai;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    color: AppColors.goldDark, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Premium còn $ngayConLai ngày',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text(
                  'Gia hạn',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
