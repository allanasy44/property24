import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SavedHomesScreen extends StatefulWidget {
  const SavedHomesScreen({super.key});

  @override
  State<SavedHomesScreen> createState() => _SavedHomesScreenState();
}

class _SavedHomesScreenState extends State<SavedHomesScreen> {
  static const Color bg = Color(0xFF0E0E0E);
  static const Color green = Color(0xFF2E7D5B);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF7A7A7A);
  static const Color card = Color(0xFFF5F1EA);

  _SavedFilter _filter = _SavedFilter.all;

  // ── Saved / reserved properties only ──
  final List<_SavedHome> _homes = const [
    // ── FOR SALE ──
    _SavedHome(
      id: 'sale_1',
      title: 'Colony, New Mexico 90210',
      subtitle: 'Millsboro-DE',
      price: '\$1,435,000',
      listing: _ListingType.sale,
      state: _SaveState.saved,
      imageUrl:
          'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400',
      beds: 4,
      baths: 3,
      area: '3,200 sqft',
    ),
    _SavedHome(
      id: 'sale_2',
      title: 'Sunset Ridge',
      subtitle: 'Millsboro-DE',
      price: '\$2,150,000',
      listing: _ListingType.sale,
      state: _SaveState.reserved,
      imageUrl:
          'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=400',
      beds: 5,
      baths: 4,
      area: '4,100 sqft',
    ),
    _SavedHome(
      id: 'sale_3',
      title: 'Willow Creek',
      subtitle: 'Millsboro-DE',
      price: '\$980,000',
      listing: _ListingType.sale,
      state: _SaveState.saved,
      imageUrl:
          'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=400',
      beds: 3,
      baths: 2,
      area: '2,400 sqft',
    ),

    // ── FOR RENT ──
    _SavedHome(
      id: 'rent_1',
      title: 'Hillcrest Rentals',
      subtitle: 'Millsboro-DE',
      price: '\$1,032,000',
      listing: _ListingType.rent,
      state: _SaveState.saved,
      imageUrl:
          'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=400',
      beds: 2,
      baths: 2,
      area: '1,200 sqft',
    ),
    _SavedHome(
      id: 'rent_2',
      title: 'Maple Grove Apartments',
      subtitle: 'Millsboro-DE',
      price: '\$1,205,000',
      listing: _ListingType.rent,
      state: _SaveState.reserved,
      imageUrl:
          'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400',
      beds: 3,
      baths: 2,
      area: '1,650 sqft',
    ),
  ];

  List<_SavedHome> get _forSale =>
      _homes.where((h) => h.listing == _ListingType.sale).toList();

  List<_SavedHome> get _forRent =>
      _homes.where((h) => h.listing == _ListingType.rent).toList();

  @override
  Widget build(BuildContext context) {
    final showSale =
        _filter == _SavedFilter.all || _filter == _SavedFilter.sale;
    final showRent =
        _filter == _SavedFilter.all || _filter == _SavedFilter.rent;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: CupertinoIcons.back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Saved & Reserved',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Filter chips ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == _SavedFilter.all,
                    onTap: () => setState(() => _filter = _SavedFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'For Sale',
                    selected: _filter == _SavedFilter.sale,
                    onTap: () => setState(() => _filter = _SavedFilter.sale),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'For Rent',
                    selected: _filter == _SavedFilter.rent,
                    onTap: () => setState(() => _filter = _SavedFilter.rent),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                physics: const BouncingScrollPhysics(),
                children: [
                  if (showSale && _forSale.isNotEmpty) ...[
                    const _SectionLabel('Saved & Reserved · For Sale'),
                    const SizedBox(height: 12),
                    ..._forSale.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _HomeCard(
                          home: h,
                          onTap: () => _openDetail(context, h),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (showRent && _forRent.isNotEmpty) ...[
                    const _SectionLabel('Saved & Reserved · For Rent'),
                    const SizedBox(height: 12),
                    ..._forRent.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _HomeCard(
                          home: h,
                          onTap: () => _openDetail(context, h),
                        ),
                      ),
                    ),
                  ],
                  if ((showSale ? _forSale : const []).isEmpty &&
                      (showRent ? _forRent : const []).isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'Nothing saved or reserved yet.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Color(0xFF7A7A7A),
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

  void _openDetail(BuildContext context, _SavedHome home) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SavedHomeDetailSheet(home: home),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  MODELS
// ═════════════════════════════════════════════════════════════
enum _ListingType { sale, rent }

enum _SaveState { saved, reserved }

enum _SavedFilter { all, sale, rent }

class _SavedHome {
  const _SavedHome({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.listing,
    required this.state,
    required this.imageUrl,
    required this.beds,
    required this.baths,
    required this.area,
  });

  final String id;
  final String title;
  final String subtitle;
  final String price;
  final _ListingType listing;
  final _SaveState state;
  final String imageUrl;
  final int beds;
  final int baths;
  final String area;
}

// ═════════════════════════════════════════════════════════════
//  SECTION LABEL
// ═════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Color(0xFF7A7A7A),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  FILTER CHIP
// ═════════════════════════════════════════════════════════════
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _SavedHomesScreenState.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _SavedHomesScreenState.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  HOME CARD
// ═════════════════════════════════════════════════════════════
class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.home, required this.onTap});

  final _SavedHome home;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isReserved = home.state == _SaveState.reserved;
    final listingLabel =
        home.listing == _ListingType.sale ? 'For Sale' : 'For Rent';

    return Material(
      color: _SavedHomesScreenState.card,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
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
                child: Stack(
                  children: [
                    Image.network(
                      home.imageUrl,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 96,
                        height: 96,
                        color: const Color(0xFFE0DACF),
                        child: const Icon(
                          CupertinoIcons.house,
                          color: Color(0xFF7A7A7A),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isReserved
                              ? _SavedHomesScreenState.green
                              : Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isReserved ? 'Reserved' : 'Saved',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      home.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: _SavedHomesScreenState.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${home.subtitle} · $listingLabel',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: _SavedHomesScreenState.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: home.price,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _SavedHomesScreenState.green,
                            ),
                          ),
                          TextSpan(
                            text: home.listing == _ListingType.rent
                                ? '/month'
                                : '',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _SavedHomesScreenState.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Chip(
                          icon: CupertinoIcons.bed_double,
                          label: '${home.beds} bd',
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          icon: CupertinoIcons.drop,
                          label: '${home.baths} ba',
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          icon: CupertinoIcons.square_grid_2x2,
                          label: home.area,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_up_right,
                  size: 16,
                  color: _SavedHomesScreenState.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0DACF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _SavedHomesScreenState.textSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _SavedHomesScreenState.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  BACK BUTTON
// ═════════════════════════════════════════════════════════════
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
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
          width: 42,
          height: 42,
          child:
              Icon(icon, size: 18, color: _SavedHomesScreenState.textPrimary),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  DETAIL SHEET
// ═════════════════════════════════════════════════════════════
class _SavedHomeDetailSheet extends StatelessWidget {
  const _SavedHomeDetailSheet({required this.home});
  final _SavedHome home;

  String get listingLabel =>
      home.listing == _ListingType.sale ? 'For Sale' : 'For Rent';

  String get saveLabel =>
      home.state == _SaveState.reserved ? 'Reserved' : 'Saved';

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
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                home.imageUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: const Color(0xFFE0DACF),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: home.state == _SaveState.reserved
                    ? _SavedHomesScreenState.green
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                saveLabel,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              home.title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _SavedHomesScreenState.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${home.subtitle} · $listingLabel',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: _SavedHomesScreenState.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _SavedHomesScreenState.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoBlock(
                      label: 'Price',
                      value: home.listing == _ListingType.rent
                          ? '${home.price}/mo'
                          : home.price,
                      valueColor: _SavedHomesScreenState.green,
                    ),
                  ),
                  Expanded(
                    child: _InfoBlock(
                      label: 'Listing',
                      value: listingLabel,
                      valueColor: _SavedHomesScreenState.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: _InfoBlock(
                      label: 'Beds · Baths',
                      value: '${home.beds} · ${home.baths}',
                      valueColor: _SavedHomesScreenState.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _SavedHomesScreenState.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.square_grid_2x2,
                      size: 18, color: _SavedHomesScreenState.green),
                  const SizedBox(width: 10),
                  Text(
                    home.area,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _SavedHomesScreenState.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _SavedHomesScreenState.green,
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
}

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
            color: _SavedHomesScreenState.textSecondary,
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
