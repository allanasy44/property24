import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../screens/live_call_screen.dart';
import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  StreamSubscription<Map<String, dynamic>>? _callSubscription;
  final Set<String> _promptedCallIds = <String>{};
  final Set<String> _endedCallIds = <String>{};
  String? _showingIncomingCallId;
  String? _answeringIncomingCallId;
  Property24State? _observedState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<Property24State>();
    if (_observedState == state) return;
    _callSubscription?.cancel();
    _observedState = state;
    _callSubscription = state.callEvents.listen(_handleCallEvent);
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleCallEvent(Map<String, dynamic> event) async {
    final rawPayload = event['payload'];
    if (rawPayload is! Map<String, dynamic>) return;
    final eventType = '${event['type'] ?? ''}';
    final callId = '${rawPayload['call_id'] ?? rawPayload['id'] ?? ''}';
    if (eventType == 'call.ended') {
      if (_showingIncomingCallId == callId && mounted) {
        _endedCallIds.add(callId);
        Navigator.of(context, rootNavigator: true).pop(false);
      }
      return;
    }
    if (eventType != 'call.started') return;
    final state = _observedState;
    if (state == null || !mounted) return;
    final call = CallLogItem.fromJson(rawPayload);
    if (call.id.isEmpty ||
        call.initiatorId == state.user?.id ||
        _promptedCallIds.contains(call.id)) {
      return;
    }
    ConversationItem? conversation;
    for (final item in state.snapshot.conversations) {
      if (item.id == call.conversationId) {
        conversation = item;
        break;
      }
    }
    if (conversation == null) {
      await state.refresh(silent: true);
      for (final item in state.snapshot.conversations) {
        if (item.id == call.conversationId) {
          conversation = item;
          break;
        }
      }
    }
    final targetConversation = conversation;
    if (targetConversation == null) return;
    if (!_promptedCallIds.add(call.id)) return;
    if (state.hasLocalActiveCall ||
        _showingIncomingCallId != null ||
        _answeringIncomingCallId != null) {
      try {
        await state.endCall(
          targetConversation.id,
          call.id,
          status: 'missed',
        );
      } catch (exception) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(exception.toString())),
          );
        }
      }
      return;
    }
    _showingIncomingCallId = call.id;
    unawaited(_showIncomingCall(call, targetConversation));
  }

  Future<void> _showIncomingCall(
    CallLogItem call,
    ConversationItem conversation,
  ) async {
    final state = _observedState;
    if (state == null || !mounted) return;
    AccountUser? caller;
    for (final participant in conversation.participants) {
      if (participant.id == call.initiatorId) {
        caller = participant;
        break;
      }
    }
    final callerName =
        caller?.name.isNotEmpty == true ? caller!.name : conversation.title;
    final timeout = Timer(const Duration(seconds: 60), () {
      if (mounted && _showingIncomingCallId == call.id) {
        Navigator.of(context, rootNavigator: true).pop(false);
      }
    });
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Incoming ${call.mode == CallMode.video ? 'video' : 'voice'} call',
        ),
        content: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    callerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    conversation.propertyId.isEmpty
                        ? 'Property24 chat'
                        : conversation.title,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Decline'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: Icon(
              call.mode == CallMode.video ? Icons.videocam : Icons.call,
            ),
            label: const Text('Answer'),
          ),
        ],
      ),
    );
    timeout.cancel();
    if (_showingIncomingCallId == call.id) _showingIncomingCallId = null;
    if (!mounted) return;
    if (_endedCallIds.remove(call.id)) return;
    if (accepted == true) {
      _answeringIncomingCallId = call.id;
      try {
        await LiveCallScreen.answerIncoming(
          context,
          conversation: conversation,
          call: call,
          peerId: call.initiatorId,
          peerName: callerName,
        );
      } catch (exception) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(exception.toString())),
          );
        }
        try {
          await state.endCall(
            conversation.id,
            call.id,
            status: 'missed',
          );
        } catch (endException) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(endException.toString())),
            );
          }
        }
      } finally {
        if (_answeringIncomingCallId == call.id) {
          _answeringIncomingCallId = null;
        }
      }
    } else {
      try {
        await state.endCall(conversation.id, call.id, status: 'missed');
      } catch (exception) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(exception.toString())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: _BottomNav(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        isAdmin: state.user?.role == AccountRole.admin,
        unreadMessages: state.unreadMessageCount,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.isAdmin,
    required this.unreadMessages,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isAdmin;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = isAdmin
        ? const [
            _NavItem(
              icon: CupertinoIcons.house,
              label: 'Dashboard',
              branchIndex: 0,
            ),
            _NavItem(
              icon: CupertinoIcons.person_2,
              label: 'Accounts',
              branchIndex: 1,
            ),
            _NavItem(
              icon: CupertinoIcons.checkmark_shield,
              label: 'Verify',
              branchIndex: 2,
            ),
            _NavItem(
              icon: CupertinoIcons.person_circle,
              label: 'Profile',
              branchIndex: 3,
            ),
          ]
        : [
            const _NavItem(
              icon: CupertinoIcons.house,
              label: 'Home',
              branchIndex: 0,
            ),
            const _NavItem(
              icon: CupertinoIcons.search,
              label: 'Explore',
              branchIndex: 1,
            ),
            const _NavItem(
              icon: CupertinoIcons.add,
              label: 'Create',
              isCreate: true,
            ),
            _NavItem(
              icon: CupertinoIcons.chat_bubble,
              label: 'Messages',
              branchIndex: 2,
              badgeCount: unreadMessages,
            ),
            const _NavItem(
              icon: CupertinoIcons.person_circle,
              label: 'You',
              branchIndex: 3,
            ),
          ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        14,
      ),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha(80),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(22),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          child: Row(
            children: List.generate(
              items.length,
              (index) {
                final item = items[index];
                final selected = item.branchIndex == currentIndex;

                return Expanded(
                  child: _BottomNavItem(
                    item: item,
                    selected: selected,
                    onTap: item.isCreate
                        ? () => _showCreateActions(context)
                        : () => onTap(item.branchIndex!),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (item.isCreate) {
      return Semantics(
        button: true,
        label: item.label,
        child: IconButton.filled(
          tooltip: item.label,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            fixedSize: const Size(48, 48),
          ),
          icon: const Icon(CupertinoIcons.add, size: 24),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color:
                selected ? AppTheme.accent.withAlpha(25) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.90,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(
                  '${item.label}-$selected',
                ),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    isLabelVisible: item.badgeCount > 0,
                    label: Text(
                      item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                      style: const TextStyle(fontSize: 9),
                    ),
                    child: Icon(
                      item.icon,
                      size: selected ? 22 : 21,
                      color: selected
                          ? AppTheme.accent
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppTheme.accent
                          : colorScheme.onSurfaceVariant,
                      height: 1.0,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    this.branchIndex,
    this.badgeCount = 0,
    this.isCreate = false,
  });

  final IconData icon;
  final String label;
  final int? branchIndex;
  final int badgeCount;
  final bool isCreate;
}

void _showCreateActions(BuildContext context) {
  final state = context.read<Property24State>();
  final actions = [
    const _CreateAction(
      icon: CupertinoIcons.house,
      label: 'List a property',
      category: 'homes',
      requiresPropertyCapability: true,
    ),
    const _CreateAction(
      icon: CupertinoIcons.bed_double,
      label: 'List accommodation',
      category: 'stays',
      requiresPropertyCapability: true,
    ),
    const _CreateAction(
      icon: Icons.celebration,
      label: 'List a venue',
      category: 'venues',
      requiresPropertyCapability: true,
    ),
    const _CreateAction(
      icon: CupertinoIcons.wrench,
      label: 'Offer a service',
      market: 'services',
    ),
    const _CreateAction(
      icon: CupertinoIcons.briefcase,
      label: 'Post a job',
      market: 'jobs',
    ),
    const _CreateAction(
      icon: CupertinoIcons.doc_text,
      label: 'Request a service',
      market: 'services',
    ),
  ];
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.bgCard,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What would you like to do?',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final action in actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(action.icon, color: AppTheme.accent),
                title: Text(
                  action.label,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (!state.signedIn && action.requiresPropertyCapability) {
                    context.pushNamed(
                      AppRoutes.authName,
                      pathParameters: const {'role': 'list-property'},
                    );
                    return;
                  }
                  unawaited(_runCreateAction(context, state, action));
                },
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CreateAction {
  const _CreateAction({
    required this.icon,
    required this.label,
    this.category,
    this.market,
    this.requiresPropertyCapability = false,
  });

  final IconData icon;
  final String label;
  final String? category;
  final String? market;
  final bool requiresPropertyCapability;
}

Future<void> _runCreateAction(
  BuildContext context,
  Property24State state,
  _CreateAction action,
) async {
  try {
    if (action.requiresPropertyCapability && !state.canManageListings) {
      await state.enablePropertyListings();
    }
    if (!context.mounted) return;
    if (action.category != null) {
      context.push(
        '${AppRoutes.listingsScreen}?category=${action.category}&create=${DateTime.now().microsecondsSinceEpoch}',
      );
      return;
    }
    context.go(
      Uri(
        path: AppRoutes.exploreScreen,
        queryParameters: {
          'market': action.market!,
          if (action.label != 'Request a service')
            'create': DateTime.now().microsecondsSinceEpoch.toString(),
        },
      ).toString(),
    );
  } catch (exception) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userFacingError(exception))),
    );
  }
}
