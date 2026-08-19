/// Generate adaptive icon foreground — icon toko tanpa background.
/// Run: dart run tool/gen_foreground.dart
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  final int sz = 1024;
  // Background transparan
  final img.Image source = img.Image(
    width: sz,
    height: sz,
    numChannels: 4,
  );

  // Isi dengan transparan penuh
  img.fill(source, color: img.ColorRgba8(0, 0, 0, 0));

  final img.ColorRgba8 white = img.ColorRgba8(0xFF, 0xFF, 0xFF, 0xFF);
  final img.ColorRgba8 lightGreen = img.ColorRgba8(0x4A, 0x9E, 0x7A, 0xFF);
  final img.ColorRgba8 spice = img.ColorRgba8(0xC4, 0x6A, 0x2F, 0xFF);
  final img.ColorRgba8 primaryGreen = img.ColorRgba8(0x1F, 0x6B, 0x4A, 0xFF);

  final int cx = sz ~/ 2;
  final int cy = sz ~/ 2;

  // Foreground di dalam safe zone (66% of canvas = 676px)
  // Adaptive icon safe zone: pusat 66% dari 108dp. Kita scaling.
  const double scale = 0.6;
  final int fgSz = (sz * scale).round();

  final int bodyW = (fgSz * 0.72).round();
  final int bodyH = (fgSz * 0.50).round();
  final int bodyX = cx - bodyW ~/ 2;
  final int bodyY = cy - 30;
  _fillRoundedRect(source, bodyX, bodyY, bodyW, bodyH, 28, white);

  final int roofW = (fgSz * 0.84).round();
  final int roofH = (fgSz * 0.33).round();
  final int roofX = cx - roofW ~/ 2;
  final int roofY = bodyY - roofH + 30;
  _fillTriangle(source, cx, roofY, roofX, roofY + roofH, roofX + roofW, roofY + roofH, white);

  final int doorW = (fgSz * 0.18).round();
  final int doorH = (fgSz * 0.27).round();
  final int doorX = cx - doorW ~/ 2;
  final int doorY = bodyY + bodyH - doorH;
  _fillRoundedRect(source, doorX, doorY, doorW, doorH, 14, lightGreen);

  final int winW = (fgSz * 0.165).round();
  final int winH = (fgSz * 0.135).round();
  final int winY = bodyY + (fgSz * 0.09).round();
  _fillRoundedRect(source, bodyX + (fgSz * 0.075).round(), winY, winW, winH, 10, lightGreen);
  _fillRoundedRect(source, bodyX + bodyW - (fgSz * 0.075).round() - winW, winY, winW, winH, 10, lightGreen);

  final int awningH = (fgSz * 0.04).round();
  _fillRoundedRect(source, bodyX - 10, bodyY - awningH ~/ 2, bodyW + 20, awningH, 7, spice);

  img.drawString(source, 'KD', font: img.arial48, x: cx - 28, y: bodyY + (fgSz * 0.03).round(), color: primaryGreen);

  final Map<String, int> densities = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
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
    File('$dir/ic_launcher_foreground.png').writeAsBytesSync(img.encodePng(resized));
    print('✅ ${entry.value}x${entry.value} → $dir/ic_launcher_foreground.png');
  }

  print('Done! Foreground icons generated.');
}

void _fillRoundedRect(img.Image image, int x, int y, int w, int h, int radius, img.Color color) {
  final int r = radius.clamp(0, math.min(w, h) ~/ 2);
  img.fillRect(image, x1: x + r, y1: y, x2: x + w - r, y2: y + h, color: color);
  img.fillRect(image, x1: x, y1: y + r, x2: x + w, y2: y + h - r, color: color);
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

void _fillTriangle(img.Image image, int x0, int y0, int x1, int y1, int x2, int y2, img.Color color) {
  final int minY = [y0, y1, y2].reduce(math.min);
  final int maxY = [y0, y1, y2].reduce(math.max);
  for (int y = minY; y <= maxY; y++) {
    final List<int> intersections = [];
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
      img.drawLine(image, x1: intersections.first, y1: y, x2: intersections.last, y2: y, color: color);
    }
  }
}
