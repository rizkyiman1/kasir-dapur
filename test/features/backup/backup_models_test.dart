import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';

void main() {
  test('corrupted payload tetap ter-parse aman', () {
    final BackupSnapshot snapshot = BackupSnapshot.fromJson(<String, Object?>{
      'business_id': 'biz-1',
      'created_at': 123,
      'tables': <String, Object?>{
        'products': <Object?>[
          <String, Object?>{'id': 'p1', 'name': 'Nasi'},
          'invalid-row',
          42,
        ],
      },
    });

    expect(snapshot.businessId, 'biz-1');
    expect(snapshot.tables['products'], isNotNull);
    expect(snapshot.tables['products']!.first['id'], 'p1');
    expect(snapshot.tables['products']![1], isEmpty);
  });
}
