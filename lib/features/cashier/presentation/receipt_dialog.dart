import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kasir_dapur/features/cashier/domain/receipt_formatter.dart';
import 'package:kasir_dapur/features/printers/domain/receipt_paper_size.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';

Future<void> showSaleReceiptDialog({
  required BuildContext context,
  required Sale sale,
  String? customerName,
  String? cashierName,
  ReceiptPaperSize paperSize = ReceiptPaperSize.mm58,
  ReceiptStoreInfo? store,
  Future<void> Function()? onPrint,
  Future<void> Function()? onReprint,
}) {
  final String text = ReceiptFormatter.fromSale(
    sale,
    paperSize: paperSize,
    customerName: customerName,
    cashierName: cashierName,
    store: store,
  );
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return _ReceiptDialog(
        sale: sale,
        text: text,
        onPrint: onPrint,
        onReprint: onReprint,
      );
    },
  );
}

class _ReceiptDialog extends StatefulWidget {
  const _ReceiptDialog({
    required this.sale,
    required this.text,
    this.onPrint,
    this.onReprint,
  });

  final Sale sale;
  final String text;
  final Future<void> Function()? onPrint;
  final Future<void> Function()? onReprint;

  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Struk'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total ${MoneyFormatter.rupiah(widget.sale.totalAmount)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (widget.sale.payments.isNotEmpty &&
                  widget.sale.payments.first.changeAmount > 0)
                Text(
                  'Kembalian ${MoneyFormatter.rupiah(widget.sale.payments.first.changeAmount)}',
                ),
              const SizedBox(height: 12),
              SelectableText(
                widget.text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  unawaited(_copy());
                },
          child: const Text('Salin'),
        ),
        if (widget.onPrint != null)
          TextButton(
            onPressed: _busy
                ? null
                : () => unawaited(_run(widget.onPrint!, 'Struk dicetak')),
            child: const Text('Cetak'),
          ),
        if (widget.onReprint != null)
          TextButton(
            onPressed: _busy
                ? null
                : () =>
                      unawaited(_run(widget.onReprint!, 'Struk dicetak ulang')),
            child: const Text('Cetak ulang'),
          ),
        FilledButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Selesai'),
        ),
      ],
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (mounted) {
      context.showMessage('Struk disalin');
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        context.showMessage(success);
      }
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
