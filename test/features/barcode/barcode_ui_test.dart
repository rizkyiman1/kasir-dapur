import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/barcode/data/camera_permission_port.dart';
import 'package:kasir_dapur/features/barcode/domain/camera_permission.dart';
import 'package:kasir_dapur/features/barcode/domain/unknown_barcode_choice.dart';
import 'package:kasir_dapur/features/barcode/presentation/barcode_scanner_page.dart';
import 'package:kasir_dapur/features/barcode/presentation/unknown_barcode_sheet.dart';

void main() {
  testWidgets('izin kamera ditolak menampilkan penjelasan, tidak crash', (
    WidgetTester tester,
  ) async {
    final MemoryCameraPermissionPort port = MemoryCameraPermissionPort(
      access: CameraAccess.denied,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cameraPermissionPortProvider.overrideWithValue(port)],
        child: const MaterialApp(home: BarcodeScannerPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(BarcodePermissionCopy.title), findsWidgets);
    expect(find.text(BarcodePermissionCopy.denied), findsOneWidget);
    expect(find.text('Izinkan kamera'), findsOneWidget);
    expect(find.text('Ketik barcode'), findsOneWidget);
  });

  testWidgets('barcode tidak ditemukan menawarkan tambah, cari, batal', (
    WidgetTester tester,
  ) async {
    UnknownBarcodeChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () async {
                  choice = await showUnknownBarcodeSheet(
                    context: context,
                    barcode: '8990000000000',
                    canAddProduct: true,
                  );
                },
                child: const Text('Buka'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.text('Barcode tidak ditemukan'), findsOneWidget);
    expect(find.text('Tambah produk'), findsOneWidget);
    expect(find.text('Cari manual'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(choice, UnknownBarcodeChoice.cancel);
  });

  testWidgets('tanpa izin kelola produk, tambah produk tidak menutup kasir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () {
                  showUnknownBarcodeSheet(
                    context: context,
                    barcode: '8990000000000',
                    canAddProduct: false,
                  );
                },
                child: const Text('Buka'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah produk'));
    await tester.pumpAndSettle();
    expect(find.text('Barcode tidak ditemukan'), findsOneWidget);
    expect(
      find.text('Minta owner/admin menambah produk, atau cari manual.'),
      findsOneWidget,
    );
  });
}
