import 'package:flutter/material.dart';

import '../theme.dart';

/// Chọn lớp đang học (6–12). Dùng ở Đăng ký và Hồ sơ.
///
/// Dạng hàng nút bấm thay vì ô thả xuống: bảy lựa chọn nhìn thấy hết một lượt,
/// học sinh bấm một chạm là xong. Bấm lại lớp đang chọn là bỏ chọn — lớp là
/// thông tin KHÔNG bắt buộc.
class ChonLop extends StatelessWidget {
  const ChonLop({super.key, required this.lop, required this.onChanged});

  final int? lop;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var l = 6; l <= 12; l++)
          Semantics(
            button: true,
            selected: lop == l,
            label: 'Lớp $l',
            child: InkWell(
              key: ValueKey('chon-lop-$l'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(lop == l ? null : l),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lop == l ? AppColors.red : AppColors.bgAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: lop == l ? AppColors.red : AppColors.border,
                  ),
                ),
                child: Text(
                  '$l',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: lop == l ? AppColors.goldBright : AppColors.inkSoft,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
