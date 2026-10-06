import 'package:flutter/material.dart';

import '../models/rental_models.dart';
import '../theme/app_theme.dart';

class PropertyComparisonScreen extends StatelessWidget {
  const PropertyComparisonScreen({
    required this.properties,
    super.key,
  });

  final List<PropertyListing> properties;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String Function(PropertyListing) value})>[
      (label: 'Monthly price', value: (property) => property.rentLabel),
      (label: 'Bedrooms', value: (property) => '${property.bedrooms}'),
      (label: 'Bathrooms', value: (property) => '${property.bathrooms}'),
      (
        label: 'Parking',
        value: (property) => _hasParking(property.parking) ? '✓' : '—',
      ),
      (label: 'Solar', value: (property) => property.solarPower ? '✓' : '—'),
      (label: 'Borehole', value: (property) => property.borehole ? '✓' : '—'),
      (
        label: 'Furnished',
        value: (property) => property.furnished ? '✓' : '—',
      ),
      (
        label: 'Pet friendly',
        value: (property) => property.petFriendly ? '✓' : '—',
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Compare properties'),
        backgroundColor: AppTheme.bgCard,
      ),
      body: properties.length < 2
          ? Center(
              child: Text(
                'Select at least two properties to compare.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 124),
                      for (final property in properties)
                        SizedBox(
                          width: 184,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  property.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  property.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  for (final row in rows)
                    Container(
                      decoration: BoxDecoration(
                        color: rows.indexOf(row).isEven
                            ? AppTheme.bgCard
                            : AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 124,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                row.label,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          for (final property in properties)
                            SizedBox(
                              width: 184,
                              child: Center(
                                child: Text(
                                  row.value(property),
                                  style: TextStyle(
                                    color: row.value(property) == '✓'
                                        ? AppTheme.accent
                                        : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  static bool _hasParking(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty &&
        normalized != 'none' &&
        normalized != 'no' &&
        normalized != 'no parking';
  }
}
