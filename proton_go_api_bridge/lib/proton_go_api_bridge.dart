import 'dart:ffi' as ffi;

import 'package:proton_go_api_bridge/src/protobuf/proton/proton.pb.dart';

import 'src/bindings.g.dart';

void protobufTest() {
  GoByteBuffer? buffer;
  try {
    buffer = ExecThingy();
    if (buffer.data == ffi.nullptr || buffer.len == 0) {
      throw Exception('Failed to execute thingy');
    }
    final data = buffer.data.cast<ffi.Uint8>().asTypedList(buffer.len);
    print('Received data: $data');

    final fo = Foobar.fromBuffer(data);
    print(fo);
  } finally {
    if (buffer != null) {
      FreeByteBuffer(buffer);
    }
  }
}

// String nativeUpper(String input) {
//   final inputPtr = input.toNativeUtf8().cast<ffi.Char>();
//   ffi.Pointer<ffi.Char> outputPtr = ffi.nullptr;

//   try {
//     outputPtr = Upper(inputPtr);
//     if (outputPtr == ffi.nullptr) {
//       throw Exception('Failed to convert string to uppercase');
//     }
//     return outputPtr.cast<Utf8>().toDartString();
//   } finally {
//     malloc.free(inputPtr);
//     if (outputPtr != ffi.nullptr) {
//       FreeString(outputPtr);
//     }
//   }
// }
