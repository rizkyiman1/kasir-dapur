final class LowStockItem {
  const LowStockItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.minStock,
  });

  final String productId;
  final String name;
  final int qty;
  final int minStock;
}

final class DashboardSaleSummary {
  const DashboardSaleSummary({
    required this.id,
    required this.totalAmount,
    required this.createdAt,
  });

  final String id;
  final int totalAmount;
  final int createdAt;
}

/// Ringkasan dashboard dari SQLite lokal. Uang dalam integer Rupiah.
final class DashboardSnapshot {
  const DashboardSnapshot({
    required this.businessId,
    required this.omzet,
    required this.transactionCount,
    required this.grossProfit,
    required this.productsSoldQty,
    required this.expensesTotal,
    required this.cashBalance,
    required this.hasOpenCashSession,
    required this.lowStock,
    required this.recentSales,
  });

  const DashboardSnapshot.empty()
    : businessId = null,
      omzet = 0,
      transactionCount = 0,
      grossProfit = 0,
      productsSoldQty = 0,
      expensesTotal = 0,
      cashBalance = 0,
      hasOpenCashSession = false,
      lowStock = const [],
      recentSales = const [];

  final String? businessId;
  final int omzet;
  final int transactionCount;
  final int grossProfit;
  final int productsSoldQty;
  final int expensesTotal;
  final int cashBalance;
  final bool hasOpenCashSession;
  final List<LowStockItem> lowStock;
  final List<DashboardSaleSummary> recentSales;

  bool get hasActivity {
    return transactionCount > 0 ||
        expensesTotal > 0 ||
        lowStock.isNotEmpty ||
        recentSales.isNotEmpty ||
        cashBalance != 0;
  }
}
