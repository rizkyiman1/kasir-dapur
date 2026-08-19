enum BillingCycle { none, monthly, yearly }

enum PlanFamily { free, pro, business }

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

  PlanFamily get family {
    return switch (this) {
      BillingPlan.free => PlanFamily.free,
      BillingPlan.proMonthly || BillingPlan.proYearly => PlanFamily.pro,
      BillingPlan.businessMonthly ||
      BillingPlan.businessYearly => PlanFamily.business,
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

  int get periodDays {
    return switch (cycle) {
      BillingCycle.none => 0,
      BillingCycle.monthly => 30,
      BillingCycle.yearly => 365,
    };
  }

  static BillingPlan parse(String value) {
    final String normalized = value.trim();
    for (final BillingPlan plan in BillingPlan.values) {
      if (plan.storageValue == normalized || plan.name == normalized) {
        return plan;
      }
    }
    throw FormatException('Kode paket tidak dikenal: $value');
  }
}
