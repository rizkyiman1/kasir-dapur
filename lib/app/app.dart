import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/router.dart';
import 'package:kasir_dapur/app/theme/app_theme.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/settings/presentation/theme_controller.dart';
import 'package:kasir_dapur/features/sync/presentation/sync_scheduler.dart';
import 'package:kasir_dapur/services/settings_repository.dart';

class KasirDapurApp extends ConsumerWidget {
  const KasirDapurApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(syncSchedulerProvider);
    final AppThemePreference themePreference = ref.watch(
      themeControllerProvider,
    );
    final ThemeMode themeMode = switch (themePreference) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        unawaited(ref.read(authControllerProvider.notifier).onUserActivity());
      },
      child: MaterialApp.router(
        title: Brand.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    );
  }
}
