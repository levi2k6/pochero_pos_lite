import 'package:flutter_test/flutter_test.dart';
import 'package:pochero_pos_lite/local_database.dart';
import 'package:pochero_pos_lite/models.dart';
import 'package:pochero_pos_lite/payments_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_path_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    useTempAppSupportDirectory();
  });

  setUp(() async {
    await LocalDatabase.instance.delete();
  });

  tearDown(() async {
    await LocalDatabase.instance.delete();
  });

  Payment samplePayment() {
    return Payment(
      id: 'pay-1',
      type: TransactionType.delivery,
      method: PaymentMethod.cash,
      amount: 500,
      change: 315,
      updatedAt: DateTime(2026, 10, 9, 14, 5),
      dirty: false,
      items: const [
        CartLine(product: Product(name: 'Pochero', price: 185), quantity: 2),
      ],
    );
  }

  test('inserts and reloads a payment with its items', () async {
    final repository = SqflitePaymentsRepository(LocalDatabase.instance);
    await repository.insertPayment(samplePayment());

    final loaded = await repository.loadPayments();

    expect(loaded, hasLength(1));
    final payment = loaded.single;
    expect(payment.id, 'pay-1');
    expect(payment.type, TransactionType.delivery);
    expect(payment.method, PaymentMethod.cash);
    expect(payment.amount, 500);
    expect(payment.change, 315);
    expect(payment.updatedAt, DateTime(2026, 10, 9, 14, 5));
    expect(payment.dirty, isFalse);
    expect(payment.items, hasLength(1));
    expect(payment.items.single.product.name, 'Pochero');
    expect(payment.items.single.product.price, 185);
    expect(payment.items.single.quantity, 2);
    expect(payment.total, 185);
  });

  test('payments survive closing and reopening the database', () async {
    await SqflitePaymentsRepository(LocalDatabase.instance)
        .insertPayment(samplePayment());
    await LocalDatabase.instance.close();

    final loaded =
        await SqflitePaymentsRepository(LocalDatabase.instance).loadPayments();

    expect(loaded, hasLength(1));
    expect(loaded.single.items, hasLength(1));
  });

  test('deletes a payment and its items', () async {
    final repository = SqflitePaymentsRepository(LocalDatabase.instance);
    await repository.insertPayment(samplePayment());

    await repository.deletePayment('pay-1');

    expect(await repository.loadPayments(), isEmpty);
  });
}
