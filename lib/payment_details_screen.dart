import 'package:flutter/material.dart';

import 'models.dart';
import 'payments_store.dart';

/// Full-screen view of one recorded payment: info box on top, items table
/// below.
class PaymentDetailsScreen extends StatelessWidget {
  const PaymentDetailsScreen({
    super.key,
    required this.payment,
    required this.store,
  });

  final Payment payment;
  final PaymentsStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Payment Details'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _InfoBox(payment: payment),
          if (payment.items.isNotEmpty) ...[
            const _ItemsTableHeader(),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: payment.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _ItemRow(item: payment.items[index]),
              ),
            ),
          ] else
            const Expanded(child: _NoItemsPlaceholder()),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete payment?'),
        content: const Text(
          "Are you sure you want to delete this payment? This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await store.remove(payment);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
}

class _NoItemsPlaceholder extends StatelessWidget {
  const _NoItemsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        'No items recorded for this payment.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = payment.items.fold(0, (sum, line) => sum + line.quantity);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoRow(
                label: 'Paid at',
                value: formatDateTime(payment.updatedAt),
              ),
              const SizedBox(height: 8),
              _InfoRow(label: 'Type', value: payment.type.label),
              const SizedBox(height: 8),
              _InfoRow(label: 'Method', value: payment.method.label),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Amount paid',
                value: formatPeso(payment.amount),
              ),
              const SizedBox(height: 8),
              _InfoRow(label: 'Change', value: formatPeso(payment.change)),
              const SizedBox(height: 8),
              _InfoRow(label: 'Items', value: '$itemCount'),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Sync',
                value: payment.dirty ? 'Unsynced' : 'Synced',
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    formatPeso(payment.total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemsTableHeader extends StatelessWidget {
  const _ItemsTableHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.bold,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text('Item', style: style)),
          SizedBox(
            width: 48,
            child: Text('Qty', textAlign: TextAlign.center, style: style),
          ),
          SizedBox(
            width: 96,
            child: Text('Unit Price', textAlign: TextAlign.right, style: style),
          ),
          SizedBox(
            width: 96,
            child: Text('Amount', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final CartLine item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.product.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              formatPeso(item.product.price),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              formatPeso(item.lineTotal),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
