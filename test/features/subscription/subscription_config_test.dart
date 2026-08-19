import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/money/money.dart';
import 'package:kasir_dapur/features/subscription/data/http_billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';

void main() {
  test('SKU dan status sesuai kontrak billing', () {
    expect(
      BillingPlan.values.map((BillingPlan p) => p.storageValue).toList(),
      <String>[
        'FREE',
        'PRO_MONTHLY',
        'PRO_YEARLY',
        'BUSINESS_MONTHLY',
        'BUSINESS_YEARLY',
      ],
    );
    expect(
      SubscriptionStatus.values.map((SubscriptionStatus s) => s.storageValue),
      containsAll(<String>[
        'active',
        'pending',
        'expired',
        'cancelled',
        'grace_period',
      ]),
    );
    expect(BillingPlan.proYearly.family.name, 'pro');
    expect(BillingPlan.businessMonthly.family.name, 'business');
  });

  test('harga hanya dibaca dari SubscriptionConfig', () {
    expect(
      SubscriptionConfig.standard.priceLabel(BillingPlan.proMonthly),
      Money(49000).formatId(),
    );
    expect(
      SubscriptionConfig.standard.amountRupiah(BillingPlan.proYearly),
      490000,
    );
    expect(
      SubscriptionConfig.standard.amountRupiah(BillingPlan.businessMonthly),
      99000,
    );
    expect(
      SubscriptionConfig.standard.amountRupiah(BillingPlan.businessYearly),
      990000,
    );
    const SubscriptionConfig priced = SubscriptionConfig(
      gracePeriodDays: 7,
      offers: <PlanOffer>[
        PlanOffer(planCode: BillingPlan.free, periodDays: 0, priceRupiah: 0),
        PlanOffer(
          planCode: BillingPlan.proMonthly,
          periodDays: 30,
          priceRupiah: 99000,
        ),
        PlanOffer(planCode: BillingPlan.proYearly, periodDays: 365),
        PlanOffer(planCode: BillingPlan.businessMonthly, periodDays: 30),
        PlanOffer(planCode: BillingPlan.businessYearly, periodDays: 365),
      ],
    );
    expect(priced.amountRupiah(BillingPlan.proMonthly), 99000);
    expect(priced.priceLabel(BillingPlan.proMonthly), Money(99000).formatId());
    expect(
      priced.priceLabel(BillingPlan.businessYearly),
      'Harga: menyusul konfigurasi bisnis',
    );
  });

  test('klien HTTP billing tidak membawa Server Key Midtrans', () {
    expect(HttpBillingGateway.clientHeaders.containsKey('Server-Key'), isFalse);
    expect(
      HttpBillingGateway.clientHeaders.containsKey('X-Server-Key'),
      isFalse,
    );
    expect(HttpBillingGateway.clientHeaders['Authorization'], isNull);
    expect(
      HttpBillingGateway.clientHeaders['Content-Type'],
      'application/json',
    );
  });
}
