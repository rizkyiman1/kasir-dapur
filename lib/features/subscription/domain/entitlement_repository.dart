import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';

abstract class EntitlementRepository {
  Future<List<Entitlement>> list(String businessId);

  Future<Entitlement?> find({
    required String businessId,
    required FeatureKey key,
  });
}
