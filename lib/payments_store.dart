import 'package:flutter/foundation.dart';

import 'models.dart';
import 'payments_repository.dart';

/// Log of recorded payments.
///
/// With a [PaymentsRepository] the log survives app restarts: [load] reads the
/// stored payments and every [add] is persisted. Without one it is in-memory
/// only, so unit tests stay simple.
class PaymentsStore extends ChangeNotifier {
  PaymentsStore({this.repository});

  final PaymentsRepository? repository;
  final List<Payment> _payments = [];
  bool _isLoading = false;
  bool _disposed = false;

  /// Read-only view of the payments, oldest first.
  List<Payment> get payments => List.unmodifiable(_payments);

  bool get isEmpty => _payments.isEmpty;

  /// True while [load] is reading stored payments.
  bool get isLoading => _isLoading;

  /// Replaces the in-memory log with the stored payments.
  Future<void> load() async {
    final repo = repository;
    if (repo == null) return;

    _isLoading = true;
    _notify();
    try {
      final payments = await repo.loadPayments();
      _payments
        ..clear()
        ..addAll(payments);
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Records [payment] in memory first, then persists it.
  Future<void> add(Payment payment) async {
    _payments.add(payment);
    _notify();
    await repository?.insertPayment(payment);
  }

  /// Removes [payment] from memory first, then from the repository.
  Future<void> remove(Payment payment) async {
    _payments.remove(payment);
    _notify();
    await repository?.deletePayment(payment.id);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Skips the rebuild when a pending [load] finishes after disposal.
  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
