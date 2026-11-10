// Web: dùng Web Speech API (window.speechSynthesis) để đọc tiếng Việt.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get supported {
  try {
    // Truy cập được speechSynthesis là đủ; lỗi -> không hỗ trợ.
    web.window.speechSynthesis.getVoices();
    return true;
  } catch (_) {
    return false;
  }
}

void speak(String text, {void Function()? onDone}) {
  try {
    final synth = web.window.speechSynthesis;
    synth.cancel(); // dừng câu đang đọc nếu có
    final u = web.SpeechSynthesisUtterance(text)
      ..lang = 'vi-VN'
      ..rate = 0.96
      ..pitch = 1.0;
    if (onDone != null) {
      u.onend = (web.Event _) {
        onDone();
      }.toJS;
    }
    // Ưu tiên chọn giọng tiếng Việt nếu trình duyệt có.
    final voices = synth.getVoices().toDart;
    for (final v in voices) {
      if (v.lang.toLowerCase().startsWith('vi')) {
        u.voice = v;
        break;
      }
    }
    synth.speak(u);
  } catch (_) {
    onDone?.call();
  }
}

void stop() {
  try {
    web.window.speechSynthesis.cancel();
  } catch (_) {}
}
