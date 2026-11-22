import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.email,
    required this.initials,
    required this.profilePicture,
    required this.onEdit,
    required this.verified,
  });

  final String name;
  final String email;
  final String initials;
  final String? profilePicture;
  final VoidCallback? onEdit;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final hasImage = profilePicture?.isNotEmpty == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff24174a).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent,
                  border: Border.all(color: AppTheme.border, width: 2),
                  image: hasImage
                      ? DecorationImage(
                          image: NetworkImage(profilePicture!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasImage
                    ? null
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
              if (verified)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.bgCard, width: 2),
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark,
                      color: Colors.white,
                      size: 12,
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit profile',
            onPressed: onEdit,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.bgSurface,
              foregroundColor: AppTheme.accent,
            ),
            icon: const Icon(CupertinoIcons.pencil, size: 18),
          ),
        ],
      ),
    );
  }
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
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.paddingOf(context).bottom + 128,
          ),
          physics: const BouncingScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
              child: Text(
                'You',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _ProfileHero(
              name: name,
              email: user?.email.isNotEmpty == true
                  ? user!.email
                  : 'Not signed in',
              initials: initials.isEmpty ? 'P' : initials,
              profilePicture: hasImage ? user!.profilePicture : null,
              onEdit: user == null
                  ? null
                  : () => _openProfileEditor(context, user),
              verified: user?.verified == true,
            ),
            if (user != null && !user.verified) ...[
              const SizedBox(height: 14),
              _IdentityPrompt(
                submitted: user.identityDocumentsSubmitted,
                onTap: () => _openVerification(context, user),
              ),
            ],
            const SizedBox(height: 26),

            const _ProfileSectionHeading('ACTIVITY'),
            _MenuCardTile(
              icon: CupertinoIcons.heart,
              label: 'Saved',
              onTap: () => context.push(AppRoutes.callsScreen),
            ),
            _MenuCardTile(
              icon: CupertinoIcons.building_2_fill,
              label: 'My listings',
              subtitle: 'Homes, stays, services, jobs',
              onTap: () => context.push(AppRoutes.listingsScreen),
            ),
            _MenuCardTile(
              icon: CupertinoIcons.calendar,
              label: 'Bookings',
              subtitle:
                  '${state.snapshot.viewings.where((item) => item.isAvailableBooking).length} active',
              onTap: () => context.push(AppRoutes.activityScreen),
            ),
            const SizedBox(height: 24),
            const _ProfileSectionHeading('ACCOUNT'),
            _MenuCardTile(
              icon: CupertinoIcons.gear,
              label: 'Settings',
              onTap: () => _openSettings(context),
            ),
            _MenuCardTile(
              icon: CupertinoIcons.person_2,
              label: 'Help center',
              onTap: () => _openHelp(context),
            ),

            const SizedBox(height: 24),

            // ─── Sign out ───
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: const BorderSide(color: AppTheme.accent, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: user == null ? null : () => _signOut(context),
              icon: const Icon(CupertinoIcons.square_arrow_right, size: 18),
              label: const Text(
                'Sign out',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to log in again to message hosts or manage listings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !context.mounted) return;
    await context.read<Property24State>().signOut();
    if (context.mounted) context.go(AppRoutes.initial);
  }

  void _openProfileEditor(BuildContext context, AccountUser user) {
    _openSidePanel<void>(
      context: context,
      child: _ProfileEditor(user: user),
    );
  }

  void _openSettings(BuildContext context) {
    _openSidePanel<void>(context: context, child: const _SettingsSheet());
  }

  void _openHelp(BuildContext context) {
    _openSidePanel<void>(context: context, child: const _HelpCenterSheet());
  }

  void _openVerification(BuildContext context, AccountUser? user) {
    _openSidePanel<void>(
      context: context,
      child: _VerificationSheet(user: user),
    );
  }
}

class _ProfileSectionHeading extends StatelessWidget {
  const _ProfileSectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _IdentityPrompt extends StatelessWidget {
  const _IdentityPrompt({required this.submitted, required this.onTap});

  final bool submitted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff24174a).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  CupertinoIcons.checkmark_shield,
                  color: AppTheme.accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      submitted
                          ? 'Your ID is being reviewed'
                          : 'Upload both sides of your ID to list',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right, color: AppTheme.textPrimary),
            ],
          ),
        ),
      ),
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
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: SafeArea(
          left: false,
          child: Material(
            color: AppTheme.bgCard,
            elevation: 12,
            borderRadius: width < 560
                ? BorderRadius.zero
                : const BorderRadius.horizontal(left: Radius.circular(24)),
            child: SizedBox(
              width: width < 560 ? width : 440,
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
  }) : badge = null;

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
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
                          color: AppTheme.accent.withValues(alpha: 0.18),
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
                                color: AppTheme.bgCard,
                                width: 2,
                              ),
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
                            'Name',
                            state.user?.name ?? 'Not signed in',
                          ),
                          _InfoRowData(
                            'Phone',
                            state.user?.phone ?? 'Not provided',
                          ),
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
                            'Your account keeps your profile, bookings, conversations, and applications together in one place. Identity documents are processed for verification and retained only for the configured review window.',
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
                        body: 'English is the current app language.',
                      ),
                    ),
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
              const SizedBox(height: 24),
              const _SectionLabel('SUPPORT'),
              const SizedBox(height: 10),
              _MenuCard(
                children: [
                  _SettingsTile(
                    icon: CupertinoIcons.question_circle,
                    label: 'Help center',
                    onTap: () =>
                        _openNestedPanel(context, const _HelpCenterSheet()),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'For account recovery, booking disputes, verification or chat safety, email us with your account name and the property or booking.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
              const SelectableText(
                'support@property24.co.zw',
                style: TextStyle(color: AppTheme.accent),
              ),
              const SizedBox(height: 14),
              Text(
                '${state.snapshot.conversations.length} chat · '
                '${state.snapshot.viewings.where((item) => item.isAvailableBooking).length} bookings · '
                '${state.snapshot.verifications.length} verifications',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _signOutFromSettings(context, state),
                  child: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNestedPanel(BuildContext context, Widget child) {
    _openSidePanel<void>(context: context, child: child);
  }

  Future<void> _signOutFromSettings(
    BuildContext context,
    Property24State state,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to log in again to message hosts or manage listings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await state.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    context.go(AppRoutes.initial);
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
        TextButton(onPressed: onClose, child: const Text('Done')),
      ],
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
        color: AppTheme.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
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
              style: TextStyle(color: AppTheme.textMuted, height: 1.45),
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
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.8,
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
            child: Divider(height: 1, thickness: 0.6, color: AppTheme.border),
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
        activeTrackColor: AppTheme.accent,
        inactiveTrackColor: AppTheme.bgSurface,
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
    final phoneLocked = widget.user.phone.trim().isNotEmpty;
    return SafeArea(
      child: ColoredBox(
        color: AppTheme.bg,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        CupertinoIcons.chevron_left,
                        color: AppTheme.textPrimary,
                        size: 28,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Profile',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 28),
                _ProfileImagePicker(
                  currentImageUrl: widget.user.profilePicture,
                  selectedImageBytes: _selectedImageBytes,
                  removeImage: _removeImage,
                  onPick: _pickImage,
                ),
                const SizedBox(height: 30),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      _ProfileEditRow(
                        label: 'Name',
                        controller: _name,
                        keyboardType: TextInputType.name,
                      ),
                      _ProfileEditRow(
                        label: 'About',
                        controller: _bio,
                        hint: '',
                      ),
                      _ProfileEditRow(
                        label: 'Username',
                        controller: _username,
                        emptyValue: 'Reserve username',
                        actionColor: AppTheme.accentTeal,
                      ),
                      _ProfileEditRow(
                        label: 'Phone number',
                        controller: _phone,
                        enabled: !phoneLocked,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? CupertinoActivityIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                          )
                        : const Text('Save changes'),
                  ),
                ),
              ],
            ),
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
    setState(() => _saving = true);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
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
  });

  final String currentImageUrl;
  final Uint8List? selectedImageBytes;
  final bool removeImage;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasCurrentImage = currentImageUrl.isNotEmpty && !removeImage;
    return Column(
      children: [
        ClipOval(
          child: SizedBox(
            width: 100,
            height: 100,
            child: selectedImageBytes != null
                ? Image.memory(selectedImageBytes!, fit: BoxFit.cover)
                : hasCurrentImage
                ? Image.network(currentImageUrl, fit: BoxFit.cover)
                : ColoredBox(
                    color: AppTheme.accent.withValues(alpha: 0.18),
                    child: Icon(
                      CupertinoIcons.person_crop_circle,
                      color: AppTheme.accent,
                      size: 50,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onPick,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.accentTeal,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Edit photo'),
        ),
      ],
    );
  }
}

class _ProfileEditRow extends StatelessWidget {
  const _ProfileEditRow({
    required this.label,
    required this.controller,
    this.emptyValue,
    this.actionColor,
    this.hint,
    this.keyboardType,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? emptyValue;
  final Color? actionColor;
  final String? hint;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final value = controller.text.trim();
    return Container(
      constraints: const BoxConstraints(minHeight: 43),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: actionColor ?? AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: value.isEmpty ? (emptyValue ?? hint) : null,
                hintStyle: TextStyle(
                  color: actionColor ?? AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: AppTheme.textMuted,
            size: 18,
          ),
        ],
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
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
        color: AppTheme.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
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
            const SizedBox(height: 16),
            _MenuCard(
              children: [
                _InfoRow(
                  label: 'Account',
                  value: state.user?.name ?? 'Guest',
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
            const SizedBox(height: 22),
            const _ProfileSectionHeading('WHAT DO YOU NEED?'),
            _MenuCard(
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.person_crop_circle,
                  label: 'Account recovery',
                  onTap: () => _showHelpTopic(context, 'Account recovery'),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.calendar,
                  label: 'Booking disputes',
                  onTap: () => _showHelpTopic(context, 'Booking disputes'),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.checkmark_shield,
                  label: 'Property verification',
                  onTap: () => _showHelpTopic(context, 'Property verification'),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.lock_shield,
                  label: 'Chat safety',
                  onTap: () => _showHelpTopic(context, 'Chat safety'),
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Include your account name and the property or booking when you write to us.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _showSupportContact(context),
                child: const Text('Email support'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpTopic(BuildContext context, String topic) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.bgCard,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Contact support with your account name and the relevant property or booking.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              const SelectableText('support@property24.co.zw'),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportContact(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.bgCard,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Contact support',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const SelectableText('support@property24.co.zw'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: 'support@property24.co.zw'),
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Support email copied')),
                      );
                    }
                  },
                  child: const Text('Copy address'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
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
  final _picker = ImagePicker();
  XFile? _frontDocument;
  XFile? _backDocument;
  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  String? _error;
  String? _submissionMessage;
  bool _busy = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final user = state.user ?? widget.user;
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Sign in to verify your account.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    final latestVerification = state.snapshot.verifications.isEmpty
        ? null
        : state.snapshot.verifications.first;
    final latestStatus = latestVerification?.status.toLowerCase().replaceAll(
      '_',
      ' ',
    );
    return SafeArea(
      child: ColoredBox(
        color: AppTheme.bg,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        CupertinoIcons.chevron_left,
                        color: AppTheme.textPrimary,
                        size: 28,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Verification',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.checkmark_shield,
                    color: AppTheme.accent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Verify your account',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Upload clear images of both sides of your ID to create listings. Review can continue after your images are submitted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      _VerificationRow(
                        label: 'Identity',
                        value: user.verified
                            ? 'ID verified'
                            : user.identityDocumentsSubmitted
                            ? 'ID images submitted'
                            : 'ID images required',
                        verified: user.verified,
                      ),
                    ],
                  ),
                ),
                if (_submissionMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _submissionMessage!,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                if (user.identityDocumentsSubmitted && !user.verified) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Your ID images were received. You can create listings while identity review continues.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                if (latestStatus == 'rejected' && !user.verified) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Some ID details could not be read. You can upload clearer images if needed.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                if (!user.identityDocumentsSubmitted ||
                    (latestStatus == 'rejected' && !user.verified)) ...[
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _DocumentPickerTile(
                          label: 'ID front image',
                          fileName: _frontDocument?.name,
                          selected: _frontBytes != null,
                          onPick: () => _pickDocument(front: true),
                        ),
                        const SizedBox(height: 10),
                        _DocumentPickerTile(
                          label: 'ID back image',
                          fileName: _backDocument?.name,
                          selected: _backBytes != null,
                          onPick: () => _pickDocument(front: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Upload clear JPEG, PNG, or WEBP images of both sides of your ID. Both images must be submitted before you can create listings.',
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
                      label: const Text('Submit ID images'),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppTheme.accent)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDocument({required bool front}) async {
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
      if (front) {
        _frontDocument = image;
        _frontBytes = bytes;
      } else {
        _backDocument = image;
        _backBytes = bytes;
      }
      _error = null;
      _submissionMessage = null;
    });
  }

  Future<void> _submitIdentity() async {
    if (_frontBytes == null || _frontDocument == null) {
      setState(() => _error = 'Upload the front of your ID');
      return;
    }
    if (_backBytes == null || _backDocument == null) {
      setState(() => _error = 'Upload the back of your ID');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = context.read<Property24State>();
      final result = await state.submitIdentityVerification(
        idFrontBytes: _frontBytes!,
        idFrontName: _frontDocument!.name,
        idFrontMimeType: _frontDocument!.mimeType ?? '',
        idBackBytes: _backBytes!,
        idBackName: _backDocument!.name,
        idBackMimeType: _backDocument!.mimeType ?? '',
      );
      final status = result.status.toLowerCase().replaceAll('_', ' ');
      if (mounted) {
        setState(() {
          _submissionMessage = status == 'verified'
              ? 'Your identity has been verified.'
              : status == 'rejected'
              ? 'The ID number did not match the document. Check your details and try again.'
              : 'Your documents were submitted for manual review. We will notify you when it is complete.';
          _frontDocument = null;
          _backDocument = null;
          _frontBytes = null;
          _backBytes = null;
        });
      }
    } catch (exception) {
      if (mounted) setState(() => _error = userFacingError(exception));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

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
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
