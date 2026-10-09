import 'package:intl/intl.dart';

String greetingForTime([DateTime? dateTime]) {
  final hour = (dateTime ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

enum AccountRole { tenant, landlord, agent, admin }

AccountRole accountRoleFromJson(Object? value) {
  return switch ('$value') {
    'landlord' => AccountRole.landlord,
    'agent' => AccountRole.agent,
    'admin' => AccountRole.admin,
    _ => AccountRole.tenant,
  };
}

extension AccountRoleLabel on AccountRole {
  String get apiValue => name;

  String get label {
    return switch (this) {
      AccountRole.tenant => 'Tenant',
      AccountRole.landlord => 'Landlord',
      AccountRole.agent => 'Agent',
      AccountRole.admin => 'Admin',
    };
  }
}

String textValue(
  Map<String, dynamic> json,
  String key, [
  String fallback = '',
]) {
  final value = json[key];
  if (value == null) return fallback;
  return '$value';
}

List<String> _listingCategoriesFromJson(Object? value) {
  if (value is! List) return const ['homes'];
  final categories = value.whereType<String>().toList(growable: false);
  return categories.isEmpty ? const ['homes'] : categories;
}

String titleize(Object? value) {
  final raw = '$value'.replaceAll('_', ' ').trim();
  if (raw.isEmpty || raw == 'null') return '';
  return raw
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

num? _coordinateValue(Map<String, dynamic> json, String key, int gpsIndex) {
  final value = json[key];
  final parsed = num.tryParse('$value');
  if (parsed != null) return parsed;
  final gps = '${json['gps'] ?? ''}'.split(',');
  if (gps.length > gpsIndex) return num.tryParse(gps[gpsIndex].trim());
  return null;
}

num? _roundCoordinate(num? value) {
  if (value == null) return null;
  return (value * 100).round() / 100;
}

String money(Object? value, {String suffix = ''}) {
  if (value == null || '$value'.isEmpty) {
    return suffix.isEmpty ? r'$0' : '\$0 $suffix';
  }
  final number = num.tryParse('$value');
  final amount = number == null
      ? '$value'
      : NumberFormat.currency(
          symbol: r'$',
          decimalDigits: number % 1 == 0 ? 0 : 2,
        ).format(number);
  return suffix.isEmpty ? amount : '$amount $suffix';
}

String localDate(Object? value, [String fallback = 'Updated']) {
  if (value == null || '$value'.isEmpty) return fallback;
  final date = DateTime.tryParse('$value');
  if (date == null) return '$value';
  return DateFormat.yMMMd().format(date.toLocal());
}

DateTime? localDateTime(Object? value) {
  if (value == null || '$value'.isEmpty) return null;
  return DateTime.tryParse('$value')?.toLocal();
}

bool isSameLocalDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String chatMessageTime(DateTime? date) =>
    date == null ? '' : DateFormat.jm().format(date);

String chatDateLabel(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  final today = now ?? DateTime.now();
  final localToday = DateTime(today.year, today.month, today.day);
  final localDate = DateTime(date.year, date.month, date.day);
  final difference = localToday.difference(localDate).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference > 1 && difference < 7) return DateFormat.EEEE().format(date);
  return DateFormat.yMMMd().format(date);
}

String chatConversationTime(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  if (isSameLocalDay(date, now)) return chatMessageTime(date);
  final yesterday = now.subtract(const Duration(days: 1));
  if (isSameLocalDay(date, yesterday)) return 'Yesterday';
  if (now.difference(date).inDays < 7) return DateFormat.E().format(date);
  return DateFormat.MMMd().format(date);
}

class AccountUser {
  const AccountUser({
    required this.id,
    required this.username,
    required this.name,
    required this.greeting,
    required this.email,
    required this.phone,
    required this.role,
    required this.verified,
    required this.emailVerified,
    required this.phoneVerified,
    required this.accountOnboardingComplete,
    required this.profilePicture,
    required this.coverPhoto,
    required this.bio,
  });

  factory AccountUser.fromJson(
    Map<String, dynamic> json, [
    Map<String, dynamic>? account,
  ]) {
    return AccountUser(
      id: textValue(json, 'id'),
      username: textValue(json, 'username', textValue(json, 'email')),
      name:
          textValue(json, 'name', textValue(json, 'email', 'Property24 user')),
      greeting: textValue(json, 'greeting', 'Good morning'),
      email: textValue(json, 'email'),
      phone: textValue(json, 'phone'),
      role: accountRoleFromJson(account?['account_type'] ?? json['role']),
      verified: json['verified'] == true || account?['is_verified'] == true,
      emailVerified:
          json['email_verified'] == true || account?['email_verified'] == true,
      phoneVerified:
          json['phone_verified'] == true || account?['phone_verified'] == true,
      accountOnboardingComplete: json['account_onboarding_complete'] == true ||
          account?['account_onboarding_complete'] == true,
      profilePicture: textValue(json, 'profile_picture'),
      coverPhoto: textValue(json, 'cover_photo'),
      bio: textValue(json, 'bio'),
    );
  }

  final String id;
  final String greeting;
  final String username;
  final String name;
  final String email;
  final String phone;
  final AccountRole role;
  final bool verified;
  final bool emailVerified;
  final bool phoneVerified;
  final bool accountOnboardingComplete;
  final String profilePicture;
  final String coverPhoto;
  final String bio;
}

class AccountContext {
  const AccountContext({
    required this.role,
    required this.isVerified,
    required this.emailVerified,
    required this.phoneVerified,
    required this.visibleSections,
    required this.capabilities,
    required this.onboardingRequirements,
    required this.fullVerificationRequired,
  });

  factory AccountContext.fromJson(Map<String, dynamic> json) {
    final onboarding = json['onboarding'] is Map<String, dynamic>
        ? json['onboarding'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AccountContext(
      role: accountRoleFromJson(json['account_type']),
      isVerified: json['is_verified'] == true,
      emailVerified: json['email_verified'] == true,
      phoneVerified: json['phone_verified'] == true,
      visibleSections: List<String>.from(json['visible_sections'] ?? const []),
      capabilities: List<String>.from(json['capabilities'] ?? const []),
      onboardingRequirements:
          List<String>.from(onboarding['requirements'] ?? const []),
      fullVerificationRequired:
          onboarding['full_verification_required'] == true,
    );
  }

  factory AccountContext.guest() {
    return const AccountContext(
      role: AccountRole.tenant,
      isVerified: false,
      emailVerified: false,
      phoneVerified: false,
      visibleSections: [
        'search',
        'applications',
        'inbox',
        'profile',
        'verification',
      ],
      capabilities: ['search_properties', 'save_properties'],
      onboardingRequirements: ['identity_verification'],
      fullVerificationRequired: false,
    );
  }

  final AccountRole role;
  final bool isVerified;
  final bool emailVerified;
  final bool phoneVerified;
  final List<String> visibleSections;
  final List<String> capabilities;
  final List<String> onboardingRequirements;
  final bool fullVerificationRequired;
}

class ServiceListing {
  const ServiceListing({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    required this.price,
    required this.priceType,
    required this.status,
    required this.owner,
    required this.createdAt,
  });

  factory ServiceListing.fromJson(Map<String, dynamic> json) {
    final ownerJson = json['owner'] is Map<String, dynamic>
        ? json['owner'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ServiceListing(
      id: textValue(json, 'id'),
      title: textValue(json, 'title'),
      category: textValue(json, 'category'),
      description: textValue(json, 'description'),
      location: textValue(json, 'location'),
      price: textValue(json, 'price'),
      priceType: textValue(json, 'price_type', 'fixed'),
      status: textValue(json, 'status', 'active'),
      owner: AccountUser.fromJson(ownerJson),
      createdAt: textValue(json, 'created_at'),
    );
  }

  final String id;
  final String title;
  final String category;
  final String description;
  final String location;
  final String price;
  final String priceType;
  final String status;
  final AccountUser owner;
  final String createdAt;
}

class ServiceRequestItem {
  const ServiceRequestItem({
    required this.id,
    required this.serviceId,
    required this.ownerId,
    required this.requesterId,
    required this.message,
    required this.status,
    required this.requester,
    required this.createdAt,
  });

  factory ServiceRequestItem.fromJson(Map<String, dynamic> json) {
    final requesterJson = json['requester'] is Map<String, dynamic>
        ? json['requester'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ServiceRequestItem(
      id: textValue(json, 'id'),
      serviceId: textValue(json, 'service_id'),
      ownerId: textValue(json, 'owner_id'),
      requesterId: textValue(json, 'requester_id'),
      message: textValue(json, 'message'),
      status: textValue(json, 'status', 'pending'),
      requester: AccountUser.fromJson(requesterJson),
      createdAt: textValue(json, 'created_at'),
    );
  }

  final String id;
  final String serviceId;
  final String ownerId;
  final String requesterId;
  final String message;
  final String status;
  final AccountUser requester;
  final String createdAt;
}

class JobPosting {
  const JobPosting({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    required this.employmentType,
    required this.compensation,
    required this.status,
    required this.owner,
    required this.createdAt,
  });

  factory JobPosting.fromJson(Map<String, dynamic> json) {
    final ownerJson = json['owner'] is Map<String, dynamic>
        ? json['owner'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return JobPosting(
      id: textValue(json, 'id'),
      title: textValue(json, 'title'),
      category: textValue(json, 'category'),
      description: textValue(json, 'description'),
      location: textValue(json, 'location'),
      employmentType: textValue(json, 'employment_type', 'full_time'),
      compensation: textValue(json, 'compensation'),
      status: textValue(json, 'status', 'active'),
      owner: AccountUser.fromJson(ownerJson),
      createdAt: textValue(json, 'created_at'),
    );
  }

  final String id;
  final String title;
  final String category;
  final String description;
  final String location;
  final String employmentType;
  final String compensation;
  final String status;
  final AccountUser owner;
  final String createdAt;
}

class JobApplicationItem {
  const JobApplicationItem({
    required this.id,
    required this.jobId,
    required this.ownerId,
    required this.applicantId,
    required this.coverMessage,
    required this.status,
    required this.applicant,
    required this.createdAt,
  });

  factory JobApplicationItem.fromJson(Map<String, dynamic> json) {
    final applicantJson = json['applicant'] is Map<String, dynamic>
        ? json['applicant'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return JobApplicationItem(
      id: textValue(json, 'id'),
      jobId: textValue(json, 'job_id'),
      ownerId: textValue(json, 'owner_id'),
      applicantId: textValue(json, 'applicant_id'),
      coverMessage: textValue(json, 'cover_message'),
      status: textValue(json, 'status', 'pending'),
      applicant: AccountUser.fromJson(applicantJson),
      createdAt: textValue(json, 'created_at'),
    );
  }

  final String id;
  final String jobId;
  final String ownerId;
  final String applicantId;
  final String coverMessage;
  final String status;
  final AccountUser applicant;
  final String createdAt;
}

class PropertyListing {
  const PropertyListing({
    required this.id,
    required this.title,
    required this.description,
    required this.address,
    required this.city,
    required this.suburb,
    required this.latitude,
    required this.longitude,
    required this.showExactLocation,
    this.listingCategories = const ['homes'],
    this.listingDetails = const {},
    required this.listingIntent,
    required this.availabilityStatus,
    required this.monthlyRent,
    required this.depositRequired,
    required this.propertyType,
    this.accommodationInstitution = '',
    this.sharedRoom = false,
    required this.bedrooms,
    required this.bathrooms,
    required this.furnished,
    required this.waterAvailability,
    required this.solarPower,
    required this.borehole,
    required this.parking,
    required this.petFriendly,
    required this.has360Tour,
    required this.verified,
    required this.photos,
    required this.videos,
    required this.listingViews,
    required this.savedCount,
    this.likesCount = 0,
    required this.applicationsCount,
    required this.owner,
    required this.agent,
    this.saved = false,
    this.reserved = false,
    this.backendTrustScore,
    this.trustBreakdown = const [],
    this.backendPassportId = '',
    this.createdAt = '',
    this.backendAvailabilityLabel = '',
    this.availabilityState = '',
    this.availableFrom = '',
    this.lastConfirmedAt = '',
    this.availabilityNeedsConfirmation = false,
    this.availabilityTemporarilyHidden = false,
    this.standReference = '',
    this.standsAvailable = 1,
    this.landSize = '',
    this.landSizeUnit = 'sqm',
    this.titleDeedStatus = 'not_provided',
    this.servicingStatus = 'not_serviced',
    this.zoning = '',
    this.roadAccess = '',
    this.electricityAvailable = false,
    this.landWaterAvailable = false,
    this.neighborhood = const NeighborhoodData.unavailable(),
  });

  factory PropertyListing.fromJson(Map<String, dynamic> json) {
    return PropertyListing(
      id: textValue(json, 'id'),
      title: textValue(json, 'title', 'Untitled property'),
      description: textValue(json, 'description'),
      address: textValue(json, 'address'),
      city: textValue(json, 'city'),
      suburb: textValue(json, 'suburb'),
      latitude: _coordinateValue(json, 'latitude', 0),
      longitude: _coordinateValue(json, 'longitude', 1),
      showExactLocation: json['show_exact_location'] == true,
      listingCategories: _listingCategoriesFromJson(json['listing_categories']),
      listingDetails: json['listing_details'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['listing_details'] as Map)
          : const {},
      listingIntent: textValue(json, 'listing_intent', 'rent'),
      availabilityStatus: textValue(json, 'availability_status', 'available'),
      monthlyRent: textValue(json, 'monthly_rent', '0'),
      depositRequired: textValue(json, 'deposit_required', '0'),
      propertyType: titleize(json['property_type']),
      accommodationInstitution:
          textValue(json, 'accommodation_institution'),
      sharedRoom: json['shared_room'] == true,
      bedrooms: int.tryParse('${json['bedrooms']}') ?? 0,
      bathrooms: num.tryParse('${json['bathrooms']}') ?? 0,
      furnished: json['furnished'] == true,
      waterAvailability: textValue(json, 'water_availability', 'Available'),
      solarPower: json['solar_power'] == true,
      borehole: json['borehole'] == true,
      parking: textValue(json, 'parking', 'Parking available'),
      petFriendly: json['pet_friendly'] == true,
      has360Tour: json['has_360_tour'] == true,
      verified: json['verified'] == true,
      photos: List<String>.from(json['photos'] ?? const []),
      videos: List<String>.from(json['videos'] ?? const []),
      listingViews: int.tryParse('${json['listing_views']}') ?? 0,
      savedCount: int.tryParse('${json['saved_count']}') ?? 0,
      likesCount: int.tryParse('${json['likes_count']}') ?? 0,
      applicationsCount: int.tryParse('${json['applications_count']}') ?? 0,
      owner: json['owner'] is Map<String, dynamic>
          ? AccountUser.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
      agent: json['agent'] is Map<String, dynamic>
          ? AccountUser.fromJson(json['agent'] as Map<String, dynamic>)
          : null,
      saved: json['saved'] == true,
      reserved: json['reserved'] == true,
      backendTrustScore: int.tryParse('${json['trust_score']}'),
      trustBreakdown: (json['trust_breakdown'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TrustSignal.fromJson)
          .toList(growable: false),
      backendPassportId: textValue(json, 'passport_id'),
      createdAt: textValue(json, 'created_at'),
      backendAvailabilityLabel: textValue(json, 'availability_label'),
      availabilityState: textValue(json, 'availability_state'),
      availableFrom: textValue(json, 'available_from'),
      lastConfirmedAt: localDate(json['last_confirmed_at'], ''),
      availabilityNeedsConfirmation:
          json['availability_needs_confirmation'] == true,
      availabilityTemporarilyHidden:
          json['availability_temporarily_hidden'] == true,
      standReference: textValue(json, 'stand_reference'),
      standsAvailable: int.tryParse('${json['stands_available']}') ?? 1,
      landSize: textValue(json, 'land_size'),
      landSizeUnit: textValue(json, 'land_size_unit', 'sqm'),
      titleDeedStatus: textValue(json, 'title_deed_status', 'not_provided'),
      servicingStatus: textValue(json, 'servicing_status', 'not_serviced'),
      zoning: textValue(json, 'zoning'),
      roadAccess: textValue(json, 'road_access'),
      electricityAvailable: json['electricity_available'] == true,
      landWaterAvailable: json['land_water_available'] == true,
      neighborhood: json['neighborhood'] is Map<String, dynamic>
          ? NeighborhoodData.fromJson(
              json['neighborhood'] as Map<String, dynamic>,
            )
          : const NeighborhoodData.unavailable(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String address;
  final String city;
  final String suburb;
  final num? latitude;
  final num? longitude;
  final bool showExactLocation;
  final List<String> listingCategories;
  final Map<String, dynamic> listingDetails;
  final String listingIntent;
  final String availabilityStatus;
  final String monthlyRent;
  final String depositRequired;
  final String propertyType;
  final String accommodationInstitution;
  final bool sharedRoom;
  final int bedrooms;
  final num bathrooms;
  final bool furnished;
  final String waterAvailability;
  final bool solarPower;
  final bool borehole;
  final String parking;
  final bool petFriendly;
  final bool has360Tour;
  final bool verified;
  final List<String> photos;
  final List<String> videos;
  final int listingViews;
  final int savedCount;
  final int likesCount;
  final int applicationsCount;
  final AccountUser? owner;
  final AccountUser? agent;
  final bool saved;
  final bool reserved;
  final int? backendTrustScore;
  final List<TrustSignal> trustBreakdown;
  final String backendPassportId;
  final String createdAt;
  final String backendAvailabilityLabel;
  final String availabilityState;
  final String availableFrom;
  final String lastConfirmedAt;
  final bool availabilityNeedsConfirmation;
  final bool availabilityTemporarilyHidden;
  final String standReference;
  final int standsAvailable;
  final String landSize;
  final String landSizeUnit;
  final String titleDeedStatus;
  final String servicingStatus;
  final String zoning;
  final String roadAccess;
  final bool electricityAvailable;
  final bool landWaterAvailable;
  final NeighborhoodData neighborhood;

  AccountUser? get supplier => agent ?? owner;
  bool get isStay => listingCategories.contains('stays');
  bool get isVenue => listingCategories.contains('venues');
  bool get isStayOrVenue => isStay || isVenue;
  String get nightlyRate => textValue(listingDetails, 'nightly_rate');
  String get eventRate => textValue(listingDetails, 'event_rate');
  List<String> get roomTypes => _listingDetailList('room_types');
  List<String> get listingAmenities => _listingDetailList('amenities');
  List<String> get activities => _listingDetailList('activities');
  List<String> get venueFeatures => _listingDetailList('venue_features');
  int get maxGuests => _listingDetailInt('max_guests');
  int get weddingCapacity => _listingDetailInt('wedding_capacity');
  int get conferenceCapacity => _listingDetailInt('conference_capacity');
  bool get cateringAvailable =>
      listingDetails['catering_available'] == true;
  bool get guestAccommodation =>
      listingDetails['guest_accommodation'] == true;
  String get rentLabel {
    if (isStay && nightlyRate.isNotEmpty) {
      return money(nightlyRate, suffix: '/ night');
    }
    if (isVenue && eventRate.isNotEmpty) {
      return money(eventRate, suffix: '/ event');
    }
    return listingIntent == 'sale'
        ? money(monthlyRent)
        : money(monthlyRent, suffix: '/ month');
  }
  bool get isLand => propertyType.toLowerCase().contains('land');
  bool get isStudentAccommodation =>
      propertyType.toLowerCase().contains('student accommodation');
  String get landSizeLabel => landSize.trim().isEmpty
      ? 'Size not provided'
      : '${landSize.trim()} $landSizeUnit';
  String get landTitleLabel => titleDeedStatus == 'not_provided'
      ? 'Title status not provided'
      : titleDeedStatus.replaceAll('_', ' ');
  String get landServicingLabel => servicingStatus == 'not_serviced'
      ? 'Not serviced'
      : servicingStatus.replaceAll('_', ' ');
  String get standSummary =>
      '${standsAvailable < 1 ? 1 : standsAvailable} ${standsAvailable == 1 ? 'stand' : 'stands'} available';

  String get depositLabel => money(depositRequired);
  String get location =>
      [suburb, city].where((value) => value.isNotEmpty).join(', ');
  String get heroLocation => location.isEmpty ? address : location;
  bool get hasCoordinates => latitude != null && longitude != null;
  num? get mapLatitude => hasCoordinates
      ? (showExactLocation ? latitude : _roundCoordinate(latitude))
      : null;
  num? get mapLongitude => hasCoordinates
      ? (showExactLocation ? longitude : _roundCoordinate(longitude))
      : null;
  String get availabilityLabel {
    if (backendAvailabilityLabel.isNotEmpty) return backendAvailabilityLabel;
    if (availabilityStatus == 'rented') return 'Rented';
    if (availabilityStatus == 'sold') return 'Sold';
    if (availabilityStatus == 'reserved') return 'Reserved';
    final date = DateTime.tryParse(availableFrom);
    return date == null
        ? 'Available'
        : 'Available from ${DateFormat('d MMM').format(date.toLocal())}';
  }

  String get passportId => backendPassportId.isNotEmpty
      ? backendPassportId
      : 'P24-${id.isEmpty ? title.hashCode.abs() : id.hashCode.abs()}';

  num get monthlyRentValue =>
      num.tryParse(monthlyRent.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  num get depositValue =>
      num.tryParse(depositRequired.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  num get estimatedFees => 0;
  num get moveInTotal => monthlyRentValue + depositValue + estimatedFees;
  String get moveInTotalLabel => money(moveInTotal);

  List<String> _listingDetailList(String key) {
    final values = listingDetails[key];
    if (values is! List) return const [];
    return values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  int _listingDetailInt(String key) =>
      int.tryParse('${listingDetails[key] ?? 0}') ?? 0;

  int get trustScore {
    if (backendTrustScore != null) return backendTrustScore!.clamp(0, 100);
    var score = 48;
    if (verified) score += 18;
    if (supplier?.verified == true) score += 12;
    if (photos.isNotEmpty) score += 6;
    if (address.isNotEmpty && city.isNotEmpty) score += 5;
    if (solarPower || borehole) score += 4;
    if (has360Tour) score += 5;
    return score.clamp(0, 100);
  }

  List<VerificationLevel> get verificationLevels {
    return [
      VerificationLevel(
        label: 'Identity verified',
        complete: supplier?.verified == true,
        detail: supplier?.verified == true
            ? 'Supplier identity checked'
            : 'Supplier must submit ID',
      ),
      VerificationLevel(
        label: 'Contact verified',
        complete:
            supplier?.emailVerified == true || supplier?.phoneVerified == true,
        detail: supplier?.phoneVerified == true
            ? 'Phone number confirmed'
            : 'Email or phone required',
      ),
      VerificationLevel(
        label: 'Authority verified',
        complete: verified && supplier?.role != AccountRole.tenant,
        detail: 'Ownership, mandate, or agent authority',
      ),
      VerificationLevel(
        label: 'Property verified',
        complete: verified,
        detail: verified
            ? 'Address and property facts checked'
            : 'Awaiting property check',
      ),
      VerificationLevel(
        label: 'Recently verified',
        complete: verified && trustScore >= 80,
        detail: availabilityLabel,
      ),
    ];
  }

  List<PropertyFact> get passportFacts {
    final isCommercialProperty = const {
      'office',
      'shop',
      'commercial property',
    }.contains(propertyType.toLowerCase());
    return [
      if (!isCommercialProperty)
        PropertyFact(iconName: 'bed', label: 'Bedrooms', value: '$bedrooms'),
      if (!isCommercialProperty)
        PropertyFact(iconName: 'bath', label: 'Bathrooms', value: '$bathrooms'),
      PropertyFact(iconName: 'type', label: 'Type', value: propertyType),
      if (isLand)
        PropertyFact(
          iconName: 'land',
          label: 'Land size',
          value: landSizeLabel,
        ),
      if (isLand)
        PropertyFact(iconName: 'stand', label: 'Stands', value: standSummary),
      if (isLand)
        PropertyFact(
          iconName: 'document',
          label: 'Title',
          value: landTitleLabel,
        ),
      if (isLand)
        PropertyFact(
          iconName: 'road',
          label: 'Servicing',
          value: landServicingLabel,
        ),
      PropertyFact(
        iconName: 'water',
        label: 'Water',
        value: borehole ? 'Borehole' : waterAvailability,
      ),
      PropertyFact(
        iconName: 'power',
        label: 'Power',
        value: solarPower ? 'Solar backup' : 'Grid only',
      ),
      PropertyFact(iconName: 'parking', label: 'Parking', value: parking),
    ];
  }
}

class NeighborhoodData {
  const NeighborhoodData({
    required this.available,
    required this.status,
    required this.waterReliability,
    required this.safetyScore,
    required this.commuteToCbdMinutes,
    required this.amenities,
    required this.sourceName,
    required this.verifiedAt,
  });

  const NeighborhoodData.unavailable()
      : available = false,
        status = 'not_available',
        waterReliability = null,
        safetyScore = null,
        commuteToCbdMinutes = null,
        amenities = const [],
        sourceName = '',
        verifiedAt = '';

  factory NeighborhoodData.fromJson(Map<String, dynamic> json) {
    return NeighborhoodData(
      available: json['available'] == true,
      status: textValue(json, 'status', 'not_available'),
      waterReliability: int.tryParse('${json['water_reliability']}'),
      safetyScore: int.tryParse('${json['safety_score']}'),
      commuteToCbdMinutes: int.tryParse('${json['commute_to_cbd_minutes']}'),
      amenities: List<String>.from(json['amenities'] ?? const []),
      sourceName: textValue(json, 'source_name'),
      verifiedAt: localDate(json['verified_at'], ''),
    );
  }

  final bool available;
  final String status;
  final int? waterReliability;
  final int? safetyScore;
  final int? commuteToCbdMinutes;
  final List<String> amenities;
  final String sourceName;
  final String verifiedAt;
}

class SavedSearchItem {
  const SavedSearchItem({
    required this.id,
    required this.name,
    required this.query,
    required this.isActive,
    required this.matchCount,
    required this.latestMatchAt,
    this.criteria = const <String, dynamic>{},
  });

  factory SavedSearchItem.fromJson(Map<String, dynamic> json) {
    return SavedSearchItem(
      id: textValue(json, 'id'),
      name: textValue(json, 'name'),
      query: textValue(json, 'query'),
      isActive: json['is_active'] == true,
      matchCount: int.tryParse('${json['match_count']}') ?? 0,
      latestMatchAt: localDate(json['latest_match_at'], ''),
      criteria: json['criteria'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['criteria'] as Map)
          : const <String, dynamic>{},
    );
  }

  final String id;
  final String name;
  final String query;
  final bool isActive;
  final int matchCount;
  final String latestMatchAt;
  final Map<String, dynamic> criteria;
}

class ComparisonSuggestion {
  const ComparisonSuggestion({
    required this.property,
    required this.score,
    required this.reasons,
  });

  factory ComparisonSuggestion.fromJson(Map<String, dynamic> json) {
    final property = json['property'] is Map<String, dynamic>
        ? PropertyListing.fromJson(json['property'] as Map<String, dynamic>)
        : PropertyListing.fromJson(json);
    return ComparisonSuggestion(
      property: property,
      score: int.tryParse('${json['score']}') ?? 0,
      reasons: List<String>.from(json['reasons'] ?? const []),
    );
  }

  final PropertyListing property;
  final int score;
  final List<String> reasons;
}

class AffordabilityResult {
  const AffordabilityResult({
    required this.moveInTotal,
    required this.rentToIncomePercent,
    required this.rentToDisposablePercent,
    required this.savingsShortfall,
    required this.assessment,
  });

  factory AffordabilityResult.fromJson(Map<String, dynamic> json) {
    return AffordabilityResult(
      moveInTotal: textValue(json, 'move_in_total', '0'),
      rentToIncomePercent: textValue(json, 'rent_to_income_percent', '0'),
      rentToDisposablePercent: textValue(json, 'rent_to_disposable_percent'),
      savingsShortfall: textValue(json, 'savings_shortfall', '0'),
      assessment: textValue(json, 'assessment'),
    );
  }

  final String moveInTotal;
  final String rentToIncomePercent;
  final String rentToDisposablePercent;
  final String savingsShortfall;
  final String assessment;
}

class TrustSignal {
  const TrustSignal({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.complete,
    required this.detail,
  });

  factory TrustSignal.fromJson(Map<String, dynamic> json) {
    return TrustSignal(
      label: textValue(json, 'label'),
      score: int.tryParse('${json['score']}') ?? 0,
      maxScore: int.tryParse('${json['max_score']}') ?? 0,
      complete: json['complete'] == true,
      detail: textValue(json, 'detail'),
    );
  }

  final String label;
  final int score;
  final int maxScore;
  final bool complete;
  final String detail;
}

class AiSearchResponse {
  const AiSearchResponse({
    required this.query,
    required this.intent,
    required this.requirements,
    required this.explanation,
    required this.results,
    required this.sessionId,
    required this.totalMatches,
    required this.exactMatches,
    required this.closeMatches,
    required this.clarificationQuestion,
    required this.parser,
  });

  factory AiSearchResponse.fromJson(Map<String, dynamic> json) {
    return AiSearchResponse(
      query: textValue(json, 'query'),
      intent: json['intent'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['intent'] as Map)
          : const <String, dynamic>{},
      requirements: json['interpreted_requirements'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              json['interpreted_requirements'] as Map,
            )
          : const <String, dynamic>{},
      explanation: textValue(json, 'explanation'),
      results: (json['results'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AiSearchCandidate.fromJson)
          .toList(growable: false),
      sessionId: textValue(json, 'session_id'),
      totalMatches: int.tryParse('${json['total_matches']}') ??
          (json['results'] as List<dynamic>? ?? const []).length,
      exactMatches: int.tryParse('${json['exact_matches']}') ?? 0,
      closeMatches: int.tryParse('${json['close_matches']}') ?? 0,
      clarificationQuestion: textValue(json, 'clarification_question'),
      parser: textValue(json, 'parser'),
    );
  }

  final String query;
  final Map<String, dynamic> intent;
  final Map<String, dynamic> requirements;
  final String explanation;
  final List<AiSearchCandidate> results;
  final String sessionId;
  final int totalMatches;
  final int exactMatches;
  final int closeMatches;
  final String clarificationQuestion;
  final String parser;
}

class AiSearchCandidate {
  const AiSearchCandidate({
    required this.property,
    required this.score,
    required this.reasons,
    required this.matchType,
    required this.missingRequirements,
    required this.missingPreferences,
  });

  factory AiSearchCandidate.fromJson(Map<String, dynamic> json) {
    final propertyJson = json['property'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['property'] as Map)
        : json;
    return AiSearchCandidate(
      property: PropertyListing.fromJson(propertyJson),
      score: int.tryParse(
            '${json['match_score'] ?? json['search_score']}',
          ) ??
          0,
      reasons: List<String>.from(json['match_reasons'] ?? const []),
      matchType: textValue(json, 'match_type', 'exact'),
      missingRequirements:
          List<String>.from(json['missing_requirements'] ?? const []),
      missingPreferences:
          List<String>.from(json['missing_preferences'] ?? const []),
    );
  }

  final PropertyListing property;
  final int score;
  final List<String> reasons;
  final String matchType;
  final List<String> missingRequirements;
  final List<String> missingPreferences;
}

class VerificationLevel {
  const VerificationLevel({
    required this.label,
    required this.complete,
    required this.detail,
  });

  final String label;
  final bool complete;
  final String detail;
}

class PropertyFact {
  const PropertyFact({
    required this.iconName,
    required this.label,
    required this.value,
  });

  final String iconName;
  final String label;
  final String value;
}

class ApplicationItem {
  const ApplicationItem({
    required this.id,
    required this.applicant,
    required this.property,
    required this.status,
    required this.score,
    required this.createdAt,
  });

  factory ApplicationItem.fromJson(Map<String, dynamic> json) {
    return ApplicationItem(
      id: textValue(json, 'id'),
      applicant: textValue(json, 'tenant'),
      property: textValue(json, 'property'),
      status: titleize(json['status']),
      score: int.tryParse('${json['score']}') ?? 0,
      createdAt: localDate(json['created_at'], 'Submitted'),
    );
  }

  final String id;
  final String applicant;
  final String property;
  final String status;
  final int score;
  final String createdAt;
}

class VerificationItem {
  const VerificationItem({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.checks,
    required this.ocrConfidence,
    required this.extractedDateOfBirth,
    required this.duplicateDocument,
    this.failureReason = '',
    this.verificationProvider = '',
    this.verificationScore = '',
    this.frontDocumentUploaded = false,
    this.backDocumentUploaded = false,
  });

  factory VerificationItem.fromJson(Map<String, dynamic> json) {
    return VerificationItem(
      id: textValue(json, 'id'),
      name: textValue(json, 'name'),
      role: titleize(json['role']),
      status: titleize(json['status']),
      checks: (json['checks'] as List<dynamic>? ?? const []).map((check) {
        if (check is Map<String, dynamic>) {
          return '${titleize(check['type'])}: ${check['details'] ?? check['result'] ?? 'review'}';
        }
        return '$check';
      }).toList(),
      ocrConfidence: textValue(json, 'ocr_confidence'),
      extractedDateOfBirth: textValue(json, 'extracted_date_of_birth'),
      duplicateDocument: json['duplicate_document'] == true,
      failureReason: textValue(json, 'failure_reason'),
      verificationProvider: textValue(json, 'verification_provider'),
      verificationScore: textValue(json, 'verification_score'),
      frontDocumentUploaded: json['id_front_document_uploaded'] == true,
      backDocumentUploaded: json['id_back_document_uploaded'] == true,
    );
  }

  final String id;
  final String name;
  final String role;
  final String status;
  final List<String> checks;
  final String ocrConfidence;
  final String extractedDateOfBirth;
  final bool duplicateDocument;
  final String failureReason;
  final String verificationProvider;
  final String verificationScore;
  final bool frontDocumentUploaded;
  final bool backDocumentUploaded;
}

class ViewingItem {
  const ViewingItem({
    required this.id,
    required this.propertyId,
    required this.property,
    required this.tenant,
    required this.agent,
    required this.scheduledFor,
    required this.status,
    required this.notes,
    this.conversationId = '',
  });

  factory ViewingItem.fromJson(Map<String, dynamic> json) {
    return ViewingItem(
      id: textValue(json, 'id'),
      propertyId: textValue(json, 'property_id'),
      property: textValue(json, 'property'),
      tenant: textValue(json, 'tenant'),
      agent: textValue(json, 'agent'),
      scheduledFor: _viewingDateTime(json['scheduled_for']),
      status: titleize(json['status']),
      notes: textValue(json, 'notes'),
      conversationId: textValue(json, 'conversation_id'),
    );
  }

  final String id;
  final String propertyId;
  final String property;
  final String tenant;
  final String agent;
  final String scheduledFor;
  final String status;
  final String notes;
  final String conversationId;

  bool get isAvailableBooking {
    final normalized = status.toLowerCase();
    return normalized == 'pending' ||
        normalized == 'confirmed' ||
        normalized == 'reserved';
  }
}

String _viewingDateTime(Object? value) {
  final date = localDateTime(value);
  return date == null ? 'Scheduled' : DateFormat.yMMMd().add_jm().format(date);
}

class ChatMessageItem {
  const ChatMessageItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.sender,
    required this.body,
    required this.createdAt,
    this.createdAtDate,
    required this.attachmentUrl,
    required this.attachmentType,
    required this.attachmentName,
    required this.deleted,
    required this.deliveryStatus,
  });

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    final createdAtDate = localDateTime(json['created_at']);
    return ChatMessageItem(
      id: textValue(json, 'id'),
      conversationId: textValue(json, 'conversation_id'),
      senderId: textValue(json, 'sender_id'),
      sender: textValue(json, 'sender', 'Property24 user'),
      body: textValue(json, 'body'),
      createdAt: createdAtDate == null
          ? localDate(json['created_at'], 'Just now')
          : chatMessageTime(createdAtDate),
      createdAtDate: createdAtDate,
      attachmentUrl: textValue(json, 'attachment_url'),
      attachmentType: textValue(json, 'attachment_type'),
      attachmentName: textValue(json, 'attachment_name'),
      deleted: json['deleted'] == true,
      deliveryStatus: textValue(json, 'delivery_status', 'sent'),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String sender;
  final String body;
  final String createdAt;
  final DateTime? createdAtDate;
  final String attachmentUrl;
  final String attachmentType;
  final String attachmentName;
  final bool deleted;
  final String deliveryStatus;
}

class PropertyCommentItem {
  const PropertyCommentItem({
    required this.id,
    required this.propertyId,
    required this.author,
    required this.authorId,
    required this.parentId,
    required this.body,
    required this.mediaUrl,
    required this.likesCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PropertyCommentItem.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json['author'];
    return PropertyCommentItem(
      id: textValue(json, 'id'),
      propertyId: textValue(json, 'property_id'),
      author: rawAuthor is Map
          ? AccountUser.fromJson(Map<String, dynamic>.from(rawAuthor))
          : AccountUser.fromJson(const {}),
      authorId: textValue(json, 'author_id'),
      parentId: textValue(json, 'parent_id'),
      body: textValue(json, 'body'),
      mediaUrl: textValue(json, 'media_url'),
      likesCount: int.tryParse('${json['likes_count'] ?? 0}') ?? 0,
      createdAt: localDate(json['created_at'], 'Just now'),
      updatedAt: localDate(json['updated_at'], 'Just now'),
    );
  }

  final String id;
  final String propertyId;
  final AccountUser author;
  final String authorId;
  final String parentId;
  final String body;
  final String mediaUrl;
  final int likesCount;
  final String createdAt;
  final String updatedAt;
}

class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.preview,
    required this.updatedAt,
    this.updatedAtDate,
    required this.phoneNumbersRevealed,
    required this.participants,
    required this.unreadCount,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'];
    final participants = (rawParticipants is List ? rawParticipants : const [])
        .whereType<Map>()
        .map(
          (participant) => AccountUser.fromJson(
            Map<String, dynamic>.from(participant),
          ),
        )
        .toList();
    final rawLastMessage = json['last_message'];
    final lastMessage = rawLastMessage is Map
        ? Map<String, dynamic>.from(rawLastMessage)
        : null;
    final updatedAtDate = localDateTime(
      json['updated_at'] ?? lastMessage?['created_at'],
    );
    return ConversationItem(
      id: textValue(json, 'id'),
      propertyId: textValue(json, 'property_id'),
      title: textValue(
        json,
        'title',
        participants.map((user) => user.name).join(' and '),
      ),
      preview: textValue(
        lastMessage ?? const {},
        'body',
        'Phone numbers remain hidden.',
      ),
      updatedAt: chatConversationTime(updatedAtDate),
      updatedAtDate: updatedAtDate,
      phoneNumbersRevealed: json['phone_numbers_revealed'] == true,
      participants: participants,
      unreadCount: int.tryParse('${json['unread_count'] ?? 0}') ?? 0,
    );
  }

  final String id;
  final String propertyId;
  final String title;
  final String preview;
  final String updatedAt;
  final DateTime? updatedAtDate;
  final bool phoneNumbersRevealed;
  final List<AccountUser> participants;
  final int unreadCount;

  ConversationItem copyWith({int? unreadCount}) {
    return ConversationItem(
      id: id,
      propertyId: propertyId,
      title: title,
      preview: preview,
      updatedAt: updatedAt,
      updatedAtDate: updatedAtDate,
      phoneNumbersRevealed: phoneNumbersRevealed,
      participants: participants,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

enum CallMode { voice, video }

class CallLogItem {
  const CallLogItem({
    this.id = '',
    required this.name,
    required this.property,
    required this.mode,
    required this.direction,
    required this.when,
    this.status = '',
    this.conversationId = '',
    this.initiatorId = '',
    this.contactId = '',
  });

  factory CallLogItem.fromJson(Map<String, dynamic> json) {
    final status = titleize(json['status']);
    return CallLogItem(
      id: textValue(json, 'id'),
      name: textValue(json, 'contact_name', 'Property24 contact'),
      property: textValue(json, 'property_title', 'Property conversation'),
      mode: textValue(json, 'mode', 'voice') == 'video'
          ? CallMode.video
          : CallMode.voice,
      direction: status == 'Missed' ? 'Missed' : 'Call',
      when: localDate(json['created_at'], 'Recent'),
      status: status,
      conversationId: textValue(json, 'conversation_id'),
      initiatorId: textValue(json, 'initiator_id'),
      contactId: textValue(json, 'contact_id'),
    );
  }

  final String id;
  final String name;
  final String property;
  final CallMode mode;
  final String direction;
  final String when;
  final String status;
  final String conversationId;
  final String initiatorId;
  final String contactId;
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.kind,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.payload = const <String, dynamic>{},
    this.occurredAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: textValue(json, 'id'),
      kind: textValue(json, 'kind', 'general'),
      message: textValue(json, 'message', 'New notification'),
      isRead: json['is_read'] == true,
      createdAt: localDate(json['created_at'], 'Just now'),
      payload: json['payload'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const <String, dynamic>{},
      occurredAt: localDateTime(json['created_at']),
    );
  }

  final String id;
  final String kind;
  final String message;
  final bool isRead;
  final String createdAt;
  final Map<String, dynamic> payload;
  final DateTime? occurredAt;

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      kind: kind,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      payload: payload,
      occurredAt: occurredAt,
    );
  }
}

class PlatformSnapshot {
  const PlatformSnapshot({
    required this.properties,
    required this.applications,
    required this.verifications,
    required this.conversations,
    required this.viewings,
    required this.calls,
    required this.savedProperties,
    required this.comparisonProperties,
    required this.comparisonSuggestions,
    required this.savedSearches,
    required this.notifications,
    this.services = const [],
    this.serviceRequests = const [],
    this.jobs = const [],
    this.jobApplications = const [],
  });

  factory PlatformSnapshot.empty() {
    return const PlatformSnapshot(
      properties: [],
      applications: [],
      verifications: [],
      conversations: [],
      viewings: [],
      calls: [],
      savedProperties: [],
      comparisonProperties: [],
      comparisonSuggestions: [],
      savedSearches: [],
      notifications: [],
      services: [],
      serviceRequests: [],
      jobs: [],
      jobApplications: [],
    );
  }

  final List<PropertyListing> properties;
  final List<ApplicationItem> applications;
  final List<VerificationItem> verifications;
  final List<ConversationItem> conversations;
  final List<ViewingItem> viewings;
  final List<CallLogItem> calls;
  final List<PropertyListing> savedProperties;
  final List<PropertyListing> comparisonProperties;
  final List<ComparisonSuggestion> comparisonSuggestions;
  final List<SavedSearchItem> savedSearches;
  final List<NotificationItem> notifications;
  final List<ServiceListing> services;
  final List<ServiceRequestItem> serviceRequests;
  final List<JobPosting> jobs;
  final List<JobApplicationItem> jobApplications;

  PlatformSnapshot copyWith({
    List<PropertyListing>? properties,
    List<ApplicationItem>? applications,
    List<VerificationItem>? verifications,
    List<ConversationItem>? conversations,
    List<ViewingItem>? viewings,
    List<CallLogItem>? calls,
    List<PropertyListing>? savedProperties,
    List<PropertyListing>? comparisonProperties,
    List<ComparisonSuggestion>? comparisonSuggestions,
    List<SavedSearchItem>? savedSearches,
    List<NotificationItem>? notifications,
    List<ServiceListing>? services,
    List<ServiceRequestItem>? serviceRequests,
    List<JobPosting>? jobs,
    List<JobApplicationItem>? jobApplications,
  }) {
    return PlatformSnapshot(
      properties: properties ?? this.properties,
      applications: applications ?? this.applications,
      verifications: verifications ?? this.verifications,
      conversations: conversations ?? this.conversations,
      viewings: viewings ?? this.viewings,
      calls: calls ?? this.calls,
      savedProperties: savedProperties ?? this.savedProperties,
      comparisonProperties: comparisonProperties ?? this.comparisonProperties,
      comparisonSuggestions:
          comparisonSuggestions ?? this.comparisonSuggestions,
      savedSearches: savedSearches ?? this.savedSearches,
      notifications: notifications ?? this.notifications,
      services: services ?? this.services,
      serviceRequests: serviceRequests ?? this.serviceRequests,
      jobs: jobs ?? this.jobs,
      jobApplications: jobApplications ?? this.jobApplications,
    );
  }
}
