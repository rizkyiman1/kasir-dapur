import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/features/printers/data/memory_printer_port.dart';
import 'package:kasir_dapur/features/printers/data/printer_repository_impl.dart';
import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';
import 'package:kasir_dapur/features/printers/domain/printer_service.dart';
import 'package:kasir_dapur/features/printers/domain/receipt_paper_size.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/features/transactions/domain/transaction_repository.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/pos_fixture.dart';

final class _FakeTransactions implements TransactionRepository {
  _FakeTransactions(this.sale);

  final Sale sale;

  @override
  Future<Sale> createCompletedSale(NewSale input) {
    throw UnimplementedError();
  }

  @override
  Future<Sale?> findByClientUuid({
    required String businessId,
    required String clientUuid,
  }) async {
    return null;
  }

  @override
  Future<Sale?> getById(String id) async {
    return id == sale.id ? sale : null;
  }
}

Sale _sale(String businessId) {
  return Sale(
    id: 'sale-1',
    clientUuid: 'uuid-1',
    businessId: businessId,
    status: 'completed',
    subtotalAmount: 25000,
    discountAmount: 0,
    taxAmount: 0,
    totalAmount: 25000,
    items: const <SaleItem>[
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
    payments: const <SalePayment>[
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
  late Directory tempDir;
  late AppDatabase database;
  late SqlitePrinterRepository repo;
  late MemoryBluetoothPrinterPort port;
  late PrinterService service;
  late String businessId;
  late Sale sale;
  const ClockService clock = ClockService();

  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('id_ID');
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_printer_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    repo = SqlitePrinterRepository(database: database, clock: clock);
    port = MemoryBluetoothPrinterPort();
    businessId = await insertBusiness(await database.database, clock: clock);
    sale = _sale(businessId);
    service = PrinterService(
      repository: repo,
      port: port,
      transactions: _FakeTransactions(sale),
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('tanpa printer, penjualan tetap bisa dicatat', () async {
    await service.afterSale(sale: sale, cashierName: 'Budi');
    expect(port.writes, isEmpty);
    expect(port.connected, isFalse);
    final PrinterProfile profile = await service.loadProfile(
      businessId: businessId,
    );
    expect(profile.lastSaleId, sale.id);
    expect(profile.hasDevice, isFalse);
  });

  test('connect, tes cetak, dan print receipt 58/80mm', () async {
    await service.setPaperSize(
      businessId: businessId,
      paperSize: ReceiptPaperSize.mm80,
    );
    await service.connect(businessId: businessId, device: port.devices.single);
    expect(port.connected, isTrue);
    await service.testPrint(businessId: businessId);
    await service.printSale(sale: sale, cashierName: 'Budi');
    expect(port.writes, hasLength(2));
    expect(port.writes.first.take(2), [0x1B, 0x40]);
    final PrinterProfile profile = await service.loadProfile(
      businessId: businessId,
    );
    expect(profile.paperSize, ReceiptPaperSize.mm80);
    expect(profile.deviceAddress, port.devices.single.address);
  });

  test('auto print mencetak setelah penjualan', () async {
    await service.connect(businessId: businessId, device: port.devices.single);
    await service.setAutoPrint(businessId: businessId, enabled: true);
    await service.afterSale(sale: sale, cashierName: 'Budi');
    expect(port.writes, hasLength(1));
  });

  test(
    'printer offline saat cetak memunculkan error, data tetap ada',
    () async {
      await service.connect(
        businessId: businessId,
        device: port.devices.single,
      );
      port.writeFails = true;
      await expectLater(
        service.printSale(sale: sale),
        throwsA(isA<PrinterException>()),
      );
      expect(
        (await service.loadProfile(businessId: businessId)).lastSaleId,
        isNull,
      );
    },
  );

  test('printer offline pada auto print tidak menghapus penjualan', () async {
    await service.connect(businessId: businessId, device: port.devices.single);
    await service.setAutoPrint(businessId: businessId, enabled: true);
    port.connectFails = true;
    port.connected = false;
    await expectLater(
      service.afterSale(sale: sale),
      throwsA(isA<PrinterException>()),
    );
    expect(
      (await service.loadProfile(businessId: businessId)).lastSaleId,
      sale.id,
    );
  });

  test('cetak ulang memakai struk terakhir', () async {
    await service.connect(businessId: businessId, device: port.devices.single);
    await service.afterSale(sale: sale);
    await service.reprintLast(businessId: businessId, cashierName: 'Budi');
    expect(port.writes, hasLength(1));
    expect(
      String.fromCharCodes(
        port.writes.single.where((int b) => b >= 32 && b < 127),
      ),
      contains('CETAK ULANG'),
    );
  });

  test(
    'disconnect memutus soket tanpa menghapus perangkat tersimpan',
    () async {
      await service.connect(
        businessId: businessId,
        device: port.devices.single,
      );
      await service.disconnect();
      expect(port.connected, isFalse);
      expect(
        (await service.loadProfile(businessId: businessId)).hasDevice,
        isTrue,
      );
    },
  );
}
