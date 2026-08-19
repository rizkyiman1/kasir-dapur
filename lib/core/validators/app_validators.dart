import 'package:kasir_dapur/core/constants/app_constants.dart';

abstract final class AppValidators {
  static String? required(String? value, {String fieldName = 'Kolom ini'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }

  static String? displayName(String? value) {
    final String? empty = required(value, fieldName: 'Nama');
    if (empty != null) {
      return empty;
    }
    if (value!.trim().length < 2) {
      return 'Nama minimal 2 karakter';
    }
    if (value.trim().length > 60) {
      return 'Nama maksimal 60 karakter';
    }
    return null;
  }

  static String? pin(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN wajib diisi';
    }
    if (value.length != AppConstants.pinLength) {
      return 'PIN harus ${AppConstants.pinLength} digit';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'PIN hanya boleh angka';
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(value)) {
      return 'PIN tidak boleh angka yang sama semua';
    }
    return null;
  }

  static String? pinConfirmation(String? pin, String? confirmation) {
    final String? pinError = AppValidators.pin(pin);
    if (pinError != null) {
      return pinError;
    }
    if (pin != confirmation) {
      return 'Konfirmasi PIN tidak sama';
    }
    return null;
  }

  /// Nomor HP opsional. Tidak wajib; format longgar jika diisi.
  static String? optionalPhone(String? value, {String fieldName = 'Nomor HP'}) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final String compact = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(r'^\+?\d{8,15}$').hasMatch(compact)) {
      return '$fieldName tidak valid';
    }
    return null;
  }

  static String? optionalText(
    String? value, {
    required int maxLength,
    String fieldName = 'Kolom ini',
  }) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (value.trim().length > maxLength) {
      return '$fieldName maksimal $maxLength karakter';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final bool ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(value.trim());
    if (!ok) {
      return 'Format email tidak valid';
    }
    return null;
  }

  /// Menerima angka Rupiah tanpa pecahan (titik pemisah ribuan diabaikan).
  static String? rupiahInteger(String? value, {bool requiredField = true}) {
    if (value == null || value.trim().isEmpty) {
      return requiredField ? 'Nominal wajib diisi' : null;
    }
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return 'Nominal harus berupa angka';
    }
    return null;
  }

  static String? positiveInt(String? value, {String fieldName = 'Kuantitas'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    final int? parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return '$fieldName harus berupa angka';
    }
    if (parsed <= 0) {
      return '$fieldName harus lebih dari 0';
    }
    return null;
  }

  static String? nonNegativeInt(
    String? value, {
    String fieldName = 'Kuantitas',
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    final int? parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return '$fieldName harus berupa angka';
    }
    if (parsed < 0) {
      return '$fieldName tidak boleh negatif';
    }
    return null;
  }

  static int parseRupiah(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return 0;
    }
    return int.parse(digits);
  }
}
