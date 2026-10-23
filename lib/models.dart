/// The kind of sale: paid at the counter, or a delivery order.
enum TransactionType {
  walkIn,
  delivery;

  String get label => switch (this) {
        TransactionType.walkIn => 'Walk-in',
        TransactionType.delivery => 'Delivery',
      };
}

/// How a payment was made.
enum PaymentMethod {
  cash,
  gcash;

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.gcash => 'GCash',
      };
}

/// One ingredient in a product's recipe.
class RecipeItem {
  const RecipeItem({required this.name});

  final String name;
}

/// One sellable food product with an optional recipe.
class Product {
  const Product({
    required this.name,
    required this.price,
    this.id = '',
    this.recipe = const [],
  });

  final String id;
  final String name;
  final double price;
  final List<RecipeItem> recipe;

  Product copyWith({
    String? id,
    String? name,
    double? price,
    List<RecipeItem>? recipe,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      recipe: recipe ?? this.recipe,
    );
  }
}

/// One line in the current order.
class CartLine {
  const CartLine({required this.product, this.quantity = 1});

  final Product product;
  final int quantity;

  double get lineTotal => product.price * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(product: product, quantity: quantity ?? this.quantity);
  }
}

/// One recorded payment.
class Payment {
  const Payment({
    required this.id,
    required this.type,
    required this.method,
    required this.amount,
    required this.change,
    required this.updatedAt,
    this.items = const [],
    this.dirty = true,
  });

  final String id;
  final TransactionType type;
  final PaymentMethod method;
  final double amount;
  final double change;
  final DateTime updatedAt;

  /// The order lines that were sold in this payment.
  final List<CartLine> items;

  /// True while the payment still needs to be synced to the backend.
  final bool dirty;

  double get total => amount - change;

  Payment copyWith({bool? dirty}) {
    return Payment(
      id: id,
      type: type,
      method: method,
      amount: amount,
      change: change,
      updatedAt: updatedAt,
      items: items,
      dirty: dirty ?? this.dirty,
    );
  }
}

String formatPeso(double amount) => '₱${amount.toStringAsFixed(2)}';

/// Formats a timestamp, e.g. `2026-10-09 14:05`.
String formatDateTime(DateTime dateTime) {
  String two(int value) => value.toString().padLeft(2, '0');
  final date = '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
  final time = '${two(dateTime.hour)}:${two(dateTime.minute)}';
  return '$date $time';
}
