import 'dart:convert';

enum PosCartStatus {
  open,
  held;

  String get storageValue => name;

  static PosCartStatus parse(String value) {
    return switch (value) {
      'open' => PosCartStatus.open,
      'held' => PosCartStatus.held,
      _ => PosCartStatus.open,
    };
  }
}

final class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.costPrice,
    required this.qty,
    this.discountAmount = 0,
    this.sku,
    this.barcode,
  });

  final String productId;
  final String name;
  final int unitPrice;
  final int costPrice;
  final int qty;
  final int discountAmount;
  final String? sku;
  final String? barcode;

  int get gross => unitPrice * qty;

  int get lineTotal => gross - discountAmount;

  CartLine copyWith({
    int? qty,
    int? discountAmount,
    String? name,
    int? unitPrice,
  }) {
    return CartLine(
      productId: productId,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice,
      qty: qty ?? this.qty,
      discountAmount: discountAmount ?? this.discountAmount,
      sku: sku,
      barcode: barcode,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'productId': productId,
      'name': name,
      'unitPrice': unitPrice,
      'costPrice': costPrice,
      'qty': qty,
      'discountAmount': discountAmount,
      'sku': sku,
      'barcode': barcode,
    };
  }
}

final class PosCart {
  const PosCart({
    required this.id,
    required this.businessId,
    required this.clientUuid,
    required this.status,
    required this.lines,
    required this.discountAmount,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.customerId,
    this.customerName,
    this.note,
  });

  final String id;
  final String businessId;
  final String? userId;
  final String clientUuid;
  final PosCartStatus status;
  final List<CartLine> lines;
  final String? customerId;
  final String? customerName;
  final int discountAmount;
  final String? note;
  final int createdAt;
  final int updatedAt;

  int get subtotal =>
      lines.fold<int>(0, (int sum, CartLine line) => sum + line.lineTotal);

  int get total {
    final int value = subtotal - discountAmount;
    return value < 0 ? 0 : value;
  }

  bool get isEmpty => lines.isEmpty;

  PosCart copyWith({
    PosCartStatus? status,
    List<CartLine>? lines,
    String? clientUuid,
    String? userId,
    String? customerId,
    String? customerName,
    int? discountAmount,
    String? note,
    int? updatedAt,
    bool clearCustomer = false,
    bool clearNote = false,
  }) {
    return PosCart(
      id: id,
      businessId: businessId,
      userId: userId ?? this.userId,
      clientUuid: clientUuid ?? this.clientUuid,
      status: status ?? this.status,
      lines: lines ?? this.lines,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      discountAmount: discountAmount ?? this.discountAmount,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String encodePayload() {
    return jsonEncode(<String, Object>{
      'items': lines.map((CartLine line) => line.toJson()).toList(),
    });
  }

  static List<CartLine> decodePayload(String payload) {
    final Object? decoded = jsonDecode(payload);
    if (decoded is! Map) {
      return const [];
    }
    final Object? items = decoded['items'];
    if (items is! List) {
      return const [];
    }
    return items.map((dynamic raw) {
      final Map<dynamic, dynamic> row = raw as Map<dynamic, dynamic>;
      return CartLine(
        productId: row['productId'] as String,
        name: row['name'] as String,
        unitPrice: row['unitPrice'] as int,
        costPrice: row['costPrice'] as int,
        qty: row['qty'] as int,
        discountAmount: (row['discountAmount'] as int?) ?? 0,
        sku: row['sku'] as String?,
        barcode: row['barcode'] as String?,
      );
    }).toList();
  }
}

extension PosCartEdit on PosCart {
  PosCart addOrIncrement(CartLine incoming) {
    final int index = lines.indexWhere(
      (CartLine line) => line.productId == incoming.productId,
    );
    if (index < 0) {
      if (incoming.qty <= 0) {
        return this;
      }
      return copyWith(lines: <CartLine>[...lines, incoming]);
    }
    return setQty(incoming.productId, lines[index].qty + incoming.qty);
  }

  PosCart setQty(String productId, int qty) {
    if (qty <= 0) {
      return copyWith(
        lines: lines
            .where((CartLine line) => line.productId != productId)
            .toList(),
      );
    }
    return copyWith(
      lines: lines.map((CartLine line) {
        if (line.productId != productId) {
          return line;
        }
        final CartLine next = line.copyWith(qty: qty);
        if (next.discountAmount > next.gross) {
          return next.copyWith(discountAmount: next.gross);
        }
        return next;
      }).toList(),
    );
  }

  PosCart removeLine(String productId) {
    return copyWith(
      lines: lines
          .where((CartLine line) => line.productId != productId)
          .toList(),
    );
  }

  PosCart setItemDiscount(String productId, int discountAmount) {
    final int safe = discountAmount < 0 ? 0 : discountAmount;
    return copyWith(
      lines: lines.map((CartLine line) {
        if (line.productId != productId) {
          return line;
        }
        final int capped = safe > line.gross ? line.gross : safe;
        return line.copyWith(discountAmount: capped);
      }).toList(),
    );
  }

  PosCart setTransactionDiscount(int amount) {
    final int safe = amount < 0 ? 0 : amount;
    final int capped = safe > subtotal ? subtotal : safe;
    return copyWith(discountAmount: capped);
  }
}
