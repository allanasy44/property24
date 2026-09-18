import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:unicons/unicons.dart';

import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: navigationShell,
      bottomNavigationBar: _BottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // FIX: colorScheme belongs to this widget's build context.
    final colorScheme = Theme.of(context).colorScheme;

    final items = [
      const _NavItem(
        icon: UniconsLine.estate,
        label: 'Home',
      ),
      const _NavItem(
        icon: UniconsLine.phone,
        label: 'Calls',
      ),
      const _NavItem(
        icon: UniconsLine.comment_alt_message,
        label: 'Chat',
      ),
      const _NavItem(
        icon: UniconsLine.user_circle,
        label: 'Profile',
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          child: Row(
            children: List.generate(
              items.length,
              (index) {
                final isActive = index == currentIndex;

                return Expanded(
                  child: Tooltip(
                    message: items[index].label,
                    child: GestureDetector(
                      onTap: () => onTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 250,
                        ),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.accent.withAlpha(30)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              items[index].icon,
                              color: isActive
                                  ? AppTheme.accent
                                  : colorScheme.onSurfaceVariant,
                              size: isActive ? 24 : 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              items[index].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 11,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isActive
                                    ? AppTheme.accent
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
