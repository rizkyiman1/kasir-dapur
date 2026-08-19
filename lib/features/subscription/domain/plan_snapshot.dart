import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_payment.dart';

final class PlanSnapshot {
  const PlanSnapshot({
    required this.subscription,
    required this.entitlements,
    this.pending,
    this.payments = const <SubscriptionPayment>[],
  });

  final Subscription subscription;
  final List<Entitlement> entitlements;
  final Subscription? pending;
  final List<SubscriptionPayment> payments;

  Plan get plan => subscription.plan;
}
