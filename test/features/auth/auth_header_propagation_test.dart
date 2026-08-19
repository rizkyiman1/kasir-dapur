import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/features/backup/data/backup_gateway.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';
import 'package:kasir_dapur/features/subscription/data/http_billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/sync/data/cloud_sync_gateway.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';

void main() {
  test('gateway billing/backup/sync mengirim Bearer token saat tersedia', () async {
    final List<String?> authHeaders = <String?>[];
    final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));
    server.listen((HttpRequest request) async {
      authHeaders.add(request.headers.value(HttpHeaders.authorizationHeader));
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/v1/billing/checkout') {
        request.response.write(
          jsonEncode(<String, Object>{
            'order_id': 'ORD-1',
            'plan_code': 'PRO_MONTHLY',
            'amount': 49000,
            'snap_token': 'snap',
            'snap_redirect_url': 'https://example.test/pay',
          }),
        );
      } else if (request.uri.path == '/v1/backup') {
        request.response.write(
          jsonEncode(<String, Object>{
            'backup_id': 'bak-1',
            'business_id': 'biz-A',
            'created_at': 1,
            'counts': <String, Object>{},
          }),
        );
      } else if (request.uri.path == '/v1/sync/push') {
        request.response.write(
          jsonEncode(<String, Object>{
            'accepted': 1,
            'duplicates': 0,
            'failed_client_uuids': <String>[],
          }),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode(<String, Object>{'error': 'not found'}));
      }
      await request.response.close();
    });

    final String baseUrl = 'http://${server.address.host}:${server.port}';
    Future<String?> tokenReader() async => 'token-abc';

    final billing = HttpBillingGateway(
      apiBaseUrl: baseUrl,
      readAccessToken: tokenReader,
    );
    final backup = HttpBackupGateway(
      apiBaseUrl: baseUrl,
      readAccessToken: tokenReader,
    );
    final sync = HttpCloudSyncGateway(
      apiBaseUrl: baseUrl,
      readAccessToken: tokenReader,
    );

    await billing.createCheckout(
      const CheckoutRequest(
        businessId: 'biz-A',
        planCode: BillingPlan.proMonthly,
        clientUuid: 'c-1',
      ),
    );
    await backup.upload(
      businessId: 'biz-A',
      clientUuid: 'b-1',
      snapshot: const BackupSnapshot(
        businessId: 'biz-A',
        createdAt: 1,
        schemaVersion: 13,
        tables: <String, List<Map<String, Object?>>>{},
      ),
    );
    await sync.push(
      businessId: 'biz-A',
      jobs: const <CloudSyncJob>[
        CloudSyncJob(
          clientUuid: 's-1',
          aggregate: 'product',
          operation: 'upsert',
          payload: <String, Object?>{'id': 'p-1'},
        ),
      ],
    );

    expect(authHeaders, everyElement('Bearer token-abc'));
  });
}
