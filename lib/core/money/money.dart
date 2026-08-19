/// Nominal uang dalam satuan Rupiah utuh. Jangan gunakan double untuk hitung uang.
final class Money {
  const Money(this.amountRupiah)
    : assert(amountRupiah >= 0, 'Nominal tidak boleh negatif');

  const Money.zero() : amountRupiah = 0;

  final int amountRupiah;

  Money operator +(Money other) => Money(amountRupiah + other.amountRupiah);

  Money operator -(Money other) {
    final int result = amountRupiah - other.amountRupiah;
    if (result < 0) {
      throw StateError('Hasil pengurangan uang tidak boleh negatif');
    }
    return Money(result);
  }

  Money times(int qty) {
    if (qty < 0) {
      throw ArgumentError.value(qty, 'qty', 'Kuantitas tidak boleh negatif');
    }
    return Money(amountRupiah * qty);
  }

  bool operator >(Money other) => amountRupiah > other.amountRupiah;

  bool operator <(Money other) => amountRupiah < other.amountRupiah;

  bool operator >=(Money other) => amountRupiah >= other.amountRupiah;

  bool operator <=(Money other) => amountRupiah <= other.amountRupiah;

  @override
  bool operator ==(Object other) {
    return other is Money && other.amountRupiah == amountRupiah;
  }

  @override
  int get hashCode => amountRupiah.hashCode;

  /// Kembalian tunai. [tendered] harus >= total.
  static Money change({required Money total, required Money tendered}) {
    if (tendered < total) {
      throw StateError('Uang diterima lebih kecil dari total');
    }
    return tendered - total;
  }

  String formatId() {
    final String digits = amountRupiah.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final int reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return 'Rp$buffer';
  }

  @override
  String toString() => formatId();
}
