import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/features/auth/domain/auth_state.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:kasir_dapur/features/dashboard/presentation/dashboard_controller.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_offline_banner.dart';
import 'package:kasir_dapur/widgets/kd_section_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState auth = ref.watch(authControllerProvider);
    final PermissionGuard guard = ref.watch(permissionGuardProvider);
    final AccessContext access = AuthStateAccessContext(auth);
    final AsyncValue<DashboardSnapshot> snapshot = ref.watch(
      dashboardSnapshotProvider,
    );
    final DashboardFilter filter = ref.watch(dashboardFilterProvider);
    final FeatureGate gate = ref
        .watch(featureGateProvider)
        .maybeWhen(
          data: (FeatureGate value) => value,
          orElse: () => FeatureGate.forPlan(Plan.free),
        );
    final String name = auth.user?.displayName ?? 'Pengguna';
    final String role = auth.user?.role.label ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(Brand.appName),
        actions: [
          IconButton(
            tooltip: 'Kunci layar',
            onPressed: () {
              unawaited(ref.read(authControllerProvider.notifier).lock());
            },
            icon: const Icon(Icons.lock_outline),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          const KdOfflineBanner(),
          Expanded(
            child: snapshot.when(
              skipLoadingOnReload: true,
              loading: () =>
                  const KdLoadingView(message: 'Memuat ringkasan usaha...'),
              error: (Object error, StackTrace _) {
                return KdErrorState(
                  title: 'Dashboard gagal dimuat',
                  subtitle: ErrorHandler.userMessage(error),
                  onRetry: () => ref.invalidate(dashboardSnapshotProvider),
                );
              },
              data: (DashboardSnapshot data) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(dashboardSnapshotProvider);
                    await ref.read(dashboardSnapshotProvider.future);
                  },
                  child: _DashboardBody(
                    name: name,
                    role: role,
                    filter: filter,
                    snapshot: data,
                    access: access,
                    guard: guard,
                    gate: gate,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({
    required this.name,
    required this.role,
    required this.filter,
    required this.snapshot,
    required this.access,
    required this.guard,
    required this.gate,
  });

  final String name;
  final String role;
  final DashboardFilter filter;
  final DashboardSnapshot snapshot;
  final AccessContext access;
  final PermissionGuard guard;
  final FeatureGate gate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= 840;
    final List<_DashboardItem> visibleMenu = _menuItems
        .where((item) => guard.can(access, item.permission))
        .toList();
    final bool showSales = guard.can(access, AppPermission.viewTransactions);
    final bool showExpenses =
        guard.can(access, AppPermission.manageExpenses) &&
        gate.canUse(FeatureKey.expenses);
    final bool showCash = guard.can(access, AppPermission.manageCash);
    final bool showStock = guard.can(access, AppPermission.manageStock);

    final List<_MetricSpec> metrics = [
      if (showSales) ...[
        _MetricSpec(
          label: 'Omzet',
          value: MoneyFormatter.rupiah(snapshot.omzet),
          icon: Icons.payments_outlined,
          color: scheme.primary,
        ),
        _MetricSpec(
          label: 'Transaksi',
          value: '${snapshot.transactionCount}',
          icon: Icons.receipt_long_outlined,
          color: scheme.primary,
        ),
        _MetricSpec(
          label: 'Laba kotor',
          value: MoneyFormatter.signedRupiah(snapshot.grossProfit),
          icon: Icons.trending_up_outlined,
          color: scheme.secondary,
        ),
        _MetricSpec(
          label: 'Produk terjual',
          value: '${snapshot.productsSoldQty}',
          icon: Icons.inventory_2_outlined,
          color: scheme.primary,
        ),
      ],
      if (showExpenses)
        _MetricSpec(
          label: 'Pengeluaran',
          value: MoneyFormatter.rupiah(snapshot.expensesTotal),
          icon: Icons.money_off_outlined,
          color: scheme.tertiary,
        ),
      if (showCash)
        _MetricSpec(
          label: 'Saldo kas',
          value: MoneyFormatter.rupiah(snapshot.cashBalance),
          subtitle: snapshot.hasOpenCashSession
              ? 'Sesi kas terbuka'
              : 'Sesi terakhir',
          icon: Icons.account_balance_wallet_outlined,
          color: scheme.secondary,
        ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text('Halo, $name', style: textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          role.isEmpty ? Brand.tagline : '$role · ${Brand.tagline}',
          style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _StorageInfoCard(scheme: scheme, textTheme: textTheme),
        const SizedBox(height: 20),
        _PeriodBar(filter: filter),
        const SizedBox(height: 16),
        if (metrics.isNotEmpty) _MetricsGrid(metrics: metrics),
        if (showSales &&
            snapshot.transactionCount == 0 &&
            snapshot.expensesTotal == 0 &&
            snapshot.lowStock.isEmpty) ...[
          const SizedBox(height: 8),
          const KdSectionCard(
            child: Column(
              children: [
                Icon(Icons.storefront_outlined, size: 40),
                SizedBox(height: 8),
                Text('Belum ada aktivitas'),
                SizedBox(height: 4),
                Text(
                  'Transaksi, pengeluaran, dan stok akan tampil di sini setelah data tercatat di perangkat.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
        if (wide && (showStock || showSales)) ...[
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showStock)
                Expanded(child: _LowStockCard(items: snapshot.lowStock)),
              if (showStock && showSales) const SizedBox(width: 12),
              if (showSales)
                Expanded(child: _RecentSalesCard(items: snapshot.recentSales)),
            ],
          ),
        ] else ...[
          if (showStock) ...[
            const SizedBox(height: 20),
            _LowStockCard(items: snapshot.lowStock),
          ],
          if (showSales) ...[
            const SizedBox(height: 20),
            _RecentSalesCard(items: snapshot.recentSales),
          ],
        ],
        if (visibleMenu.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Menu', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          _MenuGrid(items: visibleMenu, gate: gate),
        ],
        const SizedBox(height: 32),
        const KdLegalFooter(),
      ],
    );
  }
}

class _PeriodBar extends ConsumerWidget {
  const _PeriodBar({required this.filter});

  final DashboardFilter filter;

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final DateTime now = ref.read(clockProvider).now();
    final DateTime today = DashboardDateRange.startOfLocalDay(now);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: filter.customStart ?? today.subtract(const Duration(days: 6)),
        end: filter.customEnd ?? today,
      ),
      helpText: 'Pilih rentang tanggal',
      cancelText: 'Batal',
      confirmText: 'Terapkan',
      saveText: 'Terapkan',
      locale: const Locale('id', 'ID'),
    );
    if (picked == null) {
      return;
    }
    ref
        .read(dashboardFilterProvider.notifier)
        .setCustomRange(start: picked.start, end: picked.end);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final DateTime now = ref.watch(clockProvider).now();
    final range = filter.rangeFor(now);
    final String from = DateFormatter.dateId(
      DateTime.fromMillisecondsSinceEpoch(range.startMs),
    );
    final String to = DateFormatter.dateId(
      DateTime.fromMillisecondsSinceEpoch(range.endMsExclusive - 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Periode', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final DashboardPeriod period in DashboardPeriod.values) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(period.label),
                    selected: filter.period == period,
                    showCheckmark: false,
                    onSelected: (_) {
                      if (period == DashboardPeriod.custom) {
                        unawaited(_pickCustom(context, ref));
                      } else {
                        ref
                            .read(dashboardFilterProvider.notifier)
                            .setPeriod(period);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          from == to ? from : '$from – $to',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MetricSpec {
  const _MetricSpec({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<_MetricSpec> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 860
            ? 4
            : constraints.maxWidth >= 560
            ? 3
            : 2;
        const double gap = 12;
        final double tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final _MetricSpec metric in metrics)
              SizedBox(
                width: tileWidth,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricSpec metric;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: metric.color),
          const SizedBox(height: 12),
          Text(
            metric.label,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (metric.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              metric.subtitle!,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.items});

  final List<LowStockItem> items;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stok menipis', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'Tidak ada produk di bawah stok minimum.',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final LowStockItem item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(item.name),
                subtitle: Text('Minimum ${item.minStock}'),
                trailing: Text(
                  '${item.qty}',
                  style: textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _RecentSalesCard extends StatelessWidget {
  const _RecentSalesCard({required this.items});

  final List<DashboardSaleSummary> items;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transaksi terbaru', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'Belum ada transaksi pada periode ini.',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final DashboardSaleSummary sale in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(MoneyFormatter.rupiah(sale.totalAmount)),
                subtitle: Text(
                  DateFormatter.dateTimeId(
                    DateTime.fromMillisecondsSinceEpoch(sale.createdAt),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.items, required this.gate});

  final List<_DashboardItem> items;
  final FeatureGate gate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 900 ? 3 : 2;
        const double gap = 12;
        final double tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final _DashboardItem item in items)
              SizedBox(
                width: tileWidth,
                height: 112,
                child: KdSectionCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () {
                    if (!item.isEntitled(gate)) {
                      context.push(AppRoutes.subscription);
                      return;
                    }
                    context.push(item.route);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(item.icon, color: scheme.primary),
                          const Spacer(),
                          if (!item.isEntitled(gate))
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: scheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(item.title, style: textTheme.titleSmall),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DashboardItem {
  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.permission,
    this.features = const [],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final AppPermission permission;
  final List<FeatureKey> features;

  bool isEntitled(FeatureGate gate) {
    if (features.isEmpty) {
      return true;
    }
    return gate.canUseAny(features);
  }
}

const List<_DashboardItem> _menuItems = [
  _DashboardItem(
    title: 'Kasir',
    subtitle: 'Penjualan',
    icon: Icons.point_of_sale_outlined,
    route: AppRoutes.cashier,
    permission: AppPermission.cashier,
    features: [FeatureKey.offlinePos],
  ),
  _DashboardItem(
    title: 'Produk',
    subtitle: 'Katalog',
    icon: Icons.inventory_2_outlined,
    route: AppRoutes.products,
    permission: AppPermission.manageProducts,
  ),
  _DashboardItem(
    title: 'Kategori',
    subtitle: 'Pengelompokan',
    icon: Icons.category_outlined,
    route: AppRoutes.categories,
    permission: AppPermission.manageProducts,
  ),
  _DashboardItem(
    title: 'Stok',
    subtitle: 'Inventori',
    icon: Icons.warehouse_outlined,
    route: AppRoutes.inventory,
    permission: AppPermission.manageStock,
    features: [FeatureKey.basicInventory],
  ),
  _DashboardItem(
    title: 'Transaksi',
    subtitle: 'Riwayat',
    icon: Icons.receipt_long_outlined,
    route: AppRoutes.transactions,
    permission: AppPermission.viewTransactions,
  ),
  _DashboardItem(
    title: 'Laporan',
    subtitle: 'Omzet & laba',
    icon: Icons.bar_chart_outlined,
    route: AppRoutes.reports,
    permission: AppPermission.viewReports,
    features: [FeatureKey.dailyReports],
  ),
  _DashboardItem(
    title: 'Pelanggan',
    subtitle: 'Data & histori',
    icon: Icons.people_outline,
    route: AppRoutes.customers,
    permission: AppPermission.manageCustomers,
    features: [FeatureKey.customers],
  ),
  _DashboardItem(
    title: 'Pemasok',
    subtitle: 'Supplier',
    icon: Icons.local_shipping_outlined,
    route: AppRoutes.suppliers,
    permission: AppPermission.manageSuppliers,
    features: [FeatureKey.suppliers],
  ),
  _DashboardItem(
    title: 'Pengeluaran',
    subtitle: 'Biaya usaha',
    icon: Icons.payments_outlined,
    route: AppRoutes.expenses,
    permission: AppPermission.manageExpenses,
    features: [FeatureKey.expenses],
  ),
  _DashboardItem(
    title: 'Kas',
    subtitle: 'Buka & tutup',
    icon: Icons.account_balance_wallet_outlined,
    route: AppRoutes.cashManagement,
    permission: AppPermission.manageCash,
  ),
  _DashboardItem(
    title: 'Printer',
    subtitle: 'Struk thermal',
    icon: Icons.print_outlined,
    route: AppRoutes.printers,
    permission: AppPermission.managePrinters,
    features: [FeatureKey.basicReceipt],
  ),
  _DashboardItem(
    title: 'Barcode',
    subtitle: 'Pemindai',
    icon: Icons.qr_code_scanner_outlined,
    route: AppRoutes.barcode,
    permission: AppPermission.manageBarcode,
    features: [FeatureKey.barcode],
  ),
  _DashboardItem(
    title: 'Langganan',
    subtitle: 'Free / Pro',
    icon: Icons.workspace_premium_outlined,
    route: AppRoutes.subscription,
    permission: AppPermission.manageSubscription,
  ),
  _DashboardItem(
    title: 'Sinkronisasi',
    subtitle: 'Cloud & Sheets',
    icon: Icons.sync_outlined,
    route: AppRoutes.sync,
    permission: AppPermission.manageSync,
    features: [FeatureKey.googleSheetsSync, FeatureKey.cloudSync],
  ),
  _DashboardItem(
    title: 'Cadangan',
    subtitle: 'Cloud backup',
    icon: Icons.cloud_upload_outlined,
    route: AppRoutes.backup,
    permission: AppPermission.manageSettings,
    features: [FeatureKey.cloudBackup, FeatureKey.advancedBackup],
  ),
];

/// Card info penyimpanan di header dashboard.
/// Menampilkan status koneksi secara aktual (bukan hardcoded).
class _StorageInfoCard extends ConsumerWidget {
  const _StorageInfoCard({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> connectivity = ref.watch(connectivityProvider);
    final bool online = connectivity.valueOrNull ?? true;

    final IconData icon = online
        ? Icons.cloud_done_outlined
        : Icons.cloud_off_outlined;
    final String label = online
        ? 'Online · data tersinkron dengan server'
        : 'Offline · data dari SQLite perangkat';

    return KdSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
