import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:proton_go_api_bridge/src/protobuf/bridge/bridge.pb.dart';

import 'src/bindings.g.dart';

export 'src/protobuf/bridge/bridge.pb.dart';
export 'src/protobuf/commands/commands.pb.dart';
export 'src/protobuf/results/results.pb.dart';

Future<Result> executeCommand(Command command) async {
  // TODO: maybe use isolate.compute here
  final result = using((Arena arena) {
    final commandBytes = command.writeToBuffer();
    final commandBuffer = arena<GoByteBuffer>();
    final nativeDataPtr = arena<ffi.UnsignedChar>(commandBytes.length);
    nativeDataPtr
        .cast<ffi.Uint8>()
        .asTypedList(commandBytes.length)
        .setAll(0, commandBytes);
    commandBuffer.ref.data = nativeDataPtr;
    commandBuffer.ref.len = commandBytes.length;

    final resultBuffer = ExecuteCommand(commandBuffer.ref);
    try {
      if (resultBuffer.data == ffi.nullptr || resultBuffer.len == 0) {
        throw Exception('Failed to execute command');
      }
      final resultData = resultBuffer.data.cast<ffi.Uint8>().asTypedList(
        resultBuffer.len,
      );
      return Result.fromBuffer(resultData);
    } finally {
      FreeByteBuffer(resultBuffer);
    }
  });
  return result;
}
