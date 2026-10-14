/// Schema for the `payment_items` table: one sold line of a payment.
///
/// `payment_id` points back at its `payments` row. The product name and price
/// are snapshots taken at sale time.
class PaymentItemsTable {
  const PaymentItemsTable._();

  static const name = 'payment_items';

  static const id = 'id';
  static const paymentId = 'payment_id';
  static const productName = 'product_name';
  static const unitPrice = 'unit_price';
  static const quantity = 'quantity';

  static const createSql = '''
CREATE TABLE $name (
  $id INTEGER PRIMARY KEY AUTOINCREMENT,
  $paymentId TEXT NOT NULL,
  $productName TEXT NOT NULL,
  $unitPrice REAL NOT NULL,
  $quantity INTEGER NOT NULL
)''';

  static const createPaymentIndexSql = '''
CREATE INDEX idx_${name}_payment ON $name ($paymentId)''';
}
