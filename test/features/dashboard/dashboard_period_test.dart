import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';

void main() {
  final DateTime tuesday = DateTime(2026, 8, 18, 15, 30);

  test('hari ini dari tengah malam sampai besok', () {
    final DashboardDateRange range = DashboardDateRange.resolve(
      period: DashboardPeriod.today,
      now: tuesday,
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(range.startMs),
      DateTime(2026, 8, 18),
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(range.endMsExclusive),
      DateTime(2026, 8, 19),
    );
  });

  test('kemarin adalah hari sebelumnya penuh', () {
    final DashboardDateRange range = DashboardDateRange.resolve(
      period: DashboardPeriod.yesterday,
      now: tuesday,
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(range.startMs),
      DateTime(2026, 8, 17),
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(range.endMsExclusive),
      DateTime(2026, 8, 18),
    );
  });

  test('minggu ini mulai Senin', () {
    final DashboardDateRange range = DashboardDateRange.resolve(
      period: DashboardPeriod.thisWeek,
      now: tuesday,
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(range.startMs),
      DateTime(2026, 8, 17),
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(range.endMsExclusive),
      DateTime(2026, 8, 19),
    );
  });

  test('bulan ini dari tanggal 1', () {
    final DashboardDateRange range = DashboardDateRange.resolve(
      period: DashboardPeriod.thisMonth,
      now: tuesday,
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(range.startMs),
      DateTime(2026, 8, 1),
    );
  });

  test('rentang kustom inklusif dan menukar jika terbalik', () {
    final DashboardDateRange range = DashboardDateRange.resolve(
      period: DashboardPeriod.custom,
      now: tuesday,
      customStart: DateTime(2026, 8, 20, 9),
      customEnd: DateTime(2026, 8, 18, 22),
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(range.startMs),
      DateTime(2026, 8, 18),
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(range.endMsExclusive),
      DateTime(2026, 8, 21),
    );
  });
}
