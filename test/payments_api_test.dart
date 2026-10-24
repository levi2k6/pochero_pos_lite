import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pochero_pos_lite/models.dart';
import 'package:pochero_pos_lite/payments_api.dart';

Payment _samplePayment() => Payment(
      id: 'abc',
      type: TransactionType.delivery,
      method: PaymentMethod.gcash,
      amount: 185,
      change: 0,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('sync POSTs the dirty payments to /sync', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('', 200);
    });
    final api = HttpPaymentsApi(
      baseUrl: 'http://localhost:8080',
      client: client,
    );

    await api.sync([_samplePayment()]);

    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'http://localhost:8080/sync');
    expect(captured.headers['content-type'], contains('application/json'));

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    final payments = body['payments'] as List;
    expect(payments, hasLength(1));

    final payment = payments.single as Map<String, dynamic>;
    expect(payment['id'], 'abc');
    expect(payment['transaction_type'], 'delivery');
    expect(payment['method'], 'gcash');
    expect(payment['paid_amount'], 185);
    expect(payment['change_amount'], 0);
    expect(payment.containsKey('items'), isFalse);
  });

  test('sync throws on a non-2xx response', () async {
    final client = MockClient((_) async => http.Response('nope', 500));
    final api = HttpPaymentsApi(
      baseUrl: 'http://localhost:8080',
      client: client,
    );

    expect(
      api.sync([_samplePayment()]),
      throwsA(isA<HttpPaymentsException>()),
    );
  });

  test('sync fails when no backend URL is configured', () {
    final api = HttpPaymentsApi(baseUrl: '');

    expect(api.sync([_samplePayment()]), throwsA(isA<StateError>()));
  });
}
