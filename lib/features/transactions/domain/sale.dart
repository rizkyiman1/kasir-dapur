final class SaleItemDraft {
  const SaleItemDraft({
    required this.productId,
    required this.qty,
    this.discountAmount = 0,
  });

  final String productId;
  final int qty;
  final int discountAmount;
}

final class SalePaymentDraft {
  const SalePaymentDraft({
    required this.method,
    required this.amount,
    this.tenderedAmount = 0,
    this.changeAmount = 0,
  });

  final String method;
  final int amount;
  final int tenderedAmount;
  final int changeAmount;
}

final class NewSale {
  const NewSale({
    required this.businessId,
    required this.clientUuid,
    required this.items,
    required this.payments,
    this.userId,
    this.customerId,
    this.cashSessionId,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.note,
  });

  final String businessId;
  final String clientUuid;
  final String? userId;
  final String? customerId;
  final String? cashSessionId;
  final List<SaleItemDraft> items;
  final List<SalePaymentDraft> payments;
  final int discountAmount;
  final int taxAmount;
  final String? note;
}

final class SaleItem {
  const SaleItem({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.nameSnapshot,
    required this.qty,
    required this.unitPrice,
    required this.costPrice,
    required this.discountAmount,
    required this.lineTotal,
  });

  final String id;
  final String transactionId;
  final String productId;
  final String nameSnapshot;
  final int qty;
  final int unitPrice;
  final int costPrice;
  final int discountAmount;
  final int lineTotal;
}

final class SalePayment {
  const SalePayment({
    required this.id,
    required this.transactionId,
    required this.method,
    required this.amount,
    required this.tenderedAmount,
    required this.changeAmount,
  });

  final String id;
  final String transactionId;
  final String method;
  final int amount;
  final int tenderedAmount;
  final int changeAmount;
}

final class Sale {
  const Sale({
    required this.id,
    required this.clientUuid,
    required this.businessId,
    required this.status,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.items,
    required this.payments,
    this.userId,
    this.customerId,
    this.cashSessionId,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String clientUuid;
  final String businessId;
  final String? userId;
  final String? customerId;
  final String? cashSessionId;
  final String status;
  final int subtotalAmount;
  final int discountAmount;
  final int taxAmount;
  final int totalAmount;
  final String? note;
  final List<SaleItem> items;
  final List<SalePayment> payments;
  final int createdAt;
  final int updatedAt;
}
