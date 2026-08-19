import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/services/settings_repository.dart';

final class ThemeController extends Notifier<AppThemePreference> {
  @override
  AppThemePreference build() => AppThemePreference.system;

  Future<void> restore() async {
    final AppThemePreference preference = await ref
        .read(settingsRepositoryProvider)
        .readTheme();
    state = preference;
  }

  Future<void> setPreference(AppThemePreference preference) async {
    state = preference;
    await ref.read(settingsRepositoryProvider).writeTheme(preference);
  }

  ThemeMode get themeMode {
    return switch (state) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemePreference>(ThemeController.new);
