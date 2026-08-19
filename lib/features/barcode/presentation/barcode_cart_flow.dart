import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/barcode/domain/barcode_code.dart';
import 'package:kasir_dapur/features/barcode/domain/barcode_lookup_service.dart';
import 'package:kasir_dapur/features/barcode/domain/unknown_barcode_choice.dart';
import 'package:kasir_dapur/features/barcode/presentation/add_product_from_barcode_sheet.dart';
import 'package:kasir_dapur/features/barcode/presentation/unknown_barcode_sheet.dart';
import 'package:kasir_dapur/features/cashier/presentation/cashier_controller.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';

enum BarcodeCartOutcome { added, created, searched, cancelled, empty }

Future<BarcodeCartOutcome> applyScannedBarcode({
  required WidgetRef ref,
  required BuildContext context,
  required String raw,
  BarcodeSymbology? symbology,
}) async {
  final String code = raw.trim();
  if (code.isEmpty) {
    return BarcodeCartOutcome.empty;
  }
  try {
    final String businessId = await ref.read(activeBusinessIdProvider.future);
    final BarcodeLookupResult result = await ref
        .read(barcodeLookupServiceProvider)
        .lookup(businessId: businessId, raw: code, symbology: symbology);
    if (!context.mounted) {
      return BarcodeCartOutcome.cancelled;
    }
    if (result.found) {
      await ref.read(posCartProvider.notifier).addProduct(result.product!);
      if (context.mounted) {
        context.showMessage('${result.product!.name} ditambah ke keranjang');
      }
      return BarcodeCartOutcome.added;
    }
    final PermissionGuard guard = ref.read(permissionGuardProvider);
    final bool canAdd = guard.can(
      AuthStateAccessContext(ref.read(authControllerProvider)),
      AppPermission.manageProducts,
    );
    final UnknownBarcodeChoice choice =
        await showUnknownBarcodeSheet(
          context: context,
          barcode: result.displayCode,
          canAddProduct: canAdd,
        ) ??
        UnknownBarcodeChoice.cancel;
    if (!context.mounted) {
      return BarcodeCartOutcome.cancelled;
    }
    switch (choice) {
      case UnknownBarcodeChoice.addProduct:
        final Product? created = await showAddProductFromBarcodeSheet(
          context: context,
          businessId: businessId,
          barcode: result.displayCode,
          products: ref.read(productRepositoryProvider),
        );
        if (created == null || !context.mounted) {
          return BarcodeCartOutcome.cancelled;
        }
        await ref.read(posCartProvider.notifier).addProduct(created);
        if (context.mounted) {
          context.showMessage('${created.name} ditambah ke keranjang');
        }
        return BarcodeCartOutcome.created;
      case UnknownBarcodeChoice.searchManual:
        ref.read(cashierQueryProvider.notifier).state = result.displayCode;
        if (GoRouterState.of(context).uri.path != AppRoutes.cashier) {
          context.go(AppRoutes.cashier);
        }
        return BarcodeCartOutcome.searched;
      case UnknownBarcodeChoice.cancel:
        return BarcodeCartOutcome.cancelled;
    }
  } catch (error) {
    if (context.mounted) {
      context.showError(error);
    }
    return BarcodeCartOutcome.cancelled;
  }
}
