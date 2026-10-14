import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'product_details_screen.dart';
import 'products_store.dart';

/// The product records, in display order. Search to filter, drag a row to
/// reorder, tap a row to see and edit its recipe, or add a new product from the
/// app bar.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.store});

  final ProductsStore store;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  bool get _isSearching => _query.trim().isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filtered(List<Product> products) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products
        .where((product) => product.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Add product',
            icon: const Icon(Icons.add),
            onPressed: () => _addProduct(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          if (widget.store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = widget.store.products;
          if (all.isEmpty) {
            return const Center(child: Text('No products yet.'));
          }

          final products = _filtered(all);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? const Center(
                        child: Text('No products match your search.'),
                      )
                    : _isSearching
                        ? _buildPlainList(context, products)
                        : _buildReorderableList(context, products),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReorderableList(BuildContext context, List<Product> products) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: products.length,
      onReorderItem: (oldIndex, newIndex) =>
          widget.store.moveProduct(oldIndex, newIndex),
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductTile(
          key: ValueKey(product.id),
          product: product,
          dragIndex: index,
          onTap: () => _openRecipe(context, product),
        );
      },
    );
  }

  Widget _buildPlainList(BuildContext context, List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductTile(
          product: product,
          onTap: () => _openRecipe(context, product),
        );
      },
    );
  }

  void _openRecipe(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailsScreen(
          store: widget.store,
          productId: product.id,
        ),
      ),
    );
  }

  Future<void> _addProduct(BuildContext context) async {
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (_) => const _AddProductDialog(),
    );
    if (result == null) return;
    final (name, price) = result;
    await widget.store.addProduct(name: name, price: price);
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.dragIndex,
  });

  final Product product;
  final VoidCallback onTap;

  /// The row's index when shown in the reorderable list; `null` hides the drag
  /// handle (e.g. while filtering, when reordering is off).
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.restaurant,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        product.name,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text('${formatPeso(product.price)} • ${product.recipe.length} in recipe'),
      trailing: dragIndex == null
          ? null
          : ReorderableDragStartListener(
              index: dragIndex!,
              child: const Icon(Icons.drag_handle),
            ),
    );
  }
}

/// Asks for a new product's name and price. Pops `(name, price)` or `null`.
class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog();

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  String get _name => _nameController.text.trim();

  double? get _price => double.tryParse(_priceController.text.trim());

  bool get _canAdd => _name.isNotEmpty && (_price ?? 0) > 0;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Product'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Price',
              prefixText: '₱ ',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _add(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canAdd ? _add : null,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _add() {
    if (!_canAdd) return;
    Navigator.of(context).pop((_name, _price!));
  }
}
