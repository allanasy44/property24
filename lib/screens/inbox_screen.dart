import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unicons/unicons.dart';

import '../models/rental_models.dart';
import '../state/property24_state.dart';
import '../widgets/async_value_view.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    return LoadingOverlay(
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Text('Inbox', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Chat, normal calls, video calls, and the history tenants and landlords need.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.forum_outlined),
                    label: Text('Chats')),
                ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.call_outlined),
                    label: Text('Calls')),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
            const ErrorBanner(),
            const SizedBox(height: 12),
            if (!state.signedIn)
              const EmptyState(
                icon: Icons.lock_outline,
                title: 'Sign in for messages',
                body:
                    'Conversations, protected phone numbers, and call sessions load after authentication.',
              )
            else if (_tab == 0)
              _ConversationList(state: state)
            else
              _CallHistory(state: state),
          ],
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    if (state.snapshot.conversations.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No conversations yet',
        body: 'Open a property and message the landlord or agent.',
      );
    }
    return Column(
      children: [
        for (final conversation in state.snapshot.conversations)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  conversation.title.isEmpty
                      ? 'C'
                      : conversation.title.characters.first.toUpperCase(),
                ),
              ),
              title: Text(conversation.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(conversation.preview,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(conversation.updatedAt,
                      style: Theme.of(context).textTheme.labelSmall),
                  Icon(
                    conversation.phoneNumbersRevealed
                        ? Icons.phone_enabled_outlined
                        : Icons.phone_locked_outlined,
                    size: 16,
                  ),
                ],
              ),
              onTap: () => _openChat(context, conversation),
            ),
          ),
      ],
    );
  }

  void _openChat(BuildContext context, ConversationItem conversation) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ChatSheet(conversation: conversation),
    );
  }
}

class _ChatSheet extends StatefulWidget {
  const _ChatSheet({required this.conversation});

  final ConversationItem conversation;

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _message = TextEditingController();
  AttachmentType _attachmentType = AttachmentType.none;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, inset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.conversation.title,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Consumer<Property24State>(
            builder: (context, state, _) {
              return Column(
                children: [
                  for (final message in state.localChatMessages)
                    _Bubble(
                      message: message,
                      onEdit: message.mine
                          ? () => _editMessage(context, state, message)
                          : null,
                      onDelete: message.mine
                          ? () => state.deleteLocalChatMessage(message.id)
                          : null,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          SegmentedButton<AttachmentType>(
            segments: const [
              ButtonSegment(
                value: AttachmentType.none,
                icon: Icon(UniconsLine.comment),
              ),
              ButtonSegment(
                value: AttachmentType.image,
                icon: Icon(UniconsLine.image),
              ),
              ButtonSegment(
                value: AttachmentType.video,
                icon: Icon(UniconsLine.video),
              ),
              ButtonSegment(
                value: AttachmentType.audio,
                icon: Icon(UniconsLine.microphone),
              ),
            ],
            selected: {_attachmentType},
            showSelectedIcon: false,
            onSelectionChanged: (value) {
              setState(() => _attachmentType = value.first);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _message,
                  decoration: const InputDecoration(
                    hintText: 'Write a message',
                    prefixIcon: Icon(Icons.attach_file_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send message',
                onPressed: _send,
                icon: const Icon(Icons.send_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty && _attachmentType == AttachmentType.none) return;
    final state = context.read<Property24State>();
    state.addLocalChatMessage(
      text.isEmpty ? _attachmentLabel(_attachmentType) : text,
      _attachmentType,
    );
    _message.clear();
    setState(() => _attachmentType = AttachmentType.none);
    try {
      if (text.isNotEmpty) {
        await state.sendMessage(widget.conversation.id, text);
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  String _attachmentLabel(AttachmentType type) {
    return switch (type) {
      AttachmentType.image => 'Image attachment',
      AttachmentType.video => 'Video attachment',
      AttachmentType.audio => 'Audio attachment',
      AttachmentType.none => '',
    };
  }

  void _editMessage(
    BuildContext context,
    Property24State state,
    ChatMessageDraft message,
  ) {
    final controller = TextEditingController(text: message.body);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              state.updateLocalChatMessage(message.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _CallHistory extends StatelessWidget {
  const _CallHistory({required this.state});

  final Property24State state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.video_call_outlined),
            title: const Text('Start new call from a property'),
            subtitle: const Text(
                'Open any listing and use Call or Video on the contact card.'),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {},
          ),
        ),
        const SizedBox(height: 8),
        for (final item in state.callHistory)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(item.mode == CallMode.video
                  ? Icons.videocam_outlined
                  : Icons.call_outlined),
              title: Text(item.name),
              subtitle: Text('${item.property} · ${item.direction}'),
              trailing: Text(item.when,
                  style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    this.onEdit,
    this.onDelete,
  });

  final ChatMessageDraft message;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.mine
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: message.mine
              ? null
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.attachmentType != AttachmentType.none)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Icon(
                  _attachmentIcon(message.attachmentType),
                  color: message.mine
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                color: message.mine
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
            ),
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    TextButton(onPressed: onEdit, child: const Text('Edit')),
                  if (onDelete != null)
                    TextButton(
                        onPressed: onDelete, child: const Text('Delete')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get mine => message.mine;

  IconData _attachmentIcon(AttachmentType type) {
    return switch (type) {
      AttachmentType.image => UniconsLine.image,
      AttachmentType.video => UniconsLine.video,
      AttachmentType.audio => UniconsLine.microphone,
      AttachmentType.none => UniconsLine.comment,
    };
  }
}
