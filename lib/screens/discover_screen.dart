import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'activity_screen.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/async_value_view.dart';
import '../widgets/property_card.dart';
import 'ai_search_screen.dart';
import 'property_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  String _type = 'Popular';
  bool _mapMode = false;

  static const _primary = AppTheme.accent;
  static Color get _primarySoft => AppTheme.bgSurface;
  static Color get _searchFill => AppTheme.bgSurface;
  static Color get _textDark => AppTheme.textPrimary;
  static Color get _textMuted => AppTheme.textMuted;

  static const _types = ['Popular', 'Nearby', 'Recommended'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    if (state.user?.role == AccountRole.landlord) {
      return const ActivityScreen();
    }
    final displayName = state.user?.name.trim() ?? '';
    final properties = state.snapshot.properties.where((property) {
      final haystack = [
        property.title,
        property.address,
        property.city,
        property.suburb,
        property.propertyType,
        property.description,
        property.rentLabel,
        property.waterAvailability,
        property.parking,
        '${property.bedrooms} bedrooms',
        property.borehole ? 'borehole' : '',
        property.solarPower ? 'solar' : '',
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
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _primarySoft,
                          ),
                          child: Icon(CupertinoIcons.person,
                              color: _primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                            decoration: BoxDecoration(
                              color: _searchFill,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              textInputAction: TextInputAction.search,
                              style: TextStyle(
                                color: _textDark,
                                fontSize: 13.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search homes, suburbs, or types',
                                hintStyle: TextStyle(
                                  color: _textMuted,
                                  fontSize: 13.5,
                                ),
                                prefixIcon: Icon(
                                  CupertinoIcons.search,
                                  color: _textMuted,
                                  size: 20,
                                ),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: _searchController.clear,
                                        icon: Icon(
                                          CupertinoIcons.xmark,
                                          color: _textMuted,
                                          size: 18,
                                        ),
                                      ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: 'AI property matching',
                          onPressed: _openAiSearch,
                          style: IconButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            fixedSize: const Size.square(50),
                          ),
                          icon: const Icon(CupertinoIcons.lightbulb),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => _showTrustCenter(context, state),
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CupertinoIcons.slider_horizontal_3,
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
              SliverFillRemaining(
                child: EmptyState(
                  icon: CupertinoIcons.search,
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

  Future<void> _openAiSearch() async {
    final query = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => AiSearchScreen(
          initialQuery: _query,
          searchScope: 'discover',
        ),
      ),
    );
    if (!mounted || query == null) return;
    _searchController.text = query;
    setState(() => _query = query);
  }

  void _showTrustCenter(BuildContext context, Property24State state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
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
        color: AppTheme.bgCard,
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
        onPressed: () => _openNotificationPanel(context, state),
        icon: Badge(
          isLabelVisible: state.unreadNotificationCount > 0,
          backgroundColor: AppTheme.accent,
          textColor: Colors.white,
          label: Text(
            '${state.unreadNotificationCount}',
            style: TextStyle(fontSize: 10),
          ),
          child: Icon(
            CupertinoIcons.bell,
            color: AppTheme.textPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

void _openNotificationPanel(BuildContext context, Property24State state) {
  final width = MediaQuery.sizeOf(context).width;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withAlpha(71),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: SafeArea(
          left: false,
          child: Material(
            color: AppTheme.bgCard,
            elevation: 12,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(24),
            ),
            child: SizedBox(
              width: width < 560 ? width * 0.92 : 440,
              height: double.infinity,
              child: ListenableBuilder(
                listenable: state,
                builder: (_, __) => _NotificationPanel(state: state),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mark all as read',
                  onPressed: state.unreadNotificationCount == 0
                      ? null
                      : () async {
                          try {
                            await state.markAllNotificationsRead();
                          } catch (exception) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(userFacingError(exception))),
                              );
                            }
                          }
                        },
                  icon: Icon(CupertinoIcons.checkmark_circle),
                ),
                IconButton(
                  tooltip: 'Clear all notifications',
                  onPressed: state.allNotifications.isEmpty
                      ? null
                      : () => _clearAll(context),
                  icon: Icon(CupertinoIcons.trash),
                ),
                IconButton(
                  tooltip: 'Close notifications',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(CupertinoIcons.xmark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: state.allNotifications.isEmpty
                  ? Center(
                      child: Text(
                        'No new notifications',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: state.allNotifications.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: AppTheme.border),
                      itemBuilder: (context, index) {
                        final notification = state.allNotifications[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            notification.isRead
                                ? CupertinoIcons.bell
                                : CupertinoIcons.bell_fill,
                            color: notification.isRead
                                ? AppTheme.textMuted
                                : AppTheme.accent,
                          ),
                          title: Text(
                            notification.message,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: notification.isRead
                                  ? FontWeight.w400
                                  : FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            notification.createdAt,
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!notification.isRead)
                                IconButton(
                                  tooltip: 'Mark as read',
                                  onPressed: () => _markAsRead(
                                    context,
                                    notification.id,
                                  ),
                                  icon: Icon(
                                    CupertinoIcons.checkmark_circle,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Clear notification',
                                onPressed: () => _clearOne(
                                  context,
                                  notification.id,
                                ),
                                icon: Icon(
                                  CupertinoIcons.trash,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsRead(BuildContext context, String notificationId) async {
    try {
      await state.markNotificationRead(notificationId);
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }

  Future<void> _clearOne(BuildContext context, String notificationId) async {
    try {
      await state.clearNotification(notificationId);
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear notifications?'),
        content:
            const Text('All notifications will be removed from this area.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await state.clearAllNotifications();
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
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
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                    painter:
                        _MapLinesPainter(AppTheme.accent.withOpacity(0.15))),
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
                  icon: Icon(CupertinoIcons.location_north),
                  label: Text('Open directions handoff'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final property in properties.take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(CupertinoIcons.location, color: AppTheme.accent),
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
            color: property.verified ? AppTheme.trustHigh : AppTheme.accent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            property.monthlyRentValue > 0
                ? '\$${property.monthlyRentValue.round()}'
                : 'Home',
            style: TextStyle(
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
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Compare homes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: AppTheme.accent,
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
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(property.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            )),
                        const SizedBox(height: 6),
                        Text(property.rentLabel,
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w700,
                            )),
                        Text('${property.trustScore}% trust',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            )),
                        Text(
                          property.isLand
                              ? '${property.landSizeLabel} · ${property.standSummary}'
                              : '${property.bedrooms} bed · ${property.bathrooms} bath',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
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
      leading: Icon(CupertinoIcons.checkmark_circle, color: AppTheme.accent),
      title: Text(label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          )),
      subtitle: Text(value),
    );
  }
}
