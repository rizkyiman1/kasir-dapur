import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';

void main() {
  test('uang pas dan kelebihan tunai', () {
    final CashTender exact = CashTender.exact(25000);
    expect(exact.amount, 25000);
    expect(exact.tenderedAmount, 25000);
    expect(exact.changeAmount, 0);

    final CashTender excess = CashTender.fromTendered(
      total: 25000,
      tendered: 50000,
    );
    expect(excess.amount, 25000);
    expect(excess.tenderedAmount, 50000);
    expect(excess.changeAmount, 25000);
  });

  test('uang diterima kurang ditolak', () {
    expect(
      () => CashTender.fromTendered(total: 25000, tendered: 20000),
      throwsA(isA<ValidationException>()),
    );
  });

  test('semua metode pembayaran punya nilai simpan', () {
    expect(PaymentMethod.cash.storageValue, 'cash');
    expect(PaymentMethod.qris.storageValue, 'qris');
    expect(PaymentMethod.transfer.storageValue, 'transfer');
    expect(PaymentMethod.eWallet.storageValue, 'e_wallet');
    expect(PaymentMethod.debit.storageValue, 'debit');
    expect(PaymentMethod.credit.storageValue, 'credit');
    expect(PaymentMethod.midtrans.storageValue, 'midtrans');
  });
}
