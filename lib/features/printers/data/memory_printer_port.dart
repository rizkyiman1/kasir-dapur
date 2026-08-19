import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/printers/domain/bluetooth_printer_port.dart';
import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';

/// Port tes: tidak menyentuh Bluetooth sungguhan.
final class MemoryBluetoothPrinterPort implements BluetoothPrinterPort {
  MemoryBluetoothPrinterPort({
    this.bluetoothOn = true,
    this.connected = false,
    List<PrinterDevice>? devices,
    this.connectFails = false,
    this.writeFails = false,
  }) : devices = List<PrinterDevice>.from(
         devices ??
             const [
               PrinterDevice(
                 name: 'Kasir Dapur Printer',
                 address: '00:11:22:33:44:55',
               ),
             ],
       );

  bool bluetoothOn;
  bool connected;
  bool connectFails;
  bool writeFails;
  final List<PrinterDevice> devices;
  final List<List<int>> writes = [];
  PrinterDevice? lastConnected;

  @override
  Future<bool> isBluetoothOn() async => bluetoothOn;

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<List<PrinterDevice>> pairedDevices() async {
    if (!bluetoothOn) {
      throw const PrinterException(
        'Bluetooth nonaktif. Transaksi tetap tersimpan.',
      );
    }
    return List<PrinterDevice>.unmodifiable(devices);
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    if (!bluetoothOn || connectFails) {
      throw const PrinterException(
        'Printer offline. Periksa daya dan jarak Bluetooth.',
      );
    }
    lastConnected = device;
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    if (!connected || writeFails) {
      throw const PrinterException(
        'Printer offline. Transaksi tetap tersimpan.',
      );
    }
    writes.add(List<int>.from(bytes));
  }
}
