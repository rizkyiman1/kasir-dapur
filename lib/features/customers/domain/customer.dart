final class Customer {
  const Customer({
    required this.id,
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.transactionCount = 0,
    this.spendTotal = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final int transactionCount;
  final int spendTotal;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  Customer copyWith({
    String? name,
    String? phone,
    bool clearPhone = false,
    String? address,
    bool clearAddress = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return Customer(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      phone: clearPhone ? null : (phone ?? this.phone),
      email: email,
      address: clearAddress ? null : (address ?? this.address),
      notes: clearNotes ? null : (notes ?? this.notes),
      transactionCount: transactionCount,
      spendTotal: spendTotal,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }
}

final class NewCustomer {
  const NewCustomer({
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
}

final class CustomerSaleHistory {
  const CustomerSaleHistory({
    required this.transactionId,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    this.note,
  });

  final String transactionId;
  final String status;
  final int totalAmount;
  final int createdAt;
  final String? note;
}
