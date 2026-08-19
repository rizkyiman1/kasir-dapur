import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';

final storeProfileProvider = FutureProvider<StoreProfile>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(storeRepositoryProvider).getByBusinessId(businessId);
});

final class StoreSettingsController {
  StoreSettingsController(this._ref);

  final Ref _ref;

  Future<StoreProfile> save(StoreProfilePatch patch) async {
    final String businessId = await _ref.read(activeBusinessIdProvider.future);
    final StoreProfile saved = await _ref
        .read(storeRepositoryProvider)
        .update(businessId: businessId, patch: patch);
    _ref.invalidate(storeProfileProvider);
    return saved;
  }

  Future<StoreProfile?> pickLogo() async {
    final String? path = await _ref.read(logoPickerProvider).pickImagePath();
    if (path == null || path.isEmpty) {
      return null;
    }
    final String businessId = await _ref.read(activeBusinessIdProvider.future);
    final StoreProfile saved = await _ref
        .read(storeRepositoryProvider)
        .saveLogo(businessId: businessId, sourcePath: path);
    _ref.invalidate(storeProfileProvider);
    return saved;
  }

  Future<StoreProfile> removeLogo() async {
    final String businessId = await _ref.read(activeBusinessIdProvider.future);
    final StoreProfile saved = await _ref
        .read(storeRepositoryProvider)
        .clearLogo(businessId);
    _ref.invalidate(storeProfileProvider);
    return saved;
  }
}

final storeSettingsControllerProvider = Provider<StoreSettingsController>((
  Ref ref,
) {
  return StoreSettingsController(ref);
});
