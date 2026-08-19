final class Supplier {
  const Supplier({
    required this.id,
    required this.businessId,
    required this.name,
    this.contact,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? contact;
  final String? address;
  final String? notes;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  Supplier copyWith({
    String? name,
    String? contact,
    bool clearContact = false,
    String? address,
    bool clearAddress = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return Supplier(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      contact: clearContact ? null : (contact ?? this.contact),
      address: clearAddress ? null : (address ?? this.address),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }
}

final class NewSupplier {
  const NewSupplier({
    required this.businessId,
    required this.name,
    this.contact,
    this.address,
    this.notes,
  });

  final String businessId;
  final String name;
  final String? contact;
  final String? address;
  final String? notes;
}
