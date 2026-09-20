import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/osm_map_preview.dart';
import 'supplier_profile_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({super.key, required this.property});

  final PropertyListing property;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  int _page = 0;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final photos = property.photos.isEmpty ? <String>[''] : property.photos;
    final amenities = _amenities(property);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroGallery(
                  photos: photos,
                  page: _page,
                  saved: _saved,
                  onPageChanged: (index) => setState(() => _page = index),
                  onBack: () => Navigator.pop(context),
                  onSave: () => setState(() => _saved = !_saved),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 112),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PriceHeader(property: property),
                      const SizedBox(height: 14),
                      _MetaLine(property: property),
                      const SizedBox(height: 14),
                      _GuestChips(property: property),
                      const SizedBox(height: 18),
                      OsmMapPreview(
                        label: property.heroLocation,
                        latitude: property.mapLatitude,
                        longitude: property.mapLongitude,
                        approximate: !property.showExactLocation,
                        zoom: property.showExactLocation ? 15 : 12,
                      ),
                      const SizedBox(height: 18),
                      const _DetailTabs(),
                      const SizedBox(height: 14),
                      if (property.description.trim().isNotEmpty)
                        Text(
                          property.description.trim(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                            height: 1.55,
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (amenities.isNotEmpty) ...[
                        const Text(
                          'What this house offers',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in amenities) _AmenityChip(item),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      _HostCard(property: property),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomActions(property: property),
          ),
        ],
      ),
    );
  }

  List<String> _amenities(PropertyListing property) {
    return [
      if (property.has360Tour) '360 tour',
      if (property.parking.trim().isNotEmpty) property.parking.trim(),
      if (property.waterAvailability.trim().isNotEmpty)
        property.waterAvailability.trim(),
      if (property.furnished) 'Furnished',
      if (property.solarPower) 'Solar power',
      if (property.borehole) 'Borehole',
      if (property.petFriendly) 'Pet friendly',
      property.propertyType,
    ].where((item) => item.trim().isNotEmpty).toSet().toList(growable: false);
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.photos,
    required this.page,
    required this.saved,
    required this.onPageChanged,
    required this.onBack,
    required this.onSave,
  });

  final List<String> photos;
  final int page;
  final bool saved;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: photos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final photo = photos[index];
              if (photo.isEmpty) {
                return Container(
                  color: AppTheme.bgSurface,
                  child: const Icon(
                    CupertinoIcons.house,
                    color: AppTheme.textMuted,
                    size: 56,
                  ),
                );
              }
              return Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.bgSurface,
                  child: const Icon(
                    CupertinoIcons.house,
                    color: AppTheme.textMuted,
                    size: 56,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 18,
            child: _CircleAction(
              icon: CupertinoIcons.chevron_left,
              tooltip: 'Back',
              onPressed: onBack,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            right: 18,
            child: Row(
              children: [
                _CircleAction(
                  icon: CupertinoIcons.share,
                  tooltip: 'Share',
                  onPressed: () {},
                ),
                const SizedBox(width: 10),
                _CircleAction(
                  icon:
                      saved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  tooltip: saved ? 'Remove saved home' : 'Save home',
                  onPressed: onSave,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < photos.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 5,
                    width: page == index ? 18 : 5,
                    decoration: BoxDecoration(
                      color: page == index ? Colors.white : Colors.white70,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withOpacity(0.32),
        foregroundColor: Colors.white,
        fixedSize: const Size.square(36),
        minimumSize: const Size.square(36),
      ),
      icon: Icon(icon, size: 19),
    );
  }
}

class _PriceHeader extends StatelessWidget {
  const _PriceHeader({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.rentLabel,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                property.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                property.heroLocation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const _HeaderIcon(icon: CupertinoIcons.clock),
        const _HeaderIcon(icon: CupertinoIcons.bookmark),
        const _HeaderIcon(icon: CupertinoIcons.location),
        const _HeaderIcon(icon: CupertinoIcons.heart),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(icon, size: 16, color: AppTheme.textSecondary),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${property.trustScore}% trust / ${property.moveInTotalLabel} move-in',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              CupertinoIcons.eye,
              size: 13,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              property.availabilityLabel,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GuestChips extends StatelessWidget {
  const _GuestChips({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Pill(icon: CupertinoIcons.person_2, label: property.propertyType),
        _Pill(icon: CupertinoIcons.drop, label: '${property.bathrooms} baths'),
        _Pill(
            icon: CupertinoIcons.bed_double,
            label: '${property.bedrooms} beds'),
      ],
    );
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs();

  @override
  Widget build(BuildContext context) {
    const tabs = ['Overview', 'Amenities', 'Reviews', 'Location'];
    return Row(
      children: [
        for (final tab in tabs)
          Expanded(
            child: Column(
              children: [
                Text(
                  tab,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tab == tabs.first
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight:
                        tab == tabs.first ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  width: 36,
                  color:
                      tab == tabs.first ? AppTheme.accent : Colors.transparent,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.check_mark,
              size: 13, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    final supplier = property.supplier;
    final name = supplier?.name.trim() ?? '';
    final role = supplier?.role.label ?? '';
    final initials = name.isEmpty
        ? 'P'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part.characters.first.toUpperCase())
            .join();

    return InkWell(
      onTap: supplier == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SupplierProfileScreen(supplier: supplier),
                ),
              ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: AppTheme.textPrimary,
              backgroundImage: supplier?.profilePicture.isNotEmpty == true
                  ? NetworkImage(supplier!.profilePicture)
                  : null,
              child: supplier?.profilePicture.isNotEmpty == true
                  ? null
                  : Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (role.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (supplier?.verified == true)
              const Icon(
                CupertinoIcons.checkmark_seal_fill,
                color: AppTheme.accent,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _holdAndOpenChat(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Message host'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => _holdAndOpenChat(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Reserve'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _holdAndOpenChat(BuildContext context) async {
    try {
      await context.read<Property24State>().holdProperty(property);
      if (context.mounted) context.go(AppRoutes.chatScreen);
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }
}
