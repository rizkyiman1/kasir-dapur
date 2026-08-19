enum DashboardPeriod {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  custom;

  String get label {
    return switch (this) {
      DashboardPeriod.today => 'Hari ini',
      DashboardPeriod.yesterday => 'Kemarin',
      DashboardPeriod.thisWeek => 'Minggu ini',
      DashboardPeriod.thisMonth => 'Bulan ini',
      DashboardPeriod.custom => 'Rentang',
    };
  }
}

/// Rentang waktu inklusif di [startMs], eksklusif di [endMsExclusive].
final class DashboardDateRange {
  const DashboardDateRange({
    required this.startMs,
    required this.endMsExclusive,
    required this.period,
  });

  final int startMs;
  final int endMsExclusive;
  final DashboardPeriod period;

  static DateTime startOfLocalDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DashboardDateRange resolve({
    required DashboardPeriod period,
    required DateTime now,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final DateTime today = startOfLocalDay(now);
    final DateTime tomorrow = today.add(const Duration(days: 1));

    switch (period) {
      case DashboardPeriod.today:
        return DashboardDateRange(
          startMs: today.millisecondsSinceEpoch,
          endMsExclusive: tomorrow.millisecondsSinceEpoch,
          period: period,
        );
      case DashboardPeriod.yesterday:
        final DateTime yesterday = today.subtract(const Duration(days: 1));
        return DashboardDateRange(
          startMs: yesterday.millisecondsSinceEpoch,
          endMsExclusive: today.millisecondsSinceEpoch,
          period: period,
        );
      case DashboardPeriod.thisWeek:
        final DateTime weekStart = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        return DashboardDateRange(
          startMs: weekStart.millisecondsSinceEpoch,
          endMsExclusive: tomorrow.millisecondsSinceEpoch,
          period: period,
        );
      case DashboardPeriod.thisMonth:
        final DateTime monthStart = DateTime(today.year, today.month, 1);
        return DashboardDateRange(
          startMs: monthStart.millisecondsSinceEpoch,
          endMsExclusive: tomorrow.millisecondsSinceEpoch,
          period: period,
        );
      case DashboardPeriod.custom:
        if (customStart == null || customEnd == null) {
          return DashboardDateRange.resolve(
            period: DashboardPeriod.today,
            now: now,
          );
        }
        DateTime from = startOfLocalDay(customStart);
        DateTime to = startOfLocalDay(customEnd);
        if (to.isBefore(from)) {
          final DateTime swap = from;
          from = to;
          to = swap;
        }
        return DashboardDateRange(
          startMs: from.millisecondsSinceEpoch,
          endMsExclusive: to
              .add(const Duration(days: 1))
              .millisecondsSinceEpoch,
          period: period,
        );
    }
  }
}

final class DashboardFilter {
  const DashboardFilter({
    this.period = DashboardPeriod.today,
    this.customStart,
    this.customEnd,
  });

  final DashboardPeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;

  DashboardDateRange rangeFor(DateTime now) {
    return DashboardDateRange.resolve(
      period: period,
      now: now,
      customStart: customStart,
      customEnd: customEnd,
    );
  }

  DashboardFilter copyWith({
    DashboardPeriod? period,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustom = false,
  }) {
    return DashboardFilter(
      period: period ?? this.period,
      customStart: clearCustom ? null : (customStart ?? this.customStart),
      customEnd: clearCustom ? null : (customEnd ?? this.customEnd),
    );
  }
}
