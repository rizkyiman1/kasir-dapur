import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/guarded_repositories.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/inventory/domain/stock_repository.dart';

const AuthUser owner = AuthUser(
  id: 'o1',
  displayName: 'Owner',
  role: UserRole.owner,
);
const AuthUser admin = AuthUser(
  id: 'a1',
  displayName: 'Admin',
  role: UserRole.admin,
);
const AuthUser cashier = AuthUser(
  id: 'c1',
  displayName: 'Kasir',
  role: UserRole.cashier,
);

void main() {
  final PermissionGuard guard = PermissionGuard();

  StaticAccessContext access(AuthUser user) =>
      StaticAccessContext(currentUser: user);

  test('owner lolos seluruh izin yang dicek guard', () {
    final AccessContext ctx = access(owner);
    for (final AppPermission permission in AppPermission.values) {
      expect(guard.can(ctx, permission), isTrue);
      expect(() => guard.require(ctx, permission), returnsNormally);
    }
  });

  test('admin boleh stok dan laporan, tidak boleh kasir', () {
    final AccessContext ctx = access(admin);
    expect(
      () => guard.require(ctx, AppPermission.manageStock),
      returnsNormally,
    );
    expect(
      () => guard.require(ctx, AppPermission.viewReports),
      returnsNormally,
    );
    expect(
      () => guard.require(ctx, AppPermission.cashier),
      throwsA(isA<ForbiddenException>()),
    );
    expect(guard.can(ctx, AppPermission.cashier), isFalse);
  });

  test('kasir boleh kasir, ditolak stok dan pengeluaran', () {
    final AccessContext ctx = access(cashier);
    expect(() => guard.require(ctx, AppPermission.cashier), returnsNormally);
    expect(
      () => guard.require(ctx, AppPermission.viewTransactions),
      returnsNormally,
    );
    expect(
      () => guard.require(ctx, AppPermission.manageCustomers),
      returnsNormally,
    );
    expect(
      () => guard.require(ctx, AppPermission.managePrinters),
      returnsNormally,
    );
    expect(
      () => guard.require(ctx, AppPermission.manageStock),
      throwsA(isA<ForbiddenException>()),
    );
    expect(
      () => guard.require(ctx, AppPermission.manageExpenses),
      throwsA(isA<ForbiddenException>()),
    );
  });

  test('repository berpagar menolak kasir mengubah stok', () async {
    final _RecordingStockRepository inner = _RecordingStockRepository();
    final GuardedStockRepository repo = GuardedStockRepository(
      inner: inner,
      guard: guard,
      access: () => access(cashier),
    );

    expect(
      () => repo.applyMovement(
        businessId: 'b1',
        productId: 'p1',
        type: StockMovementType.adjustment,
        qtyDelta: 1,
      ),
      throwsA(isA<ForbiddenException>()),
    );
    expect(inner.called, isFalse);

    final GuardedStockRepository asOwner = GuardedStockRepository(
      inner: inner,
      guard: guard,
      access: () => access(owner),
    );
    await asOwner.applyMovement(
      businessId: 'b1',
      productId: 'p1',
      type: StockMovementType.adjustment,
      qtyDelta: 1,
    );
    expect(inner.called, isTrue);
  });

  test('sesi terkunci menolak meskipun peran owner', () {
    final AccessContext ctx = StaticAccessContext(
      currentUser: owner,
      isLocked: true,
    );
    expect(guard.can(ctx, AppPermission.cashier), isFalse);
    expect(
      () => guard.require(ctx, AppPermission.cashier),
      throwsA(isA<ForbiddenException>()),
    );
  });
}

final class _RecordingStockRepository implements StockRepository {
  bool called = false;

  @override
  Future<StockBalance> applyMovement({
    required String businessId,
    required String productId,
    required StockMovementType type,
    required int qtyDelta,
    String? refType,
    String? refId,
    String? note,
  }) async {
    called = true;
    return StockBalance(
      id: 's1',
      businessId: businessId,
      productId: productId,
      qty: qtyDelta,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Future<StockBalance?> getByProduct({
    required String businessId,
    required String productId,
  }) async => null;

  @override
  Future<List<StockMovement>> listMovements({
    required String businessId,
    required String productId,
  }) async => const [];

  @override
  Future<StockBalance> stockIn({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  }) async => applyMovement(
    businessId: businessId,
    productId: productId,
    type: StockMovementType.stockIn,
    qtyDelta: qty,
  );

  @override
  Future<StockBalance> stockOut({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  }) async => applyMovement(
    businessId: businessId,
    productId: productId,
    type: StockMovementType.stockOut,
    qtyDelta: -qty,
  );

  @override
  Future<StockBalance> purchase({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  }) async => applyMovement(
    businessId: businessId,
    productId: productId,
    type: StockMovementType.purchase,
    qtyDelta: qty,
  );

  @override
  Future<StockBalance> saleReturn({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  }) async => applyMovement(
    businessId: businessId,
    productId: productId,
    type: StockMovementType.saleReturn,
    qtyDelta: qty,
  );

  @override
  Future<StockBalance> recordDamaged({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  }) async => applyMovement(
    businessId: businessId,
    productId: productId,
    type: StockMovementType.damaged,
    qtyDelta: -qty,
  );

  @override
  Future<StockBalance> recordExpired({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  }) async => applyMovement(
    businessId: businessId,
    productId: productId,
    type: StockMovementType.expired,
    qtyDelta: -qty,
  );

  @override
  Future<StockBalance> transfer({
    required String businessId,
    required String productId,
    required int qtyDelta,
    String? note,
  }) async => applyMovement(
    businessId: businessId,
    productId: productId,
    type: StockMovementType.transfer,
    qtyDelta: qtyDelta,
  );

  @override
  Future<StockBalance> adjustTo({
    required String businessId,
    required String productId,
    required int countedQty,
    String? note,
  }) async => applyMovement(
    businessId: businessId,
    productId: productId,
    type: StockMovementType.adjustment,
    qtyDelta: countedQty,
  );

  @override
  Future<List<StockMovement>> listHistory({
    required String businessId,
    String? productId,
    StockMovementType? type,
    int limit = 200,
  }) async => const [];

  @override
  Future<List<StockPosition>> listPositions({
    required String businessId,
    String query = '',
    bool lowStockOnly = false,
  }) async => const [];

  @override
  Future<List<StockPosition>> listLowStock({
    required String businessId,
  }) async => const [];

  @override
  Future<StockOpnameResult> commitOpname({
    required String businessId,
    required List<StockOpnameLine> lines,
    String? note,
  }) async => const StockOpnameResult(adjustedCount: 0, unchangedCount: 0);

  @override
  Future<bool> allowNegativeStock(String businessId) async => false;

  @override
  Future<void> setAllowNegativeStock({
    required String businessId,
    required bool allow,
  }) async {}
}
