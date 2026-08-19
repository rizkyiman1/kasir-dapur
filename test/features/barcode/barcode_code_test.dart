import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/features/barcode/domain/barcode_code.dart';

void main() {
  test('mengenali EAN-13, EAN-8, UPC, Code 128, dan QR', () {
    expect(BarcodeSymbology.detect('8991002100004'), BarcodeSymbology.ean13);
    expect(BarcodeSymbology.detect('88884444'), BarcodeSymbology.ean8);
    expect(BarcodeSymbology.detect('012345678905'), BarcodeSymbology.upcA);
    expect(BarcodeSymbology.detect('0425261'), BarcodeSymbology.upcE);
    expect(BarcodeSymbology.detect('KD-TEH-01'), BarcodeSymbology.code128);
    expect(
      BarcodeSymbology.detect('https://dapur-rasa.com/p/teh'),
      BarcodeSymbology.qr,
    );
  });

  test('UPC-A dan EAN-13 saling dicari lewat leading zero', () {
    expect(
      BarcodeNormalizer.lookupKeys('123456789012'),
      containsAll(<String>['123456789012', '0123456789012']),
    );
    expect(
      BarcodeNormalizer.lookupKeys('0123456789012'),
      containsAll(<String>['0123456789012', '123456789012']),
    );
  });

  test('barcode kosong tidak punya kunci pencarian', () {
    expect(BarcodeNormalizer.lookupKeys('   '), isEmpty);
  });
}
