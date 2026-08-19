import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/reports/data/report_exporter.dart';
import 'package:kasir_dapur/features/reports/domain/report_filter.dart';
import 'package:kasir_dapur/features/reports/domain/report_repository.dart';
import 'package:kasir_dapur/features/reports/domain/report_snapshot.dart';
import 'package:kasir_dapur/features/reports/presentation/reports_controller.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_section_card.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReportSnapshot> snapshot = ref.watch(
      reportSnapshotProvider,
    );
    final ReportFilter filter = ref.watch(reportFilterProvider);
    final AsyncValue<ReportFilterOptions> options = ref.watch(
      reportFilterOptionsProvider,
    );
    final FeatureGate gate = ref
        .watch(featureGateProvider)
        .maybeWhen(
          data: (FeatureGate value) => value,
          orElse: () => FeatureGate.forPlan(Plan.free),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
        actions: [
          if (gate.canUse(FeatureKey.export))
            PopupMenuButton<ReportExportFormat>(
              tooltip: 'Ekspor',
              icon: const Icon(Icons.ios_share_outlined),
              onSelected: (ReportExportFormat format) {
                unawaited(_export(context, ref, format));
              },
              itemBuilder: (BuildContext context) {
                return [
                  for (final ReportExportFormat format
                      in ReportExportFormat.values)
                    PopupMenuItem<ReportExportFormat>(
                      value: format,
                      child: Text('Ekspor ${format.label}'),
                    ),
                ];
              },
            )
          else
            IconButton(
              tooltip: gate.denyMessage(FeatureKey.export),
              onPressed: () => context.go(AppRoutes.subscription),
              icon: const Icon(Icons.lock_outline),
            ),
        ],
      ),
      body: snapshot.when(
        skipLoadingOnReload: true,
        loading: () => const KdLoadingView(message: 'Memuat laporan...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Laporan gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => ref.invalidate(reportSnapshotProvider),
          );
        },
        data: (ReportSnapshot data) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(reportSnapshotProvider);
              ref.invalidate(reportFilterOptionsProvider);
              await ref.read(reportSnapshotProvider.future);
            },
            child: _ReportsBody(
              filter: filter,
              snapshot: data,
              options: options.asData?.value ?? const ReportFilterOptions(),
              gate: gate,
            ),
          );
        },
      ),
    );
  }

  static Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ReportExportFormat format,
  ) async {
    try {
      final ReportFilter filter = ref.read(reportFilterProvider);
      final ReportQuery query = filter.toQuery(ref.read(clockProvider).now());
      final ReportSnapshot snapshot = await ref.read(
        reportSnapshotProvider.future,
      );
      final List<int> bytes = switch (format) {
        ReportExportFormat.csv => utf8.encode(
          ReportExporter.csv(snapshot, query: query),
        ),
        ReportExportFormat.excel => ReportExporter.excel(
          snapshot,
          query: query,
        ),
        ReportExportFormat.pdf => await ReportExporter.pdf(
          snapshot,
          query: query,
        ),
      };
      final Directory dir = await getTemporaryDirectory();
      final String fileName = 'laporan-kasir-dapur.${format.extension}';
      final File file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: format.mimeType)],
          subject: 'Laporan ${Brand.appName}',
        ),
      );
    } catch (error) {
      if (context.mounted) {
        context.showError(error);
      }
    }
  }
}

class _ReportsBody extends ConsumerWidget {
  const _ReportsBody({
    required this.filter,
    required this.snapshot,
    required this.options,
    required this.gate,
  });

  final ReportFilter filter;
  final ReportSnapshot snapshot;
  final ReportFilterOptions options;
  final FeatureGate gate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          'Data dari SQLite perangkat · integer Rupiah',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _PeriodBar(filter: filter),
        if (gate.canUse(FeatureKey.advancedReports)) ...[
          const SizedBox(height: 12),
          _FilterBar(filter: filter, options: options),
        ],
        const SizedBox(height: 16),
        _MetricsGrid(
          metrics: [
            _MetricSpec(
              label: 'Penjualan',
              value: '${snapshot.transactionCount}',
              icon: Icons.receipt_long_outlined,
              color: scheme.primary,
            ),
            _MetricSpec(
              label: 'Omzet',
              value: MoneyFormatter.rupiah(snapshot.omzet),
              icon: Icons.payments_outlined,
              color: scheme.primary,
            ),
            if (gate.canUse(FeatureKey.profitAnalysis) ||
                gate.canUse(FeatureKey.dailyReports))
              _MetricSpec(
                label: 'Laba kotor',
                value: MoneyFormatter.signedRupiah(snapshot.grossProfit),
                icon: Icons.trending_up_outlined,
                color: scheme.secondary,
              ),
            if (gate.canUse(FeatureKey.expenses))
              _MetricSpec(
                label: 'Pengeluaran',
                value: MoneyFormatter.rupiah(snapshot.expensesTotal),
                icon: Icons.money_off_outlined,
                color: scheme.tertiary,
              ),
            _MetricSpec(
              label: 'Saldo kas',
              value: MoneyFormatter.rupiah(snapshot.cash.currentBalance),
              subtitle: snapshot.cash.hasOpenSession
                  ? 'Sesi kas terbuka'
                  : 'Sesi terakhir',
              icon: Icons.account_balance_wallet_outlined,
              color: scheme.secondary,
            ),
            _MetricSpec(
              label: 'Produk terjual',
              value: '${snapshot.productsSoldQty}',
              icon: Icons.inventory_2_outlined,
              color: scheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SalesCard(items: snapshot.sales),
        if (gate.canUse(FeatureKey.advancedReports)) ...[
          const SizedBox(height: 12),
          _NamedAmountCard(
            title: 'Produk terlaris',
            empty: 'Belum ada produk terjual pada periode ini.',
            items: snapshot.topProducts,
            trailing: (ReportNamedAmount item) =>
                '${item.qty} · ${MoneyFormatter.rupiah(item.amount)}',
          ),
        ],
        const SizedBox(height: 12),
        _StockCard(title: 'Stok', items: snapshot.stock),
        const SizedBox(height: 12),
        _StockCard(title: 'Stok menipis', items: snapshot.lowStock),
        if (gate.canUse(FeatureKey.expenses)) ...[
          const SizedBox(height: 12),
          _ExpensesCard(items: snapshot.expenses),
        ],
        const SizedBox(height: 12),
        _CashCard(cash: snapshot.cash),
        if (gate.canUse(FeatureKey.advancedReports)) ...[
          const SizedBox(height: 12),
          _NamedAmountCard(
            title: 'Metode pembayaran',
            empty: 'Belum ada pembayaran pada periode ini.',
            items: snapshot.paymentMethods,
            trailing: (ReportNamedAmount item) =>
                '${item.count} · ${MoneyFormatter.rupiah(item.amount)}',
          ),
          const SizedBox(height: 12),
          _NamedAmountCard(
            title: 'Penjualan per kasir',
            empty: 'Belum ada penjualan per kasir.',
            items: snapshot.salesByCashier,
            trailing: (ReportNamedAmount item) =>
                '${item.count} · ${MoneyFormatter.rupiah(item.amount)}',
          ),
          const SizedBox(height: 12),
          _NamedAmountCard(
            title: 'Penjualan per kategori',
            empty: 'Belum ada penjualan per kategori.',
            items: snapshot.salesByCategory,
            trailing: (ReportNamedAmount item) =>
                '${item.qty} · ${MoneyFormatter.rupiah(item.amount)}',
          ),
        ],
        const SizedBox(height: 32),
        const KdLegalFooter(),
      ],
    );
  }
}

class _PeriodBar extends ConsumerWidget {
  const _PeriodBar({required this.filter});

  final ReportFilter filter;

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
        .read(reportFilterProvider.notifier)
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
                            .read(reportFilterProvider.notifier)
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

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter, required this.options});

  final ReportFilter filter;
  final ReportFilterOptions options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FilterDropdown(
                label: 'Produk',
                value: filter.productId,
                allLabel: 'Semua produk',
                options: options.products,
                onChanged: ref.read(reportFilterProvider.notifier).setProductId,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FilterDropdown(
                label: 'Kategori',
                value: filter.categoryId,
                allLabel: 'Semua kategori',
                options: options.categories,
                onChanged: ref
                    .read(reportFilterProvider.notifier)
                    .setCategoryId,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _FilterDropdown(
                label: 'Kasir',
                value: filter.cashierId,
                allLabel: 'Semua kasir',
                options: options.cashiers,
                onChanged: ref.read(reportFilterProvider.notifier).setCashierId,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: filter.paymentMethod,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Pembayaran'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Semua metode'),
                  ),
                  for (final PaymentMethod method in PaymentMethod.values)
                    DropdownMenuItem<String?>(
                      value: method.storageValue,
                      child: Text(method.label),
                    ),
                ],
                onChanged: ref
                    .read(reportFilterProvider.notifier)
                    .setPaymentMethod,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String allLabel;
  final List<ReportFilterOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool hasValue =
        value != null && options.any((ReportFilterOption o) => o.id == value);
    return DropdownButtonFormField<String?>(
      initialValue: hasValue ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
        for (final ReportFilterOption option in options)
          DropdownMenuItem<String?>(
            value: option.id,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
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
            ? 3
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
                child: KdSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(metric.icon, color: metric.color),
                      const SizedBox(height: 12),
                      Text(
                        metric.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metric.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (metric.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          metric.subtitle!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
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

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.items});

  final List<ReportSaleRow> items;

  @override
  Widget build(BuildContext context) {
    return _ListCard(
      title: 'Penjualan',
      empty: 'Belum ada penjualan pada periode ini.',
      children: [
        for (final ReportSaleRow item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(item.cashierName),
            subtitle: Text(
              DateFormatter.dateTimeId(
                DateTime.fromMillisecondsSinceEpoch(item.createdAt),
              ),
            ),
            trailing: Text(MoneyFormatter.rupiah(item.amount)),
          ),
      ],
      hasItems: items.isNotEmpty,
    );
  }
}

class _NamedAmountCard extends StatelessWidget {
  const _NamedAmountCard({
    required this.title,
    required this.empty,
    required this.items,
    required this.trailing,
  });

  final String title;
  final String empty;
  final List<ReportNamedAmount> items;
  final String Function(ReportNamedAmount item) trailing;

  @override
  Widget build(BuildContext context) {
    return _ListCard(
      title: title,
      empty: empty,
      hasItems: items.isNotEmpty,
      children: [
        for (final ReportNamedAmount item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(item.name),
            trailing: Text(trailing(item)),
          ),
      ],
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.title, required this.items});

  final String title;
  final List<ReportStockRow> items;

  @override
  Widget build(BuildContext context) {
    return _ListCard(
      title: title,
      empty: title == 'Stok menipis'
          ? 'Tidak ada produk di bawah stok minimum.'
          : 'Belum ada stok.',
      hasItems: items.isNotEmpty,
      children: [
        for (final ReportStockRow item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(item.name),
            subtitle: Text(
              [
                if (item.categoryName != null && item.categoryName!.isNotEmpty)
                  item.categoryName,
                'Minimum ${item.minStock}',
              ].join(' · '),
            ),
            trailing: Text('${item.qty}'),
          ),
      ],
    );
  }
}

class _ExpensesCard extends StatelessWidget {
  const _ExpensesCard({required this.items});

  final List<ReportExpenseRow> items;

  @override
  Widget build(BuildContext context) {
    return _ListCard(
      title: 'Pengeluaran',
      empty: 'Belum ada pengeluaran pada periode ini.',
      hasItems: items.isNotEmpty,
      children: [
        for (final ReportExpenseRow item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(item.categoryName ?? item.note ?? 'Pengeluaran'),
            subtitle: Text(
              DateFormatter.dateId(
                DateTime.fromMillisecondsSinceEpoch(item.spentAt),
              ),
            ),
            trailing: Text(MoneyFormatter.rupiah(item.amount)),
          ),
      ],
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.cash});

  final ReportCashSnapshot cash;

  @override
  Widget build(BuildContext context) {
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _kv(context, 'Saldo kas', MoneyFormatter.rupiah(cash.currentBalance)),
          _kv(
            context,
            'Penjualan tunai',
            MoneyFormatter.rupiah(cash.periodCashSales),
          ),
          _kv(
            context,
            'Omzet non-tunai',
            MoneyFormatter.rupiah(cash.periodNonCashSales),
          ),
          _kv(context, 'Kas masuk', MoneyFormatter.rupiah(cash.periodCashIn)),
          _kv(context, 'Kas keluar', MoneyFormatter.rupiah(cash.periodCashOut)),
          _kv(
            context,
            'Kas neto periode',
            MoneyFormatter.signedRupiah(cash.periodNet),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Laporan kas hanya menghitung tunai. Omzet QRIS, transfer, '
              'dan metode lain tidak masuk saldo kas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.empty,
    required this.hasItems,
    required this.children,
  });

  final String title;
  final String empty;
  final bool hasItems;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!hasItems)
            Text(
              empty,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}
