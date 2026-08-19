import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/barcode/domain/barcode_code.dart';
import 'package:kasir_dapur/features/barcode/presentation/barcode_cart_flow.dart';
import 'package:kasir_dapur/features/barcode/presentation/barcode_scanner_page.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart.dart';
import 'package:kasir_dapur/features/cashier/domain/receipt_formatter.dart';
import 'package:kasir_dapur/features/cashier/presentation/cashier_controller.dart';
import 'package:kasir_dapur/features/cashier/presentation/payment_sheet.dart';
import 'package:kasir_dapur/features/cashier/presentation/receipt_dialog.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';
import 'package:kasir_dapur/features/printers/presentation/printers_controller.dart';
import 'package:kasir_dapur/features/products/domain/catalog_lookups.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';
import 'package:kasir_dapur/features/settings/presentation/settings_controller.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';
import 'package:kasir_dapur/widgets/kd_confirm_dialog.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

class CashierPage extends ConsumerStatefulWidget {
  const CashierPage({super.key});

  @override
  ConsumerState<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends ConsumerState<CashierPage> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _barcode = TextEditingController();
  bool _paying = false;

  @override
  void dispose() {
    _search.dispose();
    _barcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PosCart> cart = ref.watch(posCartProvider);
    final AsyncValue<List<ProductCatalogItem>> catalog = ref.watch(
      cashierCatalogProvider,
    );
    final AsyncValue<List<CatalogCategory>> categories = ref.watch(
      cashierCategoriesProvider,
    );
    final String? categoryId = ref.watch(cashierCategoryIdProvider);
    final bool wide = MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: [
          IconButton(
            tooltip: 'Tahan',
            onPressed: () => unawaited(_hold()),
            icon: const Icon(Icons.pause_circle_outline),
          ),
          IconButton(
            tooltip: 'Transaksi tertahan',
            onPressed: () => unawaited(_showHeld()),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          IconButton(
            tooltip: 'Batal',
            onPressed: () => unawaited(_cancel()),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: cart.when(
        loading: () => const KdLoadingView(message: 'Menyiapkan kasir...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Kasir gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => ref.invalidate(posCartProvider),
          );
        },
        data: (PosCart current) {
          final Widget products = _ProductsPane(
            catalog: catalog,
            categories: categories,
            categoryId: categoryId,
            search: _search,
            barcode: _barcode,
            onSearch: (String value) {
              ref.read(cashierQueryProvider.notifier).state = value;
            },
            onCategory: (String? id) {
              ref.read(cashierCategoryIdProvider.notifier).state = id;
            },
            onBarcode: (String value) => unawaited(_handleBarcode(value)),
            onScanCamera: () => unawaited(_openCameraScan()),
            onAdd: (ProductCatalogItem item) {
              unawaited(
                ref.read(posCartProvider.notifier).addCatalogItem(item),
              );
            },
          );
          final Widget basket = _CartPane(
            cart: current,
            paying: _paying,
            onPay: () => unawaited(_pay(current)),
            onCustomer: () => unawaited(_pickCustomer(current)),
          );
          if (wide) {
            return Row(
              children: [
                Expanded(flex: 3, child: products),
                const VerticalDivider(width: 1),
                SizedBox(width: 400, child: basket),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: products),
              SizedBox(height: 280, child: basket),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCameraScan() async {
    final ScannedBarcode? scanned = await openBarcodeScanner(context);
    if (scanned == null || !mounted) {
      return;
    }
    await _handleBarcode(scanned.raw, symbology: scanned.symbology);
  }

  Future<void> _handleBarcode(String raw, {BarcodeSymbology? symbology}) async {
    final BarcodeCartOutcome outcome = await applyScannedBarcode(
      ref: ref,
      context: context,
      raw: raw,
      symbology: symbology,
    );
    if (!mounted) {
      return;
    }
    if (outcome == BarcodeCartOutcome.searched) {
      _search.text = ref.read(cashierQueryProvider);
    }
    if (outcome == BarcodeCartOutcome.added ||
        outcome == BarcodeCartOutcome.created) {
      _barcode.clear();
    }
  }

  Future<void> _hold() async {
    try {
      await ref.read(posCartProvider.notifier).hold();
      if (mounted) {
        context.showMessage('Transaksi ditahan');
      }
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    }
  }

  Future<void> _cancel() async {
    final bool? ok = await KdConfirmDialog.show(
      context: context,
      title: 'Batalkan transaksi?',
      body: 'Keranjang akan dikosongkan.',
      confirmLabel: 'Batalkan',
      cancelLabel: 'Tidak',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (ok != true) {
      return;
    }
    await ref.read(posCartProvider.notifier).cancelCurrent();
  }

  Future<void> _showHeld() async {
    ref.invalidate(posHeldCartsProvider);
    final List<PosCart>? held = await showModalBottomSheet<List<PosCart>>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            final AsyncValue<List<PosCart>> tickets = ref.watch(
              posHeldCartsProvider,
            );
            return tickets.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object error, StackTrace _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(ErrorHandler.userMessage(error)),
              ),
              data: (List<PosCart> items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Tidak ada transaksi tertahan'),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int index) {
                    final PosCart ticket = items[index];
                    return ListTile(
                      title: Text(
                        ticket.customerName ?? '${ticket.lines.length} item',
                      ),
                      subtitle: Text(MoneyFormatter.rupiah(ticket.total)),
                      onTap: () => Navigator.pop(context, <PosCart>[ticket]),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
    if (held == null || held.isEmpty) {
      return;
    }
    try {
      await ref.read(posCartProvider.notifier).resume(held.first.id);
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    }
  }

  Future<void> _pickCustomer(PosCart cart) async {
    final Object? selected = await showDialog<Object>(
      context: context,
      builder: (BuildContext context) => const _CustomerPickerDialog(),
    );
    if (!mounted || selected == null) {
      return;
    }
    if (selected == 'clear') {
      await ref.read(posCartProvider.notifier).setCustomer(null);
      return;
    }
    if (selected is Customer) {
      await ref.read(posCartProvider.notifier).setCustomer(selected);
    }
  }

  Future<void> _pay(PosCart cart) async {
    if (cart.isEmpty || _paying) {
      if (cart.isEmpty && mounted) {
        context.showMessage('Keranjang masih kosong');
      }
      return;
    }
    setState(() => _paying = true);
    try {
      StoreProfile? store;
      try {
        store = await ref.read(storeProfileProvider.future);
      } catch (_) {
        store = null;
      }
      if (!mounted) {
        return;
      }
      final List<SalePaymentDraft>? payments = await showCashierPaymentSheet(
        context: context,
        total: cart.total,
        defaultMethod: store?.defaultPayment ?? PaymentMethod.cash,
      );
      if (payments == null) {
        return;
      }
      final Sale sale = await ref.read(posCartProvider.notifier).pay(payments);
      if (!mounted) {
        return;
      }
      final String? cashierName = ref
          .read(authControllerProvider)
          .user
          ?.displayName;
      final ReceiptStoreInfo? storeInfo = store == null
          ? null
          : ReceiptStoreInfo(
              name: store.receiptName,
              address: store.address,
              phone: store.phone,
              footer: store.receiptFooter,
            );
      try {
        await ref
            .read(printerServiceProvider)
            .afterSale(
              sale: sale,
              cashierName: cashierName,
              customerName: cart.customerName,
            );
      } catch (error) {
        if (mounted) {
          context.showError(error);
        }
      }
      if (!mounted) {
        return;
      }
      final ReceiptBehavior behavior =
          store?.receiptBehavior ?? ReceiptBehavior.ask;
      var showReceipt = behavior == ReceiptBehavior.ask;
      if (behavior == ReceiptBehavior.auto) {
        final profile = await ref.read(printerProfileProvider.future);
        showReceipt = !profile.autoPrint || !profile.hasDevice;
      }
      if (!mounted) {
        return;
      }
      if (showReceipt) {
        await showSaleReceiptDialog(
          context: context,
          sale: sale,
          customerName: cart.customerName,
          cashierName: cashierName,
          store: storeInfo,
          onPrint: () {
            return ref
                .read(printerServiceProvider)
                .printSale(
                  sale: sale,
                  cashierName: cashierName,
                  customerName: cart.customerName,
                );
          },
          onReprint: () {
            return ref
                .read(printerServiceProvider)
                .printSale(
                  sale: sale,
                  cashierName: cashierName,
                  customerName: cart.customerName,
                  reprint: true,
                );
          },
        );
      }
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _paying = false);
      }
    }
  }
}

class _ProductsPane extends StatelessWidget {
  const _ProductsPane({
    required this.catalog,
    required this.categories,
    required this.categoryId,
    required this.search,
    required this.barcode,
    required this.onSearch,
    required this.onCategory,
    required this.onBarcode,
    required this.onScanCamera,
    required this.onAdd,
  });

  final AsyncValue<List<ProductCatalogItem>> catalog;
  final AsyncValue<List<CatalogCategory>> categories;
  final String? categoryId;
  final TextEditingController search;
  final TextEditingController barcode;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String> onBarcode;
  final VoidCallback onScanCamera;
  final ValueChanged<ProductCatalogItem> onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cari produk',
                  ),
                  onChanged: onSearch,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 148,
                child: TextField(
                  controller: barcode,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.qr_code_2),
                    hintText: 'Barcode',
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: onBarcode,
                ),
              ),
              IconButton(
                tooltip: 'Pindai kamera',
                onPressed: onScanCamera,
                icon: const Icon(Icons.qr_code_scanner),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: categories.maybeWhen(
            data: (List<CatalogCategory> items) {
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Semua'),
                      selected: categoryId == null,
                      onSelected: (_) => onCategory(null),
                    ),
                  ),
                  for (final CatalogCategory category in items)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.name),
                        selected: categoryId == category.id,
                        onSelected: (_) => onCategory(category.id),
                      ),
                    ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ),
        Expanded(
          child: catalog.when(
            skipLoadingOnReload: true,
            loading: () => const KdLoadingView(message: 'Memuat produk...'),
            error: (Object error, StackTrace _) => KdErrorState(
              title: 'Produk gagal dimuat',
              subtitle: ErrorHandler.userMessage(error),
            ),
            data: (List<ProductCatalogItem> items) {
              if (items.isEmpty) {
                return const KdEmptyState(
                  icon: Icons.point_of_sale_outlined,
                  title: 'Tidak ada produk',
                  subtitle:
                      'Tambah produk di menu Produk, atau ubah pencarian.',
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.15,
                ),
                itemCount: items.length,
                itemBuilder: (BuildContext context, int index) {
                  final ProductCatalogItem item = items[index];
                  return _ProductTile(item: item, onTap: () => onAdd(item));
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.item, required this.onTap});

  final ProductCatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool outOfStock = item.stockQty <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: outOfStock ? null : onTap,
        splashColor: scheme.primary.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(
                    color: outOfStock
                        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                MoneyFormatter.rupiah(item.product.sellPrice),
                style: text.titleSmall?.copyWith(
                  color: outOfStock ? scheme.outline : scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    outOfStock
                        ? Icons.remove_circle_outline
                        : Icons.inventory_2_outlined,
                    size: 12,
                    color: outOfStock ? scheme.error : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    outOfStock ? 'Habis' : 'Stok ${item.stockQty}',
                    style: text.bodySmall?.copyWith(
                      color: outOfStock
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartPane extends ConsumerWidget {
  const _CartPane({
    required this.cart,
    required this.paying,
    required this.onPay,
    required this.onCustomer,
  });

  final PosCart cart;
  final bool paying;
  final VoidCallback onPay;
  final VoidCallback onCustomer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      elevation: 6,
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline),
            title: Text(cart.customerName ?? 'Pelanggan umum'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onCustomer,
          ),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Keranjang kosong'))
                : ListView.builder(
                    itemCount: cart.lines.length,
                    itemBuilder: (BuildContext context, int index) {
                      final CartLine line = cart.lines[index];
                      return ListTile(
                        dense: true,
                        title: Text(line.name),
                        subtitle: Text(
                          '${MoneyFormatter.rupiah(line.unitPrice)} × ${line.qty}'
                          '${line.discountAmount > 0 ? ' · diskon ${MoneyFormatter.rupiah(line.discountAmount)}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _QtyButton(
                              icon: Icons.remove_rounded,
                              onTap: () {
                                unawaited(
                                  ref
                                      .read(posCartProvider.notifier)
                                      .setQty(line.productId, line.qty - 1),
                                );
                              },
                            ),
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${line.qty}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            _QtyButton(
                              icon: Icons.add_rounded,
                              onTap: () {
                                unawaited(
                                  ref
                                      .read(posCartProvider.notifier)
                                      .setQty(line.productId, line.qty + 1),
                                );
                              },
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18),
                              onSelected: (String value) {
                                if (value == 'discount') {
                                  unawaited(
                                    _editItemDiscount(context, ref, line),
                                  );
                                } else if (value == 'delete') {
                                  unawaited(
                                    ref
                                        .read(posCartProvider.notifier)
                                        .removeLine(line.productId),
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) => const [
                                PopupMenuItem(
                                  value: 'discount',
                                  child: ListTile(
                                    leading: Icon(Icons.discount_outlined),
                                    title: Text('Diskon item'),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Hapus'),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // ── Summary + Pay button ──────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                // Diskon + total
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () =>
                          unawaited(_editTrxDiscount(context, ref, cart)),
                      icon: Icon(
                        cart.discountAmount > 0
                            ? Icons.discount_rounded
                            : Icons.discount_outlined,
                        size: 16,
                      ),
                      label: Text(
                        cart.discountAmount > 0
                            ? 'Diskon ${MoneyFormatter.rupiah(cart.discountAmount)}'
                            : 'Diskon',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        Text(
                          MoneyFormatter.rupiah(cart.total),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Tombol bayar — prominent, full width
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: cart.isEmpty
                          ? null
                          : Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: (paying || cart.isEmpty) ? null : onPay,
                    icon: paying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payments_rounded, size: 20),
                    label: Text(paying ? 'Memproses...' : 'Bayar Sekarang'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerPickerDialog extends ConsumerStatefulWidget {
  const _CustomerPickerDialog();

  @override
  ConsumerState<_CustomerPickerDialog> createState() =>
      _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends ConsumerState<_CustomerPickerDialog> {
  List<Customer> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  Future<void> _search(String query) async {
    final String businessId = await ref.read(activeBusinessIdProvider.future);
    final List<Customer> items = await ref
        .read(customerRepositoryProvider)
        .search(businessId: businessId, query: query);
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final TextEditingController name = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pelanggan baru'),
          content: KdTextField(
            label: 'Nama',
            controller: name,
            autofocus: true,
            validator: AppValidators.required,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, name.text.trim()),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    name.dispose();
    if (value == null || value.isEmpty) {
      return;
    }
    final String businessId = await ref.read(activeBusinessIdProvider.future);
    final Customer created = await ref
        .read(customerRepositoryProvider)
        .create(NewCustomer(businessId: businessId, name: value));
    if (mounted) {
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pelanggan'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama atau telepon',
              ),
              onChanged: (String value) => unawaited(_search(value)),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        ListTile(
                          title: const Text('Pelanggan umum'),
                          onTap: () => Navigator.pop(context, 'clear'),
                        ),
                        for (final Customer customer in _items)
                          ListTile(
                            title: Text(customer.name),
                            subtitle: customer.phone == null
                                ? null
                                : Text(customer.phone!),
                            onTap: () => Navigator.pop(context, customer),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton(
          onPressed: () => unawaited(_create()),
          child: const Text('Tambah'),
        ),
      ],
    );
  }
}

Future<void> _editItemDiscount(
  BuildContext context,
  WidgetRef ref,
  CartLine line,
) async {
  final TextEditingController controller = TextEditingController(
    text: '${line.discountAmount}',
  );
  final int? value = await showDialog<int>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Diskon item'),
        content: KdTextField(
          label: 'Nominal Rupiah',
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                AppValidators.parseRupiah(controller.text),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (value == null) {
    return;
  }
  await ref
      .read(posCartProvider.notifier)
      .setItemDiscount(line.productId, value);
}

Future<void> _editTrxDiscount(
  BuildContext context,
  WidgetRef ref,
  PosCart cart,
) async {
  final TextEditingController controller = TextEditingController(
    text: '${cart.discountAmount}',
  );
  final int? value = await showDialog<int>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Diskon transaksi'),
        content: KdTextField(
          label: 'Nominal Rupiah',
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                AppValidators.parseRupiah(controller.text),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (value == null) {
    return;
  }
  await ref.read(posCartProvider.notifier).setTransactionDiscount(value);
}

/// Tombol +/- qty di cart — touch target 44x44dp.
class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
