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
    final propertyId = '${notification.payload['property_id'] ?? ''}';
    if (propertyId.isEmpty) return;
    try {
      await state.refresh(silent: true);
      if (!context.mounted) return;
      final property = state.snapshot.properties.where(
        (item) => item.id == propertyId,
      );
      if (property.isEmpty) {
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
          builder: (_) => PropertyDetailScreen(property: property.first),
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
