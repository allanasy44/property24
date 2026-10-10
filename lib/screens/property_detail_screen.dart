import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/osm_map_preview.dart';
import '../widgets/property_card.dart';
import 'inbox_screen.dart';
import 'supplier_profile_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({super.key, required this.property});

  final PropertyListing property;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  int _page = 0;
  bool _saved = false;
  int _listingViews = 0;
  int _savedCount = 0;
  bool _liked = false;
  int _likesCount = 0;
  bool _followingSupplier = false;
  int _supplierFollowersCount = 0;
  bool _supplierFollowLoading = false;
  bool _commentsLoading = false;
  bool _similarPropertiesLoading = false;
  String? _commentsError;
  final TextEditingController _commentController = TextEditingController();
  List<PropertyCommentItem> _comments = <PropertyCommentItem>[];
  List<ComparisonSuggestion> _similarProperties = <ComparisonSuggestion>[];
  PropertyCommentItem? _replyTo;

  @override
  void initState() {
    super.initState();
    _listingViews = widget.property.listingViews;
    _savedCount = widget.property.savedCount;
    _likesCount = widget.property.likesCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeEngagement();
      _loadComments();
      _loadLikeStatus();
      _loadSupplierFollowStatus();
      _loadSimilarProperties();
    });
  }

  Future<void> _initializeEngagement() async {
    final state = context.read<Property24State>();
    if (mounted) {
      setState(
        () => _saved = state.savedPropertyIds.contains(widget.property.id),
      );
    }
    try {
      final views = await state.recordPropertyView(widget.property.id);
      if (mounted) setState(() => _listingViews = views);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  Future<void> _toggleSaved() async {
    final state = context.read<Property24State>();
    if (!state.signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save this home.')),
      );
      return;
    }

    final wasSaved = state.savedPropertyIds.contains(widget.property.id);
    try {
      await state.toggleSaved(widget.property);
      if (mounted) {
        setState(() {
          _saved = state.savedPropertyIds.contains(widget.property.id);
          _savedCount = (_savedCount + (wasSaved ? -1 : 1))
              .clamp(0, 1 << 31)
              .toInt();
        });
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final state = context.read<Property24State>();
    if (!state.signedIn) return;
    if (mounted) {
      setState(() {
        _commentsLoading = true;
        _commentsError = null;
      });
    }
    try {
      final comments = await state.loadPropertyComments(widget.property.id);
      if (mounted) setState(() => _comments = comments);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _commentsError =
            exception is ApiException && exception.statusCode == 403
            ? 'Comments are not available for this listing.'
            : userFacingError(exception);
      });
    } finally {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  Future<void> _loadSimilarProperties() async {
    final state = context.read<Property24State>();
    if (!state.signedIn) return;
    setState(() => _similarPropertiesLoading = true);
    try {
      final suggestions = await state.comparisonSuggestionsFor(
        widget.property.id,
      );
      if (mounted) setState(() => _similarProperties = suggestions);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    } finally {
      if (mounted) setState(() => _similarPropertiesLoading = false);
    }
  }

  Future<void> _loadLikeStatus() async {
    final state = context.read<Property24State>();
    if (!state.signedIn) return;
    try {
      final result = await state.propertyLikeStatus(widget.property.id);
      if (mounted) {
        setState(() {
          _liked = result['liked'] == true;
          _likesCount = int.tryParse('${result['likes_count'] ?? 0}') ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    try {
      final result = await context.read<Property24State>().togglePropertyLike(
        widget.property.id,
        liked: !_liked,
      );
      if (mounted) {
        setState(() {
          _liked = result['liked'] == true;
          _likesCount = int.tryParse('${result['likes_count'] ?? 0}') ?? 0;
        });
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  Future<void> _loadSupplierFollowStatus() async {
    final supplier = widget.property.supplier;
    final state = context.read<Property24State>();
    if (!state.signedIn ||
        supplier == null ||
        !supplier.verified ||
        supplier.id == state.user?.id) {
      return;
    }
    try {
      final result = await state.supplierFollowStatus(supplier.id);
      if (!mounted) return;
      setState(() {
        _followingSupplier = result['following'] == true;
        _supplierFollowersCount =
            int.tryParse('${result['followers_count'] ?? 0}') ?? 0;
      });
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  Future<void> _toggleSupplierFollow() async {
    final supplier = widget.property.supplier;
    final state = context.read<Property24State>();
    if (supplier == null) return;
    if (!state.signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to follow this supplier.')),
      );
      return;
    }
    if (_supplierFollowLoading) return;
    setState(() => _supplierFollowLoading = true);
    try {
      final result = await state.toggleSupplierFollow(
        supplier.id,
        following: !_followingSupplier,
      );
      if (!mounted) return;
      setState(() {
        _followingSupplier = result['following'] == true;
        _supplierFollowersCount =
            int.tryParse('${result['followers_count'] ?? 0}') ?? 0;
      });
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    } finally {
      if (mounted) setState(() => _supplierFollowLoading = false);
    }
  }

  Future<void> _postComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    try {
      final comment = await context
          .read<Property24State>()
          .createPropertyComment(
            widget.property.id,
            body,
            parentId: _replyTo?.id,
          );
      _commentController.clear();
      if (mounted) {
        setState(() {
          _comments = [comment, ..._comments];
          _replyTo = null;
        });
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  Future<void> _editComment(PropertyCommentItem comment) async {
    final controller = TextEditingController(text: comment.body);
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit comment'),
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
    if (!mounted || body == null || body.isEmpty) return;
    final updated = await context.read<Property24State>().editPropertyComment(
      widget.property.id,
      comment.id,
      body,
    );
    if (mounted) {
      setState(() {
        _comments = _comments
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
      });
    }
  }

  Future<void> _deleteComment(PropertyCommentItem comment) async {
    await context.read<Property24State>().deletePropertyComment(
      widget.property.id,
      comment.id,
    );
    if (mounted) {
      setState(
        () => _comments = _comments
            .where(
              (item) => item.id != comment.id && item.parentId != comment.id,
            )
            .toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final state = context.watch<Property24State>();
    final currentProperty = state.snapshot.properties.firstWhere(
      (item) => item.id == property.id,
      orElse: () => property,
    );
    final listingViews = currentProperty.listingViews > _listingViews
        ? currentProperty.listingViews
        : _listingViews;
    final savedCount = currentProperty.savedCount > _savedCount
        ? currentProperty.savedCount
        : _savedCount;
    final photos = property.photos.isEmpty ? <String>[''] : property.photos;
    final amenities = _amenities(property);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroGallery(
                  photos: photos,
                  page: _page,
                  saved: _saved,
                  onPageChanged: (index) => setState(() => _page = index),
                  onBack: () => Navigator.pop(context),
                  onSave: _toggleSaved,
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 112),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PriceHeader(property: property),
                      const SizedBox(height: 14),
                      _MetaLine(property: property),
                      if (property.sharedRoom ||
                          (property.isStudentAccommodation &&
                              property
                                  .accommodationInstitution
                                  .isNotEmpty)) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (property.sharedRoom)
                              const Chip(
                                avatar: Icon(CupertinoIcons.person_2, size: 16),
                                label: Text('Shared room'),
                              ),
                            if (property.isStudentAccommodation &&
                                property.accommodationInstitution.isNotEmpty)
                              Chip(
                                avatar: const Icon(
                                  CupertinoIcons.book,
                                  size: 16,
                                ),
                                label: Text(
                                  'For ${property.accommodationInstitution}',
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      _AvailabilityCard(property: property),
                      const SizedBox(height: 14),
                      _NeighborhoodCard(property: property),
                      const SizedBox(height: 14),
                      if (!property.isStayOrVenue)
                        _AffordabilityCard(property: property),
                      const SizedBox(height: 14),
                      _GuestChips(property: property),
                      if (property.isStayOrVenue) ...[
                        const SizedBox(height: 14),
                        _StayVenueDetails(property: property),
                      ],
                      const SizedBox(height: 18),
                      OsmMapPreview(
                        label: property.heroLocation,
                        latitude: property.mapLatitude,
                        longitude: property.mapLongitude,
                        approximate: !property.showExactLocation,
                        zoom: property.showExactLocation ? 15 : 12,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: _liked
                                    ? 'Unlike listing'
                                    : 'Like listing',
                                onPressed: _toggleLike,
                                icon: Icon(
                                  _liked
                                      ? CupertinoIcons.heart_fill
                                      : CupertinoIcons.heart,
                                ),
                                color: _liked
                                    ? Colors.redAccent
                                    : AppTheme.textSecondary,
                              ),
                              Text(
                                '$_likesCount likes',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          _EngagementCount(
                            icon: CupertinoIcons.eye,
                            label: '$listingViews views',
                          ),
                          _EngagementCount(
                            icon: CupertinoIcons.bookmark,
                            label: '$savedCount saved',
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.chat_bubble,
                                size: 19,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_comments.length} comments',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _DetailTabs(),
                      const SizedBox(height: 14),
                      if (property.description.trim().isNotEmpty)
                        Text(
                          property.description.trim(),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                            height: 1.55,
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (amenities.isNotEmpty) ...[
                        Text(
                          'What this house offers',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in amenities) _AmenityChip(item),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (state.signedIn &&
                          state.user?.id != widget.property.owner?.id) ...[
                        _SimilarPropertiesSection(
                          suggestions: _similarProperties,
                          isLoading: _similarPropertiesLoading,
                          onOpen: (suggestion) => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PropertyDetailScreen(
                                property: suggestion.property,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      _HostCard(
                        property: property,
                        following: _followingSupplier,
                        followersCount: _supplierFollowersCount,
                        followLoading: _supplierFollowLoading,
                        onFollow: _toggleSupplierFollow,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Comments',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_replyTo != null)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to ${_replyTo!.author.name}',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cancel reply',
                              onPressed: () => setState(() => _replyTo = null),
                              icon: const Icon(CupertinoIcons.xmark, size: 16),
                            ),
                          ],
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Write a comment...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: 'Post comment',
                            onPressed: _postComment,
                            icon: const Icon(CupertinoIcons.arrow_up),
                          ),
                        ],
                      ),
                      if (_commentsLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_commentsError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _commentsError!,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      for (final comment in _comments.where(
                        (item) => item.parentId.isEmpty,
                      )) ...[
                        _CommentTile(
                          comment: comment,
                          currentUserId: context
                              .read<Property24State>()
                              .user
                              ?.id,
                          onReply: () => setState(() => _replyTo = comment),
                          onEdit: () => _editComment(comment),
                          onDelete: () => _deleteComment(comment),
                        ),
                        for (final reply in _comments.where(
                          (item) => item.parentId == comment.id,
                        ))
                          _CommentTile(
                            comment: reply,
                            currentUserId: context
                                .read<Property24State>()
                                .user
                                ?.id,
                            isReply: true,
                            onReply: () => setState(() => _replyTo = comment),
                            onEdit: () => _editComment(reply),
                            onDelete: () => _deleteComment(reply),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomActions(property: property),
          ),
        ],
      ),
    );
  }

  List<String> _amenities(PropertyListing property) {
    final items = <String>[
      if (property.has360Tour) '360 tour',
      if (property.isLand) ...[
        property.landSizeLabel,
        property.standSummary,
        property.landTitleLabel,
        property.landServicingLabel,
        if (property.zoning.trim().isNotEmpty)
          'Zoning: ${property.zoning.trim()}',
        if (property.roadAccess.trim().isNotEmpty)
          'Road access: ${property.roadAccess.trim()}',
        if (property.electricityAvailable) 'Electricity available',
        if (property.landWaterAvailable) 'Water available',
      ] else ...[
        if (property.parking.trim().isNotEmpty) property.parking.trim(),
        if (property.waterAvailability.trim().isNotEmpty)
          property.waterAvailability.trim(),
        if (property.furnished) 'Furnished',
        if (property.solarPower) 'Solar power',
        if (property.borehole) 'Borehole',
        if (property.petFriendly) 'Pet friendly',
      ],
      property.propertyType,
      ...property.listingAmenities,
      ...property.venueFeatures,
      ...property.activities,
    ];
    return items
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    this.isReply = false,
  });

  final PropertyCommentItem comment;
  final String? currentUserId;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final canEdit = currentUserId == comment.authorId;
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 34 : 0, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundImage: comment.author.profilePicture.isEmpty
                ? null
                : NetworkImage(comment.author.profilePicture),
            child: comment.author.profilePicture.isEmpty
                ? Text(
                    comment.author.name.isEmpty
                        ? '?'
                        : comment.author.name[0].toUpperCase(),
                  )
                : null,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.author.name,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        comment.body,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton(onPressed: onReply, child: const Text('Reply')),
                    if (canEdit)
                      PopupMenuButton<String>(
                        tooltip: 'Comment options',
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'delete') onDelete();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            CupertinoIcons.ellipsis,
                            size: 16,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementCount extends StatelessWidget {
  const _EngagementCount({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.photos,
    required this.page,
    required this.saved,
    required this.onPageChanged,
    required this.onBack,
    required this.onSave,
  });

  final List<String> photos;
  final int page;
  final bool saved;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: photos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final photo = photos[index];
              if (photo.isEmpty) {
                return Container(
                  color: AppTheme.bgSurface,
                  child: Icon(
                    CupertinoIcons.house,
                    color: AppTheme.textMuted,
                    size: 56,
                  ),
                );
              }
              return Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.bgSurface,
                  child: Icon(
                    CupertinoIcons.house,
                    color: AppTheme.textMuted,
                    size: 56,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 18,
            child: _CircleAction(
              icon: CupertinoIcons.chevron_left,
              tooltip: 'Back',
              onPressed: onBack,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            right: 18,
            child: Row(
              children: [
                _CircleAction(
                  icon: CupertinoIcons.share,
                  tooltip: 'Share',
                  onPressed: () {},
                ),
                const SizedBox(width: 10),
                _CircleAction(
                  icon: saved
                      ? CupertinoIcons.heart_fill
                      : CupertinoIcons.heart,
                  tooltip: saved ? 'Remove saved home' : 'Save home',
                  onPressed: onSave,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < photos.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 5,
                    width: page == index ? 18 : 5,
                    decoration: BoxDecoration(
                      color: page == index ? Colors.white : Colors.white70,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.32),
        foregroundColor: Colors.white,
        fixedSize: const Size.square(36),
        minimumSize: const Size.square(36),
      ),
      icon: Icon(icon, size: 19),
    );
  }
}

class _PriceHeader extends StatelessWidget {
  const _PriceHeader({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.rentLabel,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                property.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                property.heroLocation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const _HeaderIcon(icon: CupertinoIcons.clock),
        const _HeaderIcon(icon: CupertinoIcons.bookmark),
        const _HeaderIcon(icon: CupertinoIcons.location),
        const _HeaderIcon(icon: CupertinoIcons.heart),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(icon, size: 16, color: AppTheme.textSecondary),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${property.trustScore}% trust / ${property.isLand ? property.standSummary : '${property.moveInTotalLabel} rent + deposit'}',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(CupertinoIcons.eye, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(
              property.availabilityLabel,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final theme = Theme.of(context);
    final liveProperty = state.currentProperty(property);
    final userId = state.user?.id;
    final canConfirm =
        userId != null &&
        (userId == liveProperty.owner?.id || userId == liveProperty.agent?.id);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                liveProperty.availabilityNeedsConfirmation ||
                        liveProperty.availabilityState == 'available_from' ||
                        liveProperty.availabilityState == 'rented' ||
                        liveProperty.availabilityState == 'sold'
                    ? CupertinoIcons.exclamationmark_triangle
                    : CupertinoIcons.checkmark_seal,
                size: 18,
                color:
                    liveProperty.availabilityNeedsConfirmation ||
                        liveProperty.availabilityState == 'available_from' ||
                        liveProperty.availabilityState == 'rented' ||
                        liveProperty.availabilityState == 'sold'
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Availability',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AvailabilityIndicator(
                      label: liveProperty.availabilityLabel,
                      state: liveProperty.availabilityState,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (liveProperty.lastConfirmedAt.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Last confirmed ${liveProperty.lastConfirmedAt}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (canConfirm) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: AvailabilityActionMenu(
                onSelected: (action) async {
                  DateTime? availableFrom;
                  if (action == 'available_from') {
                    final today = DateTime.now();
                    availableFrom = await showDatePicker(
                      context: context,
                      initialDate: today,
                      firstDate: DateTime(today.year, today.month, today.day),
                      lastDate: DateTime(2100),
                    );
                    if (availableFrom == null || !context.mounted) return;
                  }
                  try {
                    await state.confirmPropertyAvailability(
                      liveProperty,
                      action: action,
                      availableFrom: availableFrom,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Availability updated')),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(userFacingError(error))),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NeighborhoodCard extends StatelessWidget {
  const _NeighborhoodCard({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    final neighborhood = property.neighborhood;
    if (!neighborhood.available) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final details = <String>[
      if (neighborhood.waterReliability != null)
        'Water ${neighborhood.waterReliability}%',
      if (neighborhood.safetyScore != null)
        'Safety ${neighborhood.safetyScore}/100',
      if (neighborhood.commuteToCbdMinutes != null)
        '${neighborhood.commuteToCbdMinutes} min to CBD',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Neighbourhood',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            details.join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (neighborhood.amenities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              neighborhood.amenities.join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (neighborhood.sourceName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Source: ${neighborhood.sourceName}${neighborhood.verifiedAt.isEmpty ? '' : ' · ${neighborhood.verifiedAt}'}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AffordabilityCard extends StatefulWidget {
  const _AffordabilityCard({required this.property});

  final PropertyListing property;

  @override
  State<_AffordabilityCard> createState() => _AffordabilityCardState();
}

class _AffordabilityCardState extends State<_AffordabilityCard> {
  final _income = TextEditingController();
  final _commitments = TextEditingController();
  final _savings = TextEditingController();
  AffordabilityResult? _result;
  String? _error;
  bool _calculating = false;

  @override
  void dispose() {
    _income.dispose();
    _commitments.dispose();
    _savings.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    setState(() {
      _calculating = true;
      _error = null;
    });
    try {
      final result = await context
          .read<Property24State>()
          .calculateAffordability(
            widget.property,
            monthlyIncome: _income.text.trim(),
            monthlyCommitments: _commitments.text.trim().isEmpty
                ? '0'
                : _commitments.text.trim(),
            savingsAvailable: _savings.text.trim().isEmpty
                ? '0'
                : _savings.text.trim(),
          );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<Property24State>().signedIn) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Affordability',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Uses this listing’s current rent and deposit. Your figures remain on this device.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _moneyField(_income, 'Monthly income'),
          const SizedBox(height: 8),
          _moneyField(_commitments, 'Monthly commitments'),
          const SizedBox(height: 8),
          _moneyField(_savings, 'Savings available for move-in'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _calculating ? null : _calculate,
              icon: _calculating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.equal_circle, size: 17),
              label: const Text('Calculate'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(
              '\$${_result!.moveInTotal} rent + deposit · ${_result!.rentToIncomePercent}% of income',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_result!.rentToDisposablePercent.isNotEmpty)
              Text(
                '${_result!.rentToDisposablePercent}% of disposable income',
                style: theme.textTheme.bodySmall,
              ),
            if (_result!.savingsShortfall != '0')
              Text(
                '\$${_result!.savingsShortfall} still needed for move-in',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }

  Widget _moneyField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$',
        isDense: true,
      ),
    );
  }
}

class _SimilarPropertiesSection extends StatelessWidget {
  const _SimilarPropertiesSection({
    required this.suggestions,
    required this.isLoading,
    required this.onOpen,
  });

  final List<ComparisonSuggestion> suggestions;
  final bool isLoading;
  final ValueChanged<ComparisonSuggestion> onOpen;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You might also like',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              final property = suggestion.property;
              return SizedBox(
                width: 220,
                child: Material(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onOpen(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            property.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${property.bedrooms} bed · ${property.location}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            property.rentLabel,
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GuestChips extends StatelessWidget {
  const _GuestChips({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Pill(icon: CupertinoIcons.person_2, label: property.propertyType),
        if (property.isLand) ...[
          _Pill(icon: CupertinoIcons.square, label: property.landSizeLabel),
          _Pill(
            icon: CupertinoIcons.square_stack_3d_up,
            label: property.standSummary,
          ),
          _Pill(icon: CupertinoIcons.doc_text, label: property.landTitleLabel),
          _Pill(
            icon: CupertinoIcons.location,
            label: property.landServicingLabel,
          ),
        ] else if (property.isVenue &&
            !property.isStay &&
            !property.listingCategories.contains('homes')) ...[
          if (property.weddingCapacity > 0)
            _Pill(
              icon: CupertinoIcons.person_2,
              label: '${property.weddingCapacity} wedding guests',
            ),
          if (property.conferenceCapacity > 0)
            _Pill(
              icon: CupertinoIcons.person_2,
              label: '${property.conferenceCapacity} conference guests',
            ),
        ] else ...[
          _Pill(
            icon: CupertinoIcons.drop,
            label: '${property.bathrooms} baths',
          ),
          _Pill(
            icon: CupertinoIcons.bed_double,
            label: '${property.bedrooms} beds',
          ),
        ],
      ],
    );
  }
}

class _StayVenueDetails extends StatelessWidget {
  const _StayVenueDetails({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    final capacities = <String>[
      if (property.maxGuests > 0) 'Sleeps ${property.maxGuests} guests',
      if (property.weddingCapacity > 0)
        'Wedding capacity: ${property.weddingCapacity}',
      if (property.conferenceCapacity > 0)
        'Conference capacity: ${property.conferenceCapacity}',
      if (property.cateringAvailable) 'Catering available',
      if (property.guestAccommodation) 'Guest accommodation',
    ];
    final sections = <(String, List<String>)>[
      if (property.isStay && property.isVenue && property.eventRate.isNotEmpty)
        ('Venue pricing', ['From ${money(property.eventRate)} / event']),
      ('Rooms', property.roomTypes),
      ('Amenities', property.listingAmenities),
      ('Activities', property.activities),
      ('For events', [...property.venueFeatures, ...capacities]),
    ].where((section) => section.$2.isNotEmpty).toList(growable: false);
    if (sections.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < sections.length; index++) ...[
            if (index > 0) const SizedBox(height: 14),
            Text(
              sections[index].$1,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in sections[index].$2) _AmenityChip(item),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs();

  @override
  Widget build(BuildContext context) {
    const tabs = ['Overview', 'Amenities', 'Reviews', 'Location'];
    return Row(
      children: [
        for (final tab in tabs)
          Expanded(
            child: Column(
              children: [
                Text(
                  tab,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tab == tabs.first
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: tab == tabs.first
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  width: 36,
                  color: tab == tabs.first
                      ? AppTheme.accent
                      : Colors.transparent,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.check_mark,
            size: 13,
            color: AppTheme.accent,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({
    required this.property,
    required this.following,
    required this.followersCount,
    required this.followLoading,
    required this.onFollow,
  });

  final PropertyListing property;
  final bool following;
  final int followersCount;
  final bool followLoading;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final supplier = property.supplier;
    final name = supplier?.name.trim() ?? '';
    final initials = name.isEmpty
        ? 'P'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.characters.first.toUpperCase())
              .join();

    return InkWell(
      onTap: supplier == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SupplierProfileScreen(supplier: supplier),
              ),
            ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: AppTheme.textPrimary,
                  backgroundImage: supplier?.profilePicture.isNotEmpty == true
                      ? NetworkImage(supplier!.profilePicture)
                      : null,
                  child: supplier?.profilePicture.isNotEmpty == true
                      ? null
                      : Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty)
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (supplier?.email.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          supplier!.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (supplier?.verified == true &&
                    supplier?.id != context.read<Property24State>().user?.id)
                  TextButton(
                    onPressed: followLoading ? null : onFollow,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: followLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(following ? 'Following' : 'Follow'),
                  ),
                if (supplier?.verified == true)
                  const Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: AppTheme.accent,
                    size: 18,
                  ),
              ],
            ),
            if (supplier?.verified == true)
              Padding(
                padding: const EdgeInsets.only(left: 54, top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$followersCount followers',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 10.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.property});

  final PropertyListing property;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final canInteract = state.signedIn && state.user?.id != property.owner?.id;
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canInteract && !property.isStayOrVenue) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _requestViewing(context),
                icon: const Icon(CupertinoIcons.calendar),
                label: const Text('Request viewing'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _contactHost(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Message host'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _contactHost(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    property.isStay
                        ? 'Enquire about stay'
                        : property.isVenue
                        ? 'Enquire about venue'
                        : 'Reserve',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _requestViewing(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final availableFrom = DateTime.tryParse(property.availableFrom);
    final firstDate = availableFrom != null && availableFrom.isAfter(today)
        ? availableFrom
        : today;
    final initialDate = firstDate.isAfter(today.add(const Duration(days: 1)))
        ? firstDate
        : today.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null || !context.mounted) return;
    final scheduledFor = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!scheduledFor.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a viewing time in the future.')),
      );
      return;
    }
    try {
      final state = context.read<Property24State>();
      final viewing = await state.requestViewing(property, scheduledFor);
      if (!context.mounted) return;
      ConversationItem? conversation;
      for (final item in state.snapshot.conversations) {
        if (item.id == viewing.conversationId) {
          conversation = item;
          break;
        }
      }
      if (conversation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Viewing request sent. Refresh your inbox to open the conversation.',
            ),
          ),
        );
        context.go(AppRoutes.chatScreen);
        return;
      }
      final selectedConversation = conversation;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConversationScreen(
            conversation: selectedConversation,
            property: property,
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

  Future<void> _contactHost(BuildContext context) async {
    try {
      final state = context.read<Property24State>();
      if (property.isStayOrVenue) {
        await state.messageAboutProperty(property);
      } else {
        await state.holdProperty(property);
      }
      if (context.mounted) context.go(AppRoutes.chatScreen);
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }
}
