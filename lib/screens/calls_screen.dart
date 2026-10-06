import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';
import 'listings_screen.dart';
import 'property_detail_screen.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class SavedHomesScreen extends StatefulWidget {
  const SavedHomesScreen({super.key});

  @override
  State<SavedHomesScreen> createState() => _SavedHomesScreenState();
}

class _SavedHomesScreenState extends State<SavedHomesScreen> {
  _SavedFilter filter = _SavedFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    if (state.user?.role == AccountRole.landlord) {
      return const ListingsScreen();
    }
    final properties = state.snapshot.savedProperties
        .map(state.currentProperty)
        .toList(growable: false);
    final sale = properties
        .where((property) => property.listingIntent == 'sale')
        .toList();
    final rent = properties
        .where((property) => property.listingIntent == 'rent')
        .toList();
    final visible = filter == _SavedFilter.sale
        ? sale
        : filter == _SavedFilter.rent
            ? rent
            : properties;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: state.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: AppTheme.bg,
                foregroundColor: AppTheme.textPrimary,
                elevation: 0,
                scrolledUnderElevation: 0,
                pinned: true,
                title: const Text('Saved & Reserved'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: filter == _SavedFilter.all,
                          onTap: () =>
                              setState(() => filter = _SavedFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'For Sale',
                          selected: filter == _SavedFilter.sale,
                          onTap: () =>
                              setState(() => filter = _SavedFilter.sale),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'For Rent',
                          selected: filter == _SavedFilter.rent,
                          onTap: () =>
                              setState(() => filter = _SavedFilter.rent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.loading && properties.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                )
              else if (visible.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      switch (filter) {
                        _SavedFilter.sale => 'No saved properties for sale.',
                        _SavedFilter.rent => 'No saved rental properties.',
                        _SavedFilter.all => 'Nothing saved or reserved yet.',
                      },
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) => _PropertyCard(
                      property: visible[index],
                      onRemove: () => _removeSaved(state, visible[index]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeSaved(
    Property24State state,
    PropertyListing property,
  ) async {
    try {
      await state.toggleSaved(property);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }
}

enum _SavedFilter { all, sale, rent }

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property, required this.onRemove});

  final PropertyListing property;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final image = property.photos.isNotEmpty ? property.photos.first : '';
    final intent = property.listingIntent == 'sale' ? 'For Sale' : 'For Rent';
    final lifecycle = property.reserved
        ? 'Reserved'
        : property.availabilityStatus == 'sold'
            ? 'Sold'
            : property.availabilityStatus == 'rented'
                ? 'Rented'
                : 'Saved';

    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PropertyDetailScreen(property: property),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: image.isEmpty
                    ? Container(
                        width: 96,
                        height: 112,
                        color: AppTheme.bgSurface,
                        child: Icon(
                          CupertinoIcons.building_2_fill,
                          color: AppTheme.textMuted,
                        ),
                      )
                    : Image.network(
                        image,
                        width: 96,
                        height: 112,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 96,
                          height: 112,
                          color: AppTheme.bgSurface,
                          child: Icon(
                            CupertinoIcons.building_2_fill,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            property.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (property.saved)
                          IconButton(
                            tooltip: 'Remove saved property',
                            onPressed: onRemove,
                            icon: const Icon(
                              CupertinoIcons.bookmark_fill,
                              size: 18,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    Text(
                      '${property.heroLocation} · $intent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      property.rentLabel,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _DetailChip(
                          property.isLand
                              ? property.standSummary
                              : '${property.bedrooms} bd',
                        ),
                        _DetailChip(
                          property.isLand
                              ? property.landSizeLabel
                              : '${property.bathrooms} ba',
                        ),
                        _DetailChip(lifecycle),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
