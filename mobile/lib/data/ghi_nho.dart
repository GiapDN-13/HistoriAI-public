/// "Câu chốt để nhớ" cho từng trận — lấy nguyên văn từ tài liệu nhóm soạn
/// `Lộ-trình-học-giai-đoạn-Bạch-Đằng.docx` (lộ trình 938 → 981 → 1288, bám sách
/// giáo khoa). Hiện ở màn chi tiết sự kiện, mục "Ghi nhớ nhanh".
///
/// Góp ý phụ huynh 04/10: "Nếu app có nội dung bám sát chương trình học ở trường
/// thì tôi sẵn sàng cho con sử dụng lâu dài." Sự kiện chưa có câu chốt thì không hiện.
///
/// Từ 21/10 câu chốt lấy từ API `/lo-trinh` (backend/data/lo_trinh.json, nhập từ tài
/// liệu bằng tools/nhap_lo_trinh.py). Bảng này chỉ còn là DỰ PHÒNG khi API chưa có
/// (máy chủ cũ, mất mạng) — trận mới thêm vào tài liệu + chạy script nhập là đủ,
/// không cần thêm ở đây. Có sửa thì sửa ở tài liệu, giữ hai nơi khớp nhau.
const ghiNhoNhanh = <String, String>{
  'bach-dang-938':
      'Ngô Quyền dùng cọc ngầm và thủy triều, nhử quân Nam Hán vào Bạch Đằng rồi '
          'phản công khi nước rút, mở ra thời kì độc lập tự chủ.',
  'khang-chien-tong-981':
      'Trong hoàn cảnh cuối thời Đinh rối ren, Lê Hoàn lên ngôi, lãnh đạo quân dân '
          'đánh bại cuộc xâm lược của Tống năm 981 và giữ vững độc lập Đại Cồ Việt.',
  'bach-dang-1288':
      'Sau khi cắt đứt thuyền lương ở Vân Đồn, quân Trần nhử thủy quân Ô Mã Nhi vào '
          'bãi cọc Bạch Đằng lúc nước lên, phản công khi nước rút và giành thắng lợi '
          'quyết định.',
};

/// Trận đã có phim gốc, đang chờ nhóm design dựng (CLAUDE.md, 27/09). Màn chi tiết
/// hiện khung "Phim đang được dựng" thay vì im lặng — góp ý 04/10: "mới thấy có
/// video về trận Bạch Đằng thôi". Có phim rồi (`features` chứa `cinematic`) thì
/// khung tự ẩn; Bạch Đằng 1288 chưa có phim gốc nên không nằm ở đây.
const phimDangDung = {'quang-trung-1789', 'lam-son-1428', 'khang-chien-tong-981'};
