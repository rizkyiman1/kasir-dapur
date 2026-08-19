import 'dart:convert';
import 'dart:io';

import 'package:kasir_dapur_backend/config/backend_config.dart';

/// Tab salinan Google Sheets. Bukan database transaksi.
abstract final class SheetTabs {
  static const String products = 'Products';
  static const String businesses = 'Businesses';
  static const String users = 'Users';
  static const String inventory = 'Inventory';
  static const String transactions = 'Transactions';
  static const String transactionItems = 'TransactionItems';
  static const String stockMovements = 'StockMovements';
  static const String expenses = 'Expenses';
  static const String customers = 'Customers';
  static const String suppliers = 'Suppliers';
  static const String cashSessions = 'CashSessions';
  static const String cashMovements = 'CashMovements';
  static const String categories = 'Categories';
  static const String settings = 'Settings';
  static const String subscriptions = 'Subscriptions';
  static const String dailyReports = 'DailyReports';

  static const List<String> all = <String>[
    businesses,
    users,
    products,
    inventory,
    transactions,
    transactionItems,
    stockMovements,
    expenses,
    customers,
    suppliers,
    cashSessions,
    cashMovements,
    categories,
    settings,
    subscriptions,
    dailyReports,
  ];
}

abstract class SheetsMirror {
  Future<void> upsertRow({
    required String tab,
    required String rowKey,
    required Map<String, Object?> values,
  });

  Map<String, Map<String, Map<String, Object?>>> snapshot({String? businessId});
}

final class MemorySheetsMirror implements SheetsMirror {
  MemorySheetsMirror()
    : _tabs = <String, Map<String, Map<String, Object?>>>{
        for (final String tab in SheetTabs.all)
          tab: <String, Map<String, Object?>>{},
      };

  final Map<String, Map<String, Map<String, Object?>>> _tabs;

  @override
  Future<void> upsertRow({
    required String tab,
    required String rowKey,
    required Map<String, Object?> values,
  }) async {
    final Map<String, Map<String, Object?>>? sheet = _tabs[tab];
    if (sheet == null) {
      throw FormatException('Tab Google Sheets tidak dikenal: $tab');
    }
    sheet[rowKey] = Map<String, Object?>.from(values);
  }

  @override
  Map<String, Map<String, Map<String, Object?>>> snapshot({
    String? businessId,
  }) {
    return <String, Map<String, Map<String, Object?>>>{
      for (final MapEntry<String, Map<String, Map<String, Object?>>> entry
          in _tabs.entries)
        entry.key: <String, Map<String, Object?>>{
          for (final MapEntry<String, Map<String, Object?>> row
              in entry.value.entries)
            if (businessId == null || row.value['business_id'] == businessId)
              row.key: Map<String, Object?>.from(row.value),
        },
    };
  }

  int rowCount(String tab) => _tabs[tab]?.length ?? 0;
}

/// Menulis ulang tab ke Spreadsheet jika token dan ID ada. Idempoten per rowKey.
final class GoogleSheetsHttpSink {
  GoogleSheetsHttpSink({required this.config, HttpClient? client})
    : _client = client;

  final BackendConfig config;
  final HttpClient? _client;

  bool get enabled {
    return config.googleSheetsSpreadsheetId.isNotEmpty &&
        config.googleSheetsAccessToken.isNotEmpty;
  }

  Future<void> overwriteTab({
    required String tab,
    required List<Map<String, Object?>> rows,
  }) async {
    if (!enabled) {
      return;
    }
    final List<String> headers = rows.isEmpty
        ? <String>['client_uuid']
        : rows.first.keys.toList();
    final List<List<Object?>> values = <List<Object?>>[
      headers,
      ...rows.map(
        (Map<String, Object?> row) =>
            headers.map((String key) => row[key]).toList(),
      ),
    ];
    final HttpClient client = _client ?? HttpClient();
    final bool owned = _client == null;
    try {
      final Uri uri = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '${Uri.encodeComponent(config.googleSheetsSpreadsheetId)}'
        '/values/${Uri.encodeComponent('$tab!A1')}'
        '?valueInputOption=RAW',
      );
      final HttpClientRequest request = await client.putUrl(uri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${config.googleSheetsAccessToken}',
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(<String, Object>{'values': values}));
      final HttpClientResponse response = await request.close();
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException(
          'Gagal menulis salinan Google Sheets. SQLite tetap sumber transaksi.',
        );
      }
    } finally {
      if (owned) {
        client.close(force: true);
      }
    }
  }
}
