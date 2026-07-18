import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_info.freezed.dart';

@freezed
sealed class AuthInfo with _$AuthInfo {
  const factory AuthInfo({
    required int code,
    required String username,
    required int version,
    required String modulus,
    required String serverEphemeral,
    required String salt,
    required String srpSession,
  }) = _AuthInfo;
}
