import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/features/auth/domain/auth_state.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/sync/presentation/sync_controller.dart';

/// Menyinkronkan antrian saat online. Transaksi lokal tidak menunggu hasil ini.
final class SyncScheduler {
  SyncScheduler(this._ref) {
    _timer = Timer.periodic(AppConstants.syncPollInterval, (_) {
      unawaited(flush());
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(flush());
      },
    );
  }

  final Ref _ref;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _busy = false;

  Future<void> flush() async {
    if (_busy) {
      return;
    }
    if (!_ref.read(authControllerProvider).isAuthenticated) {
      return;
    }
    _busy = true;
    try {
      final String businessId = await _ref.read(
        activeBusinessIdProvider.future,
      );
      await _ref.read(syncEngineProvider).run(businessId: businessId);
      _ref.invalidate(syncSnapshotProvider);
    } on Object {
      // Antrian tetap di SQLite. Percobaan berikutnya menunggu interval.
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
  }
}

final syncSchedulerProvider = Provider<SyncScheduler>((Ref ref) {
  final SyncScheduler scheduler = SyncScheduler(ref);
  ref.listen(authControllerProvider, (AuthState? previous, AuthState next) {
    if (next.isAuthenticated) {
      unawaited(scheduler.flush());
    }
  });
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
