import 'package:flutter/material.dart';
import 'package:unicons/unicons.dart';

import '../models/rental_models.dart';

// Local palette (keeps this file self-contained)
class _C {
  static const primary = Color(0xFF6C4CF1);
  static const primarySoft = Color(0xFFEDE9FE);
  static const searchFill = Color(0xFFF4F2FB);
  static const textDark = Color(0xFF1E1B2E);
  static const textMuted = Color(0xFF8A8A9E);
}

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
    final p = widget.property;
    final photos = p.photos.isEmpty ? <String>[''] : p.photos;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(UniconsLine.arrow_left, color: _C.textDark),
                  ),
                  Expanded(
                    child: Text(
                      p.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(UniconsLine.share_alt, color: _C.textDark),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Image carousel
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Stack(
                          children: [
                            PageView.builder(
                              itemCount: photos.length,
                              onPageChanged: (i) => setState(() => _page = i),
                              itemBuilder: (_, i) => photos[i].isEmpty
                                  ? Container(
                                      color: _C.searchFill,
                                      child: const Icon(Icons.home_outlined,
                                          size: 60, color: _C.textMuted),
                                    )
                                  : Image.network(photos[i], fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setState(() => _saved = !_saved),
                                child: Container(
                                  height: 36,
                                  width: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _saved
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 18,
                                    color: _saved ? _C.primary : _C.textDark,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(photos.length, (i) {
                                  final active = i == _page;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    height: 6,
                                    width: active ? 18 : 6,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? _C.primary
                                          : Colors.white.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _C.textDark,
                            )),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 15, color: _C.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                p.heroLocation,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _C.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Info chips
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _C.primarySoft,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(children: [
                            _InfoChip(
                                icon: UniconsLine.bed,
                                label: '${p.bedrooms} bhk'),
                            _divider(),
                            _InfoChip(
                                icon: Icons.square_foot,
                                label: '${(p.bathrooms * 500).round()} sq ft'),
                            _divider(),
                            _InfoChip(
                                icon: Icons.weekend_outlined,
                                label:
                                    p.furnished ? 'Furnished' : 'Unfurnished'),
                          ]),
                        ),
                        const SizedBox(height: 22),

                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Price : ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: _C.textDark,
                                ),
                              ),
                              TextSpan(
                                text: p.rentLabel,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _C.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        const Text('Description',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _C.textDark,
                            )),
                        const SizedBox(height: 8),
                        Text(
                          p.description.isEmpty
                              ? 'No description provided.'
                              : p.description,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color: _C.textMuted,
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(UniconsLine.phone,
                          color: _C.primary, size: 18),
                      label: const Text('Call',
                          style: TextStyle(
                              color: _C.primary, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: _C.primary.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(UniconsLine.comment_message,
                          color: Colors.white, size: 18),
                      label: const Text('Message',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
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

  Widget _divider() => Container(
        width: 1,
        height: 30,
        color: _C.primary.withOpacity(0.15),
      );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: _C.primary, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _C.textDark,
              )),
        ],
      ),
    );
  }
}
