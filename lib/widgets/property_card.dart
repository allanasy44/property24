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
                  aspectRatio: 2.25,
                  child: property.photos.isEmpty
                      ? const _PropertyImagePlaceholder()
                      : Image.network(
                          property.photos.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => DecoratedBox(
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
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffeee9ff),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${property.trustScore}% trust',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ?trailing,
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
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
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
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: property.rentLabel,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (property.parking.trim().isNotEmpty)
                          TextSpan(
                            text: '  ·  ${property.parking}',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        TextSpan(
                          text:
                              '  ·  ${property.isLand
                                  ? 'Land'
                                  : property.isStay
                                  ? 'Stay'
                                  : property.isVenue
                                  ? 'Venue'
                                  : property.propertyType}',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 13),
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

class _PropertyImagePlaceholder extends StatelessWidget {
  const _PropertyImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xfffaf8ff), Color(0xffc8b8ff)],
            ),
          ),
        ),
        CustomPaint(painter: _PlaceholderStripePainter()),
      ],
    );
  }
}

class _PlaceholderStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.2;
    const step = 28.0;
    for (var start = -size.height; start < size.width; start += step) {
      canvas.drawLine(
        Offset(start, size.height),
        Offset(start + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          foregroundColor: selected
              ? colorScheme.onPrimary
              : colorScheme.secondary,
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
      'reserved' => Colors.amber.shade700,
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
