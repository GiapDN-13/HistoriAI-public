import 'browser_tts_stub.dart'
    if (dart.library.js_interop) 'browser_tts_web.dart' as impl;

/// Đọc văn bản bằng giọng có sẵn của trình duyệt (Web Speech API).
///
/// Dùng làm fallback khi backend không có TTS (vd web trên Render free không
/// chạy viXTTS). Trên mobile/native: no-op (mobile dùng audio từ backend).
class BrowserTts {
  /// True nếu nền tảng hỗ trợ đọc (web có speechSynthesis).
  static bool get supported => impl.supported;

  /// Đọc [text] (tiếng Việt). [onDone] gọi khi đọc xong/hủy.
  static void speak(String text, {void Function()? onDone}) =>
      impl.speak(text, onDone: onDone);

  static void stop() => impl.stop();
}
