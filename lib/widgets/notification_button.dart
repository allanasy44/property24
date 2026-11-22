import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/rental_models.dart';
import '../screens/property_detail_screen.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class NotificationButton extends StatelessWidget {
  const NotificationButton({required this.state, super.key});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border),
      ),
      child: IconButton(
        tooltip: 'Notifications',
        padding: EdgeInsets.zero,
        onPressed: () => _openNotificationPanel(context, state),
        icon: Badge(
          isLabelVisible: state.unreadNotificationCount > 0,
          backgroundColor: AppTheme.accent,
          textColor: Colors.white,
          label: Text(
            '${state.unreadNotificationCount}',
            style: const TextStyle(fontSize: 10),
          ),
          child: Icon(
            CupertinoIcons.bell,
            color: AppTheme.textPrimary,
            size: 28,
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
            borderRadius: width < 560
                ? BorderRadius.zero
                : const BorderRadius.horizontal(left: Radius.circular(24)),
            child: SizedBox(
              width: width < 560 ? width : 440,
              height: double.infinity,
              child: ListenableBuilder(
                listenable: state,
                builder: (_, _) => _NotificationPanel(state: state),
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

class _NotificationPanel extends StatefulWidget {
  const _NotificationPanel({required this.state});

  final Property24State state;

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifications = state.allNotifications
        .where((item) {
          return switch (_filter) {
            'Unread' => !item.isRead,
            'Messages' => item.kind.toLowerCase().contains('message'),
            'Listings' =>
              item.kind.toLowerCase().contains('property') ||
                  item.kind.toLowerCase().contains('listing'),
            _ => true,
          };
        })
        .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (state.unreadNotificationCount > 0)
                  TextButton(
                    onPressed: () async {
                      try {
                        await state.markAllNotificationsRead();
                      } catch (exception) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(userFacingError(exception))),
                          );
                        }
                      }
                    },
                    child: const Text('Mark all read'),
                  ),
                if (state.allNotifications.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear all notifications',
                    onPressed: () => _clearAll(context),
                    icon: const Icon(CupertinoIcons.trash),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  for (final filter in const [
                    'All',
                    'Unread',
                    'Messages',
                    'Listings',
                  ])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _filter == filter
                                ? AppTheme.bgCard
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _filter == filter
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 5,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            filter,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      state.liveConnected
                          ? CupertinoIcons.bell_fill
                          : CupertinoIcons.bell,
                      color: state.liveConnected
                          ? AppTheme.accentTeal
                          : AppTheme.accent,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.liveConnected
                              ? 'Live alerts are on'
                              : state.signedIn
                              ? 'Connecting to live alerts'
                              : 'Live alerts require sign in',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          state.liveConnected
                              ? 'Connected to real-time updates.'
                              : state.liveConnectionIssue ??
                                    (state.signedIn
                                        ? 'Waiting for the backend connection.'
                                        : 'Sign in to receive account updates.'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'LATEST',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Text(
                        'No notifications here yet',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: AppTheme.border),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: notification.payload['property_id'] == null
                              ? null
                              : () => _openNotificationProperty(
                                  context,
                                  notification,
                                ),
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
                                  onPressed: () =>
                                      _markAsRead(context, notification.id),
                                  icon: const Icon(
                                    CupertinoIcons.checkmark_circle,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Clear notification',
                                onPressed: () =>
                                    _clearOne(context, notification.id),
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

  Future<void> _openNotificationProperty(
    BuildContext context,
    NotificationItem notification,
  ) async {
    final state = widget.state;
    final propertyId = '${notification.payload['property_id'] ?? ''}';
    if (propertyId.isEmpty) return;
    try {
      await state.refresh(silent: true);
      if (!context.mounted) return;
      final allProperties = [
        ...state.snapshot.properties,
        ...state.snapshot.savedProperties,
      ];
      PropertyListing? matchedProperty;
      for (final property in allProperties) {
        if (property.id == propertyId) {
          matchedProperty = property;
          break;
        }
      }
      if (matchedProperty == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This property is no longer available.'),
          ),
        );
        return;
      }
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PropertyDetailScreen(
            property: state.currentProperty(matchedProperty!),
          ),
        ),
      );
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  Future<void> _markAsRead(BuildContext context, String notificationId) async {
    final state = widget.state;
    try {
      await state.markNotificationRead(notificationId);
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  Future<void> _clearOne(BuildContext context, String notificationId) async {
    final state = widget.state;
    try {
      await state.clearNotification(notificationId);
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final state = widget.state;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear notifications?'),
        content: const Text(
          'All notifications will be removed from this area.',
        ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }
}
