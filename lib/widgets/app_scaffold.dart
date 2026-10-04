import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../screens/live_call_screen.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import 'inprop_brand.dart';

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
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: const InPropBrand(compact: true),
                ),
              ),
            ),
          ),
          Expanded(child: widget.navigationShell),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        isLandlord: state.user?.role == AccountRole.landlord,
        unreadMessages: state.unreadMessageCount,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.isLandlord,
    required this.unreadMessages,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isLandlord;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Navigation icons based on the reference design:
    // Home • Saved • Messages • Profile
    final items = isLandlord
        ? const [
            _NavItem(icon: CupertinoIcons.house, label: 'Dashboard'),
            _NavItem(icon: CupertinoIcons.building_2_fill, label: 'Listings'),
          ]
        : const [
            _NavItem(icon: CupertinoIcons.house, label: 'Home'),
            _NavItem(icon: CupertinoIcons.heart, label: 'Saved'),
          ];
    final allItems = [
      ...items,
      _NavItem(
        icon: CupertinoIcons.chat_bubble,
        label: 'Messages',
        badgeCount: unreadMessages,
      ),
      _NavItem(icon: CupertinoIcons.person_circle, label: 'Profile'),
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
              allItems.length,
              (index) {
                final item = allItems[index];
                final selected = index == currentIndex;

                return Expanded(
                  child: _BottomNavItem(
                    item: item,
                    selected: selected,
                    onTap: () => onTap(index),
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
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final int badgeCount;
}
