import 'dart:io';

import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';
import 'package:kasir_dapur/features/settings/domain/store_repository.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqliteStoreRepository implements StoreRepository {
  SqliteStoreRepository({
    required this._database,
    required this._clock,
    required this._documentsDirectory,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Future<Directory> Function() _documentsDirectory;
  final Uuid _uuid;

  @override
  Future<StoreProfile> getByBusinessId(String businessId) async {
    final Database db = await _database.database;
    return _read(db, businessId);
  }

  @override
  Future<StoreProfile> update({
    required String businessId,
    required StoreProfilePatch patch,
  }) async {
    if (patch.name != null) {
      final String? error = AppValidators.displayName(patch.name);
      if (error != null) {
        throw ValidationException(error);
      }
    }
    if (patch.phone != null && !patch.clearPhone) {
      final String? error = AppValidators.optionalPhone(patch.phone);
      if (error != null) {
        throw ValidationException(error);
      }
    }
    if (patch.address != null && !patch.clearAddress) {
      final String? error = AppValidators.optionalText(
        patch.address,
        maxLength: 200,
        fieldName: 'Alamat',
      );
      if (error != null) {
        throw ValidationException(error);
      }
    }
    if (patch.receiptFooter != null && !patch.clearFooter) {
      final String? error = AppValidators.optionalText(
        patch.receiptFooter,
        maxLength: 240,
        fieldName: 'Footer receipt',
      );
      if (error != null) {
        throw ValidationException(error);
      }
    }

    final Database db = await _database.database;
    final StoreProfile current = await _read(db, businessId);
    final int now = _clock.nowEpochMs();

    final String name = patch.name?.trim() ?? current.name;
    final String? address = _optionalText(
      incoming: patch.address,
      current: current.address,
      clear: patch.clearAddress,
    );
    final String? phone = _optionalText(
      incoming: patch.phone,
      current: current.phone,
      clear: patch.clearPhone,
    );
    final String? footer = _optionalText(
      incoming: patch.receiptFooter,
      current: current.receiptFooter,
      clear: patch.clearFooter,
    );
    final String? logoPath = patch.clearLogo
        ? null
        : (patch.logoPath ?? current.logoPath);
    final PaymentMethod payment =
        patch.defaultPayment ?? current.defaultPayment;
    final ReceiptBehavior behavior =
        patch.receiptBehavior ?? current.receiptBehavior;

    await _database.runInTransaction((txn) async {
      await txn.update(
        DatabaseConstants.tableBusinesses,
        <String, Object?>{
          'name': name,
          'address': address,
          'phone': phone,
          'logo_path': logoPath,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object>[businessId],
      );
      await _upsertSettings(
        txn,
        businessId: businessId,
        receiptFooter: footer,
        defaultPayment: payment,
        receiptBehavior: behavior,
        now: now,
      );
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: businessId,
        aggregate: SyncAggregate.business,
        entityId: businessId,
      );
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: businessId,
        aggregate: SyncAggregate.settings,
        entityId: businessId,
      );
    });
    if (patch.clearLogo && current.logoPath != null) {
      await _deleteFile(current.logoPath!);
    }
    return _read(db, businessId);
  }

  @override
  Future<StoreProfile> saveLogo({
    required String businessId,
    required String sourcePath,
  }) async {
    final File source = File(sourcePath);
    if (!source.existsSync()) {
      throw const ValidationException('Berkas logo tidak ditemukan');
    }
    final Directory documents = await _documentsDirectory();
    final Directory logos = Directory(p.join(documents.path, 'logos'));
    if (!logos.existsSync()) {
      await logos.create(recursive: true);
    }
    final String ext = p.extension(sourcePath).toLowerCase();
    final String suffix = ext == '.png' || ext == '.webp' || ext == '.jpg'
        ? ext
        : '.jpg';
    final String destPath = p.join(logos.path, '$businessId$suffix');
    await source.copy(destPath);
    final StoreProfile current = await getByBusinessId(businessId);
    if (current.logoPath != null && current.logoPath != destPath) {
      await _deleteFile(current.logoPath!);
    }
    return update(
      businessId: businessId,
      patch: StoreProfilePatch(logoPath: destPath),
    );
  }

  @override
  Future<StoreProfile> clearLogo(String businessId) {
    return update(
      businessId: businessId,
      patch: const StoreProfilePatch(clearLogo: true),
    );
  }

  Future<StoreProfile> _read(DatabaseExecutor db, String businessId) async {
    final rows = await db.query(
      DatabaseConstants.tableBusinesses,
      where: 'id = ?',
      whereArgs: <Object>[businessId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const NotFoundException('Toko tidak ditemukan');
    }
    final Map<String, Object?> business = rows.first;
    final settings = await db.query(
      DatabaseConstants.tableBusinessSettings,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
      limit: 1,
    );
    final Map<String, Object?>? setting = settings.isEmpty
        ? null
        : settings.first;
    PaymentMethod payment = PaymentMethod.cash;
    try {
      payment = PaymentMethod.parse(
        readStringOrNull(setting?['default_payment']) ?? 'cash',
      );
    } catch (_) {
      payment = PaymentMethod.cash;
    }
    return StoreProfile(
      id: readString(business['id'], field: 'id'),
      name: readString(business['name'], field: 'name'),
      address: readStringOrNull(business['address']),
      phone: readStringOrNull(business['phone']),
      logoPath: readStringOrNull(business['logo_path']),
      receiptFooter: readStringOrNull(setting?['receipt_footer']),
      defaultPayment: payment,
      receiptBehavior: ReceiptBehavior.parse(
        readStringOrNull(setting?['receipt_behavior']),
      ),
    );
  }

  Future<void> _upsertSettings(
    DatabaseExecutor db, {
    required String businessId,
    required String? receiptFooter,
    required PaymentMethod defaultPayment,
    required ReceiptBehavior receiptBehavior,
    required int now,
  }) async {
    await db.execute(
      '''
INSERT INTO ${DatabaseConstants.tableBusinessSettings} (
  id, business_id, currency_code, receipt_footer, default_payment,
  receipt_behavior, created_at, updated_at
) VALUES (?, ?, 'IDR', ?, ?, ?, ?, ?)
ON CONFLICT(business_id) DO UPDATE SET
  receipt_footer = excluded.receipt_footer,
  default_payment = excluded.default_payment,
  receipt_behavior = excluded.receipt_behavior,
  updated_at = excluded.updated_at
''',
      <Object?>[
        _uuid.v4(),
        businessId,
        receiptFooter,
        defaultPayment.storageValue,
        receiptBehavior.storageValue,
        now,
        now,
      ],
    );
  }

  String? _optionalText({
    required String? incoming,
    required String? current,
    required bool clear,
  }) {
    if (clear) {
      return null;
    }
    if (incoming == null) {
      return current;
    }
    final String trimmed = incoming.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _deleteFile(String path) async {
    final File file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
