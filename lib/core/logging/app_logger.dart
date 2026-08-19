import 'package:logger/logger.dart';

/// Logger aplikasi. Jangan pernah menulis PIN, token, atau secret.
final class AppLogger {
  AppLogger._(this._logger);

  static AppLogger? _instance;

  final Logger _logger;

  static AppLogger get instance {
    return _instance ??= AppLogger._(
      Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 8,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
      ),
    );
  }

  static void init({required bool verbose}) {
    Logger.level = verbose ? Level.debug : Level.warning;
    _instance = AppLogger._(
      Logger(
        printer: PrettyPrinter(
          methodCount: verbose ? 1 : 0,
          errorMethodCount: 8,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
      ),
    );
  }

  void debug(String message) => _logger.d(_sanitize(message));

  void info(String message) => _logger.i(_sanitize(message));

  void warning(String message) => _logger.w(_sanitize(message));

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(
      _sanitize(message),
      error: error == null ? null : _sanitize('$error'),
      stackTrace: stackTrace,
    );
  }

  String _sanitize(String input) {
    return input.replaceAll(
      RegExp(
        r'(pin|password|secret|token|key)\s*[:=]\s*\S+',
        caseSensitive: false,
      ),
      r'$1=[redacted]',
    );
  }
}
