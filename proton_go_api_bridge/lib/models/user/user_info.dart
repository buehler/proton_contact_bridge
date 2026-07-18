import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_info.freezed.dart';
part 'user_info.g.dart';

@freezed
sealed class UserInfo with _$UserInfo {
  const factory UserInfo({
    required String id,
    required String email,
    required String username,
    required String displayname,
  }) = _UserInfo;

  factory UserInfo.empty() =>
      UserInfo(id: 'n/a', email: 'n/a', username: 'n/a', displayname: 'n/a');

  factory UserInfo.fromJson(Map<String, dynamic> json) =>
      _$UserInfoFromJson(json);
}
