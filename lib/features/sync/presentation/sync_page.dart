import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/presentation/entitlement_page.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/features/sync/presentation/sync_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_section_card.dart';

class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const EntitlementPage(
      feature: FeatureKey.googleSheetsSync,
      child: _SyncBody(),
    );
  }
}

class _SyncBody extends ConsumerWidget {
  const _SyncBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SyncSnapshot> snapshot = ref.watch(syncSnapshotProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sinkronisasi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.dashboard);
            }
          },
        ),
      ),
      body: snapshot.when(
        loading: () =>
            const KdLoadingView(message: 'Memuat status sinkronisasi...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Status sinkronisasi gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => ref.invalidate(syncSnapshotProvider),
          );
        },
        data: (SyncSnapshot data) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'SQLite adalah database transaksi utama. Google Sheets hanya '
                'laporan, cadangan, pemantauan, dan ekspor. Transaksi kasir '
                'tetap berjalan saat offline.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              KdSectionCard(child: _StatusBlock(data: data)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: data.status == SyncRunStatus.syncing
                        ? null
                        : () => unawaited(_run(context, ref)),
                    icon: const Icon(Icons.sync),
                    label: const Text('Sinkronkan sekarang'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        data.failedCount == 0 ||
                            data.status == SyncRunStatus.syncing
                        ? null
                        : () =>
                              unawaited(_run(context, ref, retryFailed: true)),
                    icon: const Icon(Icons.replay),
                    label: const Text('Coba lagi yang gagal'),
                  ),
                ],
              ),
              if (data.failedJobs.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Antrian gagal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...data.failedJobs.take(12).map((SyncJob job) {
                  return KdSectionCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(job.aggregate),
                      subtitle: Text(
                        job.lastError?.trim().isNotEmpty == true
                            ? job.lastError!
                            : 'Gagal dikirim. Data tetap di SQLite.',
                      ),
                      trailing: Text('${job.attempts}x'),
                    ),
                  );
                }),
              ],
              if (data.logs.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Log sinkronisasi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...data.logs.take(12).map((SyncLog log) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(log.message ?? log.status),
                    subtitle: Text(
                      DateFormatter.dateTimeId(
                        DateTime.fromMillisecondsSinceEpoch(log.createdAt),
                      ),
                    ),
                    trailing: Text(log.status),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref, {
    bool retryFailed = false,
  }) async {
    try {
      final SyncRunResult result = await ref
          .read(syncControllerProvider)
          .run(retryFailed: retryFailed);
      if (!context.mounted) {
        return;
      }
      context.showMessage(result.message ?? 'Sinkronisasi selesai.');
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      context.showMessage(ErrorHandler.userMessage(error));
    }
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.data});

  final SyncSnapshot data;

  @override
  Widget build(BuildContext context) {
    final String lastSync = data.lastSyncAt == null
        ? 'Belum pernah'
        : DateFormatter.dateTimeId(
            DateTime.fromMillisecondsSinceEpoch(data.lastSyncAt!),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status sinkronisasi',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(_statusLabel(data)),
        const SizedBox(height: 4),
        Text('Koneksi: ${data.online ? 'Online' : 'Offline'}'),
        Text('Terakhir sinkron: $lastSync'),
        const SizedBox(height: 12),
        Text('Menunggu: ${data.pendingCount}'),
        Text('Gagal: ${data.failedCount}'),
        Text('Selesai: ${data.doneCount}'),
        const SizedBox(height: 8),
        Text(
          'Tab salinan: Products, Transactions, TransactionItems, '
          'StockMovements, Expenses, Customers, DailyReports.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _statusLabel(SyncSnapshot data) {
    return switch (data.status) {
      SyncRunStatus.idle => 'Ada antrian menunggu dikirim.',
      SyncRunStatus.offline => 'Offline. Antrian menunggu koneksi.',
      SyncRunStatus.skipped => 'Paket belum mencakup Google Sheets.',
      SyncRunStatus.syncing => 'Sedang menyinkronkan...',
      SyncRunStatus.success => 'Tersinkron. SQLite tetap sumber data.',
      SyncRunStatus.failed => 'Ada antrian gagal. Data kasir tidak dihapus.',
    };
  }
}
