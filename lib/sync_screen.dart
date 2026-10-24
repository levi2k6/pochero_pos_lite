import 'package:flutter/material.dart';

import 'payments_store.dart';

/// Manual sync screen: nothing leaves the device until the cashier presses
/// "Sync now". Shows a large spinner while syncing and a message afterwards.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key, required this.store});

  final PaymentsStore store;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _syncing = false;
  bool _failed = false;
  int _syncingCount = 0;
  String? _message;

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _failed = false;
      _syncingCount = widget.store.pendingSync.length;
      _message = null;
    });

    final result = await widget.store.syncPending();
    if (!mounted) return;

    setState(() {
      _syncing = false;
      _failed = result.failed;
      if (result.failed) {
        _message = 'Sync failed: ${result.error}';
      } else if (result.upToDate) {
        _message = 'Everything is up to date.';
      } else {
        final noun = result.synced == 1 ? 'payment' : 'payments';
        _message = 'Synced ${result.synced} $noun.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Sync'),
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final pending = _syncing
              ? _syncingCount
              : widget.store.pendingSync.length;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: _syncing
                        ? const CircularProgressIndicator(strokeWidth: 8)
                        : Icon(
                            Icons.cloud_sync_outlined,
                            size: 96,
                            color: theme.colorScheme.primary,
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _syncing ? 'Syncing...' : 'Ready to sync',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _syncing
                        ? 'Sending $pending ${pending == 1 ? 'payment' : 'payments'} to the backend...'
                        : 'You have $pending pending ${pending == 1 ? 'payment' : 'payments'}.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _failed
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _syncing ? null : _sync,
                    icon: const Icon(Icons.sync),
                    label: Text(_syncing ? 'Syncing...' : 'Sync now'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
