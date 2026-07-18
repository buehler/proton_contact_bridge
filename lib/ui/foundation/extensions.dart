import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/theme.dart';

extension BuildContextTheming on BuildContext {
  KinCryptTheme get theme =>
      Theme.of(this).extension<KinCryptTheme>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? kinCryptDarkTheme
          : kinCryptLightTheme);
}
