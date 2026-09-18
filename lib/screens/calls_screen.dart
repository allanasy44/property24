import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unicons/unicons.dart';

import '../state/property24_state.dart';
import '../widgets/async_value_view.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    return LoadingOverlay(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Row(
            children: [
              _NotificationButton(state: state),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Calls',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Voice and video call history for tenants, landlords, and agents.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showCallSheet(context, CallMode.voice),
                      icon: const Icon(UniconsLine.phone),
                      label: const Text('Voice call'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCallSheet(context, CallMode.video),
                      icon: const Icon(UniconsLine.video),
                      label: const Text('Video call'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in state.callHistory)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(
                  item.mode == CallMode.video
                      ? UniconsLine.video
                      : UniconsLine.phone,
                ),
                title: Text(item.name),
                subtitle: Text('${item.property} · ${item.direction}'),
                trailing: Text(
                  item.when,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCallSheet(BuildContext context, CallMode mode) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mode == CallMode.video ? 'Start video call' : 'Start voice call',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text(
              'Open a property contact card to connect this call to the right listing, landlord, or tenant.',
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Notifications',
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final notification in state.notifications)
                  ListTile(
                    leading: const Icon(UniconsLine.bell),
                    title: Text(notification),
                  ),
              ],
            ),
          ),
        );
      },
      icon: Badge(
        label: Text('${state.notifications.length}'),
        child: const Icon(UniconsLine.bell),
      ),
    );
  }
}
