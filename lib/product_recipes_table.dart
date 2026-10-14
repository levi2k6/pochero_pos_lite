/// Schema for the `product_recipes` table: one ingredient of a product.
///
/// `product_id` points back at its `products` row.
class ProductRecipesTable {
  const ProductRecipesTable._();

  static const name = 'product_recipes';

  static const id = 'id';
  static const productId = 'product_id';
  static const ingredient = 'ingredient';
  static const position = 'position';

  static const createSql = '''
CREATE TABLE $name (
  $id INTEGER PRIMARY KEY AUTOINCREMENT,
  $productId TEXT NOT NULL,
  $ingredient TEXT NOT NULL,
  $position INTEGER NOT NULL
)''';

  static const createProductIndexSql = '''
CREATE INDEX idx_${name}_product ON $name ($productId)''';
}
