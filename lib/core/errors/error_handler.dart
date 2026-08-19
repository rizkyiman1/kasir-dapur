import 'package:flutter/foundation.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/logging/app_logger.dart';

abstract final class ErrorHandler {
  static void install() {
    FlutterError.onError = onFlutterError;
    PlatformDispatcher.instance.onError = onPlatformError;
  }

  static void onFlutterError(FlutterErrorDetails details) {
    AppLogger.instance.error(
      'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  }

  static bool onPlatformError(Object error, StackTrace stackTrace) {
    AppLogger.instance.error(
      'PlatformError',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  }

  static String userMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}
