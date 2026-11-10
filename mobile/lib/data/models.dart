// Model dữ liệu khớp với schema backend (app/schemas/content.py).

class HistoricalEvent {
  HistoricalEvent({
    required this.slug,
    required this.title,
    required this.year,
    this.period,
    this.era,
    this.summary,
    this.cinematicVideoUrl,
    this.thumbnailUrl,
    this.features,
    this.quizCount = 0,
    this.learningProgress,
    this.summaryThcs,
    this.summaryThpt,
    this.grades = const [],
    this.curriculum = const [],
    this.sources = const [],
  });

  final String slug;
  final String title;
  final int year;
  final String? period;
  final String? era;
  final String? summary;
  final String? cinematicVideoUrl;
  final String? thumbnailUrl;
  final String? features;

  /// Số câu hỏi thật trong kho của sự kiện này, do backend đếm.
  final int quizCount;

  /// Tiến độ học do backend người dùng cung cấp sau này (0–1). Null = chưa bắt đầu.
  final double? learningProgress;

  // --- Do đường ống làm giàu dữ liệu điền (data_pipeline/). Sự kiện chưa qua
  // đường ống thì rỗng và app hiện như cũ. ---
  final String? summaryThcs;
  final String? summaryThpt;

  /// Các lớp học tới sự kiện này theo Chương trình GDPT 2018.
  final List<int> grades;
  final List<CurriculumRef> curriculum;
  final List<SourceRef> sources;

  /// Chủ đề chương trình dùng được để hiện. Bỏ các dòng đường ống tách hỏng từ PDF
  /// chương trình (vd Lam Sơn 1428 có dòng "THCS-8-04" với chủ đề chỉ còn "XVIII"):
  /// tên chủ đề dưới 3 chữ là mảnh vụn, không phải tên chủ đề thật.
  List<CurriculumRef> get chuongTrinhHopLe => curriculum
      .where((c) => c.lop > 0 && c.chuDe.trim().split(RegExp(r'\s+')).length >= 3)
      .toList();

  /// Các lớp học tới sự kiện — theo chủ đề hợp lệ; chưa có chủ đề thì theo [grades].
  List<int> get lopHoc {
    final ct = chuongTrinhHopLe;
    final ds = ct.isEmpty ? grades : ct.map((c) => c.lop);
    return ({...ds}.toList()..sort());
  }

  /// Tóm tắt hợp với người đọc. Biết lớp thì chọn bản THCS/THPT; chưa biết thì
  /// ưu tiên bản nhóm viết tay, không có mới dùng bản THCS.
  String? tomTatCho(int? lop) {
    String? rong(String? s) => (s == null || s.trim().isEmpty) ? null : s;
    if (lop != null) {
      final theoCap = lop >= 10 ? rong(summaryThpt) : rong(summaryThcs);
      return theoCap ?? rong(summary) ?? rong(summaryThcs);
    }
    return rong(summary) ?? rong(summaryThcs);
  }

  /// Bộ sưu tập banner bài học đồ hoạ nghệ thuật hoàn chỉnh
  ///
  /// Banner ĐÃ IN SẴN CHỮ (tên trận, năm, triều đại, một dòng mô tả). Vì vậy nó
  /// không thay [thumbnailUrl]: chỗ nào lấy banner thì phải tự ẩn chữ đè trùng
  /// (xem [hasIntegratedBanner]), còn [thumbnailUrl] vẫn là ảnh máy chủ trả.
  static const Map<String, String> eventBanners = {
    'bach-dang-938': 'assets/events/bach_dang_938.jpg',
    'khang-chien-tong-981': 'assets/events/khang_chien_tong_981.jpg',
    'bach-dang-1288': 'assets/events/bach_dang_1288.jpg',
    'lam-son-1428': 'assets/events/lam_son_1428.jpg',
    'quang-trung-1789': 'assets/events/quang_trung_1789.jpg',
  };

  /// Ảnh banner cục bộ nếu có sẵn trong assets.
  String? get bannerAsset => eventBanners[slug];

  /// Trả về true nếu sự kiện đã có ảnh banner thiết kế hoàn chỉnh (bao gồm typography / huy hiệu)
  bool get hasIntegratedBanner => eventBanners.containsKey(slug);

  /// Tỉ lệ khung hình (width / height) chuẩn xác theo kích thước tệp banner
  double get bannerAspectRatio =>
      slug == 'bach-dang-938' ? (946 / 394) : (1024 / 426);

  factory HistoricalEvent.fromJson(Map<String, dynamic> j) {
    final s = (j['slug'] ?? '').toString();
    return HistoricalEvent(
      slug: s,
      title: j['title'] ?? '',
      year: (j['year'] as num?)?.toInt() ?? 0,
      period: j['period'],
      era: j['era'],
      summary: j['summary'],
      cinematicVideoUrl: j['cinematic_video_url'],
      // Giữ đúng ảnh máy chủ trả. Từng chỗ hiện ảnh tự chọn `bannerAsset ??
      // thumbnailUrl` — ghi đè ở đây thì chỗ nào cũng nhận banner có chữ mà không
      // biết để ẩn tiêu đề/chip đè lên, thành chữ chồng chữ.
      thumbnailUrl: j['thumbnail_url'],
      features: j['features'],
      quizCount: (j['quiz_count'] as num?)?.toInt() ?? 0,
      learningProgress: (j['learning_progress'] as num?)?.toDouble(),
      summaryThcs: j['summary_thcs'],
      summaryThpt: j['summary_thpt'],
      grades: ((j['grades'] as String?) ?? '')
          .split(',')
          .map((item) => int.tryParse(item.trim()))
          .whereType<int>()
          .toList(),
      curriculum: ((j['curriculum'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => CurriculumRef.fromJson(m.cast<String, dynamic>()))
          .toList(),
      sources: SourceRef.danhSach(j['sources']),
    );
  }
}

/// Một chủ đề trong Chương trình GDPT 2018 mà sự kiện thuộc về.
class CurriculumRef {
  const CurriculumRef({required this.ma, required this.lop, required this.chuDe});
  final String ma;
  final int lop;
  final String chuDe;

  factory CurriculumRef.fromJson(Map<String, dynamic> j) => CurriculumRef(
        ma: (j['ma'] ?? '').toString(),
        lop: (j['lop'] as num?)?.toInt() ?? 0,
        chuDe: (j['chu_de'] ?? '').toString(),
      );
}

/// Nguồn tư liệu kèm giấy phép. Giấy phép CC BY-SA của Wikipedia BẮT BUỘC ghi
/// nguồn ở nơi người dùng thấy được — nên phải hiện ra, không chỉ lưu.
class SourceRef {
  const SourceRef({required this.ten, this.url, this.giayPhep});
  final String ten;
  final String? url;
  final String? giayPhep;

  static List<SourceRef> danhSach(dynamic tho) => ((tho as List?) ?? const [])
      .whereType<Map>()
      .where((m) => (m['ten'] ?? '').toString().isNotEmpty)
      .map((m) => SourceRef(
            ten: m['ten'].toString(),
            url: m['url']?.toString(),
            giayPhep: m['giay_phep']?.toString(),
          ))
      .toList();
}

class Figure {
  Figure({
    required this.slug,
    required this.name,
    this.title,
    this.period,
    this.portraitUrl,
    this.modelUrl,
    this.knowledgeBoundary,
    this.isFeatured = false,
    this.unlockLevel = 1,
  });

  final String slug;
  final String name;
  final String? title;
  final String? period;
  final String? portraitUrl;
  final String? modelUrl;
  final String? knowledgeBoundary;
  final bool isFeatured;
  final int unlockLevel;

  factory Figure.fromJson(Map<String, dynamic> j) => Figure(
        slug: j['slug'],
        name: j['name'],
        title: j['title'],
        period: j['period'],
        portraitUrl: j['portrait_url'],
        modelUrl: j['model_url'],
        knowledgeBoundary: j['knowledge_boundary'],
        isFeatured: j['is_featured'] ?? false,
        unlockLevel: j['unlock_level'] ?? 1,
      );

  // --- Ảnh đóng gói theo app (khớp mockup, load tức thì) ---

  /// Chân dung toàn thân (.jpg hi-res) cho ảnh nền card.
  static const _fullPortraits = <String>{'tran-hung-dao', 'quang-trung'};

  /// Chân dung dạng .png cũ (chỉ Nguyễn Trãi tạm dùng crop mockup).
  static const _pngPortraits = <String>{'nguyen-trai'};

  /// Nhân vật có bộ 6 ảnh xoay 360 (turntable).
  static const _spinFigures = <String>{'tran-hung-dao', 'quang-trung'};

  /// Ảnh nền card (toàn thân). Null nếu chưa có.
  String? get portraitAsset {
    if (_fullPortraits.contains(slug)) return 'assets/portraits/$slug.jpg';
    if (_pngPortraits.contains(slug)) return 'assets/portraits/$slug.png';
    return null;
  }

  /// Ảnh khuôn mặt (vuông) cho avatar tròn. Fallback về portraitAsset.
  String? get faceAsset => _fullPortraits.contains(slug)
      ? 'assets/portraits/$slug-face.jpg'
      : portraitAsset;

  /// 6 frame xoay 360 (drag-to-rotate). Rỗng nếu không có.
  List<String> get spinFrames => _spinFigures.contains(slug)
      ? List.generate(6, (i) => 'assets/figures3d/$slug/$i.jpg')
      : const [];

  bool get hasSpin => _spinFigures.contains(slug);

  /// Nhân vật có model 3D .glb thật (đã deploy tại historiai-app/models).
  /// Ưu tiên cờ này để hiện viewer 3D; ảnh dùng làm poster fallback.
  static const _glbFigures = <String>{'tran-hung-dao', 'quang-trung'};

  bool get hasModel3D =>
      _glbFigures.contains(slug) || (modelUrl ?? '').isNotEmpty;
}

class Artifact {
  Artifact(
      {required this.slug,
      required this.name,
      this.period,
      this.description,
      this.modelGlbUrl,
      this.thumbnailUrl,
      this.realScaleMeters});
  final String slug;
  final String name;
  final String? period;
  final String? description;
  final String? modelGlbUrl;
  final String? thumbnailUrl;

  /// Chiều lớn nhất của hiện vật ngoài đời, đơn vị **mét**.
  ///
  /// `null` nghĩa là nhóm **chưa tra được nguồn đáng tin** cho cổ vật này —
  /// không phải "quên điền". Mọi tính năng hứa "kích thước thật" (đặt cổ vật
  /// vào phòng qua AR) phải tự ẩn đi khi giá trị này rỗng: thà thiếu một nút
  /// còn hơn dạy người học nhớ sai kích thước cổ vật.
  final double? realScaleMeters;

  /// Hiện vật có model .glb thật để dựng 3D hay không.
  bool get hasModel3D => (modelGlbUrl ?? '').isNotEmpty;

  /// Đã biết kích thước thật hay chưa.
  bool get coKichThuocThat => (realScaleMeters ?? 0) > 0;

  factory Artifact.fromJson(Map<String, dynamic> j) => Artifact(
        slug: j['slug'],
        name: j['name'],
        period: j['period'],
        description: j['description'],
        modelGlbUrl: j['model_glb_url'],
        thumbnailUrl: j['thumbnail_url'],
        realScaleMeters: _soMet(j['real_scale_meters']),
      );

  /// Backend lưu `real_scale_meters` ở kiểu chuỗi (cột String), và ô chưa tra
  /// được để rỗng. Chuỗi rác cũng trả `null` chứ không ném lỗi — một ô gõ nhầm
  /// trong seed không đáng làm sập cả màn Bảo tàng.
  static double? _soMet(dynamic tho) {
    if (tho == null) return null;
    if (tho is num) return tho > 0 ? tho.toDouble() : null;
    final s = tho.toString().trim();
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    return (v != null && v > 0) ? v : null;
  }
}

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.difficulty,
  });

  final int id;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final int difficulty;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: j['id'],
        question: j['question'],
        optionA: j['option_a'],
        optionB: j['option_b'],
        optionC: j['option_c'],
        optionD: j['option_d'],
        difficulty: j['difficulty'] ?? 1,
      );
}

class QuizCheckResult {
  QuizCheckResult({
    required this.questionId,
    required this.correct,
    this.correctOption,
    this.explanation,
  });

  final int questionId;
  final bool correct;

  /// Đáp án đúng + lời giải — máy chủ trả kèm từ 21/10. Máy chủ cũ không có thì null
  /// và màn chơi hiện như trước (chỉ báo đúng/sai).
  final String? correctOption;
  final String? explanation;

  factory QuizCheckResult.fromJson(Map<String, dynamic> j) => QuizCheckResult(
        questionId: j['question_id'],
        correct: j['correct'],
        correctOption: (j['correct_option'] as String?)?.toUpperCase(),
        explanation: (j['explanation'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['explanation'] as String).trim(),
      );
}

class QuizSubmitResult {
  QuizSubmitResult({
    required this.questionId,
    required this.correct,
    required this.correctOption,
    this.explanation,
    this.xp = 0,
  });

  final int questionId;
  final bool correct;
  final String correctOption;
  final String? explanation;

  /// XP thật máy chủ cộng cho câu này: 0 nếu sai HOẶC đã từng trả lời đúng trước đó.
  final int xp;

  factory QuizSubmitResult.fromJson(Map<String, dynamic> j) => QuizSubmitResult(
        questionId: j['question_id'],
        correct: j['correct'],
        correctOption: j['correct_option'],
        explanation: j['explanation'],
        xp: (j['xp'] as num?)?.toInt() ?? 0,
      );
}
