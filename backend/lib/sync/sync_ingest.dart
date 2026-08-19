import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/sync/sheets_mirror.dart';

final class SyncPushResult {
  const SyncPushResult({
    required this.accepted,
    required this.duplicates,
    required this.failedClientUuids,
  });

  final int accepted;
  final int duplicates;
  final List<String> failedClientUuids;

  Map<String, Object> toJson() {
    return <String, Object>{
      'accepted': accepted,
      'duplicates': duplicates,
      'failed_client_uuids': failedClientUuids,
    };
  }
}

final class SyncIngestService {
  SyncIngestService({required this.store, this.google});

  final AppStore store;
  final GoogleSheetsHttpSink? google;

  Future<SyncPushResult> push({
    required String businessId,
    required List<Map<String, Object?>> jobs,
  }) async {
    if (businessId.trim().isEmpty) {
      throw const FormatException('business_id wajib.');
    }
    int accepted = 0;
    int duplicates = 0;
    final List<String> failed = <String>[];
    final Set<String> touchedTabs = <String>{};

    for (final Map<String, Object?> raw in jobs) {
      final String clientUuid = raw['client_uuid'] as String? ?? '';
      final String aggregate = raw['aggregate'] as String? ?? '';
      if (clientUuid.isEmpty || aggregate.isEmpty) {
        failed.add(clientUuid.isEmpty ? 'invalid' : clientUuid);
        continue;
      }
      try {
        final Map<String, Object?> payload = _mapOf(raw['payload']);
        final List<String> tabs = await _mirror(
          businessId: businessId,
          clientUuid: clientUuid,
          aggregate: aggregate,
          payload: payload,
        );
        touchedTabs.addAll(tabs);
        final bool duplicate = store.hasSyncJob(
          businessId: businessId,
          clientUuid: clientUuid,
        );
        if (duplicate) {
          duplicates += 1;
          store.writeAudit(
            action: 'sync.duplicate',
            entity: aggregate,
            businessId: businessId,
            detail:
                'client_uuid $clientUuid sudah ada. Baris Sheets di-upsert.',
          );
        } else {
          store.rememberSyncJob(
            businessId: businessId,
            clientUuid: clientUuid,
            aggregate: aggregate,
          );
          accepted += 1;
          store.writeAudit(
            action: 'sync.push',
            entity: aggregate,
            businessId: businessId,
            detail: 'Salinan $aggregate. SQLite tetap sumber transaksi.',
          );
        }
      } on Object {
        failed.add(clientUuid);
      }
    }

    if (google != null && google!.enabled) {
      final Map<String, Map<String, Map<String, Object?>>> snap = store.sheets
          .snapshot(businessId: businessId);
      for (final String tab in touchedTabs) {
        await google!.overwriteTab(
          tab: tab,
          rows: snap[tab]?.values.toList() ?? const <Map<String, Object?>>[],
        );
      }
    }

    return SyncPushResult(
      accepted: accepted,
      duplicates: duplicates,
      failedClientUuids: failed,
    );
  }

  Future<List<String>> _mirror({
    required String businessId,
    required String clientUuid,
    required String aggregate,
    required Map<String, Object?> payload,
  }) async {
    switch (aggregate) {
      case 'product':
        await store.sheets.upsertRow(
          tab: SheetTabs.products,
          rowKey: _rowKey(businessId, clientUuid, payload['id']),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.products];
      case 'business':
        await store.sheets.upsertRow(
          tab: SheetTabs.businesses,
          rowKey: _rowKey(businessId, clientUuid, payload['id']),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.businesses];
      case 'user_account':
        return _upsertRowsSnapshot(
          tab: SheetTabs.users,
          businessId: businessId,
          clientUuid: clientUuid,
          payload: payload,
          idField: 'id',
        );
      case 'inventory':
        await store.sheets.upsertRow(
          tab: SheetTabs.inventory,
          rowKey: _rowKey(
            businessId,
            clientUuid,
            payload['product_id'] ?? payload['id'],
          ),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.inventory];
      case 'transaction':
        await store.sheets.upsertRow(
          tab: SheetTabs.transactions,
          rowKey: _rowKey(businessId, clientUuid, payload['id']),
          values: _transactionHeader(payload, businessId, clientUuid),
        );
        final Object? itemsRaw = payload['items'];
        if (itemsRaw is List) {
          for (final Object? item in itemsRaw) {
            final Map<String, Object?> row = _mapOf(item);
            final String itemId = '${row['id'] ?? ''}';
            await store.sheets.upsertRow(
              tab: SheetTabs.transactionItems,
              rowKey: _rowKey(businessId, 'item:$itemId', itemId),
              values: <String, Object?>{
                'client_uuid': 'item:$itemId',
                'business_id': businessId,
                'id': itemId,
                'transaction_id': row['transaction_id'] ?? payload['id'],
                'product_id': row['product_id'],
                'name_snapshot': row['name_snapshot'],
                'qty': _intOf(row['qty']),
                'unit_price': _intOf(row['unit_price']),
                'cost_price': _intOf(row['cost_price']),
                'discount_amount': _intOf(row['discount_amount']),
                'line_total': _intOf(row['line_total']),
              },
            );
          }
        }
        return <String>[SheetTabs.transactions, SheetTabs.transactionItems];
      case 'stock_movement':
        await store.sheets.upsertRow(
          tab: SheetTabs.stockMovements,
          rowKey: _rowKey(businessId, clientUuid, payload['id']),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.stockMovements];
      case 'expense':
        await store.sheets.upsertRow(
          tab: SheetTabs.expenses,
          rowKey: _rowKey(businessId, clientUuid, payload['id']),
          values: _moneyRow(payload, businessId, clientUuid, 'amount'),
        );
        return <String>[SheetTabs.expenses];
      case 'customer':
        await store.sheets.upsertRow(
          tab: SheetTabs.customers,
          rowKey: _rowKey(businessId, clientUuid, payload['id']),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.customers];
      case 'supplier':
        await store.sheets.upsertRow(
          tab: SheetTabs.suppliers,
          rowKey: _rowKey(businessId, clientUuid, payload['id']),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.suppliers];
      case 'cash_session':
        await store.sheets.upsertRow(
          tab: SheetTabs.cashSessions,
          rowKey: _rowKey(businessId, clientUuid, payload['id']),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.cashSessions];
      case 'cash_movement':
        await store.sheets.upsertRow(
          tab: SheetTabs.cashMovements,
          rowKey: _rowKey(businessId, clientUuid, payload['id']),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.cashMovements];
      case 'category':
        await store.sheets.upsertRow(
          tab: SheetTabs.categories,
          rowKey: _rowKey(businessId, clientUuid, payload['id']),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.categories];
      case 'settings':
        await store.sheets.upsertRow(
          tab: SheetTabs.settings,
          rowKey: _rowKey(businessId, clientUuid, businessId),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.settings];
      case 'subscription_meta':
        await store.sheets.upsertRow(
          tab: SheetTabs.subscriptions,
          rowKey: _rowKey(businessId, clientUuid, businessId),
          values: _withMeta(payload, businessId, clientUuid),
        );
        return <String>[SheetTabs.subscriptions];
      case 'daily_report':
        await store.sheets.upsertRow(
          tab: SheetTabs.dailyReports,
          rowKey: _rowKey(
            businessId,
            clientUuid,
            payload['date'] ?? payload['id'],
          ),
          values: <String, Object?>{
            'client_uuid': clientUuid,
            'business_id': businessId,
            'date': payload['date'] ?? payload['id'],
            'omzet': _intOf(payload['omzet']),
            'transaction_count': _intOf(payload['transaction_count']),
            'expenses_total': _intOf(payload['expenses_total']),
          },
        );
        return <String>[SheetTabs.dailyReports];
      default:
        throw FormatException('Aggregate tidak dikenal: $aggregate');
    }
  }

  Future<List<String>> _upsertRowsSnapshot({
    required String tab,
    required String businessId,
    required String clientUuid,
    required Map<String, Object?> payload,
    required String idField,
  }) async {
    final Object? rowsRaw = payload['rows'];
    if (rowsRaw is! List) {
      return <String>[tab];
    }
    for (final Object? item in rowsRaw) {
      final Map<String, Object?> row = _mapOf(item);
      final Object? rowId = row[idField];
      if (rowId == null) {
        continue;
      }
      await store.sheets.upsertRow(
        tab: tab,
        rowKey: _rowKey(businessId, clientUuid, rowId),
        values: _withMeta(row, businessId, clientUuid),
      );
    }
    return <String>[tab];
  }

  Map<String, Object?> _transactionHeader(
    Map<String, Object?> payload,
    String businessId,
    String clientUuid,
  ) {
    return <String, Object?>{
      'client_uuid': clientUuid,
      'business_id': businessId,
      'id': payload['id'],
      'status': payload['status'],
      'subtotal_amount': _intOf(payload['subtotal_amount']),
      'discount_amount': _intOf(payload['discount_amount']),
      'tax_amount': _intOf(payload['tax_amount']),
      'total_amount': _intOf(payload['total_amount']),
      'user_id': payload['user_id'],
      'customer_id': payload['customer_id'],
      'created_at': payload['created_at'],
    };
  }

  Map<String, Object?> _withMeta(
    Map<String, Object?> payload,
    String businessId,
    String clientUuid,
  ) {
    // business_id SELALU dari authenticated context — tidak pernah dari payload.
    // Ini mencegah Business A meng-inject data ke Sheets Business B.
    return <String, Object?>{
      ...payload,
      'client_uuid': clientUuid,
      'business_id': businessId,
    };
  }

  Map<String, Object?> _moneyRow(
    Map<String, Object?> payload,
    String businessId,
    String clientUuid,
    String field,
  ) {
    final Map<String, Object?> row = _withMeta(payload, businessId, clientUuid);
    row[field] = _intOf(payload[field]);
    return row;
  }

  String _rowKey(String businessId, String clientUuid, Object? entityId) {
    return '$businessId|$clientUuid|${entityId ?? ''}';
  }

  Map<String, Object?> _mapOf(Object? value) {
    if (value is Map) {
      return value.map(
        (Object? key, Object? val) =>
            MapEntry<String, Object?>(key.toString(), val),
      );
    }
    return <String, Object?>{};
  }

  int _intOf(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
