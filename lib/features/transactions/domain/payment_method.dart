import 'package:kasir_dapur/core/errors/app_exception.dart';

enum PaymentMethod {
  cash,
  qris,
  transfer,
  eWallet,
  debit,
  credit,
  midtrans;

  String get storageValue {
    return switch (this) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.qris => 'qris',
      PaymentMethod.transfer => 'transfer',
      PaymentMethod.eWallet => 'e_wallet',
      PaymentMethod.debit => 'debit',
      PaymentMethod.credit => 'credit',
      PaymentMethod.midtrans => 'midtrans',
    };
  }

  String get label {
    return switch (this) {
      PaymentMethod.cash => 'Tunai',
      PaymentMethod.qris => 'QRIS',
      PaymentMethod.transfer => 'Transfer',
      PaymentMethod.eWallet => 'E-Wallet',
      PaymentMethod.debit => 'Debit',
      PaymentMethod.credit => 'Kredit',
      PaymentMethod.midtrans => 'Midtrans',
    };
  }

  bool get isCash => this == PaymentMethod.cash;

  static PaymentMethod parse(String value) {
    return switch (value) {
      'cash' || 'tunai' => PaymentMethod.cash,
      'qris' => PaymentMethod.qris,
      'transfer' => PaymentMethod.transfer,
      'e_wallet' || 'ewallet' || 'e-wallet' => PaymentMethod.eWallet,
      'debit' => PaymentMethod.debit,
      'credit' || 'kredit' => PaymentMethod.credit,
      'midtrans' => PaymentMethod.midtrans,
      _ => throw ValidationException('Metode pembayaran tidak dikenal: $value'),
    };
  }
}

/// Hitung pembayaran tunai. [amount] yang masuk transaksi = total, bukan uang diterima.
final class CashTender {
  const CashTender({
    required this.amount,
    required this.tenderedAmount,
    required this.changeAmount,
  });

  final int amount;
  final int tenderedAmount;
  final int changeAmount;

  static CashTender exact(int total) {
    if (total < 0) {
      throw const ValidationException('Total tidak boleh negatif');
    }
    return CashTender(amount: total, tenderedAmount: total, changeAmount: 0);
  }

  static CashTender fromTendered({required int total, required int tendered}) {
    if (total < 0 || tendered < 0) {
      throw const ValidationException('Nominal harus integer >= 0');
    }
    if (tendered < total) {
      throw const ValidationException('Uang diterima kurang dari total');
    }
    return CashTender(
      amount: total,
      tenderedAmount: tendered,
      changeAmount: tendered - total,
    );
  }
}
