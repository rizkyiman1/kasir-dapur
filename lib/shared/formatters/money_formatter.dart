import 'package:kasir_dapur/core/money/money.dart';

abstract final class MoneyFormatter {
  static String rupiah(int amountRupiah) => Money(amountRupiah).formatId();

  static String rupiahMoney(Money money) => money.formatId();

  /// Laba/rugi. Boleh negatif; bukan untuk menyimpan uang di domain.
  static String signedRupiah(int amountRupiah) {
    if (amountRupiah < 0) {
      return '-${Money(-amountRupiah).formatId()}';
    }
    return Money(amountRupiah).formatId();
  }
}
