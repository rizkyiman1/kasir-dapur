enum CameraAccess {
  granted,
  denied,
  permanentlyDenied,
  unavailable;

  bool get canScan => this == CameraAccess.granted;
}

abstract class CameraPermissionPort {
  Future<CameraAccess> status();

  Future<CameraAccess> request();

  Future<bool> openSettings();
}

/// Penjelasan izin kamera — ditampilkan sebelum/saat permintaan izin.
abstract final class BarcodePermissionCopy {
  static const String title = 'Kamera untuk memindai barcode';

  static const String explanation =
      'Kasir Dapur memakai kamera hanya untuk membaca barcode produk '
      '(EAN-13, EAN-8, UPC, Code 128) dan QR jika relevan, agar barang '
      'bisa ditambahkan ke keranjang. Aplikasi tidak mengambil foto '
      'dan tidak mengunggah gambar dari kamera.';

  static const String denied =
      'Izin kamera ditolak. Anda tetap bisa mengetik barcode secara manual. '
      'Kasir tidak akan tertutup.';

  static const String permanentlyDenied =
      'Izin kamera ditolak permanen. Aktifkan kamera di pengaturan perangkat, '
      'atau ketik barcode secara manual.';
}
