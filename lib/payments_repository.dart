import 'package:sqflite/sqflite.dart';

import 'local_database.dart';
import 'models.dart';
import 'payment_items_table.dart';
import 'payments_table.dart';

/// Contract for where recorded payments are stored.
///
/// `SqflitePaymentsRepository` is the on-device implementation; tests inject an
/// in-memory fake.
abstract interface class PaymentsRepository {
  /// All payments, oldest first, each with its sold lines.
  Future<List<Payment>> loadPayments();

  /// Inserts a payment and its lines.
  Future<void> insertPayment(Payment payment);

  /// Removes a payment and its lines.
  Future<void> deletePayment(String id);
}

/// sqflite-backed [PaymentsRepository]: the device's offline store.
class SqflitePaymentsRepository implements PaymentsRepository {
  SqflitePaymentsRepository(this._local);

  final LocalDatabase _local;

  @override
  Future<List<Payment>> loadPayments() async {
    final db = await _local.open();
    final rows = await db.query(
      PaymentsTable.name,
      orderBy: '${PaymentsTable.updatedAt} ASC',
    );
    final items = await _itemsByPayment(db);

    return [
      for (final row in rows)
        Payment(
          id: row[PaymentsTable.id] as String,
          type: TransactionType.values.byName(
            row[PaymentsTable.type] as String,
          ),
          method: PaymentMethod.values.byName(
            row[PaymentsTable.method] as String,
          ),
          amount: (row[PaymentsTable.amount] as num).toDouble(),
          change: (row[PaymentsTable.change] as num).toDouble(),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row[PaymentsTable.updatedAt] as int,
          ),
          items: items[row[PaymentsTable.id] as String] ?? const [],
          dirty: (row[PaymentsTable.dirty] as int) == 1,
        ),
    ];
  }

  @override
  Future<void> insertPayment(Payment payment) async {
    final db = await _local.open();
    await db.transaction((txn) async {
      await txn.insert(PaymentsTable.name, {
        PaymentsTable.id: payment.id,
        PaymentsTable.type: payment.type.name,
        PaymentsTable.method: payment.method.name,
        PaymentsTable.amount: payment.amount,
        PaymentsTable.change: payment.change,
        PaymentsTable.updatedAt: payment.updatedAt.millisecondsSinceEpoch,
        PaymentsTable.dirty: payment.dirty ? 1 : 0,
      });
      for (final line in payment.items) {
        await txn.insert(PaymentItemsTable.name, {
          PaymentItemsTable.paymentId: payment.id,
          PaymentItemsTable.productName: line.product.name,
          PaymentItemsTable.unitPrice: line.product.price,
          PaymentItemsTable.quantity: line.quantity,
        });
      }
    });
  }

  @override
  Future<void> deletePayment(String id) async {
    final db = await _local.open();
    await db.transaction((txn) async {
      await txn.delete(
        PaymentItemsTable.name,
        where: '${PaymentItemsTable.paymentId} = ?',
        whereArgs: [id],
      );
      await txn.delete(
        PaymentsTable.name,
        where: '${PaymentsTable.id} = ?',
        whereArgs: [id],
      );
    });
  }

  Future<Map<String, List<CartLine>>> _itemsByPayment(Database db) async {
    final rows = await db.query(PaymentItemsTable.name);
    final byPayment = <String, List<CartLine>>{};
    for (final row in rows) {
      final paymentId = row[PaymentItemsTable.paymentId] as String;
      byPayment.putIfAbsent(paymentId, () => []).add(
            CartLine(
              product: Product(
                name: row[PaymentItemsTable.productName] as String,
                price: (row[PaymentItemsTable.unitPrice] as num).toDouble(),
              ),
              quantity: row[PaymentItemsTable.quantity] as int,
            ),
          );
    }
    return byPayment;
  }
}
