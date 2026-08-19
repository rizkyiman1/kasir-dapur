import 'package:kasir_dapur/features/settings/domain/store_profile.dart';

abstract class StoreRepository {
  Future<StoreProfile> getByBusinessId(String businessId);

  Future<StoreProfile> update({
    required String businessId,
    required StoreProfilePatch patch,
  });

  Future<StoreProfile> saveLogo({
    required String businessId,
    required String sourcePath,
  });

  Future<StoreProfile> clearLogo(String businessId);
}
