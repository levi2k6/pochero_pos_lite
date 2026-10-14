import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'products_repository.dart';

const _uuid = Uuid();

/// The products seeded on a fresh database, in their default order.
const defaultProducts = [
  Product(id: 'pochero', name: 'Pochero', price: 185),
  Product(id: 'lechon-kawali', name: 'Lechon Kawali', price: 220),
  Product(id: 'sizzling-sisig', name: 'Sizzling Sisig', price: 165),
  Product(id: 'chicken-adobo', name: 'Chicken Adobo', price: 145),
  Product(id: 'kare-kare', name: 'Kare-Kare', price: 210),
  Product(id: 'sinigang-na-baboy', name: 'Sinigang na Baboy', price: 175),
  Product(id: 'pancit-canton', name: 'Pancit Canton', price: 130),
  Product(id: 'lumpiang-shanghai', name: 'Lumpiang Shanghai', price: 95),
  Product(id: 'halo-halo', name: 'Halo-Halo', price: 110),
  Product(id: 'buko-juice', name: 'Buko Juice', price: 65),
];

/// Products and their recipes, in display order.
///
/// With a [ProductsRepository] the list survives restarts and a fresh database
/// is seeded with [defaultProducts]. Without one it is in-memory only, so unit
/// tests stay simple.
class ProductsStore extends ChangeNotifier {
  ProductsStore({this.repository});

  final ProductsRepository? repository;
  final List<Product> _products = [];
  bool _isLoading = false;
  bool _disposed = false;

  /// Read-only view of the products, in display order.
  List<Product> get products => List.unmodifiable(_products);

  bool get isLoading => _isLoading;

  /// The product with [id], or `null` if it no longer exists.
  Product? byId(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  /// Loads stored products, seeding [defaultProducts] on an empty store.
  Future<void> load() async {
    final repo = repository;
    if (repo == null) {
      if (_products.isEmpty) _products.addAll(defaultProducts);
      _notify();
      return;
    }

    _isLoading = true;
    _notify();
    try {
      var loaded = await repo.loadProducts();
      if (loaded.isEmpty) {
        for (final product in defaultProducts) {
          await repo.insertProduct(product);
        }
        loaded = await repo.loadProducts();
      }
      _products
        ..clear()
        ..addAll(loaded);
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Appends a new product so it shows last in the grid.
  Future<void> addProduct({required String name, required double price}) async {
    final product = Product(id: _uuid.v4(), name: name, price: price);
    _products.add(product);
    _notify();
    await repository?.insertProduct(product);
  }

  /// Moves the product at [oldIndex] to [newIndex] (list reorder).
  Future<void> moveProduct(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _products.length) return;
    final target = newIndex.clamp(0, _products.length - 1);
    if (oldIndex == target) return;

    final product = _products.removeAt(oldIndex);
    _products.insert(target, product);
    _notify();
    await repository?.saveProductOrder(_products);
  }

  /// Appends [item] to [productId]'s recipe.
  Future<void> addRecipeItem(String productId, RecipeItem item) {
    return _updateRecipe(productId, (recipe) => [...recipe, item]);
  }

  /// Removes the recipe entry at [index] from [productId].
  Future<void> removeRecipeAt(String productId, int index) {
    return _updateRecipe(productId, (recipe) {
      final next = [...recipe];
      if (index >= 0 && index < next.length) next.removeAt(index);
      return next;
    });
  }

  Future<void> _updateRecipe(
    String productId,
    List<RecipeItem> Function(List<RecipeItem> recipe) update,
  ) async {
    final index = _products.indexWhere((product) => product.id == productId);
    if (index == -1) return;

    final recipe = update(_products[index].recipe);
    _products[index] = _products[index].copyWith(recipe: recipe);
    _notify();
    await repository?.saveRecipe(productId, recipe);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Skips the rebuild when a pending [load] finishes after disposal.
  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
