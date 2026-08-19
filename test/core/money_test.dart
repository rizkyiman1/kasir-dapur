import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/money/money.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';

void main() {
  group('Money', () {
    test('menjumlahkan tanpa pecahan', () {
      expect(const Money(1500) + const Money(500), const Money(2000));
    });

    test('menghitung kembalian tunai', () {
      expect(
        Money.change(total: const Money(17500), tendered: const Money(20000)),
        const Money(2500),
      );
    });

    test('menolak kembalian jika uang kurang', () {
      expect(
        () => Money.change(
          total: const Money(20000),
          tendered: const Money(10000),
        ),
        throwsStateError,
      );
    });

    test('memformat Rupiah dengan pemisah ribuan', () {
      expect(const Money(1250000).formatId(), 'Rp1.250.000');
      expect(const Money(0).formatId(), 'Rp0');
      expect(MoneyFormatter.signedRupiah(-1500), '-Rp1.500');
      expect(MoneyFormatter.signedRupiah(1500), 'Rp1.500');
    });

    test('perkalian kuantitas memakai integer', () {
      expect(const Money(3500).times(3), const Money(10500));
    });
  });
}
