import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const Color bg = Color(0xFF0E0E0E);
  static const Color green = Color(0xFF2E7D5B);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF7A7A7A);
  static const Color card = Color(0xFFF5F1EA);

  final MapController _mapController = MapController();

  static const LatLng center = LatLng(38.6901, -75.1513);

  int selectedNav = 1;

  final List<_PropertyPin> pins = const [
    _PropertyPin(
      id: '1',
      price: '\$1,032,000',
      position: LatLng(38.6930, -75.1460),
      highlighted: false,
      listing: _ListingType.rent,
    ),
    _PropertyPin(
      id: '2',
      price: '\$1,205,000',
      position: LatLng(38.6870, -75.1560),
      highlighted: false,
      listing: _ListingType.rent,
    ),
    _PropertyPin(
      id: '3',
      price: '\$1,375,000',
      position: LatLng(38.6910, -75.1430),
      highlighted: false,
      listing: _ListingType.sale,
    ),
    _PropertyPin(
      id: '4',
      price: '\$1,435,000',
      position: LatLng(38.6880, -75.1495),
      highlighted: true,
      listing: _ListingType.rent,
    ),
    _PropertyPin(
      id: '5',
      price: 'Open',
      position: LatLng(38.6895, -75.1520),
      highlighted: false,
      listing: _ListingType.openLandlord,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yourcompany.property24',
                  ),
                  MarkerLayer(
                    markers: pins.map((pin) {
                      return Marker(
                        point: pin.position,
                        width: 120,
                        height: 60,
                        child: GestureDetector(
                          onTap: () {
                            _openPropertySheet(context, pin);
                          },
                          child: _PricePin(
                            price: pin.price,
                            highlighted: pin.highlighted,
                            listing: pin.listing,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // SEARCH
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  const _CircleBackButton(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(
                            CupertinoIcons.search,
                            size: 20,
                            color: textPrimary,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Millsboro, DE',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _mapController.move(
                                center,
                                15,
                              );
                            },
                            icon: const Icon(
                              CupertinoIcons.location,
                              size: 20,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ZOOM
            Positioned(
              right: 16,
              top: 300,
              child: Column(
                children: [
                  _ZoomButton(
                    icon: CupertinoIcons.plus,
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;

                      _mapController.move(
                        _mapController.camera.center,
                        currentZoom + 1,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _ZoomButton(
                    icon: CupertinoIcons.minus,
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;

                      _mapController.move(
                        _mapController.camera.center,
                        currentZoom - 1,
                      );
                    },
                  ),
                ],
              ),
            ),

            // PROPERTY CARD
            Positioned(
              left: 16,
              right: 16,
              bottom: 90,
              child: _PropertyCard(
                title: 'Colony, New\nMexico 90210',
                subtitle: 'Millsboro-DE',
                price: '\$1,435,000',
                priceSuffix: '/month',
                imageUrl:
                    'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400',
                onTap: () {
                  _openPropertySheet(context, pins[3]);
                },
              ),
            ),

            // NAV
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomNav(
                selected: selectedNav,
                onSelect: (index) {
                  setState(() {
                    selectedNav = index;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPropertySheet(
    BuildContext context,
    _PropertyPin pin,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {
        return _PropertyDetailSheet(pin: pin);
      },
    );
  }
}

// ============================================================
// PROPERTY PIN
// ============================================================

enum _ListingType {
  rent,
  sale,
  openLandlord,
}

class _PropertyPin {
  const _PropertyPin({
    required this.id,
    required this.price,
    required this.position,
    required this.highlighted,
    required this.listing,
  });

  final String id;
  final String price;
  final LatLng position;
  final bool highlighted;
  final _ListingType listing;
}

class _PricePin extends StatelessWidget {
  const _PricePin({
    required this.price,
    required this.highlighted,
    required this.listing,
  });

  final String price;
  final bool highlighted;
  final _ListingType listing;

  Color get backgroundColor {
    if (listing == _ListingType.openLandlord) {
      return const Color(0xFF1A1A1A);
    }

    return highlighted ? const Color(0xFF2E7D5B) : Colors.white;
  }

  Color get foregroundColor {
    if (listing == _ListingType.openLandlord) {
      return Colors.white;
    }

    return highlighted ? Colors.white : const Color(0xFF1A1A1A);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: listing == _ListingType.openLandlord
            ? Border.all(
                color: const Color(0xFF2E7D5B),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (listing == _ListingType.openLandlord) ...[
            const Icon(
              CupertinoIcons.add,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            price,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ZOOM BUTTON
// ============================================================

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BACK BUTTON
// ============================================================

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).maybePop();
        },
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            CupertinoIcons.back,
            size: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PROPERTY CARD
// ============================================================

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.priceSuffix,
    required this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final String priceSuffix;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F1EA),
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  imageUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      width: 90,
                      height: 90,
                      color: const Color(0xFFE0DACF),
                      child: const Icon(
                        CupertinoIcons.house,
                        color: Color(0xFF7A7A7A),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFF7A7A7A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E7D5B),
                            ),
                          ),
                          TextSpan(
                            text: priceSuffix,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2E7D5B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_up_right,
                  size: 18,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOTTOM NAV
// ============================================================

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selected,
    required this.onSelect,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: CupertinoIcons.house,
            selected: selected == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: CupertinoIcons.search,
            selected: selected == 1,
            onTap: () => onSelect(1),
          ),
          _NavItem(
            icon: CupertinoIcons.heart,
            selected: selected == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            icon: CupertinoIcons.chat_bubble,
            selected: selected == 3,
            onTap: () => onSelect(3),
          ),
          _NavItem(
            icon: CupertinoIcons.person,
            selected: selected == 4,
            onTap: () => onSelect(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF2E7D5B) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            if (selected)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D5B),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROPERTY DETAIL SHEET
// ============================================================

class _PropertyDetailSheet extends StatelessWidget {
  const _PropertyDetailSheet({
    required this.pin,
  });

  final _PropertyPin pin;

  String get listingLabel {
    switch (pin.listing) {
      case _ListingType.rent:
        return 'For Rent';

      case _ListingType.sale:
        return 'For Sale';

      case _ListingType.openLandlord:
        return 'Open · Landlord slot';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Colony, New Mexico 90210',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Millsboro-DE',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Color(0xFF7A7A7A),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F1EA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoBlock(
                      label: 'Price',
                      value: pin.price == 'Open' ? 'Open' : '${pin.price}/mo',
                      valueColor: const Color(0xFF2E7D5B),
                    ),
                  ),
                  Expanded(
                    child: _InfoBlock(
                      label: 'Listing',
                      value: listingLabel,
                      valueColor: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const Expanded(
                    child: _InfoBlock(
                      label: 'Type',
                      value: 'House',
                      valueColor: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Listed by',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A7A7A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(
                    'https://i.pravatar.cc/150?img=12',
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marcus Whitfield',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        'Landlord · Verified',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF7A7A7A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D5B),
                  ),
                  onPressed: () {},
                  icon: const Icon(
                    CupertinoIcons.phone,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () {},
                  icon: const Icon(
                    CupertinoIcons.chat_bubble,
                    size: 18,
                    color: Color(0xFF2E7D5B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Get there',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A7A7A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TravelCard(
                    icon: CupertinoIcons.car,
                    mode: 'Drive',
                    time: '12 min',
                    distance: '6.4 km',
                    onTap: () {
                      _openDirections(
                        context,
                        pin.position,
                        'driving',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TravelCard(
                    icon: CupertinoIcons.location,
                    mode: 'Walk',
                    time: '58 min',
                    distance: '6.4 km',
                    onTap: () {
                      _openDirections(
                        context,
                        pin.position,
                        'walking',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TravelCard(
                    icon: CupertinoIcons.bus,
                    mode: 'Transit',
                    time: '24 min',
                    distance: '6.4 km',
                    onTap: () {
                      _openDirections(
                        context,
                        pin.position,
                        'transit',
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Also for sale nearby',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A7A7A),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _MiniListing(
                    title: 'Sunset Ridge',
                    price: '\$2,150,000',
                    imageUrl:
                        'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400',
                  ),
                  SizedBox(width: 10),
                  _MiniListing(
                    title: 'Willow Creek',
                    price: '\$980,000',
                    imageUrl:
                        'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=400',
                  ),
                  SizedBox(width: 10),
                  _MiniListing(
                    title: 'Hillcrest',
                    price: '\$1,320,000',
                    imageUrl:
                        'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=400',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D5B),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {},
              icon: const Icon(
                CupertinoIcons.chat_bubble_text,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Contact landlord',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openDirections(
    BuildContext context,
    LatLng destination,
    String travelMode,
  ) {
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&destination=${destination.latitude},'
        '${destination.longitude}'
        '&travelmode=$travelMode';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(url),
      ),
    );
  }
}

// ============================================================
// INFO BLOCK
// ============================================================

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7A7A7A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TRAVEL CARD
// ============================================================

class _TravelCard extends StatelessWidget {
  const _TravelCard({
    required this.icon,
    required this.mode,
    required this.time,
    required this.distance,
    required this.onTap,
  });

  final IconData icon;
  final String mode;
  final String time;
  final String distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F1EA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 8,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: const Color(0xFF2E7D5B),
              ),
              const SizedBox(height: 6),
              Text(
                mode,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A7A7A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                distance,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: Color(0xFF7A7A7A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MINI LISTING
// ============================================================

class _MiniListing extends StatelessWidget {
  const _MiniListing({
    required this.title,
    required this.price,
    required this.imageUrl,
  });

  final String title;
  final String price;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1EA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
            child: Image.network(
              imageUrl,
              width: 160,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  width: 160,
                  height: 80,
                  color: const Color(0xFFE0DACF),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  price,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D5B),
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
