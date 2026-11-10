import 'package:flutter/material.dart';

/// Mô hình Thẻ Cẩm Nang Kế Sách Sử Việt
class HistoricalStrategem {
  final String id;
  final String title;
  final String author;
  final String period;
  final String corePrinciple;
  final String historyStory;
  final String modernLesson;
  final IconData icon;
  final String famousQuote;

  const HistoricalStrategem({
    required this.id,
    required this.title,
    required this.author,
    required this.period,
    required this.corePrinciple,
    required this.historyStory,
    required this.modernLesson,
    required this.icon,
    required this.famousQuote,
  });

  static const List<HistoricalStrategem> allStrategems = [
    HistoricalStrategem(
      id: 'bach_dang_coc_ngam',
      title: 'Cọc Ngầm Bạch Đằng',
      author: 'Ngô Quyền & Trần Hưng Đạo',
      period: 'Năm 938 & Năm 1288',
      corePrinciple: 'Mượn sức thiên nhiên tạo thế áp đảo bất ngờ',
      historyStory: 'Lợi dụng thủy triều lên xuống của sông Bạch Đằng, quân ta đóng cọc gỗ bịt sắt vót nhọn, nhử thuyền giặc vào bẫy khi nước lớn rồi tổng lực phản công khi nước rút, biến địa hình thành mồ chôn quân xâm lược.',
      modernLesson: 'Hiểu rõ môi trường và thời thế xung quanh mình. Khi nguồn lực ít hơn đối thủ, hãy tận dụng các yếu tố tự nhiên và quy luật thị trường để tạo lợi thế cạnh tranh độc nhất.',
      icon: Icons.water_rounded,
      famousQuote: 'Biết người biết ta, thuận theo con nước mà định giang sơn.',
    ),
    HistoricalStrategem(
      id: 'vuon_khong_nha_trong',
      title: 'Vườn Không Nhà Trống',
      author: 'Triều đình Nhà Trần',
      period: 'Ba lần kháng chiến chống Nguyên Mông',
      corePrinciple: 'Triệt tiêu nguồn tiếp tế, kéo dài thời gian để đối phương suy yếu',
      historyStory: 'Quân dân Thăng Long chủ động rút lui, cất giấu toàn bộ lương thảo thực phẩm. Quân Mông Cổ hung hãn chiếm được thành trống không có gì ăn, rơi vào cảnh đói khát, kiệt quệ tinh thần trước khi bị quân ta phản công tiêu diệt.',
      modernLesson: 'Kỹ năng quản lý tài nguyên và kiên nhẫn. Không đối đầu trực diện khi đối phương đang ở đỉnh cao phong độ; biết thu mình bảo toàn năng lượng để bung sức vào thời điểm quyết định.',
      icon: Icons.home_work_rounded,
      famousQuote: 'Nếu bệ hạ muốn hàng, trước hết hãy chém đầu thần đã!',
    ),
    HistoricalStrategem(
      id: 'tien_phat_che_nhan',
      title: 'Tiên Phát Chế Nhân',
      author: 'Thái úy Lý Thường Kiệt',
      period: 'Kháng chiến chống Tống (1075 - 1077)',
      corePrinciple: 'Ngồi yên đợi giặc không bằng đem quân đánh trước để bẻ gãy mũi nhọn',
      historyStory: 'Nắm được dã tâm và kho lương tập kết xâm lược của nhà Tống tại Ung Châu, Lý Thường Kiệt bất ngờ chủ động xuất kích đánh tan sào huyệt tiếp tế của địch rồi nhanh chóng rút về lập phòng tuyến sông Như Nguyệt.',
      modernLesson: 'Chủ động nắm bắt cơ hội thay vì bị động chờ khó khăn ập đến. Trong học tập, chuẩn bị bài vở kỹ lưỡng trước khi thi cử giúp bạn hoàn toàn làm chủ tình thế.',
      icon: Icons.bolt_rounded,
      famousQuote: 'Nam quốc sơn hà Nam đế cư, tiệt nhiên định phận tại thiên thư!',
    ),
    HistoricalStrategem(
      id: 'hanh_quan_than_toc',
      title: 'Hành Quân Thần Tốc',
      author: 'Hoàng đế Quang Trung',
      period: 'Đại phá 29 vạn quân Thanh (Xuân Kỷ Dậu 1789)',
      corePrinciple: 'Tốc độ quyết định chiến trường, đánh trúng thời khắc đối phương sơ hở nhất',
      historyStory: 'Vua Quang Trung hành quân từ Phú Xuân ra Thăng Long chỉ trong vòng chưa đầy một tháng, cho quân ăn Tết sớm rồi xuất kích đúng đêm giao thừa, đánh tan đồn Ngọc Hồi - Đống Đa làm Tôn Sĩ Nghị không kịp trở tay.',
      modernLesson: 'Kỷ luật hành động và sức mạnh của sự quyết đoán. Đã xác định mục tiêu thì phải tập trung toàn bộ năng lượng thực hiện thần tốc, không chần chừ do dự.',
      icon: Icons.speed_rounded,
      famousQuote: 'Đánh cho để dài tóc, đánh cho để đen răng, đánh cho nó chích luân bất phản!',
    ),
    HistoricalStrategem(
      id: 'vay_don_diet_vien',
      title: 'Vây Đồn Diệt Viện',
      author: 'Lê Lợi & Nguyễn Trãi',
      period: 'Khởi nghĩa Lam Sơn (1418 - 1427)',
      corePrinciple: 'Vây hãm thành trì kiên cố, tập trung tiêu diệt đạo quân cứu viện',
      historyStory: 'Tại chiến dịch Chi Lăng - Xương Giang, nghĩa quân Lam Sơn bao vây thành Đông Quan nhưng không công phá gấp mà dồn lực mai phục tiêu diệt 10 vạn quân viện binh của Liễu Thăng ở ải Chi Lăng, khiến giặc trong thành buộc phải đầu hàng.',
      modernLesson: 'Tập trung giải quyết gốc rễ của vấn đề thay vì tiêu tốn sức lực vào các chướng ngại bề nổi. Cắt đứt nguyên nhân cốt lõi thì khó khăn tự khắc tiêu tan.',
      icon: Icons.filter_center_focus_rounded,
      famousQuote: 'Tướng giặc ngã ngựa ở Chi Lăng, giang sơn thu về một cõi độc lập.',
    ),
    HistoricalStrategem(
      id: 'danh_chac_tien_chac',
      title: 'Đánh Chắc Tiến Chắc',
      author: 'Đại tướng Võ Nguyên Giáp',
      period: 'Chiến dịch Điện Biên Phủ (1954)',
      corePrinciple: 'Dũng cảm thay đổi phương châm khi thực tế chiến trường không cho phép mạo hiểm',
      historyStory: 'Sau nhiều đêm trăn trở, Đại tướng Võ Nguyên Giáp đưa ra quyết định khó khăn nhất trong cuộc đời chỉ huy: chuyển từ "Đánh nhanh thắng nhanh" sang "Đánh chắc tiến chắc", kéo pháo ra chuẩn bị chu đáo để nắm chắc 100% thắng lợi.',
      modernLesson: 'Tư duy linh hoạt và tinh thần trách nhiệm. Đừng bám chấp vào kế hoạch cũ nếu hoàn cảnh thay đổi; dũng cảm điều chỉnh phương pháp là chìa khóa của thành công bền vững.',
      icon: Icons.shield_rounded,
      famousQuote: 'Không nắm chắc phần thắng thì tuyệt đối không được đánh!',
    ),
  ];
}
