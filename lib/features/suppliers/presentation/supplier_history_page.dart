import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier.dart';
import 'package:kasir_dapur/features/suppliers/presentation/suppliers_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_section_card.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

class SupplierHistoryPage extends ConsumerWidget {
  const SupplierHistoryPage({super.key, required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ContactHistoryEntry>> history = ref.watch(
      supplierHistoryProvider(supplier.id),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('History · ${supplier.name}'),
        actions: [
          IconButton(
            tooltip: 'Tambah catatan',
            onPressed: () => unawaited(_addNote(context, ref)),
            icon: const Icon(Icons.note_add_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          KdSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (supplier.contact != null) Text(supplier.contact!),
                if (supplier.address != null) Text(supplier.address!),
                const SizedBox(height: 8),
                Text(
                  'ID: ${supplier.id}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Riwayat', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          history.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: KdLoadingView(message: 'Memuat riwayat...'),
            ),
            error: (Object error, StackTrace _) {
              return KdErrorState(
                title: 'Riwayat gagal dimuat',
                subtitle: ErrorHandler.userMessage(error),
                onRetry: () =>
                    ref.invalidate(supplierHistoryProvider(supplier.id)),
              );
            },
            data: (List<ContactHistoryEntry> items) {
              if (items.isEmpty) {
                return const KdEmptyState(
                  icon: Icons.history,
                  title: 'Belum ada riwayat',
                  subtitle:
                      'Perubahan data dan catatan usaha akan tercatat di sini.',
                );
              }
              return Column(
                children: [
                  for (final ContactHistoryEntry row in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(row.summary),
                      subtitle: Text(
                        DateFormatter.dateTimeId(
                          DateTime.fromMillisecondsSinceEpoch(row.createdAt),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const KdLegalFooter(),
        ],
      ),
    );
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final TextEditingController note = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Catatan riwayat'),
          content: KdTextField(
            label: 'Catatan',
            controller: note,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            hint: 'Catatan usaha, bukan data pribadi',
            validator: AppValidators.required,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(note.text.trim()),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    note.dispose();
    if (value == null || value.isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(supplierControllerProvider)
          .addNote(supplierId: supplier.id, note: value);
      if (context.mounted) {
        context.showMessage('Catatan riwayat disimpan.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        context.showMessage(ErrorHandler.userMessage(error));
      }
    }
  }
}
