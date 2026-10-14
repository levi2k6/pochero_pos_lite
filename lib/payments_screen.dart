import 'package:flutter/material.dart';

import 'models.dart';
import 'payment_details_screen.dart';
import 'payments_store.dart';

/// Which payments the list shows.
enum _PaymentFilter { today, all }

/// The recorded payments, newest last. Defaults to showing today's payments.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, required this.store});

  final PaymentsStore store;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  _PaymentFilter _filter = _PaymentFilter.today;

  List<Payment> _filtered(List<Payment> payments) {
    if (_filter == _PaymentFilter.all) return payments;
    final now = DateTime.now();
    return payments
        .where(
          (payment) =>
              payment.updatedAt.year == now.year &&
              payment.updatedAt.month == now.month &&
              payment.updatedAt.day == now.day,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          if (widget.store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = widget.store.payments;
          if (all.isEmpty) {
            return const Center(child: Text('No payments yet.'));
          }

          final payments = _filtered(all);
          final total = payments.fold<double>(
            0,
            (sum, payment) => sum + payment.amount,
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_PaymentFilter>(
                    segments: const [
                      ButtonSegment(
                        value: _PaymentFilter.today,
                        label: Text('Today'),
                        icon: Icon(Icons.today_outlined),
                      ),
                      ButtonSegment(
                        value: _PaymentFilter.all,
                        label: Text('All'),
                        icon: Icon(Icons.all_inclusive),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (selection) =>
                        setState(() => _filter = selection.first),
                  ),
                ),
              ),
              Expanded(
                child: payments.isEmpty
                    ? const Center(child: Text('No payments today.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: payments.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) => _PaymentTile(
                          payment: payments[index],
                          store: widget.store,
                        ),
                      ),
              ),
              _PaymentTotalBar(count: payments.length, total: total),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentTotalBar extends StatelessWidget {
  const _PaymentTotalBar({required this.count, required this.total});

  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                'Total ($count)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                formatPeso(total),
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

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.store});

  final Payment payment;
  final PaymentsStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortId = payment.id.substring(0, 8);

    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentDetailsScreen(payment: payment, store: store),
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.payments_outlined,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        formatDateTime(payment.updatedAt),
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${payment.type.label} • ${payment.method.label} • #$shortId',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatPeso(payment.amount),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Change ${formatPeso(payment.change)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
