import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';
import 'package:kasir_dapur/features/backup/presentation/backup_controller.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/presentation/entitlement_page.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_section_card.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const EntitlementPage(
      feature: FeatureKey.cloudBackup,
      child: _BackupBody(),
    );
  }
}

class _BackupBody extends ConsumerWidget {
  const _BackupBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BackupUiSnapshot> snapshot = ref.watch(
      backupUiSnapshotProvider,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadangan cloud'),
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
            const KdLoadingView(message: 'Memuat status cadangan...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Status cadangan gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => ref.invalidate(backupUiSnapshotProvider),
          );
        },
        data: (BackupUiSnapshot data) {
          final bool busy =
              data.status == BackupStatus.backingUp ||
              data.status == BackupStatus.restoring;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Cadangan menyalin data usaha ke server Kasir Dapur. '
                'SQLite tetap database transaksi. Jika cadangan gagal, '
                'kasir tetap dapat digunakan.',
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
                    onPressed: busy
                        ? null
                        : () => unawaited(_backupNow(context, ref)),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Backup Now'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || data.lastBackupId == null
                        ? null
                        : () => unawaited(
                            _confirmRestore(context, ref, data.lastBackupId!),
                          ),
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore'),
                  ),
                ],
              ),
              if (data.remote.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Cadangan di server',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...data.remote.take(8).map((RemoteBackupInfo row) {
                  return KdSectionCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(row.id),
                      subtitle: Text(
                        DateFormatter.dateTimeId(
                          DateTime.fromMillisecondsSinceEpoch(row.createdAt),
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                _confirmRestore(context, ref, row.id),
                              ),
                        child: const Text('Restore'),
                      ),
                    ),
                  );
                }),
              ],
              if (data.logs.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Riwayat cadangan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...data.logs.take(12).map((BackupLog log) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(log.message ?? log.status),
                    subtitle: Text(
                      DateFormatter.dateTimeId(
                        DateTime.fromMillisecondsSinceEpoch(log.createdAt),
                      ),
                    ),
                    trailing: Text(log.direction),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    try {
      final BackupRunResult result = await ref
          .read(backupControllerProvider)
          .backupNow();
      if (!context.mounted) {
        return;
      }
      context.showMessage(result.message ?? 'Cadangan selesai.');
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      context.showMessage(ErrorHandler.userMessage(error));
    }
  }

  Future<void> _confirmRestore(
    BuildContext context,
    WidgetRef ref,
    String backupId,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Pulihkan cadangan?'),
          content: const Text(
            'Restore menimpa baris dengan id yang sama di SQLite. '
            'Transaksi lokal yang lebih baru tidak dihapus. '
            'Kasir tetap dapat digunakan. Tindakan ini membutuhkan konfirmasi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Pulihkan'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final BackupRunResult result = await ref
          .read(backupControllerProvider)
          .restore(backupId: backupId, confirmed: true);
      if (!context.mounted) {
        return;
      }
      context.showMessage(result.message ?? 'Pemulihan selesai.');
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

  final BackupUiSnapshot data;

  @override
  Widget build(BuildContext context) {
    final String last = data.lastBackupAt == null
        ? 'Belum pernah'
        : DateFormatter.dateTimeId(
            DateTime.fromMillisecondsSinceEpoch(data.lastBackupAt!),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Backup Status', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(_statusLabel(data.status)),
        Text('Koneksi: ${data.online ? 'Online' : 'Offline'}'),
        const SizedBox(height: 8),
        Text('Last Backup: $last'),
        if (data.lastBackupId != null) Text('ID: ${data.lastBackupId}'),
        if (data.lastMessage != null) ...[
          const SizedBox(height: 8),
          Text(data.lastMessage!),
        ],
        const SizedBox(height: 8),
        Text(
          'Isi cadangan: products, transactions, transaction_items, '
          'stock, stock_movements, expenses, customers, settings.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      BackupStatus.idle => 'Siap membuat cadangan.',
      BackupStatus.backingUp => 'Sedang mencadangkan...',
      BackupStatus.restoring => 'Sedang memulihkan...',
      BackupStatus.success => 'Cadangan terakhir berhasil.',
      BackupStatus.failed => 'Cadangan terakhir gagal. Kasir tetap jalan.',
      BackupStatus.skipped => 'Paket belum mencakup cadangan cloud.',
      _ => status,
    };
  }
}
