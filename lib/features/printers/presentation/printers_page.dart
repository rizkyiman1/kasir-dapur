import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';
import 'package:kasir_dapur/features/printers/domain/receipt_paper_size.dart';
import 'package:kasir_dapur/features/printers/presentation/printers_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/widgets/kd_button.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_section_card.dart';

class PrintersPage extends ConsumerStatefulWidget {
  const PrintersPage({super.key});

  @override
  ConsumerState<PrintersPage> createState() => _PrintersPageState();
}

class _PrintersPageState extends ConsumerState<PrintersPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PrinterProfile> profile = ref.watch(
      printerProfileProvider,
    );
    final AsyncValue<bool> bluetooth = ref.watch(printerBluetoothProvider);
    final AsyncValue<bool> connected = ref.watch(printerConnectionProvider);
    final AsyncValue<List<PrinterDevice>> devices = ref.watch(
      printerDevicesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _busy ? null : () => invalidatePrinters(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const KdLoadingView(message: 'Memuat printer...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Printer gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => invalidatePrinters(ref),
          );
        },
        data: (PrinterProfile current) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              KdSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kertas dan cetak',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final ReceiptPaperSize size
                            in ReceiptPaperSize.values)
                          ChoiceChip(
                            label: Text(size.label),
                            selected: current.paperSize == size,
                            onSelected: _busy
                                ? null
                                : (_) => unawaited(_setPaper(size)),
                          ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cetak otomatis'),
                      subtitle: const Text(
                        'Struk dicetak setelah pembayaran berhasil',
                      ),
                      value: current.autoPrint,
                      onChanged: _busy
                          ? null
                          : (bool value) => unawaited(_setAutoPrint(value)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KdSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bluetooth.asData?.value == true
                          ? 'Bluetooth aktif'
                          : 'Bluetooth nonaktif atau tidak tersedia',
                    ),
                    Text(
                      connected.asData?.value == true
                          ? 'Terhubung ke ${current.deviceName ?? current.deviceAddress ?? 'printer'}'
                          : current.hasDevice
                          ? 'Tersimpan: ${current.deviceName ?? current.deviceAddress}'
                          : 'Belum ada printer. Aplikasi tetap bisa dipakai.',
                    ),
                    const SizedBox(height: 8),
                    devices.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (Object error, StackTrace _) {
                        return Text(ErrorHandler.userMessage(error));
                      },
                      data: (List<PrinterDevice> items) {
                        if (items.isEmpty) {
                          return const KdEmptyState(
                            icon: Icons.print_disabled_outlined,
                            title: 'Tidak ada printer terpasang',
                            subtitle: 'Pasangkan printer thermal di pengaturan Bluetooth, lalu muat ulang. Kasir tetap berjalan tanpa printer.',
                          );
                        }
                        return Column(
                          children: [
                            for (final PrinterDevice device in items)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  current.deviceAddress == device.address
                                      ? Icons.print
                                      : Icons.print_outlined,
                                ),
                                title: Text(device.name),
                                subtitle: Text(device.address),
                                trailing:
                                    current.deviceAddress == device.address
                                    ? const Text('Dipilih')
                                    : null,
                                onTap: _busy
                                    ? null
                                    : () => unawaited(_connect(device)),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    KdButton(
                      label: 'Putuskan',
                      icon: Icons.link_off,
                      onPressed: _busy ? null : () => unawaited(_disconnect()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KdSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cetak',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    KdButton(
                      label: 'Tes cetak',
                      icon: Icons.receipt_long_outlined,
                      loading: _busy,
                      onPressed: _busy ? null : () => unawaited(_testPrint()),
                    ),
                    const SizedBox(height: 8),
                    KdButton(
                      label: 'Cetak ulang struk terakhir',
                      icon: Icons.replay,
                      onPressed: _busy ? null : () => unawaited(_reprint()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Jika printer offline, transaksi tetap tersimpan di kasir.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const KdLegalFooter(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        context.showMessage(success);
        invalidatePrinters(ref);
      }
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setPaper(ReceiptPaperSize size) {
    return _run(() async {
      final String businessId = await ref.read(activeBusinessIdProvider.future);
      await printerOf(ref)
          .setPaperSize(businessId: businessId, paperSize: size);
    }, 'Ukuran kertas ${size.label}');
  }

  Future<void> _setAutoPrint(bool enabled) {
    return _run(() async {
      final String businessId = await ref.read(activeBusinessIdProvider.future);
      await printerOf(ref)
          .setAutoPrint(businessId: businessId, enabled: enabled);
    }, enabled ? 'Cetak otomatis aktif' : 'Cetak otomatis nonaktif');
  }

  Future<void> _connect(PrinterDevice device) {
    return _run(() async {
      final String businessId = await ref.read(activeBusinessIdProvider.future);
      await printerOf(ref).connect(businessId: businessId, device: device);
    }, 'Terhubung ke ${device.name}');
  }

  Future<void> _disconnect() {
    return _run(() => printerOf(ref).disconnect(), 'Printer diputus');
  }

  Future<void> _testPrint() {
    return _run(() async {
      final String businessId = await ref.read(activeBusinessIdProvider.future);
      await printerOf(ref).testPrint(businessId: businessId);
    }, 'Tes cetak dikirim');
  }

  Future<void> _reprint() {
    return _run(() async {
      final String businessId = await ref.read(activeBusinessIdProvider.future);
      final String? cashierName = ref
          .read(authControllerProvider)
          .user
          ?.displayName;
      await printerOf(ref)
          .reprintLast(businessId: businessId, cashierName: cashierName);
    }, 'Struk terakhir dicetak ulang');
  }
}
