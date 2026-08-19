import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/cash_management/domain/cash.dart';
import 'package:kasir_dapur/features/cash_management/presentation/cash_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_section_card.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

class CashManagementPage extends ConsumerWidget {
  const CashManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CashDrawerSnapshot?> drawer = ref.watch(
      cashDrawerProvider,
    );
    final AsyncValue<List<CashSession>> closed = ref.watch(
      cashClosedSessionsProvider,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ),
      body: drawer.when(
        skipLoadingOnReload: true,
        loading: () => const KdLoadingView(message: 'Memuat sesi kas...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Sesi kas gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => ref.invalidate(cashDrawerProvider),
          );
        },
        data: (CashDrawerSnapshot? snapshot) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (snapshot == null)
                const _OpenCashierCard()
              else
                _OpenSessionCard(snapshot: snapshot),
              const SizedBox(height: 20),
              Text(
                'Closing report',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              closed.maybeWhen(
                data: (List<CashSession> rows) {
                  if (rows.isEmpty) {
                    return Text(
                      'Belum ada laporan tutup kas.',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  }
                  return Column(
                    children: [
                      for (final CashSession row in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ClosedReportCard(session: row),
                        ),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              const KdLegalFooter(),
            ],
          );
        },
      ),
    );
  }
}

class _OpenCashierCard extends ConsumerStatefulWidget {
  const _OpenCashierCard();

  @override
  ConsumerState<_OpenCashierCard> createState() => _OpenCashierCardState();
}

class _OpenCashierCardState extends ConsumerState<_OpenCashierCard> {
  final TextEditingController _opening = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Open cashier', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Saldo awal laci. Penjualan non-tunai tidak masuk kas.'),
          const SizedBox(height: 12),
          KdTextField(
            label: 'Opening balance',
            controller: _opening,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (String? value) =>
                AppValidators.rupiahInteger(value, requiredField: true),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : () => unawaited(_open()),
            child: const Text('Open cashier'),
          ),
        ],
      ),
    );
  }

  Future<void> _open() async {
    final String? error = AppValidators.rupiahInteger(_opening.text);
    if (error != null) {
      context.showMessage(error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(cashControllerProvider)
          .open(openingAmount: AppValidators.parseRupiah(_opening.text));
      if (mounted) {
        context.showMessage('Kasir dibuka.');
      }
    } on Object catch (error) {
      if (mounted) {
        context.showMessage(ErrorHandler.userMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _OpenSessionCard extends ConsumerWidget {
  const _OpenSessionCard({required this.snapshot});

  final CashDrawerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KdSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sesi kas terbuka',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _kv(
                'Opening balance',
                MoneyFormatter.rupiah(snapshot.openingAmount),
              ),
              _kv('Transactions', '${snapshot.transactionCount}'),
              _kv('Penjualan tunai', MoneyFormatter.rupiah(snapshot.cashSales)),
              _kv(
                'Omzet non-tunai',
                MoneyFormatter.rupiah(snapshot.nonCashSales),
              ),
              _kv(
                'Cash movement masuk',
                MoneyFormatter.rupiah(snapshot.cashIn),
              ),
              _kv(
                'Cash movement keluar',
                MoneyFormatter.rupiah(snapshot.cashOut),
              ),
              _kv(
                'Expected cash',
                MoneyFormatter.rupiah(snapshot.expectedAmount),
              ),
              const SizedBox(height: 8),
              Text(
                'Expected cash = opening + penjualan tunai + kas masuk − kas keluar. '
                'Omzet non-tunai tidak dihitung.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => unawaited(
                      _addMovement(context, ref, CashMovementType.cashIn),
                    ),
                    child: const Text('Cash movement masuk'),
                  ),
                  OutlinedButton(
                    onPressed: () => unawaited(
                      _addMovement(context, ref, CashMovementType.cashOut),
                    ),
                    child: const Text('Cash movement keluar'),
                  ),
                  FilledButton(
                    onPressed: () => unawaited(_close(context, ref)),
                    child: const Text('Close cashier'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (snapshot.sales.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Transactions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final SessionSaleRow sale in snapshot.sales)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(MoneyFormatter.rupiah(sale.totalAmount)),
              subtitle: Text(
                [
                  DateFormatter.dateTimeId(
                    DateTime.fromMillisecondsSinceEpoch(sale.createdAt),
                  ),
                  if (sale.hasCash)
                    'Tunai ${MoneyFormatter.rupiah(sale.cashAmount)}',
                  if (sale.hasNonCash)
                    'Non-tunai ${MoneyFormatter.rupiah(sale.nonCashAmount)}',
                ].join(' · '),
              ),
            ),
        ],
        if (snapshot.movements.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Cash movement', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final CashMovement row in snapshot.movements)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(CashMovementType.label(row.type)),
              subtitle: Text(
                [
                  DateFormatter.dateTimeId(
                    DateTime.fromMillisecondsSinceEpoch(row.createdAt),
                  ),
                  if (row.note != null && row.note!.isNotEmpty) row.note!,
                ].join(' · '),
              ),
              trailing: Text(MoneyFormatter.rupiah(row.amount)),
            ),
        ],
      ],
    );
  }

  Future<void> _addMovement(
    BuildContext context,
    WidgetRef ref,
    String type,
  ) async {
    final TextEditingController amount = TextEditingController();
    final TextEditingController note = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(CashMovementType.label(type)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KdTextField(
                label: 'Nominal (Rp)',
                controller: amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
              ),
              const SizedBox(height: 12),
              KdTextField(label: 'Catatan', controller: note, hint: 'Opsional'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    final int parsed = AppValidators.parseRupiah(amount.text);
    amount.dispose();
    final String noteText = note.text.trim();
    note.dispose();
    if (ok != true || !context.mounted) {
      return;
    }
    if (parsed <= 0) {
      context.showMessage('Nominal mutasi kas harus integer > 0');
      return;
    }
    try {
      await ref
          .read(cashControllerProvider)
          .addMovement(
            sessionId: snapshot.session.id,
            type: type,
            amount: parsed,
            note: noteText.isEmpty ? null : noteText,
          );
      if (context.mounted) {
        context.showMessage('Cash movement disimpan.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        context.showMessage(ErrorHandler.userMessage(error));
      }
    }
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final TextEditingController actual = TextEditingController(
      text: '${snapshot.expectedAmount}',
    );
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Close cashier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expected cash: ${MoneyFormatter.rupiah(snapshot.expectedAmount)}',
              ),
              const SizedBox(height: 8),
              Text(
                'Omzet non-tunai ${MoneyFormatter.rupiah(snapshot.nonCashSales)} '
                'tidak masuk expected cash.',
              ),
              const SizedBox(height: 12),
              KdTextField(
                label: 'Actual cash',
                controller: actual,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Simpan closing report'),
            ),
          ],
        );
      },
    );
    final int counted = AppValidators.parseRupiah(actual.text);
    actual.dispose();
    if (ok != true || !context.mounted) {
      return;
    }
    try {
      final CashSession closed = await ref
          .read(cashControllerProvider)
          .close(sessionId: snapshot.session.id, countedAmount: counted);
      if (!context.mounted) {
        return;
      }
      final int difference = closed.differenceAmount ?? 0;
      context.showMessage(
        'Closing report disimpan. Difference: ${MoneyFormatter.signedRupiah(difference)}',
      );
    } on Object catch (error) {
      if (context.mounted) {
        context.showMessage(ErrorHandler.userMessage(error));
      }
    }
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ClosedReportCard extends StatelessWidget {
  const _ClosedReportCard({required this.session});

  final CashSession session;

  @override
  Widget build(BuildContext context) {
    final CashClosingReport? report = session.closingReport;
    final int expected = report?.expectedAmount ?? session.expectedAmount ?? 0;
    final int actual = report?.actualAmount ?? session.closingAmount ?? 0;
    final int difference =
        report?.differenceAmount ?? session.differenceAmount ?? 0;
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.closedAt == null
                ? 'Closing report'
                : DateFormatter.dateTimeId(
                    DateTime.fromMillisecondsSinceEpoch(session.closedAt!),
                  ),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _kv(
            'Opening balance',
            report?.openingAmount ?? session.openingAmount,
          ),
          _kv('Penjualan tunai', report?.cashSales ?? 0),
          _kv('Omzet non-tunai', report?.nonCashSales ?? 0),
          _kv('Expected cash', expected),
          _kv('Actual cash', actual),
          _kv('Difference', difference, signed: true),
        ],
      ),
    );
  }

  Widget _kv(String label, int amount, {bool signed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            signed
                ? MoneyFormatter.signedRupiah(amount)
                : MoneyFormatter.rupiah(amount),
          ),
        ],
      ),
    );
  }
}
