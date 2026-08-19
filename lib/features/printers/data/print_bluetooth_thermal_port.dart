import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/logging/app_logger.dart';
import 'package:kasir_dapur/features/printers/domain/bluetooth_printer_port.dart';
import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

final class PrintBluetoothThermalPort implements BluetoothPrinterPort {
  const PrintBluetoothThermalPort();

  Future<void> _ensureAccess() async {
    if (!Platform.isAndroid) {
      return;
    }
    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    if (statuses.values.any(
      (PermissionStatus status) => status.isPermanentlyDenied,
    )) {
      throw const PrinterException(
        'Izin Bluetooth ditolak. Aktifkan di pengaturan perangkat.',
      );
    }
    if (statuses.values.any((PermissionStatus status) => !status.isGranted)) {
      throw const PrinterException(
        'Izin Bluetooth diperlukan untuk mencetak struk.',
      );
    }
  }

  @override
  Future<bool> isBluetoothOn() {
    return _guard(() async {
      return PrintBluetoothThermal.bluetoothEnabled;
    });
  }

  @override
  Future<bool> isConnected() {
    return _guard(() async {
      return PrintBluetoothThermal.connectionStatus;
    });
  }

  @override
  Future<List<PrinterDevice>> pairedDevices() {
    return _guard(() async {
      await _ensureAccess();
      if (!await PrintBluetoothThermal.bluetoothEnabled) {
        throw const PrinterException(
          'Bluetooth nonaktif. Transaksi tetap tersimpan.',
        );
      }
      final List<BluetoothInfo> infos =
          await PrintBluetoothThermal.pairedBluetooths;
      return [
        for (final BluetoothInfo info in infos)
          PrinterDevice(name: info.name, address: info.macAdress),
      ];
    });
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    await _guard(() async {
      await _ensureAccess();
      if (!await PrintBluetoothThermal.bluetoothEnabled) {
        throw const PrinterException(
          'Bluetooth nonaktif. Transaksi tetap tersimpan.',
        );
      }
      final bool ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.address,
      );
      if (!ok) {
        throw const PrinterException(
          'Printer offline. Periksa daya dan jarak Bluetooth.',
        );
      }
    });
  }

  @override
  Future<void> disconnect() async {
    await _guard(() async {
      await PrintBluetoothThermal.disconnect;
    });
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    await _guard(() async {
      if (!await PrintBluetoothThermal.connectionStatus) {
        throw const PrinterException(
          'Printer offline. Transaksi tetap tersimpan.',
        );
      }
      final bool ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (!ok) {
        throw const PrinterException('Gagal mengirim struk ke printer.');
      }
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PrinterException {
      rethrow;
    } on MissingPluginException {
      throw const PrinterException(
        'Printer Bluetooth tidak tersedia di perangkat ini.',
      );
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Printer Bluetooth gagal',
        error: error,
        stackTrace: stackTrace,
      );
      throw const PrinterException(
        'Printer offline. Transaksi tetap tersimpan.',
      );
    }
  }
}
