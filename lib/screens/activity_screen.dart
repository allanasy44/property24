import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/async_value_view.dart';
import '../widgets/metric_tile.dart';
import 'inbox_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final isLandlord = state.user?.role == AccountRole.landlord;
    final greetingPrefix = greetingForTime();
    final userName = state.user?.name.trim() ?? '';
    final properties = state.snapshot.properties;
    final savedProperties = state.snapshot.savedProperties;
    final bookings = state.snapshot.viewings
        .where((item) => item.isAvailableBooking)
        .take(5)
        .toList(growable: false);
    final theme = Theme.of(context);
    final metrics = isLandlord
        ? <Widget>[
            MetricTile(
              icon: CupertinoIcons.house,
              label: 'Total listings',
              value: '${properties.length}',
            ),
            MetricTile(
              icon: CupertinoIcons.checkmark_seal,
              label: 'Verified',
              value: '${state.verifiedProperties}',
            ),
            MetricTile(
              icon: CupertinoIcons.person_2,
              label: 'Applications',
              value: '${state.snapshot.applications.length}',
            ),
          ]
        : <Widget>[
            MetricTile(
              icon: CupertinoIcons.heart,
              label: 'Saved homes',
              value: '${savedProperties.length}',
            ),
            MetricTile(
              icon: CupertinoIcons.doc_text,
              label: 'Applications',
              value: '${state.snapshot.applications.length}',
            ),
            MetricTile(
              icon: CupertinoIcons.calendar,
              label: 'Bookings',
              value: '${bookings.length}',
            ),
          ];

    return LoadingOverlay(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isLandlord)
                        Text(
                          'Home',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      Text(
                        greetingPrefix,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (userName.isNotEmpty)
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (!isLandlord) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Live updates from your applications, bookings, and home care.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                _LandlordNotificationButton(state: state),
              ],
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: metrics,
            ),
            const SizedBox(height: 18),
            const ErrorBanner(),
            if (isLandlord && state.user?.accountOnboardingComplete != true)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(
                    CupertinoIcons.lock_open,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Finish account verification'),
                  subtitle: const Text(
                    'Complete identity verification before publishing a listing.',
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_forward),
                  onTap: () => GoRouter.of(context).go(AppRoutes.profileScreen),
                ),
              ),
            const SizedBox(height: 18),
            if (isLandlord) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Portfolio', style: theme.textTheme.titleLarge),
                  TextButton.icon(
                    onPressed: () =>
                        GoRouter.of(context).go(AppRoutes.listingsScreen),
                    icon: const Icon(CupertinoIcons.arrow_right, size: 16),
                    label: const Text('View all'),
                  ),
                ],
              ),
              if (properties.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(CupertinoIcons.house),
                    title: Text('No listings yet'),
                    subtitle: Text(
                      'Add your first sale or rental property to start receiving enquiries.',
                    ),
                  ),
                )
              else
                for (final property in properties.take(3))
                  _PortfolioRow(property: property),
              _Section(
                title: 'Client reservations',
                empty: 'No pending or reserved reservations.',
                children: [
                  for (final booking in bookings)
                    _BookingRow(booking: booking, isLandlord: true),
                ],
              ),
            ] else ...[
              _Section(
                title: 'Saved homes',
                empty: 'Save a property to see it here.',
                children: [
                  for (final property in savedProperties.take(5))
                    _SavedPropertyRow(property: property),
                ],
              ),
              _Section(
                title: 'Bookings',
                empty: 'No pending or reserved bookings.',
                children: [
                  for (final booking in bookings)
                    _BookingRow(booking: booking, isLandlord: false),
                ],
              ),
            ],
            _Section(
              title: 'Applications',
              empty: 'No applications yet.',
              children: [
                for (final item in state.snapshot.applications.take(5))
                  ListTile(
                    leading: const Icon(CupertinoIcons.doc_text),
                    title: Text(item.property),
                    subtitle: Text(
                      '${isLandlord ? item.applicant : item.createdAt} / score ${item.score}',
                    ),
                    trailing: Text(item.status),
                  ),
              ],
            ),
            _Section(
              title: 'Messages',
              empty: 'No conversations yet.',
              children: [
                for (final item in state.snapshot.conversations.take(5))
                  ListTile(
                    leading: const Icon(CupertinoIcons.chat_bubble),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: item.unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (item.unreadCount > 0)
                          _ActivityUnreadBadge(count: item.unreadCount),
                      ],
                    ),
                    subtitle: Text(
                      item.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(item.updatedAt),
                    onTap: () => _openConversation(context, state, item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openConversation(
    BuildContext context,
    Property24State state,
    ConversationItem conversation,
  ) {
    PropertyListing? property;
    for (final item in state.snapshot.properties) {
      if (item.id == conversation.propertyId) {
        property = item;
        break;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          conversation: conversation,
          property: property,
        ),
      ),
    );
  }
}

class _ActivityUnreadBadge extends StatelessWidget {
  const _ActivityUnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking, required this.isLandlord});

  final ViewingItem booking;
  final bool isLandlord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.read<Property24State>();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          isLandlord ? CupertinoIcons.person : CupertinoIcons.calendar,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(
        isLandlord
            ? (booking.tenant.isEmpty ? 'Client reservation' : booking.tenant)
            : booking.property,
      ),
      subtitle: Text(
        isLandlord
            ? '${booking.property} / ${booking.scheduledFor}'
            : '${booking.scheduledFor} / ${booking.status}',
      ),
      trailing: booking.status.toLowerCase() == 'pending' && isLandlord
          ? PopupMenuButton<String>(
              tooltip: 'Respond to viewing request',
              onSelected: (status) async {
                try {
                  await state.updateViewingStatus(booking, status);
                } catch (exception) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(userFacingError(exception)),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'confirmed',
                  child: Text('Accept request'),
                ),
                PopupMenuItem(
                  value: 'rejected',
                  child: Text('Reject request'),
                ),
              ],
            )
          : Text(
              booking.status,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
      onTap: booking.conversationId.isEmpty
          ? null
          : () {
              ConversationItem? conversation;
              for (final item in state.snapshot.conversations) {
                if (item.id == booking.conversationId) {
                  conversation = item;
                  break;
                }
              }
              if (conversation == null) return;
              final matchedConversation = conversation;
              PropertyListing? property;
              for (final item in state.snapshot.properties) {
                if (item.id == booking.propertyId) {
                  property = item;
                  break;
                }
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConversationScreen(
                    conversation: matchedConversation,
                    property: property,
                  ),
                ),
              );
            },
    );
  }
}

class _SavedPropertyRow extends StatelessWidget {
  const _SavedPropertyRow({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(CupertinoIcons.house, color: theme.colorScheme.primary),
      ),
      title: Text(property.title),
      subtitle: Text(property.heroLocation),
      trailing: Text(
        property.rentLabel,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LandlordNotificationButton extends StatelessWidget {
  const _LandlordNotificationButton({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        tooltip: 'Notifications',
        padding: EdgeInsets.zero,
        onPressed: () => _openLandlordNotifications(context, state),
        icon: Badge(
          isLabelVisible: state.unreadNotificationCount > 0,
          backgroundColor: Theme.of(context).colorScheme.primary,
          textColor: Theme.of(context).colorScheme.onPrimary,
          label: Text(
            '${state.unreadNotificationCount}',
            style: const TextStyle(fontSize: 10),
          ),
          child: Icon(
            CupertinoIcons.bell,
            color: Theme.of(context).colorScheme.onSurface,
            size: 28,
          ),
        ),
      ),
    );
  }
}

void _openLandlordNotifications(BuildContext context, Property24State state) {
  final width = MediaQuery.sizeOf(context).width;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withAlpha(71),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        left: false,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 12,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
          child: SizedBox(
            width: width < 560 ? width * 0.92 : 440,
            height: double.infinity,
            child: ListenableBuilder(
              listenable: state,
              builder: (_, __) => _LandlordNotificationPanel(state: state),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(curved),
        child: child,
      );
    },
  );
}

class _LandlordNotificationPanel extends StatelessWidget {
  const _LandlordNotificationPanel({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    style: theme.textTheme.titleLarge,
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
                                  content: Text(userFacingError(exception)),
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(CupertinoIcons.checkmark_circle),
                ),
                IconButton(
                  tooltip: 'Clear all notifications',
                  onPressed: state.allNotifications.isEmpty
                      ? null
                      : () => _clearAll(context),
                  icon: const Icon(CupertinoIcons.trash),
                ),
                IconButton(
                  tooltip: 'Close notifications',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(CupertinoIcons.xmark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: state.allNotifications.isEmpty
                  ? Center(
                      child: Text(
                        'No new notifications',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      itemCount: state.allNotifications.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: theme.colorScheme.outlineVariant),
                      itemBuilder: (context, index) {
                        final notification = state.allNotifications[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            notification.isRead
                                ? CupertinoIcons.bell
                                : CupertinoIcons.bell_fill,
                            color: notification.isRead
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.primary,
                          ),
                          title: Text(
                            notification.message,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w400
                                  : FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(notification.createdAt),
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
                                    color: theme.colorScheme.primary,
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
                                  color: theme.colorScheme.onSurfaceVariant,
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

class _PortfolioRow extends StatelessWidget {
  const _PortfolioRow({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: SizedBox(
          width: 58,
          height: 58,
          child: property.photos.isEmpty
              ? DecoratedBox(
                  decoration:
                      BoxDecoration(color: theme.colorScheme.primaryContainer),
                  child: Icon(
                    CupertinoIcons.house,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Image.network(
                  property.photos.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      CupertinoIcons.house,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
        ),
        title:
            Text(property.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${property.listingIntent == 'sale' ? 'For sale' : 'For rent'} / ${property.availabilityStatus} / ${property.listingViews} views',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          property.rentLabel,
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  empty,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}
