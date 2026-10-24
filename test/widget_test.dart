import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pochero_pos_lite/main.dart';
import 'package:pochero_pos_lite/models.dart';
import 'package:pochero_pos_lite/payments_api.dart';
import 'package:pochero_pos_lite/payments_repository.dart';
import 'package:pochero_pos_lite/products_repository.dart';
import 'package:pochero_pos_lite/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [PaymentsRepository] so widget tests never touch sqflite.
class _FakePaymentsRepository implements PaymentsRepository {
  final List<Payment> payments = [];
  final List<String> syncedIds = [];

  @override
  Future<List<Payment>> loadPayments() async => List.of(payments);

  @override
  Future<void> insertPayment(Payment payment) async => payments.add(payment);

  @override
  Future<void> deletePayment(String id) async =>
      payments.removeWhere((payment) => payment.id == id);

  @override
  Future<void> markSynced(String id) async => syncedIds.add(id);
}

/// In-memory [PaymentsApi]; can fail or wait on [completer].
class _FakePaymentsApi implements PaymentsApi {
  _FakePaymentsApi({this.fail = false});

  final bool fail;
  final List<Payment> synced = [];
  Completer<void>? completer;

  @override
  Future<void> sync(List<Payment> payments) async {
    if (completer != null) await completer!.future;
    if (fail) throw Exception('offline');
    synced.addAll(payments);
  }
}

/// In-memory [ProductsRepository] so widget tests never touch sqflite.
class _FakeProductsRepository implements ProductsRepository {
  final List<Product> products = [];

  @override
  Future<List<Product>> loadProducts() async => List.of(products);

  @override
  Future<void> insertProduct(Product product) async => products.add(product);

  @override
  Future<void> saveProductOrder(List<Product> products) async {
    this.products
      ..clear()
      ..addAll(products);
  }

  @override
  Future<void> saveRecipe(String productId, List<RecipeItem> recipe) async {
    final index = products.indexWhere((product) => product.id == productId);
    if (index == -1) return;
    products[index] = products[index].copyWith(recipe: List.of(recipe));
  }
}

Future<SessionStore> _loggedInSession() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionStore(prefs);
  await session.login(
    url: 'http://localhost:8080',
    username: SessionStore.adminUsername,
    password: SessionStore.adminPassword,
  );
  return session;
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    PocheroPosLiteApp(
      session: await _loggedInSession(),
      repository: _FakePaymentsRepository(),
      productsRepository: _FakeProductsRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _dialogField() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

Finder _dialogConfirm() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Confirm'),
    );

Finder _dialogFields() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

Future<void> _confirmWithCash(WidgetTester tester, String cash) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
  await tester.pumpAndSettle();
  await tester.enterText(_dialogField(), cash);
  await tester.pump();
  await tester.tap(_dialogConfirm());
  await tester.pumpAndSettle();
}

Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('POS layout renders cart, products, and confirm', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Current Order'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Pochero'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('₱0.00'), findsOneWidget);
    expect(find.text('Walk-in'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Confirm'), findsOneWidget);
  });

  testWidgets('search filters the product grid', (tester) async {
    await _pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'pochero');
    await tester.pump();

    expect(find.text('Pochero'), findsOneWidget);
    expect(find.text('Lechon Kawali'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No products match your search.'), findsOneWidget);
  });

  testWidgets('tapping a product adds it to the cart', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Pochero'));
    await tester.pump();

    expect(find.text('1 x ₱185.00'), findsOneWidget);
    expect(
      find.text('No items yet.\nTap a product to add it.'),
      findsNothing,
    );
    expect(find.text('₱0.00'), findsNothing);
  });

  testWidgets('confirming a walk-in records a payment', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Pochero'));
    await tester.pump();
    await _confirmWithCash(tester, '500');

    expect(find.text('Payment Details'), findsOneWidget);
    await _goBack(tester);

    expect(
      find.text('No items yet.\nTap a product to add it.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Payments'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Walk-in • Cash'), findsOneWidget);
    expect(find.text('₱500.00'), findsNWidgets(2));
    expect(find.text('Change ₱315.00'), findsOneWidget);
    expect(find.text('Total (1)'), findsOneWidget);
  });

  testWidgets('confirming opens the new payment details', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Pochero'));
    await tester.pump();
    await _confirmWithCash(tester, '500');

    expect(find.text('Payment Details'), findsOneWidget);
    expect(find.text('Amount paid'), findsOneWidget);
    expect(find.text('₱500.00'), findsOneWidget);
    expect(find.text('₱315.00'), findsOneWidget);
    expect(find.text('Pochero'), findsOneWidget);
  });

  testWidgets('opening a payment shows its details and items', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Pochero'));
    await tester.pump();
    await _confirmWithCash(tester, '500');
    await _goBack(tester);

    await tester.tap(find.byTooltip('Payments'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Walk-in • Cash'));
    await tester.pumpAndSettle();

    expect(find.text('Payment Details'), findsOneWidget);
    expect(find.text('Paid at'), findsOneWidget);
    expect(find.text('Amount paid'), findsOneWidget);
    expect(find.text('₱500.00'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('₱315.00'), findsOneWidget);
    expect(find.text('Item'), findsOneWidget);
    expect(find.text('Qty'), findsOneWidget);
    expect(find.text('Unit Price'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Pochero'), findsOneWidget);
  });

  testWidgets('deleting a payment removes it after confirming',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Pochero'));
    await tester.pump();
    await _confirmWithCash(tester, '500');
    await _goBack(tester);

    await tester.tap(find.byTooltip('Payments'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Walk-in • Cash'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete payment?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Payment Details'), findsNothing);
    expect(find.text('No payments yet.'), findsOneWidget);
  });

  testWidgets('cancelling delete keeps the payment', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Pochero'));
    await tester.pump();
    await _confirmWithCash(tester, '500');
    await _goBack(tester);

    await tester.tap(find.byTooltip('Payments'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Walk-in • Cash'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Payment Details'), findsOneWidget);
    expect(find.text('Paid at'), findsOneWidget);
  });

  testWidgets('confirming with GCash records a GCash payment',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Pochero'));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GCash'));
    await tester.pumpAndSettle();
    await tester.tap(_dialogConfirm());
    await tester.pumpAndSettle();
    await _goBack(tester);

    await tester.tap(find.byTooltip('Payments'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Walk-in • GCash'), findsOneWidget);
    expect(find.text('₱185.00'), findsNWidgets(2));
    expect(find.text('Change ₱0.00'), findsOneWidget);
    expect(find.text('Total (1)'), findsOneWidget);
  });

  testWidgets('confirming a delivery records a delivery payment',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Pochero'));
    await tester.pump();
    await tester.tap(find.text('Delivery'));
    await tester.pump();
    await _confirmWithCash(tester, '200');
    await _goBack(tester);

    await tester.tap(find.byTooltip('Payments'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Delivery • Cash'), findsOneWidget);
    expect(find.text('₱200.00'), findsNWidgets(2));
    expect(find.text('Change ₱15.00'), findsOneWidget);
    expect(find.text('Total (1)'), findsOneWidget);
  });

  testWidgets('adding a product shows it in the list and the grid',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Products'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    await tester.enterText(_dialogFields().at(0), 'Bicol Express');
    await tester.enterText(_dialogFields().at(1), '150');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Bicol Express'),
      find.byType(ReorderableListView),
      const Offset(0, -200),
    );
    expect(find.text('Bicol Express'), findsOneWidget);

    await _goBack(tester);
    await tester.enterText(find.byType(TextField), 'bicol');
    await tester.pumpAndSettle();
    expect(find.text('Bicol Express'), findsOneWidget);
  });

  testWidgets('a recipe can add and remove ingredients', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Products'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pochero'));
    await tester.pumpAndSettle();

    expect(find.text('Recipe'), findsOneWidget);
    expect(find.text('No ingredients yet. Tap + to add one.'), findsOneWidget);

    await tester.tap(find.byTooltip('Add ingredient'));
    await tester.pumpAndSettle();
    await tester.enterText(_dialogFields().at(0), 'Pork belly');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Pork belly'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Pork belly'), findsNothing);
    expect(find.text('No ingredients yet. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('search filters the product list', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Products'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'lechon');
    await tester.pumpAndSettle();

    expect(find.text('Lechon Kawali'), findsOneWidget);
    expect(find.text('Pochero'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No products match your search.'), findsOneWidget);
  });

  testWidgets('payment list defaults to today and can show all',
      (tester) async {
    final payments = _FakePaymentsRepository()
      ..payments.addAll([
        Payment(
          id: '00000000-old',
          type: TransactionType.walkIn,
          method: PaymentMethod.cash,
          amount: 100,
          change: 0,
          updatedAt: DateTime(2020, 1, 1, 10),
        ),
        Payment(
          id: '00000000-new',
          type: TransactionType.walkIn,
          method: PaymentMethod.cash,
          amount: 200,
          change: 0,
          updatedAt: DateTime.now(),
        ),
      ]);

    await tester.pumpWidget(
      PocheroPosLiteApp(
        session: await _loggedInSession(),
        repository: payments,
        productsRepository: _FakeProductsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Payments'));
    await tester.pumpAndSettle();

    expect(find.text('Total (1)'), findsOneWidget);
    expect(find.text('₱100.00'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Total (2)'), findsOneWidget);
  });

  testWidgets('manual sync shows a spinner then a success message',
      (tester) async {
    final repository = _FakePaymentsRepository();
    final api = _FakePaymentsApi()..completer = Completer<void>();

    await tester.pumpWidget(
      PocheroPosLiteApp(
        session: await _loggedInSession(),
        repository: repository,
        productsRepository: _FakeProductsRepository(),
        paymentsApi: api,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pochero'));
    await tester.pump();
    await _confirmWithCash(tester, '500');
    await _goBack(tester);

    await tester.tap(find.byTooltip('Sync'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to sync'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sync now'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Sending 1 payment'), findsOneWidget);

    api.completer!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Synced 1 payment.'), findsOneWidget);
    expect(repository.syncedIds, contains(api.synced.single.id));
  });

  testWidgets('manual sync reports when there is nothing to sync',
      (tester) async {
    final api = _FakePaymentsApi();

    await tester.pumpWidget(
      PocheroPosLiteApp(
        session: await _loggedInSession(),
        repository: _FakePaymentsRepository(),
        productsRepository: _FakeProductsRepository(),
        paymentsApi: api,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sync now'));
    await tester.pumpAndSettle();

    expect(find.text('Everything is up to date.'), findsOneWidget);
    expect(api.synced, isEmpty);
  });

  testWidgets('manual sync reports a failure and keeps payments dirty',
      (tester) async {
    final repository = _FakePaymentsRepository();
    final api = _FakePaymentsApi(fail: true);

    await tester.pumpWidget(
      PocheroPosLiteApp(
        session: await _loggedInSession(),
        repository: repository,
        productsRepository: _FakeProductsRepository(),
        paymentsApi: api,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pochero'));
    await tester.pump();
    await _confirmWithCash(tester, '500');
    await _goBack(tester);

    await tester.tap(find.byTooltip('Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sync now'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sync failed:'), findsOneWidget);
    expect(repository.syncedIds, isEmpty);
    expect(repository.payments.single.dirty, isTrue);
  });

  testWidgets('signed-out app shows login and opens the POS after login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = SessionStore(prefs);

    await tester.pumpWidget(
      PocheroPosLiteApp(
        session: session,
        repository: _FakePaymentsRepository(),
        productsRepository: _FakeProductsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Current Order'), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'http://localhost:8080',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'admin');
    await tester.enterText(find.byType(TextFormField).at(2), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Current Order'), findsOneWidget);
    expect(session.isLoggedIn, isTrue);
    expect(session.url, 'http://localhost:8080');
  });

  testWidgets('login shows an error for wrong credentials', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = SessionStore(prefs);

    await tester.pumpWidget(
      PocheroPosLiteApp(
        session: session,
        repository: _FakePaymentsRepository(),
        productsRepository: _FakeProductsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'http://localhost:8080',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'admin');
    await tester.enterText(find.byType(TextFormField).at(2), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid username or password.'), findsOneWidget);
    expect(find.text('Current Order'), findsNothing);
  });

  testWidgets('logout returns to the login screen', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Current Order'), findsNothing);
  });

  test('session persists across instances and normalizes the URL', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = SessionStore(prefs);

    expect(
      await first.login(
        url: 'http://10.0.0.5:8080/',
        username: SessionStore.adminUsername,
        password: SessionStore.adminPassword,
      ),
      isTrue,
    );

    final second = SessionStore(prefs);
    await second.load();

    expect(second.isLoggedIn, isTrue);
    expect(second.username, 'admin');
    expect(second.url, 'http://10.0.0.5:8080');
  });

  testWidgets('dirty payments show an unsynced indicator until synced',
      (tester) async {
    final repository = _FakePaymentsRepository();

    await tester.pumpWidget(
      PocheroPosLiteApp(
        session: await _loggedInSession(),
        repository: repository,
        productsRepository: _FakeProductsRepository(),
        paymentsApi: _FakePaymentsApi(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pochero'));
    await tester.pump();
    await _confirmWithCash(tester, '500');

    expect(find.text('Unsynced'), findsOneWidget);
    await _goBack(tester);

    await tester.tap(find.byTooltip('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('Unsynced'), findsOneWidget);
    await _goBack(tester);

    await tester.tap(find.byTooltip('Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sync now'));
    await tester.pumpAndSettle();
    await _goBack(tester);

    await tester.tap(find.byTooltip('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('Unsynced'), findsNothing);
  });
}
