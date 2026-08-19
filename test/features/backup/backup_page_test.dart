import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';
import 'package:kasir_dapur/features/backup/presentation/backup_controller.dart';
import 'package:kasir_dapur/features/backup/presentation/backup_page.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';

void main() {
  const AuthUser owner = AuthUser(
    id: 'o1',
    displayName: 'Budi',
    role: UserRole.owner,
  );

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets(
    'menampilkan Backup Now, Last Backup, status, dan konfirmasi Restore',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => SeededAuthController(user: owner),
            ),
            featureGateProvider.overrideWith(
              (Ref ref) async => FeatureGate.forPlan(Plan.pro),
            ),
            backupUiSnapshotProvider.overrideWith(
              (Ref ref) async => const BackupUiSnapshot(
                status: BackupStatus.success,
                lastBackupAt: 1755514800000,
                lastBackupId: 'bak-1',
                lastMessage:
                    'Cadangan tersimpan. SQLite tetap database transaksi.',
                online: true,
              ),
            ),
          ],
          child: const MaterialApp(home: BackupPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backup Now'), findsOneWidget);
      expect(find.textContaining('Last Backup'), findsOneWidget);
      expect(find.text('Backup Status'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.textContaining('cadangan gagal'), findsOneWidget);

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Pulihkan cadangan?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Pulihkan cadangan?'), findsNothing);
      expect(find.text('Backup Now'), findsOneWidget);
    },
  );
}
