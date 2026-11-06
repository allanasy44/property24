import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MarketNavigation extends StatelessWidget {
  const MarketNavigation({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const _markets = [
    ('Properties', 'properties', CupertinoIcons.house_fill),
    ('Stays', 'stays', CupertinoIcons.bed_double_fill),
    ('Venues', 'venues', CupertinoIcons.building_2_fill),
    ('Services', 'services', CupertinoIcons.wrench_fill),
    ('Jobs', 'jobs', CupertinoIcons.briefcase_fill),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        itemCount: _markets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, value, icon) = _markets[index];
          final isSelected = selected == value;
          return Semantics(
            button: true,
            selected: isSelected,
            label: label,
            child: Material(
              color: isSelected ? AppTheme.accent : AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                onTap: () => onSelected(value),
                borderRadius: BorderRadius.circular(15),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minWidth: 76),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isSelected ? AppTheme.accent : AppTheme.border,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected ? Colors.white : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
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
    );
  }
}
