import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/app/app.dart';
import 'package:kasir_dapur/config/env.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/logging/app_logger.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final EnvConfig env = EnvConfig.fromDartDefine();
  AppLogger.init(verbose: env.enableVerboseLog);
  ErrorHandler.install();
  await initializeDateFormatting('id_ID');
  AppLogger.instance.info('Menjalankan Kasir Dapur (${env.environment.name})');
  runApp(const ProviderScope(child: KasirDapurApp()));
}
