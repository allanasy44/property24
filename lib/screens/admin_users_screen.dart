import 'dart:async';

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
  Timer? _presenceRefreshTimer;

  @override
  void initState() {
    super.initState();
    _users = _load();
    _presenceRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final next = _load();
      setState(() => _users = next);
    });
  }

  @override
  void dispose() {
    _presenceRefreshTimer?.cancel();
    super.dispose();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
    }
  }

  Future<void> _enableAccount(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable account?'),
        content: Text(
          '${user['name'] ?? user['username']} will be able to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      await Property24Api().setAdminUserActive(
        token: token,
        userId: '${user['id']}',
        active: true,
      );
      await _reload();
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
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
              separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                      child: const Icon(
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
                      '${user['email'] ?? ''} · ${user['role'] ?? 'tenant'} · ${active ? 'Account enabled' : 'Account disabled'}\n${_presenceLabel(user)}',
                      maxLines: 3,
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
                        : IconButton(
                            tooltip: 'Enable account',
                            icon: Icon(
                              CupertinoIcons.lock_open,
                              color: AppTheme.textMuted,
                            ),
                            onPressed: () => _enableAccount(user),
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

  String _presenceLabel(Map<String, dynamic> user) {
    if (user['online'] == true) return 'Online now · live connection';
    final lastSeenValue = user['last_seen_at'];
    if (lastSeenValue == null || '$lastSeenValue'.isEmpty) {
      return 'Never active';
    }
    final lastSeen = DateTime.tryParse('$lastSeenValue')?.toLocal();
    if (lastSeen == null) return 'Last seen time unavailable';
    final now = DateTime.now();
    if (lastSeen.year == now.year &&
        lastSeen.month == now.month &&
        lastSeen.day == now.day) {
      final hour = lastSeen.hour.toString().padLeft(2, '0');
      final minute = lastSeen.minute.toString().padLeft(2, '0');
      return 'Last seen today at $hour:$minute';
    }
    final day = lastSeen.day.toString().padLeft(2, '0');
    final month = lastSeen.month.toString().padLeft(2, '0');
    return 'Last seen $day/$month/${lastSeen.year}';
  }
}
