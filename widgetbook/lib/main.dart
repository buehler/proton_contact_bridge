import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:proton_contact_bridge/ui/foundation/theme.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import 'main.directories.g.dart';
import 'preview/harness.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleFonts.pendingFonts([GoogleFonts.manrope()]);
  runApp(const WidgetbookApp());
}

@widgetbook.App()
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) => Widgetbook.material(
    directories: directories,
    appBuilder: (context, child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PreviewHost(
        key: ValueKey(WidgetbookState.of(context).path),
        child: child,
      ),
    ),
    addons: [
      MaterialThemeAddon(
        themes: [
          WidgetbookTheme(
            name: 'Dark',
            data: ThemeData(
              brightness: Brightness.dark,
              extensions: [kinCryptDarkTheme],
            ),
          ),
          WidgetbookTheme(
            name: 'Light',
            data: ThemeData(
              brightness: Brightness.light,
              extensions: [kinCryptLightTheme],
            ),
          ),
        ],
      ),
      ViewportAddon([
        IosViewports.iPhone13ProMax,
        ...IosViewports.all,
        ...MacosViewports.all,
        ...AndroidViewports.all,
        Viewports.none,
      ]),
    ],
  );
}
