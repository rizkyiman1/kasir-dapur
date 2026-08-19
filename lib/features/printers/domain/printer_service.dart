import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/logging/app_logger.dart';
import 'package:kasir_dapur/features/cashier/domain/receipt_formatter.dart';
import 'package:kasir_dapur/features/printers/domain/bluetooth_printer_port.dart';
import 'package:kasir_dapur/features/printers/domain/esc_pos_encoder.dart';
import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';
import 'package:kasir_dapur/features/printers/domain/printer_repository.dart';
import 'package:kasir_dapur/features/printers/domain/receipt_paper_size.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';
import 'package:kasir_dapur/features/settings/domain/store_repository.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/features/transactions/domain/transaction_repository.dart';

final class PrinterService {
  const PrinterService({
    required PrinterRepository repository,
    required BluetoothPrinterPort port,
    required TransactionRepository transactions,
    StoreRepository? storeRepository,
  }) : _repository = repository,
       _port = port,
       _transactions = transactions,
       _storeRepository = storeRepository;

  final PrinterRepository _repository;
  final BluetoothPrinterPort _port;
  final TransactionRepository _transactions;
  final StoreRepository? _storeRepository;

  Future<PrinterProfile> loadProfile({required String businessId}) {
    return _repository.loadOrCreate(businessId: businessId);
  }

  Future<PrinterProfile> setPaperSize({
    required String businessId,
    required ReceiptPaperSize paperSize,
  }) async {
    final PrinterProfile profile = await _repository.loadOrCreate(
      businessId: businessId,
    );
    return _repository.save(profile.copyWith(paperSize: paperSize));
  }

  Future<PrinterProfile> setAutoPrint({
    required String businessId,
    required bool enabled,
  }) async {
    final PrinterProfile profile = await _repository.loadOrCreate(
      businessId: businessId,
    );
    return _repository.save(profile.copyWith(autoPrint: enabled));
  }

  Future<bool> isBluetoothOn() => _port.isBluetoothOn();

  Future<bool> isConnected() => _port.isConnected();

  Future<List<PrinterDevice>> pairedDevices() => _port.pairedDevices();

  Future<PrinterProfile> connect({
    required String businessId,
    required PrinterDevice device,
  }) async {
    await _port.connect(device);
    final PrinterProfile profile = await _repository.loadOrCreate(
      businessId: businessId,
    );
    return _repository.save(
      profile.copyWith(deviceName: device.name, deviceAddress: device.address),
    );
  }

  Future<void> disconnect() => _port.disconnect();

  Future<void> testPrint({required String businessId}) async {
    final PrinterProfile profile = await _ensureDevice(businessId);
    await _ensureReady(profile);
    await _port.writeBytes(
      EscPosEncoder.encodeLines(
        ReceiptFormatter.testPage(paperSize: profile.paperSize),
      ),
    );
  }

  Future<void> printSale({
    required Sale sale,
    String? cashierName,
    String? customerName,
    bool reprint = false,
  }) async {
    final PrinterProfile profile = await _ensureDevice(sale.businessId);
    await _ensureReady(profile);
    await _port.writeBytes(
      EscPosEncoder.encodeLines(
        ReceiptFormatter.linesFromSale(
          sale,
          paperSize: profile.paperSize,
          cashierName: cashierName,
          customerName: customerName,
          reprint: reprint,
          store: await _storeInfo(sale.businessId),
        ),
      ),
    );
    await _repository.save(profile.copyWith(lastSaleId: sale.id));
  }

  Future<void> reprintLast({
    required String businessId,
    String? cashierName,
  }) async {
    final PrinterProfile profile = await _repository.loadOrCreate(
      businessId: businessId,
    );
    final String? saleId = profile.lastSaleId;
    if (saleId == null || saleId.isEmpty) {
      throw const PrinterException('Belum ada struk untuk dicetak ulang.');
    }
    final Sale? sale = await _transactions.getById(saleId);
    if (sale == null) {
      throw const PrinterException('Struk terakhir tidak ditemukan.');
    }
    await printSale(sale: sale, cashierName: cashierName, reprint: true);
  }

  /// Menyimpan id penjualan. Jika auto print aktif, mencetak.
  /// Kegagalan printer tidak membatalkan transaksi pemanggil.
  Future<void> afterSale({
    required Sale sale,
    String? cashierName,
    String? customerName,
  }) async {
    final PrinterProfile remembered = await _repository.loadOrCreate(
      businessId: sale.businessId,
    );
    await _repository.save(remembered.copyWith(lastSaleId: sale.id));
    if (!remembered.autoPrint || !remembered.hasDevice) {
      return;
    }
    try {
      await printSale(
        sale: sale,
        cashierName: cashierName,
        customerName: customerName,
      );
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Cetak otomatis gagal',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is PrinterException) {
        rethrow;
      }
      throw const PrinterException(
        'Printer offline. Transaksi tetap tersimpan.',
      );
    }
  }

  Future<PrinterProfile> _ensureDevice(String businessId) async {
    final PrinterProfile profile = await _repository.loadOrCreate(
      businessId: businessId,
    );
    if (!profile.hasDevice) {
      throw const PrinterException(
        'Belum ada printer. Transaksi tetap tersimpan.',
      );
    }
    return profile;
  }

  Future<void> _ensureReady(PrinterProfile profile) async {
    final bool bluetoothOn = await _port.isBluetoothOn();
    if (!bluetoothOn) {
      throw const PrinterException(
        'Bluetooth nonaktif. Transaksi tetap tersimpan.',
      );
    }
    if (await _port.isConnected()) {
      return;
    }
    final String? address = profile.deviceAddress;
    if (address == null || address.trim().isEmpty) {
      // Seharusnya tidak terjadi karena _ensureDevice sudah memeriksa hasDevice,
      // tapi guard ini mencegah crash jika state tidak konsisten.
      throw const PrinterException(
        'Alamat printer tidak ditemukan. Konfigurasi ulang printer.',
      );
    }
    await _port.connect(
      PrinterDevice(name: profile.deviceName ?? 'Printer', address: address),
    );
  }

  Future<ReceiptStoreInfo?> _storeInfo(String businessId) async {
    final StoreRepository? stores = _storeRepository;
    if (stores == null) {
      return null;
    }
    try {
      final StoreProfile profile = await stores.getByBusinessId(businessId);
      return ReceiptStoreInfo(
        name: profile.receiptName,
        address: profile.address,
        phone: profile.phone,
        footer: profile.receiptFooter,
      );
    } catch (error, stack) {
      AppLogger.instance.error(
        '_storeInfo: gagal memuat profil toko',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }
}
