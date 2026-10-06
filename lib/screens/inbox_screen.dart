import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/async_value_view.dart';
import 'live_call_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String _query = '';
  String _filter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final conversations = state.snapshot.conversations.where((conversation) {
      final property = _propertyFor(state, conversation);
      final haystack = [
        conversation.title,
        conversation.preview,
        property?.title ?? '',
        property?.heroLocation ?? '',
      ].join(' ').toLowerCase();
      final matchesQuery =
          _query.trim().isEmpty || haystack.contains(_query.toLowerCase());
      final matchesFilter = _filter == 'All' ||
          (_filter == 'Unread' && conversation.unreadCount > 0);
      return matchesQuery && matchesFilter;
    }).toList()
      ..sort((first, second) {
        final firstDate = first.updatedAtDate;
        final secondDate = second.updatedAtDate;
        if (firstDate == null) return secondDate == null ? 0 : 1;
        if (secondDate == null) return -1;
        return secondDate.compareTo(firstDate);
      });

    return LoadingOverlay(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chats',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Camera',
                  onPressed: () => _showUnavailable('Camera'),
                  icon: const Icon(CupertinoIcons.camera),
                ),
                IconButton(
                  tooltip: 'New chat',
                  onPressed: () => _showUnavailable('New chat'),
                  icon: const Icon(CupertinoIcons.square_pencil),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13.5,
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _searchController.clear,
                          icon: Icon(
                            CupertinoIcons.xmark,
                            color: AppTheme.textMuted,
                            size: 18,
                          ),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in const ['All', 'Unread'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ChatFilter(
                        label: filter,
                        selected: _filter == filter,
                        onTap: () => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const ErrorBanner(),
            if (conversations.isEmpty)
              const EmptyState(
                icon: CupertinoIcons.chat_bubble_2,
                title: 'No conversations',
                body: '',
              )
            else
              for (var index = 0; index < conversations.length; index++) ...[
                if (index == 0 ||
                    _conversationGroup(
                          conversations[index - 1].updatedAtDate,
                        ) !=
                        _conversationGroup(conversations[index].updatedAtDate))
                  _ConversationGroupHeading(
                    label:
                        _conversationGroup(conversations[index].updatedAtDate),
                  ),
                _ConversationTile(
                  conversation: conversations[index],
                  property: _propertyFor(state, conversations[index]),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConversationScreen(
                        conversation: conversations[index],
                        property: _propertyFor(state, conversations[index]),
                      ),
                    ),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  void _showUnavailable(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is available from a conversation')),
    );
  }

  PropertyListing? _propertyFor(
    Property24State state,
    ConversationItem conversation,
  ) {
    for (final property in state.snapshot.properties) {
      if (property.id == conversation.propertyId) return property;
    }
    return null;
  }

  String _conversationGroup(DateTime? updatedAt) {
    if (updatedAt == null) return 'Earlier';
    final now = DateTime.now();
    if (isSameLocalDay(updatedAt, now)) return 'Today';
    if (isSameLocalDay(updatedAt, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return 'Earlier';
  }
}

class _ConversationGroupHeading extends StatelessWidget {
  const _ConversationGroupHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ChatFilter extends StatelessWidget {
  const _ChatFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.accent : AppTheme.bgSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.property,
    required this.onTap,
  });

  final ConversationItem conversation;
  final PropertyListing? property;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final participant = conversation.participants.isNotEmpty
        ? conversation.participants.first
        : null;
    final contactName = participant?.name.isNotEmpty == true
        ? participant!.name
        : conversation.title;
    final subtitle = [
      if (property?.title.isNotEmpty == true) property!.title,
      conversation.preview,
    ].join('  ·  ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              _ChatAvatar(participant: participant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contactName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          conversation.updatedAt,
                          style: TextStyle(
                            color: conversation.unreadCount > 0
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: conversation.unreadCount > 0
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (conversation.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          _UnreadCountBadge(count: conversation.unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(count > 99 ? 12 : 20),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    required this.conversation,
    required this.property,
    super.key,
  });

  final ConversationItem conversation;
  final PropertyListing? property;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _message = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  List<ChatMessageItem> _messages = <ChatMessageItem>[];
  bool _loading = false;
  bool _recording = false;
  bool _uploading = false;
  int _revision = -1;
  Property24State? _observedState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMessages());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<Property24State>();
    if (_observedState != state) {
      _observedState?.removeListener(_onStateChanged);
      _observedState = state..addListener(_onStateChanged);
    }
    final next = context
        .read<Property24State>()
        .conversationRevision(widget.conversation.id);
    if (next != _revision) {
      _revision = next;
      _loadMessages();
    }
  }

  @override
  void dispose() {
    _observedState?.removeListener(_onStateChanged);
    _message.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final state = _observedState;
    if (!mounted || state == null) return;
    final next = state.conversationRevision(widget.conversation.id);
    if (next != _revision) {
      _revision = next;
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    final state = context.read<Property24State>();
    if (!state.signedIn || _loading) return;
    if (mounted) setState(() => _loading = true);
    try {
      final messages =
          await state.loadConversationMessages(widget.conversation.id);
      state.sendLiveEvent('delivered', widget.conversation.id);
      state.sendLiveEvent('read', widget.conversation.id);
      if (mounted) setState(() => _messages = messages);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final property = widget.property;
    final canShareLocation =
        property?.hasCoordinates == true && property?.showExactLocation == true;
    final participant = _participant(state);
    final contactName = participant?.name.isNotEmpty == true
        ? participant!.name
        : widget.conversation.title;
    final activeCall = state.activeCallForConversation(widget.conversation.id);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _ChatAvatar(participant: participant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contactName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    state.typingUserForConversation(widget.conversation.id) ??
                        (property?.title ?? 'Property24 chat'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Voice call',
            onPressed: () => _startCall(CallMode.voice),
            icon: const Icon(CupertinoIcons.phone, size: 20),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () => _startCall(CallMode.video),
            icon: const Icon(CupertinoIcons.videocam, size: 21),
          ),
          PopupMenuButton<String>(
            tooltip: 'Chat options',
            onSelected: _handleChatOption,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'contact', child: Text('Contact info')),
              PopupMenuItem(value: 'mute', child: Text('Mute notifications')),
              PopupMenuItem(value: 'block', child: Text('Block contact')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (activeCall != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withAlpha(24),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accent.withAlpha(90)),
              ),
              child: Row(
                children: [
                  Icon(
                    activeCall.mode == CallMode.video
                        ? CupertinoIcons.videocam_fill
                        : CupertinoIcons.phone_fill,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${activeCall.mode == CallMode.video ? 'Video' : 'Voice'} call in progress',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: activeCall.id.isEmpty
                        ? null
                        : () => _endCall(activeCall.id),
                    child: const Text('End'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: [
                if (_loading && _messages.isEmpty)
                  const Center(child: CircularProgressIndicator()),
                for (var index = 0; index < _messages.length; index++) ...[
                  if (_messages[index].createdAtDate != null &&
                      (index == 0 ||
                          _messages[index - 1].createdAtDate == null ||
                          !isSameLocalDay(
                            _messages[index].createdAtDate!,
                            _messages[index - 1].createdAtDate!,
                          )))
                    _MessageDateDivider(
                      label: chatDateLabel(_messages[index].createdAtDate),
                    ),
                  _PersistedMessageBubble(
                    item: _messages[index],
                    mine: _messages[index].senderId == state.user?.id,
                    onLongPress: () => _showMessageActions(_messages[index]),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(14),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Capture photo or video',
                    onPressed: _uploading ? null : _showAttachmentSheet,
                    icon: const Icon(CupertinoIcons.add_circled_solid),
                    color: AppTheme.textSecondary,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 34, height: 34),
                  ),
                  IconButton(
                    tooltip: canShareLocation
                        ? 'Share location'
                        : 'Location unavailable',
                    onPressed: canShareLocation
                        ? () async {
                            await state.shareLocation(
                              widget.conversation.id,
                              property: property!,
                            );
                            await _loadMessages();
                          }
                        : null,
                    icon: const Icon(CupertinoIcons.location),
                    color: canShareLocation
                        ? AppTheme.textSecondary
                        : AppTheme.textMuted,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 34, height: 34),
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 34),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: TextField(
                        controller: _message,
                        minLines: 1,
                        maxLines: 3,
                        onChanged: (value) => state.sendLiveEvent(
                          'typing',
                          widget.conversation.id,
                          payload: {'is_typing': value.trim().isNotEmpty},
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message',
                          border: InputBorder.none,
                          prefixIcon: IconButton(
                            tooltip: 'Emoji',
                            onPressed: _showEmojiPicker,
                            icon: const Icon(CupertinoIcons.smiley),
                            color: AppTheme.textSecondary,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _message,
                    builder: (context, value, child) {
                      final hasText = value.text.trim().isNotEmpty;
                      return Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: hasText ? AppTheme.accent : AppTheme.bgSurface,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: hasText
                              ? 'Send'
                              : (_recording
                                  ? 'Stop recording'
                                  : 'Record audio'),
                          onPressed: _uploading
                              ? null
                              : hasText
                                  ? _send
                                  : _toggleRecording,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 34,
                            height: 34,
                          ),
                          icon: Icon(
                            hasText
                                ? CupertinoIcons.arrow_up
                                : (_recording
                                    ? CupertinoIcons.stop_fill
                                    : CupertinoIcons.mic),
                            size: 18,
                            color:
                                hasText ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AccountUser? _participant(Property24State state) {
    for (final participant in widget.conversation.participants) {
      if (participant.id != state.user?.id) return participant;
    }
    return widget.conversation.participants.isEmpty
        ? null
        : widget.conversation.participants.first;
  }

  Future<void> _showMessageActions(ChatMessageItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (item.senderId == context.read<Property24State>().user?.id &&
                !item.deleted)
              ListTile(
                leading: const Icon(CupertinoIcons.pencil),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
            if (item.senderId == context.read<Property24State>().user?.id &&
                !item.deleted)
              ListTile(
                leading: const Icon(CupertinoIcons.delete),
                title: const Text('Delete message'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            if (item.senderId != context.read<Property24State>().user?.id)
              ListTile(
                leading: const Icon(CupertinoIcons.exclamationmark_triangle),
                title: const Text('Report message'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final state = context.read<Property24State>();
    try {
      if (action == 'delete') {
        await state.deleteConversationMessage(widget.conversation.id, item.id);
      } else if (action == 'report') {
        await state.reportConversationMessage(widget.conversation.id, item.id);
      } else if (action == 'edit') {
        final controller = TextEditingController(text: item.body);
        final body = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Edit message'),
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (body != null && body.isNotEmpty) {
          await state.editConversationMessage(
            widget.conversation.id,
            item.id,
            body,
          );
        }
      }
      await _loadMessages();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }

  Future<void> _startCall(CallMode mode) async {
    try {
      await LiveCallScreen.startOutgoing(
        context,
        conversation: widget.conversation,
        mode: mode,
        peerName: _participant(context.read<Property24State>())?.name ??
            widget.conversation.title,
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }

  Future<void> _endCall(String callId) async {
    try {
      await context.read<Property24State>().endCall(
            widget.conversation.id,
            callId,
          );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }

  Future<void> _handleChatOption(String option) async {
    if (option == 'contact') {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChatAvatar(
                  participant: _participant(context.read<Property24State>()),
                  large: true,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.conversation.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.property != null)
                  Text(
                    widget.property!.title,
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
              ],
            ),
          ),
        ),
      );
    } else if (option == 'block') {
      final participant = _participant(context.read<Property24State>());
      if (participant == null) return;
      try {
        await context
            .read<Property24State>()
            .blockConversationUser(widget.conversation.id, participant.id);
        if (mounted) Navigator.of(context).pop();
      } catch (exception) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userFacingError(exception))),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications muted for this chat')),
      );
    }
  }

  Future<void> _showEmojiPicker() async {
    const emojis = [
      '😀',
      '😂',
      '😍',
      '🥹',
      '😊',
      '😉',
      '👍',
      '🙏',
      '❤️',
      '🔥',
      '🎉',
      '🏠',
      '📍',
      '✨',
      '👏',
      '🤝',
      '😅',
      '🤔',
      '😮',
      '😢',
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final emoji in emojis)
                IconButton(
                  tooltip: emoji,
                  onPressed: () {
                    final value = _message.value;
                    final selection = value.selection.isValid
                        ? value.selection
                        : TextSelection.collapsed(offset: value.text.length);
                    final nextText = value.text.replaceRange(
                      selection.start,
                      selection.end,
                      emoji,
                    );
                    _message.value = value.copyWith(
                      text: nextText,
                      selection: TextSelection.collapsed(
                        offset: selection.start + emoji.length,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  icon: Text(emoji, style: const TextStyle(fontSize: 25)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAttachmentSheet() async {
    final captureVideo = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.camera),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.videocam),
              title: const Text('Video'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
          ],
        ),
      ),
    );
    if (captureVideo != null) {
      await _captureChatMedia(video: captureVideo);
    }
  }

  Future<void> _captureChatMedia({required bool video}) async {
    try {
      final file = video
          ? await _picker.pickVideo(
              source: ImageSource.camera,
              preferredCameraDevice: CameraDevice.rear,
              maxDuration: const Duration(minutes: 2),
            )
          : await _picker.pickImage(
              source: ImageSource.camera,
              preferredCameraDevice: CameraDevice.rear,
              imageQuality: 100,
            );
      if (file != null) await _sendAttachment(file, video ? 'video' : 'image');
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_recording) {
        final path = await _audioRecorder.stop();
        if (mounted) setState(() => _recording = false);
        if (path != null) {
          await _sendAttachment(XFile(path, mimeType: 'audio/mp4'), 'audio');
        }
        return;
      }
      if (!await _audioRecorder.hasPermission()) {
        throw StateError('Microphone permission is required to record audio.');
      }
      final directory = await getTemporaryDirectory();
      await _audioRecorder.start(
        const RecordConfig(),
        path:
            '${directory.path}/property24-${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      if (mounted) setState(() => _recording = true);
    } catch (exception) {
      if (mounted) {
        setState(() => _recording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }

  Future<void> _sendAttachment(XFile file, String type) async {
    if (mounted) setState(() => _uploading = true);
    try {
      await context
          .read<Property24State>()
          .sendMessageAttachment(widget.conversation.id, file, type);
      await _loadMessages();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    if (body.isEmpty) return;
    _message.clear();
    try {
      await context
          .read<Property24State>()
          .sendMessage(widget.conversation.id, body);
      await _loadMessages();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }
}

class _MessageDateDivider extends StatelessWidget {
  const _MessageDateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.participant, this.large = false});

  final AccountUser? participant;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final radius = large ? 38.0 : 19.0;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.bgSurface,
      backgroundImage: participant?.profilePicture.isNotEmpty == true
          ? NetworkImage(participant!.profilePicture)
          : null,
      child: participant?.profilePicture.isNotEmpty == true
          ? null
          : Icon(
              CupertinoIcons.person_fill,
              size: large ? 32 : 17,
              color: AppTheme.textMuted,
            ),
    );
  }
}

class _PersistedMessageBubble extends StatelessWidget {
  const _PersistedMessageBubble({
    required this.item,
    required this.mine,
    required this.onLongPress,
  });

  final ChatMessageItem item;
  final bool mine;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: _MessageBubble(item: item, mine: mine),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.item, required this.mine});

  final ChatMessageItem item;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final attachmentType = item.attachmentType.toLowerCase();
    final hasAttachment = item.attachmentUrl.isNotEmpty;
    final isLocation = item.body.startsWith('Location:') ||
        item.body.startsWith('Live location:');
    final foreground = mine ? Colors.white : AppTheme.textPrimary;
    final muted = mine ? Colors.white70 : AppTheme.textMuted;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppTheme.accent : AppTheme.bgCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isLocation)
              _LocationMessage(
                text: item.body,
                foreground: foreground,
                muted: muted,
              )
            else if (hasAttachment && attachmentType == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  item.attachmentUrl,
                  width: 220,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _AttachmentTile(
                    icon: CupertinoIcons.photo,
                    label: item.attachmentName.isEmpty
                        ? 'Photo unavailable'
                        : item.attachmentName,
                    foreground: foreground,
                  ),
                ),
              )
            else if (hasAttachment)
              _AttachmentTile(
                icon: attachmentType == 'video'
                    ? CupertinoIcons.play_circle_fill
                    : attachmentType == 'audio'
                        ? CupertinoIcons.waveform
                        : CupertinoIcons.doc,
                label: item.attachmentName.isEmpty
                    ? 'Shared $attachmentType'
                    : item.attachmentName,
                foreground: foreground,
              ),
            if (item.body.isNotEmpty && !isLocation) ...[
              if (hasAttachment) const SizedBox(height: 6),
              Text(
                item.body,
                style: TextStyle(color: foreground, fontSize: 13, height: 1.3),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.createdAt,
                  style: TextStyle(color: muted, fontSize: 9),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  _DeliveryTicks(
                    status: item.deliveryStatus,
                    mutedColor: muted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryTicks extends StatelessWidget {
  const _DeliveryTicks({required this.status, required this.mutedColor});

  final String status;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final read = status.toLowerCase() == 'read';
    final delivered = read || status.toLowerCase() == 'delivered';
    final color = read ? const Color(0xff53bdeb) : mutedColor;
    if (!delivered) {
      return Icon(CupertinoIcons.checkmark, size: 12, color: color);
    }
    return SizedBox(
      width: 16,
      height: 13,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Icon(CupertinoIcons.checkmark_alt, size: 12, color: color),
          ),
          Positioned(
            left: 4,
            child: Icon(CupertinoIcons.checkmark_alt, size: 12, color: color),
          ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: foreground, size: 25),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: foreground, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _LocationMessage extends StatelessWidget {
  const _LocationMessage({
    required this.text,
    required this.foreground,
    required this.muted,
  });

  final String text;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.location_solid, color: foreground, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: foreground, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
