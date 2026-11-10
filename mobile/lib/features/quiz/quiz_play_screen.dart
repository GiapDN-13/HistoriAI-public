import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/api_client.dart';
import '../../core/bai_lam_cho.dart';
import '../../core/theme.dart';
import '../../core/utils/motion_preferences.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/battle_slash_effect.dart';
import '../../core/widgets/battlefield_tactics_header.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../../data/models.dart';
import 'quiz_result_screen.dart';

/// Câu khen khi đúng. Góp ý 04/10: chữ "sử hoá" quá thì học sinh thấy xa lạ —
/// giữ chút không khí trận mạc nhưng đọc là hiểu ngay.
const _correctPhrases = [
  'Chính xác!',
  'Đúng rồi!',
  'Trúng ngay!',
];

/// Câu khi sai / hết giờ.
const _wrongPhrases = [
  'Chưa đúng',
  'Tiếc quá!',
  'Sai mất rồi',
];

/// Màn chơi Quiz — Đấu trường 4 đáp án + timer 30s + 3 mạng.
/// Ẩn thanh tab dưới để học sinh tập trung làm bài (Mục 5.1).
/// Tích hợp con dấu triện đỏ son khi làm đúng (Mục 16.4 s),
/// nhịp đập trống trận khi timer < 5s (Mục 16.4 t), và layout cân đối.
class QuizPlayScreen extends StatefulWidget {
  const QuizPlayScreen({
    super.key,
    required this.eventSlug,
    required this.eventTitle,
    this.cauHoiSan,
  });

  final String eventSlug;
  final String eventTitle;

  /// Bộ câu có sẵn (vd "Ôn câu sai") — có thì không tải theo sự kiện nữa.
  final List<QuizQuestion>? cauHoiSan;

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen>
    with TickerProviderStateMixin {
  final _api = ApiClient();
  final _rng = Random();

  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int _lives = 3;
  int _score = 0;
  int _correctCount = 0;
  int _streakCount = 0;
  int _timerSeconds = 30;
  Timer? _timer;
  String? _error;

  bool _loading = true;
  bool _answered = false;
  bool _checkingAnswer = false;
  bool? _currentAnswerCorrect;
  int _answerRequestGeneration = 0;
  String? _selectedOption;

  /// Đáp án đúng + lời giải của câu vừa chấm (máy chủ trả kèm). Chọn sai / hết giờ
  /// thì hiện cả hai và CHỜ người học bấm "Câu tiếp theo" — trước đây 1,4 giây sau
  /// là tự sang câu, không kịp biết mình sai ở đâu (góp ý 05/10).
  String? _correctOption;
  String? _explanation;
  bool _waitingNext = false;

  /// Cuộn danh sách đáp án xuống thẻ giải thích khi nó hiện — điện thoại nhỏ thì
  /// thẻ nằm dưới mép màn, người học không biết là có.
  final _cuonDapAn = ScrollController();

  void _cuonToiGiaiThich() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_cuonDapAn.hasClients) return;
      _cuonDapAn.animateTo(
        _cuonDapAn.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  final List<Map<String, dynamic>> _answers = [];
  List<QuizSubmitResult> _results = [];
  bool _submitting = false;

  // Animation nhịp trống trận khi timer < 5s
  late final AnimationController _pulseCtrl;

  // Animation cho selected answer effect (scale/glow)
  late final AnimationController _answerFeedbackCtrl;
  late final Animation<double> _answerScale;

  // Battle feedback state
  String _stampText = 'CHUẨN';
  String _stampSubtext = 'CHÍNH XÁC';
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    // Bắt buộc ghi nhận event quizStart theo R3
    Analytics.instance.log(Ev.quizStart, target: widget.eventSlug);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Answer selection feedback — 200ms
    _answerFeedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _answerScale = Tween<double>(begin: 1.0, end: 1.018).animate(
      CurvedAnimation(parent: _answerFeedbackCtrl, curve: Curves.easeOut),
    );

    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cuonDapAn.dispose();
    _pulseCtrl.dispose();
    _answerFeedbackCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MotionPreferences.reduce(context);
  }

  Future<void> _loadQuestions() async {
    final san = widget.cauHoiSan;
    if (san != null) {
      setState(() {
        _questions = List.of(san);
        _loading = false;
        if (_questions.isNotEmpty) _startTimer();
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get('/quiz/${widget.eventSlug}') as List;
      if (!mounted) return;
      setState(() {
        _questions = data.map((e) => QuizQuestion.fromJson(e)).toList();
        _loading = false;
        if (_questions.isNotEmpty) _startTimer();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Không thể tải câu hỏi đấu trường');
    }
  }

  void _startTimer({int seconds = 30}) {
    _timer?.cancel();
    _pulseCtrl.stop();
    setState(() => _timerSeconds = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds <= 1) {
        t.cancel();
        _pulseCtrl.stop();
        _handleTimeout();
      } else {
        setState(() {
          _timerSeconds--;
          if (_timerSeconds <= 5 && !_reduceMotion && !_pulseCtrl.isAnimating) {
            _pulseCtrl.repeat(reverse: true);
          }
        });
      }
    });
  }

  Future<void> _handleTimeout() async {
    if (_answered || _checkingAnswer) return;
    final q = _questions[_currentIndex];
    const phrases = _wrongPhrases;
    _stampText = phrases[_rng.nextInt(phrases.length)];
    _stampSubtext = 'HẾT GIỜ';
    final generation = ++_answerRequestGeneration;
    setState(() {
      _answered = true;
      _currentAnswerCorrect = false;
      _lives--;
      _streakCount = 0;
    });
    _answers.add({'question_id': q.id, 'selected_option': ''});
    _answerFeedbackCtrl.forward();
    // Hết giờ cũng nên biết đáp án: hỏi máy chủ với lựa chọn rỗng.
    try {
      final checked = QuizCheckResult.fromJson(await _api.post('/quiz/check', {
        'question_id': q.id,
        'selected_option': '',
      }) as Map<String, dynamic>);
      if (!mounted || generation != _answerRequestGeneration) return;
      if (checked.questionId == q.id && checked.correctOption != null) {
        setState(() {
          _correctOption = checked.correctOption;
          _explanation = checked.explanation;
          _waitingNext = true;
        });
        _cuonToiGiaiThich();
        return;
      }
    } catch (_) {}
    if (mounted && generation == _answerRequestGeneration) _advanceAfterDelay();
  }

  Future<void> _selectOption(String option) async {
    if (_answered || _checkingAnswer) return;
    _timer?.cancel();
    _pulseCtrl.stop();
    final q = _questions[_currentIndex];
    final generation = ++_answerRequestGeneration;
    // Đổi màu ô vừa bấm NGAY, trước khi máy chủ trả lời — góp ý 17/10 "ấn đáp án
    // phải mất một lúc mới hiện": trước đây trong lúc chờ mạng màn hình đứng im.
    setState(() {
      _checkingAnswer = true;
      _selectedOption = option;
    });

    try {
      final data = await _api.post('/quiz/check', {
        'question_id': q.id,
        'selected_option': option,
      }) as Map<String, dynamic>;
      if (!mounted || generation != _answerRequestGeneration) return;
      final checked = QuizCheckResult.fromJson(data);
      if (checked.questionId != q.id) {
        throw StateError('Quiz check returned a different question');
      }

      final isCorrect = checked.correct;
      final phrases = isCorrect ? _correctPhrases : _wrongPhrases;
      _stampText = phrases[_rng.nextInt(phrases.length)];
      _stampSubtext = isCorrect ? 'CHÍNH XÁC' : 'CHƯA ĐÚNG';
      _answers.add({'question_id': q.id, 'selected_option': option});

      setState(() {
        _checkingAnswer = false;
        _answered = true;
        _currentAnswerCorrect = isCorrect;
        _correctOption = checked.correctOption;
        _explanation = checked.explanation;
        // Sai mà biết đáp án đúng → dừng lại giảng; đúng thì đi tiếp cho nhanh.
        _waitingNext = !isCorrect && checked.correctOption != null;
        if (isCorrect) {
          _correctCount++;
          _streakCount++;
        } else {
          _lives--;
          _streakCount = 0;
        }
      });
      _answerFeedbackCtrl.forward(from: 0);
      if (_waitingNext) {
        _cuonToiGiaiThich();
      } else {
        _advanceAfterDelay();
      }
    } catch (_) {
      if (!mounted || generation != _answerRequestGeneration) return;
      setState(() {
        _checkingAnswer = false;
        _selectedOption = null;
      });
      _startTimer(seconds: _timerSeconds);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mạng chập chờn nên chưa chấm được. Bạn chọn lại nhé.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  bool get _isLastStep =>
      _lives <= 0 || _currentIndex >= _questions.length - 1;

  void _nextQuestion() {
    if (!mounted) return;
    _answerFeedbackCtrl.reset();
    if (_isLastStep) {
      _submitAndFinish();
    } else {
      setState(() {
        _currentIndex++;
        _answered = false;
        _checkingAnswer = false;
        _currentAnswerCorrect = null;
        _selectedOption = null;
        _correctOption = null;
        _explanation = null;
        _waitingNext = false;
      });
      _startTimer();
    }
  }

  void _advanceAfterDelay() {
    final generation = _answerRequestGeneration;
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted || generation != _answerRequestGeneration || _waitingNext) {
        return;
      }
      _nextQuestion();
    });
  }

  Future<void> _submitAndFinish() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    // Điểm hiển thị theo số câu chấm đúng lúc chơi — có cả khi chưa lưu được.
    _score = _correctCount * 10;
    int? xpNhan;
    var trangThai = TrangThaiLuu.daLuu;
    if (!_api.isSignedIn) {
      // Khách: giữ bài trên máy, đăng nhập/đăng ký xong app tự gửi (bai_lam_cho.dart).
      trangThai = TrangThaiLuu.khach;
      await BaiLamCho.them(List.of(_answers));
    } else {
      try {
        final data = await _api.postJson('/quiz/submit', _answers) as List;
        _results = data.map((e) => QuizSubmitResult.fromJson(e)).toList();
        xpNhan = _results.fold<int>(0, (s, r) => s + r.xp);
        _score = _results.where((r) => r.correct).length * 10;
      } catch (_) {
        // Trước đây lỗi bị nuốt: màn kết quả trông như đã lưu. Giờ giữ lại gửi sau
        // và nói thẳng với người dùng.
        trangThai = TrangThaiLuu.loi;
        await BaiLamCho.them(List.of(_answers));
      }
    }
    // Bắt buộc giữ nguyên lời gọi đo lường quizSubmit theo R3
    Analytics.instance.log(
      Ev.quizSubmit,
      target: widget.eventSlug,
      value: _correctCount,
      them: {'tong_cau': _questions.length, 'luu': trangThai.name},
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          score: _score,
          totalQuestions: _questions.length,
          livesLeft: _lives,
          results: _results,
          eventTitle: widget.eventTitle,
          eventSlug: widget.eventSlug,
          soCauDung: _correctCount,
          xpNhan: xpNhan,
          trangThaiLuu: trangThai,
          laOnTap: widget.cauHoiSan != null,
          questions: List<QuizQuestion>.unmodifiable(_questions),
          selectedOptions: {
            for (final answer in _answers)
              answer['question_id'] as int: answer['selected_option'] as String,
          },
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Dừng trận đấu?',
          style: TextStyle(
              fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Nếu thoát bây giờ, kết quả của trận đấu sẽ không được lưu lại.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục làm bài',
                style:
                    TextStyle(fontFamily: 'Montserrat', color: AppColors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thoát',
                style: TextStyle(
                    fontFamily: 'Montserrat', color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
    return exit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.red,
          foregroundColor: AppColors.goldBright,
          leading: IconButton(
            tooltip: 'Thoát trận đấu',
            icon: const Icon(Icons.close_rounded, color: AppColors.goldBright),
            onPressed: () async {
              final shouldExit = await _onWillPop();
              if (shouldExit && context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            widget.eventTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            // Số mạng sống còn lại
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: List.generate(3, (i) {
                  final active = i < _lives;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.favorite,
                      size: 20,
                      color: active ? AppColors.goldBright : Colors.white24,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : _error != null
                ? ErrorState(message: _error!, onRetry: _loadQuestions)
                : _buildQuizBody(),
      ),
    );
  }

  Widget _buildQuizBody() {
    final q = _questions[_currentIndex];
    final isUrgent = _timerSeconds <= 5;

    final options = [
      ('A', q.optionA),
      ('B', q.optionB),
      ('C', q.optionC),
      ('D', q.optionD),
    ];

    return DongSonBackground(
      size: 340,
      opacity: 0.03,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sa Bàn Bày Binh Bố Trận & Sĩ Khí Đại Việt
              BattlefieldTacticsHeader(
                campaignName: widget.eventTitle,
                currentQuestion: _currentIndex + 1,
                totalQuestions: _questions.length,
                correctCount: _correctCount,
                streakCount: _streakCount,
                timeRemaining: _timerSeconds,
                isDrumBeating: isUrgent,
              ),

              const SizedBox(height: 12),

              // Thẻ hiển thị nội dung câu hỏi
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Text(
                  q.question,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.45,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 4 ô đáp án lựa chọn (phân bố đều chiều dọc)
              Expanded(
                child: Stack(
                  children: [
                    ListView.separated(
                      controller: _cuonDapAn,
                      physics: const BouncingScrollPhysics(),
                      itemCount: options.length + (_waitingNext ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, idx) {
                        if (idx >= options.length) return _giaiThich();
                        final opt = options[idx];
                        final optKey = opt.$1;
                        final optText = opt.$2;

                        final isSelected = _selectedOption == optKey;
                        // Ô đáp án đúng khi người học chọn sai / hết giờ.
                        final isRevealedCorrect = _answered &&
                            _currentAnswerCorrect == false &&
                            _correctOption == optKey;
                        final isUnselected =
                            _answered && !isSelected && !isRevealedCorrect;

                        // --- Color state ---
                        Color tileBg = AppColors.card;
                        Color borderCol = AppColors.border;
                        Color textColor = AppColors.ink;
                        double borderWidth = 1.0;
                        List<BoxShadow>? shadows = appSoftShadow;
                        Color badgeBg = AppColors.bgAlt;
                        Color badgeBorder = AppColors.border;
                        Color badgeText = AppColors.inkSoft;
                        Widget? suffixIcon;

                        if (_answered && isSelected) {
                          final isCorrect = _currentAnswerCorrect == true;
                          final accent =
                              isCorrect ? AppColors.gold : AppColors.danger;
                          tileBg = accent.withValues(alpha: 0.08);
                          borderCol = accent;
                          textColor =
                              isCorrect ? AppColors.goldDark : AppColors.danger;
                          borderWidth = 2.0;
                          shadows = [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.25),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ];
                          badgeBg = accent;
                          badgeBorder = accent;
                          badgeText = Colors.white;
                          suffixIcon = Icon(
                            isCorrect
                                ? Icons.check_circle_rounded
                                : Icons.close_rounded,
                            color: accent,
                            size: 20,
                          );
                        } else if (isRevealedCorrect) {
                          const accent = AppColors.success;
                          tileBg = accent.withValues(alpha: 0.08);
                          borderCol = accent;
                          textColor = AppColors.ink;
                          borderWidth = 2.0;
                          badgeBg = accent;
                          badgeBorder = accent;
                          badgeText = Colors.white;
                          suffixIcon = const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Đáp án đúng',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  )),
                              SizedBox(width: 4),
                              Icon(Icons.check_circle_rounded,
                                  color: accent, size: 20),
                            ],
                          );
                        } else if (_checkingAnswer && isSelected) {
                          // Đang chờ máy chủ chấm: đổi màu ngay để biết đã bấm.
                          tileBg = AppColors.red.withValues(alpha: 0.06);
                          borderCol = AppColors.red;
                          borderWidth = 2.0;
                          badgeBg = AppColors.red;
                          badgeBorder = AppColors.red;
                          badgeText = Colors.white;
                          suffixIcon = const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.red),
                          );
                        }

                        Widget tile = AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: tileBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: borderCol, width: borderWidth),
                            boxShadow: shadows,
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: badgeBorder),
                                ),
                                child: Text(
                                  optKey,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: badgeText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  optText,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              if (suffixIcon != null) ...[
                                const SizedBox(width: 8),
                                suffixIcon,
                              ],
                            ],
                          ),
                        );

                        // Scale/slash cho đúng; shake nhẹ cho sai.
                        if (_answered && isSelected) {
                          final isCorrect = _currentAnswerCorrect == true;
                          tile = AnimatedBuilder(
                            animation: _answerFeedbackCtrl,
                            builder: (context, child) {
                              final t = _answerFeedbackCtrl.value;
                              final shake = isCorrect
                                  ? 0.0
                                  : sin(t * pi * 6) * 4 * (1 - t);
                              return Transform.translate(
                                offset: Offset(shake, 0),
                                child: Transform.scale(
                                  scale: _answerScale.value,
                                  child: child,
                                ),
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                tile,
                                Positioned.fill(
                                  child: BattleSlashEffect(
                                    animation: _answerFeedbackCtrl,
                                    isCorrect: isCorrect,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Dim unselected answers
                        if (isUnselected) {
                          tile = AnimatedOpacity(
                            opacity: 0.5,
                            duration: const Duration(milliseconds: 250),
                            child: tile,
                          );
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: (_answered || _checkingAnswer)
                                ? null
                                : () => _selectOption(optKey),
                            child: tile,
                          ),
                        );
                      },
                    ),

                    // Con dấu triện — chỉ khi tự sang câu; đang giảng thì nhường chỗ.
                    if (_answered && !_waitingNext)
                      Positioned(
                        right: 16,
                        bottom: 8,
                        child: RoyalSealStamp(
                          text: _stampText,
                          subtext: _stampSubtext,
                          width: 145,
                          height: 78,
                        ),
                      ),
                  ],
                ),
              ),
              if (_waitingNext) ...[
                const SizedBox(height: 12),
                AppButton(
                  key: const Key('quiz-cau-tiep'),
                  label: _isLastStep ? 'Xem kết quả' : 'Câu tiếp theo',
                  icon: Icons.arrow_forward_rounded,
                  fullWidth: true,
                  onPressed: _nextQuestion,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Thẻ giảng lại khi chọn sai / hết giờ: đáp án đúng + lời giải (nếu kho có).
  Widget _giaiThich() {
    final q = _questions[_currentIndex];
    final dung = switch (_correctOption) {
      'A' => q.optionA,
      'B' => q.optionB,
      'C' => q.optionC,
      'D' => q.optionD,
      _ => null,
    };
    return Container(
      key: const Key('quiz-giai-thich'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline_rounded,
                size: 18, color: AppColors.goldDark),
            const SizedBox(width: 6),
            Text(
              _selectedOption == null ? 'Hết giờ — đáp án là' : 'Đáp án đúng là',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.goldDark,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          if (dung != null)
            Text(
              '$_correctOption. $dung',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                height: 1.35,
              ),
            ),
          if (_explanation != null) ...[
            const SizedBox(height: 6),
            Text(
              _explanation!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                color: AppColors.inkSoft,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
