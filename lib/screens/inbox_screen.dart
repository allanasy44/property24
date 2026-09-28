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
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _recording = false;
  bool _uploading = false;

  @override
  void dispose() {
    _message.dispose();
    _audioRecorder.dispose();
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
                  _TextBubble(text: widget.conversation.preview, mine: false),
                for (final item in state.localChatMessages)
                  item.attachmentType == AttachmentType.location
                      ? _LocationBubble(item: item)
                      : item.attachmentType == AttachmentType.none
                          ? _TextBubble(text: item.body, mine: item.mine)
                          : _AttachmentBubble(item: item),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                children: [
                  if (_recording || _uploading)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4),
                        child: Text(
                          _recording
                              ? 'Recording walkthrough...'
                              : 'Sending attachment...',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: _recording
                                        ? Colors.redAccent
                                        : AppTheme.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Add photo or video',
                        onPressed: _uploading ? null : _showAttachmentSheet,
                        icon: const Icon(CupertinoIcons.paperclip),
                      ),
                      IconButton(
                        tooltip: _recording ? 'Stop recording' : 'Record audio',
                        onPressed: _uploading ? null : _toggleRecording,
                        color: _recording ? Colors.redAccent : null,
                        icon: Icon(_recording
                            ? CupertinoIcons.stop_fill
                            : CupertinoIcons.mic),
                      ),
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
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Write a message',
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 12),
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed: _uploading ? null : _send,
                        icon: const Icon(CupertinoIcons.arrow_up),
                      ),
                    ],
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
              leading: const Icon(CupertinoIcons.camera),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickChatMedia(source: ImageSource.camera, video: false);
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.photo_on_rectangle),
              title: const Text('Choose a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickChatMedia(source: ImageSource.gallery, video: false);
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.videocam),
              title: const Text('Record a video'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickChatMedia(source: ImageSource.camera, video: true);
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.film),
              title: const Text('Choose a video'),
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
              maxDuration: const Duration(minutes: 2),
            )
          : await _picker.pickImage(
              source: source,
              preferredCameraDevice: CameraDevice.rear,
              imageQuality: 100,
            );
      if (file != null) await _sendAttachment(file, video ? 'video' : 'image');
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
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
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Microphone permission is required to record audio.')));
      return;
    }
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/property24-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _sendAttachment(XFile file, String type) async {
    if (mounted) setState(() => _uploading = true);
    try {
      await context
          .read<Property24State>()
          .sendMessageAttachment(widget.conversation.id, file, type);
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

class _AttachmentBubble extends StatelessWidget {
  const _AttachmentBubble({required this.item});

  final ChatMessageDraft item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.attachmentType) {
      AttachmentType.image => CupertinoIcons.photo,
      AttachmentType.video => CupertinoIcons.film,
      AttachmentType.audio => CupertinoIcons.waveform,
      _ => CupertinoIcons.paperclip,
    };
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.74),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accent.withOpacity(0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.accent,
              child:
                  Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: AppTheme.accent),
          ],
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
          borderRadius: BorderRadius.circular(8),
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
