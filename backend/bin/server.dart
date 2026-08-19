import 'dart:io';

import 'package:kasir_dapur_backend/config/backend_config.dart';
import 'package:kasir_dapur_backend/config/brand.dart';
import 'package:kasir_dapur_backend/runtime.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> args) async {
  final BackendConfig config = BackendConfig.fromMap(loadProcessEnv());
  config.validateProductionSecrets();
  final BackendRuntime runtime = BackendRuntime.production(config);
  await runtime.startupReconcile();
  final HttpServer server = await shelf_io.serve(
    runtime.handler,
    InternetAddress.anyIPv4,
    config.port,
  );
  stderr.writeln(
    '${Brand.appName} backend ${Brand.companyName} '
    'mendengar di http://${server.address.host}:${server.port} '
    '(Midtrans ${config.midtrans.environment.name.toUpperCase()}, '
    'configured=${config.midtrans.isConfigured})',
  );
  ProcessSignal.sigint.watch().listen((_) async {
    runtime.close();
    await server.close(force: true);
    exit(0);
  });
}
