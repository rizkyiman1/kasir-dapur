import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/barcode/domain/barcode_code.dart';
import 'package:kasir_dapur/features/barcode/domain/camera_permission.dart';
import 'package:kasir_dapur/widgets/kd_button.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<ScannedBarcode?> openBarcodeScanner(BuildContext context) {
  return Navigator.of(context).push<ScannedBarcode>(
    MaterialPageRoute<ScannedBarcode>(
      builder: (BuildContext context) => const BarcodeScannerPage(),
    ),
  );
}

class BarcodeScannerPage extends ConsumerStatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  ConsumerState<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends ConsumerState<BarcodeScannerPage> {
  final TextEditingController _manual = TextEditingController();
  CameraAccess _access = CameraAccess.denied;
  bool _loading = true;
  bool _handled = false;
  MobileScannerController? _controller;

  static const List<BarcodeFormat> _formats = <BarcodeFormat>[
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.code128,
    BarcodeFormat.qrCode,
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadPermission());
  }

  @override
  void dispose() {
    _manual.dispose();
    unawaited(_controller?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _loadPermission() async {
    try {
      final CameraAccess access = await ref
          .read(cameraPermissionPortProvider)
          .status();
      if (!mounted) {
        return;
      }
      setState(() {
        _access = access;
        _loading = false;
      });
      if (access.canScan) {
        _ensureController();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _access = CameraAccess.unavailable;
        _loading = false;
      });
    }
  }

  void _ensureController() {
    _controller ??= MobileScannerController(
      autoStart: true,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      formats: _formats,
    );
  }

  Future<void> _requestPermission() async {
    setState(() => _loading = true);
    try {
      final CameraAccess access = await ref
          .read(cameraPermissionPortProvider)
          .request();
      if (!mounted) {
        return;
      }
      setState(() {
        _access = access;
        _loading = false;
      });
      if (access.canScan) {
        _ensureController();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _access = CameraAccess.denied;
        _loading = false;
      });
    }
  }

  void _submit(String raw, BarcodeSymbology symbology) {
    final String code = raw.trim();
    if (code.isEmpty || _handled) {
      return;
    }
    _handled = true;
    Navigator.pop(context, ScannedBarcode(raw: code, symbology: symbology));
  }

  BarcodeSymbology _mapFormat(BarcodeFormat format) {
    return switch (format) {
      BarcodeFormat.ean13 => BarcodeSymbology.ean13,
      BarcodeFormat.ean8 => BarcodeSymbology.ean8,
      BarcodeFormat.upcA => BarcodeSymbology.upcA,
      BarcodeFormat.upcE => BarcodeSymbology.upcE,
      BarcodeFormat.code128 => BarcodeSymbology.code128,
      BarcodeFormat.qrCode => BarcodeSymbology.qr,
      _ => BarcodeSymbology.unknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pindai barcode')),
      body: Column(
        children: [
          Expanded(child: _scannerBody()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BarcodePermissionCopy.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  BarcodePermissionCopy.explanation,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                KdTextField(
                  label: 'Ketik barcode',
                  controller: _manual,
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 8),
                KdButton(
                  label: 'Cari',
                  icon: Icons.search,
                  onPressed: () {
                    _submit(
                      _manual.text,
                      BarcodeSymbology.detect(_manual.text),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scannerBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_access.canScan && _controller != null) {
      return MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        onDetectError: (Object _, StackTrace _) {},
        errorBuilder: (BuildContext context, MobileScannerException error) {
          return _PermissionFallback(
            access: error.errorCode == MobileScannerErrorCode.permissionDenied
                ? CameraAccess.denied
                : CameraAccess.unavailable,
            onRequest: () => unawaited(_requestPermission()),
            onSettings: () {
              unawaited(ref.read(cameraPermissionPortProvider).openSettings());
            },
          );
        },
        overlayBuilder: (BuildContext context, BoxConstraints constraints) {
          return Center(
            child: Container(
              width: constraints.maxWidth * 0.72,
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      );
    }
    return _PermissionFallback(
      access: _access,
      onRequest: () => unawaited(_requestPermission()),
      onSettings: () {
        unawaited(ref.read(cameraPermissionPortProvider).openSettings());
      },
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) {
      return;
    }
    final Barcode barcode = capture.barcodes.first;
    final String? value = barcode.rawValue ?? barcode.displayValue;
    if (value == null || value.trim().isEmpty) {
      return;
    }
    _submit(value, _mapFormat(barcode.format));
  }
}

class _PermissionFallback extends StatelessWidget {
  const _PermissionFallback({
    required this.access,
    required this.onRequest,
    required this.onSettings,
  });

  final CameraAccess access;
  final VoidCallback onRequest;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final String message = switch (access) {
      CameraAccess.permanentlyDenied => BarcodePermissionCopy.permanentlyDenied,
      CameraAccess.unavailable =>
        'Kamera tidak tersedia di perangkat ini. Ketik barcode secara manual.',
      _ => BarcodePermissionCopy.denied,
    };
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 56),
          const SizedBox(height: 12),
          Text(
            BarcodePermissionCopy.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (access == CameraAccess.permanentlyDenied)
            KdButton(label: 'Buka pengaturan', onPressed: onSettings)
          else if (access != CameraAccess.unavailable)
            KdButton(label: 'Izinkan kamera', onPressed: onRequest),
        ],
      ),
    );
  }
}
