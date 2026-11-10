/// Native (mobile/desktop): không có Web Speech API -> no-op.
const bool supported = false;

void speak(String text, {void Function()? onDone}) => onDone?.call();

void stop() {}
