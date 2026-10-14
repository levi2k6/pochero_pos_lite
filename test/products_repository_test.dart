import 'package:flutter_test/flutter_test.dart';
import 'package:pochero_pos_lite/local_database.dart';
import 'package:pochero_pos_lite/models.dart';
import 'package:pochero_pos_lite/products_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_path_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    useTempAppSupportDirectory();
  });

  setUp(() async {
    await LocalDatabase.instance.delete();
  });

  tearDown(() async {
    await LocalDatabase.instance.delete();
  });

  test('inserts products and reloads them in order', () async {
    final repository = SqfliteProductsRepository(LocalDatabase.instance);
    await repository.insertProduct(
      const Product(id: 'a', name: 'Pochero', price: 185),
    );
    await repository.insertProduct(
      const Product(id: 'b', name: 'Lechon Kawali', price: 220),
    );

    final loaded = await repository.loadProducts();

    expect(loaded.map((product) => product.id), ['a', 'b']);
    expect(loaded.first.name, 'Pochero');
    expect(loaded.first.price, 185);
  });

  test('saves a product recipe', () async {
    final repository = SqfliteProductsRepository(LocalDatabase.instance);
    await repository.insertProduct(
      const Product(id: 'a', name: 'Pochero', price: 185),
    );

    await repository.saveRecipe('a', const [
      RecipeItem(name: 'Pork belly'),
      RecipeItem(name: 'Saba banana'),
    ]);

    final loaded = await repository.loadProducts();

    expect(loaded.single.recipe, hasLength(2));
    expect(loaded.single.recipe.first.name, 'Pork belly');
    expect(loaded.single.recipe.last.name, 'Saba banana');
  });

  test('persists a changed product order', () async {
    final repository = SqfliteProductsRepository(LocalDatabase.instance);
    await repository.insertProduct(
      const Product(id: 'a', name: 'Pochero', price: 185),
    );
    await repository.insertProduct(
      const Product(id: 'b', name: 'Lechon Kawali', price: 220),
    );

    await repository.saveProductOrder(const [
      Product(id: 'b', name: 'Lechon Kawali', price: 220),
      Product(id: 'a', name: 'Pochero', price: 185),
    ]);

    final loaded = await repository.loadProducts();

    expect(loaded.map((product) => product.id), ['b', 'a']);
  });
}
