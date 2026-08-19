import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/features/settings/data/store_repository_impl.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/pos_fixture.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late SqliteStoreRepository stores;
  late String businessId;
  const ClockService clock = ClockService();

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_store_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    businessId = await insertBusiness(await database.database, clock: clock);
    stores = SqliteStoreRepository(
      database: database,
      clock: clock,
      documentsDirectory: () async => tempDir,
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'profil toko, default payment, receipt behavior, dan logo tersimpan',
    () async {
      StoreProfile profile = await stores.update(
        businessId: businessId,
        patch: const StoreProfilePatch(
          name: 'Warung Dapur Rasa',
          address: 'Depok',
          phone: '02112345678',
          receiptFooter: 'Terima kasih sudah belanja',
          defaultPayment: PaymentMethod.qris,
          receiptBehavior: ReceiptBehavior.auto,
        ),
      );
      expect(profile.name, 'Warung Dapur Rasa');
      expect(profile.address, 'Depok');
      expect(profile.phone, '02112345678');
      expect(profile.receiptFooter, 'Terima kasih sudah belanja');
      expect(profile.defaultPayment, PaymentMethod.qris);
      expect(profile.receiptBehavior, ReceiptBehavior.auto);

      final File source = File(p.join(tempDir.path, 'logo.jpg'));
      await source.writeAsBytes(const <int>[255, 216, 255, 217]);
      profile = await stores.saveLogo(
        businessId: businessId,
        sourcePath: source.path,
      );
      expect(profile.hasLogo, isTrue);
      expect(File(profile.logoPath!).existsSync(), isTrue);

      profile = await stores.clearLogo(businessId);
      expect(profile.hasLogo, isFalse);
    },
  );
}
