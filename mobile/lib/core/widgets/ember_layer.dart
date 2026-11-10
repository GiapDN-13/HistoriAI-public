import 'package:flutter/material.dart';

import '../app_preferences.dart';
import 'ember_layer_stub.dart'
    if (dart.library.js_interop) 'ember_layer_web.dart' as platform;

/// HTML/CSS trang trí được Flutter xếp giữa nền và nội dung, không phủ toàn app.
class EmberLayer extends StatelessWidget {
  const EmberLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppPreferences.emberEffectsEnabled,
      builder: (context, enabled, _) => enabled
          ? ExcludeSemantics(
              child: IgnorePointer(child: platform.buildEmberLayer()),
            )
          : const SizedBox.shrink(),
    );
  }
}
