import 'package:flutter/material.dart';

/// Hệ thống Phẩm hàm Khoa Cử Đại Việt (EdTech Pedagogical Gamification)
class ScholarlyRank {
  final String title;
  final String stage;
  final String description;
  final String motto;
  final int minXp;
  final int maxXp;
  final IconData icon;
  final Color badgeColor;
  final String edictTitle;
  final String edictBody;

  /// Nghĩa dễ hiểu của danh hiệu — góp ý 04/10: từ "sử hoá" (đồng sinh, mưu lược…)
  /// làm học sinh thấy xa lạ. Hiện ngay dưới tên danh hiệu.
  final String nghia;

  const ScholarlyRank({
    required this.title,
    required this.stage,
    required this.description,
    required this.motto,
    required this.minXp,
    required this.maxXp,
    required this.icon,
    required this.badgeColor,
    required this.edictTitle,
    required this.edictBody,
    required this.nghia,
  });

  static const List<ScholarlyRank> allRanks = [
    ScholarlyRank(
      title: 'Đồng Sinh',
      stage: 'Nhập môn Thư phòng',
      description: 'Bước đầu tiên: làm vài trận quiz để tích điểm và lên danh hiệu.',
      motto: 'Ngọc bất trác bất thành khí, nhân bất học bất tri đạo.',
      minXp: 0,
      maxXp: 99,
      icon: Icons.menu_book_rounded,
      badgeColor: Color(0xFF8D6E63),
      edictTitle: 'CHIẾU CHỈ KHAI TÂM',
      edictBody: 'Phụng thiên thừa vận, Hoàng đế chiếu viết: Nay sĩ tử sơ tâm cầu học, ban cho danh hiệu Đồng Sinh, chuyên tâm bút nghiên tích lũy sử học!',
      nghia: 'Học trò mới vào học',
    ),
    ScholarlyRank(
      title: 'Sĩ Tử',
      stage: 'Kỳ thi Hương dự bị',
      description: 'Đã nắm được những trận đánh đầu tiên. Thử thêm trận mới để lên Tú Tài.',
      motto: 'Đầu đội nhật nguyệt, chân đạp sơn hà.',
      minXp: 100,
      maxXp: 299,
      icon: Icons.edit_note_rounded,
      badgeColor: Color(0xFF6D4C41),
      edictTitle: 'SẮC PHONG SĨ TỬ',
      edictBody: 'Sĩ tử đã tỏ lòng kiên định, thấu hiểu ngọn nguồn sử Việt. Nay đặc ân ban danh Sĩ Tử Thao Lược, chuẩn bị ứng thí trường Hương!',
      nghia: 'Người đang ôn để đi thi',
    ),
    ScholarlyRank(
      title: 'Tú Tài',
      stage: 'Khoa thi Hương đỗ đạt',
      description: 'Hiểu khá chắc nhiều trận đánh. Như người đỗ kỳ thi ở tỉnh ngày xưa.',
      motto: 'Văn chương cái thế, bút lực kinh thiên.',
      minXp: 300,
      maxXp: 599,
      icon: Icons.military_tech_rounded,
      badgeColor: Color(0xFF2E7D32),
      edictTitle: 'BẢNG VÀNG THI HƯƠNG',
      edictBody: 'Khảo thí tường tận, văn hay chữ tốt. Nay trẫm chuẩn y sắc phong Tú Tài đệ nhất xứ, ban áo xanh gấm lụa vinh quy bái tổ!',
      nghia: 'Đỗ kỳ thi ở tỉnh (thi Hương)',
    ),
    ScholarlyRank(
      title: 'Cử Nhân',
      stage: 'Thi Hương đỗ hạng cao',
      description: 'Kiến thức vững, đủ sức làm đề khó. Bước tiếp là danh hiệu Tiến Sĩ.',
      motto: 'Bình sinh dĩ thiên hạ vi kỷ nhiệm.',
      minXp: 600,
      maxXp: 999,
      icon: Icons.workspace_premium_rounded,
      badgeColor: Color(0xFF1565C0),
      edictTitle: 'SẮC BAN CỬ NHÂN',
      edictBody: 'Tài danh vang khắp xứ, đỗ cao khoa thi Hương. Sắc phong Cử Nhân, chuẩn bị lên kinh đô ứng thí kỳ thi Hội!',
      nghia: 'Đỗ cao ở kỳ thi Hương',
    ),
    ScholarlyRank(
      title: 'Tiến Sĩ',
      stage: 'Đại khoa Đệ Tam Giáp',
      description: 'Như các tiến sĩ được khắc tên trên bia đá Văn Miếu.',
      motto: 'Hiền tài là nguyên khí của quốc gia.',
      minXp: 1000,
      maxXp: 1999,
      icon: Icons.shield_rounded,
      badgeColor: Color(0xFFBA2323),
      edictTitle: 'BIA TIẾN SĨ ĐỀ DANH',
      edictBody: 'Hiền tài thịnh trị đất nước! Sĩ tử đã vượt qua kỳ thi Đình, đặc ân ban danh Tiến Sĩ Xuất Thân, đục bia đá đặt tại Quốc Tử Giám lưu danh muôn thuở!',
      nghia: 'Đỗ kỳ thi lớn ở kinh đô',
    ),
    ScholarlyRank(
      title: 'Bảng Nhãn / Thám Hoa',
      stage: 'Đại khoa Đệ Nhị Giáp',
      description: 'Thuộc nhóm giỏi nhất — như người đỗ nhì, đỗ ba cả nước ngày xưa.',
      motto: 'Kinh bang tế thế, dũng liệt phi thường.',
      minXp: 2000,
      maxXp: 3999,
      icon: Icons.auto_awesome_rounded,
      badgeColor: Color(0xFFD4AF37),
      edictTitle: 'HOÀNG CHIẾU NHỊ GIÁP',
      edictBody: 'Phụng chỉ Hoàng ân: Ban cờ biểu danh, ngựa hồng ban lộc. Phong hàm Bảng Nhãn Thám Hoa, đứng đầu hàng khanh tướng tham chính triều đình!',
      nghia: 'Đỗ nhì, đỗ ba cả nước',
    ),
    ScholarlyRank(
      title: 'Trạng Nguyên',
      stage: 'Đệ Nhất Giáp Đệ Nhất Danh',
      description: 'Danh hiệu cao nhất — như người đỗ đầu cả nước.',
      motto: 'Vạn đại sử xanh ghi tấc dạ, ngàn năm bia đá tạc ngàn thu.',
      minXp: 4000,
      maxXp: 999999,
      icon: Icons.stars_rounded,
      badgeColor: Color(0xFFFFB300),
      edictTitle: 'ĐẠI ẤN TRẠNG NGUYÊN',
      edictBody: 'Vạn tuế thánh minh! Đứng đầu Tam Khôi thiên hạ, phong Trạng Nguyên Thống Lĩnh Sử Học, ban mão vàng áo ngọc, cưỡi ngựa dạo phố vinh quy bái tổ!',
      nghia: 'Đỗ đầu cả nước',
    ),
  ];

  /// Ảnh huy hiệu (giao Codex vẽ — `docs/PROMPT_CODEX_PHAN_HOI_21-10.md`). Chưa có
  /// tệp thì nơi dùng hiện [icon] thay thế.
  String get anh {
    const ten = {
      'Đồng Sinh': 'dong_sinh',
      'Sĩ Tử': 'si_tu',
      'Tú Tài': 'tu_tai',
      'Cử Nhân': 'cu_nhan',
      'Tiến Sĩ': 'tien_si',
      'Bảng Nhãn / Thám Hoa': 'bang_nhan_tham_hoa',
      'Trạng Nguyên': 'trang_nguyen',
    };
    return 'assets/danh_hieu/${ten[title] ?? 'dong_sinh'}.png';
  }

  /// Huy hiệu dạng widget: ảnh nếu có, không thì biểu tượng [icon] màu [mau].
  Widget huyHieu({double co = 20, Color? mau}) => Image.asset(
        anh,
        width: co,
        height: co,
        errorBuilder: (_, __, ___) => Icon(icon, size: co, color: mau ?? badgeColor),
      );

  /// Cấp độ đúng công thức máy chủ (`routes/quiz.py::_calc_level`): ⌊√(điểm/100)⌋ + 1.
  static int capTuDiem(int xp) {
    var cap = 1;
    while (cap * cap * 100 <= xp) {
      cap++;
    }
    return cap;
  }

  static ScholarlyRank fromXp(int xp) {
    for (final rank in allRanks.reversed) {
      if (xp >= rank.minXp) {
        return rank;
      }
    }
    return allRanks.first;
  }

  double progressInCurrentRank(int xp) {
    if (xp >= maxXp) return 1.0;
    if (xp <= minXp) return 0.0;
    final range = maxXp - minXp;
    return (xp - minXp) / range;
  }

  int xpToNextRank(int xp) {
    if (xp >= maxXp) return 0;
    return maxXp + 1 - xp;
  }
}
