import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter tidak memuat Server Key Midtrans', () {
    final Directory lib = Directory('lib');
    expect(lib.existsSync(), isTrue);
    final Iterable<File> dartFiles = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'));
    for (final File file in dartFiles) {
      final String source = file.readAsStringSync();
      expect(source, isNot(contains('MIDTRANS_SERVER_KEY')));
      expect(source, isNot(contains('SB-Mid-server')));
      expect(source, isNot(contains('Mid-server-')));
      expect(source, isNot(contains('GOOGLE_SHEETS_CLIENT_SECRET')));
      expect(source, isNot(contains('GOOGLE_SHEETS_ACCESS_TOKEN')));
    }
  });
}
