import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unicons/unicons.dart';

import '../models/rental_models.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/async_value_view.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    return LoadingOverlay(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Text('Account', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Identity, verification, preferences, and role-based access for tenants and landlords.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          const ErrorBanner(),
          if (state.signedIn)
            _SignedInProfile(state: state)
          else
            const _AuthPanel(),
        ],
      ),
    );
  }
}

class _SignedInProfile extends StatelessWidget {
  const _SignedInProfile({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    final user = state.user!;
    final profileImage = state.profileImageUrl.isNotEmpty
        ? state.profileImageUrl
        : user.profilePicture;
    return Column(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                height: 96,
                decoration: BoxDecoration(
                  image: user.coverPhoto.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(user.coverPhoto),
                          fit: BoxFit.cover),
                  gradient: user.coverPhoto.isEmpty
                      ? const LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accentTeal])
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundImage: profileImage.isEmpty
                          ? null
                          : NetworkImage(profileImage),
                      child: profileImage.isEmpty
                          ? Text(user.name.characters.first.toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          Row(
                            children: [
                              Flexible(child: Text('@${state.publicUsername}')),
                              const SizedBox(width: 6),
                              Icon(
                                state.usernameVerified
                                    ? UniconsLine.check_circle
                                    : UniconsLine.clock,
                                size: 16,
                                color: state.usernameVerified
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                              ),
                            ],
                          ),
                          Text(user.email),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(user.role.label)),
                              _StatusChip(label: 'ID', active: user.verified),
                              _StatusChip(
                                  label: 'Email', active: user.emailVerified),
                              _StatusChip(
                                  label: 'Phone', active: user.phoneVerified),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: () => _openProfileEditor(context, state),
                  icon: const Icon(UniconsLine.image_edit),
                  label: const Text('Edit public profile'),
                ),
              ),
            ],
          ),
        ),
        _VerificationPanel(state: state),
        _SettingsPanel(state: state),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.read<Property24State>().signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  void _openProfileEditor(BuildContext context, Property24State state) {
    final username = TextEditingController(text: state.publicUsername);
    final image = TextEditingController(text: state.profileImageUrl);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Public profile',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: username,
              decoration: const InputDecoration(labelText: 'Public username'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: image,
              decoration: const InputDecoration(labelText: 'Profile image URL'),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                state.updatePublicProfile(
                  username: username.text,
                  imageUrl: image.text,
                );
                Navigator.pop(context);
              },
              icon: const Icon(UniconsLine.check),
              label: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationPanel extends StatelessWidget {
  const _VerificationPanel({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verification',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _VerificationRow(
              icon: Icons.badge_outlined,
              title: 'Upload national ID or passport',
              complete: state.user?.verified == true,
            ),
            _VerificationRow(
              icon: Icons.sms_outlined,
              title: 'Verify phone number',
              complete: state.account.phoneVerified,
            ),
            _VerificationRow(
              icon: Icons.alternate_email_outlined,
              title: 'Verify email address',
              complete: state.account.emailVerified,
            ),
            if (state.account.role != AccountRole.tenant)
              const _VerificationRow(
                icon: Icons.real_estate_agent_outlined,
                title: 'Upload ownership or agent authority',
                complete: false,
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openVerification(context),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Start verification'),
            ),
          ],
        ),
      ),
    );
  }

  void _openVerification(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Verification upload',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const TextField(
                decoration:
                    InputDecoration(labelText: 'ID or passport number')),
            const SizedBox(height: 10),
            const TextField(
                decoration: InputDecoration(labelText: 'Phone number for OTP')),
            const SizedBox(height: 10),
            const TextField(
                decoration:
                    InputDecoration(labelText: 'Authority document reference')),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Submit for review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(UniconsLine.setting),
            title: const Text('Capabilities'),
            subtitle: Text(state.account.capabilities.map(titleize).join(', ')),
          ),
          ListTile(
            leading: const Icon(UniconsLine.bell),
            title: const Text('Smart alerts'),
            subtitle: Text(state.smartAlerts.isEmpty
                ? 'No saved alerts yet'
                : state.smartAlerts.join(', ')),
          ),
          ListTile(
            leading: const Icon(UniconsLine.heart),
            title: const Text('Saved homes'),
            subtitle: Text('${state.savedPropertyIds.length} homes saved'),
          ),
          SwitchListTile(
            secondary: const Icon(UniconsLine.moon),
            title: const Text('Dark mode'),
            value: state.darkMode,
            onChanged: state.toggleThemeMode,
          ),
          SwitchListTile(
            secondary: const Icon(UniconsLine.shield),
            title:
                const Text('Protect phone number until trust is established'),
            value: true,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

class _AuthPanel extends StatefulWidget {
  const _AuthPanel();

  @override
  State<_AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<_AuthPanel> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;
  AccountRole _role = AccountRole.tenant;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppTheme.accent, AppTheme.accentTeal]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _register ? 'Create your rental account' : 'Welcome back',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  _register
                      ? 'Choose tenant, landlord, or agent and prepare verification from day one.'
                      : 'Sign in to chat, call, apply, save homes, and manage listings.',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_register) ...[
                    SegmentedButton<AccountRole>(
                      segments: const [
                        ButtonSegment(
                            value: AccountRole.tenant, label: Text('Tenant')),
                        ButtonSegment(
                            value: AccountRole.landlord,
                            label: Text('Landlord')),
                        ButtonSegment(
                            value: AccountRole.agent, label: Text('Agent')),
                      ],
                      selected: {_role},
                      onSelectionChanged: (value) =>
                          setState(() => _role = value.first),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextFormField(
                    controller: _email,
                    decoration:
                        const InputDecoration(labelText: 'Email or username'),
                    keyboardType: TextInputType.emailAddress,
                    validator: _required,
                  ),
                  const SizedBox(height: 10),
                  if (_register) ...[
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                          labelText: 'Phone number for OTP'),
                      keyboardType: TextInputType.phone,
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                    obscureText: _obscure,
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _submit,
                          icon: Icon(_register
                              ? Icons.person_add_alt_1_outlined
                              : Icons.login),
                          label: Text(_register ? 'Create account' : 'Sign in'),
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _register = !_register),
                      child: Text(_register
                          ? 'I already have an account'
                          : 'Create tenant or landlord account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<Property24State>();
    try {
      if (_register) {
        await state.register(
          role: _role,
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await state.signIn(_email.text.trim(), _password.text);
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar:
          Icon(active ? Icons.check_circle : Icons.pending_outlined, size: 16),
      label: Text(active ? '$label verified' : '$label pending'),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({
    required this.icon,
    required this.title,
    required this.complete,
  });

  final IconData icon;
  final String title;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: Icon(
        complete ? Icons.check_circle : Icons.radio_button_unchecked,
        color: complete
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
