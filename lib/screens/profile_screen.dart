import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class _ProfileInitials extends StatelessWidget {
  const _ProfileInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials.isEmpty ? 'P' : initials,
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<Property24State>().refresh();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) context.read<Property24State>().refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final user = state.user;
    final bookingCount = _availableBookings(state).length;

    final name =
        user?.name.trim().isNotEmpty == true ? user!.name : 'Property24 member';
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
            // ─── Profile title ───
            Center(
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
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasImage
                        ? Image.network(
                            user!.profilePicture,
                            key: ValueKey(user.profilePicture),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ProfileInitials(
                              initials: initials,
                            ),
                          )
                        : _ProfileInitials(initials: initials),
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
                user?.email.isNotEmpty == true ? user!.email : 'Not signed in',
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
              icon: CupertinoIcons.person,
              label: 'Profile Edit',
              onTap:
                  user == null ? null : () => _openProfileEditor(context, user),
            ),
            _MenuCardTile(
              icon: CupertinoIcons.gear,
              label: 'Setting',
              onTap: () => _openSettings(context),
            ),
            _MenuCardTile(
              icon: CupertinoIcons.calendar,
              label: 'Available Bookings',
              subtitle: bookingCount == 0
                  ? 'No pending or reserved bookings'
                  : '$bookingCount pending or reserved',
              badge: bookingCount,
              onTap: () => _openBookings(context),
            ),
            _MenuCardTile(
              icon: CupertinoIcons.checkmark_shield,
              label: 'Verification',
              subtitle: _verificationSummary(user),
              onTap: () => _openVerification(context, user),
            ),
            _MenuCardTile(
              icon: CupertinoIcons.person_2,
              label: 'Help Center',
              onTap: () => _openHelp(context),
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

  List<ViewingItem> _availableBookings(Property24State state) {
    return state.snapshot.viewings
        .where((item) => item.isAvailableBooking)
        .toList(growable: false);
  }

  String _verificationSummary(AccountUser? user) {
    if (user == null) return 'Sign in to verify your account';
    if (user.verified) return 'Identity verification complete';
    if (user.phoneVerified) return 'Phone verified';
    return 'Phone and identity verification pending';
  }

  void _openProfileEditor(BuildContext context, AccountUser user) {
    _openSidePanel<void>(
      context: context,
      child: _ProfileEditor(user: user),
    );
  }

  void _openSettings(BuildContext context) {
    _openSidePanel<void>(
      context: context,
      child: const _SettingsSheet(),
    );
  }

  void _openHelp(BuildContext context) {
    _openSidePanel<void>(
      context: context,
      child: const _HelpCenterSheet(),
    );
  }

  void _openVerification(BuildContext context, AccountUser? user) {
    _openSidePanel<void>(
      context: context,
      child: _VerificationSheet(user: user),
    );
  }

  void _openBookings(BuildContext context) {
    _openSidePanel<void>(
      context: context,
      child: _BookingsPanel(bookingsBuilder: _availableBookings),
    );
  }
}

Future<T?> _openSidePanel<T>({
  required BuildContext context,
  required Widget child,
}) {
  final width = MediaQuery.sizeOf(context).width;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withOpacity(0.28),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: SafeArea(
          left: false,
          child: Material(
            color: AppTheme.bgCard,
            elevation: 12,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(24),
            ),
            child: SizedBox(
              width: width < 560 ? width * 0.92 : 440,
              height: double.infinity,
              child: child,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
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
                            border:
                                Border.all(color: AppTheme.bgCard, width: 2),
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelHeader(
                title: 'Settings',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              _SyncSummary(state: state),
              const SizedBox(height: 20),
              const _SectionLabel('Account'),
              const SizedBox(height: 10),
              _MenuCard(
                children: [
                  _SettingsTile(
                    icon: CupertinoIcons.person,
                    label: 'Account Information',
                    onTap: () => _openNestedPanel(
                      context,
                      _InfoPanel(
                        title: 'Account',
                        rows: [
                          _InfoRowData(
                              'Name', state.user?.name ?? 'Not signed in'),
                          _InfoRowData('Role', state.account.role.label),
                          _InfoRowData(
                              'Phone', state.user?.phone ?? 'Not provided'),
                          _InfoRowData(
                            'Profile',
                            state.user?.verified == true
                                ? 'Identity verified'
                                : 'Verification pending',
                          ),
                        ],
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.shield_lefthalf_fill,
                    label: 'Privacy Policy',
                    onTap: () => _openNestedPanel(
                      context,
                      const _TextInfoPanel(
                        title: 'Privacy',
                        body:
                            'Property24 stores profile media, verification files, bookings, conversations, leases, and application activity on the backend. Identity documents are processed for verification and retained only for the configured review window.',
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.doc_text,
                    label: 'My Bookings',
                    trailing: _CountBadge(
                      count: state.snapshot.viewings
                          .where((item) => item.isAvailableBooking)
                          .length,
                    ),
                    onTap: () => _openNestedPanel(
                      context,
                      _BookingsPanel(
                        bookingsBuilder: (state) => state.snapshot.viewings
                            .where((item) => item.isAvailableBooking)
                            .toList(growable: false),
                      ),
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const _SectionLabel('App'),
              const SizedBox(height: 10),
              _MenuCard(
                children: [
                  _SettingsTile(
                    icon: CupertinoIcons.globe,
                    label: 'Language',
                    trailing: Text(
                      'English',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    onTap: () => _openNestedPanel(
                      context,
                      const _TextInfoPanel(
                        title: 'Language',
                        body:
                            'The current app language is English. This is synced with the local app profile while backend account data remains unchanged.',
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: CupertinoIcons.bell,
                    label: 'Push Notification',
                    trailing: _ThemedSwitch(
                      value: _pushEnabled,
                      onChanged: (value) {
                        setState(() => _pushEnabled = value);
                        context.read<Property24State>().addNotification(
                              value
                                  ? 'Push notifications enabled for bookings, chats, and verification updates.'
                                  : 'Push notifications paused on this device.',
                            );
                      },
                    ),
                    onTap: () {
                      final next = !_pushEnabled;
                      setState(() => _pushEnabled = next);
                      context.read<Property24State>().addNotification(
                            next
                                ? 'Push notifications enabled for bookings, chats, and verification updates.'
                                : 'Push notifications paused on this device.',
                          );
                    },
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
      ),
    );
  }

  void _openNestedPanel(BuildContext context, Widget child) {
    _openSidePanel<void>(context: context, child: child);
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.onClose});
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(CupertinoIcons.xmark),
        ),
      ],
    );
  }
}

class _SyncSummary extends StatelessWidget {
  const _SyncSummary({required this.state});
  final Property24State state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Synced with backend',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${state.snapshot.conversations.length} chats · '
            '${state.snapshot.viewings.length} bookings · '
            '${state.snapshot.verifications.length} verifications',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.accent,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData(this.label, this.value);
  final String label;
  final String value;
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.rows});
  final String title;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(title: title, onClose: () => Navigator.pop(context)),
            const SizedBox(height: 12),
            _MenuCard(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _InfoRow(
                    label: rows[i].label,
                    value: rows[i].value,
                    showDivider: i != rows.length - 1,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.showDivider,
  });
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(color: AppTheme.textMuted)),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: AppTheme.border, indent: 14, endIndent: 14),
      ],
    );
  }
}

class _TextInfoPanel extends StatelessWidget {
  const _TextInfoPanel({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(title: title, onClose: () => Navigator.pop(context)),
            const SizedBox(height: 12),
            Text(
              body,
              style: TextStyle(
                color: AppTheme.textMuted,
                height: 1.45,
              ),
            ),
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
  final _picker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _removeImage = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _username = TextEditingController(text: widget.user.username);
    _bio = TextEditingController(text: widget.user.bio);
    _phone = TextEditingController(text: widget.user.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelHeader(
                title: 'Edit profile',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              _ProfileImagePicker(
                currentImageUrl: widget.user.profilePicture,
                selectedImageBytes: _selectedImageBytes,
                removeImage: _removeImage,
                onPick: _pickImage,
                onRemove: widget.user.profilePicture.isEmpty &&
                        _selectedImageBytes == null
                    ? null
                    : () => setState(() {
                          _selectedImage = null;
                          _selectedImageBytes = null;
                          _removeImage = true;
                        }),
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
              _ThemedField(controller: _bio, label: 'Bio', maxLines: 3),
              const SizedBox(height: 18),
              if (_saveError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withAlpha(70)),
                  ),
                  child: Text(
                    _saveError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
      _removeImage = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await context.read<Property24State>().updateProfile(
            username: _username.text.trim(),
            name: _name.text.trim(),
            bio: _bio.text.trim(),
            phone: _phone.text.trim(),
            profilePictureBytes: _selectedImageBytes,
            profilePictureName: _selectedImage?.name,
            profilePictureMimeType: _selectedImage?.mimeType,
            removeProfilePicture: _removeImage,
          );
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) {
        setState(() {
          _saveError = exception is ApiException
              ? exception.message
              : 'Profile could not be saved. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProfileImagePicker extends StatelessWidget {
  const _ProfileImagePicker({
    required this.currentImageUrl,
    required this.selectedImageBytes,
    required this.removeImage,
    required this.onPick,
    required this.onRemove,
  });

  final String currentImageUrl;
  final Uint8List? selectedImageBytes;
  final bool removeImage;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasCurrentImage = currentImageUrl.isNotEmpty && !removeImage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 72,
              height: 72,
              child: selectedImageBytes != null
                  ? Image.memory(selectedImageBytes!, fit: BoxFit.cover)
                  : hasCurrentImage
                      ? Image.network(currentImageUrl, fit: BoxFit.cover)
                      : ColoredBox(
                          color: AppTheme.bgCard,
                          child: Icon(
                            CupertinoIcons.person_crop_circle,
                            color: AppTheme.textMuted,
                            size: 34,
                          ),
                        ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile photo',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'JPEG, PNG, or WEBP uploaded to your backend profile.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onPick,
                      icon: const Icon(CupertinoIcons.photo, size: 16),
                      label: const Text('Upload'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(color: AppTheme.border),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onRemove,
                      icon: const Icon(CupertinoIcons.trash, size: 16),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class _BookingsPanel extends StatelessWidget {
  const _BookingsPanel({required this.bookingsBuilder});
  final List<ViewingItem> Function(Property24State state) bookingsBuilder;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final bookings = bookingsBuilder(state);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(
              title: 'Bookings',
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => context.read<Property24State>().refresh(),
                child: bookings.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          Icon(
                            CupertinoIcons.calendar_badge_minus,
                            color: AppTheme.textMuted,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'No pending or reserved bookings.',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = bookings[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.bgSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.property,
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    _StatusPill(label: item.status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.scheduledFor,
                                  style: TextStyle(color: AppTheme.textMuted),
                                ),
                                if (item.agent.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Agent: ${item.agent}',
                                    style: TextStyle(color: AppTheme.textMuted),
                                  ),
                                ],
                                if (item.notes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    item.notes,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
    final state = context.watch<Property24State>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(
              title: 'Help center',
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              children: [
                _InfoRow(
                  label: 'Account',
                  value: state.user?.name ?? 'Guest',
                  showDivider: true,
                ),
                _InfoRow(
                  label: 'Role',
                  value: state.account.role.label,
                  showDivider: true,
                ),
                _InfoRow(
                  label: 'Open chats',
                  value: '${state.snapshot.conversations.length}',
                  showDivider: true,
                ),
                _InfoRow(
                  label: 'Active bookings',
                  value:
                      '${state.snapshot.viewings.where((item) => item.isAvailableBooking).length}',
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'For account recovery, booking disputes, property verification, document review, and chat safety, contact support with your account name and the relevant property or booking.',
              style: TextStyle(color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
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
  final _nationalId = TextEditingController();
  final _agencyRegistration = TextEditingController();
  final _agencyName = TextEditingController();
  final _contactDetails = TextEditingController();
  final _picker = ImagePicker();
  XFile? _frontDocument;
  XFile? _backDocument;
  XFile? _ownershipDocument;
  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  Uint8List? _ownershipBytes;
  String? _challengeId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _nationalId.dispose();
    _agencyRegistration.dispose();
    _agencyName.dispose();
    _contactDetails.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final user = state.user ?? widget.user;
    final matchingVerifications = state.snapshot.verifications
        .where(
            (item) => item.role.toLowerCase() == user?.role.label.toLowerCase())
        .toList();
    final latestVerification =
        matchingVerifications.isEmpty ? null : matchingVerifications.first;
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Sign in to verify your account.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelHeader(
                title: 'Verification',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 18),
              _VerificationRow(
                label: 'Identity',
                value: user.verified
                    ? 'Document information verified'
                    : 'National ID review required',
                verified: user.verified,
              ),
              if (latestVerification != null && !user.verified) ...[
                const SizedBox(height: 8),
                _VerificationStatusCard(item: latestVerification),
              ],
              if (!user.verified) ...[
                const SizedBox(height: 12),
                _ThemedField(
                  controller: _nationalId,
                  label: 'National ID number',
                  hint: '63-123456-A-12',
                ),
                const SizedBox(height: 12),
                _DocumentPickerTile(
                  label: 'ID front image',
                  fileName: _frontDocument?.name,
                  selected: _frontBytes != null,
                  onPick: () => _pickDocument(_VerificationUploadSlot.front),
                ),
                const SizedBox(height: 10),
                _DocumentPickerTile(
                  label: 'ID back image',
                  fileName: _backDocument?.name,
                  selected: _backBytes != null,
                  onPick: () => _pickDocument(_VerificationUploadSlot.back),
                ),
                if (user.role == AccountRole.landlord) ...[
                  const SizedBox(height: 10),
                  _DocumentPickerTile(
                    label: 'Ownership or authorization image',
                    fileName: _ownershipDocument?.name,
                    selected: _ownershipBytes != null,
                    onPick: () =>
                        _pickDocument(_VerificationUploadSlot.ownership),
                  ),
                ],
                if (user.role == AccountRole.agent) ...[
                  const SizedBox(height: 12),
                  _ThemedField(
                    controller: _agencyRegistration,
                    label: 'Estate agency registration',
                  ),
                  const SizedBox(height: 12),
                  _ThemedField(
                    controller: _agencyName,
                    label: 'Agency name',
                  ),
                  const SizedBox(height: 12),
                  _ThemedField(
                    controller: _contactDetails,
                    label: 'Business contact details',
                    maxLines: 3,
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Upload clear JPEG, PNG, or WEBP images. Files are checked for size, dimensions, quality, OCR availability, and duplicate reuse. Results may require manual review.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _busy ? null : _submitIdentity,
                    icon: const Icon(CupertinoIcons.checkmark_shield),
                    label: const Text('Submit identity verification'),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: AppTheme.accent)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDocument(_VerificationUploadSlot slot) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2600,
      maxHeight: 2600,
      imageQuality: 95,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      switch (slot) {
        case _VerificationUploadSlot.front:
          _frontDocument = image;
          _frontBytes = bytes;
          break;
        case _VerificationUploadSlot.back:
          _backDocument = image;
          _backBytes = bytes;
          break;
        case _VerificationUploadSlot.ownership:
          _ownershipDocument = image;
          _ownershipBytes = bytes;
          break;
      }
      _error = null;
    });
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

  Future<void> _submitIdentity() async {
    final idNumber = _nationalId.text.trim();
    if (idNumber.isEmpty) {
      setState(() => _error = 'Enter your national ID number');
      return;
    }
    if (_frontBytes == null || _frontDocument == null) {
      setState(() => _error = 'Upload the front of your ID');
      return;
    }
    if (_backBytes == null || _backDocument == null) {
      setState(() => _error = 'Upload the back of your ID');
      return;
    }
    final user = context.read<Property24State>().user ?? widget.user;
    if (user?.role == AccountRole.landlord &&
        (_ownershipBytes == null || _ownershipDocument == null)) {
      setState(() => _error = 'Upload ownership or authorization proof');
      return;
    }
    if (user?.role == AccountRole.agent) {
      if (_agencyRegistration.text.trim().isEmpty) {
        setState(() => _error = 'Enter the estate agency registration');
        return;
      }
      if (_agencyName.text.trim().isEmpty) {
        setState(() => _error = 'Enter the agency name');
        return;
      }
      if (_contactDetails.text.trim().isEmpty) {
        setState(() => _error = 'Enter business contact details');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Property24State>().submitIdentityVerification(
            nationalIdNumber: idNumber,
            idFrontBytes: _frontBytes!,
            idFrontName: _frontDocument!.name,
            idFrontMimeType: _frontDocument!.mimeType ?? '',
            idBackBytes: _backBytes!,
            idBackName: _backDocument!.name,
            idBackMimeType: _backDocument!.mimeType ?? '',
            ownershipBytes: _ownershipBytes,
            ownershipName: _ownershipDocument?.name,
            ownershipMimeType: _ownershipDocument?.mimeType,
            estateAgencyRegistration: _agencyRegistration.text.trim(),
            agencyName: _agencyName.text.trim(),
            contactDetails: _contactDetails.text.trim(),
          );
      if (mounted) {
        setState(() {
          _frontDocument = null;
          _backDocument = null;
          _ownershipDocument = null;
          _frontBytes = null;
          _backBytes = null;
          _ownershipBytes = null;
          _nationalId.clear();
          _agencyRegistration.clear();
          _agencyName.clear();
          _contactDetails.clear();
        });
      }
    } catch (exception) {
      if (mounted) setState(() => _error = userFacingError(exception));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _VerificationStatusCard extends StatelessWidget {
  const _VerificationStatusCard({required this.item});

  final VerificationItem item;

  @override
  Widget build(BuildContext context) {
    final needsReview = item.status.toLowerCase().contains('review');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest result: ${item.status}',
            style: TextStyle(
              color: needsReview ? AppTheme.accent : AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (item.ocrConfidence.isNotEmpty)
            Text('OCR: ${item.ocrConfidence}',
                style: TextStyle(color: AppTheme.textMuted)),
          if (item.duplicateDocument)
            Text('Duplicate document detected: manual review required',
                style: TextStyle(color: AppTheme.accent)),
          if (item.checks.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final check in item.checks.take(5))
              Text('• $check',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

enum _VerificationUploadSlot { front, back, ownership }

class _DocumentPickerTile extends StatelessWidget {
  const _DocumentPickerTile({
    required this.label,
    required this.fileName,
    required this.selected,
    required this.onPick,
  });
  final String label;
  final String? fileName;
  final bool selected;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bgSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.doc_text,
                color: selected ? AppTheme.accent : AppTheme.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileName?.isNotEmpty == true ? fileName! : 'Choose image',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_forward, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
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
        verified ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.clock,
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
