import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';

abstract class PrinterRepository {
  Future<PrinterProfile> loadOrCreate({required String businessId});

  Future<PrinterProfile> save(PrinterProfile profile);
}
