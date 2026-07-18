import 'package:flutter/widgets.dart';

enum DisplayProfile {
  compact, // Mobile portrait
  medium, // Mobile landscape / Tablet portrait
  large; // Tablet landscape / Desktop

  static DisplayProfile of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return switch (width) {
      < 600 => DisplayProfile.compact,
      < 840 => DisplayProfile.medium,
      _ => DisplayProfile.large,
    };
  }
}
