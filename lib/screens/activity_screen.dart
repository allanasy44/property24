import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/property24_state.dart';
import '../widgets/async_value_view.dart';
import '../widgets/metric_tile.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    return LoadingOverlay(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Text(
              'Activity',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                MetricTile(
                  icon: Icons.verified_outlined,
                  label: 'Verified listings',
                  value: '${state.verifiedProperties}',
                ),
                MetricTile(
                  icon: Icons.home_work_outlined,
                  label: 'All listings',
                  value: '${state.snapshot.properties.length}',
                ),
                MetricTile(
                  icon: Icons.assignment_outlined,
                  label: 'Applications',
                  value: '${state.snapshot.applications.length}',
                ),
                MetricTile(
                  icon: Icons.build_outlined,
                  label: 'Open maintenance',
                  value: '${state.openMaintenance}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const ErrorBanner(),
            _Section(
              title: 'Applications',
              empty: 'No applications yet.',
              children: [
                for (final item in state.snapshot.applications)
                  ListTile(
                    leading: const Icon(Icons.assignment_turned_in_outlined),
                    title: Text(item.property),
                    subtitle: Text(
                        '${item.applicant} · score ${item.score} · ${item.createdAt}'),
                    trailing: Text(item.status),
                  ),
              ],
            ),
            _Section(
              title: 'Payments',
              empty: 'No payments recorded.',
              children: [
                for (final item in state.snapshot.payments)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(item.amount),
                    subtitle: Text(
                        '${item.property} · ${item.method} · ${item.paidAt}'),
                    trailing: Text(item.status),
                  ),
              ],
            ),
            _Section(
              title: 'Leases',
              empty: 'No leases generated.',
              children: [
                for (final item in state.snapshot.leases)
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(item.property),
                    subtitle: Text('${item.tenant} · ${item.monthlyRent}'),
                    trailing: Text(item.status),
                  ),
              ],
            ),
            _Section(
              title: 'Maintenance',
              empty: 'No maintenance requests.',
              children: [
                for (final item in state.snapshot.maintenance)
                  ListTile(
                    leading: const Icon(Icons.handyman_outlined),
                    title: Text(item.issue),
                    subtitle: Text(
                        '${item.property} · ${item.category} · ${item.updatedAt}'),
                    trailing: Text(item.priority),
                  ),
              ],
            ),
            if (state.snapshot.verifications.isNotEmpty)
              _Section(
                title: 'Verification queue',
                empty: '',
                children: [
                  for (final item in state.snapshot.verifications)
                    ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: Text(item.name),
                      subtitle:
                          Text('${item.role} · ${item.checks.join(', ')}'),
                      trailing: Text(item.status),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(empty),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}
