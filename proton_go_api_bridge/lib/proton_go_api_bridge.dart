import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import 'src/bindings.g.dart';

export 'src/bindings.g.dart';

String nativeUpper(String input) {
  final inputPtr = input.toNativeUtf8().cast<ffi.Char>();
  ffi.Pointer<ffi.Char> outputPtr = ffi.nullptr;

  try {
    outputPtr = Upper(inputPtr);
    if (outputPtr == ffi.nullptr) {
      throw Exception('Failed to convert string to uppercase');
    }
    return outputPtr.cast<Utf8>().toDartString();
  } finally {
    malloc.free(inputPtr);
    if (outputPtr != ffi.nullptr) {
      FreeString(outputPtr);
    }
  }
}
