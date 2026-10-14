import 'package:sqflite/sqflite.dart';

import 'local_database.dart';
import 'models.dart';
import 'product_recipes_table.dart';
import 'products_table.dart';

/// Contract for where product records and their recipes are stored.
///
/// `SqfliteProductsRepository` is the on-device implementation; tests inject an
/// in-memory fake.
abstract interface class ProductsRepository {
  /// All products in display order, each with its recipe.
  Future<List<Product>> loadProducts();

  /// Inserts a product (appended last) and its recipe.
  Future<void> insertProduct(Product product);

  /// Rewrites each product's position to match [products]' order.
  Future<void> saveProductOrder(List<Product> products);

  /// Replaces [productId]'s whole recipe with [recipe].
  Future<void> saveRecipe(String productId, List<RecipeItem> recipe);
}

/// sqflite-backed [ProductsRepository]: the device's offline store.
class SqfliteProductsRepository implements ProductsRepository {
  SqfliteProductsRepository(this._local);

  final LocalDatabase _local;

  @override
  Future<List<Product>> loadProducts() async {
    final db = await _local.open();
    final productRows = await db.query(
      ProductsTable.name,
      orderBy: '${ProductsTable.position} ASC',
    );
    final recipeRows = await db.query(
      ProductRecipesTable.name,
      orderBy: '${ProductRecipesTable.position} ASC',
    );

    final recipes = <String, List<RecipeItem>>{};
    for (final row in recipeRows) {
      final productId = row[ProductRecipesTable.productId] as String;
      recipes.putIfAbsent(productId, () => []).add(
            RecipeItem(
              name: row[ProductRecipesTable.ingredient] as String,
            ),
          );
    }

    return [
      for (final row in productRows)
        Product(
          id: row[ProductsTable.id] as String,
          name: row[ProductsTable.productName] as String,
          price: (row[ProductsTable.price] as num).toDouble(),
          recipe: recipes[row[ProductsTable.id] as String] ?? const [],
        ),
    ];
  }

  @override
  Future<void> insertProduct(Product product) async {
    final db = await _local.open();
    await db.transaction((txn) async {
      final count = Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM ${ProductsTable.name}'),
          ) ??
          0;
      await txn.insert(ProductsTable.name, {
        ProductsTable.id: product.id,
        ProductsTable.productName: product.name,
        ProductsTable.price: product.price,
        ProductsTable.position: count,
      });
      await _replaceRecipe(txn, product.id, product.recipe);
    });
  }

  @override
  Future<void> saveProductOrder(List<Product> products) async {
    final db = await _local.open();
    await db.transaction((txn) async {
      for (var i = 0; i < products.length; i++) {
        await txn.update(
          ProductsTable.name,
          {ProductsTable.position: i},
          where: '${ProductsTable.id} = ?',
          whereArgs: [products[i].id],
        );
      }
    });
  }

  @override
  Future<void> saveRecipe(String productId, List<RecipeItem> recipe) async {
    final db = await _local.open();
    await db.transaction((txn) => _replaceRecipe(txn, productId, recipe));
  }

  Future<void> _replaceRecipe(
    DatabaseExecutor txn,
    String productId,
    List<RecipeItem> recipe,
  ) async {
    await txn.delete(
      ProductRecipesTable.name,
      where: '${ProductRecipesTable.productId} = ?',
      whereArgs: [productId],
    );
    for (var i = 0; i < recipe.length; i++) {
      await txn.insert(ProductRecipesTable.name, {
        ProductRecipesTable.productId: productId,
        ProductRecipesTable.ingredient: recipe[i].name,
        ProductRecipesTable.position: i,
      });
    }
  }
}
