import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Contract for the remote backend sync.
abstract interface class PaymentsApi {
  /// Pushes [payments] to the backend `/sync` endpoint.
  Future<void> sync(List<Payment> payments);
}

/// REST client for the Go backend (`POST /sync`).
///
/// The base URL comes from the signed-in session. When it is empty the client
/// is unconfigured and calls throw a [StateError].
class HttpPaymentsApi implements PaymentsApi {
  HttpPaymentsApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 10);

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  @override
  Future<void> sync(List<Payment> payments) async {
    final response = await _client
        .post(
          _uri('/sync'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'payments': [
              for (final payment in payments) paymentPayload(payment),
            ],
          }),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpPaymentsException(
        'POST /sync failed (${response.statusCode})',
      );
    }
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

/// One payment in the `/sync` body: only the backend `payment` columns for now.
///
/// More entity types (products, items, …) will join the payload later.
Map<String, dynamic> paymentPayload(Payment payment) => {
      'id': payment.id,
      'transaction_type': payment.type.name,
      'method': payment.method.name,
      'paid_amount': payment.amount,
      'change_amount': payment.change,
    };

class HttpPaymentsException implements Exception {
  HttpPaymentsException(this.message);

  final String message;

  @override
  String toString() => 'HttpPaymentsException: $message';
}
