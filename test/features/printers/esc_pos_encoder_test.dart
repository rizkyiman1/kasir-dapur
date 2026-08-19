import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/features/printers/domain/esc_pos_encoder.dart';

void main() {
  test('ESC/POS diawali init dan diakhiri potong kertas', () {
    final List<int> bytes = EscPosEncoder.encodeLines(const <String>[
      'Kasir Dapur',
      'Tes',
    ]);
    expect(bytes.take(2), [0x1B, 0x40]);
    expect(bytes, containsAllInOrder(<int>[0x1D, 0x56, 0x41]));
    expect(
      String.fromCharCodes(bytes.where((int b) => b >= 32 && b < 127)),
      contains('Kasir Dapur'),
    );
  });
}
