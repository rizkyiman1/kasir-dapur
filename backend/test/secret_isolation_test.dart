import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('.env.example memuat secret Midtrans dan .env tidak ikut repo', () {
    final File example = File('.env.example');
    expect(example.existsSync(), isTrue);
    final String text = example.readAsStringSync();
    expect(text, contains('MIDTRANS_SERVER_KEY'));
    expect(text, contains('MIDTRANS_CLIENT_KEY'));
    expect(text, contains('MIDTRANS_MERCHANT_ID'));
    expect(text, contains('MIDTRANS_ENVIRONMENT=SANDBOX'));
    expect(File('.env').existsSync(), isFalse);
  });

  test('kode backend tidak mengirim Server Key ke klien', () {
    final File api = File('lib/http/api.dart');
    final String source = api.readAsStringSync();
    expect(source, isNot(contains('serverKey')));
    expect(source, isNot(contains('MIDTRANS_SERVER_KEY')));
  });
}
