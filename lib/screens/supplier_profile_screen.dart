import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class SupplierProfileScreen extends StatelessWidget {
  const SupplierProfileScreen({
    required this.supplier,
    super.key,
  });

  final AccountUser supplier;

  @override
  Widget build(BuildContext context) {
    final listings = context
        .watch<Property24State>()
        .snapshot
        .properties
        .where((property) =>
            property.owner?.id == supplier.id ||
            property.agent?.id == supplier.id)
        .toList(growable: false);
    final photos = listings
        .expand((property) => property.photos)
        .where((photo) => photo.trim().isNotEmpty)
        .take(9)
        .toList(growable: false);
    final initials = _initials(supplier.name);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            supplier.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (supplier.verified) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_rounded,
                            color: AppTheme.accent,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'More',
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accentTeal],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.bgSurface,
                          backgroundImage: supplier.profilePicture.isNotEmpty
                              ? NetworkImage(supplier.profilePicture)
                              : null,
                          child: supplier.profilePicture.isNotEmpty
                              ? null
                              : Text(
                                  initials,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      _Stat(value: '${listings.length}', label: 'Posts'),
                      const _StatDivider(),
                      _Stat(
                        value:
                            '${listings.where((item) => item.verified).length}',
                        label: 'Verified',
                      ),
                      const _StatDivider(),
                      _Stat(
                        value:
                            '${listings.fold<int>(0, (total, item) => total + item.savedCount)}',
                        label: 'Saved',
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    [supplier.role.label, supplier.email]
                        .where((value) => value.trim().isNotEmpty)
                        .join(' at '),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (supplier.bio.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      supplier.bio.trim(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const Text('Follow'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const Text('Chat'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const Text('Contacts'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Row(
                    children: [
                      Expanded(
                        child: _ProfileTab(
                          icon: Icons.view_list_rounded,
                          label: 'POSTS',
                          selected: true,
                        ),
                      ),
                      Expanded(
                        child: _ProfileTab(
                          icon: Icons.attach_money_rounded,
                          label: 'SALE',
                        ),
                      ),
                      Expanded(
                        child: _ProfileTab(
                          icon: Icons.search_rounded,
                          label: 'RENT',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: photos.isEmpty ? listings.length : photos.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemBuilder: (context, index) {
                      final image = photos.isEmpty
                          ? (listings[index].photos.isEmpty
                              ? ''
                              : listings[index].photos.first)
                          : photos[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: image.isEmpty
                            ? Container(
                                color: AppTheme.bgSurface,
                                child: const Icon(
                                  Icons.home_work_outlined,
                                  color: AppTheme.textMuted,
                                ),
                              )
                            : Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.bgSurface,
                                  child: const Icon(
                                    Icons.home_work_outlined,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'P';
    return parts
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: AppTheme.border,
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppTheme.textPrimary),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 2,
          width: double.infinity,
          color: selected ? AppTheme.accent : AppTheme.border,
        ),
      ],
    );
  }
}
