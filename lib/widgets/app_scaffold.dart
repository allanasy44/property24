import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../state/property24_state.dart';

import '../theme/app_theme.dart';
import 'inprop_brand.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      extendBody: true,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: const InPropBrand(compact: true),
                ),
              ),
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        isLandlord: state.user?.role == AccountRole.landlord,
        unreadMessages: state.unreadMessageCount,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.isLandlord,
    required this.unreadMessages,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isLandlord;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Navigation icons based on the reference design:
    // Home • Saved • Messages • Profile
    final items = isLandlord
        ? const [
            _NavItem(icon: CupertinoIcons.house, label: 'Dashboard'),
            _NavItem(icon: CupertinoIcons.building_2_fill, label: 'Listings'),
          ]
        : const [
            _NavItem(icon: CupertinoIcons.house, label: 'Home'),
            _NavItem(icon: CupertinoIcons.heart, label: 'Saved'),
          ];
    final allItems = [
      ...items,
      _NavItem(
        icon: CupertinoIcons.chat_bubble,
        label: 'Messages',
        badgeCount: unreadMessages,
      ),
      _NavItem(icon: CupertinoIcons.person_circle, label: 'Profile'),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        14,
      ),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha(80),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(22),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          child: Row(
            children: List.generate(
              allItems.length,
              (index) {
                final item = allItems[index];
                final selected = index == currentIndex;

                return Expanded(
                  child: _BottomNavItem(
                    item: item,
                    selected: selected,
                    onTap: () => onTap(index),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color:
                selected ? AppTheme.accent.withAlpha(25) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.90,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(
                  '${item.label}-$selected',
                ),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    isLabelVisible: item.badgeCount > 0,
                    label: Text(
                      item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                      style: const TextStyle(fontSize: 9),
                    ),
                    child: Icon(
                      item.icon,
                      size: selected ? 22 : 21,
                      color: selected
                          ? AppTheme.accent
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppTheme.accent
                          : colorScheme.onSurfaceVariant,
                      height: 1.0,
                      letterSpacing: 0,
                    ),
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

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final int badgeCount;
}
