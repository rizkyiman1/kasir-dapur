/// Tool untuk generate launcher icon Kasir Dapur.
///
/// Logo: ikon spatula/wajan yang simpel — menandakan "dapur" sekaligus cocok
/// untuk UMKM retail. Dirender secara programatik murni menggunakan
/// package `image` (tidak memerlukan aset external/copyrighted).
///
/// Run: dart run tool/gen_icon.dart
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  // Ukuran source 1024x1024 — lalu di-resize ke semua resolusi
  final int sz = 1024;
  final img.Image source = img.Image(width: sz, height: sz);

  // ── Warna brand ──────────────────────────────────────────────────────────
  final img.ColorRgba8 green = img.ColorRgba8(0x1F, 0x6B, 0x4A, 0xFF);
  final img.ColorRgba8 white = img.ColorRgba8(0xFF, 0xFF, 0xFF, 0xFF);
  final img.ColorRgba8 lightGreen = img.ColorRgba8(0x4A, 0x9E, 0x7A, 0xFF);
  final img.ColorRgba8 spice = img.ColorRgba8(0xC4, 0x6A, 0x2F, 0xFF);

  // ── Background: rounded rect hijau ──────────────────────────────────────
  _fillRoundedRect(source, 0, 0, sz, sz, 200, green);

  // ── Ikon: storefront sederhana (toko dengan atap segitiga) ───────────────
  // Bangunan toko berwarna putih, proporsi besar agar terlihat di ikon kecil
  final int cx = sz ~/ 2;
  final int cy = sz ~/ 2;

  // Badan toko (persegi panjang)
  final int bodyW = 480;
  final int bodyH = 340;
  final int bodyX = cx - bodyW ~/ 2;
  final int bodyY = cy - 60;
  _fillRoundedRect(source, bodyX, bodyY, bodyW, bodyH, 32, white);

  // Atap (segitiga dengan rounded top)
  final int roofW = 560;
  final int roofH = 220;
  final int roofX = cx - roofW ~/ 2;
  final int roofY = bodyY - roofH + 30;
  _fillTriangle(
    source,
    cx,
    roofY,
    roofX,
    roofY + roofH,
    roofX + roofW,
    roofY + roofH,
    white,
  );

  // Pintu (persegi panjang hijau muda di tengah bawah badan)
  final int doorW = 120;
  final int doorH = 180;
  final int doorX = cx - doorW ~/ 2;
  final int doorY = bodyY + bodyH - doorH;
  _fillRoundedRect(source, doorX, doorY, doorW, doorH, 16, lightGreen);

  // Jendela kiri dan kanan
  final int winW = 110;
  final int winH = 90;
  final int winY = bodyY + 60;
  // Kiri
  _fillRoundedRect(
    source,
    bodyX + 50,
    winY,
    winW,
    winH,
    12,
    lightGreen,
  );
  // Kanan
  _fillRoundedRect(
    source,
    bodyX + bodyW - 50 - winW,
    winY,
    winW,
    winH,
    12,
    lightGreen,
  );

  // Strip dekoratif oranye di bawah atap (awning)
  final int awningH = 28;
  final int awningY = bodyY - awningH ~/ 2;
  _fillRoundedRect(
    source,
    bodyX - 10,
    awningY,
    bodyW + 20,
    awningH,
    8,
    spice,
  );

  // Teks "KD" kecil di atas pintu sebagai sign board
  img.drawString(
    source,
    'KD',
    font: img.arial48,
    x: cx - 30,
    y: bodyY + 20,
    color: green,
  );

  // ── Simpan source 1024×1024 ──────────────────────────────────────────────
  Directory('assets/icons').createSync(recursive: true);
  File('assets/icons/ic_launcher_1024.png').writeAsBytesSync(
    img.encodePng(source),
  );
  print('✅ Source 1024x1024 → assets/icons/ic_launcher_1024.png');

  // ── Resize ke semua Android densities ────────────────────────────────────
  final Map<String, int> densities = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in densities.entries) {
    final img.Image resized = img.copyResize(
      source,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    final String dir = 'android/app/src/main/res/${entry.key}';
    Directory(dir).createSync(recursive: true);
    File('$dir/ic_launcher.png').writeAsBytesSync(img.encodePng(resized));
    print('✅ ${entry.value}x${entry.value} → $dir/ic_launcher.png');
  }

  // ── Web favicon (jika ada) ───────────────────────────────────────────────
  if (Directory('web').existsSync()) {
    final img.Image fav192 = img.copyResize(
      source,
      width: 192,
      height: 192,
      interpolation: img.Interpolation.cubic,
    );
    File('web/icons/Icon-192.png').writeAsBytesSync(img.encodePng(fav192));

    final img.Image fav512 = img.copyResize(
      source,
      width: 512,
      height: 512,
      interpolation: img.Interpolation.cubic,
    );
    File('web/icons/Icon-512.png').writeAsBytesSync(img.encodePng(fav512));
    print('✅ Web icons updated');
  }

  print('\nDone! 🎉 Launcher icons generated for Kasir Dapur.');
}

// ── Drawing helpers ──────────────────────────────────────────────────────────

void _fillRoundedRect(
  img.Image image,
  int x,
  int y,
  int w,
  int h,
  int radius,
  img.Color color,
) {
  final int r = radius.clamp(0, math.min(w, h) ~/ 2);
  // Fill main rects
  img.fillRect(image, x1: x + r, y1: y, x2: x + w - r, y2: y + h, color: color);
  img.fillRect(image, x1: x, y1: y + r, x2: x + w, y2: y + h - r, color: color);
  // Four corner circles
  _fillCircle(image, x + r, y + r, r, color);
  _fillCircle(image, x + w - r, y + r, r, color);
  _fillCircle(image, x + r, y + h - r, r, color);
  _fillCircle(image, x + w - r, y + h - r, r, color);
}

void _fillCircle(img.Image image, int cx, int cy, int r, img.Color color) {
  for (int dy = -r; dy <= r; dy++) {
    for (int dx = -r; dx <= r; dx++) {
      if (dx * dx + dy * dy <= r * r) {
        final int px = cx + dx;
        final int py = cy + dy;
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          image.setPixel(px, py, color);
        }
      }
    }
  }
}

void _fillTriangle(
  img.Image image,
  int x0,
  int y0,
  int x1,
  int y1,
  int x2,
  int y2,
  img.Color color,
) {
  // Simple scanline fill
  final int minY = [y0, y1, y2].reduce(math.min);
  final int maxY = [y0, y1, y2].reduce(math.max);

  for (int y = minY; y <= maxY; y++) {
    final List<int> intersections = [];

    // Check each edge
    void checkEdge(int ax, int ay, int bx, int by) {
      if ((ay <= y && by > y) || (by <= y && ay > y)) {
        final double t = (y - ay) / (by - ay);
        intersections.add(ax + (t * (bx - ax)).round());
      }
    }

    checkEdge(x0, y0, x1, y1);
    checkEdge(x1, y1, x2, y2);
    checkEdge(x2, y2, x0, y0);

    if (intersections.length >= 2) {
      intersections.sort();
      img.drawLine(
        image,
        x1: intersections.first,
        y1: y,
        x2: intersections.last,
        y2: y,
        color: color,
      );
    }
  }
}
