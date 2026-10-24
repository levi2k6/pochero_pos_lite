import 'package:flutter/foundation.dart';

import 'models.dart';
import 'payments_api.dart';
import 'payments_repository.dart';

/// What a manual sync attempt did.
class SyncResult {
  const SyncResult({this.synced = 0, this.error});

  /// How many payments were pushed and marked clean.
  final int synced;

  /// A human-readable failure message, or `null` on success.
  final String? error;

  bool get failed => error != null;

  bool get upToDate => error == null && synced == 0;
}

/// Log of recorded payments.
///
/// With a [PaymentsRepository] the log survives app restarts: [load] reads the
/// stored payments and every [add] is persisted. With a [PaymentsApi] dirty
/// payments can be pushed on demand via [syncPending] — nothing syncs on its
/// own, so the backend is only called from the Sync screen.
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

  /// Payments still waiting to be synced.
  List<Payment> get pendingSync =>
      _payments.where((payment) => payment.dirty).toList();

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

  /// Records [payment] in memory first, then persists it. Nothing is sent to
  /// the backend here; it stays dirty until [syncPending] runs.
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

  /// Pushes every dirty payment to the backend. Manual only.
  Future<SyncResult> syncPending() async {
    final client = api;
    if (client == null) {
      return const SyncResult(error: 'Backend is not configured.');
    }
    final pending = pendingSync;
    if (pending.isEmpty) return const SyncResult();

    try {
      await client.sync(pending);
    } catch (error) {
      final message =
          error is HttpPaymentsException ? error.message : '$error';
      return SyncResult(error: message);
    }

    for (final payment in pending) {
      await repository?.markSynced(payment.id);
      _markSyncedInMemory(payment.id);
    }
    return SyncResult(synced: pending.length);
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
