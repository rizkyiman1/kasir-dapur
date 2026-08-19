import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';

/// Abstraksi Bluetooth SPP. Tes memakai port memori, produksi memakai plugin.
abstract class BluetoothPrinterPort {
  Future<bool> isBluetoothOn();

  Future<bool> isConnected();

  Future<List<PrinterDevice>> pairedDevices();

  Future<void> connect(PrinterDevice device);

  Future<void> disconnect();

  Future<void> writeBytes(List<int> bytes);
}
