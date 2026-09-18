import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:unicons/unicons.dart';

import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../state/property24_state.dart';
import '../widgets/async_value_view.dart';
import '../widgets/property_card.dart';
import 'property_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _query = '';
  String _type = 'All';
  bool _mapMode = false;

  static const _types = [
    'All',
    'House',
    'Flat',
    'Cottage',
    'Student Accommodation',
    'Commercial Property',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final properties = state.snapshot.properties.where((property) {
      final haystack = [
        property.title,
        property.address,
        property.city,
        property.suburb,
        property.propertyType,
      ].join(' ').toLowerCase();
      final matchesQuery =
          _query.trim().isEmpty || haystack.contains(_query.toLowerCase());
      final matchesType = _type == 'All' ||
          property.propertyType.toLowerCase() == _type.toLowerCase();
      return matchesQuery && matchesType;
    }).toList();
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return LoadingOverlay(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NotificationButton(state: state),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hi, find your dream home',
                                  style: textTheme.headlineSmall),
                              const SizedBox(height: 4),
                              Text(
                                'Verified rentals, real costs, lifestyle fit, and direct contact.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tooltip(
                          message: 'Trust center',
                          child: IconButton.filledTonal(
                            onPressed: () => _showTrustCenter(context, state),
                            icon: const Icon(UniconsLine.shield_check),
                          ),
                        ),
                      ],
                    ),
                    if (state.canManageListings) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () =>
                            context.pushNamed(AppRoutes.listingsName),
                        icon: const Icon(UniconsLine.estate),
                        label: const Text('Manage listings'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SearchBar(
                      hintText: 'Search suburb, city, or property type',
                      leading: const Icon(Icons.search),
                      trailing: [
                        Tooltip(
                          message: 'Create smart alert',
                          child: IconButton(
                            onPressed: () => _saveAlert(context, state),
                            icon: const Icon(UniconsLine.bell),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _types.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final type = _types[index];
                          return ChoiceChip(
                            label: Text(type),
                            selected: _type == type,
                            onSelected: (_) => setState(() => _type = type),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _TrustStrip(
                            verified: state.verifiedProperties,
                            total: state.snapshot.properties.length,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              icon: Icon(Icons.view_agenda_outlined),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.map_outlined),
                            ),
                          ],
                          selected: {_mapMode},
                          showSelectedIcon: false,
                          onSelectionChanged: (value) {
                            setState(() => _mapMode = value.first);
                          },
                        ),
                      ],
                    ),
                    if (state.smartAlerts.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final alert in state.smartAlerts)
                            Chip(
                              avatar: const Icon(
                                  Icons.notifications_active_outlined,
                                  size: 16),
                              label: Text(alert),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: ErrorBanner()),
            if (properties.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.search_off,
                  title: 'No matching listings',
                  body: 'Try another suburb, city, or property type.',
                ),
              )
            else if (_mapMode)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _MapExplorer(
                    properties: properties,
                    onOpen: (property) => _openDetails(context, property),
                  ),
                ),
              )
            else ...[
              if (state.comparedProperties.isNotEmpty)
                SliverToBoxAdapter(
                  child: _ComparisonTray(
                    properties: state.comparedProperties,
                    onClear: () {
                      for (final property in state.comparedProperties) {
                        state.toggleComparison(property);
                      }
                    },
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.builder(
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final property = properties[index];
                    return PropertyCard(
                      property: property,
                      saved: state.savedPropertyIds.contains(property.id),
                      compared:
                          state.comparisonPropertyIds.contains(property.id),
                      onSave: () => state.toggleSaved(property),
                      onCompare: () => state.toggleComparison(property),
                      onTap: () => _openDetails(context, property),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, PropertyListing property) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyDetailScreen(property: property),
      ),
    );
  }

  void _saveAlert(BuildContext context, Property24State state) {
    final label = [
      if (_query.trim().isNotEmpty) _query.trim(),
      if (_type != 'All') _type,
      'verified rentals',
    ].join(' · ');
    state.addSmartAlert(label);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Smart alert saved: $label')),
    );
  }

  void _showTrustCenter(BuildContext context, Property24State state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trust center', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _TrustLine(
                label: 'Identity verified',
                value: '${state.verifiedProperties} listings'),
            _TrustLine(
                label: 'Contact verified', value: 'Phone and email ready'),
            _TrustLine(
                label: 'Authority verified', value: 'Owner or agent evidence'),
            _TrustLine(
                label: 'Property verified',
                value: 'Location and facts checked'),
            _TrustLine(
                label: 'Recently verified',
                value: 'Availability confirmation flow'),
          ],
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Notifications',
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final item in state.notifications)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(UniconsLine.bell),
                    title: Text(item),
                  ),
              ],
            ),
          ),
        );
      },
      icon: Badge(
        label: Text('${state.notifications.length}'),
        child: const Icon(UniconsLine.bell),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip({required this.verified, required this.total});

  final int verified;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$verified of $total homes verified',
              style: Theme.of(context).textTheme.labelLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapExplorer extends StatelessWidget {
  const _MapExplorer({required this.properties, required this.onOpen});

  final List<PropertyListing> properties;
  final ValueChanged<PropertyListing> onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          height: 360,
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xffe8f2ea),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                    painter: _MapLinesPainter(colorScheme.outlineVariant)),
              ),
              for (var index = 0; index < properties.take(5).length; index++)
                Positioned(
                  left: 28.0 + (index * 53) % 230,
                  top: 42.0 + (index * 71) % 240,
                  child: _MapPin(
                      property: properties[index],
                      onTap: () => onOpen(properties[index])),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Open directions handoff'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final property in properties.take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: Text(property.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(property.heroLocation),
            trailing: Text(property.rentLabel),
            onTap: () => onOpen(property),
          ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.property, required this.onTap});

  final PropertyListing property;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: property.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: property.verified
                ? const Color(0xff19b66a)
                : const Color(0xff12324a),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            property.monthlyRentValue > 0
                ? '\$${property.monthlyRentValue.round()}'
                : 'Home',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _MapLinesPainter extends CustomPainter {
  const _MapLinesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (i + 1) / 8;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y + (i.isEven ? 26 : -22)), paint);
    }
    for (var i = 0; i < 5; i++) {
      final x = size.width * (i + 1) / 6;
      canvas.drawLine(
          Offset(x, 0), Offset(x + (i.isEven ? 18 : -18), size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapLinesPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ComparisonTray extends StatelessWidget {
  const _ComparisonTray({required this.properties, required this.onClear});

  final List<PropertyListing> properties;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Compare homes',
                        style: Theme.of(context).textTheme.titleMedium)),
                TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final property in properties)
                    Container(
                      width: 172,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(property.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Text(property.rentLabel),
                          Text('${property.trustScore}% trust'),
                          Text(
                              '${property.bedrooms} bed · ${property.bathrooms} bath'),
                        ],
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
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle_outline),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
