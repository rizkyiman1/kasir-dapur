import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';
import 'package:kasir_dapur/features/printers/domain/printer_repository.dart';
import 'package:kasir_dapur/features/printers/domain/receipt_paper_size.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqlitePrinterRepository implements PrinterRepository {
  SqlitePrinterRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  @override
  Future<PrinterProfile> loadOrCreate({required String businessId}) async {
    final Database db = await _database.database;
    final rows = await db.query(
      DatabaseConstants.tablePrinterSettings,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
      orderBy: 'is_default DESC, updated_at DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return _map(rows.first);
    }
    final int now = _clock.nowEpochMs();
    final PrinterProfile created = PrinterProfile(
      id: _uuid.v4(),
      businessId: businessId,
      paperSize: ReceiptPaperSize.mm58,
      autoPrint: false,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert(DatabaseConstants.tablePrinterSettings, _row(created));
    return created;
  }

  @override
  Future<PrinterProfile> save(PrinterProfile profile) async {
    final int now = _clock.nowEpochMs();
    final PrinterProfile next = profile.copyWith(updatedAt: now);
    final Database db = await _database.database;
    final int changed = await db.update(
      DatabaseConstants.tablePrinterSettings,
      _row(next),
      where: 'id = ?',
      whereArgs: <Object>[profile.id],
    );
    if (changed == 0) {
      await db.insert(DatabaseConstants.tablePrinterSettings, _row(next));
    }
    return next;
  }

  Map<String, Object?> _row(PrinterProfile profile) {
    return <String, Object?>{
      'id': profile.id,
      'business_id': profile.businessId,
      'paper_size': profile.paperSize.storageValue,
      'device_name': profile.deviceName,
      'device_address': profile.deviceAddress,
      'is_default': profile.isDefault ? 1 : 0,
      'auto_print': profile.autoPrint ? 1 : 0,
      'last_sale_id': profile.lastSaleId,
      'created_at': profile.createdAt,
      'updated_at': profile.updatedAt,
    };
  }

  PrinterProfile _map(Map<String, Object?> row) {
    return PrinterProfile(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      paperSize: ReceiptPaperSize.parse(
        readString(row['paper_size'], field: 'paper_size'),
      ),
      deviceName: readStringOrNull(row['device_name']),
      deviceAddress: readStringOrNull(row['device_address']),
      autoPrint: readBoolInt(row['auto_print'], field: 'auto_print'),
      lastSaleId: readStringOrNull(row['last_sale_id']),
      isDefault: readBoolInt(row['is_default'], field: 'is_default'),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
    );
  }
}
