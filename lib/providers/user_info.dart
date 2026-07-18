import 'dart:convert';

import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/providers/storage.dart';
import 'package:proton_go_api_bridge/models/auth/auth_state.dart';
import 'package:proton_go_api_bridge/models/user/user_info.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_info.g.dart';

@riverpod
Stream<UserInfo> userInfo(Ref ref) async* {
  final api = await ref.watch(protonApiProvider.future);
  final store = ref.watch(sharedPreferencesProvider);
  yield* api.authStateStream.asyncMap((state) async {
    if (state is Authenticated) {
      if (await store.containsKey(StorageKeys.userInfo.key)) {
        final jsonString = await store.getString(StorageKeys.userInfo.key);
        return UserInfo.fromJson(jsonDecode(jsonString!));
      }

      final userInfo = await api.getUserInfo();
      await store.setString(
        StorageKeys.userInfo.key,
        jsonEncode(userInfo.toJson()),
      );
      return userInfo;
    }

    return UserInfo.empty();
  });
}
