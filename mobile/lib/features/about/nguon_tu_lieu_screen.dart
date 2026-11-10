import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/widgets/vietnamese_decorations.dart';

/// Màn "Nguồn tư liệu" — ghi công tác giả và giấy phép.
///
/// VÌ SAO BẮT BUỘC PHẢI CÓ
///     Hoạ tiết trống đồng, chim Lạc và chín mô hình 3D đều dùng giấy phép
///     Creative Commons **Ghi công** (CC BY / CC BY-SA). Điều kiện của giấy
///     phép là ghi công ở nơi NGƯỜI DÙNG THẤY ĐƯỢC. Để phần ghi công nằm
///     trong `assets/brand/CREDITS.md` — một tệp trong mã nguồn — là không
///     đáp ứng điều kiện đó, dù thiện chí có đủ.
///
///     CC BY-SA còn buộc bản sửa đổi mang cùng giấy phép. Hai hoạ tiết dưới
///     đây đã bị sửa (đổi màu, làm dày nét, cắt lại) nên phần "đã sửa gì"
///     không phải cho đẹp, nó là nghĩa vụ.
class NguonTuLieuScreen extends StatelessWidget {
  const NguonTuLieuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.goldBright,
        centerTitle: true,
        title: const Text(
          'NGUỒN TƯ LIỆU',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: DongSonBackground(
        size: 320,
        opacity: 0.03,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
          children: [
            const _Loi(
              'Sản phẩm này dựng trên công sức của nhiều người khác. Dưới đây '
              'là nguồn và giấy phép của từng phần — ghi ra không phải cho '
              'lịch sự, mà vì giấy phép buộc phải ghi.',
            ),
            const SizedBox(height: 20),
            ..._muc.map((m) => _TheNguon(m)),
            const SizedBox(height: 8),
            const _Loi(
              'Nội dung lịch sử biên soạn dựa trên hồ sơ Bảo vật quốc gia và '
              'tư liệu của Bảo tàng Lịch sử Quốc gia. Phần trò chuyện do mô '
              'hình ngôn ngữ sinh ra và có thể sai — hãy đối chiếu sách giáo '
              'khoa khi dùng cho bài tập.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Nguon {
  const _Nguon(this.ten, this.tacGia, this.giayPhep, this.lienKet, this.suaGi);

  final String ten;
  final String tacGia;
  final String giayPhep;
  final String lienKet;
  final String? suaGi;
}

const _muc = <_Nguon>[
  _Nguon(
    'Hoạ tiết mặt trống đồng Ngọc Lũ',
    'Ebaychatter0 · Wikimedia Commons',
    'CC BY-SA 3.0',
    'https://commons.wikimedia.org/wiki/File:Trong_Dong_Ngoc_Lu.svg',
    'Kết xuất sang PNG, cắt viền, bỏ màu gốc chỉ giữ kênh alpha để app tự '
        'tô màu theo bộ nhận diện.',
  ),
  _Nguon(
    'Hoạ tiết chim Lạc',
    'Ebaychatter0 · Wikimedia Commons',
    'CC BY-SA 3.0',
    'https://commons.wikimedia.org/wiki/File:Trong_Dong_Ngoc_Lu.svg',
    'Trích một con chim ở vành ngoài mặt trống, làm dày nét để không vỡ khi '
        'thu nhỏ, bỏ màu gốc.',
  ),
  _Nguon(
    'Chín mô hình 3D cổ vật',
    'Nhiều tác giả trên Sketchfab',
    'CC BY 4.0',
    'https://sketchfab.com',
    'Nén hình học và kết cấu để tải nhanh trên mạng di động; chuẩn hoá tỉ lệ '
        'về mét để đặt đúng kích thước thật.',
  ),
  _Nguon(
    'Mô hình nhân vật lịch sử',
    'Dựng bằng Tripo3D, đội HistoJourney tinh chỉnh',
    'Tự dựng',
    '',
    'Nạp thêm các đoạn cử động soạn riêng cho sản phẩm.',
  ),
  _Nguon(
    'Bộ hiển thị mô hình 3D',
    'Google · <model-viewer>',
    'Apache 2.0',
    'https://modelviewer.dev',
    null,
  ),
];

class _Loi extends StatelessWidget {
  const _Loi(this.chu);
  final String chu;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: const BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          border: Border(left: BorderSide(color: AppColors.gold, width: 4)),
        ),
        child: Text(
          chu,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Color(0xFF5C4033),
            fontSize: 13.5,
            height: 1.55,
          ),
        ),
      );
}

class _TheNguon extends StatelessWidget {
  const _TheNguon(this.n);
  final _Nguon n;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n.ten,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            n.tacGia,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.inkSoft,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  n.giayPhep,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (n.lienKet.isNotEmpty) ...[
                const Spacer(),
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(n.lienKet),
                      mode: LaunchMode.externalApplication),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                  ),
                  child: const Text(
                    'Xem nguồn',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.cta,
                        fontSize: 12.5),
                  ),
                ),
              ],
            ],
          ),
          if (n.suaGi != null) ...[
            const SizedBox(height: 6),
            Text(
              'Đã sửa đổi: ${n.suaGi}',
              style: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.inkSoft,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
