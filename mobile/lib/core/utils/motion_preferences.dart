import 'package:flutter/widgets.dart';

/// Central access point for the platform's reduced-motion preference.
abstract final class MotionPreferences {
  static bool reduce(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
