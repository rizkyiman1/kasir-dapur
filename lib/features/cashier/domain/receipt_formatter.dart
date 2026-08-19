import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/features/printers/domain/receipt_paper_size.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';

final class ReceiptStoreInfo {
  const ReceiptStoreInfo({
    required this.name,
    this.address,
    this.phone,
    this.footer,
  });

  final String name;
  final String? address;
  final String? phone;
  final String? footer;
}

abstract final class ReceiptFormatter {
  static String fromSale(
    Sale sale, {
    ReceiptPaperSize paperSize = ReceiptPaperSize.mm58,
    String? customerName,
    String? cashierName,
    bool reprint = false,
    ReceiptStoreInfo? store,
  }) {
    return linesFromSale(
      sale,
      paperSize: paperSize,
      customerName: customerName,
      cashierName: cashierName,
      reprint: reprint,
      store: store,
    ).join('\n');
  }

  static List<String> linesFromSale(
    Sale sale, {
    ReceiptPaperSize paperSize = ReceiptPaperSize.mm58,
    String? customerName,
    String? cashierName,
    bool reprint = false,
    ReceiptStoreInfo? store,
  }) {
    final int width = paperSize.columns;
    final String storeName = (store?.name.trim().isNotEmpty ?? false)
        ? store!.name.trim()
        : Brand.appName;
    final List<String> lines = [
      _center(storeName, width),
      if (store?.address != null && store!.address!.trim().isNotEmpty)
        ..._wrap(store.address!.trim(), width),
      if (store?.phone != null && store!.phone!.trim().isNotEmpty)
        _center(store.phone!.trim(), width),
      _center(Brand.companyName, width),
      _center(Brand.websiteHost, width),
      _rule(width),
      _pair('No. transaksi', _shortId(sale.id), width),
      DateFormatter.dateTimeId(
        DateTime.fromMillisecondsSinceEpoch(sale.createdAt),
      ),
    ];
    if (cashierName != null && cashierName.isNotEmpty) {
      lines.add(_pair('Kasir', cashierName, width));
    }
    if (customerName != null && customerName.isNotEmpty) {
      lines.add(_pair('Pelanggan', customerName, width));
    }
    if (reprint) {
      lines.add(_center('CETAK ULANG', width));
    }
    lines
      ..add(_rule(width))
      ..add('Item')
      ..add('Qty / Harga / Diskon / Total');
    for (final SaleItem item in sale.items) {
      lines
        ..addAll(_wrap(item.nameSnapshot, width))
        ..add(_pair('Qty', '${item.qty}', width))
        ..add(_pair('Harga', MoneyFormatter.rupiah(item.unitPrice), width))
        ..add(
          _pair(
            'Diskon',
            item.discountAmount > 0
                ? '-${MoneyFormatter.rupiah(item.discountAmount)}'
                : MoneyFormatter.rupiah(0),
            width,
          ),
        )
        ..add(_pair('Total', MoneyFormatter.rupiah(item.lineTotal), width));
    }
    lines
      ..add(_rule(width))
      ..add(
        _pair('Subtotal', MoneyFormatter.rupiah(sale.subtotalAmount), width),
      );
    if (sale.discountAmount > 0) {
      lines.add(
        _pair(
          'Diskon',
          '-${MoneyFormatter.rupiah(sale.discountAmount)}',
          width,
        ),
      );
    }
    lines
      ..add(_pair('TOTAL', MoneyFormatter.rupiah(sale.totalAmount), width))
      ..add(_rule(width))
      ..add('Pembayaran');
    for (final SalePayment payment in sale.payments) {
      lines.add(
        _pair(
          _methodLabel(payment.method),
          MoneyFormatter.rupiah(payment.amount),
          width,
        ),
      );
      if (payment.tenderedAmount > 0) {
        lines.add(
          _pair(
            'Diterima',
            MoneyFormatter.rupiah(payment.tenderedAmount),
            width,
          ),
        );
      }
      lines.add(
        _pair('Kembalian', MoneyFormatter.rupiah(payment.changeAmount), width),
      );
    }
    lines
      ..add(_rule(width))
      ..add(_center('Terima kasih', width));
    if (store?.footer != null && store!.footer!.trim().isNotEmpty) {
      lines.addAll(_wrap(store.footer!.trim(), width));
    }
    lines
      ..add(_center(Brand.copyright, width))
      ..add(_center(Brand.websiteHost, width));
    return [for (final String line in lines) _fit(line, width)];
  }

  static List<String> testPage({
    ReceiptPaperSize paperSize = ReceiptPaperSize.mm58,
  }) {
    final int width = paperSize.columns;
    return [
      _center(Brand.appName, width),
      _center(Brand.companyName, width),
      _center(Brand.websiteHost, width),
      _rule(width),
      _center('Tes printer', width),
      _pair('Kertas', paperSize.label, width),
      _rule(width),
      _center(Brand.copyright, width),
    ].map((String line) => _fit(line, width)).toList();
  }

  static String _methodLabel(String method) {
    try {
      return PaymentMethod.parse(method).label;
    } catch (_) {
      return method;
    }
  }

  static String _shortId(String id) {
    if (id.length <= 12) {
      return id;
    }
    return id.substring(0, 8);
  }

  static String _rule(int width) => List<String>.filled(width, '-').join();

  static String _center(String text, int width) {
    if (text.length >= width) {
      return _fit(text, width);
    }
    final int pad = (width - text.length) ~/ 2;
    return '${' ' * pad}$text';
  }

  static String _pair(String label, String value, int width) {
    if (label.length + 1 + value.length <= width) {
      return '$label${' ' * (width - label.length - value.length)}$value';
    }
    final int valueWidth = value.length < width ? value.length : width;
    final String fittedValue = _fit(value, valueWidth);
    final int leftWidth = width - fittedValue.length - 1;
    if (leftWidth <= 0) {
      return _fit(fittedValue, width);
    }
    return '${_fit(label, leftWidth)} $fittedValue';
  }

  static List<String> _wrap(String text, int width) {
    if (text.length <= width) {
      return [text];
    }
    final List<String> lines = [];
    var remaining = text;
    while (remaining.length > width) {
      lines.add(remaining.substring(0, width));
      remaining = remaining.substring(width);
    }
    if (remaining.isNotEmpty) {
      lines.add(remaining);
    }
    return lines;
  }

  static String _fit(String text, int width) {
    if (text.length <= width) {
      return text;
    }
    return text.substring(0, width);
  }
}
