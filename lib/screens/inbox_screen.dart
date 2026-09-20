import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  // ─────────── Colors sampled from the design ───────────
  static const Color _bg = Color(0xFF1A1A1A);
  static const Color _surface = Color(0xFF232323);
  static const Color _accent = Color(0xFFFF4D4D);
  static const Color _textPrimary = Color(0xFFF5F5F5);
  static const Color _textSecondary = Color(0xFF9E9E9E);
  static const Color _online = Color(0xFF3DDC84);

  // ─────────── Mock data from the design ───────────
  final List<_ActiveUser> _activeUsers = const [
    _ActiveUser(imageUrl: 'https://i.pravatar.cc/150?img=12'),
    _ActiveUser(imageUrl: 'https://i.pravatar.cc/150?img=32'),
    _ActiveUser(imageUrl: 'https://i.pravatar.cc/150?img=45'),
    _ActiveUser(imageUrl: 'https://i.pravatar.cc/150?img=5'),
    _ActiveUser(imageUrl: 'https://i.pravatar.cc/150?img=68'),
  ];

  final List<_MessageItem> _messages = const [
    _MessageItem(
      name: 'Arlene McCoy',
      preview: 'Wowem consectetur',
      time: '12.50 PM',
      imageUrl: 'https://i.pravatar.cc/150?img=47',
      unread: 1,
    ),
    _MessageItem(
      name: 'Wade Warren',
      preview: 'Wowem consectetur',
      time: '12.50 PM',
      imageUrl: 'https://i.pravatar.cc/150?img=15',
      unread: 0,
    ),
    _MessageItem(
      name: 'Courtney Henry',
      preview: 'Wowem consectetur',
      time: '12.50 PM',
      imageUrl: 'https://i.pravatar.cc/150?img=20',
      unread: 0,
    ),
    _MessageItem(
      name: 'Darlene Robertson',
      preview: 'Wowem consectetur',
      time: '12.50 PM',
      imageUrl: 'https://i.pravatar.cc/150?img=44',
      unread: 0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─────────── Top bar ───────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Message',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  _CircleIconButton(
                    icon: Icons.more_vert,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // ─────────── Body ───────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Search bar
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.search,
                            color: _textSecondary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: _textPrimary,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Search any car...',
                              hintStyle: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: _textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const Icon(Icons.mic_none,
                            color: _textSecondary, size: 22),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Active Now
                  const Text(
                    'Active Now',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _activeUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        return _ActiveAvatar(
                          imageUrl: _activeUsers[index].imageUrl,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Messages
                  const Text(
                    'Messages',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message list
                  ..._messages.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _MessageTile(item: m),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),

      // ─────────── FAB ───────────
      floatingActionButton: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {},
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3A3A3A), width: 1.2),
        ),
        child: Icon(icon, color: _InboxScreenState._textPrimary, size: 18),
      ),
    );
  }
}

class _ActiveAvatar extends StatelessWidget {
  const _ActiveAvatar({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        children: [
          Container(
            width: 66,
            height: 66,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4D4D), Color(0xFFFF8A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _InboxScreenState._bg,
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _InboxScreenState._online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _InboxScreenState._bg,
                  width: 2.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.item});
  final _MessageItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _InboxScreenState._surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar + unread badge
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(item.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (item.unread > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _InboxScreenState._accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${item.unread}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Name + preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _InboxScreenState._textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.preview,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: _InboxScreenState._textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Time
          Text(
            item.time,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: _InboxScreenState._textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Data models (local)
// ─────────────────────────────────────────────────────────────

class _ActiveUser {
  const _ActiveUser({required this.imageUrl});
  final String imageUrl;
}

class _MessageItem {
  const _MessageItem({
    required this.name,
    required this.preview,
    required this.time,
    required this.imageUrl,
    required this.unread,
  });
  final String name;
  final String preview;
  final String time;
  final String imageUrl;
  final int unread;
}
