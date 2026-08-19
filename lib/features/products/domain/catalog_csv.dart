abstract final class CatalogCsv {
  static const List<String> headers = [
    'sku',
    'barcode',
    'nama',
    'kategori',
    'satuan',
    'hpp',
    'harga_jual',
    'stok',
    'min_stok',
    'deskripsi',
    'aktif',
  ];

  static String export(List<CatalogCsvRow> rows) {
    final StringBuffer buffer = StringBuffer()..writeln(headers.join(','));
    for (final CatalogCsvRow row in rows) {
      buffer.writeln(
        [
          _escape(row.sku),
          _escape(row.barcode),
          _escape(row.name),
          _escape(row.categoryName),
          _escape(row.unitName),
          '${row.costPrice}',
          '${row.sellPrice}',
          '${row.stockQty}',
          '${row.minStock}',
          _escape(row.description),
          row.isActive ? '1' : '0',
        ].join(','),
      );
    }
    return buffer.toString();
  }

  static List<CatalogCsvRow> parse(String csv) {
    final List<String> lines = csv
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((String line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const [];
    }
    var start = 0;
    final List<String> first = _parseLine(lines.first);
    if (first.isNotEmpty && first.first.toLowerCase().trim() == 'sku') {
      start = 1;
    }
    final List<CatalogCsvRow> rows = [];
    for (int i = start; i < lines.length; i++) {
      final List<String> cols = _parseLine(lines[i]);
      if (cols.every((String col) => col.trim().isEmpty)) {
        continue;
      }
      rows.add(
        CatalogCsvRow(
          sku: _cell(cols, 0),
          barcode: _cell(cols, 1),
          name: _cell(cols, 2) ?? '',
          categoryName: _cell(cols, 3),
          unitName: _cell(cols, 4),
          costPrice: _intCell(cols, 5),
          sellPrice: _intCell(cols, 6),
          stockQty: _intCell(cols, 7),
          minStock: _intCell(cols, 8),
          description: _cell(cols, 9),
          isActive: _boolCell(cols, 10),
          sourceLine: i + 1,
        ),
      );
    }
    return rows;
  }

  static String? _cell(List<String> cols, int index) {
    if (index >= cols.length) {
      return null;
    }
    final String value = cols[index].trim();
    return value.isEmpty ? null : value;
  }

  static int _intCell(List<String> cols, int index) {
    final String? raw = _cell(cols, index);
    if (raw == null) {
      return 0;
    }
    final String digits = raw.replaceAll(RegExp(r'[^0-9-]'), '');
    return int.tryParse(digits) ?? 0;
  }

  static bool _boolCell(List<String> cols, int index) {
    final String? raw = _cell(cols, index)?.toLowerCase();
    if (raw == null) {
      return true;
    }
    return raw != '0' &&
        raw != 'tidak' &&
        raw != 'nonaktif' &&
        raw != 'false' &&
        raw != 'no';
  }

  static String _escape(String? value) {
    final String text = value ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static List<String> _parseLine(String line) {
    final List<String> cells = [];
    final StringBuffer current = StringBuffer();
    var quoted = false;
    for (int i = 0; i < line.length; i++) {
      final String char = line[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            current.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          current.write(char);
        }
      } else if (char == '"') {
        quoted = true;
      } else if (char == ',') {
        cells.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    cells.add(current.toString());
    return cells;
  }
}

final class CatalogCsvRow {
  const CatalogCsvRow({
    required this.name,
    required this.costPrice,
    required this.sellPrice,
    required this.stockQty,
    required this.minStock,
    required this.isActive,
    required this.sourceLine,
    this.sku,
    this.barcode,
    this.categoryName,
    this.unitName,
    this.description,
  });

  final String? sku;
  final String? barcode;
  final String name;
  final String? categoryName;
  final String? unitName;
  final int costPrice;
  final int sellPrice;
  final int stockQty;
  final int minStock;
  final String? description;
  final bool isActive;
  final int sourceLine;
}
