import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/data/models.dart';

void main() {
  test('HistoricalEvent nhận tiến độ học tùy chọn từ API tương lai', () {
    final event = HistoricalEvent.fromJson({
      'slug': 'bach-dang-938',
      'title': 'Trận Bạch Đằng 938',
      'year': 938,
      'learning_progress': 0.6,
    });

    expect(event.learningProgress, 0.6);
  });

  test('HistoricalEvent mặc định chưa có tiến độ khi API chưa hỗ trợ', () {
    final event = HistoricalEvent.fromJson({
      'slug': 'lam-son-1428',
      'title': 'Khởi nghĩa Lam Sơn',
      'year': 1428,
    });

    expect(event.learningProgress, isNull);
  });

  test('Figure nhận phạm vi tri thức từ cấu hình persona', () {
    final figure = Figure.fromJson({
      'slug': 'tran-hung-dao',
      'name': 'Trần Hưng Đạo',
      'knowledge_boundary': 'đến khoảng năm 1300',
    });

    expect(figure.knowledgeBoundary, 'đến khoảng năm 1300');
  });

  test('HistoricalEvent ánh xạ đầy đủ 5 banner bài học từ assets', () {
    final slugs = [
      'bach-dang-938',
      'khang-chien-tong-981',
      'bach-dang-1288',
      'lam-son-1428',
      'quang-trung-1789',
    ];

    for (final slug in slugs) {
      final ev = HistoricalEvent.fromJson({'slug': slug, 'title': slug, 'year': 1000});
      expect(ev.hasIntegratedBanner, isTrue, reason: 'Slug $slug phải có integrated banner');
      expect(ev.bannerAsset, isNotNull, reason: 'Slug $slug phải có bannerAsset');
      expect(ev.bannerAsset, startsWith('assets/events/'), reason: 'Slug $slug phải lấy ảnh trong assets');
      expect(ev.bannerAspectRatio, greaterThan(2.35), reason: 'Slug $slug phải có tỉ lệ banner ~2.4:1');
      expect(ev.bannerAspectRatio, lessThan(2.45), reason: 'Slug $slug phải có tỉ lệ banner ~2.4:1');
    }
  });
}
