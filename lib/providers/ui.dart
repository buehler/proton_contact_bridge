import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/providers/storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ui.g.dart';

@riverpod
final class ThemeNotifier extends _$ThemeNotifier {
  @override
  Future<ThemeMode> build() async {
    final storedValue = await ref
        .watch(sharedPreferencesProvider)
        .getString(StorageKeys.themeMode.key);

    return ThemeMode.values.firstWhere(
      (mode) => mode.name == storedValue,
      orElse: () => ThemeMode.system,
    );
  }

  ThemeMode get mode => state.value ?? ThemeMode.dark;

  Future<void> setMode(ThemeMode mode) async {
    final previous = state.requireValue;
    state = AsyncData(mode);

    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(StorageKeys.themeMode.key, mode.name);
    } catch (_) {
      if (state.value == mode) {
        state = AsyncData(previous);
      }
      rethrow;
    }
  }

  Future<void> toggle() => setMode(switch (mode) {
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.light,
    ThemeMode.system => ThemeMode.light,
  });
}
