import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../design/ds_typography_scale.dart';

// ============================================================================
// App Preferences — persisted with flutter_secure_storage
// Manages: dark mode, text scale (A / A+ / A++)
// ============================================================================

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
const _kDarkMode   = 'pref_dark_mode';
const _kTextScale  = 'pref_text_scale';

class AppPreferences {
  final bool darkMode;
  final DsTextScale textScale;

  const AppPreferences({
    this.darkMode  = false,
    this.textScale = DsTextScale.medium,
  });

  AppPreferences copyWith({bool? darkMode, DsTextScale? textScale}) =>
      AppPreferences(
        darkMode:  darkMode  ?? this.darkMode,
        textScale: textScale ?? this.textScale,
      );

  ThemeMode get themeMode => darkMode ? ThemeMode.dark : ThemeMode.light;
}

class AppPreferencesNotifier extends AsyncNotifier<AppPreferences> {
  @override
  Future<AppPreferences> build() async {
    final dark  = await _storage.read(key: _kDarkMode);
    final scale = await _storage.read(key: _kTextScale);
    return AppPreferences(
      darkMode:  dark == 'true',
      textScale: DsTextScaleX.fromIndex(int.tryParse(scale ?? '1') ?? 1),
    );
  }

  Future<void> setDarkMode(bool value) async {
    await _storage.write(key: _kDarkMode, value: value.toString());
    state = AsyncData(state.value!.copyWith(darkMode: value));
  }

  Future<void> setTextScale(DsTextScale scale) async {
    await _storage.write(key: _kTextScale, value: scale.storageIndex.toString());
    state = AsyncData(state.value!.copyWith(textScale: scale));
  }
}

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesNotifier, AppPreferences>(
  AppPreferencesNotifier.new,
);

// ─── Convenience selector providers ──────────────────────────────────────────

final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(appPreferencesProvider).value?.darkMode ?? false;
});

final textScaleProvider = Provider<DsTextScale>((ref) {
  return ref.watch(appPreferencesProvider).value?.textScale ?? DsTextScale.medium;
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  final dark = ref.watch(isDarkModeProvider);
  return dark ? ThemeMode.dark : ThemeMode.light;
});
