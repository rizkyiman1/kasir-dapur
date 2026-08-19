import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/features/sync/presentation/sync_controller.dart';
import 'package:kasir_dapur/features/sync/presentation/sync_page.dart';

void main() {
  const AuthUser owner = AuthUser(
    id: 'o1',
    displayName: 'Budi',
    role: UserRole.owner,
  );

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('menampilkan status, last sync, dan tombol manual/retry', (
    tester,
  ) async {
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
          syncSnapshotProvider.overrideWith(
            (Ref ref) async => const SyncSnapshot(
              status: SyncRunStatus.failed,
              pendingCount: 2,
              failedCount: 1,
              doneCount: 4,
              lastSyncAt: 1755514800000,
              online: true,
              failedJobs: <SyncJob>[
                SyncJob(
                  id: 'j1',
                  businessId: 'b1',
                  clientUuid: 'c1',
                  aggregate: 'transaction',
                  operation: 'upsert',
                  payload: '{"id":"t1"}',
                  status: SyncJobStatus.failed,
                  attempts: 2,
                  lastError: 'Server tidak tersedia.',
                  createdAt: 1,
                  updatedAt: 1,
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: SyncPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sinkronisasi'), findsWidgets);
    expect(
      find.textContaining('SQLite adalah database transaksi utama'),
      findsOneWidget,
    );
    expect(find.text('Sinkronkan sekarang'), findsOneWidget);
    expect(find.text('Coba lagi yang gagal'), findsOneWidget);
    expect(find.textContaining('Menunggu: 2'), findsOneWidget);
    expect(find.textContaining('Gagal: 1'), findsOneWidget);
    expect(find.text('Antrian gagal'), findsOneWidget);
    expect(find.textContaining('DailyReports'), findsOneWidget);
  });
}
