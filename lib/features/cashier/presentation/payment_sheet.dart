import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';
import 'package:kasir_dapur/widgets/kd_button.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

Future<List<SalePaymentDraft>?> showCashierPaymentSheet({
  required BuildContext context,
  required int total,
  PaymentMethod defaultMethod = PaymentMethod.cash,
}) {
  return showModalBottomSheet<List<SalePaymentDraft>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return _PaymentSheet(total: total, defaultMethod: defaultMethod);
    },
  );
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.total, required this.defaultMethod});

  final int total;
  final PaymentMethod defaultMethod;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late PaymentMethod _method = widget.defaultMethod;
  final TextEditingController _tendered = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _tendered.text = '${widget.total}';
  }

  @override
  void dispose() {
    _tendered.dispose();
    super.dispose();
  }

  int get _tenderedValue => AppValidators.parseRupiah(_tendered.text);

  int get _change {
    if (!_method.isCash) {
      return 0;
    }
    final int tendered = _tenderedValue;
    if (tendered < widget.total) {
      return 0;
    }
    return tendered - widget.total;
  }

  @override
  Widget build(BuildContext context) {
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pembayaran', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Total ${MoneyFormatter.rupiah(widget.total)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final PaymentMethod method in PaymentMethod.values)
                ChoiceChip(
                  label: Text(method.label),
                  selected: _method == method,
                  onSelected: (_) {
                    setState(() {
                      _method = method;
                      _error = null;
                      if (!method.isCash) {
                        _tendered.text = '${widget.total}';
                      }
                    });
                  },
                ),
            ],
          ),
          if (_method.isCash) ...[
            const SizedBox(height: 12),
            KdTextField(
              label: 'Uang diterima',
              controller: _tendered,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Uang pas'),
                  onPressed: () {
                    setState(() => _tendered.text = '${widget.total}');
                  },
                ),
                for (final int amount in <int>[20000, 50000, 100000])
                  if (amount >= widget.total)
                    ActionChip(
                      label: Text(MoneyFormatter.rupiah(amount)),
                      onPressed: () {
                        setState(() => _tendered.text = '$amount');
                      },
                    ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Kembalian ${MoneyFormatter.rupiah(_change)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          if (_method == PaymentMethod.midtrans)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Midtrans dicatat lokal. Tidak ada kunci server di aplikasi ini.',
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          KdButton(label: 'Bayar', icon: Icons.check, onPressed: _confirm),
        ],
      ),
    );
  }

  void _confirm() {
    try {
      final List<SalePaymentDraft> payments;
      if (_method.isCash) {
        final CashTender cash = CashTender.fromTendered(
          total: widget.total,
          tendered: _tenderedValue,
        );
        payments = [
          SalePaymentDraft(
            method: _method.storageValue,
            amount: cash.amount,
            tenderedAmount: cash.tenderedAmount,
            changeAmount: cash.changeAmount,
          ),
        ];
      } else {
        payments = [
          SalePaymentDraft(
            method: _method.storageValue,
            amount: widget.total,
            tenderedAmount: widget.total,
          ),
        ];
      }
      Navigator.pop(context, payments);
    } catch (error) {
      setState(
        () => _error = error is AppException
            ? error.message
            : 'Terjadi kesalahan, coba lagi.',
      );
    }
  }
}
