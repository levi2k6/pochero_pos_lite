import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Contract for the remote payment backend.
abstract interface class PaymentsApi {
  /// Creates [payment] on the backend.
  Future<void> createPayment(Payment payment);

  /// Reads a payment's raw backend payload, or `null` when it does not exist.
  Future<Map<String, dynamic>?> getPayment(String id);
}

/// REST client for the Go backend (`POST /payment`, `GET /payment/{id}`).
///
/// The base URL comes from the signed-in [SessionStore]. When it is empty the
/// client is unconfigured and calls throw a [StateError]; [PaymentsStore] treats
/// that as "sync unavailable" and leaves the payment dirty.
class HttpPaymentsApi implements PaymentsApi {
  HttpPaymentsApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 10);

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  @override
  Future<void> createPayment(Payment payment) async {
    final response = await _client
        .post(
          _uri('/payment'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(paymentPayload(payment)),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpPaymentsException(
        'POST /payment failed (${response.statusCode})',
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> getPayment(String id) async {
    final response =
        await _client.get(_uri('/payment/$id')).timeout(_timeout);
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpPaymentsException(
        'GET /payment/$id failed (${response.statusCode})',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Uri _uri(String path) {
    if (!isConfigured) {
      throw StateError('Backend URL is not set');
    }
    final base = baseUrl.trim().endsWith('/')
        ? baseUrl.trim().substring(0, baseUrl.trim().length - 1)
        : baseUrl.trim();
    return Uri.parse('$base$path');
  }
}

/// The JSON body for `POST /payment`.
///
/// Mirrors the backend `payment` columns; `items` carries the sold lines so the
/// server can resolve/attach products.
Map<String, dynamic> paymentPayload(Payment payment) => {
      'id': payment.id,
      'transaction_type': payment.type.name,
      'method': payment.method.name,
      'paid_amount': payment.amount,
      'change_amount': payment.change,
      'items': [
        for (final line in payment.items)
          {
            'name': line.product.name,
            'quantity': line.quantity,
            'unit_price': line.product.price,
          },
      ],
    };

class HttpPaymentsException implements Exception {
  HttpPaymentsException(this.message);

  final String message;

  @override
  String toString() => 'HttpPaymentsException: $message';
}
