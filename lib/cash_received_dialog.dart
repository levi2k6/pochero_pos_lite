import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';

/// Asks how the order was paid and, for cash, the amount handed over.
///
/// Pops the chosen [PaymentMethod] and the amount paid when confirmed (cash
/// only confirms once it covers [total]; GCash is always the exact total), or
/// `null` when cancelled.
class CashReceivedDialog extends StatefulWidget {
  const CashReceivedDialog({super.key, required this.total});

  final double total;

  @override
  State<CashReceivedDialog> createState() => _CashReceivedDialogState();
}

class _CashReceivedDialogState extends State<CashReceivedDialog> {
  final _controller = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  bool get _isCash => _method == PaymentMethod.cash;

  double get _cashReceived => double.tryParse(_controller.text.trim()) ?? 0;

  double get _amount => _isCash ? _cashReceived : widget.total;

  bool get _canConfirm => _isCash ? _cashReceived >= widget.total : true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = _amount - widget.total;

    return AlertDialog(
      title: const Text('Receive Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PaymentMethod>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: PaymentMethod.cash,
                  label: Text('Cash'),
                  icon: Icon(Icons.payments_outlined),
                ),
                ButtonSegment(
                  value: PaymentMethod.gcash,
                  label: Text('GCash'),
                  icon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ],
              selected: {_method},
              onSelectionChanged: (selection) =>
                  setState(() => _method = selection.first),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: theme.textTheme.bodyMedium),
              Text(
                formatPeso(widget.total),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isCash)
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Cash received',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _confirm(),
            )
          else
            Text(
              'Exact amount via GCash.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Change', style: theme.textTheme.bodyMedium),
              Text(
                _canConfirm ? formatPeso(change) : '—',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _canConfirm
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.of(context).pop((_method, _amount));
  }
}
