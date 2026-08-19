import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/logging/app_logger.dart';
import 'package:kasir_dapur/core/security/pin_hasher.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/auth/domain/auth_repository.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqliteAuthRepository implements AuthRepository {
  SqliteAuthRepository({
    required this._database,
    required this._clock,
    PinHasher? pinHasher,
    Uuid? uuid,
  }) : _pinHasher = pinHasher ?? PinHasher(),
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final PinHasher _pinHasher;
  final Uuid _uuid;

  @override
  Future<AuthUser?> getById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      DatabaseConstants.tableLocalUsers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapUser(rows.first);
  }

  @override
  Future<List<AuthUser>> listUsers() async {
    final db = await _database.database;
    final rows = await db.query(
      DatabaseConstants.tableLocalUsers,
      orderBy: 'created_at ASC',
    );
    return rows.map(_mapUser).toList();
  }

  @override
  Future<bool> hasLocalUser() async {
    final List<AuthUser> users = await listUsers();
    return users.isNotEmpty;
  }

  @override
  Future<AuthUser> registerOwner({
    required String displayName,
    required String pin,
  }) async {
    _validateProfile(displayName: displayName, pin: pin);
    if (await hasLocalUser()) {
      throw const AuthException('Akun perangkat ini sudah terdaftar.');
    }
    return _insertUser(
      displayName: displayName.trim(),
      pin: pin,
      role: UserRole.owner,
    );
  }

  @override
  Future<AuthUser> createUser({
    required String displayName,
    required String pin,
    required UserRole role,
  }) async {
    if (role == UserRole.owner) {
      throw const ValidationException(
        'Owner hanya dibuat saat onboarding perangkat.',
      );
    }
    _validateProfile(displayName: displayName, pin: pin);
    if (!await hasLocalUser()) {
      throw const AuthException('Buat akun Owner terlebih dahulu.');
    }
    return _insertUser(displayName: displayName.trim(), pin: pin, role: role);
  }

  @override
  Future<AuthUser?> authenticate({required String pin, String? userId}) async {
    final db = await _database.database;
    final Map<String, Object?>? row = await _resolveUserRow(db, userId: userId);
    if (row == null) {
      return null;
    }
    final String salt = row['pin_salt']! as String;
    final String expectedHash = row['pin_hash']! as String;
    final String algorithm =
        (row['pin_algo'] as String?) ?? PinHasher.algorithmLegacySha256;
    final bool ok = _pinHasher.verify(
      pin: pin,
      salt: salt,
      expectedHash: expectedHash,
      algorithm: algorithm,
    );
    if (!ok) {
      AppLogger.instance.warning('Autentikasi PIN ditolak');
      return null;
    }
    final AuthUser user = _mapUser(row);
    if (algorithm != PinHasher.currentAlgorithm) {
      await _rehashPin(db, userId: user.id, pin: pin);
    }
    return user;
  }

  @override
  Future<void> changePin({
    required String userId,
    required String currentPin,
    required String newPin,
  }) async {
    final String? pinError = AppValidators.pin(newPin);
    if (pinError != null) {
      throw ValidationException(pinError);
    }
    final AuthUser? matched = await authenticate(
      pin: currentPin,
      userId: userId,
    );
    if (matched == null) {
      throw const AuthException('PIN saat ini tidak sesuai');
    }
    final Database db = await _database.database;
    await _rehashPin(db, userId: userId, pin: newPin);
  }

  @override
  Future<void> deleteAllLocalUsers() async {
    final Database db = await _database.database;
    await db.delete(DatabaseConstants.tableLocalSessions);
    await db.delete(DatabaseConstants.tableLocalUsers);
    AppLogger.instance.info('Akun perangkat dihapus dari SQLite lokal');
  }

  void _validateProfile({required String displayName, required String pin}) {
    final String? nameError = AppValidators.displayName(displayName);
    if (nameError != null) {
      throw ValidationException(nameError);
    }
    final String? pinError = AppValidators.pin(pin);
    if (pinError != null) {
      throw ValidationException(pinError);
    }
  }

  Future<AuthUser> _insertUser({
    required String displayName,
    required String pin,
    required UserRole role,
  }) async {
    final String salt = _pinHasher.generateSalt();
    final String hash = _pinHasher.hash(pin: pin, salt: salt);
    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    final AuthUser user = AuthUser(
      id: id,
      displayName: displayName,
      role: role,
    );

    final db = await _database.database;
    await db.insert(DatabaseConstants.tableLocalUsers, <String, Object>{
      'id': user.id,
      'display_name': user.displayName,
      'role': user.role.name,
      'pin_salt': salt,
      'pin_hash': hash,
      'pin_algo': PinHasher.currentAlgorithm,
      'created_at': now,
      'updated_at': now,
    });
    AppLogger.instance.info('Pengguna lokal ${user.role.name} disimpan');
    return user;
  }

  Future<Map<String, Object?>?> _resolveUserRow(
    Database db, {
    String? userId,
  }) async {
    if (userId != null) {
      final rows = await db.query(
        DatabaseConstants.tableLocalUsers,
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    }
    final rows = await db.query(
      DatabaseConstants.tableLocalUsers,
      orderBy: 'created_at ASC',
    );
    if (rows.isEmpty) {
      return null;
    }
    if (rows.length > 1) {
      throw const ValidationException('Pilih pengguna terlebih dahulu.');
    }
    return rows.first;
  }

  Future<void> _rehashPin(
    Database db, {
    required String userId,
    required String pin,
  }) async {
    final String salt = _pinHasher.generateSalt();
    final String hash = _pinHasher.hash(pin: pin, salt: salt);
    await db.update(
      DatabaseConstants.tableLocalUsers,
      <String, Object>{
        'pin_salt': salt,
        'pin_hash': hash,
        'pin_algo': PinHasher.currentAlgorithm,
        'updated_at': _clock.nowEpochMs(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  AuthUser _mapUser(Map<String, Object?> row) {
    return AuthUser(
      id: row['id']! as String,
      displayName: row['display_name']! as String,
      role: UserRole.fromStorage(row['role']! as String),
    );
  }
}
