import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/cash_management/domain/cash.dart';

final cashClosedSessionsProvider = FutureProvider<List<CashSession>>((
  Ref ref,
) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(cashRepositoryProvider).listClosed(businessId: businessId);
});

final cashDrawerProvider = FutureProvider<CashDrawerSnapshot?>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  final CashSession? open = await ref
      .watch(cashRepositoryProvider)
      .getOpenSession(businessId);
  if (open == null) {
    return null;
  }
  return ref.watch(cashRepositoryProvider).drawer(open.id);
});

final class CashController {
  CashController(this._ref);

  final Ref _ref;

  Future<CashSession> open({required int openingAmount}) async {
    final String businessId = await _ref.read(activeBusinessIdProvider.future);
    final String? userId = _ref.read(authControllerProvider).user?.id;
    final CashSession session = await _ref
        .read(cashRepositoryProvider)
        .openSession(
          businessId: businessId,
          openingAmount: openingAmount,
          userId: userId,
        );
    _ref.invalidate(cashDrawerProvider);
    return session;
  }

  Future<void> addMovement({
    required String sessionId,
    required String type,
    required int amount,
    String? note,
  }) async {
    await _ref
        .read(cashRepositoryProvider)
        .addMovement(
          sessionId: sessionId,
          type: type,
          amount: amount,
          note: note,
        );
    _ref.invalidate(cashDrawerProvider);
  }

  Future<CashSession> close({
    required String sessionId,
    required int countedAmount,
  }) async {
    final CashSession closed = await _ref
        .read(cashRepositoryProvider)
        .closeSession(sessionId: sessionId, countedAmount: countedAmount);
    _ref.invalidate(cashDrawerProvider);
    _ref.invalidate(cashClosedSessionsProvider);
    return closed;
  }
}

final cashControllerProvider = Provider<CashController>((Ref ref) {
  return CashController(ref);
});
