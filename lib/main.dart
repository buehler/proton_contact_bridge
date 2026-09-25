import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart' as dart_log;
import 'package:proton_contact_bridge/logger.dart';
import 'package:proton_contact_bridge/providers/invalidation.dart';
import 'package:proton_contact_bridge/providers/sync.dart';
import 'package:proton_contact_bridge/providers/ui.dart';
import 'package:proton_contact_bridge/providers/wakelock.dart';
import 'package:proton_contact_bridge/router.dart';
import 'package:proton_contact_bridge/ui/foundation/theme.dart';
import 'package:proton_contact_bridge/utils.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart'
    show initializeNativePlatform;
import 'package:talker_flutter/talker_flutter.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger_observer.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNativePlatform();
  dart_log.Logger.root.level = dart_log.Level.ALL;
  dart_log.Logger.root.onRecord.listen((record) {
    if (record.level >= dart_log.Level.SEVERE) {
      talkerInstance.handle(
        record.error ?? Object(),
        record.stackTrace,
        record.message,
      );
    } else {
      talkerInstance.log(
        record.message,
        logLevel: switch (record.level) {
          dart_log.Level.INFO => LogLevel.info,
          dart_log.Level.WARNING => LogLevel.warning,
          dart_log.Level.SEVERE => LogLevel.error,
          dart_log.Level.FINE => LogLevel.debug,
          _ => LogLevel.verbose,
        },
        exception: record.error,
        stackTrace: record.stackTrace,
      );
    }
  });
  installNativeLogger();

  try {
    await initializePhoneNumberFormatting();
  } catch (error, stackTrace) {
    talkerInstance.log(
      'Phone number formatting initialization failed.',
      logLevel: LogLevel.warning,
      exception: error,
      stackTrace: stackTrace,
    );
  }

  await GoogleFonts.pendingFonts([GoogleFonts.manrope()]);

  runApp(
    ProviderScope(
      observers: [
        TalkerRiverpodObserver(
          talker: talkerInstance,
          settings: const TalkerRiverpodLoggerSettings(
            printStateFullData: false,
          ),
        ),
      ],
      child: const ProtonContactBridgeApp(),
    ),
  );
}

class ProtonContactBridgeApp extends ConsumerWidget {
  const ProtonContactBridgeApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(wakelockProvider);
    ref.watch(syncStatusProviderInvalidationProvider);
    ref.watch(syncTriggerProvider);

    return MaterialApp.router(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      themeMode: ref.watch(themeProvider).value ?? ThemeMode.dark,
      theme: ThemeData(extensions: [kinCryptLightTheme]),
      darkTheme: ThemeData(extensions: [kinCryptDarkTheme]),
    );
  }
}
