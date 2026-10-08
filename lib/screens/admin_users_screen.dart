import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<Map<String, dynamic>>> _users;

  @override
  void initState() {
    super.initState();
    _users = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    final token = context.read<Property24State>().token;
    if (token == null) {
      throw const ApiException('Sign in with a support-admin account.');
    }
    return Property24Api().adminUsers(token);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _users = next);
    await next;
  }

  Future<void> _disableAccount(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable account?'),
        content: Text(
          'This will prevent ${user['name'] ?? user['username']} from signing in. Their records will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      await Property24Api().deactivateAdminUser(
        token: token,
        userId: '${user['id']}',
      );
      await _reload();
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(exception))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('User accounts'),
        actions: [
          IconButton(
            tooltip: 'Refresh users',
            onPressed: _reload,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _users,
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
            final users = snapshot.data!
                .where((item) => item['role'] != 'admin')
                .toList(growable: false);
            if (users.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('No user accounts yet.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = users[index];
                final active = user['active'] == true;
                return Card(
                  color: AppTheme.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: AppTheme.border),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.accent.withValues(alpha: .12),
                      child: Icon(
                        CupertinoIcons.person,
                        color: AppTheme.accent,
                      ),
                    ),
                    title: Text(
                      '${user['name'] ?? user['username'] ?? 'Account'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${user['email'] ?? ''} · ${user['role'] ?? 'tenant'} · ${active ? 'Active' : 'Disabled'}',
                      maxLines: 2,
                    ),
                    trailing: active
                        ? IconButton(
                            tooltip: 'Disable account',
                            icon: Icon(
                              CupertinoIcons.person_crop_circle_badge_xmark,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => _disableAccount(user),
                          )
                        : Icon(
                            CupertinoIcons.lock,
                            color: AppTheme.textMuted,
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
