import 'package:kasir_dapur_backend/auth/jwt_service.dart';
import 'package:kasir_dapur_backend/auth/user_store.dart';
import 'package:kasir_dapur_backend/billing/billing_state.dart';
import 'package:kasir_dapur_backend/config/backend_config.dart';
import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/domain/catalog.dart';
import 'package:kasir_dapur_backend/http/api.dart';
import 'package:kasir_dapur_backend/middleware/rate_limiter.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:kasir_dapur_backend/services/checkout_service.dart';
import 'package:kasir_dapur_backend/services/webhook_service.dart';
import 'package:kasir_dapur_backend/sync/sheets_mirror.dart';
import 'package:kasir_dapur_backend/sync/sync_ingest.dart';
import 'package:shelf/shelf.dart';

final class BackendRuntime {
  BackendRuntime({
    required this.config,
    required this.store,
    required this.userStore,
    required this.jwtService,
    required this.midtrans,
    required this.billing,
    RateLimiter? rateLimiter,
  }) : catalog = SubscriptionCatalog.fromPricing(config.pricing),
       checkout = CheckoutService(
         store: store,
         catalog: SubscriptionCatalog.fromPricing(config.pricing),
         midtrans: midtrans,
         billing: billing,
       ),
       webhook = WebhookService(
         store: store,
         catalog: SubscriptionCatalog.fromPricing(config.pricing),
         midtrans: midtrans,
         midtransConfig: config.midtrans,
         billing: billing,
       ),
       sync = SyncIngestService(
         store: store,
         google: GoogleSheetsHttpSink(config: config),
       ),
       rateLimiter =
           rateLimiter ??
           RateLimiter(
             trustForwardedHeaders: config.trustProxyHeaders,
             trustedProxyIps: config.trustedProxyIps,
           );

  final BackendConfig config;
  final AppStore store;
  final UserStore userStore;
  final JwtService jwtService;
  final MidtransGateway midtrans;
  final BillingState billing;
  final SubscriptionCatalog catalog;
  final CheckoutService checkout;
  final WebhookService webhook;
  final SyncIngestService sync;
  final RateLimiter rateLimiter;

  Handler get handler {
    return BackendApp(
      config: config,
      store: store,
      userStore: userStore,
      jwtService: jwtService,
      checkout: checkout,
      webhook: webhook,
      sync: sync,
      rateLimiter: rateLimiter,
      billing: billing,
    ).handler;
  }

  factory BackendRuntime.production(BackendConfig config) {
    final AppStore store = AppStore();
    final BillingState billing = BillingState.open(
      path: config.billingSqlitePath,
      store: store,
    );
    billing.hydrateCache();
    return BackendRuntime(
      config: config,
      store: store,
      userStore: UserStore(),
      jwtService: JwtService(secret: config.jwtSecret),
      midtrans: HttpMidtransGateway(config: config.midtrans),
      billing: billing,
    );
  }

  factory BackendRuntime.testing({
    required BackendConfig config,
    required MidtransGateway midtrans,
    AppStore? store,
    UserStore? userStore,
    JwtService? jwtService,
    RateLimiter? rateLimiter,
    BillingFaultHooks? billingFaultHooks,
  }) {
    final AppStore resolvedStore = store ?? AppStore();
    final BillingState billing = BillingState.open(
      path: config.billingSqlitePath,
      store: resolvedStore,
      faultHooks: billingFaultHooks,
    );
    billing.hydrateCache();
    return BackendRuntime(
      config: config,
      store: resolvedStore,
      userStore: userStore ?? UserStore(),
      jwtService: jwtService ?? JwtService(secret: config.jwtSecret),
      midtrans: midtrans,
      billing: billing,
      rateLimiter: rateLimiter,
    );
  }

  Future<void> startupReconcile() async {
    await billing.reconcilePending(midtrans: midtrans, catalog: catalog);
  }

  void close() {
    billing.close();
  }
}
