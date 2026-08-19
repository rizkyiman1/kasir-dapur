/// Kesalahan domain yang aman ditampilkan ke pengguna.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ValidationException extends AppException {
  const ValidationException(super.message);
}

final class AuthException extends AppException {
  const AuthException(super.message);
}

final class DatabaseException extends AppException {
  const DatabaseException(super.message);
}

final class InsufficientStockException extends AppException {
  const InsufficientStockException([
    super.message = 'Stok tidak mencukupi untuk transaksi ini.',
  ]);
}

final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Data tidak ditemukan.']);
}

final class ConflictException extends AppException {
  const ConflictException(super.message);
}

final class ForbiddenException extends AppException {
  const ForbiddenException([
    super.message = 'Anda tidak memiliki izin untuk tindakan ini.',
  ]);
}

final class PlanLimitException extends AppException {
  const PlanLimitException(super.message, {this.featureKey});

  final String? featureKey;
}

final class UnexpectedException extends AppException {
  const UnexpectedException([
    super.message = 'Terjadi kesalahan. Silakan coba lagi.',
  ]);
}

final class PrinterException extends AppException {
  const PrinterException([
    super.message = 'Printer offline. Transaksi tetap tersimpan.',
  ]);
}
