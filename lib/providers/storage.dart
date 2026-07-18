import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'storage.g.dart';

enum StorageKeys {
  userInfo('user_info'),
  contactSortOrder('contact_sort_order'),
  contactDisplayOrder('contact_display_order'),
  phoneCountryCode('phone_country_code'),
  themeMode('theme_mode');

  final String key;
  const StorageKeys(this.key);
}

@riverpod
SharedPreferencesAsync sharedPreferences(Ref ref) => SharedPreferencesAsync();
