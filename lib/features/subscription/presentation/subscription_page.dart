import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan_catalog.dart';
import 'package:kasir_dapur/features/subscription/domain/plan_snapshot.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_payment.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_service.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_section_card.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalUrlLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

Uri? parseSnapRedirectUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    return null;
  }
  final Uri? uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return null;
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return null;
  }
  return uri;
}

Future<bool> launchSnapRedirectUrl({
  required String? rawUrl,
  required ExternalUrlLauncher launcher,
}) async {
  final Uri? uri = parseSnapRedirectUrl(rawUrl);
  if (uri == null) {
    return false;
  }
  return launcher(uri, mode: LaunchMode.externalApplication);
}

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key, this.launchExternalUrl = launchUrl});

  final ExternalUrlLauncher launchExternalUrl;

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  late final AppLifecycleListener _lifecycle;
  bool _paymentFlowActive = false;
  bool _refreshingStatus = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(_refreshStatusAfterPaymentReturn()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WidgetRef ref = this.ref;
    final AsyncValue<PlanSnapshot> snapshot = ref.watch(planSnapshotProvider);
    final SubscriptionConfig config = ref.watch(subscriptionConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Langganan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.dashboard);
            }
          },
        ),
      ),
      body: snapshot.when(
        loading: () => const KdLoadingView(message: 'Memuat paket...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Paket gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => ref.invalidate(planSnapshotProvider),
          );
        },
        data: (PlanSnapshot data) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Pembayaran Midtrans diverifikasi server Kasir Dapur. '
                'Menekan tombol pembayaran tidak mengaktifkan paket. '
                'Server Key Midtrans tidak disimpan di aplikasi ini.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _CurrentPlanCard(snapshot: data),
              const SizedBox(height: 12),
              const _PricingOverviewCard(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => unawaited(_sync(context, ref)),
                      child: const Text('Cek Status Pembayaran'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => unawaited(_restore(context, ref)),
                      child: const Text('Pulihkan hak akses'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Naikkan paket',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final PlanOffer offer in config.paidOffers) ...[
                _UpgradeCard(
                  offer: offer,
                  current: data.subscription,
                  pending: data.pending,
                  onUpgrade: () => unawaited(_upgrade(offer)),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              Text(
                'Riwayat pembayaran',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _PaymentHistoryList(payments: data.payments),
              const SizedBox(height: 12),
              const _CommercialAvailabilityCard(),
              const SizedBox(height: 12),
              Text(
                'Perbandingan fitur',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const _FeatureComparisonTable(),
              const SizedBox(height: 32),
              const KdLegalFooter(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(subscriptionControllerProvider).restoreEntitlements();
      if (context.mounted) {
        context.showMessage('Hak akses dipulihkan dari paket terverifikasi.');
      }
    } catch (error) {
      if (context.mounted) {
        context.showError(error);
      }
    }
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(subscriptionControllerProvider).syncFromBackend();
      if (context.mounted) {
        context.showMessage('Status langganan disinkronkan dari server.');
      }
    } catch (error) {
      if (context.mounted) {
        context.showError(error);
      }
    }
  }

  Future<void> _refreshStatusAfterPaymentReturn() async {
    if (!_paymentFlowActive || _refreshingStatus) {
      return;
    }
    _refreshingStatus = true;
    try {
      await ref.read(subscriptionControllerProvider).syncFromBackend();
      ref.invalidate(planSnapshotProvider);
      if (mounted) {
        context.showMessage('Status pembayaran diperbarui dari server.');
      }
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    } finally {
      _refreshingStatus = false;
      _paymentFlowActive = false;
    }
  }

  Future<void> _upgrade(PlanOffer offer) async {
    try {
      final UpgradeRequestResult result = await ref
          .read(subscriptionControllerProvider)
          .requestUpgrade(offer.planCode);
      if (!mounted) {
        return;
      }
      final bool launched = await launchSnapRedirectUrl(
        rawUrl: result.checkout?.snapRedirectUrl,
        launcher: widget.launchExternalUrl,
      );
      if (!mounted) {
        return;
      }
      if (launched) {
        _paymentFlowActive = true;
        context.showMessage(
          'Halaman pembayaran dibuka. Menunggu verifikasi pembayaran dari server.',
        );
        return;
      }
      if (result.checkoutError == null) {
        context.showError(
          const ValidationException(
            'Halaman pembayaran tidak dapat dibuka. Silakan coba lagi atau cek status pembayaran.',
          ),
        );
      } else {
        context.showMessage(
          'Pengajuan ${offer.planCode.label} tersimpan. Checkout server belum tersedia. Paket belum aktif.',
        );
      }
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    }
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.snapshot});

  final PlanSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final Subscription current = snapshot.subscription;
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paket saat ini', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            current.planCode.label,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(current.plan.summary),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(current.status.label)),
              Chip(label: Text(_expiryLabel(current))),
              Chip(label: Text(_sourceLabel(current.source))),
              Chip(
                label: Text(
                  'Produk ${PlanCatalog.cell(current.plan, FeatureKey.maxProducts)}',
                ),
              ),
              Chip(
                label: Text(
                  'Kasir ${PlanCatalog.cell(current.plan, FeatureKey.maxCashiers)}',
                ),
              ),
            ],
          ),
          if (snapshot.pending != null) ...[
            const SizedBox(height: 12),
            Text(
              'Ada pengajuan ${snapshot.pending!.planCode.label} menunggu '
              'verifikasi pembayaran.',
            ),
          ],
        ],
      ),
    );
  }

  static String _expiryLabel(Subscription current) {
    final int? endsAt = current.endsAt;
    if (endsAt == null) {
      return 'Tidak kedaluwarsa';
    }
    return 'Berakhir ${DateFormatter.dateId(DateTime.fromMillisecondsSinceEpoch(endsAt))}';
  }

  static String _sourceLabel(String source) {
    return switch (source) {
      'default' => 'Bawaan perangkat',
      'backend' => 'Terverifikasi server',
      'midtrans' => 'Midtrans',
      _ => source,
    };
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.offer,
    required this.current,
    required this.pending,
    required this.onUpgrade,
  });

  final PlanOffer offer;
  final Subscription current;
  final Subscription? pending;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final bool selected =
        offer.planCode == current.planCode && current.grantsEntitlements;
    final bool waiting = pending?.planCode == offer.planCode;
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.planCode.label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(offer.planCode.family.summary),
          const SizedBox(height: 8),
          Text('${offer.priceLabel} · ${offer.cycleLabel}'),
          if (offer.planCode.cycle == BillingCycle.yearly) ...[
            const SizedBox(height: 4),
            Text(
              'Hemat dibanding bulanan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: selected || waiting ? null : onUpgrade,
              child: Text(
                selected
                    ? 'Paket saat ini'
                    : waiting
                    ? 'Menunggu verifikasi'
                    : 'Ajukan ${offer.planCode.label}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingOverviewCard extends StatelessWidget {
  const _PricingOverviewCard();

  @override
  Widget build(BuildContext context) {
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Harga Resmi Paket'),
          SizedBox(height: 8),
          Text('Free: Rp0'),
          Text('Pro bulanan: Rp49.000 / 30 hari'),
          Text('Pro tahunan: Rp490.000 / 365 hari'),
          Text('Business bulanan: Rp99.000 / 30 hari'),
          Text('Business tahunan: Rp990.000 / 365 hari'),
        ],
      ),
    );
  }
}

class _CommercialAvailabilityCard extends StatelessWidget {
  const _CommercialAvailabilityCard();

  @override
  Widget build(BuildContext context) {
    return KdSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Tersedia Saat Ini'),
          SizedBox(height: 8),
          Text(
            'Business: sinkronisasi cloud, cadangan lanjutan, dan seluruh fitur Pro.',
          ),
          SizedBox(height: 12),
          Text('Segera Hadir (Business)'),
          SizedBox(height: 8),
          Text(
            'Multi cabang, multi perangkat, izin lanjutan, dasbor pusat, laporan bisnis, API, dukungan prioritas.',
          ),
        ],
      ),
    );
  }
}

class _PaymentHistoryList extends StatelessWidget {
  const _PaymentHistoryList({required this.payments});

  final List<SubscriptionPayment> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const KdSectionCard(child: Text('Belum ada riwayat pembayaran.'));
    }
    return KdSectionCard(
      child: Column(
        children: [
          for (int i = 0; i < payments.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            _PaymentTile(payment: payments[i]),
          ],
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final SubscriptionPayment payment;

  @override
  Widget build(BuildContext context) {
    final String amount = payment.amountRupiah <= 0
        ? SubscriptionConfig.standard.priceLabel(payment.planCode)
        : MoneyFormatter.rupiah(payment.amountRupiah);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(payment.planCode.label),
      subtitle: Text(
        '${payment.status.label} · ${payment.provider} · '
        '${DateFormatter.dateTimeId(DateTime.fromMillisecondsSinceEpoch(payment.createdAt))}',
      ),
      trailing: Text(amount),
    );
  }
}

class _FeatureComparisonTable extends StatelessWidget {
  const _FeatureComparisonTable();

  @override
  Widget build(BuildContext context) {
    return KdSectionCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Fitur')),
            DataColumn(label: Text('Free')),
            DataColumn(label: Text('Pro')),
            DataColumn(label: Text('Business')),
          ],
          rows: [
            for (final FeatureKey key in FeatureKey.values)
              DataRow(
                cells: [
                  DataCell(SizedBox(width: 160, child: Text(key.label))),
                  DataCell(Text(PlanCatalog.cell(Plan.free, key))),
                  DataCell(Text(PlanCatalog.cell(Plan.pro, key))),
                  DataCell(Text(PlanCatalog.cell(Plan.business, key))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
