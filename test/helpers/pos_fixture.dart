import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

Future<String> insertBusiness(
  Database db, {
  required ClockService clock,
  String name = 'Dapur Rasa',
}) async {
  final String id = const Uuid().v4();
  final int now = clock.nowEpochMs();
  await db.insert(DatabaseConstants.tableBusinesses, <String, Object>{
    'id': id,
    'name': name,
    'legal_name': 'PT Dapur Rasa Karya Nusantara',
    'status': 'active',
    'created_at': now,
    'updated_at': now,
  });
  return id;
}
