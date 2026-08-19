import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan_snapshot.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_page.dart';

void main() {
  const AuthUser owner = AuthUser(
    id: 'o1',
    displayName: 'Budi',
    role: UserRole.owner,
  );

  testWidgets(
    'menampilkan paket, status, upgrade, riwayat, dan pulihkan hak akses',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final PlanSnapshot snapshot = PlanSnapshot(
        subscription: Subscription(
          id: 's1',
          businessId: 'b1',
          plan: Plan.free,
          planCode: BillingPlan.free,
          status: SubscriptionStatus.active,
          source: 'default',
          startsAt: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
        entitlements: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => SeededAuthController(user: owner),
            ),
            planSnapshotProvider.overrideWith((Ref ref) async => snapshot),
            featureGateProvider.overrideWith(
              (Ref ref) async => FeatureGate.forPlan(Plan.free),
            ),
          ],
          child: const MaterialApp(home: SubscriptionPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paket saat ini'), findsWidgets);
      expect(find.text('Free'), findsWidgets);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Tidak kedaluwarsa'), findsOneWidget);
      expect(find.text('Naikkan paket'), findsOneWidget);
      expect(find.text('Riwayat pembayaran'), findsOneWidget);
      expect(find.text('Belum ada riwayat pembayaran.'), findsOneWidget);
      expect(find.text('Pulihkan hak akses'), findsOneWidget);
      expect(find.text('Perbandingan fitur'), findsOneWidget);
      expect(find.text('Harga Resmi Paket'), findsOneWidget);
      expect(find.text('Free: Rp0'), findsOneWidget);
      expect(find.textContaining('Pro bulanan: Rp49.000'), findsOneWidget);
      expect(find.textContaining('Pro tahunan: Rp490.000'), findsOneWidget);
      expect(find.textContaining('Business bulanan: Rp99.000'), findsOneWidget);
      expect(
        find.textContaining('Business tahunan: Rp990.000'),
        findsOneWidget,
      );
      expect(find.text('Ajukan Pro bulanan'), findsOneWidget);
      expect(find.text('Segera Hadir (Business)'), findsOneWidget);
      expect(find.textContaining('tidak mengaktifkan paket'), findsOneWidget);
      expect(
        find.textContaining('Server Key Midtrans tidak disimpan'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Google Sheets'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Google Sheets'), findsOneWidget);
    },
  );
}
