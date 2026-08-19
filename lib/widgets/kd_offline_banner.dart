import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';

/// Banner offline yang muncul di bagian atas layar ketika koneksi mati.
///
/// Gunakan sebagai `body` wrapper:
/// ```dart
/// Column(children: [
///   const KdOfflineBanner(),
///   Expanded(child: mainContent),
/// ])
/// ```
class KdOfflineBanner extends ConsumerWidget {
  const KdOfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> status = ref.watch(connectivityProvider);
    // Selama loading/error asumsikan online agar tidak salah menampilkan banner.
    final bool online = status.valueOrNull ?? true;
    if (online) {
      return const SizedBox.shrink();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline · Data tersimpan lokal, sync otomatis saat online.',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Provider status konektivitas — cek sekali ke backend.
/// Widget yang butuh update berkala dapat memanggil `ref.invalidate(connectivityProvider)`.
/// Menggunakan [ConnectivityPort] yang sudah terdaftar di [providers.dart].
final connectivityProvider = FutureProvider.autoDispose<bool>((Ref ref) async {
  final port = ref.watch(connectivityPortProvider);
  try {
    return await port.isOnline();
  } on Object {
    return false;
  }
});
