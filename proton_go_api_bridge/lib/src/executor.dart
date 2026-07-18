import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:proton_go_api_bridge/src/bindings.g.dart';
import 'package:proton_go_api_bridge/src/protobuf/bridge/bridge.pb.dart';

Future<Result> executeCommand(Command command) async {
  final commandBytes = command.writeToBuffer();

  final resultBytes = await Isolate.run(() {
    return using((Arena arena) {
      final commandBuffer = arena<GoByteBuffer>();
      final nativeDataPtr = arena<ffi.UnsignedChar>(commandBytes.length);

      nativeDataPtr
          .cast<ffi.Uint8>()
          .asTypedList(commandBytes.length)
          .setAll(0, commandBytes);

      commandBuffer.ref
        ..data = nativeDataPtr
        ..len = commandBytes.length;

      final resultBuffer = ExecuteCommand(commandBuffer.ref);

      try {
        if (resultBuffer.data == ffi.nullptr || resultBuffer.len == 0) {
          throw Exception('Failed to execute command');
        }

        return Uint8List.fromList(
          resultBuffer.data.cast<ffi.Uint8>().asTypedList(resultBuffer.len),
        );
      } finally {
        FreeByteBuffer(resultBuffer);
      }
    });
  });

  final result = Result.fromBuffer(resultBytes);
  if (result.hasError()) {
    throw ApiException(result.error.message);
  }
  return result;
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => 'ApiException: $message';
}
