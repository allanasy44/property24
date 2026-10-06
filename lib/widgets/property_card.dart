import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../models/rental_models.dart';
import '../theme/app_theme.dart';

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    required this.property,
    this.onTap,
    this.trailing,
    this.saved = false,
    this.compared = false,
    this.onSave,
    this.onCompare,
    this.distanceLabel,
    super.key,
  });

  final PropertyListing property;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool saved;
  final bool compared;
  final VoidCallback? onSave;
  final VoidCallback? onCompare;
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: property.photos.isEmpty
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.bgSurface, AppTheme.borderMid],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.building_2_fill,
                            color: colorScheme.secondary,
                            size: 46,
                          ),
                        )
                      : Image.network(
                          property.photos.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                            ),
                            child: Icon(
                              CupertinoIcons.building_2_fill,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _ImageBadge(
                    icon: CupertinoIcons.checkmark_seal,
                    label: '${property.trustScore}% trust',
                    emphasized: property.trustScore >= 80,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Row(
                    children: [
                      _RoundIconButton(
                        tooltip: saved ? 'Remove saved home' : 'Save home',
                        icon: saved
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        selected: saved,
                        onPressed: onSave,
                      ),
                      const SizedBox(width: 8),
                      _RoundIconButton(
                        tooltip: compared
                            ? 'Remove from comparison'
                            : 'Compare home',
                        icon: CupertinoIcons.arrow_left_right,
                        selected: compared,
                        onPressed: onCompare,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: AvailabilityIndicator(
                    label: property.availabilityLabel,
                    state: property.availabilityState,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.location.isEmpty
                              ? property.address
                              : property.location,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (distanceLabel != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          CupertinoIcons.location,
                          size: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          distanceLabel!,
                          style: textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Pill(
                          icon: CupertinoIcons.money_dollar,
                          label: property.rentLabel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Pill(
                          icon: property.isLand
                              ? CupertinoIcons.square_stack_3d_up
                              : CupertinoIcons.money_dollar_circle,
                          label: property.isLand
                              ? property.standSummary
                              : '${property.moveInTotalLabel} rent + deposit',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (property.isLand) ...[
                        _Pill(
                          icon: CupertinoIcons.square,
                          label: property.landSizeLabel,
                        ),
                        _Pill(
                          icon: CupertinoIcons.doc_text,
                          label: property.landTitleLabel,
                        ),
                        _Pill(
                          icon: CupertinoIcons.location,
                          label: property.landServicingLabel,
                        ),
                        if (property.electricityAvailable)
                          const _Pill(
                            icon: CupertinoIcons.bolt,
                            label: 'Electricity',
                          ),
                        if (property.landWaterAvailable)
                          const _Pill(
                            icon: CupertinoIcons.drop,
                            label: 'Water',
                          ),
                      ] else ...[
                        _Pill(
                          icon: CupertinoIcons.bed_double,
                          label: '${property.bedrooms} beds',
                        ),
                        _Pill(
                          icon: CupertinoIcons.drop,
                          label: '${property.bathrooms} baths',
                        ),
                        _Pill(
                          icon: CupertinoIcons.drop,
                          label: property.borehole
                              ? 'Borehole'
                              : property.waterAvailability,
                        ),
                        if (property.solarPower)
                          const _Pill(
                            icon: CupertinoIcons.bolt,
                            label: 'Solar',
                          ),
                      ],
                      if (property.has360Tour)
                        const _Pill(
                          icon: CupertinoIcons.rotate_right,
                          label: '360 tour',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? colorScheme.primary
              : colorScheme.surface.withValues(alpha: 0.9),
          foregroundColor:
              selected ? colorScheme.onPrimary : colorScheme.secondary,
          fixedSize: const Size.square(40),
          minimumSize: const Size.square(40),
        ),
      ),
    );
  }
}

class AvailabilityIndicator extends StatelessWidget {
  const AvailabilityIndicator({
    required this.label,
    required this.state,
    super.key,
  });

  final String label;
  final String state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      'available_from' ||
      'needs_confirmation' ||
      'reserved' =>
        Colors.amber.shade700,
      'rented' || 'sold' || 'temporarily_hidden' => Colors.red.shade700,
      _ => Colors.green.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.circle_fill, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class AvailabilityActionMenu extends StatelessWidget {
  const AvailabilityActionMenu({required this.onSelected, super.key});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Update availability',
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'available', child: Text('Mark available')),
        PopupMenuItem(
          value: 'available_from',
          child: Text('Available from date...'),
        ),
        PopupMenuItem(value: 'rented', child: Text('Mark rented')),
        PopupMenuItem(value: 'sold', child: Text('Mark sold')),
      ],
      icon: const Icon(CupertinoIcons.ellipsis_circle),
    );
  }
}

class _ImageBadge extends StatelessWidget {
  const _ImageBadge({
    required this.icon,
    required this.label,
    required this.emphasized,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: emphasized
            ? AppTheme.trustHigh
            : colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: emphasized ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: emphasized
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
