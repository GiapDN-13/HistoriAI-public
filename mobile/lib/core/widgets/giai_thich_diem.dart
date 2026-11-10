import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/scholarly_rank.dart';

/// Bảng giải thích Điểm · Cấp · Danh hiệu · Chuỗi ngày, mở khi chạm vào các con số
/// ở trang chủ.
///
/// VÌ SAO (góp ý 17/10): "Phần hướng dẫn ban đầu hơi nhiều chữ, mình thường bấm bỏ
/// qua nên sau đó không hiểu XP và streak dùng để làm gì." Hướng dẫn đầu chỉ xem
/// một lần; giải thích phải nằm ngay cạnh con số, lúc nào cũng mở lại được.
///
/// Luật viết ở đây phải khớp máy chủ: +10 điểm cho câu đúng LẦN ĐẦU
/// (`routes/quiz.py`), cấp = ⌊√(điểm/100)⌋ + 1, chuỗi ngày tính theo giờ VN khi
/// nộp quiz / hỏi vĩ nhân / làm bài lớp học (`services/ngay_hoc.py`).
Future<void> showGiaiThichDiem(
  BuildContext context, {
  required int xp,
  required int streak,
  required bool daDangNhap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      maxChildSize: .94,
      minChildSize: .4,
      builder: (_, cuon) => GiaiThichDiem(
        xp: xp,
        streak: streak,
        daDangNhap: daDangNhap,
        cuon: cuon,
      ),
    ),
  );
}

class GiaiThichDiem extends StatelessWidget {
  const GiaiThichDiem({
    super.key,
    required this.xp,
    required this.streak,
    required this.daDangNhap,
    this.cuon,
  });

  final int xp;
  final int streak;
  final bool daDangNhap;
  final ScrollController? cuon;

  @override
  Widget build(BuildContext context) {
    final hang = ScholarlyRank.fromXp(xp);
    final cap = ScholarlyRank.capTuDiem(xp);
    return ListView(
      controller: cuon,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Điểm, cấp và chuỗi ngày',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          daDangNhap
              ? 'Bạn đang có $xp điểm · cấp $cap · chuỗi $streak ngày.'
              : 'Đăng nhập để điểm và chuỗi ngày được lưu vào tài khoản.',
          style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        const _Muc(
          icon: Icons.military_tech_outlined,
          mau: AppColors.gold,
          tieuDe: 'Điểm (XP)',
          noiDung: 'Mỗi câu quiz trả lời đúng lần đầu được +10 điểm. '
              'Làm lại câu đã đúng thì không cộng thêm, nên điểm cho biết bạn đã '
              'biết bao nhiêu câu chứ không phải đã bấm bao nhiêu lần.',
        ),
        const _Muc(
          icon: Icons.shield_outlined,
          mau: AppColors.red,
          tieuDe: 'Cấp độ',
          noiDung: 'Lên cấp theo điểm: cấp 2 ở 100 điểm, cấp 3 ở 400, cấp 4 ở 900. '
              'Lên cấp 2 là mở được trò chuyện với Quang Trung.',
        ),
        const _Muc(
          icon: Icons.local_fire_department_outlined,
          mau: AppColors.cta,
          tieuDe: 'Chuỗi ngày học',
          noiDung: 'Số ngày liên tiếp bạn có học: làm quiz, hỏi vĩ nhân hoặc làm '
              'bài trong lớp. Bỏ một ngày là chuỗi về 0 — mỗi ngày chỉ cần một '
              'câu là giữ được chuỗi.',
        ),
        const _Muc(
          icon: Icons.emoji_events_outlined,
          mau: AppColors.goldDark,
          tieuDe: 'Bảng vàng',
          noiDung: 'Xếp hạng mọi người theo tổng điểm.',
        ),
        const SizedBox(height: 6),
        const Text(
          'DANH HIỆU THEO ĐIỂM',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.red,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lấy tên các học vị khoa cử ngày xưa: thi đỗ càng cao, danh hiệu càng lớn.',
          style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 8),
        for (final h in ScholarlyRank.allRanks)
          _DongDanhHieu(hang: h, laHienTai: identical(h, hang)),
      ],
    );
  }
}

class _Muc extends StatelessWidget {
  const _Muc({
    required this.icon,
    required this.mau,
    required this.tieuDe,
    required this.noiDung,
  });

  final IconData icon;
  final Color mau;
  final String tieuDe;
  final String noiDung;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: mau.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: mau, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tieuDe,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.ink,
                    )),
                const SizedBox(height: 2),
                Text(noiDung,
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.inkSoft, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DongDanhHieu extends StatelessWidget {
  const _DongDanhHieu({required this.hang, required this.laHienTai});

  final ScholarlyRank hang;
  final bool laHienTai;

  @override
  Widget build(BuildContext context) {
    final khoang = hang.maxXp >= 999999
        ? 'từ ${hang.minXp} điểm'
        : '${hang.minXp}–${hang.maxXp} điểm';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: laHienTai ? AppColors.gold.withValues(alpha: .14) : AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: laHienTai ? AppColors.gold : AppColors.border,
          width: laHienTai ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          hang.huyHieu(co: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: hang.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontSize: 13.5,
                ),
                children: [
                  TextSpan(
                    text: ' — ${hang.nghia}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            laHienTai ? 'Bạn ở đây' : khoang,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: laHienTai ? AppColors.goldDark : AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
