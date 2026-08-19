import 'package:kasir_dapur_backend/midtrans/midtrans_signature.dart';
import 'package:test/test.dart';

void main() {
  test('tanda tangan SHA512 memakai Server Key hanya di backend', () {
    final String digest = MidtransSignature.digest(
      orderId: 'KD-1',
      statusCode: '200',
      grossAmount: '150000.00',
      serverKey: 'secret',
    );
    expect(digest.length, 128);
    expect(
      MidtransSignature.matches(
        orderId: 'KD-1',
        statusCode: '200',
        grossAmount: '150000.00',
        serverKey: 'secret',
        provided: digest,
      ),
      isTrue,
    );
    expect(
      MidtransSignature.matches(
        orderId: 'KD-1',
        statusCode: '200',
        grossAmount: '150000.00',
        serverKey: 'secret',
        provided: 'salah',
      ),
      isFalse,
    );
    expect(MidtransSignature.grossAmountOf(150000), '150000.00');
  });
}
