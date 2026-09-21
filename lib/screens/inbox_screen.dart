import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/async_value_view.dart';
import '../widgets/osm_map_preview.dart';
import 'ai_search_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String _query = '';

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
      return _query.trim().isEmpty || haystack.contains(_query.toLowerCase());
    }).toList(growable: false);

    return LoadingOverlay(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Inbox',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _openAiSearch,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.search,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _query.isEmpty ? '' : _query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _query.isEmpty
                              ? AppTheme.textMuted
                              : AppTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () => setState(() => _query = ''),
                        icon: const Icon(
                          CupertinoIcons.xmark,
                          color: AppTheme.textMuted,
                          size: 18,
                        ),
                      ),
                  ],
                ),
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
              for (final conversation in conversations)
                _ConversationTile(
                  conversation: conversation,
                  property: _propertyFor(state, conversation),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConversationScreen(
                        conversation: conversation,
                        property: _propertyFor(state, conversation),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
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

  Future<void> _openAiSearch() async {
    final query = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => AiSearchScreen(initialQuery: _query),
      ),
    );
    if (!mounted || query == null) return;
    setState(() => _query = query);
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
    final title = property?.title.isNotEmpty == true
        ? property!.title
        : conversation.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.bgSurface,
                  backgroundImage:
                      participant?.profilePicture.isNotEmpty == true
                          ? NetworkImage(participant!.profilePicture)
                          : null,
                  child: participant?.profilePicture.isNotEmpty == true
                      ? null
                      : const Icon(
                          CupertinoIcons.person,
                          color: AppTheme.textMuted,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        property?.heroLocation ?? conversation.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  conversation.updatedAt,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final property = widget.property;
    final canShareExact =
        property?.hasCoordinates == true && property?.showExactLocation == true;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(
          property?.title ?? widget.conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          if (property != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: OsmMapPreview(
                label: property.heroLocation,
                latitude: property.mapLatitude,
                longitude: property.mapLongitude,
                approximate: !property.showExactLocation,
                height: 150,
                zoom: property.showExactLocation ? 15 : 12,
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (widget.conversation.preview.trim().isNotEmpty)
                  _TextBubble(
                    text: widget.conversation.preview,
                    mine: false,
                  ),
                for (final item in state.localChatMessages)
                  item.attachmentType == AttachmentType.location
                      ? _LocationBubble(item: item)
                      : _TextBubble(text: item.body, mine: item.mine),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: canShareExact
                        ? 'Share live location'
                        : 'Exact location is private',
                    onPressed: canShareExact
                        ? () => context
                            .read<Property24State>()
                            .addLocalLocationMessage(property: property!)
                        : null,
                    icon: const Icon(CupertinoIcons.location),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _message,
                      decoration: const InputDecoration(
                        hintText: '',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _send,
                    icon: const Icon(CupertinoIcons.arrow_up),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    if (body.isEmpty) return;
    _message.clear();
    try {
      await context
          .read<Property24State>()
          .sendMessage(widget.conversation.id, body);
    } catch (_) {
      if (!mounted) return;
      context.read<Property24State>().addLocalChatMessage(
            body,
            AttachmentType.none,
          );
    }
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppTheme.accent : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: mine ? Colors.white : AppTheme.textPrimary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LocationBubble extends StatelessWidget {
  const _LocationBubble({required this.item});

  final ChatMessageDraft item;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.74,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OsmMapPreview(
              label: item.locationLabel,
              latitude: item.latitude,
              longitude: item.longitude,
              height: 130,
              approximate: false,
              zoom: 16,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  CupertinoIcons.location_north,
                  color: AppTheme.accent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.liveLocation ? 'Live location' : item.locationLabel,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
