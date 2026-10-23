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
      items: const [
        CartLine(
          product: Product(name: 'Pochero', price: 185),
          quantity: 2,
        ),
      ],
    );

void main() {
  test('createPayment POSTs the payment payload', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('', 201);
    });
    final api = HttpPaymentsApi(
      baseUrl: 'http://localhost:8080',
      client: client,
    );

    await api.createPayment(_samplePayment());

    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'http://localhost:8080/payment');
    expect(captured.headers['content-type'], contains('application/json'));

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['id'], 'abc');
    expect(body['transaction_type'], 'delivery');
    expect(body['method'], 'gcash');
    expect(body['paid_amount'], 185);
    expect(body['change_amount'], 0);
    expect(body['items'], hasLength(1));
    expect((body['items'] as List).single['name'], 'Pochero');
  });

  test('createPayment throws on a non-2xx response', () async {
    final client = MockClient((_) async => http.Response('nope', 500));
    final api = HttpPaymentsApi(
      baseUrl: 'http://localhost:8080',
      client: client,
    );

    expect(
      api.createPayment(_samplePayment()),
      throwsA(isA<HttpPaymentsException>()),
    );
  });

  test('getPayment decodes the body and returns null on 404', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/missing')) {
        return http.Response('', 404);
      }
      return http.Response(jsonEncode({'id': 'abc'}), 200);
    });
    final api = HttpPaymentsApi(
      baseUrl: 'http://localhost:8080',
      client: client,
    );

    expect((await api.getPayment('abc'))?['id'], 'abc');
    expect(await api.getPayment('missing'), isNull);
  });

  test('calls fail when no backend URL is configured', () {
    final api = HttpPaymentsApi(baseUrl: '');

    expect(
      api.createPayment(_samplePayment()),
      throwsA(isA<StateError>()),
    );
  });
}
