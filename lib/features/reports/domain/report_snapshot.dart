library;

/// Semua nominal uang adalah integer Rupiah dari SQLite. Jangan double.

final class ReportSaleRow {
  const ReportSaleRow({
    required this.id,
    required this.createdAt,
    required this.amount,
    required this.cashierName,
  });

  final String id;
  final int createdAt;
  final int amount;
  final String cashierName;
}

final class ReportNamedAmount {
  const ReportNamedAmount({
    required this.id,
    required this.name,
    required this.amount,
    this.qty = 0,
    this.count = 0,
    this.cogs = 0,
    this.grossProfit = 0,
  });

  final String id;
  final String name;
  final int amount;
  final int qty;
  final int count;
  final int cogs;
  final int grossProfit;
}

final class ReportStockRow {
  const ReportStockRow({
    required this.productId,
    required this.name,
    required this.qty,
    required this.minStock,
    this.categoryName,
  });

  final String productId;
  final String name;
  final int qty;
  final int minStock;
  final String? categoryName;
}

final class ReportExpenseRow {
  const ReportExpenseRow({
    required this.id,
    required this.amount,
    required this.spentAt,
    this.note,
    this.categoryName,
  });

  final String id;
  final int amount;
  final int spentAt;
  final String? note;
  final String? categoryName;
}

final class ReportCashSnapshot {
  const ReportCashSnapshot({
    required this.currentBalance,
    required this.hasOpenSession,
    required this.periodCashSales,
    this.periodNonCashSales = 0,
    required this.periodCashIn,
    required this.periodCashOut,
  });

  const ReportCashSnapshot.empty()
    : currentBalance = 0,
      hasOpenSession = false,
      periodCashSales = 0,
      periodNonCashSales = 0,
      periodCashIn = 0,
      periodCashOut = 0;

  final int currentBalance;
  final bool hasOpenSession;
  final int periodCashSales;
  final int periodNonCashSales;
  final int periodCashIn;
  final int periodCashOut;

  int get periodNet => periodCashSales + periodCashIn - periodCashOut;
}

/// Hasil laporan. Setiap angka uang/qty berasal dari agregasi INTEGER SQLite.
final class ReportSnapshot {
  const ReportSnapshot({
    required this.businessId,
    required this.omzet,
    required this.transactionCount,
    required this.productsSoldQty,
    required this.cogs,
    required this.grossProfit,
    required this.expensesTotal,
    required this.sales,
    required this.topProducts,
    required this.stock,
    required this.lowStock,
    required this.expenses,
    required this.cash,
    required this.paymentMethods,
    required this.salesByCashier,
    required this.salesByCategory,
  });

  const ReportSnapshot.empty()
    : businessId = null,
      omzet = 0,
      transactionCount = 0,
      productsSoldQty = 0,
      cogs = 0,
      grossProfit = 0,
      expensesTotal = 0,
      sales = const [],
      topProducts = const [],
      stock = const [],
      lowStock = const [],
      expenses = const [],
      cash = const ReportCashSnapshot.empty(),
      paymentMethods = const [],
      salesByCashier = const [],
      salesByCategory = const [];

  final String? businessId;
  final int omzet;
  final int transactionCount;
  final int productsSoldQty;
  final int cogs;
  final int grossProfit;
  final int expensesTotal;
  final List<ReportSaleRow> sales;
  final List<ReportNamedAmount> topProducts;
  final List<ReportStockRow> stock;
  final List<ReportStockRow> lowStock;
  final List<ReportExpenseRow> expenses;
  final ReportCashSnapshot cash;
  final List<ReportNamedAmount> paymentMethods;
  final List<ReportNamedAmount> salesByCashier;
  final List<ReportNamedAmount> salesByCategory;

  bool get hasActivity {
    return transactionCount > 0 ||
        expensesTotal > 0 ||
        stock.isNotEmpty ||
        lowStock.isNotEmpty ||
        cash.currentBalance != 0 ||
        cash.periodNet != 0;
  }
}
