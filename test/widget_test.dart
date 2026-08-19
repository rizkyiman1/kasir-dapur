import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/app/app.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/domain/session.dart';

import 'helpers/fakes.dart';

List<Override> _overrides({
  required FakeAuthRepository auth,
  FakeSessionRepository? sessions,
}) {
  return [
    authRepositoryProvider.overrideWithValue(auth),
    sessionRepositoryProvider.overrideWithValue(
      sessions ?? FakeSessionRepository(),
    ),
    settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
    sessionConfigProvider.overrideWithValue(
      const SessionConfig(checkInterval: Duration(days: 1)),
    ),
  ];
}

void main() {
  testWidgets('Splash menampilkan identitas lalu ke onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(auth: FakeAuthRepository()),
        child: const KasirDapurApp(),
      ),
    );

    expect(find.text(Brand.appName), findsWidgets);
    expect(find.text(Brand.tagline), findsOneWidget);

    await tester.pump(
      const Duration(milliseconds: AppConstants.splashMinDurationMs + 50),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selamat datang'), findsOneWidget);
    expect(find.text('Lanjutkan'), findsOneWidget);
  });

  testWidgets('Login tampil jika akun lokal sudah ada', (tester) async {
    final FakeAuthRepository auth = FakeAuthRepository(
      user: const AuthUser(id: '1', displayName: 'Budi', role: UserRole.owner),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(auth: auth),
        child: const KasirDapurApp(),
      ),
    );

    await tester.pump(
      const Duration(milliseconds: AppConstants.splashMinDurationMs + 50),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masuk ke ${Brand.appName}'), findsOneWidget);
  });
}
