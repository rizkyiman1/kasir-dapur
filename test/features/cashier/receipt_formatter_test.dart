import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/features/cashier/domain/receipt_formatter.dart';
import 'package:kasir_dapur/features/printers/domain/receipt_paper_size.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';

Sale _sale() {
  return const Sale(
    id: 'sale-1',
    clientUuid: 'uuid-1',
    businessId: 'biz-1',
    status: 'completed',
    subtotalAmount: 25000,
    discountAmount: 0,
    taxAmount: 0,
    totalAmount: 25000,
    items: <SaleItem>[
      SaleItem(
        id: 'i1',
        transactionId: 'sale-1',
        productId: 'p1',
        nameSnapshot: 'Nasi Goreng',
        qty: 1,
        unitPrice: 25000,
        costPrice: 8000,
        discountAmount: 0,
        lineTotal: 25000,
      ),
    ],
    payments: <SalePayment>[
      SalePayment(
        id: 'pay-1',
        transactionId: 'sale-1',
        method: 'cash',
        amount: 25000,
        tenderedAmount: 50000,
        changeAmount: 25000,
      ),
    ],
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  test('struk memuat identitas, item, pembayaran, dan footer', () {
    final String text = ReceiptFormatter.fromSale(
      _sale(),
      cashierName: 'Budi',
      customerName: 'Siti',
    );
    expect(text, contains(Brand.appName));
    expect(text, contains(Brand.companyName));
    expect(text, contains(Brand.websiteHost));
    expect(text, contains('No. transaksi'));
    expect(text, contains('Kasir'));
    expect(text, contains('Budi'));
    expect(text, contains('Nasi Goreng'));
    expect(text, contains('Qty'));
    expect(text, contains('Harga'));
    expect(text, contains('Diskon'));
    expect(text, contains('Pembayaran'));
    expect(text, contains('Kembalian'));
    expect(text, contains(Brand.copyright));
  });

  test('lebar 58mm tidak melebihi 32 kolom, 80mm 48 kolom', () {
    final List<String> mm58 = ReceiptFormatter.linesFromSale(
      _sale(),
      paperSize: ReceiptPaperSize.mm58,
      cashierName: 'Budi',
    );
    final List<String> mm80 = ReceiptFormatter.linesFromSale(
      _sale(),
      paperSize: ReceiptPaperSize.mm80,
      cashierName: 'Budi',
    );
    expect(mm58.every((String line) => line.length <= 32), isTrue);
    expect(mm80.every((String line) => line.length <= 48), isTrue);
    expect(ReceiptPaperSize.mm58.columns, 32);
    expect(ReceiptPaperSize.mm80.columns, 48);
  });

  test('struk memakai nama toko, alamat, telepon, dan footer receipt', () {
    final String text = ReceiptFormatter.fromSale(
      _sale(),
      store: const ReceiptStoreInfo(
        name: 'Warung Dapur Rasa',
        address: 'Depok',
        phone: '021123456',
        footer: 'NPWP toko tercatat di perangkat',
      ),
    );
    expect(text, contains('Warung Dapur Rasa'));
    expect(text, contains('Depok'));
    expect(text, contains('021123456'));
    expect(text, contains('NPWP toko tercatat di perangkat'));
    expect(text, contains(Brand.companyName));
    expect(text, isNot(contains('example.com')));
  });
}
