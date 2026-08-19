final class ClockService {
  const ClockService();

  DateTime now() => DateTime.now();

  int nowEpochMs() => now().millisecondsSinceEpoch;
}

/// Jam yang dapat digeser. Untuk tes timeout sesi, bukan produksi.
final class AdjustableClock extends ClockService {
  AdjustableClock([DateTime? initial])
    : _now = initial ?? DateTime.utc(2026, 8, 18, 8);

  DateTime _now;

  @override
  DateTime now() => _now;

  void setNow(DateTime value) {
    _now = value;
  }

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
