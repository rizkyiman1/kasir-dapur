/// Pemisahan lingkungan. Tidak berisi secret, Server Key Midtrans, atau kredensial.
enum AppEnvironment { development, staging, production }

final class EnvConfig {
  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableVerboseLog,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final bool enableVerboseLog;

  static const EnvConfig development = EnvConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: 'https://api-dev.dapur-rasa.com',
    enableVerboseLog: true,
  );

  static const EnvConfig staging = EnvConfig(
    environment: AppEnvironment.staging,
    apiBaseUrl: 'https://api-staging.dapur-rasa.com',
    enableVerboseLog: true,
  );

  static const EnvConfig production = EnvConfig(
    environment: AppEnvironment.production,
    apiBaseUrl: 'https://api.dapur-rasa.com',
    enableVerboseLog: false,
  );

  bool get isProduction => environment == AppEnvironment.production;

  /// Dipilih lewat `--dart-define=ENV=dev|staging|prod`. Default: dev.
  static EnvConfig fromDartDefine({
    String env = const String.fromEnvironment('ENV', defaultValue: 'dev'),
  }) {
    switch (env.toLowerCase()) {
      case 'prod':
      case 'production':
        return production;
      case 'staging':
      case 'stage':
        return staging;
      default:
        return development;
    }
  }
}
