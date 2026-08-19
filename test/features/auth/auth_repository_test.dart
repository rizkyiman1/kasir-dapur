import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/security/pin_hasher.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/auth/data/auth_repository_impl.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late SqliteAuthRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_auth_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    repository = SqliteAuthRepository(
      database: database,
      clock: const ClockService(),
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('registrasi owner memakai hash aman, bukan PIN polos', () async {
    expect(await repository.hasLocalUser(), isFalse);

    final AuthUser user = await repository.registerOwner(
      displayName: 'Budi',
      pin: '123456',
    );
    expect(user.role, UserRole.owner);
    expect(await repository.hasLocalUser(), isTrue);
    expect(await repository.authenticate(pin: '000000'), isNull);
    expect(await repository.authenticate(pin: '123456'), isNotNull);

    final db = await database.database;
    final rows = await db.query(DatabaseConstants.tableLocalUsers);
    expect(rows, hasLength(1));
    expect(rows.first['pin_hash'], isNot('123456'));
    expect(rows.first['pin_hash'], isNot(contains('123456')));
    expect(rows.first['pin_algo'], PinHasher.currentAlgorithm);
    expect(rows.first['pin_salt'], isNotEmpty);
  });

  test('login salah PIN ditolak dan multi-user membutuhkan userId', () async {
    final AuthUser owner = await repository.registerOwner(
      displayName: 'Budi',
      pin: '123456',
    );
    final AuthUser cashier = await repository.createUser(
      displayName: 'Cici',
      pin: '234567',
      role: UserRole.cashier,
    );

    expect(
      await repository.authenticate(pin: '111111', userId: owner.id),
      isNull,
    );
    expect(
      await repository.authenticate(pin: '123456', userId: owner.id),
      isNotNull,
    );
    expect(
      await repository.authenticate(pin: '234567', userId: cashier.id),
      isNotNull,
    );
    expect(
      await repository.authenticate(pin: '123456', userId: cashier.id),
      isNull,
    );
  });

  test(
    'hash lama sha256-iter diverifikasi lalu di-upgrade ke PBKDF2',
    () async {
      await repository.registerOwner(displayName: 'Budi', pin: '123456');
      final db = await database.database;
      final PinHasher hasher = PinHasher();
      const String salt = 'legacy-salt';
      final String legacyHash = hasher.hash(
        pin: '123456',
        salt: salt,
        algorithm: PinHasher.algorithmLegacySha256,
      );
      await db.update(DatabaseConstants.tableLocalUsers, <String, Object>{
        'pin_salt': salt,
        'pin_hash': legacyHash,
        'pin_algo': PinHasher.algorithmLegacySha256,
      });

      expect(await repository.authenticate(pin: '123456'), isNotNull);
      final rows = await db.query(DatabaseConstants.tableLocalUsers);
      expect(rows.first['pin_algo'], PinHasher.currentAlgorithm);
      expect(rows.first['pin_hash'], isNot(legacyHash));
      expect(await repository.authenticate(pin: '123456'), isNotNull);
    },
  );

  test('ganti PIN dan hapus akun perangkat tidak men-DROP tabel', () async {
    final AuthUser owner = await repository.registerOwner(
      displayName: 'Budi',
      pin: '123456',
    );
    await repository.createUser(
      displayName: 'Cici',
      pin: '234567',
      role: UserRole.cashier,
    );
    await repository.changePin(
      userId: owner.id,
      currentPin: '123456',
      newPin: '654321',
    );
    expect(
      await repository.authenticate(pin: '123456', userId: owner.id),
      isNull,
    );
    expect(
      await repository.authenticate(pin: '654321', userId: owner.id),
      isNotNull,
    );

    await repository.deleteAllLocalUsers();
    expect(await repository.hasLocalUser(), isFalse);
    final db = await database.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = '${DatabaseConstants.tableLocalUsers}'",
    );
    expect(tables, isNotEmpty);
  });
}
