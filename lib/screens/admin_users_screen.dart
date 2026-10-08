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
  List<Map<String, dynamic>> _knownUsers = [];

  @override
  void initState() {
    super.initState();
    _users = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final token = context.read<Property24State>().token;
    if (token == null) {
      throw const ApiException('Sign in with a support-admin account.');
    }
    _knownUsers = await Property24Api().adminUsers(token);
    return _knownUsers;
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _users = next);
    await next;
  }

  Future<void> _edit([Map<String, dynamic>? user]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AdminUserDialog(
        user: user,
        landlords: _knownUsers
            .where(
                (item) => item['role'] == 'landlord' && item['active'] == true)
            .toList(growable: false),
      ),
    );
    if (result == null || !mounted) return;
    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      final api = Property24Api();
      if (user == null) {
        await api.createAdminUser(token: token, data: result);
      } else {
        await api.updateAdminUser(
          token: token,
          userId: '${user['id']}',
          data: result,
        );
      }
      await _reload();
    } catch (exception) {
      _showError(exception);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final isActive = user['active'] == true;
    if (isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deactivate account?'),
          content: Text(
            'This prevents ${user['name'] ?? user['username']} from signing in. Their records will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final token = context.read<Property24State>().token;
    if (token == null) return;
    try {
      if (isActive) {
        await Property24Api().deactivateAdminUser(
          token: token,
          userId: '${user['id']}',
        );
      } else {
        await Property24Api().updateAdminUser(
          token: token,
          userId: '${user['id']}',
          data: const {'is_active': true},
        );
      }
      await _reload();
    } catch (exception) {
      _showError(exception);
    }
  }

  void _showError(Object exception) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userFacingError(exception))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('User accounts'),
        actions: [
          IconButton(
            tooltip: 'Add account',
            onPressed: () => _edit(),
            icon: const Icon(CupertinoIcons.person_add),
          ),
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
                      '${user['email'] ?? ''} · ${user['role'] ?? 'tenant'} · ${active ? 'Active' : 'Deactivated'}',
                      maxLines: 2,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') _edit(user);
                        if (action == 'active') _toggleActive(user);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit account'),
                        ),
                        PopupMenuItem(
                          value: 'active',
                          child: Text(active ? 'Deactivate' : 'Reactivate'),
                        ),
                      ],
                    ),
                    onTap: () => _edit(user),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        child: const Icon(CupertinoIcons.person_add),
      ),
    );
  }
}

class _AdminUserDialog extends StatefulWidget {
  const _AdminUserDialog({this.user, required this.landlords});

  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> landlords;

  @override
  State<_AdminUserDialog> createState() => _AdminUserDialogState();
}

class _AdminUserDialogState extends State<_AdminUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  final _password = TextEditingController();
  late String _role;
  String? _parentLandlordId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${widget.user?['name'] ?? ''}');
    _email = TextEditingController(text: '${widget.user?['email'] ?? ''}');
    _phone = TextEditingController(text: '${widget.user?['phone'] ?? ''}');
    _role = '${widget.user?['role'] ?? 'tenant'}';
    final parentId = widget.user?['parent_landlord_id'];
    _parentLandlordId = parentId == null ? null : '$parentId';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'role': _role,
      if (widget.user == null) 'username': _email.text.trim(),
      if (widget.user == null) 'password': _password.text,
      if (_role == 'agent') 'parent_landlord_id': _parentLandlordId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.user == null;
    return AlertDialog(
      title: Text(creating ? 'Create account' : 'Edit account'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a name'
                      : null,
                ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value == null ||
                          !value.contains('@') ||
                          !value.contains('.')
                      ? 'Enter a valid email'
                      : null,
                ),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'Account type'),
                  items: const [
                    DropdownMenuItem(value: 'tenant', child: Text('Tenant')),
                    DropdownMenuItem(
                      value: 'landlord',
                      child: Text('Landlord'),
                    ),
                    DropdownMenuItem(value: 'agent', child: Text('Agent')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
                if (_role == 'agent')
                  DropdownButtonFormField<String>(
                    value: widget.landlords.any(
                      (item) => '${item['id']}' == _parentLandlordId,
                    )
                        ? _parentLandlordId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Landlord',
                    ),
                    items: [
                      for (final landlord in widget.landlords)
                        DropdownMenuItem(
                          value: '${landlord['id']}',
                          child: Text(
                            '${landlord['name'] ?? landlord['username']}',
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _parentLandlordId = value),
                    validator: (value) =>
                        value == null ? 'Assign the agent to a landlord' : null,
                  ),
                if (creating)
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                    ),
                    validator: (value) => (value ?? '').length < 15
                        ? 'Use at least 15 characters'
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
