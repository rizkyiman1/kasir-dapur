import 'package:flutter/material.dart';

/// Palet warna resmi Kasir Dapur.
///
/// Nuansa hijau daun tropis (primary) + kuning kunyit (tertiary) + oranye
/// rempah (secondary) — terasa "dapur UMKM" tanpa tampak seperti app restoran.
abstract final class AppColors {
  /// Hijau segar — primary brand (daun, segar, terpercaya).
  static const Color seed = Color(0xFF1F6B4A);

  /// Oranye rempah — secondary accent (wajan, bumbu).
  static const Color spice = Color(0xFFC46A2F);

  /// Kuning kunyit — tertiary accent (kunyit, keemasan, premium).
  static const Color turmeric = Color(0xFFB8860B);

  // Warna semantik yang digunakan langsung di widget
  static const Color success = Color(0xFF2D7A4F);
  static const Color successContainer = Color(0xFFD6F5E5);
  static const Color successOnContainer = Color(0xFF0B3D22);

  static const Color warning = Color(0xFFB85C00);
  static const Color warningContainer = Color(0xFFFFE0B2);
  static const Color warningOnContainer = Color(0xFF3E1A00);

  static const Color offline = Color(0xFF757575);
  static const Color offlineContainer = Color(0xFFEEEEEE);
}
