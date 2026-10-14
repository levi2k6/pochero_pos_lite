/// Schema for the `products` table: one product record and its grid position.
class ProductsTable {
  const ProductsTable._();

  static const name = 'products';

  static const id = 'id';
  static const productName = 'name';
  static const price = 'price';
  static const position = 'position';

  static const createSql = '''
CREATE TABLE $name (
  $id TEXT PRIMARY KEY,
  $productName TEXT NOT NULL,
  $price REAL NOT NULL,
  $position INTEGER NOT NULL
)''';
}
