import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'payments_api.dart';
import 'payments_repository.dart';

/// Log of recorded payments.
///
/// With a [PaymentsRepository] the log survives app restarts: [load] reads the
/// stored payments and every [add] is persisted. With a [PaymentsApi] each new
/// payment is pushed to the backend and marked clean on success; payments left
/// dirty are retried on [load]. Without either it is in-memory only, so unit
/// tests stay simple.
class PaymentsStore extends ChangeNotifier {
  PaymentsStore({this.repository, this.api});

  final PaymentsRepository? repository;
  final PaymentsApi? api;
  final List<Payment> _payments = [];
  bool _isLoading = false;
  bool _disposed = false;

  /// Read-only view of the payments, oldest first.
  List<Payment> get payments => List.unmodifiable(_payments);

  bool get isEmpty => _payments.isEmpty;

  /// True while [load] is reading stored payments.
  bool get isLoading => _isLoading;

  /// Replaces the in-memory log with the stored payments, then retries any
  /// payments still waiting to sync.
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
    unawaited(_syncPending());
  }

  /// Records [payment] in memory first, then persists and syncs it.
  Future<void> add(Payment payment) async {
    _payments.add(payment);
    _notify();
    await repository?.insertPayment(payment);
    await _sync(payment);
  }

  /// Removes [payment] from memory first, then from the repository.
  Future<void> remove(Payment payment) async {
    _payments.remove(payment);
    _notify();
    await repository?.deletePayment(payment.id);
  }

  /// Pushes one payment to the backend and clears its dirty flag on success.
  /// Failures are swallowed so the app keeps working offline; the payment stays
  /// dirty and is retried on the next [load].
  Future<void> _sync(Payment payment) async {
    final client = api;
    if (client == null) return;

    try {
      await client.createPayment(payment);
    } catch (_) {
      return;
    }
    await repository?.markSynced(payment.id);
    _markSyncedInMemory(payment.id);
  }

  Future<void> _syncPending() async {
    if (api == null) return;
    for (final payment in List.of(_payments)) {
      if (payment.dirty) await _sync(payment);
    }
  }

  void _markSyncedInMemory(String id) {
    final index = _payments.indexWhere((payment) => payment.id == id);
    if (index == -1) return;
    _payments[index] = _payments[index].copyWith(dirty: false);
    _notify();
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
