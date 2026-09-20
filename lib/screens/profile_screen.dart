import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final user = state.user;

    final name = user?.name.trim().isNotEmpty == true
        ? user!.name
        : 'Property24 member';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final hasImage = user?.profilePicture.isNotEmpty == true;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            // ─── Back arrow + "Profile" title ───
            Row(
              children: [
                _CircleIconButton(
                  icon: CupertinoIcons.back,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 28),

            // ─── Avatar + edit badge ───
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.bgCard,
                      border: Border.all(color: AppTheme.border, width: 2),
                      image: hasImage
                          ? DecorationImage(
                              image: NetworkImage(user!.profilePicture),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !hasImage
                        ? Center(
                            child: Text(
                              initials.isEmpty ? 'P' : initials,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: user == null
                          ? null
                          : () => _openProfileEditor(context, user),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.bg, width: 3),
                        ),
                        child: const Icon(
                          CupertinoIcons.pencil,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ─── Name ───
            Center(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ─── Email ───
            Center(
              child: Text(
                user?.email.isNotEmpty == true
                    ? user!.email
                    : 'Not signed in',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ─── Menu cards ───
            _MenuCardTile(
              icon: CupertinoIcons.cart,
              label: 'My Purchases',
              badge: 1,
              onTap: () {},
            ),
            _MenuCardTile(
              icon: CupertinoIcons.person,
              label: 'Profile Edit',
              onTap: user == null
                  ? null
                  : () => _openProfileEditor(context, user),
            ),
            _MenuCardTile(
              icon: CupertinoIcons.gear,
              label: 'Setting',
              onTap: () => _openSettings(context),
            ),
            _MenuCardTile(
              icon: CupertinoIcons.briefcase,
              label: 'My Wallet',
              onTap: () {},
            ),
            _MenuCardTile(
              icon: CupertinoIcons.person_2,
              label: 'Help Center',
              onTap: () => _openHelp(context),
            ),
            _MenuCardTile(
              icon: CupertinoIcons.checkmark_shield,
              label: 'Verification',
              subtitle: _verificationSummary(user),
              onTap: () => _openVerification(context, user),
              showBottomSpacing: false,
            ),

            const SizedBox(height: 24),

            // ─── Sign out ───
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: BorderSide(color: AppTheme.accent, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: user == null
                  ? null
                  : () => context.read<Property24State>().signOut(),
              icon: const Icon(CupertinoIcons.square_arrow_right, size: 18),
              label: const Text(
                'Sign out',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _verificationSummary(AccountUser? user) {
    if (user == null) return 'Sign in to verify your account';
    if (user.phoneVerified && user.emailVerified) {
      return 'Email and phone verified';
    }
    if (user.phoneVerified) return 'Phone verified';
    if (user.emailVerified) return 'Email verified; phone pending';
    return 'Email and phone verification pending';
  }

  void _openProfileEditor(BuildContext context, AccountUser user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProfileEditor(user: user),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SettingsSheet(),
    );
  }

  void _openHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _HelpCenterSheet(),
    );
  }

  void _openVerification(BuildContext context, AccountUser? user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _VerificationSheet(user: user),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  Menu card tile (using AppTheme colors)
// ═════════════════════════════════════════════════════════════
class _MenuCardTile extends StatelessWidget {
  const _MenuCardTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.showBottomSpacing = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final int? badge;
  final bool showBottomSpacing;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: EdgeInsets.only(bottom: showBottomSpacing ? 12 : 0),
      child: Material(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: enabled ? AppTheme.accent : AppTheme.textMuted,
                      ),
                    ),
                    if (badge != null && badge! > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.bgCard, width: 2),
                          ),
                          child: Text(
                            '$badge',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Circular outlined back button
// ─────────────────────────────────────────────────────────────
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border, width: 1.2),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 18),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  SETTINGS SHEET (image layout, AppTheme colors, real-time)
// ═════════════════════════════════════════════════════════════
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _pushEnabled = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Setting',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const _SectionLabel('Account Settings'),
            const SizedBox(height: 10),
            _MenuCard(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.person,
                  label: 'Account Information',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: CupertinoIcons.creditcard,
                  label: 'Payment Method',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: CupertinoIcons.link,
                  label: 'Link Account',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: CupertinoIcons.shield_lefthalf_fill,
                  label: 'Privacy Policy',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: CupertinoIcons.doc_text,
                  label: 'My Bookings',
                  onTap: () {},
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 26),

            const _SectionLabel('App Settings'),
            const SizedBox(height: 10),
            _MenuCard(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.globe,
                  label: 'Language',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: CupertinoIcons.bell,
                  label: 'Push Notification',
                  trailing: _ThemedSwitch(
                    value: _pushEnabled,
                    onChanged: (v) => setState(() => _pushEnabled = v),
                  ),
                  onTap: () => setState(() => _pushEnabled = !_pushEnabled),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.moon,
                  label: 'Dark Mode',
                  trailing: _ThemedSwitch(
                    value: state.darkMode,
                    onChanged: state.toggleThemeMode,
                  ),
                  onTap: () => state.toggleThemeMode(!state.darkMode),
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                trailing ??
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 70, right: 14),
            child: Divider(
              height: 1,
              thickness: 0.6,
              color: AppTheme.border,
            ),
          ),
      ],
    );
  }
}

class _ThemedSwitch extends StatelessWidget {
  const _ThemedSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.85,
      child: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.accent,
        trackColor: AppTheme.bgSurface,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  PROFILE EDITOR (real-time, themed)
// ═════════════════════════════════════════════════════════════
class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.user});
  final AccountUser user;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _phone;
  late final TextEditingController _imageUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _username = TextEditingController(text: widget.user.username);
    _bio = TextEditingController(text: widget.user.bio);
    _phone = TextEditingController(text: widget.user.phone);
    _imageUrl = TextEditingController(text: widget.user.profilePicture);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _phone.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _ThemedField(controller: _name, label: 'Full name'),
          const SizedBox(height: 12),
          _ThemedField(controller: _username, label: 'Username'),
          const SizedBox(height: 12),
          _ThemedField(
            controller: _phone,
            label: 'Zimbabwe phone number',
            hint: '+263771234567',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _ThemedField(
            controller: _imageUrl,
            label: 'Profile image URL',
            hint: 'https://...',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          _ThemedField(controller: _bio, label: 'Bio', maxLines: 3),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<Property24State>().updateProfile(
            username: _username.text.trim(),
            name: _name.text.trim(),
            bio: _bio.text.trim(),
            phone: _phone.text.trim(),
            profilePictureUrl: _imageUrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ThemedField extends StatelessWidget {
  const _ThemedField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppTheme.textMuted),
        hintStyle: TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accent, width: 1.2),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  HELP CENTER
// ═════════════════════════════════════════════════════════════
class _HelpCenterSheet extends StatelessWidget {
  const _HelpCenterSheet();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help center',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Need help with your account, verification, or a property? Contact the Property24 support team from your registered email address.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            SelectableText(
              'support@property24.co.zw',
              style: TextStyle(color: AppTheme.accent),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  VERIFICATION (real-time)
// ═════════════════════════════════════════════════════════════
class _VerificationSheet extends StatefulWidget {
  const _VerificationSheet({required this.user});
  final AccountUser? user;

  @override
  State<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<_VerificationSheet> {
  final _code = TextEditingController();
  String? _challengeId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Sign in to verify your account.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _VerificationRow(
            label: 'Email',
            value: user.email,
            verified: user.emailVerified,
          ),
          _VerificationRow(
            label: 'Zimbabwe phone',
            value: user.phone,
            verified: user.phoneVerified,
          ),
          if (!user.phoneVerified) ...[
            const SizedBox(height: 10),
            if (_challengeId == null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _busy ? null : _sendCode,
                  icon: const Icon(CupertinoIcons.paperplane),
                  label: const Text('Send phone code'),
                ),
              )
            else ...[
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: '6-digit code',
                  labelStyle: TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _busy ? null : _verifyCode,
                  child: const Text('Verify phone'),
                ),
              ),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: AppTheme.accent)),
          ],
        ],
      ),
    );
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _challengeId =
          await context.read<Property24State>().requestPhoneVerification();
      if (mounted) setState(() {});
    } catch (exception) {
      if (mounted) setState(() => _error = userFacingError(exception));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _code.text.trim();
    if (_challengeId == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Property24State>().verifyPhone(_challengeId!, code);
      if (mounted) setState(() => _challengeId = null);
    } catch (exception) {
      if (mounted) setState(() => _error = userFacingError(exception));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({
    required this.label,
    required this.value,
    required this.verified,
  });
  final String label;
  final String value;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        verified
            ? CupertinoIcons.checkmark_circle_fill
            : CupertinoIcons.clock,
        color: verified ? AppTheme.accent : AppTheme.textMuted,
      ),
      title: Text(label, style: TextStyle(color: AppTheme.textPrimary)),
      subtitle: Text(
        value.isEmpty ? 'Not provided' : value,
        style: TextStyle(color: AppTheme.textMuted),
      ),
      trailing: Text(
        verified ? 'Verified' : 'Pending',
        style: TextStyle(
          color: verified ? AppTheme.accent : AppTheme.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}