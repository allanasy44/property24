import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/async_value_view.dart';
import '../widgets/property_card.dart';
import 'property_detail_screen.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({
    this.initialCategories = const ['homes'],
    this.openComposerOnOpen = false,
    super.key,
  });

  final List<String> initialCategories;
  final bool openComposerOnOpen;

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  static const _primary = AppTheme.accent;
  static Color get _searchFill => AppTheme.bgSurface;
  static Color get _textDark => AppTheme.textPrimary;
  static Color get _textMuted => AppTheme.textMuted;

  @override
  void initState() {
    super.initState();
    if (widget.openComposerOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditor(context);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final isLandlord = state.canManageListings;
    final displayName = state.user?.name.trim() ?? '';
    final accountListings = state.snapshot.properties.where(
      (property) =>
          property.owner?.id == state.user?.id ||
          property.agent?.id == state.user?.id,
    );
    final listings = accountListings.where((property) {
      final haystack = [
        property.title,
        property.description,
        property.address,
        property.city,
        property.suburb,
        property.propertyType,
        ...property.listingCategories,
        ...property.roomTypes,
        ...property.listingAmenities,
        ...property.activities,
        ...property.venueFeatures,
        property.rentLabel,
        property.parking,
        property.waterAvailability,
        property.bedrooms.toString(),
        property.borehole ? 'borehole' : '',
        property.solarPower ? 'solar' : '',
      ].join(' ').toLowerCase();
      return _query.trim().isEmpty || haystack.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: LoadingOverlay(
        child: RefreshIndicator(
          onRefresh: state.refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: isLandlord
                                ? const SizedBox.shrink()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${greetingForTime()},',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.3,
                                          color: _textMuted,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        displayName.isEmpty
                                            ? greetingForTime()
                                            : displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 23,
                                          height: 1.15,
                                          color: _textDark,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _openEditor(context),
                            child: Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _primary.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                CupertinoIcons.add,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Listings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: _searchFill,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) =>
                                    setState(() => _query = value),
                                textInputAction: TextInputAction.search,
                                style: TextStyle(
                                  color: _textDark,
                                  fontSize: 13.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search your listings',
                                  hintStyle: TextStyle(
                                    color: _textMuted,
                                    fontSize: 13.5,
                                  ),
                                  prefixIcon: Icon(
                                    CupertinoIcons.search,
                                    color: _textMuted,
                                    size: 20,
                                  ),
                                  suffixIcon: _query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: _searchController.clear,
                                          icon: Icon(
                                            CupertinoIcons.xmark,
                                            color: _textMuted,
                                            size: 18,
                                          ),
                                        ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 17,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: ErrorBanner()),
              if (listings.isEmpty && accountListings.isEmpty)
                const SliverFillRemaining(
                  child: EmptyState(
                    icon: CupertinoIcons.house,
                    title: 'No listings yet',
                    body:
                        'Create a sale or rental listing to start receiving enquiries.',
                  ),
                )
              else if (listings.isEmpty)
                const SliverFillRemaining(
                  child: EmptyState(
                    icon: CupertinoIcons.search,
                    title: 'No matching listings',
                    body: '',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  sliver: SliverList.builder(
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      final property = listings[index];
                      return _LandlordListingTile(
                        property: property,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PropertyDetailScreen(property: property),
                          ),
                        ),
                        onEdit: () => _openEditor(context, property),
                        onDelete: () => _delete(context, property),
                        onAvailabilityChange: (action) =>
                            _updateAvailability(context, property, action),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, [PropertyListing? property]) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) => PropertyEditor(
          property: property,
          initialCategories: widget.initialCategories,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, PropertyListing property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete listing?'),
        content: Text(property.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<Property24State>().deleteProperty(property.id);
  }

  Future<void> _updateAvailability(
    BuildContext context,
    PropertyListing property,
    String action,
  ) async {
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
      await context.read<Property24State>().confirmPropertyAvailability(
        property,
        action: action,
        availableFrom: availableFrom,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'rented'
                  ? 'Listing marked as rented and removed from search.'
                  : 'Availability updated.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
      }
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _LandlordListingTile extends StatelessWidget {
  const _LandlordListingTile({
    required this.property,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailabilityChange,
  });

  final PropertyListing property;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onAvailabilityChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSale = property.listingIntent == 'sale';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      color: AppTheme.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  property.photos.isEmpty
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.bgSurface, AppTheme.borderMid],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.building_2_fill,
                            size: 46,
                            color: theme.colorScheme.secondary,
                          ),
                        )
                      : Image.network(
                          property.photos.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.bgSurface,
                            ),
                            child: Icon(
                              CupertinoIcons.building_2_fill,
                              size: 46,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(
                          alpha: 0.94,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isSale ? 'For sale' : 'For rent',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: 0.94),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        tooltip: 'Listing actions',
                        onSelected: (value) =>
                            value == 'edit' ? onEdit() : onDelete(),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit listing'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete listing'),
                          ),
                        ],
                        icon: Icon(
                          CupertinoIcons.ellipsis,
                          color: theme.colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        property.rentLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.heroLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _ListingMetric(
                        icon: CupertinoIcons.eye,
                        value: '${property.listingViews} views',
                      ),
                      _ListingMetric(
                        icon: CupertinoIcons.person_2,
                        value: '${property.applicationsCount} applications',
                      ),
                      AvailabilityIndicator(
                        label: property.availabilityLabel,
                        state: property.availabilityState,
                      ),
                      AvailabilityActionMenu(onSelected: onAvailabilityChange),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingMetric extends StatelessWidget {
  const _ListingMetric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(value, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class PropertyEditor extends StatefulWidget {
  const PropertyEditor({
    this.property,
    this.initialCategories = const ['homes'],
    super.key,
  });

  final PropertyListing? property;
  final List<String> initialCategories;

  @override
  State<PropertyEditor> createState() => _PropertyEditorState();
}

class _PropertyEditorState extends State<PropertyEditor> {
  static const _primary = AppTheme.accent;
  static Color get _searchFill => AppTheme.bgSurface;
  static Color get _textDark => AppTheme.textPrimary;
  static Color get _textMuted => AppTheme.textMuted;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _suburb;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _rent;
  late final TextEditingController _deposit;
  late final TextEditingController _beds;
  late final TextEditingController _baths;
  late final TextEditingController _description;
  late final TextEditingController _water;
  late final TextEditingController _parking;
  late final TextEditingController _images;
  late final TextEditingController _videos;
  late final TextEditingController _audio;
  late final TextEditingController _standReference;
  late final TextEditingController _stands;
  String _landSizeUnit = 'sqm';
  String _titleDeedStatus = 'not_provided';
  String _servicingStatus = 'not_serviced';
  bool _electricityAvailable = false;
  bool _landWaterAvailable = false;
  late final TextEditingController _landSize;
  late final TextEditingController _zoning;
  late final TextEditingController _roadAccess;
  late final TextEditingController _accommodationInstitution;
  late final TextEditingController _nightlyRate;
  late final TextEditingController _eventRate;
  late final TextEditingController _roomTypes;
  late final TextEditingController _listingAmenities;
  late final TextEditingController _activities;
  late final TextEditingController _venueFeatures;
  late final TextEditingController _maxGuests;
  late final TextEditingController _weddingCapacity;
  late final TextEditingController _conferenceCapacity;
  String _intent = 'Rent';
  String _type = 'house';
  Set<String> _listingCategories = {'homes'};
  bool _sharedRoom = false;
  bool _furnished = false;
  bool _solar = false;
  bool _borehole = false;
  bool _pets = false;
  bool _tour = false;
  bool _showExactLocation = false;
  bool _cateringAvailable = false;
  bool _guestAccommodation = false;
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newImages = <XFile>[];
  XFile? _newVideo;
  late final Future<List<Map<String, dynamic>>> _adminLandlords;
  String? _ownerId;

  @override
  void initState() {
    super.initState();
    final state = context.read<Property24State>();
    final token = state.token;
    _adminLandlords = state.user?.role == AccountRole.admin && token != null
        ? Property24Api()
              .adminUsers(token)
              .then(
                (users) => users
                    .where(
                      (user) =>
                          user['role'] == 'landlord' && user['active'] == true,
                    )
                    .toList(growable: false),
              )
        : Future.value(const <Map<String, dynamic>>[]);
    final property = widget.property;
    _title = TextEditingController(text: property?.title ?? '');
    _address = TextEditingController(text: property?.address ?? '');
    _city = TextEditingController(text: property?.city ?? 'Harare');
    _suburb = TextEditingController(text: property?.suburb ?? '');
    _latitude = TextEditingController(text: '${property?.latitude ?? ''}');
    _longitude = TextEditingController(text: '${property?.longitude ?? ''}');
    _rent = TextEditingController(text: property?.monthlyRent ?? '');
    _standReference = TextEditingController(
      text: property?.standReference ?? '',
    );
    _stands = TextEditingController(text: '${property?.standsAvailable ?? 1}');
    _landSize = TextEditingController(text: property?.landSize ?? '');
    _zoning = TextEditingController(text: property?.zoning ?? '');
    _roadAccess = TextEditingController(text: property?.roadAccess ?? '');
    _accommodationInstitution = TextEditingController(
      text: property?.accommodationInstitution ?? '',
    );
    final listingDetails = property?.listingDetails ?? const {};
    _nightlyRate = TextEditingController(
      text: '${listingDetails['nightly_rate'] ?? ''}',
    );
    _eventRate = TextEditingController(
      text: '${listingDetails['event_rate'] ?? ''}',
    );
    _roomTypes = TextEditingController(
      text: property?.roomTypes.join('\n') ?? '',
    );
    _listingAmenities = TextEditingController(
      text: property?.listingAmenities.join(', ') ?? '',
    );
    _activities = TextEditingController(
      text: property?.activities.join(', ') ?? '',
    );
    _venueFeatures = TextEditingController(
      text: property?.venueFeatures.join(', ') ?? '',
    );
    _maxGuests = TextEditingController(text: '${property?.maxGuests ?? ''}');
    _weddingCapacity = TextEditingController(
      text: '${property?.weddingCapacity ?? ''}',
    );
    _conferenceCapacity = TextEditingController(
      text: '${property?.conferenceCapacity ?? ''}',
    );
    _deposit = TextEditingController(text: property?.depositRequired ?? '');
    _beds = TextEditingController(text: '${property?.bedrooms ?? ''}');
    _baths = TextEditingController(text: '${property?.bathrooms ?? ''}');
    _landSizeUnit = property?.landSizeUnit ?? 'sqm';
    _titleDeedStatus = property?.titleDeedStatus ?? 'not_provided';
    _servicingStatus = property?.servicingStatus ?? 'not_serviced';
    _electricityAvailable = property?.electricityAvailable ?? false;
    _landWaterAvailable = property?.landWaterAvailable ?? false;
    _description = TextEditingController(text: property?.description ?? '');
    _water = TextEditingController(
      text: property?.waterAvailability ?? 'Available',
    );
    _parking = TextEditingController(
      text: property?.parking ?? 'Parking available',
    );
    _images = TextEditingController(text: property?.photos.join('\n') ?? '');
    _videos = TextEditingController(text: property?.videos.join('\n') ?? '');
    _audio = TextEditingController();
    _type =
        (property?.propertyType.toLowerCase().replaceAll(' ', '_') ?? 'house');
    _intent = property?.listingIntent == 'sale' ? 'Sale' : 'Rent';
    _furnished = property?.furnished ?? false;
    _solar = property?.solarPower ?? false;
    _borehole = property?.borehole ?? false;
    _pets = property?.petFriendly ?? false;
    _tour = property?.has360Tour ?? false;
    _showExactLocation = property?.showExactLocation ?? false;
    _sharedRoom = property?.sharedRoom ?? false;
    _listingCategories = property == null
        ? widget.initialCategories.toSet()
        : {...property.listingCategories};
    if (_listingCategories.isEmpty) _listingCategories = {'homes'};
    if (_listingCategories.contains('stays') ||
        _listingCategories.contains('venues')) {
      _intent = 'Rent';
    }
    _cateringAvailable = property?.cateringAvailable ?? false;
    _guestAccommodation = property?.guestAccommodation ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _address.dispose();
    _city.dispose();
    _suburb.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _rent.dispose();
    _deposit.dispose();
    _beds.dispose();
    _baths.dispose();
    _description.dispose();
    _water.dispose();
    _parking.dispose();
    _images.dispose();
    _videos.dispose();
    _audio.dispose();
    _standReference.dispose();
    _stands.dispose();
    _landSize.dispose();
    _zoning.dispose();
    _roadAccess.dispose();
    _accommodationInstitution.dispose();
    _nightlyRate.dispose();
    _eventRate.dispose();
    _roomTypes.dispose();
    _listingAmenities.dispose();
    _activities.dispose();
    _venueFeatures.dispose();
    _maxGuests.dispose();
    _weddingCapacity.dispose();
    _conferenceCapacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final isLand = _type == 'land';
    final isCommercialProperty = _type == 'office' || _type == 'shop';
    final hasHomes = _listingCategories.contains('homes');
    final hasStays = _listingCategories.contains('stays');
    final hasVenues = _listingCategories.contains('venues');
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(
          isLand
              ? widget.property == null
                    ? 'Add land listing'
                    : 'Edit land listing'
              : widget.property == null
              ? 'Add property'
              : 'Edit property',
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(CupertinoIcons.xmark),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, inset + 96),
          children: [
            _Section(
              title: 'Listing type',
              child: Builder(
                builder: (context) {
                  final colors = Theme.of(context).colorScheme;
                  if (isLand) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.tag_fill,
                            color: colors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'For sale',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            color: colors.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  }
                  return SegmentedButton<String>(
                    segments: [
                      if (!hasStays && !hasVenues)
                        const ButtonSegment(
                          value: 'Sale',
                          label: Text('For sale'),
                          icon: Icon(CupertinoIcons.tag),
                        ),
                      if (_type != 'land')
                        const ButtonSegment(
                          value: 'Rent',
                          label: Text('For rent'),
                          icon: Icon(CupertinoIcons.calendar),
                        ),
                    ],
                    selected: {_intent},
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? colors.onPrimary
                            : colors.onSurface,
                      ),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: colors.outlineVariant),
                      ),
                      shape: const WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                    ),
                    onSelectionChanged: (value) {
                      if (_type == 'land' && value.first == 'Rent') return;
                      setState(() => _intent = value.first);
                    },
                  );
                },
              ),
            ),
            _Section(
              title: 'Property details',
              child: Column(
                children: [
                  if (context.read<Property24State>().user?.role ==
                          AccountRole.admin &&
                      widget.property == null)
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _adminLandlords,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              userFacingError(snapshot.error!),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DropdownButtonFormField<String>(
                            initialValue: _ownerId,
                            decoration: _inputDeco('Listing owner'),
                            items: [
                              for (final landlord in snapshot.data ?? const [])
                                DropdownMenuItem(
                                  value: '${landlord['id']}',
                                  child: Text(
                                    '${landlord['name'] ?? landlord['email']}',
                                  ),
                                ),
                            ],
                            validator: (value) => value == null
                                ? 'Select the landlord who owns this listing'
                                : null,
                            onChanged: (value) =>
                                setState(() => _ownerId = value),
                          ),
                        );
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select every category that applies. One listing can appear in both Stays and Venues.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final category in const {
                              'homes': 'Homes',
                              'stays': 'Stays',
                              'venues': 'Venues',
                            }.entries)
                              FilterChip(
                                label: Text(category.value),
                                selected: _listingCategories.contains(
                                  category.key,
                                ),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _listingCategories.add(category.key);
                                      if (category.key != 'homes') {
                                        if (_type == 'land') _type = 'house';
                                        _intent = 'Rent';
                                      }
                                    } else if (_listingCategories.length > 1) {
                                      _listingCategories.remove(category.key);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _field(_title, 'Title'),
                  _field(_description, 'Details', maxLines: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: _inputDeco('Property type'),
                      items: const [
                        DropdownMenuItem(value: 'house', child: Text('House')),
                        DropdownMenuItem(value: 'flat', child: Text('Flat')),
                        DropdownMenuItem(
                          value: 'cottage',
                          child: Text('Cottage'),
                        ),
                        DropdownMenuItem(value: 'room', child: Text('Room')),
                        DropdownMenuItem(
                          value: 'office',
                          child: Text('Office'),
                        ),
                        DropdownMenuItem(value: 'shop', child: Text('Shop')),
                        DropdownMenuItem(
                          value: 'student_accommodation',
                          child: Text('Student accommodation'),
                        ),
                        DropdownMenuItem(
                          value: 'commercial_property',
                          child: Text('Commercial property'),
                        ),
                        DropdownMenuItem(
                          value: 'land',
                          child: Text('Land / Stand for sale'),
                        ),
                        DropdownMenuItem(value: 'lodge', child: Text('Lodge')),
                        DropdownMenuItem(
                          value: 'guest_house',
                          child: Text('Guest house'),
                        ),
                        DropdownMenuItem(value: 'hotel', child: Text('Hotel')),
                        DropdownMenuItem(
                          value: 'holiday_home',
                          child: Text('Holiday home'),
                        ),
                        DropdownMenuItem(
                          value: 'resort',
                          child: Text('Resort'),
                        ),
                        DropdownMenuItem(
                          value: 'self_catering_apartment',
                          child: Text('Self-catering apartment'),
                        ),
                        DropdownMenuItem(
                          value: 'camping_glamping',
                          child: Text('Camping / glamping'),
                        ),
                        DropdownMenuItem(
                          value: 'wedding_venue',
                          child: Text('Wedding venue'),
                        ),
                        DropdownMenuItem(
                          value: 'conference_venue',
                          child: Text('Conference venue'),
                        ),
                        DropdownMenuItem(
                          value: 'party_venue',
                          child: Text('Party venue'),
                        ),
                        DropdownMenuItem(
                          value: 'garden',
                          child: Text('Garden'),
                        ),
                        DropdownMenuItem(
                          value: 'function_hall',
                          child: Text('Function hall'),
                        ),
                        DropdownMenuItem(
                          value: 'corporate_event_space',
                          child: Text('Corporate event space'),
                        ),
                      ],
                      onChanged: (value) {
                        final next = value ?? 'house';
                        setState(() {
                          _type = next;
                          if (next == 'land') {
                            _intent = 'Sale';
                            _listingCategories = {'homes'};
                          }
                          if ({
                            'lodge',
                            'guest_house',
                            'hotel',
                            'holiday_home',
                            'resort',
                            'self_catering_apartment',
                            'camping_glamping',
                          }.contains(next)) {
                            _intent = 'Rent';
                            if (_listingCategories.length == 1 &&
                                _listingCategories.contains('homes')) {
                              _listingCategories.remove('homes');
                            }
                            _listingCategories.add('stays');
                          } else if ({
                            'wedding_venue',
                            'conference_venue',
                            'party_venue',
                            'garden',
                            'function_hall',
                            'corporate_event_space',
                          }.contains(next)) {
                            _intent = 'Rent';
                            if (_listingCategories.length == 1 &&
                                _listingCategories.contains('homes')) {
                              _listingCategories.remove('homes');
                            }
                            _listingCategories.add('venues');
                          }
                        });
                      },
                    ),
                  ),
                  if (_type == 'student_accommodation')
                    _field(
                      _accommodationInstitution,
                      'University, college or polytechnic (e.g. UZ or Harare Polytechnic)',
                    ),
                  if (_type == 'room' || _type == 'student_accommodation')
                    _switch(
                      'Shared room',
                      _sharedRoom,
                      (value) => setState(() => _sharedRoom = value),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Location',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _field(_city, 'City')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_suburb, 'Suburb')),
                    ],
                  ),
                  _field(
                    _address,
                    isLand
                        ? 'Stand location / address'
                        : isCommercialProperty
                        ? 'Office / shop address'
                        : 'Property address',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _latitude,
                          'Latitude',
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          requiredField: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          _longitude,
                          'Longitude',
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          requiredField: false,
                        ),
                      ),
                    ],
                  ),
                  _switch(
                    'Show exact map location publicly',
                    _showExactLocation,
                    (v) => setState(() => _showExactLocation = v),
                  ),
                ],
              ),
            ),
            _Section(
              title: isLand
                  ? 'Asking price'
                  : hasStays || hasVenues
                  ? 'Rates and capacity'
                  : isCommercialProperty
                  ? 'Rental details'
                  : 'Pricing and rooms',
              child: Column(
                children: [
                  if (hasHomes || (!hasStays && !hasVenues))
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            _rent,
                            isLand
                                ? 'Asking price'
                                : _intent == 'Sale'
                                ? 'Price'
                                : 'Monthly rent',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        if (!isLand) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field(
                              _deposit,
                              'Deposit',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (hasStays)
                    _field(
                      _nightlyRate,
                      'From price per night (USD)',
                      keyboardType: TextInputType.number,
                    ),
                  if (hasVenues)
                    _field(
                      _eventRate,
                      'From price per event (USD)',
                      keyboardType: TextInputType.number,
                    ),
                  if (!isLand &&
                      (!isCommercialProperty || hasStays) &&
                      (hasHomes || hasStays || (!hasHomes && !hasVenues)))
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            _beds,
                            'Bedrooms',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            _baths,
                            'Bathrooms',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (hasStays || hasVenues)
              _Section(
                title: 'Stay & venue details',
                child: Column(
                  children: [
                    if (hasStays) ...[
                      _field(
                        _maxGuests,
                        'Maximum guests',
                        keyboardType: TextInputType.number,
                        requiredField: false,
                      ),
                      _field(
                        _roomTypes,
                        'Rooms / accommodation types (one per line)',
                        maxLines: 3,
                        requiredField: false,
                      ),
                      _field(
                        _listingAmenities,
                        'Amenities (comma separated)',
                        maxLines: 2,
                        requiredField: false,
                      ),
                      _field(
                        _activities,
                        'Activities (comma separated)',
                        maxLines: 2,
                        requiredField: false,
                      ),
                    ],
                    if (hasVenues) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              _weddingCapacity,
                              'Wedding capacity',
                              keyboardType: TextInputType.number,
                              requiredField: false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field(
                              _conferenceCapacity,
                              'Conference capacity',
                              keyboardType: TextInputType.number,
                              requiredField: false,
                            ),
                          ),
                        ],
                      ),
                      _field(
                        _venueFeatures,
                        'Venue features (comma separated)',
                        maxLines: 2,
                        requiredField: false,
                      ),
                      _switch(
                        'Catering available',
                        _cateringAvailable,
                        (value) => setState(() => _cateringAvailable = value),
                      ),
                      _switch(
                        'Guest accommodation available',
                        _guestAccommodation,
                        (value) => setState(() => _guestAccommodation = value),
                      ),
                    ],
                  ],
                ),
              ),
            if (isLand)
              _Section(
                title: 'Land / stand details',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _field(_landSize, 'Plot size')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _landSizeUnit,
                            decoration: _inputDeco('Unit'),
                            items: const [
                              DropdownMenuItem(value: 'sqm', child: Text('m²')),
                              DropdownMenuItem(
                                value: 'hectares',
                                child: Text('Hectares'),
                              ),
                              DropdownMenuItem(
                                value: 'acres',
                                child: Text('Acres'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _landSizeUnit = value ?? 'sqm'),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            _stands,
                            'Stands available',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            _standReference,
                            'Stand / scheme reference',
                            requiredField: false,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DropdownButtonFormField<String>(
                        initialValue: _titleDeedStatus,
                        decoration: _inputDeco('Ownership document status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'title_deed',
                            child: Text('Title deed'),
                          ),
                          DropdownMenuItem(
                            value: 'cession',
                            child: Text('Cession'),
                          ),
                          DropdownMenuItem(
                            value: 'offer_allocation_letter',
                            child: Text('Offer / allocation letter'),
                          ),
                          DropdownMenuItem(
                            value: 'council_approved',
                            child: Text('Council approved'),
                          ),
                          DropdownMenuItem(
                            value: 'not_provided',
                            child: Text('Not provided'),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => _titleDeedStatus = value ?? 'not_provided',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DropdownButtonFormField<String>(
                        initialValue: _servicingStatus,
                        decoration: _inputDeco('Servicing status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'serviced',
                            child: Text('Serviced'),
                          ),
                          DropdownMenuItem(
                            value: 'partially_serviced',
                            child: Text('Partly serviced'),
                          ),
                          DropdownMenuItem(
                            value: 'not_serviced',
                            child: Text('Not serviced'),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => _servicingStatus = value ?? 'not_serviced',
                        ),
                      ),
                    ),
                    _field(_zoning, 'Zoning / permitted use'),
                    _field(_roadAccess, 'Road access', requiredField: false),
                    _switch(
                      'Electricity available',
                      _electricityAvailable,
                      (value) => setState(() => _electricityAvailable = value),
                    ),
                    _switch(
                      'Water available',
                      _landWaterAvailable,
                      (value) => setState(() => _landWaterAvailable = value),
                    ),
                    _switch(
                      'Borehole on site',
                      _borehole,
                      (value) => setState(() => _borehole = value),
                    ),
                  ],
                ),
              ),
            if (!isLand)
              _Section(
                title: 'Features',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _field(_water, 'Water availability')),
                        const SizedBox(width: 10),
                        Expanded(child: _field(_parking, 'Parking')),
                      ],
                    ),
                    _switch(
                      'Furnished',
                      _furnished,
                      (v) => setState(() => _furnished = v),
                    ),
                    _switch(
                      'Solar power',
                      _solar,
                      (v) => setState(() => _solar = v),
                    ),
                    _switch(
                      'Borehole',
                      _borehole,
                      (v) => setState(() => _borehole = v),
                    ),
                    _switch(
                      'Pet friendly',
                      _pets,
                      (v) => setState(() => _pets = v),
                    ),
                    _switch(
                      '360 tour / video walkthrough ready',
                      _tour,
                      (v) => setState(() => _tour = v),
                    ),
                  ],
                ),
              ),
            _Section(
              title: 'Photos & video',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickPhoto(camera: true),
                        icon: const Icon(CupertinoIcons.camera, size: 18),
                        label: const Text('Camera'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(
                          CupertinoIcons.photo_on_rectangle,
                          size: 18,
                        ),
                        label: const Text('Photos'),
                      ),
                    ],
                  ),
                  if (widget.property?.photos.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Current photos',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 86,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.property!.photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.property!.photos[index],
                            width: 112,
                            height: 86,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 112,
                              height: 86,
                              color: AppTheme.bgSurface,
                              alignment: Alignment.center,
                              child: const Icon(CupertinoIcons.photo),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_newImages.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Selected photos',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    for (final file in _newImages)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(
                          CupertinoIcons.photo,
                          color: AppTheme.accent,
                        ),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove photo',
                          onPressed: () =>
                              setState(() => _newImages.remove(file)),
                          icon: const Icon(CupertinoIcons.xmark_circle),
                        ),
                      ),
                  ],
                  const Divider(height: 28),
                  Text(
                    isLand ? 'Site video' : 'Video walkthrough',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickVideo(camera: true),
                        icon: const Icon(CupertinoIcons.videocam, size: 18),
                        label: Text(isLand ? 'Record site' : 'Record'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickVideo,
                        icon: const Icon(CupertinoIcons.film, size: 18),
                        label: Text(isLand ? 'Site video' : 'Video'),
                      ),
                    ],
                  ),
                  if (_newVideo != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        CupertinoIcons.film,
                        color: AppTheme.accent,
                      ),
                      title: Text(
                        _newVideo!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove video',
                        onPressed: () => setState(() => _newVideo = null),
                        icon: const Icon(CupertinoIcons.xmark_circle),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(widget.property == null ? 'Continue' : 'Save changes'),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───
  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _searchFill,
    labelStyle: TextStyle(color: _textMuted, fontWeight: FontWeight.w500),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _primary, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: _inputDeco(label),
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: _textDark),
        validator: (value) =>
            requiredField && (value == null || value.trim().isEmpty)
            ? 'Required'
            : null,
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: _primary,
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w500, color: _textDark),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Future<void> _pickPhoto({bool camera = false}) async {
    try {
      if (camera) {
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 100,
        );
        if (file != null && mounted) setState(() => _newImages.add(file));
        return;
      }
      final files = await _picker.pickMultiImage(imageQuality: 100);
      if (mounted && files.isNotEmpty) setState(() => _newImages.addAll(files));
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  Future<void> _pickVideo({bool camera = false}) async {
    try {
      final file = await _picker.pickVideo(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        maxDuration: const Duration(minutes: 2),
      );
      if (file != null && mounted) setState(() => _newVideo = file);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  List<String> _splitDetailList(String value, {bool linesOnly = false}) {
    final parts = value.split(linesOnly ? '\n' : RegExp(r'[,\n]'));
    return parts
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final isLandListing = _type == 'land';
    final isCommercialProperty = _type == 'office' || _type == 'shop';
    final hasHomes = _listingCategories.contains('homes');
    final hasStays = _listingCategories.contains('stays');
    final hasVenues = _listingCategories.contains('venues');
    final hasLatitude = _latitude.text.trim().isNotEmpty;
    final hasLongitude = _longitude.text.trim().isNotEmpty;
    if (hasLatitude != hasLongitude) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both latitude and longitude.')),
      );
      return;
    }
    final draft = PropertyDraft(
      title: _title.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      suburb: _suburb.text.trim(),
      latitude: _latitude.text.trim(),
      longitude: _longitude.text.trim(),
      showExactLocation: _showExactLocation,
      listingIntent: _intent.toLowerCase(),
      listingCategories: _listingCategories.toList(growable: false),
      listingDetails: {
        'nightly_rate': hasStays ? _nightlyRate.text.trim() : '',
        'event_rate': hasVenues ? _eventRate.text.trim() : '',
        'room_types': hasStays
            ? _splitDetailList(_roomTypes.text, linesOnly: true)
            : <String>[],
        'amenities': hasStays
            ? _splitDetailList(_listingAmenities.text)
            : <String>[],
        'activities': hasStays
            ? _splitDetailList(_activities.text)
            : <String>[],
        'venue_features': hasVenues
            ? _splitDetailList(_venueFeatures.text)
            : <String>[],
        'max_guests': hasStays ? _maxGuests.text.trim() : '',
        'wedding_capacity': hasVenues ? _weddingCapacity.text.trim() : '',
        'conference_capacity': hasVenues ? _conferenceCapacity.text.trim() : '',
        'catering_available': hasVenues && _cateringAvailable,
        'guest_accommodation': hasVenues && _guestAccommodation,
      },
      accommodationInstitution: _accommodationInstitution.text.trim(),
      sharedRoom:
          _sharedRoom && (_type == 'room' || _type == 'student_accommodation'),
      monthlyRent: hasHomes || (!hasStays && !hasVenues)
          ? _rent.text.trim()
          : hasStays
          ? _nightlyRate.text.trim()
          : _eventRate.text.trim(),
      depositRequired: isLandListing || !hasHomes ? '' : _deposit.text.trim(),
      propertyType: _type,
      ownerId: _ownerId,
      bedrooms:
          isLandListing ||
              (isCommercialProperty && !hasStays) ||
              (!hasHomes && !hasStays)
          ? 0
          : int.tryParse(_beds.text) ?? 0,
      bathrooms:
          isLandListing ||
              (isCommercialProperty && !hasStays) ||
              (!hasHomes && !hasStays)
          ? 0
          : num.tryParse(_baths.text) ?? 1,
      description: _description.text.trim(),
      waterAvailability: isLandListing ? '' : _water.text.trim(),
      parking: isLandListing ? '' : _parking.text.trim(),
      furnished: !isLandListing && _furnished,
      solarPower: !isLandListing && _solar,
      borehole: _borehole,
      petFriendly: !isLandListing && _pets,
      has360Tour: !isLandListing && _tour,
      standReference: isLandListing ? _standReference.text.trim() : '',
      standsAvailable: isLandListing ? int.tryParse(_stands.text) ?? 1 : 1,
      landSize: isLandListing ? _landSize.text.trim() : '',
      landSizeUnit: isLandListing ? _landSizeUnit : 'sqm',
      titleDeedStatus: isLandListing ? _titleDeedStatus : 'not_provided',
      servicingStatus: isLandListing ? _servicingStatus : 'not_serviced',
      zoning: isLandListing ? _zoning.text.trim() : '',
      roadAccess: isLandListing ? _roadAccess.text.trim() : '',
      electricityAvailable: isLandListing && _electricityAvailable,
      landWaterAvailable: isLandListing && _landWaterAvailable,
    );

    try {
      final state = context.read<Property24State>();
      final saved = await state.saveProperty(
        draft,
        propertyId: widget.property?.id,
      );
      for (final file in _newImages) {
        await state.uploadPropertyPhoto(saved.id, file);
      }
      if (_newVideo != null) {
        await state.uploadPropertyVideo(saved.id, _newVideo!);
      }
      await state.refresh();
      if (!mounted) return;
      await _showSuccessDialog();
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withValues(alpha: 0.16),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accent,
                    ),
                    child: const Icon(
                      CupertinoIcons.check_mark,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Congratulations!',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.property == null
                      ? 'Your property listed successfully.'
                      : 'Your listing was updated successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
