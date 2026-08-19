/// Generate splash screen assets untuk Android.
///
/// Menghasilkan:
/// - android/app/src/main/res/drawable/launch_background.xml (light)
/// - android/app/src/main/res/drawable-v21/launch_background.xml (light API 21+)
/// - android/app/src/main/res/drawable-night/launch_background.xml (dark)
/// - android/app/src/main/res/drawable-night-v21/launch_background.xml (dark)
/// - android/app/src/main/res/mipmap-*/launch_icon.png (icon centered)
///
/// Run: dart run tool/gen_splash.dart
library;

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  print('Generating splash assets...');

  // Baca source icon yang sudah kita buat
  final img.Image? source = img.decodePng(
    File('assets/icons/ic_launcher_1024.png').readAsBytesSync(),
  );
  if (source == null) {
    print('❌ Source icon not found. Run gen_icon.dart first.');
    exit(1);
  }

  // Generate launch_icon di berbagai resolusi
  final Map<String, int> densities = {
    'mipmap-mdpi': 96,
    'mipmap-hdpi': 144,
    'mipmap-xhdpi': 192,
    'mipmap-xxhdpi': 288,
    'mipmap-xxxhdpi': 384,
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
    File('$dir/launch_icon.png').writeAsBytesSync(img.encodePng(resized));
    print('✅ ${entry.value}x${entry.value} → $dir/launch_icon.png');
  }

  // Buat warna XML
  _writeColorsXml();

  // Buat launch_background.xml (light mode)
  _writeLaunchBackground('drawable', light: true);
  _writeLaunchBackground('drawable-v21', light: true);

  // Buat launch_background.xml (dark mode)
  _writeLaunchBackground('drawable-night', light: false);
  _writeLaunchBackground('drawable-night-v21', light: false);

  // Update styles.xml agar support dark
  _writeStyles();
  _writeStylesNight();

  print('\nDone! 🎉 Splash screen generated for Kasir Dapur.');
}

void _writeColorsXml() {
  final String path = 'android/app/src/main/res/values/colors.xml';
  File(path).writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Brand colors Kasir Dapur -->
    <color name="kd_primary">#1F6B4A</color>
    <color name="kd_primary_dark">#174F38</color>
    <color name="kd_surface_light">#FAFAF8</color>
    <color name="kd_surface_dark">#121212</color>
</resources>
''');
  print('✅ colors.xml');

  // Also create night version
  Directory('android/app/src/main/res/values-night').createSync(recursive: true);
  File('android/app/src/main/res/values-night/colors.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="kd_primary">#174F38</color>
    <color name="kd_primary_dark">#0F3325</color>
    <color name="kd_surface_light">#121212</color>
    <color name="kd_surface_dark">#0A0A0A</color>
</resources>
''');
  print('✅ values-night/colors.xml');
}

void _writeLaunchBackground(String drawableDir, {required bool light}) {
  final String dir = 'android/app/src/main/res/$drawableDir';
  Directory(dir).createSync(recursive: true);

  final String bgColor = light ? '@color/kd_primary' : '@color/kd_primary_dark';

  File('$dir/launch_background.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<!-- Splash screen Kasir Dapur — background brand hijau + icon centered -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Background warna brand -->
    <item android:drawable="$bgColor" />

    <!-- Icon centered -->
    <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/launch_icon" />
    </item>
</layer-list>
''');
  print('✅ $dir/launch_background.xml');
}

void _writeStyles() {
  File('android/app/src/main/res/values/styles.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Splash screen: background hijau brand + icon centered (light mode) -->
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowFullscreen">true</item>
    </style>
    <!-- Theme setelah Flutter siap -->
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@color/kd_surface_light</item>
    </style>
</resources>
''');
  print('✅ values/styles.xml');
}

void _writeStylesNight() {
  Directory('android/app/src/main/res/values-night').createSync(recursive: true);
  File('android/app/src/main/res/values-night/styles.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Splash screen: background hijau gelap (dark mode) -->
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowFullscreen">true</item>
    </style>
    <!-- Theme setelah Flutter siap (dark background) -->
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@color/kd_surface_dark</item>
    </style>
</resources>
''');
  print('✅ values-night/styles.xml');
}
