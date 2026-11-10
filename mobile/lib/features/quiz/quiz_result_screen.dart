import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/analytics.dart';
import '../../core/api_client.dart';
import '../timeline/event_detail_screen.dart';
import '../phan_hoi/hoi_phan_hoi.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/royal_edict_scroll.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../../data/models.dart';
import '../../core/widgets/phao_giay.dart';

/// Bài vừa làm đã vào tài khoản chưa — màn kết quả phải nói thật điều này.
enum TrangThaiLuu {
  /// Đã lưu lên máy chủ.
  daLuu,

  /// Khách chưa đăng nhập: giữ trên máy, đăng nhập xong tự cộng.
  khach,

  /// Đã đăng nhập nhưng nộp hỏng (mất mạng): giữ trên máy, gửi lại sau.
  loi,
}

/// Màn kết quả Quiz — Bảng Vàng Bia Tiến Sĩ Văn Miếu (Mục 16.4 p).
/// Tôn vinh điểm số và kiến thức của học sinh với phong cách khoa bảng Việt Nam.
class QuizResultScreen extends StatefulWidget {
  const QuizResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.livesLeft,
    required this.results,
    required this.eventTitle,
    this.questions = const [],
    this.selectedOptions = const {},
    this.eventSlug,
    this.soCauDung,
    this.xpNhan,
    this.trangThaiLuu = TrangThaiLuu.daLuu,
    this.laOnTap = false,
  });

  final String? eventSlug;

  /// Số câu chấm đúng lúc chơi — dùng khi chưa có kết quả từ máy chủ (khách, lỗi mạng).
  final int? soCauDung;

  /// XP thật máy chủ cộng (chỉ câu lần đầu đúng). null = chưa lưu nên chưa biết.
  final int? xpNhan;
  final TrangThaiLuu trangThaiLuu;

  /// Lượt "Ôn câu sai" (không phải một trận theo sự kiện).
  final bool laOnTap;

  final int score;
  final int totalQuestions;
  final int livesLeft;
  final List<QuizSubmitResult> results;
  final String eventTitle;
  final List<QuizQuestion> questions;
  final Map<int, String> selectedOptions;

  String? _questionText(int questionId) {
    for (final question in questions) {
      if (question.id == questionId) return question.question;
    }
    return null;
  }

  String? _optionText(int questionId, String? optionKey) {
    if (optionKey == null) return null;
    for (final question in questions) {
      if (question.id != questionId) continue;
      return switch (optionKey.toUpperCase()) {
        'A' => question.optionA,
        'B' => question.optionB,
        'C' => question.optionC,
        'D' => question.optionD,
        _ => null,
      };
    }
    return null;
  }

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  int _displayedXp = 0;
  bool _showDetails = false;
  Timer? _henHoiPhanHoi;

  /// Trận kế tiếp theo năm — nút "Học tiếp". Góp ý 04/10: "giữ được chuỗi vài
  /// ngày rồi mình không biết học tiếp bài nào". Trước đây chỉ có "đánh lại" và
  /// "về bản đồ".
  HistoricalEvent? _tranTiep;

  Future<void> _timTranTiep() async {
    if (widget.laOnTap) return;
    try {
      final ds = (await ApiClient().get('/events') as List)
          .map((j) => HistoricalEvent.fromJson((j as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.year.compareTo(b.year));
      final i = ds.indexWhere((e) => e.slug == widget.eventSlug);
      if (i >= 0 && i + 1 < ds.length && mounted) {
        setState(() => _tranTiep = ds[i + 1]);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    // Bắt buộc ghi nhận event đo lường quizResultView theo R3
    Analytics.instance.log(Ev.quizResultView, target: widget.eventSlug, value: widget.score);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.elasticOut,
    );
    _animCtrl.forward();
    _animateXp();
    _timTranTiep();
    _anMung();
    // Hỏi phản hồi sau khi người dùng kịp nhìn điểm và pháo giấy, không chen ngang
    // lúc đang mừng. Hẹn bằng Timer để huỷ được khi rời màn sớm.
    _henHoiPhanHoi = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) hoiPhanHoi(context, nguCanh: 'quiz', target: widget.eventTitle);
    });
  }

  /// Rung tay một nhịp ngay khi màn kết quả hiện ra.
  ///
  /// Thắng thì rung mạnh hai nhịp cách nhau, thua thì một nhịp nhẹ. Đây là
  /// phần phản hồi duy nhất người dùng cảm nhận được mà không cần nhìn, và nó
  /// rẻ: không cần tệp âm thanh, không cần xin quyền gì.
  ///
  /// Trên web thì lặng lẽ không làm gì — đó là hành vi đúng, không phải lỗi.
  void _anMung() {
    if (WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      return;
    }
    final thang = widget.livesLeft > 0 && widget.score > 0;
    if (!thang) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _henHoiPhanHoi?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _animateXp() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final target = widget.xpNhan ?? widget.score;
      if (target <= 0) return;
      if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
          .disableAnimations) {
        setState(() => _displayedXp = target);
        return;
      }
      const steps = 20;
      const stepDuration = 800 ~/ steps;
      int currentStep = 0;
      Timer.periodic(Duration(milliseconds: stepDuration), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        currentStep++;
        setState(() {
          _displayedXp = (target * currentStep ~/ steps).clamp(0, target);
        });
        if (currentStep >= steps) t.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final correctCount = widget.results.isNotEmpty
        ? widget.results.where((r) => r.correct).length
        : (widget.soCauDung ?? 0);
    final isPassed = widget.livesLeft > 0 && widget.score > 0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('KẾT QUẢ ĐẤU TRƯỜNG'),
        automaticallyImplyLeading: false,
      ),
      // Pháo giấy phủ LÊN TRÊN toàn bộ nội dung, và chỉ khi thắng. Thua mà vẫn
      // bắn pháo thì thành ra chế nhạo người ta.
      body: Stack(
        children: [
          _than(isPassed, correctCount, reduceMotion),
          Positioned.fill(child: PhaoGiay(chay: isPassed && !reduceMotion)),
        ],
      ),
    );
  }

  Widget _than(bool isPassed, int correctCount, bool reduceMotion) {
    return DongSonBackground(
      size: 340,
      opacity: 0.035,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                reduceMotion
                    ? _doctoralSteleCard(isPassed, correctCount)
                    : ScaleTransition(
                        scale: _scaleAnim,
                        child: _doctoralSteleCard(isPassed, correctCount),
                      ),
                if (isPassed)
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: RoyalSealStamp(
                      text: 'CHINH PHỤC',
                      subtext: 'HOÀN THÀNH',
                      width: 104,
                      height: 58,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _baoLuu(correctCount),
            const SizedBox(height: 20),

            // Nút xem chi tiết đáp án
            if (widget.results.isNotEmpty) ...[
              Semantics(
                button: true,
                expanded: _showDetails,
                label: _showDetails
                    ? 'Ẩn chi tiết bài làm'
                    : 'Xem giải thích từng câu hỏi',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _showDetails = !_showDetails),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: appSoftShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _showDetails
                                ? 'Ẩn chi tiết bài làm'
                                : 'Xem giải thích từng câu hỏi',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.red,
                            ),
                          ),
                          Icon(
                            _showDetails
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: AppColors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_showDetails) ...[
                const SizedBox(height: 12),
                ...widget.results.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: r.correct ? AppColors.success : AppColors.danger,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget._questionText(r.questionId)
                            case final question?) ...[
                          Text(question,
                              style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Icon(
                              r.correct ? Icons.check_circle : Icons.cancel,
                              color: r.correct
                                  ? AppColors.success
                                  : AppColors.danger,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Câu hỏi ${idx + 1}: ${r.correct ? 'Chính xác' : 'Chưa đúng'}',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: r.correct
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        if (widget._optionText(r.questionId,
                                widget.selectedOptions[r.questionId])
                            case final selected?) ...[
                          const SizedBox(height: 6),
                          Text('Bạn chọn: $selected',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.inkSoft,
                                  height: 1.4)),
                        ],
                        if (!r.correct)
                          if (widget._optionText(r.questionId, r.correctOption)
                              case final correct?) ...[
                            const SizedBox(height: 4),
                            Text('Đáp án đúng: $correct',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.success,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600)),
                          ],
                        if (r.explanation != null &&
                            r.explanation!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            r.explanation!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: AppColors.inkSoft,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],

            const SizedBox(height: 24),

            // Các nút hành động
            if (isPassed) ...[
              AppButton(
                label: 'Nhận giấy khen',
                icon: Icons.auto_awesome_rounded,
                variant: AppButtonVariant.primary,
                fullWidth: true,
                onPressed: () {
                  showRoyalEdictDialog(
                    context,
                    title: 'SẮC BAN KHỞI THẮNG',
                    recipient: 'Sĩ tử Đại Việt',
                    rankTitle: 'Chiến Tích: ${widget.eventTitle}',
                    body:
                        'Khảo thí tường minh, kế sách bày binh chuẩn xác đạt điểm tối đa! Ban thưởng sắc phong hoàng triều ghi nhận công trạng sử học.',
                    motto:
                        'Hiền tài là nguyên khí của quốc gia, quốc gia hưng thịnh nhờ sự học vững bền.',
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            // Thua thì thứ người ta muốn nhất là thử lại ngay, không phải
            // quay về bản đồ rồi tự đi tìm lại trận vừa rồi. Tiêu đề màn này
            // ghi "RÈN LUYỆN LẠI" từ trước mà chưa từng có nút để làm việc đó.
            if (!isPassed) ...[
              AppButton(
                label: 'Đánh lại trận này',
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.primary,
                fullWidth: true,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 12),
            ],
            if (_tranTiep != null) ...[
              AppButton(
                key: const Key('ket-qua-hoc-tiep'),
                label: 'Học tiếp: ${_tranTiep!.title}',
                icon: Icons.arrow_forward_rounded,
                variant: AppButtonVariant.secondary,
                fullWidth: true,
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EventDetailScreen(event: _tranTiep!)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            AppButton(
              label: 'Về danh sách trận',
              icon: Icons.map_outlined,
              variant: isPassed
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Nói thẳng bài vừa làm đã vào tài khoản chưa, và XP vì sao có thể ít hơn điểm.
  Widget _baoLuu(int correctCount) {
    final (IconData icon, Color mau, String chu) = switch (widget.trangThaiLuu) {
      TrangThaiLuu.khach => (
          Icons.person_add_alt_1_rounded,
          AppColors.cta,
          'Bài này chưa vào tài khoản nào. Đăng nhập hoặc đăng ký — app sẽ tự '
              'cộng bài vừa làm vào tài khoản của bạn.'
        ),
      TrangThaiLuu.loi => (
          Icons.cloud_off_rounded,
          AppColors.danger,
          'Chưa lưu được vì mất kết nối. App đã giữ bài này và sẽ tự gửi lại '
              'ở lần mở tới.'
        ),
      TrangThaiLuu.daLuu when (widget.xpNhan ?? 0) == 0 && correctCount > 0 => (
          Icons.info_outline_rounded,
          AppColors.inkSoft,
          'Đã lưu vào tài khoản. Những câu đúng này bạn đã được cộng XP ở lần '
              'làm trước — XP chỉ cộng cho lần đầu trả lời đúng mỗi câu.'
        ),
      TrangThaiLuu.daLuu => (
          Icons.cloud_done_rounded,
          AppColors.success,
          'Đã lưu vào tài khoản của bạn.'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mau.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: mau, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(chu,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  /// Khung mô phỏng Bia Tiến Sĩ Văn Miếu vinh quy bái tổ
  Widget _doctoralSteleCard(bool isPassed, int correctCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Biểu tượng Bia Tiến Sĩ / Vương miện hoa bảng
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: imperialRedGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.red.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(
              isPassed ? Icons.auto_awesome : Icons.replay_rounded,
              color: AppColors.goldBright,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            isPassed ? 'BẢNG VÀNG KHẮC TÊN' : 'RÈN LUYỆN LẠI',
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: AppColors.red,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.eventTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: AppColors.inkSoft,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 18),
          Container(
            width: 140,
            height: 1.5,
            color: AppColors.gold.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 18),

          // Điểm thưởng tích luỹ
          Text(
            '+$_displayedXp',
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              color: AppColors.cta,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(
            widget.trangThaiLuu == TrangThaiLuu.daLuu
                ? 'XP NHẬN ĐƯỢC'
                : 'ĐIỂM TRẬN NÀY · CHƯA LƯU',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: AppColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 18),

          // Kết quả câu đúng
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '$correctCount / ${widget.totalQuestions} câu đúng',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
