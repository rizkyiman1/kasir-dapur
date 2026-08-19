import 'package:kasir_dapur/features/cash_management/domain/cash.dart';

abstract class CashRepository {
  Future<CashSession> openSession({
    required String businessId,
    required int openingAmount,
    String? userId,
  });

  Future<CashMovement> addMovement({
    required String sessionId,
    required String type,
    required int amount,
    String? note,
  });

  Future<CashSession> closeSession({
    required String sessionId,
    required int countedAmount,
  });

  Future<CashSession?> getOpenSession(String businessId);

  Future<CashSession?> getSession(String id);

  Future<CashDrawerSnapshot> drawer(String sessionId);

  Future<List<CashSession>> listClosed({
    required String businessId,
    int limit = 20,
  });
}
