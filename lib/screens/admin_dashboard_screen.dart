import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'admin_users_screen.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/metric_tile.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, dynamic>> _summary;

  @override
  void initState() {
    super.initState();
    _summary = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final token = context.read<Property24State>().token;
    if (token == null) {
      throw const ApiException('Sign in with a support-admin account.');
    }
    return Property24Api().adminDashboard(token);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _summary = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Support dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _refresh,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    userFacingError(snapshot.error!),
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              );
            }
            final data = snapshot.data!;
            final users = data['users'] as Map<String, dynamic>? ?? {};
            final listings = data['listings'] as Map<String, dynamic>? ?? {};
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Platform overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Account, listing and support activity at a glance.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount:
                      MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.28,
                  children: [
                    MetricTile(
                      icon: CupertinoIcons.person_2,
                      label: 'Users',
                      value: '${users['total'] ?? 0}',
                    ),
                    MetricTile(
                      icon: CupertinoIcons.building_2_fill,
                      label: 'Listings',
                      value: '${listings['total'] ?? 0}',
                    ),
                    MetricTile(
                      icon: CupertinoIcons.doc_text,
                      label: 'Applications',
                      value: '${data['applications'] ?? 0}',
                    ),
                    MetricTile(
                      icon: CupertinoIcons.checkmark_seal,
                      label: 'Verifications pending',
                      value: '${data['pending_verifications'] ?? 0}',
                    ),
                    MetricTile(
                      icon: CupertinoIcons.flag,
                      label: 'Open reports',
                      value: '${data['open_reports'] ?? 0}',
                    ),
                    MetricTile(
                      icon: CupertinoIcons.calendar,
                      label: 'Viewings',
                      value: '${data['viewings'] ?? 0}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminUsersScreen(),
                    ),
                  ),
                  icon: const Icon(CupertinoIcons.person_2),
                  label: const Text('Manage user accounts'),
                ),
                const SizedBox(height: 12),
                _InsightCard(
                  title: 'Accounts',
                  icon: CupertinoIcons.person_2,
                  rows: [
                    ('Active', '${users['active'] ?? 0}'),
                    ('Tenants', '${users['tenants'] ?? 0}'),
                    ('Landlords', '${users['landlords'] ?? 0}'),
                    ('Agents', '${users['agents'] ?? 0}'),
                    ('Joined this month', '${data['users_created_this_month'] ?? 0}'),
                  ],
                ),
                const SizedBox(height: 12),
                _InsightCard(
                  title: 'Listings',
                  icon: CupertinoIcons.house,
                  rows: [
                    ('Active', '${listings['active'] ?? 0}'),
                    ('Verified', '${listings['verified'] ?? 0}'),
                    (
                      'Added this month',
                      '${listings['created_this_month'] ?? 0}',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
