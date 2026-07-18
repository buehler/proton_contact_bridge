import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:talker_flutter/talker_flutter.dart';

final talkerInstance = TalkerFlutter.init();

final class NativeLog extends TalkerLog {
  NativeLog(this.nativeLogLevel, String message)
    : super(
        message,
        title: 'native code | ${nativeLogLevel.name}',
        logLevel: switch (nativeLogLevel) {
          NativeLogLevel.debug => LogLevel.debug,
          NativeLogLevel.info => LogLevel.info,
          NativeLogLevel.warn => LogLevel.warning,
          NativeLogLevel.error => LogLevel.error,
        },
        pen: switch (nativeLogLevel) {
          NativeLogLevel.debug => AnsiPen()..gray(),
          NativeLogLevel.info => AnsiPen()..blue(),
          NativeLogLevel.warn => AnsiPen()..yellow(),
          NativeLogLevel.error => AnsiPen()..red(),
        },
      );

  final NativeLogLevel nativeLogLevel;
}

late final NativeLoggerCallback nativeLoggerCallback;

void installNativeLogger() {
  nativeLoggerCallback = NativeLoggerCallback((level, message) {
    talkerInstance.logCustom(NativeLog(level, message));
  });
}
