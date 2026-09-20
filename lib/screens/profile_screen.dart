import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color _bg = Color(0xFF121212);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _red = Color(0xFFFF3B30);
  static const Color _redTint = Color(0x33FF3B30);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFF8E8E93);
  static const Color _border = Color(0xFF2C2C2E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          physics: const BouncingScrollPhysics(),
          children: [
            // ─── Back arrow + "Profile" title ───
            Row(
              children: [
                _CircleIconButton(
                  icon: CupertinoIcons.back,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 28),

            // ─── Avatar + red pencil badge ───
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _card,
                      border: Border.all(color: _border, width: 2),
                      image: const DecorationImage(
                        image: NetworkImage('https://i.pravatar.cc/300?img=33'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _red,
                        shape: BoxShape.circle,
                        border: Border.all(color: _bg, width: 3),
                      ),
                      child: const Icon(CupertinoIcons.pencil,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ─── Name ───
            const Center(
              child: Text(
                'Courtney Henry',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ─── Email ───
            const Center(
              child: Text(
                'nevaeh.simmons@example.com',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _textSecondary,
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
              onTap: () {},
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
              onTap: () {},
              showBottomSpacing: false,
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SettingsSheet(),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  SETTINGS SHEET (from the "Setting" image)
// ═════════════════════════════════════════════════════════════
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _iconBox = Color(0xFF2A2A2C);
  static const Color _red = Color(0xFFFF3B30);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFF8E8E93);
  static const Color _divider = Color(0xFF2C2C2E);

  bool _pushEnabled = true;
  bool _darkEnabled = false;

  @override
  Widget build(BuildContext context) {
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
            const Center(
              child: Text(
                'Setting',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Account Settings ───
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

            // ─── App Settings ───
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
                  trailing: _RedSwitch(
                    value: _pushEnabled,
                    onChanged: (v) => setState(() => _pushEnabled = v),
                  ),
                  onTap: () => setState(() => _pushEnabled = !_pushEnabled),
                ),
                _SettingsTile(
                  icon: CupertinoIcons.moon,
                  label: 'Dark Mode',
                  trailing: _RedSwitch(
                    value: _darkEnabled,
                    onChanged: (v) => setState(() => _darkEnabled = v),
                  ),
                  onTap: () => setState(() => _darkEnabled = !_darkEnabled),
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
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFF8E8E93),
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
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
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
                    color: const Color(0xFF2A2A2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                trailing ??
                    const Icon(
                      CupertinoIcons.chevron_forward,
                      size: 18,
                      color: Color(0xFF8E8E93),
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 70, right: 14),
            child: Divider(
              height: 1,
              thickness: 0.6,
              color: Color(0xFF2C2C2E),
            ),
          ),
      ],
    );
  }
}

class _RedSwitch extends StatelessWidget {
  const _RedSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.85,
      child: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFFF3B30),
        trackColor: const Color(0xFF3A3A3C),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  Profile screen — menu card tile
// ═════════════════════════════════════════════════════════════
class _MenuCardTile extends StatelessWidget {
  const _MenuCardTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.showBottomSpacing = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;
  final bool showBottomSpacing;

  static const Color _card = Color(0xFF1C1C1E);
  static const Color _red = Color(0xFFFF3B30);
  static const Color _redTint = Color(0x33FF3B30);
  static const Color _textPrimary = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: showBottomSpacing ? 14 : 0),
      child: Material(
        color: _card,
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
                        color: _redTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 22, color: _red),
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
                            color: _red,
                            shape: BoxShape.circle,
                            border: Border.all(color: _card, width: 2),
                          ),
                          child: Text(
                            '$badge',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
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
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  size: 18,
                  color: Color(0xFF8E8E93),
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
// Circular outlined back button
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
          border: Border.all(color: const Color(0xFF3A3A3C), width: 1.2),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
