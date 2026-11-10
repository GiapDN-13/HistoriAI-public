import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../analytics.dart';
import '../theme.dart';
import 'app_widgets.dart';
import 'vietnamese_decorations.dart';

/// Trình phát thước phim lịch sử.
///
/// **Chỉ tải video khi người dùng bấm.** Một thước phim nặng trên trăm MB; tự
/// động nạp là đốt dung lượng 3G/4G của học sinh cho thứ họ có thể không xem.
/// Trước khi bấm, chỗ này chỉ là ảnh bìa tĩnh.
class CinematicPlayer extends StatefulWidget {
  const CinematicPlayer({
    super.key,
    required this.url,
    required this.eventSlug,
    this.posterUrl,
  });

  /// Địa chỉ tệp .mp4. Rỗng thì widget hiện trạng thái "chưa có phim".
  final String url;

  /// Slug sự kiện — dùng cho đo lường `video_play`.
  final String eventSlug;

  final String? posterUrl;

  @override
  State<CinematicPlayer> createState() => _CinematicPlayerState();
}

class _CinematicPlayerState extends State<CinematicPlayer> {
  VideoPlayerController? _dieuKhien;
  bool _dangNap = false;
  String? _loi;

  @override
  void dispose() {
    _dieuKhien?.dispose();
    super.dispose();
  }

  Future<void> _batDauPhat() async {
    if (_dangNap || _dieuKhien != null) return;
    setState(() {
      _dangNap = true;
      _loi = null;
    });

    Analytics.instance.log(Ev.videoPlay, target: widget.eventSlug);

    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _dieuKhien = c;
        _dangNap = false;
      });
      await c.play();
    } catch (e) {
      await c.dispose();
      if (!mounted) return;
      setState(() {
        _dangNap = false;
        _loi = 'Chưa mở được thước phim. Kiểm tra lại đường mạng rồi thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.redDeepest,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: _dieuKhien != null ? _khungPhat(_dieuKhien!) : _khungChoBam(),
        ),
      ),
    );
  }

  /// Trạng thái trước khi bấm: ảnh bìa + nút phát. Chưa tốn một byte video nào.
  Widget _khungChoBam() {
    final chuaCoPhim = widget.url.trim().isEmpty;
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        if ((widget.posterUrl ?? '').isNotEmpty)
          Opacity(
            opacity: 0.55,
            child: CoverImage(
              url: widget.posterUrl,
              borderRadius: 0,
              width: double.infinity,
              height: double.infinity,
            ),
          )
        else
          const Opacity(opacity: 0.12, child: DongSonBackground(size: 200)),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_dangNap)
              const SizedBox(
                width: 46,
                height: 46,
                child: CircularProgressIndicator(
                  color: AppColors.goldBright,
                  strokeWidth: 3,
                ),
              )
            else
              Semantics(
                button: true,
                label: 'Phát thước phim lịch sử',
                child: InkWell(
                  onTap: chuaCoPhim ? null : _batDauPhat,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: chuaCoPhim ? null : ctaGradient,
                      color: chuaCoPhim ? Colors.white24 : null,
                      boxShadow: chuaCoPhim
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.cta.withValues(alpha: 0.4),
                                blurRadius: 16,
                              ),
                            ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 32),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              _loi ??
                  (chuaCoPhim
                      ? 'Thước phim đang được dựng'
                      : _dangNap
                          ? 'Đang mở thước phim…'
                          : 'Xem thước phim lịch sử'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                color: _loi != null ? Colors.white : AppColors.goldBright,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _khungPhat(VideoPlayerController c) {
    return Stack(
      alignment: Alignment.center,
      children: [
        VideoPlayer(c),
        // Chạm vào khung để tạm dừng hoặc chạy tiếp
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                setState(() => c.value.isPlaying ? c.pause() : c.play()),
          ),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (_, v, __) => AnimatedOpacity(
            opacity: v.isPlaying ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black38,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 32),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VideoProgressIndicator(
                c,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                colors: const VideoProgressColors(
                  playedColor: AppColors.goldBright,
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
              ),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (_, v, __) => Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  child: Row(
                    children: [
                      Text(
                        '${_phut(v.position)} / ${_phut(v.duration)}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip:
                            v.volume == 0 ? 'Bật âm thanh' : 'Tắt âm thanh',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          v.volume == 0
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () => c.setVolume(v.volume == 0 ? 1 : 0),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _phut(Duration d) {
    final p = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final g = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$p:$g' : '$p:$g';
  }
}
