import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web: phải dùng NÚT CHÍNH THỨC do Google vẽ (GIS) — Google không cho app web tự
/// mở cửa sổ đăng nhập bằng nút riêng. Bấm xong, mã về qua authenticationEvents.
Widget nutGoogleWeb() => SizedBox(
      height: 44,
      child: web.renderButton(
        configuration: web.GSIButtonConfiguration(
          text: web.GSIButtonText.continueWith,
          shape: web.GSIButtonShape.pill,
          theme: web.GSIButtonTheme.outline,
          size: web.GSIButtonSize.large,
          locale: 'vi',
          minimumWidth: 280,
        ),
      ),
    );
