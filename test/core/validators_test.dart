import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';

void main() {
  group('AppValidators', () {
    test('nama tampilan wajib dan minimal 2 karakter', () {
      expect(AppValidators.displayName(null), isNotNull);
      expect(AppValidators.displayName('A'), isNotNull);
      expect(AppValidators.displayName('Budi'), isNull);
    });

    test('PIN harus 6 digit dan tidak seragam', () {
      expect(AppValidators.pin('12345'), isNotNull);
      expect(AppValidators.pin('111111'), isNotNull);
      expect(AppValidators.pin('12ab56'), isNotNull);
      expect(AppValidators.pin('123456'), isNull);
    });

    test('konfirmasi PIN harus sama', () {
      expect(AppValidators.pinConfirmation('123456', '123457'), isNotNull);
      expect(AppValidators.pinConfirmation('123456', '123456'), isNull);
    });

    test('email opsional tetapi harus valid jika diisi', () {
      expect(AppValidators.email(null), isNull);
      expect(AppValidators.email(''), isNull);
      expect(AppValidators.email('salah'), isNotNull);
      expect(AppValidators.email('owner@dapur-rasa.com'), isNull);
    });

    test('kuantitas harus angka tidak negatif atau lebih dari 0', () {
      expect(AppValidators.positiveInt('0'), isNotNull);
      expect(AppValidators.positiveInt('3'), isNull);
      expect(AppValidators.nonNegativeInt('0'), isNull);
      expect(AppValidators.nonNegativeInt('-1'), isNotNull);
    });

    test('nominal Rupiah hanya menerima angka', () {
      expect(AppValidators.rupiahInteger('Rp12.500'), isNull);
      expect(AppValidators.parseRupiah('Rp12.500'), 12500);
      expect(AppValidators.rupiahInteger('abc'), isNotNull);
    });
  });
}
