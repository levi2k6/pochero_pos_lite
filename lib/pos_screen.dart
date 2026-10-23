import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'cash_received_dialog.dart';
import 'local_database.dart';
import 'models.dart';
import 'payment_details_screen.dart';
import 'payments_api.dart';
import 'payments_repository.dart';
import 'payments_screen.dart';
import 'payments_store.dart';
import 'products_repository.dart';
import 'products_screen.dart';
import 'products_store.dart';

const _uuid = Uuid();

/// The POS scene: order on the left, product grid on the right.
///
/// [repository], [productsRepository], and [paymentsApi] default to the
/// sqflite/REST implementations; tests inject fakes.
class PosScreen extends StatefulWidget {
  const PosScreen({
    super.key,
    this.repository,
    this.productsRepository,
    this.paymentsApi,
    this.backendUrl = '',
    this.onLogout,
  });

  final PaymentsRepository? repository;
  final ProductsRepository? productsRepository;
  final PaymentsApi? paymentsApi;
  final String backendUrl;
  final VoidCallback? onLogout;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<CartLine> _cart = [];
  late final PaymentsStore _payments;
  late final ProductsStore _products;
  String _query = '';
  TransactionType _type = TransactionType.walkIn;

  @override
  void initState() {
    super.initState();
    _payments = PaymentsStore(
      repository: widget.repository ??
          SqflitePaymentsRepository(LocalDatabase.instance),
      api: widget.paymentsApi ??
          (widget.backendUrl.trim().isEmpty
              ? null
              : HttpPaymentsApi(baseUrl: widget.backendUrl)),
    )..load();
    _products = ProductsStore(
      repository: widget.productsRepository ??
          SqfliteProductsRepository(LocalDatabase.instance),
    )
      ..addListener(_onProductsChanged)
      ..load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _payments.dispose();
    _products
      ..removeListener(_onProductsChanged)
      ..dispose();
    super.dispose();
  }

  void _onProductsChanged() {
    if (mounted) setState(() {});
  }

  double get _total =>
      _cart.fold(0, (sum, line) => sum + line.lineTotal);

  List<Product> get _filteredProducts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _products.products;
    return _products.products
        .where((product) => product.name.toLowerCase().contains(query))
        .toList();
  }

  void _addToCart(Product product) {
    setState(() {
      final index =
          _cart.indexWhere((line) => line.product.name == product.name);
      if (index == -1) {
        _cart.add(CartLine(product: product));
      } else {
        _cart[index] =
            _cart[index].copyWith(quantity: _cart[index].quantity + 1);
      }
    });
  }

  void _changeQuantity(CartLine line, int delta) {
    setState(() {
      final index = _cart.indexOf(line);
      if (index == -1) return;
      final next = _cart[index].quantity + delta;
      if (next <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index] = _cart[index].copyWith(quantity: next);
      }
    });
  }

  Future<void> _confirm() async {
    if (_cart.isEmpty) return;
    final total = _total;
    final result = await showDialog<(PaymentMethod, double)>(
      context: context,
      builder: (_) => CashReceivedDialog(total: total),
    );
    if (result == null || !mounted) return;
    final (method, amount) = result;

    final payment = Payment(
      id: _uuid.v4(),
      type: _type,
      method: method,
      amount: amount,
      change: amount - total,
      updatedAt: DateTime.now(),
      items: List.of(_cart),
    );
    await _payments.add(payment);
    if (!mounted) return;
    setState(_cart.clear);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentDetailsScreen(payment: payment, store: _payments),
      ),
    );
  }

  void _openPayments() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentsScreen(store: _payments),
      ),
    );
  }

  void _openProducts() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductsScreen(store: _products),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pochero POS'),
        actions: [
          IconButton(
            tooltip: 'Products',
            icon: const Icon(Icons.restaurant_menu),
            onPressed: _openProducts,
          ),
          IconButton(
            tooltip: 'Payments',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: _openPayments,
          ),
          if (widget.onLogout != null)
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: widget.onLogout,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cartWidth = math.min(360.0, constraints.maxWidth * 0.38);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: cartWidth,
                  child: _CartPanel(
                    cart: _cart,
                    total: _total,
                    type: _type,
                    onTypeChanged: (value) => setState(() => _type = value),
                    onQuantityChanged: _changeQuantity,
                    onConfirm: _confirm,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _ProductPanel(
                    searchController: _searchController,
                    products: _filteredProducts,
                    onQueryChanged: (value) => setState(() => _query = value),
                    onClearQuery: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    onProductSelected: _addToCart,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The left side: current order, total, order type, and confirm.
class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.cart,
    required this.total,
    required this.type,
    required this.onTypeChanged,
    required this.onQuantityChanged,
    required this.onConfirm,
  });

  final List<CartLine> cart;
  final double total;
  final TransactionType type;
  final ValueChanged<TransactionType> onTypeChanged;
  final void Function(CartLine line, int delta) onQuantityChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = cart.fold(0, (sum, line) => sum + line.quantity);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Current Order',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (itemCount > 0)
                  Chip(
                    label: Text('$itemCount'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? const _EmptyCartPlaceholder()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cart.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _CartLineTile(
                      line: cart[index],
                      onIncrement: () => onQuantityChanged(cart[index], 1),
                      onDecrement: () => onQuantityChanged(cart[index], -1),
                    ),
                  ),
          ),
          const Divider(height: 1),
          _TotalBar(
            total: total,
            canConfirm: cart.isNotEmpty,
            type: type,
            onTypeChanged: onTypeChanged,
            onConfirm: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
  });

  final CartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${line.quantity} x ${formatPeso(line.product.price)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Decrease',
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Increase',
          ),
          SizedBox(
            width: 72,
            child: Text(
              formatPeso(line.lineTotal),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCartPlaceholder extends StatelessWidget {
  const _EmptyCartPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No items yet.\nTap a product to add it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({
    required this.total,
    required this.canConfirm,
    required this.type,
    required this.onTypeChanged,
    required this.onConfirm,
  });

  final double total;
  final bool canConfirm;
  final TransactionType type;
  final ValueChanged<TransactionType> onTypeChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Total',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatPeso(total),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.walkIn,
                  label: Text('Walk-in'),
                  icon: Icon(Icons.storefront_outlined),
                ),
                ButtonSegment(
                  value: TransactionType.delivery,
                  label: Text('Delivery'),
                  icon: Icon(Icons.delivery_dining_outlined),
                ),
              ],
              selected: {type},
              onSelectionChanged: (selection) =>
                  onTypeChanged(selection.first),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canConfirm ? onConfirm : null,
            icon: const Icon(Icons.check),
            label: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

/// The right side: search plus the food products.
class _ProductPanel extends StatelessWidget {
  const _ProductPanel({
    required this.searchController,
    required this.products,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onProductSelected,
  });

  final TextEditingController searchController;
  final List<Product> products;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<Product> onProductSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Products',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClearQuery,
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const _NoResultsPlaceholder()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) => _ProductCard(
                    product: products[index],
                    onTap: () => onProductSelected(products[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatPeso(product.price),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResultsPlaceholder extends StatelessWidget {
  const _NoResultsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        'No products match your search.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
