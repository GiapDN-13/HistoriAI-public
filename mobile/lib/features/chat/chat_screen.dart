import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/analytics.dart';
import '../../core/api_client.dart';
import '../../core/app_preferences.dart';
import '../../core/services/browser_tts.dart';
import '../../core/theme.dart';
import '../../core/widgets/chi_dan.dart';
import '../../core/widgets/glb_viewer.dart';
import '../../core/widgets/vietnamese_decorations.dart';
import '../../data/models.dart';
import '../phan_hoi/hoi_phan_hoi.dart';
import '../premium/het_luot_ngay.dart';
import 'giong_doc.dart';
import 'lich_su_chat.dart';
import 'widgets/audio_bar.dart';
import 'widgets/chat_bubble.dart';

/// Màn hình Chat với Vĩ Nhân — hỗ trợ stream trả lời từ LLM + phát âm thanh TTS.
/// Khắc phục L11 (nút gửi thành nút chính), L16 (chỉ hiện audio bar khi phát thật),
/// thêm 3 câu hỏi gợi ý nhanh theo Mục 16.3 j.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.figureSlug,
    required this.figureName,
    this.figureTitle,
    this.period,
    this.cauMoDau,
  });

  final String figureSlug;
  final String figureName;
  final String? figureTitle;
  final String? period;

  /// Câu điền sẵn vào ô nhập (vd từ thẻ "Mốc sử hôm nay"). Không tự gửi.
  final String? cauMoDau;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiClient();
  final _textCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  final List<ChatMessage> _messages = [];
  int _nextMessageId = 0;
  bool _isLoading = false;
  StreamSubscription<String>? _streamSub;

  late final HangDoiGiong _giong;
  int _soCauDaTraLoi = 0;
  TachCau? _tach;
  bool _isSpeaking = false;
  bool _audioLoading = false;
  int? _speakingIndex;
  Duration? _audioDuration;

  bool _is3DMode = false;
  bool _hasModel3D = false;
  final _dieuKhien3D = GlbViewerController();

  final _khoaNut3D = GlobalKey();
  final _khoaGoiY = GlobalKey();
  final _khoaONhap = GlobalKey();

  ImageProvider? get _portraitProvider {
    final figure = Figure(slug: widget.figureSlug, name: widget.figureName);
    if (figure.faceAsset != null) {
      return AssetImage(figure.faceAsset!);
    }
    return null;
  }

  String get _figureSealText {
    final slug = widget.figureSlug.toLowerCase();
    if (slug.contains('hung-dao') || slug.contains('tran-quoc-tuan')) {
      return 'VẠN KIẾP TIẾT CHẾ';
    }
    if (slug.contains('nguyen-trai')) return 'ỨC TRAI QUAN TRIỆN';
    if (slug.contains('ho-chi-minh')) return 'ÁI QUỐC CHÍNH ĐẠI';
    if (slug.contains('vo-nguyen-giap')) return 'TỔNG TƯ LỆNH';
    if (slug.contains('quang-trung') || slug.contains('nguyen-hue')) {
      return 'BẮC BÌNH ĐẠI ẤN';
    }
    if (slug.contains('ngo-quyen')) return 'TIỀN NGÔ VƯƠNG';
    if (slug.contains('le-loi')) return 'BÌNH ĐỊNH VƯƠNG';
    if (slug.contains('trung')) return 'MÊ LINH TRƯNG NỮ';
    return 'ĐẠI VIỆT DANH NHÂN';
  }

  @override
  void initState() {
    super.initState();
    // Bắt buộc ghi nhận event chatOpen theo R3
    Analytics.instance.log(Ev.chatOpen, target: widget.figureSlug);
    _hasModel3D =
        Figure(slug: widget.figureSlug, name: widget.figureName).hasModel3D;
    _giong = HangDoiGiong(
      xin: _xinGiong,
      trinhPhat: TrinhPhatAudioplayers(),
      khiLoi: _docBangTrinhDuyet,
    );
    _giong.dangNoi.addListener(_capNhatGiong);
    _giong.dangTai.addListener(_capNhatGiong);
    _addIntroMessage();
    _napLichSu();
    if (widget.cauMoDau != null) _textCtl.text = widget.cauMoDau!;
  }

  /// Mở lại cuộc trò chuyện cũ với vị này (lưu trên máy — xem lich_su_chat.dart).
  Future<void> _napLichSu() async {
    final cu = await LichSuChat.doc(widget.figureSlug);
    if (!mounted || cu.isEmpty || _messages.length > 1) return;
    setState(() {
      for (final l in cu) {
        _messages.add(ChatMessage(
          id: _nextMessageId++,
          text: l.noiDung,
          isUser: l.laNguoiDung,
          sources: l.nguon,
        ));
      }
    });
    _scrollDown();
  }

  /// Các lượt thật (bỏ lời chào mở đầu, câu đang gõ, câu báo lỗi).
  List<LuotDaLuu> get _cacLuot => [
        for (final m in _messages.skip(1))
          if (!m.isTyping && !m.laLoi && m.text.trim().isNotEmpty)
            LuotDaLuu(
                laNguoiDung: m.isUser, noiDung: m.text, nguon: m.sources ?? const []),
      ];

  Future<void> _cuocTroChuyenMoi() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Xoá cuộc trò chuyện?'),
        content: Text('Toàn bộ trò chuyện với ${widget.figureName} sẽ bị xoá khỏi máy này '
            'và không khôi phục được. Sau đó con có thể hỏi lại từ đầu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _stopAudio();
    await _streamSub?.cancel();
    await LichSuChat.xoa(widget.figureSlug);
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _isLoading = false;
      _addIntroMessage();
    });
  }

  Future<void> _saoChep(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Đã sao chép câu trả lời'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  /// Máy chủ bắt đầu tạo giọng ngay khi nhận câu; đường dẫn trả về phát được
  /// trong lúc đang tạo (tiếng đầu ~0,6 s).
  Future<String?> _xinGiong(String cau) async {
    final r = await _api.post('/chat/speak/stream', {
      'figure_slug': widget.figureSlug,
      'text': cau,
    }) as Map<String, dynamic>;
    return r['audio_url'] as String?;
  }

  /// Máy chủ không tạo được giọng cho câu này — đọc bằng giọng của trình duyệt.
  Future<void> _docBangTrinhDuyet(String cau) {
    if (!BrowserTts.supported) return Future.value();
    final xong = Completer<void>();
    BrowserTts.speak(cau, onDone: () {
      if (!xong.isCompleted) xong.complete();
    });
    return xong.future;
  }

  void _capNhatGiong() {
    if (!mounted) return;
    final noi = _giong.dangNoi.value;
    setState(() {
      _isSpeaking = noi;
      _audioLoading = _giong.dangTai.value;
      if (!noi && !_giong.dangTai.value && !_giong.ban && !_isLoading) {
        _speakingIndex = null;
      }
    });
    // Nhân vật khua tay khi đang nói, đứng thở khi đã nói xong và không còn chữ về
    if (noi) {
      _cuDong('giang_giai');
    } else if (!_giong.ban && !_isLoading) {
      _cuDong('dung_tho');
    }
  }

  bool _daXinChiDan = false;

  /// Gọi từ lúc thân màn được dựng — xem ghi chú cùng tên ở màn Bảo tàng.
  void _chiDan() {
    if (_daXinChiDan || !mounted) return;
    _daXinChiDan = true;
    ChiDan.chay(context, khoa: 'chat-vi-nhan-v1', cacBuoc: [
      BuocChiDan(
        khoa: _khoaGoiY,
        tieuDe: 'Chưa biết hỏi gì thì chạm sẵn',
        noiDung: 'Ba câu gợi ý bám đúng những gì vị này thật sự biết. Chạm '
            'một câu là gửi ngay.',
        boTronKhung: 18,
      ),
      BuocChiDan(
        khoa: _khoaONhap,
        tieuDe: 'Hoặc hỏi theo ý mình',
        noiDung: 'Gõ tiếng Việt bình thường. Hỏi ngoài thời của vị ấy thì '
            'ngài sẽ nói thẳng là không rõ, chứ không bịa.',
        boTronKhung: 22,
      ),
      if (_hasModel3D)
        BuocChiDan(
          khoa: _khoaNut3D,
          tieuDe: 'Gọi ngài hiện lên',
          noiDung: 'Bấm nút này để thấy nhân vật dựng 3D: ngài sẽ cúi chào, '
              'rồi khua người mỗi khi đang trả lời con.',
          boTronKhung: 20,
        ),
    ]);
  }

  @override
  void dispose() {
    _textCtl.dispose();
    _scrollCtl.dispose();
    _giong.dangNoi.removeListener(_capNhatGiong);
    _giong.dangTai.removeListener(_capNhatGiong);
    unawaited(_giong.huy());
    BrowserTts.stop();
    _streamSub?.cancel();
    super.dispose();
  }

  void _addIntroMessage() {
    _messages.add(ChatMessage(
      id: _nextMessageId++,
      text:
          'Ta là ${widget.figureName}! Hãy hỏi ta về lịch sử Việt Nam, ta sẽ đàm đạo cùng con.',
      isUser: false,
      sources: const [],
    ));
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtl.hasClients) {
        _scrollCtl.animateTo(
          _scrollCtl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _textCtl.text.trim();
    if (text.isEmpty || _isLoading) return;
    _textCtl.clear();
    await _stopAudio();

    // Bắt buộc ghi nhận event chatMessageSent theo R3
    Analytics.instance.log(
      Ev.chatMessageSent,
      target: widget.figureSlug,
      value: text.length,
    );

    // Lịch sử lấy TRƯỚC khi thêm câu hỏi mới — câu mới gửi riêng ở trường message.
    final lichSu = _cacLuot.map((l) => l.choMayChu()).toList();
    setState(() {
      _messages.add(ChatMessage(
        id: _nextMessageId++,
        text: text,
        isUser: true,
        sources: const [],
      ));
      _isLoading = true;
    });
    // Nhân vật bắt đầu "nói" ngay lúc nhận câu hỏi, không chờ chữ đầu tiên về:
    // độ trễ mạng là chỗ người dùng dễ tưởng app đứng hình nhất.
    _cuDong('giang_giai');
    _scrollDown();

    final replyMsg = ChatMessage(
      id: _nextMessageId++,
      text: '',
      isUser: false,
      isTyping: true,
      sources: const [],
    );
    setState(() => _messages.add(replyMsg));

    final replyIndex = _messages.length - 1;
    final buffer = StringBuffer();
    // Nguồn thật của sử liệu máy chủ đã đưa cho mô hình — tới ở một dòng riêng
    // "[NGUON][...]" ngay trước [DONE] (backend/app/api/routes/chat.py).
    var nguon = const <String>[];
    final tuDoc = AppPreferences.tuDoc.value;
    var daBaoLoi = false;
    _tach = TachCau();
    if (tuDoc) _speakingIndex = replyIndex;

    try {
      final stream = _api.streamChat(widget.figureSlug, text, lichSu: lichSu);
      _streamSub = stream.listen(
        (chunk) {
          if (chunk.startsWith('[NGUON]')) {
            try {
              nguon = (jsonDecode(chunk.substring(7)) as List).cast<String>();
            } catch (_) {}
            return;
          }
          buffer.write(chunk);
          // Đọc từng câu ngay khi câu đó viết xong — không đợi cả đoạn
          if (tuDoc) {
            for (final cau in _tach!.them(chunk)) {
              _giong.them(cau);
            }
          }
          _messages[replyIndex] = _messages[replyIndex].copyWith(
            text: buffer.toString().trimLeft(),
            isTyping: true,
          );
          setState(() {});
          _scrollDown();
        },
        // Sau onError stream vẫn phát onDone; không chặn thì câu báo lỗi vừa
        // hiện bị đè bằng "ta chưa nghĩ ra câu trả lời" (hoặc thẻ hết lượt
        // bị bỏ sót vì tin nhắn đã gỡ).
        onDone: () {
          if (daBaoLoi) return;
          _onReplyComplete(replyIndex, buffer.toString().trim(), nguon);
        },
        onError: (e) {
          daBaoLoi = true;
          final soCau = soCauKhiHetLuot(e);
          if (soCau != null) {
            _hetLuotNgay(replyIndex, text, soCau);
            return;
          }
          _messages[replyIndex] = _messages[replyIndex].copyWith(
            text:
                'Xin lỗi con, có trục trặc nhỏ trong dòng hồi ức. Hãy thử hỏi lại ta nhé.',
            isTyping: false,
            laLoi: true,
          );
          setState(() => _isLoading = false);
          _cuDong('dung_tho');
        },
      );
    } catch (e) {
      setState(() {
        _messages[replyIndex] = _messages[replyIndex].copyWith(
          text: 'Xin lỗi con, ta chưa nghe rõ câu hỏi. Con hãy hỏi lại nhé.',
          isTyping: false,
          laLoi: true,
        );
        _isLoading = false;
      });
      _cuDong('dung_tho');
    }
  }

  /// Hết lượt hỏi miễn phí trong ngày (402 `het_luot_ngay`).
  ///
  /// Gỡ cả câu hỏi lẫn khung trả lời đang chờ: câu đó CHƯA được trả lời, để
  /// nó lại trong khung chat thì lịch sử như thể vĩ nhân đã làm ngơ. Trả chữ
  /// về ô nhập để người dùng không phải gõ lại khi mai quay lại (hoặc sau khi
  /// mua Premium).
  void _hetLuotNgay(int replyIndex, String cauHoi, int soCau) {
    if (!mounted) return;
    setState(() {
      // Gỡ từ cuối lên: chỉ gỡ khi đúng là hai tin vừa thêm.
      if (_messages.length == replyIndex + 1 && replyIndex >= 1) {
        _messages.removeRange(replyIndex - 1, replyIndex + 1);
      }
      _isLoading = false;
      _speakingIndex = null;
      _textCtl.text = cauHoi;
      _textCtl.selection = TextSelection.collapsed(offset: cauHoi.length);
    });
    _cuDong('dung_tho');
    hienHetLuotNgay(context, soCau: soCau);
  }

  void _onReplyComplete(int index, String fullText, [List<String> nguon = const []]) {
    setState(() {
      // KHÔNG gắn nguồn: trước đây câu nào cũng ghi "Đại Việt Sử Ký Toàn Thư"
      // dù mô hình không hề tra sách đó. Máy chủ trả "[Lỗi kết nối AI…]" khi mô
      // hình hỏng — đánh dấu là lỗi để không lưu, không gửi lại làm ngữ cảnh.
      final loi = fullText.isEmpty || fullText.contains('[Lỗi');
      _messages[index] = _messages[index].copyWith(
        text: fullText.contains('[Lỗi quá tải')
            ? 'Hôm nay ta đã tiếp quá nhiều lượt hỏi, cần nghỉ ít lâu. Con quay lại '
                'sau ít phút nhé.'
            : loi
                ? 'Xin lỗi con, ta chưa nghĩ ra câu trả lời. Con hỏi lại nhé.'
                : fullText,
        isTyping: false,
        laLoi: loi,
        sources: loi ? const [] : nguon,
      );
      _isLoading = false;
    });
    LichSuChat.ghi(widget.figureSlug, _cacLuot);
    // Hỏi vĩ nhân cũng là một ngày học — giữ chuỗi ngày cho người đã đăng nhập.
    if (_api.isSignedIn) {
      _api.post('/me/streak', {}).catchError((_) => null);
    }
    if (AppPreferences.tuDoc.value) {
      final cuoi = _tach?.ket();
      if (cuoi != null) _giong.them(cuoi);
    } else {
      // Không tự đọc: vẫn nhờ máy chủ tạo sẵn, để lúc bấm loa là phát ngay
      for (final cau in TachCau.tachHet(fullText)) {
        _giong.lamNong(cau);
      }
    }
    if (!_giong.ban) _cuDong('dung_tho');
    _scrollDown();
    // Đủ 3 câu trả lời mới hỏi — lúc đó người dùng đã đủ trải nghiệm để có ý kiến
    _soCauDaTraLoi++;
    if (_soCauDaTraLoi == 3) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) hoiPhanHoi(context, nguCanh: 'chat', target: widget.figureSlug);
      });
    }
  }

  Future<void> _stopAudio() async {
    await _giong.dung();
    BrowserTts.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _speakingIndex = null;
        _audioLoading = false;
      });
    }
  }

  Future<void> _toggleAudioFor(int index, String text) async {
    // Đang tải cũng tính là đang đọc: bấm lại lúc đó là muốn dừng, không phải xếp thêm lượt
    if ((_isSpeaking || _audioLoading) && _speakingIndex == index) {
      await _stopAudio();
      return;
    }

    // Bắt buộc ghi nhận event chatVoicePlay theo R3
    Analytics.instance.log(Ev.chatVoicePlay, target: widget.figureSlug);

    await _stopAudio();

    setState(() {
      _speakingIndex = index;
      _audioLoading = true;
      _audioDuration = null;
    });
    // Đọc theo từng câu: câu đầu phát ngay khi có tiếng, câu sau tạo trong lúc
    // câu trước đang phát. Câu nào đã tự đọc lúc trước thì lấy từ lưu đệm.
    for (final cau in TachCau.tachHet(text)) {
      _giong.them(cau);
    }
  }

  /// Sân khấu 3D phía trên khung chat.
  ///
  /// Chiếm 30% chiều cao: đủ thấy nhân vật từ đầu tới quá thắt lưng, mà vẫn
  /// còn chỗ cho vài dòng đối thoại. Cố tình KHÔNG cận mặt — rig không có
  /// xương hàm nên không nhép miệng được; đóng khung ngang tầm 3/4 người thì
  /// ở cỡ màn hình điện thoại không ai nhận ra điều đó.
  Widget _sanKhau3D() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.30,
      decoration: const BoxDecoration(
        color: AppColors.bgAlt,
        border: Border(
          bottom: BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      child: GlbViewer(
        slug: widget.figureSlug,
        // 90° là hướng nhìn thẳng mặt; tắt tự xoay vì nhân vật đang trò
        // chuyện mà quay lưng lại giữa câu thì hỏng hết cảm giác đối thoại.
        quayNgangDo: 90,
        tuXoay: false,
        cuDongDau: 'chao',
        dieuKhien: _dieuKhien3D,
        poster: _portraitProvider,
      ),
    );
  }

  /// Đổi cử động theo trạng thái cuộc trò chuyện. Gọi thoải mái kể cả khi
  /// chưa bật chế độ 3D — lệnh rơi vào hư không, không sao.
  void _cuDong(String ten, {bool motLan = false}) =>
      _dieuKhien3D.cuDong(ten, motLan: motLan);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _chiDan());
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            if (_is3DMode && _hasModel3D) _sanKhau3D(),
            Expanded(
              child: DongSonBackground(
                size: 320,
                opacity: 0.03,
                child: ListView.builder(
                  controller: _scrollCtl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isAudioActive = _speakingIndex == i;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChatBubble(
                          key: ValueKey(m.id),
                          text: m.text,
                          isUser: m.isUser,
                          isTyping: m.isTyping,
                          sources:
                              (m.sources?.isEmpty ?? true) ? null : m.sources,
                          botAvatar: m.isUser ? null : _portraitProvider,
                          sealText: m.isUser ? null : _figureSealText,
                        ),
                        // Sửa lỗi L16: Chỉ hiện AudioBar khi đang phát, bình thường hiện nút "Nghe ngài kể"
                        if (!m.isUser &&
                            !m.isTyping &&
                            m.text.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 44, bottom: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(child: isAudioActive
                                ? AudioBar(
                                    isPlaying: _isSpeaking,
                                    loading: _audioLoading,
                                    duration: _audioDuration,
                                    onToggle: () => _toggleAudioFor(i, m.text),
                                  )
                                : Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () => _toggleAudioFor(i, m.text),
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(minHeight: 44),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgAlt,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: AppColors.border),
                                          boxShadow: appSoftShadow,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.volume_up_rounded,
                                                color: AppColors.red, size: 15),
                                            SizedBox(width: 5),
                                            Text(
                                              'Nghe ngài kể',
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )),
                                if (!m.laLoi)
                                  IconButton(
                                    tooltip: 'Sao chép câu trả lời',
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 17, color: AppColors.inkSoft),
                                    onPressed: () => _saoChep(m.text),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.figureName} đang suy ngẫm...',
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.inkSoft,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),

            // 3 thẻ câu hỏi gợi ý nhanh (Mục 16.3 j)
            KeyedSubtree(key: _khoaGoiY, child: _suggestedQuestions()),

            // Thanh nhập liệu
            KeyedSubtree(key: _khoaONhap, child: _inputBar()),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
        decoration: const BoxDecoration(
          color: AppColors.red,
          boxShadow: [
            BoxShadow(
                color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Quay lại danh sách vĩ nhân',
              icon: const Icon(Icons.arrow_back, color: AppColors.goldBright),
              onPressed: () {
                if (_isSpeaking) _stopAudio();
                Navigator.pop(context);
              },
            ),
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBright, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.redDark,
                backgroundImage: _portraitProvider,
                child: _portraitProvider == null
                    ? const Icon(Icons.person,
                        color: AppColors.goldBright, size: 20)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.figureName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      color: AppColors.goldBright,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.figureTitle ?? 'Danh nhân lịch sử Việt Nam',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.onRed.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Xoá cuộc trò chuyện',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.goldBright, size: 22),
              onPressed: _messages.length > 1 ? _cuocTroChuyenMoi : null,
            ),
            ValueListenableBuilder<bool>(
              valueListenable: AppPreferences.tuDoc,
              builder: (_, bat, __) => IconButton(
                tooltip: bat
                    ? 'Đang tự đọc câu trả lời — bấm để tắt'
                    : 'Bật tự đọc câu trả lời',
                icon: Icon(
                  bat ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: AppColors.goldBright,
                  size: 22,
                ),
                onPressed: () {
                  AppPreferences.setTuDoc(!bat);
                  if (bat) _stopAudio();
                },
              ),
            ),
            if (_hasModel3D)
              IconButton(
                tooltip: _is3DMode ? 'Chuyển sang ảnh' : 'Xem mô hình 3D',
                icon: Icon(
                  _is3DMode ? Icons.image_rounded : Icons.view_in_ar_rounded,
                  color: AppColors.goldBright,
                  size: 22,
                ),
                key: _khoaNut3D,
                onPressed: () {
                  setState(() => _is3DMode = !_is3DMode);
                  // Bật lại lần thứ hai trở đi thì viewer đã nạp sẵn, nên phải
                  // tự ra lệnh chào; lần đầu viewer tự chào khi nạp xong.
                  if (_is3DMode) _cuDong('chao', motLan: true);
                },
              ),
          ],
        ),
      );

  Widget _suggestedQuestions() {
    final slug = widget.figureSlug.toLowerCase();
    final List<String> suggestions;

    if (slug.contains('hung-dao') || slug.contains('tran-quoc-tuan')) {
      suggestions = [
        'Khởi bẩm Vương gia, kế sách cọc ngầm Bạch Đằng?',
        'Ý chí "Sát Thát" bắt nguồn từ đâu?',
        'Lời căn dặn hậu thế về đạo giữ nước?',
      ];
    } else if (slug.contains('quang-trung') || slug.contains('nguyen-hue')) {
      suggestions = [
        'Khởi bẩm Hoàng thượng, vì sao tiến quân ra Bắc đúng dịp Tết?',
        'Trận Ngọc Hồi – Đống Đa diễn ra thế nào?',
        'Lời hiểu dụ tướng sĩ ở Nghệ An năm ấy?',
      ];
    } else if (slug.contains('nguyen-trai')) {
      suggestions = [
        'Bái kiến Tiên sinh, tư tưởng "Nhân nghĩa" cốt ở đâu?',
        'Hoàn cảnh khởi thảo Bình Ngô Đại Cáo?',
        'Nỗi niềm Ước Trai với sự nghiệp kiến quốc?',
      ];
    } else if (slug.contains('ho-chi-minh')) {
      suggestions = [
        'Kính thưa Bác, tinh thần "Không có gì quý hơn độc lập tự do"?',
        'Lời Bác dặn dò thanh thiếu niên Việt Nam?',
        'Bí quyết quy tụ sức mạnh khối đại đoàn kết?',
      ];
    } else if (slug.contains('vo-nguyen-giap')) {
      suggestions = [
        'Khởi bẩm Đại tướng, quyết định đổi từ "đánh nhanh" sang "đánh chắc"?',
        'Chiến dịch Điện Biên Phủ "chấn động địa cầu"?',
        'Nghệ thuật chiến tranh nhân dân Đại Việt?',
      ];
    } else {
      suggestions = [
        'Khởi bẩm Tiền nhân, kế sách lớn nhất của Người là gì?',
        'Ý nghĩa của chiến tích hào hùng với non sông?',
        'Lời răn dạy quý báu cho thế hệ học sinh hôm nay?',
      ];
    }

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _sendMessage(suggestions[i]),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                  boxShadow: appSoftShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.help_outline_rounded,
                        size: 13, color: AppColors.red),
                    const SizedBox(width: 5),
                    Text(
                      suggestions[i],
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _inputBar() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(color: AppColors.red),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Bỏ nút mic (27/09): chưa nhận được giọng nói, nút chỉ báo "đang
              // hoàn thiện" — hứa suông. Thêm lại khi làm thật.
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _textCtl,
                  style: const TextStyle(
                      fontFamily: 'Inter', color: AppColors.ink, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Hỏi ${widget.figureName}...',
                    hintStyle: const TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.inkMuted,
                        fontSize: 14),
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              _sendButton(),
            ],
          ),
        ),
      );

  Widget _sendButton() {
    final hasText = _textCtl.text.trim().isNotEmpty;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: (hasText || _isLoading) ? ctaGradient : null,
        color: (hasText || _isLoading) ? null : Colors.white24,
        shape: BoxShape.circle,
        boxShadow: hasText ? appSoftShadow : null,
      ),
      child: IconButton(
        tooltip: _isLoading ? 'Đang gửi câu hỏi' : 'Gửi câu hỏi',
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Icon(
                Icons.send_rounded,
                color: hasText
                    ? Colors.white
                    : AppColors.onRed.withValues(alpha: 0.6),
                size: 19,
              ),
        onPressed: (hasText && !_isLoading) ? () => _sendMessage() : null,
      ),
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.isTyping = false,
    this.sources,
    this.hasAudio = false,
    this.laLoi = false,
  });

  final int id;

  /// Câu báo lỗi của app (không phải lời vĩ nhân) — không lưu, không gửi làm ngữ cảnh.
  final bool laLoi;
  final String text;
  final bool isUser;
  final bool isTyping;
  final List<String>? sources;
  final bool hasAudio;

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    bool? isTyping,
    List<String>? sources,
    bool? hasAudio,
    bool? laLoi,
  }) =>
      ChatMessage(
        id: id,
        text: text ?? this.text,
        isUser: isUser ?? this.isUser,
        isTyping: isTyping ?? this.isTyping,
        sources: sources ?? this.sources,
        hasAudio: hasAudio ?? this.hasAudio,
        laLoi: laLoi ?? this.laLoi,
      );
}
