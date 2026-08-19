import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/config/env.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';

/// Konfigurasi runtime yang aman untuk klien. Tidak ada secret di sini.
final class AppConfig {
  const AppConfig({
    required this.env,
    this.subscription = SubscriptionConfig.standard,
  });

  final EnvConfig env;
  final SubscriptionConfig subscription;

  String get appName => Brand.appName;
  String get tagline => Brand.tagline;
  String get packageId => Brand.packageId;
  String get websiteUrl => Brand.websiteUrl;

  bool get isOfflineFirst => true;
}
