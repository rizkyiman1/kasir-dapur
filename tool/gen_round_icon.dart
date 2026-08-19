/// Generate ic_launcher_round.png — icon bulat untuk Android 7.1+.
/// Run: dart run tool/gen_round_icon.dart
library;

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final img.Image? source = img.decodePng(
    File('assets/icons/ic_launcher_1024.png').readAsBytesSync(),
  );
  if (source == null) {
    print('❌ Source icon not found. Run gen_icon.dart first.');
    exit(1);
  }

  final Map<String, int> densities = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in densities.entries) {
    final int sz = entry.value;

    // Resize source
    final img.Image resized = img.copyResize(
      source,
      width: sz,
      height: sz,
      interpolation: img.Interpolation.cubic,
    );

    // Buat circle mask — background transparan di luar lingkaran
    final img.Image round = img.Image(
      width: sz,
      height: sz,
      numChannels: 4,
    );
    img.fill(round, color: img.ColorRgba8(0, 0, 0, 0));

    final double cx = sz / 2.0;
    final double cy = sz / 2.0;
    final double r = sz / 2.0;

    for (int y = 0; y < sz; y++) {
      for (int x = 0; x < sz; x++) {
        final double dx = x - cx;
        final double dy = y - cy;
        if (dx * dx + dy * dy <= r * r) {
          round.setPixel(x, y, resized.getPixel(x, y));
        }
      }
    }

    final String dir = 'android/app/src/main/res/${entry.key}';
    Directory(dir).createSync(recursive: true);
    File('$dir/ic_launcher_round.png').writeAsBytesSync(img.encodePng(round));
    print('✅ ${sz}x${sz} → $dir/ic_launcher_round.png');
  }

  print('Done! Round icons generated.');
}
