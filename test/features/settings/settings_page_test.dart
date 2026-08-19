import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/settings/domain/legal_documents.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';
import 'package:kasir_dapur/features/settings/presentation/settings_controller.dart';
import 'package:kasir_dapur/features/settings/presentation/settings_page.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan_snapshot.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';

void main() {
  const AuthUser owner = AuthUser(
    id: 'o1',
    displayName: 'Budi',
    role: UserRole.owner,
  );

  testWidgets('pengaturan menampilkan usaha, printer, POS, user, legal resmi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => SeededAuthController(user: owner),
          ),
          storeProfileProvider.overrideWith(
            (Ref ref) async => const StoreProfile(
              id: 'biz-1',
              name: 'Warung Dapur Rasa',
              address: 'Depok',
              phone: '02112345678',
              receiptFooter: 'Terima kasih',
              defaultPayment: PaymentMethod.cash,
              receiptBehavior: ReceiptBehavior.ask,
            ),
          ),
          planSnapshotProvider.overrideWith(
            (Ref ref) async => PlanSnapshot(
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
            ),
          ),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BUSINESS'), findsOneWidget);
    expect(find.text('Warung Dapur Rasa'), findsWidgets);
    expect(find.text('PRINTER'), findsOneWidget);
    expect(find.text('Printer'), findsWidgets);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Default payment'), findsOneWidget);
    expect(find.text('Negative stock'), findsOneWidget);
    expect(find.text('Receipt behavior'), findsOneWidget);
    expect(find.text('USER'), findsOneWidget);
    expect(find.text('PIN'), findsWidgets);
    expect(find.text('Owner, Admin, Cashier'), findsOneWidget);
    expect(find.text('Permission'), findsOneWidget);
    expect(find.text('SUBSCRIPTION'), findsOneWidget);
    expect(find.text('BACKUP'), findsOneWidget);
    expect(find.text('Backup'), findsWidgets);
    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('PRIVACY'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Data & Keamanan'), findsOneWidget);
    expect(find.text('Cara Menggunakan Aplikasi'), findsOneWidget);
    expect(find.text('Hapus Akun'), findsWidgets);
    expect(find.text('Support & Kontak'), findsOneWidget);
    expect(find.text('LEGAL'), findsOneWidget);
    expect(find.text(Brand.appName), findsWidgets);
    expect(find.text(Brand.companyName), findsOneWidget);
    expect(find.text(Brand.ownerName), findsWidgets);
    expect(find.text(Brand.websiteHost), findsWidgets);
    expect(find.text('example.com'), findsNothing);
    expect(find.textContaining('lorem'), findsNothing);

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text(LegalDocuments.privacyTitle), findsWidgets);
    expect(find.textContaining(Brand.companyName), findsWidgets);
  });
}
