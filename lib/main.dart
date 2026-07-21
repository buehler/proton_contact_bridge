import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleFonts.pendingFonts([
    GoogleFonts.hankenGrotesk(),
    GoogleFonts.inter(),
    GoogleFonts.jetBrainsMono(),
  ]);
  runApp(const ProviderScope(child: ProtonContactBridgeApp()));
}

class ProtonContactBridgeApp extends ConsumerWidget {
  const ProtonContactBridgeApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(protonAuthProvider);
    return MaterialApp.router(
      title: 'Flutter Demo',
      theme: FlexThemeData.light(scheme: FlexScheme.aquaBlue),
      darkTheme: FlexThemeData.dark(scheme: FlexScheme.aquaBlue),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
