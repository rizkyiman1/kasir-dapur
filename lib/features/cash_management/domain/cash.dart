import 'dart:convert';

final class CashSession {
  const CashSession({
    required this.id,
    required this.businessId,
    this.userId,
    required this.openingAmount,
    this.closingAmount,
    this.expectedAmount,
    this.differenceAmount,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.createdAt,
    required this.updatedAt,
    this.closingReport,
  });

  final String id;
  final String businessId;
  final String? userId;
  final int openingAmount;
  final int? closingAmount;
  final int? expectedAmount;
  final int? differenceAmount;
  final String status;
  final int openedAt;
  final int? closedAt;
  final int createdAt;
  final int updatedAt;
  final CashClosingReport? closingReport;

  bool get isOpen => status == CashSessionStatus.open;
}

abstract final class CashSessionStatus {
  static const String open = 'open';
  static const String closed = 'closed';
}

abstract final class CashMovementType {
  static const String cashIn = 'in';
  static const String cashOut = 'out';

  static String label(String type) {
    return switch (type) {
      cashIn => 'Kas masuk',
      cashOut => 'Kas keluar',
      _ => type,
    };
  }
}

final class CashMovement {
  const CashMovement({
    required this.id,
    required this.businessId,
    required this.sessionId,
    required this.type,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String sessionId;
  final String type;
  final int amount;
  final String? note;
  final int createdAt;

  bool get isIn => type == CashMovementType.cashIn;
}

final class SessionSaleRow {
  const SessionSaleRow({
    required this.transactionId,
    required this.createdAt,
    required this.totalAmount,
    required this.cashAmount,
    required this.nonCashAmount,
  });

  final String transactionId;
  final int createdAt;
  final int totalAmount;
  final int cashAmount;
  final int nonCashAmount;

  bool get hasCash => cashAmount > 0;
  bool get hasNonCash => nonCashAmount > 0;
}

/// Laporan tutup kas. Hanya tunai masuk ke expected; omzet non-tunai terpisah.
final class CashClosingReport {
  const CashClosingReport({
    required this.openingAmount,
    required this.cashSales,
    required this.nonCashSales,
    required this.cashIn,
    required this.cashOut,
    required this.expectedAmount,
    required this.actualAmount,
    required this.differenceAmount,
    required this.transactionCount,
    required this.closedAt,
  });

  final int openingAmount;
  final int cashSales;
  final int nonCashSales;
  final int cashIn;
  final int cashOut;
  final int expectedAmount;
  final int actualAmount;
  final int differenceAmount;
  final int transactionCount;
  final int closedAt;

  Map<String, Object> toJson() {
    return <String, Object>{
      'opening_amount': openingAmount,
      'cash_sales': cashSales,
      'non_cash_sales': nonCashSales,
      'cash_in': cashIn,
      'cash_out': cashOut,
      'expected_amount': expectedAmount,
      'actual_amount': actualAmount,
      'difference_amount': differenceAmount,
      'transaction_count': transactionCount,
      'closed_at': closedAt,
    };
  }

  factory CashClosingReport.fromJson(Map<String, Object?> json) {
    return CashClosingReport(
      openingAmount: _int(json['opening_amount']),
      cashSales: _int(json['cash_sales']),
      nonCashSales: _int(json['non_cash_sales']),
      cashIn: _int(json['cash_in']),
      cashOut: _int(json['cash_out']),
      expectedAmount: _int(json['expected_amount']),
      actualAmount: _int(json['actual_amount']),
      differenceAmount: _int(json['difference_amount']),
      transactionCount: _int(json['transaction_count']),
      closedAt: _int(json['closed_at']),
    );
  }

  static CashClosingReport? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final Object decoded = jsonDecode(raw) as Object;
    if (decoded is! Map) {
      return null;
    }
    return CashClosingReport.fromJson(
      decoded.map(
        (Object? key, Object? value) =>
            MapEntry<String, Object?>(key.toString(), value),
      ),
    );
  }

  static int _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse('$value') ?? 0;
  }
}

/// Ringkasan laci kas saat sesi terbuka. Expected tidak memuat omzet non-tunai.
final class CashDrawerSnapshot {
  const CashDrawerSnapshot({
    required this.session,
    required this.cashSales,
    required this.nonCashSales,
    required this.cashIn,
    required this.cashOut,
    required this.expectedAmount,
    required this.transactionCount,
    required this.movements,
    required this.sales,
  });

  final CashSession session;
  final int cashSales;
  final int nonCashSales;
  final int cashIn;
  final int cashOut;
  final int expectedAmount;
  final int transactionCount;
  final List<CashMovement> movements;
  final List<SessionSaleRow> sales;

  int get openingAmount => session.openingAmount;
}
