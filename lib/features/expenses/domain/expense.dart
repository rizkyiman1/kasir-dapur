final class ExpenseCategoryCatalog {
  const ExpenseCategoryCatalog._();

  static const String listrik = 'listrik';
  static const String gas = 'gas';
  static const String packaging = 'packaging';
  static const String transport = 'transport';
  static const String gaji = 'gaji';
  static const String sewa = 'sewa';
  static const String internet = 'internet';
  static const String lainnya = 'lainnya';

  static const List<({String code, String label})> defaults =
      <({String code, String label})>[
        (code: listrik, label: 'Listrik'),
        (code: gas, label: 'Gas'),
        (code: packaging, label: 'Packaging'),
        (code: transport, label: 'Transport'),
        (code: gaji, label: 'Gaji'),
        (code: sewa, label: 'Sewa'),
        (code: internet, label: 'Internet'),
        (code: lainnya, label: 'Lainnya'),
      ];

  static String labelOf(String? code, {String? fallback}) {
    if (code == null || code.isEmpty) {
      return fallback ?? 'Lainnya';
    }
    for (final ({String code, String label}) row in defaults) {
      if (row.code == code) {
        return row.label;
      }
    }
    return fallback ?? code;
  }
}

final class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.businessId,
    required this.name,
    this.code,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? code;
  final int createdAt;
  final int updatedAt;

  String get label => ExpenseCategoryCatalog.labelOf(code, fallback: name);
}

final class Expense {
  const Expense({
    required this.id,
    required this.businessId,
    this.categoryId,
    this.categoryName,
    this.categoryCode,
    required this.amount,
    this.note,
    required this.spentAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String? categoryId;
  final String? categoryName;
  final String? categoryCode;
  final int amount;
  final String? note;
  final int spentAt;
  final int createdAt;
  final int updatedAt;

  String get categoryLabel =>
      ExpenseCategoryCatalog.labelOf(categoryCode, fallback: categoryName);
}

final class NewExpense {
  const NewExpense({
    required this.businessId,
    required this.amount,
    this.categoryId,
    this.note,
    required this.spentAt,
  });

  final String businessId;
  final String? categoryId;
  final int amount;
  final String? note;
  final int spentAt;
}
