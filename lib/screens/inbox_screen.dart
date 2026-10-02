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
import '../widgets/osm_map_preview.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String _query = '';
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
                Expanded(
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
            Container(
              height: 50,
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
                  hintText: 'Search people, properties, or messages',
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
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
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
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
                      : Icon(
                          CupertinoIcons.person,
                          color: AppTheme.textMuted,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
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
                          if (conversation.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            _UnreadCountBadge(count: conversation.unreadCount),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conversation.preview,
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  conversation.updatedAt,
                  style: TextStyle(
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMessages());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    _message.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final state = context.read<Property24State>();
    if (!state.signedIn || _loading) return;
    if (mounted) setState(() => _loading = true);
    try {
      final messages =
          await state.loadConversationMessages(widget.conversation.id);
      if (mounted) setState(() => _messages = messages);
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
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: Text(property?.title ?? widget.conversation.title)),
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
              padding: const EdgeInsets.all(16),
              children: [
                if (_loading && _messages.isEmpty)
                  Center(child: CircularProgressIndicator()),
                for (final item in _messages)
                  _PersistedMessageBubble(
                      item: item, mine: item.senderId == state.user?.id),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Add photo or video',
                    onPressed: _uploading ? null : _showAttachmentSheet,
                    icon: Icon(CupertinoIcons.paperclip),
                  ),
                  IconButton(
                    tooltip: _recording ? 'Stop recording' : 'Record audio',
                    onPressed: _uploading ? null : _toggleRecording,
                    icon: Icon(_recording
                        ? CupertinoIcons.stop_fill
                        : CupertinoIcons.mic),
                  ),
                  IconButton(
                    tooltip: canShareLocation
                        ? 'Share location'
                        : 'Location unavailable',
                    onPressed: canShareLocation
                        ? () async {
                            await state.shareLocation(widget.conversation.id,
                                property: property!);
                            await _loadMessages();
                          }
                        : null,
                    icon: Icon(CupertinoIcons.location),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                          hintText: 'Write a message',
                          border: InputBorder.none),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _send,
                    icon: Icon(CupertinoIcons.arrow_up),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAttachmentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(CupertinoIcons.camera),
              title: Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickChatMedia(source: ImageSource.camera, video: false);
              },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.photo_on_rectangle),
              title: Text('Choose a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickChatMedia(source: ImageSource.gallery, video: false);
              },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.videocam),
              title: Text('Record a video'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickChatMedia(source: ImageSource.camera, video: true);
              },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.film),
              title: Text('Choose a video'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickChatMedia(source: ImageSource.gallery, video: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickChatMedia(
      {required ImageSource source, required bool video}) async {
    try {
      final file = video
          ? await _picker.pickVideo(
              source: source,
              preferredCameraDevice: CameraDevice.rear,
              maxDuration: const Duration(minutes: 2))
          : await _picker.pickImage(
              source: source,
              preferredCameraDevice: CameraDevice.rear,
              imageQuality: 100);
      if (file != null) await _sendAttachment(file, video ? 'video' : 'image');
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(exception))));
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _audioRecorder.stop();
      if (mounted) setState(() => _recording = false);
      if (path != null)
        await _sendAttachment(XFile(path, mimeType: 'audio/mp4'), 'audio');
      return;
    }
    if (!await _audioRecorder.hasPermission()) return;
    final directory = await getTemporaryDirectory();
    await _audioRecorder.start(const RecordConfig(),
        path:
            '${directory.path}/property24-${DateTime.now().millisecondsSinceEpoch}.m4a');
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _sendAttachment(XFile file, String type) async {
    if (mounted) setState(() => _uploading = true);
    try {
      await context
          .read<Property24State>()
          .sendMessageAttachment(widget.conversation.id, file, type);
      await _loadMessages();
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(exception))));
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(exception))));
    }
  }
}

class _PersistedMessageBubble extends StatelessWidget {
  const _PersistedMessageBubble({required this.item, required this.mine});

  final ChatMessageItem item;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final body = item.attachmentType.isEmpty
        ? item.body
        : '${item.body.isEmpty ? 'Shared attachment' : item.body} · ${item.attachmentType}';
    return _TextBubble(text: body, mine: mine);
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
          color: mine ? AppTheme.accent : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
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
