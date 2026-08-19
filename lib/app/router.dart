import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/app/route_error_page.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/features/auth/domain/auth_state.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/auth/presentation/local_users_page.dart';
import 'package:kasir_dapur/features/auth/presentation/lock_page.dart';
import 'package:kasir_dapur/features/auth/presentation/login_page.dart';
import 'package:kasir_dapur/features/auth/presentation/onboarding_page.dart';
import 'package:kasir_dapur/features/auth/presentation/splash_page.dart';
import 'package:kasir_dapur/features/barcode/presentation/barcode_page.dart';
import 'package:kasir_dapur/features/backup/presentation/backup_page.dart';
import 'package:kasir_dapur/features/cash_management/presentation/cash_management_page.dart';
import 'package:kasir_dapur/features/cashier/presentation/cashier_page.dart';
import 'package:kasir_dapur/features/categories/presentation/categories_page.dart';
import 'package:kasir_dapur/features/customers/presentation/customers_page.dart';
import 'package:kasir_dapur/features/dashboard/presentation/dashboard_page.dart';
import 'package:kasir_dapur/features/expenses/presentation/expenses_page.dart';
import 'package:kasir_dapur/features/inventory/presentation/inventory_page.dart';
import 'package:kasir_dapur/features/inventory/presentation/stock_card_page.dart';
import 'package:kasir_dapur/features/inventory/presentation/stock_history_page.dart';
import 'package:kasir_dapur/features/inventory/presentation/stock_opname_page.dart';
import 'package:kasir_dapur/features/printers/presentation/printers_page.dart';
import 'package:kasir_dapur/features/products/presentation/products_page.dart';
import 'package:kasir_dapur/features/reports/presentation/reports_page.dart';
import 'package:kasir_dapur/features/settings/presentation/settings_page.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_page.dart';
import 'package:kasir_dapur/features/suppliers/presentation/suppliers_page.dart';
import 'package:kasir_dapur/features/sync/presentation/sync_page.dart';
import 'package:kasir_dapur/features/transactions/presentation/transactions_page.dart';

final routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (_, _) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);
  final PermissionGuard guard = ref.read(permissionGuardProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthState auth = ref.read(authControllerProvider);
      final String location = state.matchedLocation;
      final bool onSplash = location == AppRoutes.splash;
      final bool onOnboarding = location == AppRoutes.onboarding;
      final bool onLogin = location == AppRoutes.login;
      final bool onLock = location == AppRoutes.lock;

      switch (auth.status) {
        case AuthStatus.unknown:
          return onSplash ? null : AppRoutes.splash;
        case AuthStatus.needsOnboarding:
          return onOnboarding ? null : AppRoutes.onboarding;
        case AuthStatus.unauthenticated:
          return onLogin ? null : AppRoutes.login;
        case AuthStatus.locked:
          return onLock ? null : AppRoutes.lock;
        case AuthStatus.authenticated:
          if (onSplash || onOnboarding || onLogin || onLock) {
            return AppRoutes.dashboard;
          }
          final AppPermission? required = AppRoutes.requiredPermission(
            location,
          );
          if (required != null &&
              !guard.can(AuthStateAccessContext(auth), required)) {
            return AppRoutes.dashboard;
          }
          return null;
      }
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) {
          return const SplashPage();
        },
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) {
          return const OnboardingPage();
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage();
        },
      ),
      GoRoute(
        path: AppRoutes.lock,
        builder: (BuildContext context, GoRouterState state) {
          return const LockPage();
        },
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (BuildContext context, GoRouterState state) {
          return const DashboardPage();
        },
      ),
      GoRoute(
        path: AppRoutes.cashier,
        builder: (BuildContext context, GoRouterState state) {
          return const CashierPage();
        },
      ),
      GoRoute(
        path: AppRoutes.products,
        builder: (BuildContext context, GoRouterState state) {
          return const ProductsPage();
        },
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (BuildContext context, GoRouterState state) {
          return const CategoriesPage();
        },
      ),
      GoRoute(
        path: AppRoutes.inventory,
        builder: (BuildContext context, GoRouterState state) {
          return const InventoryPage();
        },
      ),
      GoRoute(
        path: AppRoutes.stockCard,
        builder: (BuildContext context, GoRouterState state) {
          return StockCardPage(
            productId: state.uri.queryParameters['productId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.stockOpname,
        builder: (BuildContext context, GoRouterState state) {
          return const StockOpnamePage();
        },
      ),
      GoRoute(
        path: AppRoutes.stockHistory,
        builder: (BuildContext context, GoRouterState state) {
          return const StockHistoryPage();
        },
      ),
      GoRoute(
        path: AppRoutes.transactions,
        builder: (BuildContext context, GoRouterState state) {
          return const TransactionsPage();
        },
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (BuildContext context, GoRouterState state) {
          return const ReportsPage();
        },
      ),
      GoRoute(
        path: AppRoutes.customers,
        builder: (BuildContext context, GoRouterState state) {
          return const CustomersPage();
        },
      ),
      GoRoute(
        path: AppRoutes.suppliers,
        builder: (BuildContext context, GoRouterState state) {
          return const SuppliersPage();
        },
      ),
      GoRoute(
        path: AppRoutes.expenses,
        builder: (BuildContext context, GoRouterState state) {
          return const ExpensesPage();
        },
      ),
      GoRoute(
        path: AppRoutes.cashManagement,
        builder: (BuildContext context, GoRouterState state) {
          return const CashManagementPage();
        },
      ),
      GoRoute(
        path: AppRoutes.printers,
        builder: (BuildContext context, GoRouterState state) {
          return const PrintersPage();
        },
      ),
      GoRoute(
        path: AppRoutes.barcode,
        builder: (BuildContext context, GoRouterState state) {
          return const BarcodePage();
        },
      ),
      GoRoute(
        path: AppRoutes.subscription,
        builder: (BuildContext context, GoRouterState state) {
          return const SubscriptionPage();
        },
      ),
      GoRoute(
        path: AppRoutes.sync,
        builder: (BuildContext context, GoRouterState state) {
          return const SyncPage();
        },
      ),
      GoRoute(
        path: AppRoutes.backup,
        builder: (BuildContext context, GoRouterState state) {
          return const BackupPage();
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsPage();
        },
      ),
      GoRoute(
        path: AppRoutes.users,
        builder: (BuildContext context, GoRouterState state) {
          return const LocalUsersPage();
        },
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) {
      return RouteErrorPage(error: state.error);
    },
  );
});
