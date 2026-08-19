import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';

enum BillingCycle { none, monthly, yearly }

/// SKU langganan. Berbeda dari [Plan] (keluarga fitur Free/Pro/Business).
enum BillingPlan {
  free,
  proMonthly,
  proYearly,
  businessMonthly,
  businessYearly;

  String get storageValue {
    return switch (this) {
      BillingPlan.free => 'FREE',
      BillingPlan.proMonthly => 'PRO_MONTHLY',
      BillingPlan.proYearly => 'PRO_YEARLY',
      BillingPlan.businessMonthly => 'BUSINESS_MONTHLY',
      BillingPlan.businessYearly => 'BUSINESS_YEARLY',
    };
  }

  String get label {
    return switch (this) {
      BillingPlan.free => 'Free',
      BillingPlan.proMonthly => 'Pro bulanan',
      BillingPlan.proYearly => 'Pro tahunan',
      BillingPlan.businessMonthly => 'Business bulanan',
      BillingPlan.businessYearly => 'Business tahunan',
    };
  }

  Plan get family {
    return switch (this) {
      BillingPlan.free => Plan.free,
      BillingPlan.proMonthly || BillingPlan.proYearly => Plan.pro,
      BillingPlan.businessMonthly ||
      BillingPlan.businessYearly => Plan.business,
    };
  }

  BillingCycle get cycle {
    return switch (this) {
      BillingPlan.free => BillingCycle.none,
      BillingPlan.proMonthly ||
      BillingPlan.businessMonthly => BillingCycle.monthly,
      BillingPlan.proYearly ||
      BillingPlan.businessYearly => BillingCycle.yearly,
    };
  }

  bool get isPaid => this != BillingPlan.free;

  static BillingPlan fromFamily(Plan plan) {
    return switch (plan) {
      Plan.free => BillingPlan.free,
      Plan.pro => BillingPlan.proMonthly,
      Plan.business => BillingPlan.businessMonthly,
    };
  }

  static BillingPlan parse(String value) {
    final String normalized = value.trim();
    for (final BillingPlan plan in BillingPlan.values) {
      if (plan.storageValue == normalized || plan.name == normalized) {
        return plan;
      }
    }
    throw ValidationException('Kode paket tidak dikenal: $value');
  }
}
