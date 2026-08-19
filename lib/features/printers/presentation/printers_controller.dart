import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';
import 'package:kasir_dapur/features/printers/domain/printer_service.dart';

final printerProfileProvider = FutureProvider<PrinterProfile>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(printerServiceProvider).loadProfile(businessId: businessId);
});

final printerConnectionProvider = FutureProvider<bool>((Ref ref) async {
  ref.watch(printerProfileProvider);
  return ref.watch(printerServiceProvider).isConnected();
});

final printerBluetoothProvider = FutureProvider<bool>((Ref ref) {
  return ref.watch(printerServiceProvider).isBluetoothOn();
});

final printerDevicesProvider = FutureProvider<List<PrinterDevice>>((
  Ref ref,
) async {
  ref.watch(printerProfileProvider);
  return ref.watch(printerServiceProvider).pairedDevices();
});

PrinterService printerOf(WidgetRef ref) => ref.read(printerServiceProvider);

void invalidatePrinters(WidgetRef ref) {
  ref
    ..invalidate(printerProfileProvider)
    ..invalidate(printerConnectionProvider)
    ..invalidate(printerBluetoothProvider)
    ..invalidate(printerDevicesProvider);
}
