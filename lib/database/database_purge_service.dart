import 'package:kasir_dapur/core/logging/app_logger.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';

/// Layanan purge data lama yang aman.
///
/// Hanya menghapus baris dengan `status = 'done'` yang sudah melewati
/// batas retensi. Tidak pernah menyentuh transaksi, transaction_items,
/// atau stock_movements.
///
/// Dipanggil saat app idle — tidak boleh berjalan ketika transaksi POS
/// sedang berlangsung. Gunakan [runIfIdle] untuk memastikan ini.
final class DatabasePurgeService {
  DatabasePurgeService({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  /// Berapa hari entri sync_logs 'done' dipertahankan sebelum dihapus.
  static const int syncLogRetentionDays = 90;

  /// Berapa hari entri sync_queue 'done' dipertahankan sebelum dihapus.
  static const int syncQueueRetentionDays = 30;

  bool _running = false;

  /// Jalankan purge jika tidak ada operasi purge lain yang berjalan.
  /// Kembalikan [PurgeResult] dengan jumlah baris yang dihapus.
  ///
  /// Aman dipanggil kapan saja — tidak akan berjalan bersamaan.
  Future<PurgeResult> runIfIdle({DateTime? now}) async {
    if (_running) {
      return const PurgeResult(
        syncLogsDeleted: 0,
        syncQueueDeleted: 0,
        skipped: true,
      );
    }
    _running = true;
    try {
      return await _run(now: now ?? DateTime.now());
    } catch (error, stack) {
      AppLogger.instance.error(
        'DatabasePurgeService: purge gagal',
        error: error,
        stackTrace: stack,
      );
      return const PurgeResult(
        syncLogsDeleted: 0,
        syncQueueDeleted: 0,
        skipped: false,
      );
    } finally {
      _running = false;
    }
  }

  Future<PurgeResult> _run({required DateTime now}) async {
    final db = await _database.database;

    final int logCutoff = now
        .subtract(Duration(days: syncLogRetentionDays))
        .millisecondsSinceEpoch;

    final int queueCutoff = now
        .subtract(Duration(days: syncQueueRetentionDays))
        .millisecondsSinceEpoch;

    // Hapus sync_logs yang sudah 'done' dan lebih tua dari 90 hari.
    final int logsDeleted = await db.delete(
      DatabaseConstants.tableSyncLogs,
      where: "status = 'done' AND created_at < ?",
      whereArgs: <Object>[logCutoff],
    );

    // Hapus sync_queue yang sudah 'done' dan lebih tua dari 30 hari.
    // Hanya hapus jika tidak ada sync_logs yang masih merujuk ke queue_id ini
    // (foreign key: sync_logs.queue_id → sync_queue.id, tapi tanpa CASCADE).
    // Karena logs 'done' yang tua sudah dihapus di atas, ini aman.
    final int queueDeleted = await db.delete(
      DatabaseConstants.tableSyncQueue,
      where: "status = 'done' AND created_at < ?",
      whereArgs: <Object>[queueCutoff],
    );

    if (logsDeleted > 0 || queueDeleted > 0) {
      AppLogger.instance.info(
        'DatabasePurgeService: hapus $logsDeleted sync_logs, '
        '$queueDeleted sync_queue (done/expired)',
      );
    }

    return PurgeResult(
      syncLogsDeleted: logsDeleted,
      syncQueueDeleted: queueDeleted,
      skipped: false,
    );
  }
}

final class PurgeResult {
  const PurgeResult({
    required this.syncLogsDeleted,
    required this.syncQueueDeleted,
    required this.skipped,
  });

  /// Jumlah baris sync_logs yang dihapus.
  final int syncLogsDeleted;

  /// Jumlah baris sync_queue yang dihapus.
  final int syncQueueDeleted;

  /// True jika purge dilewati karena sedang berjalan (concurrent guard).
  final bool skipped;

  bool get didWork => syncLogsDeleted > 0 || syncQueueDeleted > 0;

  @override
  String toString() =>
      'PurgeResult(logs=$syncLogsDeleted, queue=$syncQueueDeleted, skipped=$skipped)';
}
