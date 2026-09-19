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
  String _type = 'Popular';
  bool _mapMode = false;

  static const _primary = Color(0xFF6C4CF1);
  static const _primarySoft = Color(0xFFEDE9FE);
  static const _searchFill = Color(0xFFF4F2FB);
  static const _textDark = Color(0xFF1E1B2E);
  static const _textMuted = Color(0xFF8A8A9E);

  static const _types = ['Popular', 'Nearby', 'Recommended'];

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
      return matchesQuery;
    }).toList();

    return LoadingOverlay(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Top bar: avatar + greeting + bell ───
                    Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _primarySoft,
                          ),
                          child: const Icon(UniconsLine.user,
                              color: _primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Good Evening!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _textMuted,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Isabella Chen',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _textDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _NotificationButton(state: state),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ─── Search bar + filter button ───
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: _searchFill,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                    color: _textMuted, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      hintText: 'Food, Groceries, Drinks etc.',
                                      hintStyle: TextStyle(
                                        color: _textMuted,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: _textDark,
                                    ),
                                    onChanged: (v) =>
                                        setState(() => _query = v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => _showTrustCenter(context, state),
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.tune,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ─── Pill tabs ───
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _types.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final type = _types[index];
                          final selected = _type == type;
                          return GestureDetector(
                            onTap: () => setState(() => _type = type),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? _primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Center(
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: selected ? Colors.white : _textDark,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
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

  void _showTrustCenter(BuildContext context, Property24State state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
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

// ─────────────────────────────────────────────────────────────
// Notification bell button (circular, white, shadowed)
// ─────────────────────────────────────────────────────────────
class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            builder: (context) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1B2E),
                    ),
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
          label: Text(
            '${state.notifications.length}',
            style: const TextStyle(fontSize: 10),
          ),
          child:
              const Icon(UniconsLine.bell, color: Color(0xFF1E1B2E), size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Trust strip (kept, restyled)
// ─────────────────────────────────────────────────────────────
class _TrustStrip extends StatelessWidget {
  const _TrustStrip({required this.verified, required this.total});

  final int verified;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF6C4CF1)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$verified of $total homes verified',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E1B2E),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Map explorer (restyled)
// ─────────────────────────────────────────────────────────────
class _MapExplorer extends StatelessWidget {
  const _MapExplorer({required this.properties, required this.onOpen});

  final List<PropertyListing> properties;
  final ValueChanged<PropertyListing> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 360,
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                    painter: _MapLinesPainter(
                        const Color(0xFF6C4CF1).withOpacity(0.15))),
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
            leading: const Icon(Icons.location_on_outlined,
                color: Color(0xFF6C4CF1)),
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
                ? const Color(0xFF19B66A)
                : const Color(0xFF6C4CF1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            property.monthlyRentValue > 0
                ? '\$${property.monthlyRentValue.round()}'
                : 'Home',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
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

// ─────────────────────────────────────────────────────────────
// Comparison tray (restyled)
// ─────────────────────────────────────────────────────────────
class _ComparisonTray extends StatelessWidget {
  const _ComparisonTray({required this.properties, required this.onClear});

  final List<PropertyListing> properties;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Compare homes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1B2E),
                  ),
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    color: Color(0xFF6C4CF1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
                      color: const Color(0xFFF4F2FB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(property.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E1B2E),
                            )),
                        const SizedBox(height: 6),
                        Text(property.rentLabel,
                            style: const TextStyle(
                              color: Color(0xFF6C4CF1),
                              fontWeight: FontWeight.w700,
                            )),
                        Text('${property.trustScore}% trust',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8A8A9E),
                            )),
                        Text(
                            '${property.bedrooms} bed · ${property.bathrooms} bath',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8A8A9E),
                            )),
                      ],
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

class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle_outline, color: Color(0xFF6C4CF1)),
      title: Text(label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E1B2E),
          )),
      subtitle: Text(value),
    );
  }
}
