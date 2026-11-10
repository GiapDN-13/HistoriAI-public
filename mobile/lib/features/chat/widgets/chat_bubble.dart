import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils/motion_preferences.dart';
import 'source_chip.dart';

/// Bubble chat — lời vĩ nhân (nền sắc phong hoàng gia) / lời người học (cam gradient).
/// Tương phản rõ nét giữa phong thái tiền nhân và người học thời nay.
class ChatBubble extends StatefulWidget {
  const ChatBubble({
    super.key,
    required this.text,
    this.isUser = false,
    this.isTyping = false,
    this.sources,
    this.botAvatar,
    this.sealText,
  });

  final String text;
  final bool isUser;
  final bool isTyping;
  final List<String>? sources;
  final ImageProvider? botAvatar;
  final String? sealText;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  bool _reduceMotion = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MotionPreferences.reduce(context);
    if (!widget.isUser && !widget.isTyping && !_revealed) _startReveal();
  }

  @override
  void didUpdateWidget(covariant ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isUser &&
        oldWidget.isTyping &&
        !widget.isTyping &&
        !_revealed) {
      _startReveal();
    }
  }

  void _startReveal() {
    _revealed = true;
    if (_reduceMotion) {
      _revealController.value = 1;
    } else {
      _revealController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldAnimate = !widget.isUser && !widget.isTyping && _revealed;
    final bubble = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isUser) ...[
            _avatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: widget.isUser ? ctaGradient : null,
                color: widget.isUser ? null : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(widget.isUser ? 14 : 3),
                  bottomRight: Radius.circular(widget.isUser ? 3 : 14),
                ),
                border: widget.isUser
                    ? null
                    : Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        width: 1,
                      ),
                boxShadow: appSoftShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isTyping) _typingIndicator() else _messageText(),
                  if (widget.sources != null && widget.sources!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.sources!
                          .map((s) => SourceChip(label: s))
                          .toList(),
                    ),
                  ],
                  if (!widget.isUser &&
                      !widget.isTyping &&
                      widget.sealText != null &&
                      widget.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.red.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded,
                                size: 10, color: AppColors.red),
                            const SizedBox(width: 4),
                            Text(
                              widget.sealText!,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.red,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.isUser) const SizedBox(width: 32),
        ],
      ),
    );

    if (!shouldAnimate || _reduceMotion) return bubble;
    return AnimatedBuilder(
      animation: _revealController,
      child: bubble,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_revealController.value);
        return Opacity(
          opacity: 0.68 + 0.32 * t,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _messageText() {
    final style = TextStyle(
      fontFamily: 'Inter',
      color: widget.isUser ? Colors.white : AppColors.ink,
      fontSize: 14.5,
      height: 1.5,
    );
    if (widget.isUser || _reduceMotion || !_revealed) {
      return Text(widget.text, style: style);
    }

    final groups = _textGroups(widget.text);
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: groups.asMap().entries.map((entry) {
            final start = (entry.key * 0.10).clamp(0.0, 0.3).toDouble();
            final end =
                (0.72 + entry.key * 0.08).clamp(start + 0.1, 1.0).toDouble();
            final animation = CurvedAnimation(
              parent: _revealController,
              curve: Interval(start, end, curve: Curves.easeOut),
            );
            return AnimatedBuilder(
              animation: animation,
              child: Text(entry.value, style: style),
              builder: (context, child) => Opacity(
                opacity: 0.35 + 0.65 * animation.value,
                child: Transform.translate(
                  offset: Offset(0, 4 * (1 - animation.value)),
                  child: child,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<String> _textGroups(String text) {
    final paragraphs = text
        .split(RegExp(r'\n+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return _coalesce(paragraphs.isEmpty ? [text] : paragraphs);
  }

  List<String> _coalesce(List<String> parts) {
    if (parts.length <= 4) return parts;
    final groups = List.generate(4, (_) => <String>[]);
    for (var i = 0; i < parts.length; i++) {
      groups[(i * 4 / parts.length).floor()].add(parts[i]);
    }
    return groups.map((group) => group.join(' ')).toList();
  }

  Widget _avatar() => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.redDark,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.goldBright, width: 1.8),
          image: widget.botAvatar != null
              ? DecorationImage(image: widget.botAvatar!, fit: BoxFit.cover)
              : null,
          boxShadow: appSoftShadow,
        ),
        child: widget.botAvatar == null
            ? const Center(
                child:
                    Icon(Icons.person, color: AppColors.goldBright, size: 20),
              )
            : null,
      );

  Widget _typingIndicator() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(),
          const SizedBox(width: 5),
          _dot(),
          const SizedBox(width: 5),
          _dot(),
        ],
      );

  Widget _dot() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.3, end: 1.0),
        duration: const Duration(milliseconds: 600),
        builder: (_, value, __) => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        ),
      );
}
