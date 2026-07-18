import 'package:freezed_annotation/freezed_annotation.dart';

part 'two_factor_info.freezed.dart';
part 'two_factor_info.g.dart';

@freezed
sealed class TwoFactorInfo with _$TwoFactorInfo {
  const TwoFactorInfo._();

  const factory TwoFactorInfo({
    @JsonKey(name: 'Enabled') required int enabled,
  }) = _TwoFactorInfo;

  bool get hasTOTP => enabled & 1 == 1;
  bool get hasFIDO2 => enabled & 2 == 2;

  factory TwoFactorInfo.fromJson(Map<String, dynamic> json) =>
      _$TwoFactorInfoFromJson(json);
}
