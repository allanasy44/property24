import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../models/zimbabwe_institutions.dart';
import '../services/device_location.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/async_value_view.dart';
import '../widgets/property_card.dart';
import 'ai_search_screen.dart';
import 'property_comparison_screen.dart';
import 'property_detail_screen.dart';
import 'marketplace_screen.dart';
import 'saved_searches_sheet.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    this.initialMarket,
    this.initialView = 'browse',
    this.initialQuery,
    this.createRequestId,
    super.key,
  });

  final String? initialMarket;
  final String initialView;
  final String? initialQuery;
  final String? createRequestId;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  String _type = 'Popular';
  late String _market;
  late String _marketView;
  late bool _createOnOpen;
  String? _createRequestId;
  String? _studentInstitution;
  double? _studentMaxDistanceKm;
  bool _studentSharedOnly = false;
  bool _studentVerifiedOnly = false;
  LatLng? _deviceLocation;
  _DiscoveryArea? _selectedArea;
  String? _locationError;
  bool _locationLoading = false;
  Property24State? _listenedState;
  final Set<String> _seenPropertyNotificationIds = <String>{};

  static Color get _textDark => AppTheme.textPrimary;
  static Color get _textMuted => AppTheme.textMuted;

  static const _discoveryModes = ['Popular', 'Nearby', 'Recommended'];
  static const _specialViews = ['Student stays', 'Shared rooms', 'Following'];

  @override
  void initState() {
    super.initState();
    _market = _normalizeMarket(widget.initialMarket);
    _marketView = widget.initialView;
    _query = widget.initialQuery ?? '';
    _searchController.text = _query;
    _createRequestId = widget.createRequestId;
    _createOnOpen = _createRequestId != null;
  }

  @override
  void didUpdateWidget(covariant DiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMarket != widget.initialMarket) {
      _market = _normalizeMarket(widget.initialMarket);
    }
    if (oldWidget.initialView != widget.initialView) {
      _marketView = widget.initialView;
    }
    if (oldWidget.initialQuery != widget.initialQuery) {
      _query = widget.initialQuery ?? '';
      _searchController.text = _query;
    }
    if (widget.createRequestId != oldWidget.createRequestId) {
      _createRequestId = widget.createRequestId;
      _createOnOpen = _createRequestId != null;
    }
  }

  String _normalizeMarket(String? value) => switch (value) {
    'stays' || 'venues' || 'services' || 'jobs' => value!,
    _ => 'properties',
  };

  static const _markets = [
    ('Properties', 'properties'),
    ('Stays', 'stays'),
    ('Venues', 'venues'),
    ('Services', 'services'),
    ('Jobs', 'jobs'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<Property24State>();
    if (identical(_listenedState, state)) return;
    _listenedState?.removeListener(_onPropertyNotification);
    _listenedState = state;
    _seenPropertyNotificationIds
      ..clear()
      ..addAll(
        state.allNotifications
            .where(
              (item) =>
                  item.kind.startsWith('property.') ||
                  item.kind == 'saved_search.match',
            )
            .map((item) => item.id),
      );
    state.addListener(_onPropertyNotification);
  }

  @override
  void dispose() {
    _listenedState?.removeListener(_onPropertyNotification);
    _searchController.dispose();
    super.dispose();
  }

  void _onPropertyNotification() {
    final state = _listenedState;
    if (!mounted || state == null || !state.signedIn) {
      return;
    }
    final notification = state.allNotifications.firstWhere(
      (item) =>
          (item.kind.startsWith('property.') ||
              item.kind == 'saved_search.match') &&
          !_seenPropertyNotificationIds.contains(item.id),
      orElse: () => const NotificationItem(
        id: '',
        kind: '',
        message: '',
        isRead: true,
        createdAt: '',
      ),
    );
    if (notification.id.isEmpty) return;
    _seenPropertyNotificationIds.add(notification.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(notification.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: notification.payload['property_id'] == null
              ? null
              : SnackBarAction(
                  label: 'View',
                  onPressed: () => _openAlertProperty(state, notification),
                ),
        ),
      );
  }

  Future<void> _openAlertProperty(
    Property24State state,
    NotificationItem notification,
  ) async {
    try {
      await state.refresh(silent: true);
      if (!mounted) return;
      final propertyId = '${notification.payload['property_id'] ?? ''}';
      final matches = state.snapshot.properties.where(
        (property) => property.id == propertyId,
      );
      if (matches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This property is no longer available.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PropertyDetailScreen(property: matches.first),
        ),
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(exception))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    if (_market == 'services' || _market == 'jobs') {
      return MarketplaceScreen(
        key: ValueKey('$_market-$_createRequestId'),
        market: _market,
        initialView: _marketView,
        createOnOpen: _createOnOpen,
        onSelectMarket: (market) => setState(() {
          _market = market;
          _marketView = 'browse';
          _createOnOpen = false;
          _createRequestId = null;
        }),
      );
    }
    final marketTitle = switch (_market) {
      'stays' => 'Stays',
      'venues' => 'Venues',
      _ => 'Properties',
    };
    final activeFilterCount = [
      _type != 'Popular',
      _studentInstitution != null,
      _studentSharedOnly,
      _studentVerifiedOnly,
      _studentMaxDistanceKm != null,
    ].where((active) => active).length;
    final sourceProperties = _type == 'Following'
        ? state.followedProperties
        : state.snapshot.properties;
    final institutions =
        <String>{
          ...zimbabweInstitutions,
          ...state.snapshot.properties
              .where(
                (property) =>
                    property.isStudentAccommodation &&
                    property.accommodationInstitution.trim().isNotEmpty,
              )
              .map((property) => property.accommodationInstitution.trim()),
        }.toList()..sort(
          (first, second) =>
              first.toLowerCase().compareTo(second.toLowerCase()),
        );
    var properties = sourceProperties.where((property) {
      if (property.owner?.id == state.user?.id ||
          property.agent?.id == state.user?.id) {
        return false;
      }
      final haystack = [
        property.title,
        property.address,
        property.city,
        property.suburb,
        property.propertyType,
        ...property.roomTypes,
        ...property.listingAmenities,
        ...property.activities,
        ...property.venueFeatures,
        property.accommodationInstitution,
        property.description,
        property.rentLabel,
        property.waterAvailability,
        property.parking,
        '${property.bedrooms} bedrooms',
        property.borehole ? 'borehole' : '',
        property.solarPower ? 'solar' : '',
      ].join(' ').toLowerCase();
      final matchesQuery =
          _query.trim().isEmpty || haystack.contains(_query.toLowerCase());
      return matchesQuery;
    }).toList();
    if (_market == 'stays') {
      properties = properties.where((property) => property.isStay).toList();
    } else if (_market == 'venues') {
      properties = properties.where((property) => property.isVenue).toList();
    } else {
      properties = properties
          .where(
            (property) =>
                property.listingCategories.contains('homes') ||
                !property.isStayOrVenue,
          )
          .toList();
    }
    if (_type == 'Student stays') {
      properties = properties
          .where((property) => property.isStudentAccommodation)
          .where(
            (property) =>
                _studentInstitution == null ||
                property.accommodationInstitution.toLowerCase() ==
                    _studentInstitution!.toLowerCase(),
          )
          .where((property) => !_studentSharedOnly || property.sharedRoom)
          .where((property) => !_studentVerifiedOnly || property.verified)
          .toList();
      if (_studentMaxDistanceKm != null && _deviceLocation == null) {
        properties = [];
      } else if (_deviceLocation case final location?) {
        properties =
            properties
                .where(
                  (property) =>
                      _distanceMeters(property, location) <=
                      (_studentMaxDistanceKm ?? double.infinity) * 1000,
                )
                .toList()
              ..sort(
                (first, second) => _distanceMeters(
                  first,
                  location,
                ).compareTo(_distanceMeters(second, location)),
              );
      } else {
        properties.sort(_newestFirst);
      }
    } else if (_type == 'Shared rooms') {
      properties = properties.where((property) => property.sharedRoom).toList();
      if (_deviceLocation case final location?) {
        properties.sort(
          (first, second) => _distanceMeters(
            first,
            location,
          ).compareTo(_distanceMeters(second, location)),
        );
      } else if (_selectedArea case final area?) {
        properties = properties.where(area.matches).toList()
          ..sort(_newestFirst);
      } else {
        properties.sort(_newestFirst);
      }
    } else if (_type == 'Nearby') {
      if (_deviceLocation case final location?) {
        properties.sort(
          (first, second) => _distanceMeters(
            first,
            location,
          ).compareTo(_distanceMeters(second, location)),
        );
      } else if (_selectedArea case final area?) {
        properties =
            properties.where((property) => area.matches(property)).toList()
              ..sort(_newestFirst);
      } else {
        properties = [];
      }
    } else if (_type == 'Recommended') {
      properties.sort(
        (first, second) => _recommendationScore(
          second,
          state,
        ).compareTo(_recommendationScore(first, state)),
      );
    } else if (_type == 'Popular') {
      properties.sort(
        (first, second) =>
            _popularityScore(second).compareTo(_popularityScore(first)),
      );
    }
    final now = DateTime.now();
    final newToday = properties.where((property) {
      final createdAt = localDateTime(property.createdAt);
      return createdAt != null && isSameLocalDay(createdAt, now);
    }).toList();
    final recentlyAdded = properties.where((property) {
      final createdAt = localDateTime(property.createdAt);
      return createdAt != null &&
          !createdAt.isAfter(now) &&
          !isSameLocalDay(createdAt, now) &&
          now.difference(createdAt) <= const Duration(days: 7);
    }).toList();
    recentlyAdded.sort(
      (first, second) => localDateTime(
        second.createdAt,
      )!.compareTo(localDateTime(first.createdAt)!),
    );
    List<PropertyListing> eventProperties(String kind) {
      final propertyIds = state.allNotifications
          .where(
            (notification) =>
                notification.kind == kind &&
                notification.occurredAt != null &&
                now.difference(notification.occurredAt!) <=
                    const Duration(days: 30),
          )
          .map((notification) => '${notification.payload['property_id'] ?? ''}')
          .where((id) => id.isNotEmpty)
          .toSet();
      return properties
          .where((property) => propertyIds.contains(property.id))
          .toList();
    }

    final priceReduced = eventProperties('property.price_reduced');
    final backOnMarket = eventProperties('property.back_on_market');
    final hasHighlights =
        newToday.isNotEmpty ||
        recentlyAdded.isNotEmpty ||
        priceReduced.isNotEmpty ||
        backOnMarket.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: LoadingOverlay(
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Explore $marketTitle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 24,
                                    height: 1.2,
                                    color: _textDark,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  switch (_market) {
                                    'stays' =>
                                      'Find a place to stay, near or far.',
                                    'venues' =>
                                      'Discover spaces for your next occasion.',
                                    _ => 'Find a home that feels right.',
                                  },
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ─── Property search controls ───
                      Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          onSubmitted: _submitSearch,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(color: _textDark, fontSize: 14),
                          decoration: InputDecoration(
                            filled: false,
                            hintText: switch (_market) {
                              'stays' => 'Search stays or locations',
                              'venues' => 'Search venues or locations',
                              _ => 'Search properties or locations',
                            },
                            hintStyle: TextStyle(
                              color: _textMuted,
                              fontSize: 12.5,
                            ),
                            prefixIcon: Icon(
                              CupertinoIcons.search,
                              color: _textMuted,
                              size: 19,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Search with AI',
                                  onPressed: () => _submitSearch(),
                                  icon: const Icon(
                                    CupertinoIcons.sparkles,
                                    color: AppTheme.accent,
                                    size: 19,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Sort and filters',
                                  onPressed: _showExploreFilters,
                                  icon: Badge(
                                    isLabelVisible: activeFilterCount > 0,
                                    label: Text('$activeFilterCount'),
                                    child: Icon(
                                      CupertinoIcons.slider_horizontal_3,
                                      color: _textMuted,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                if (state.signedIn)
                                  IconButton(
                                    tooltip: 'Saved searches',
                                    onPressed: () => openSavedSearches(context),
                                    icon: Badge(
                                      isLabelVisible:
                                          state.savedSearches.isNotEmpty,
                                      label: Text(
                                        state.savedSearches.length > 99
                                            ? '99+'
                                            : '${state.savedSearches.length}',
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.bookmark,
                                        color: _textMuted,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _markets.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final (label, value) = _markets[index];
                            final selected = _market == value;
                            return ChoiceChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _market = value;
                                  _type = 'Popular';
                                  _marketView = 'browse';
                                  _createOnOpen = false;
                                  _createRequestId = null;
                                });
                              },
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              selectedColor: AppTheme.accent,
                              backgroundColor: AppTheme.bgSurface,
                              side: BorderSide(color: AppTheme.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              showCheckmark: false,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 22),

                      if (_type != 'Popular')
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.slider_horizontal_3,
                                size: 15,
                                color: _textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Showing $_type',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => setState(() {
                                  _type = 'Popular';
                                  _studentInstitution = null;
                                  _studentSharedOnly = false;
                                  _studentVerifiedOnly = false;
                                  _studentMaxDistanceKm = null;
                                  _selectedArea = null;
                                }),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              if (_type == 'Student stays')
                SliverToBoxAdapter(
                  child: _StudentAccommodationFilters(
                    institutions: institutions,
                    institution: _studentInstitution,
                    sharedOnly: _studentSharedOnly,
                    verifiedOnly: _studentVerifiedOnly,
                    maxDistanceKm: _studentMaxDistanceKm,
                    locationAvailable: _deviceLocation != null,
                    locationLoading: _locationLoading,
                    locationError: _locationError,
                    onInstitutionChanged: (value) =>
                        setState(() => _studentInstitution = value),
                    onSharedChanged: (value) =>
                        setState(() => _studentSharedOnly = value),
                    onVerifiedChanged: (value) =>
                        setState(() => _studentVerifiedOnly = value),
                    onDistanceChanged: (value) =>
                        setState(() => _studentMaxDistanceKm = value),
                    onUseDeviceLocation: _requestDeviceLocation,
                  ),
                ),
              if (_type == 'Nearby' || _type == 'Shared rooms')
                SliverToBoxAdapter(
                  child: _NearbyLocationControl(
                    loading: _locationLoading,
                    error: _locationError,
                    selectedArea: _selectedArea?.label,
                    onUseDeviceLocation: _requestDeviceLocation,
                    onChooseArea: () => _chooseNearbyArea(sourceProperties),
                  ),
                ),
              if (_type != 'Nearby' &&
                  _type != 'Following' &&
                  _type != 'Stays' &&
                  _type != 'Venues' &&
                  _type != 'Student stays' &&
                  _type != 'Shared rooms') ...[
                _DiscoveryPropertySection(
                  title: '🔥 New properties today',
                  properties: newToday,
                  onOpen: (property) => _openDetails(context, property),
                ),
                _DiscoveryPropertySection(
                  title: 'Recently added',
                  properties: recentlyAdded,
                  onOpen: (property) => _openDetails(context, property),
                ),
                _DiscoveryPropertySection(
                  title: 'Price reduced',
                  properties: priceReduced,
                  onOpen: (property) => _openDetails(context, property),
                ),
                _DiscoveryPropertySection(
                  title: 'Back on the market',
                  properties: backOnMarket,
                  onOpen: (property) => _openDetails(context, property),
                ),
                if (_type == 'Recommended')
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Text(
                        'Ranked using your saved AI searches, budget fit, location and listing activity.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: ErrorBanner()),
              if (properties.isEmpty && !hasHighlights)
                SliverFillRemaining(
                  child: EmptyState(
                    icon: CupertinoIcons.search,
                    title: _type == 'Following'
                        ? 'No followed listings yet'
                        : _type == 'Stays'
                        ? 'No stays listed yet'
                        : _type == 'Venues'
                        ? 'No event venues listed yet'
                        : _type == 'Student stays' &&
                              _studentMaxDistanceKm != null &&
                              _deviceLocation == null
                        ? 'Set your location for distance filtering'
                        : _type == 'Student stays'
                        ? 'No student accommodation matches'
                        : _type == 'Shared rooms'
                        ? 'No shared rooms listed yet'
                        : _type == 'Nearby' && _selectedArea == null
                        ? 'Choose your nearby area'
                        : 'No matching listings',
                    body: _type == 'Following'
                        ? 'Follow a property manager or agent to see their listings here.'
                        : _type == 'Stays'
                        ? 'Browse lodges, guest houses, hotels, cottages, holiday homes, resorts and more.'
                        : _type == 'Venues'
                        ? 'Discover wedding, conference, party and other event venues.'
                        : _type == 'Student stays' &&
                              _studentMaxDistanceKm != null &&
                              _deviceLocation == null
                        ? 'Use your current location to find student accommodation within your selected distance.'
                        : _type == 'Student stays'
                        ? 'Try another institution or adjust shared-room, verification, or distance filters.'
                        : _type == 'Shared rooms'
                        ? 'Browse available shared-room listings or choose a nearby area.'
                        : _type == 'Nearby' && _selectedArea == null
                        ? 'Allow location access or choose a city or suburb to see nearby homes.'
                        : 'Try another suburb, city, or property type.',
                  ),
                )
              else if (_type == 'Nearby')
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: _MapExplorer(
                      properties: properties,
                      center: _nearbyMapCenter(properties),
                      distanceFor: _deviceLocation == null
                          ? null
                          : (property) => _formatDistance(
                              _distanceMeters(property, _deviceLocation!),
                            ),
                      onOpen: (property) => _openDetails(context, property),
                    ),
                  ),
                )
              else ...[
                if (state.comparedProperties.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ComparisonTray(
                      properties: state.comparedProperties,
                      suggestions: state.comparisonSuggestions,
                      onCompare: state.comparedProperties.length < 2
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PropertyComparisonScreen(
                                  properties: state.comparedProperties,
                                ),
                              ),
                            ),
                      onClear: () {
                        state.clearComparisons();
                      },
                      onAddSuggestion: (property) {
                        state.toggleComparison(property);
                      },
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList.builder(
                    itemCount: properties.length,
                    itemBuilder: (context, index) {
                      final property = properties[index];
                      return PropertyCard(
                        property: property,
                        distanceLabel:
                            (_type == 'Recommended' ||
                                    _type == 'Student stays' ||
                                    _type == 'Shared rooms') &&
                                _deviceLocation != null &&
                                _hasPrivacyAwareCoordinates(property)
                            ? _formatDistance(
                                _distanceMeters(property, _deviceLocation!),
                              )
                            : null,
                        saved: state.savedPropertyIds.contains(property.id),
                        compared: state.comparisonPropertyIds.contains(
                          property.id,
                        ),
                        onSave: () => state.toggleSaved(property),
                        onCompare: () => state.toggleComparison(property),
                        onTap: () => _openDetails(context, property),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestDeviceLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      final location = await getCurrentDeviceLocation();
      if (!mounted) return;
      setState(() {
        _deviceLocation = location;
        _selectedArea = null;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _deviceLocation = null;
        _locationError = exception is UnsupportedError
            ? 'Device location is unavailable here. Choose a city or suburb instead.'
            : 'Location permission was denied or unavailable. Choose a city or suburb instead.';
      });
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _chooseNearbyArea(List<PropertyListing> properties) async {
    final areas = <String, _DiscoveryArea>{};
    for (final property in properties) {
      if (property.city.trim().isEmpty && property.suburb.trim().isEmpty) {
        continue;
      }
      final area = _DiscoveryArea(
        city: property.city.trim(),
        suburb: property.suburb.trim(),
      );
      areas[area.label.toLowerCase()] = area;
    }
    final options = areas.values.toList()
      ..sort((first, second) => first.label.compareTo(second.label));
    if (options.isEmpty) {
      setState(() {
        _locationError =
            'No listing locations are available to choose from yet.';
      });
      return;
    }
    final selected = await showModalBottomSheet<_DiscoveryArea>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.bgCard,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Choose a city or suburb',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final area in options)
              ListTile(
                leading: const Icon(CupertinoIcons.location),
                title: Text(area.label),
                onTap: () => Navigator.of(context).pop(area),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedArea = selected;
      _deviceLocation = null;
      _locationError = null;
    });
  }

  LatLng? _nearbyMapCenter(List<PropertyListing> properties) {
    final location = _deviceLocation;
    if (location != null) return LatLng(location.latitude, location.longitude);
    final coordinates = properties
        .where(_hasPrivacyAwareCoordinates)
        .map(
          (property) => LatLng(
            property.mapLatitude!.toDouble(),
            property.mapLongitude!.toDouble(),
          ),
        )
        .toList(growable: false);
    if (coordinates.isEmpty) return null;
    return LatLng(
      coordinates.map((point) => point.latitude).reduce((a, b) => a + b) /
          coordinates.length,
      coordinates.map((point) => point.longitude).reduce((a, b) => a + b) /
          coordinates.length,
    );
  }

  int _recommendationScore(PropertyListing property, Property24State state) {
    final text = [
      property.title,
      property.description,
      property.city,
      property.suburb,
      property.propertyType,
    ].join(' ').toLowerCase();
    var bestSearchScore = 0;
    for (final search in state.savedSearches.where((item) => item.isActive)) {
      final criteria = search.criteria;
      var score = 0;
      final locations = criteria['locations'] is List
          ? (criteria['locations'] as List).map((value) => '$value')
          : ['${criteria['location'] ?? ''}'];
      if (locations.any(
        (location) =>
            location.trim().isNotEmpty &&
            '${property.city} ${property.suburb}'.toLowerCase().contains(
              location.toLowerCase(),
            ),
      )) {
        score += 35;
      }
      final minBedrooms = int.tryParse(
        '${criteria['min_bedrooms'] ?? criteria['bedrooms_min'] ?? ''}',
      );
      final maxBedrooms = int.tryParse(
        '${criteria['max_bedrooms'] ?? criteria['bedrooms_max'] ?? ''}',
      );
      if ((minBedrooms == null || property.bedrooms >= minBedrooms) &&
          (maxBedrooms == null || property.bedrooms <= maxBedrooms) &&
          (minBedrooms != null || maxBedrooms != null)) {
        score += 15;
      }
      final minPrice = num.tryParse(
        '${criteria['min_price'] ?? criteria['rent_min'] ?? ''}',
      );
      final maxPrice = num.tryParse(
        '${criteria['max_price'] ?? criteria['rent_max'] ?? ''}',
      );
      if ((minPrice == null || property.monthlyRentValue >= minPrice) &&
          (maxPrice == null || property.monthlyRentValue <= maxPrice) &&
          (minPrice != null || maxPrice != null)) {
        score += 20;
      }
      final propertyType = '${criteria['property_type'] ?? ''}'.toLowerCase();
      if (propertyType.isNotEmpty &&
          propertyType != 'unspecified' &&
          property.propertyType.toLowerCase().contains(propertyType)) {
        score += 15;
      }
      final intent = '${criteria['listing_intent'] ?? criteria['intent'] ?? ''}'
          .toLowerCase();
      if (intent.isNotEmpty && property.listingIntent.toLowerCase() == intent) {
        score += 10;
      }
      final amenities = criteria['required_amenities'];
      if (amenities is List) {
        score +=
            amenities
                .where((item) => _propertyHasAmenity(property, '$item', text))
                .length *
            5;
      }
      if (score > bestSearchScore) bestSearchScore = score;
    }
    final distanceScore =
        _deviceLocation != null && _hasPrivacyAwareCoordinates(property)
        ? (20 - _distanceMeters(property, _deviceLocation!) / 2500)
              .clamp(0, 20)
              .round()
        : 0;
    final popularityScore = _popularityScore(property).clamp(0, 15);
    final recencyScore = _recencyScore(property).clamp(0, 10);
    return bestSearchScore + distanceScore + popularityScore + recencyScore;
  }

  int _popularityScore(PropertyListing property) =>
      property.listingViews + property.savedCount * 4 + property.likesCount * 3;

  int _recencyScore(PropertyListing property) {
    final createdAt = localDateTime(property.createdAt);
    if (createdAt == null) return 0;
    final days = DateTime.now().difference(createdAt).inDays;
    if (days < 0 || days > 30) return 0;
    return (10 - days ~/ 3).clamp(0, 10);
  }

  static bool _propertyHasAmenity(
    PropertyListing property,
    String amenity,
    String listingText,
  ) {
    final normalized = amenity.toLowerCase().replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return false;
    return switch (normalized) {
      'borehole' => property.borehole,
      'solar' || 'solar power' => property.solarPower,
      'pet friendly' || 'pets' => property.petFriendly,
      'furnished' => property.furnished,
      'parking' => property.parking.trim().isNotEmpty,
      _ => listingText.contains(normalized),
    };
  }

  static int _newestFirst(PropertyListing first, PropertyListing second) {
    final firstDate = localDateTime(first.createdAt);
    final secondDate = localDateTime(second.createdAt);
    if (firstDate == null) return secondDate == null ? 0 : 1;
    if (secondDate == null) return -1;
    return secondDate.compareTo(firstDate);
  }

  static bool _hasPrivacyAwareCoordinates(PropertyListing property) {
    final latitude = property.mapLatitude;
    final longitude = property.mapLongitude;
    return latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  static double _distanceMeters(PropertyListing property, LatLng? origin) {
    if (origin == null || !_hasPrivacyAwareCoordinates(property)) {
      return double.infinity;
    }
    const earthRadiusMeters = 6371000.0;
    final latitude1 = origin.latitude * math.pi / 180;
    final latitude2 = property.mapLatitude!.toDouble() * math.pi / 180;
    final deltaLatitude =
        (property.mapLatitude!.toDouble() - origin.latitude) * math.pi / 180;
    final deltaLongitude =
        (property.mapLongitude!.toDouble() - origin.longitude) * math.pi / 180;
    final haversine =
        math.pow(math.sin(deltaLatitude / 2), 2) +
        math.cos(latitude1) *
            math.cos(latitude2) *
            math.pow(math.sin(deltaLongitude / 2), 2);
    return earthRadiusMeters * 2 * math.asin(math.sqrt(haversine));
  }

  static String _formatDistance(double meters) {
    if (!meters.isFinite) return '';
    final kilometers = meters / 1000;
    return kilometers < 1
        ? '${meters.round()} m'
        : '${kilometers.toStringAsFixed(kilometers < 10 ? 1 : 0)} km';
  }

  void _openDetails(BuildContext context, PropertyListing property) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyDetailScreen(property: property),
      ),
    );
  }

  Future<void> _submitSearch([String? submittedQuery]) async {
    final query = (submittedQuery ?? _searchController.text)
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (query.isEmpty) return;

    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() => _query = query);
    if (mounted) await _openAiSearch(query);
  }

  Future<void> _openAiSearch([String? initialQuery]) async {
    final query = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => AiSearchScreen(
          initialQuery: initialQuery ?? _query,
          searchScope: 'discover',
        ),
      ),
    );
    if (!mounted || query == null) return;
    _searchController.text = query;
    setState(() => _query = query);
  }

  Future<void> _showExploreFilters() async {
    final selection = await showModalBottomSheet<(String, bool)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        var draftMode = _type;
        var resetAll = false;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sort and filters',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            draftMode = 'Popular';
                            resetAll = true;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sort by',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mode in _discoveryModes)
                        _ExploreModeChip(
                          label: mode,
                          selected: draftMode == mode,
                          onSelected: () => setSheetState(() {
                            draftMode = mode;
                            resetAll = false;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'More ways to explore',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mode in _specialViews)
                        _ExploreModeChip(
                          label: mode,
                          selected: draftMode == mode,
                          onSelected: () => setSheetState(() {
                            draftMode = mode;
                            resetAll = false;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop((draftMode, resetAll)),
                      child: const Text('Show results'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || selection == null) return;
    setState(() {
      _type = selection.$1;
      if (selection.$2) {
        _studentInstitution = null;
        _studentSharedOnly = false;
        _studentVerifiedOnly = false;
        _studentMaxDistanceKm = null;
        _selectedArea = null;
      }
    });
  }
}

class _StudentAccommodationFilters extends StatelessWidget {
  const _StudentAccommodationFilters({
    required this.institutions,
    required this.institution,
    required this.sharedOnly,
    required this.verifiedOnly,
    required this.maxDistanceKm,
    required this.locationAvailable,
    required this.locationLoading,
    required this.locationError,
    required this.onInstitutionChanged,
    required this.onSharedChanged,
    required this.onVerifiedChanged,
    required this.onDistanceChanged,
    required this.onUseDeviceLocation,
  });

  final List<String> institutions;
  final String? institution;
  final bool sharedOnly;
  final bool verifiedOnly;
  final double? maxDistanceKm;
  final bool locationAvailable;
  final bool locationLoading;
  final String? locationError;
  final ValueChanged<String?> onInstitutionChanged;
  final ValueChanged<bool> onSharedChanged;
  final ValueChanged<bool> onVerifiedChanged;
  final ValueChanged<double?> onDistanceChanged;
  final VoidCallback onUseDeviceLocation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final distanceValue = maxDistanceKm == null
        ? 'any'
        : '${maxDistanceKm!.round()}';
    final availableInstitutions =
        <String>{
          ...institutions,
          if (institution != null && institution!.trim().isNotEmpty)
            institution!,
        }.toList()..sort(
          (first, second) =>
              first.toLowerCase().compareTo(second.toLowerCase()),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: institution ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'University, college or polytechnic',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All institutions'),
                    ),
                    for (final name in availableInstitutions)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) => onInstitutionChanged(
                    value?.isEmpty == true ? null : value,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: distanceValue,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'any', child: Text('Any distance')),
                  DropdownMenuItem(value: '5', child: Text('Within 5 km')),
                  DropdownMenuItem(value: '10', child: Text('Within 10 km')),
                  DropdownMenuItem(value: '20', child: Text('Within 20 km')),
                  DropdownMenuItem(value: '50', child: Text('Within 50 km')),
                ],
                onChanged: (value) => onDistanceChanged(
                  value == null || value == 'any' ? null : double.parse(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Shared rooms'),
                selected: sharedOnly,
                onSelected: onSharedChanged,
              ),
              FilterChip(
                label: const Text('Verified property managers'),
                selected: verifiedOnly,
                onSelected: onVerifiedChanged,
              ),
              ActionChip(
                avatar: locationLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : Icon(
                        locationAvailable
                            ? CupertinoIcons.location_fill
                            : CupertinoIcons.location,
                        size: 16,
                      ),
                label: Text(
                  locationAvailable ? 'Location on' : 'Use my location',
                ),
                onPressed: locationLoading ? null : onUseDeviceLocation,
              ),
            ],
          ),
          if (locationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                locationError!,
                style: TextStyle(color: colors.error, fontSize: 12),
              ),
            ),
          if (maxDistanceKm != null && !locationAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Enable location to apply the distance filter.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _NearbyLocationControl extends StatelessWidget {
  const _NearbyLocationControl({
    required this.loading,
    required this.error,
    required this.selectedArea,
    required this.onUseDeviceLocation,
    required this.onChooseArea,
  });

  final bool loading;
  final String? error;
  final String? selectedArea;
  final VoidCallback onUseDeviceLocation;
  final VoidCallback onChooseArea;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : onUseDeviceLocation,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CupertinoIcons.location, size: 17),
                label: Text(loading ? 'Finding you…' : 'Use my location'),
              ),
              OutlinedButton.icon(
                onPressed: onChooseArea,
                icon: const Icon(CupertinoIcons.map_pin_ellipse, size: 17),
                label: Text(selectedArea ?? 'Choose city or suburb'),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ] else if (selectedArea != null) ...[
            const SizedBox(height: 6),
            Text(
              'Showing listings in this area. Allow location access for distance-based results.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Choose an area or allow location access to sort homes by distance.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Notification bell button (circular, white, shadowed)
// ─────────────────────────────────────────────────────────────
class _DiscoveryPropertySection extends StatelessWidget {
  const _DiscoveryPropertySection({
    required this.title,
    required this.properties,
    required this.onOpen,
  });

  final String title;
  final List<PropertyListing> properties;
  final ValueChanged<PropertyListing> onOpen;

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 118,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: properties.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final property = properties[index];
                  return SizedBox(
                    width: 250,
                    child: Material(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onOpen(property),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                property.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '\$${property.monthlyRentValue.round()}',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}

class _DiscoveryArea {
  const _DiscoveryArea({required this.city, required this.suburb});

  final String city;
  final String suburb;

  String get label =>
      [suburb, city].where((item) => item.isNotEmpty).join(', ');

  bool matches(PropertyListing property) {
    return (city.isEmpty ||
            property.city.trim().toLowerCase() == city.toLowerCase()) &&
        (suburb.isEmpty ||
            property.suburb.trim().toLowerCase() == suburb.toLowerCase());
  }
}

// ─────────────────────────────────────────────────────────────
// Nearby map and location-priced listing markers.
// ─────────────────────────────────────────────────────────────
class _MapExplorer extends StatelessWidget {
  const _MapExplorer({
    required this.properties,
    required this.center,
    required this.distanceFor,
    required this.onOpen,
  });

  final List<PropertyListing> properties;
  final LatLng? center;
  final String Function(PropertyListing property)? distanceFor;
  final ValueChanged<PropertyListing> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 360,
            width: double.infinity,
            child: center == null
                ? ColoredBox(
                    color: AppTheme.bgSurface,
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Map locations will appear when listings include coordinates.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: center!,
                          initialZoom: 12,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.property24.zimbabwe',
                          ),
                          MarkerLayer(
                            markers: [
                              for (final property in properties.where(
                                _DiscoverScreenState
                                    ._hasPrivacyAwareCoordinates,
                              ))
                                Marker(
                                  point: LatLng(
                                    property.mapLatitude!.toDouble(),
                                    property.mapLongitude!.toDouble(),
                                  ),
                                  width: 112,
                                  height: 42,
                                  child: _MapPin(
                                    property: property,
                                    onTap: () => onOpen(property),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const Positioned(
                        right: 8,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            child: Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(fontSize: 9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (!properties.any(_DiscoverScreenState._hasPrivacyAwareCoordinates))
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('No listings with map coordinates in this area yet.'),
          ),
        for (final property in properties)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              CupertinoIcons.location,
              color: AppTheme.accent,
            ),
            title: Text(
              property.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                property.heroLocation,
                if (distanceFor != null) distanceFor!(property),
              ].where((item) => item.isNotEmpty).join(' · '),
            ),
            trailing: Text(property.rentLabel),
            onTap: () => onOpen(property),
          ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.property, required this.onTap});

  final PropertyListing property;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: property.title,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: property.verified ? AppTheme.trustHigh : AppTheme.accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Center(
              child: Text(
                property.rentLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Comparison tray (restyled)
// ─────────────────────────────────────────────────────────────
class _ComparisonTray extends StatelessWidget {
  const _ComparisonTray({
    required this.properties,
    required this.suggestions,
    required this.onCompare,
    required this.onClear,
    required this.onAddSuggestion,
  });

  final List<PropertyListing> properties;
  final List<ComparisonSuggestion> suggestions;
  final VoidCallback? onCompare;
  final VoidCallback onClear;
  final ValueChanged<PropertyListing> onAddSuggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Compare homes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onCompare,
                icon: const Icon(CupertinoIcons.arrow_left_right, size: 16),
                label: const Text('Compare now'),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final property in properties)
                  Container(
                    width: 172,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          property.rentLabel,
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${property.trustScore}% trust',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          property.isLand
                              ? '${property.landSizeLabel} · ${property.standSummary}'
                              : '${property.bedrooms} bed · ${property.bathrooms} bath',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (suggestions.isNotEmpty && properties.length < 3) ...[
            const SizedBox(height: 14),
            Text(
              'Suggested from live listings',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            for (final suggestion in suggestions.take(2))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  CupertinoIcons.sparkles,
                  size: 18,
                  color: AppTheme.accent,
                ),
                title: Text(
                  suggestion.property.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${suggestion.score}% match · ${suggestion.reasons.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                trailing: IconButton(
                  tooltip: 'Add to comparison',
                  onPressed: () => onAddSuggestion(suggestion.property),
                  icon: const Icon(CupertinoIcons.plus_circle_fill),
                  color: AppTheme.accent,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ExploreModeChip extends StatelessWidget {
  const _ExploreModeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.accent,
      backgroundColor: AppTheme.bgSurface,
      side: BorderSide(color: selected ? AppTheme.accent : AppTheme.border),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
