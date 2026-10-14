/// Schema for the `payments` table.
///
/// One recorded payment. Its sold lines live in `payment_items`, keyed by
/// `payment_id`.
class PaymentsTable {
  const PaymentsTable._();

  static const name = 'payments';

  static const id = 'id';
  static const type = 'type';
  static const method = 'method';
  static const amount = 'amount';
  static const change = 'change';
  static const updatedAt = 'updated_at';
  static const dirty = 'dirty';

  static const createSql = '''
CREATE TABLE $name (
  $id TEXT PRIMARY KEY,
  $type TEXT NOT NULL,
  $method TEXT NOT NULL,
  $amount REAL NOT NULL,
  $change REAL NOT NULL,
  $updatedAt INTEGER NOT NULL,
  $dirty INTEGER NOT NULL DEFAULT 1
)''';
}
