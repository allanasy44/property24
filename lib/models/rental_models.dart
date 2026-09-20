import 'package:intl/intl.dart';

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

String textValue(Map<String, dynamic> json, String key,
    [String fallback = '']) {
  final value = json[key];
  if (value == null) return fallback;
  return '$value';
}

String titleize(Object? value) {
  final raw = '$value'.replaceAll('_', ' ').trim();
  if (raw.isEmpty || raw == 'null') return '';
  return raw
      .split(RegExp(r'\s+'))
      .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
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
  if (value == null || '$value'.isEmpty)
    return suffix.isEmpty ? r'$0' : '\$0 $suffix';
  final number = num.tryParse('$value');
  final amount = number == null
      ? '$value'
      : NumberFormat.currency(
              symbol: r'$', decimalDigits: number % 1 == 0 ? 0 : 2)
          .format(number);
  return suffix.isEmpty ? amount : '$amount $suffix';
}

String localDate(Object? value, [String fallback = 'Updated']) {
  if (value == null || '$value'.isEmpty) return fallback;
  final date = DateTime.tryParse('$value');
  if (date == null) return '$value';
  return DateFormat.yMMMd().format(date.toLocal());
}

class AccountUser {
  const AccountUser({
    required this.id,
    required this.username,
    required this.name,
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

  factory AccountUser.fromJson(Map<String, dynamic> json,
      [Map<String, dynamic>? account]) {
    return AccountUser(
      id: textValue(json, 'id'),
      username: textValue(json, 'username', textValue(json, 'email')),
      name:
          textValue(json, 'name', textValue(json, 'email', 'Property24 user')),
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
        'payments',
        'leases',
        'maintenance',
        'inbox',
        'profile',
        'verification'
      ],
      capabilities: ['search_properties', 'save_properties'],
      onboardingRequirements: ['email_verification'],
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
    required this.monthlyRent,
    required this.depositRequired,
    required this.propertyType,
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
    required this.applicationsCount,
    required this.owner,
    required this.agent,
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
      monthlyRent: textValue(json, 'monthly_rent', '0'),
      depositRequired: textValue(json, 'deposit_required', '0'),
      propertyType: titleize(json['property_type']),
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
      applicationsCount: int.tryParse('${json['applications_count']}') ?? 0,
      owner: json['owner'] is Map<String, dynamic>
          ? AccountUser.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
      agent: json['agent'] is Map<String, dynamic>
          ? AccountUser.fromJson(json['agent'] as Map<String, dynamic>)
          : null,
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
  final String monthlyRent;
  final String depositRequired;
  final String propertyType;
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
  final int applicationsCount;
  final AccountUser? owner;
  final AccountUser? agent;

  AccountUser? get supplier => agent ?? owner;
  String get rentLabel => money(monthlyRent, suffix: '/ month');
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
  String get availabilityLabel =>
      verified ? 'Confirmed this week' : 'Awaiting confirmation';
  String get passportId =>
      'P24-${id.isEmpty ? title.hashCode.abs() : id.hashCode.abs()}';

  num get monthlyRentValue =>
      num.tryParse(monthlyRent.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  num get depositValue =>
      num.tryParse(depositRequired.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  num get estimatedFees => (monthlyRentValue * 0.08).round();
  num get moveInTotal => monthlyRentValue + depositValue + estimatedFees;
  String get moveInTotalLabel => money(moveInTotal);

  int get trustScore {
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
    return [
      PropertyFact(iconName: 'bed', label: 'Bedrooms', value: '$bedrooms'),
      PropertyFact(iconName: 'bath', label: 'Bathrooms', value: '$bathrooms'),
      PropertyFact(iconName: 'type', label: 'Type', value: propertyType),
      PropertyFact(
          iconName: 'water',
          label: 'Water',
          value: borehole ? 'Borehole' : waterAvailability),
      PropertyFact(
          iconName: 'power',
          label: 'Power',
          value: solarPower ? 'Solar backup' : 'Grid only'),
      PropertyFact(iconName: 'parking', label: 'Parking', value: parking),
    ];
  }
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

class PaymentItem {
  const PaymentItem({
    required this.id,
    required this.tenant,
    required this.property,
    required this.amount,
    required this.method,
    required this.status,
    required this.receiptNumber,
    required this.paidAt,
  });

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      id: textValue(json, 'id'),
      tenant: textValue(json, 'tenant'),
      property: textValue(json, 'property'),
      amount: money(json['amount']),
      method: titleize(json['method']),
      status: titleize(json['status']),
      receiptNumber: textValue(json, 'receipt_number'),
      paidAt: localDate(json['paid_at'], 'Recorded'),
    );
  }

  final String id;
  final String tenant;
  final String property;
  final String amount;
  final String method;
  final String status;
  final String receiptNumber;
  final String paidAt;
}

class MaintenanceItem {
  const MaintenanceItem({
    required this.id,
    required this.issue,
    required this.category,
    required this.property,
    required this.tenant,
    required this.description,
    required this.status,
    required this.priority,
    required this.updatedAt,
  });

  factory MaintenanceItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceItem(
      id: textValue(json, 'id'),
      issue: textValue(json, 'issue'),
      category: titleize(json['category']),
      property: textValue(json, 'property'),
      tenant: textValue(json, 'tenant'),
      description: textValue(json, 'description'),
      status: titleize(json['status']),
      priority: titleize(json['priority']),
      updatedAt: localDate(json['updated_at']),
    );
  }

  final String id;
  final String issue;
  final String category;
  final String property;
  final String tenant;
  final String description;
  final String status;
  final String priority;
  final String updatedAt;
}

class LeaseItem {
  const LeaseItem({
    required this.id,
    required this.property,
    required this.tenant,
    required this.landlord,
    required this.monthlyRent,
    required this.deposit,
    required this.status,
    required this.signedByTenant,
    required this.signedByLandlord,
  });

  factory LeaseItem.fromJson(Map<String, dynamic> json) {
    return LeaseItem(
      id: textValue(json, 'id'),
      property: textValue(json, 'property'),
      tenant: textValue(json, 'tenant'),
      landlord: textValue(json, 'landlord'),
      monthlyRent: money(json['monthly_rent']),
      deposit: money(json['deposit']),
      status: titleize(json['status']),
      signedByTenant: json['signed_by_tenant'] == true,
      signedByLandlord: json['signed_by_landlord'] == true,
    );
  }

  final String id;
  final String property;
  final String tenant;
  final String landlord;
  final String monthlyRent;
  final String deposit;
  final String status;
  final bool signedByTenant;
  final bool signedByLandlord;
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
  });

  factory VerificationItem.fromJson(Map<String, dynamic> json) {
    return VerificationItem(
      id: textValue(json, 'id'),
      name: textValue(json, 'name'),
      role: titleize(json['role']),
      status: titleize(json['status']),
      checks: List<String>.from(json['checks'] ?? const []),
    );
  }

  final String id;
  final String name;
  final String role;
  final String status;
  final List<String> checks;
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
  });

  factory ViewingItem.fromJson(Map<String, dynamic> json) {
    return ViewingItem(
      id: textValue(json, 'id'),
      propertyId: textValue(json, 'property_id'),
      property: textValue(json, 'property'),
      tenant: textValue(json, 'tenant'),
      agent: textValue(json, 'agent'),
      scheduledFor: localDate(json['scheduled_for'], 'Scheduled'),
      status: titleize(json['status']),
      notes: textValue(json, 'notes'),
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

  bool get isAvailableBooking {
    final normalized = status.toLowerCase();
    return normalized == 'pending' ||
        normalized == 'confirmed' ||
        normalized == 'reserved';
  }
}

class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.preview,
    required this.updatedAt,
    required this.phoneNumbersRevealed,
    required this.participants,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final participants = (json['participants'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AccountUser.fromJson)
        .toList();
    final lastMessage = json['last_message'] is Map<String, dynamic>
        ? json['last_message'] as Map<String, dynamic>
        : null;
    return ConversationItem(
      id: textValue(json, 'id'),
      propertyId: textValue(json, 'property_id'),
      title: textValue(
        json,
        'title',
        participants.map((user) => user.name).join(' and '),
      ),
      preview: textValue(
          lastMessage ?? const {}, 'body', 'Phone numbers remain hidden.'),
      updatedAt: localDate(json['updated_at']),
      phoneNumbersRevealed: json['phone_numbers_revealed'] == true,
      participants: participants,
    );
  }

  final String id;
  final String propertyId;
  final String title;
  final String preview;
  final String updatedAt;
  final bool phoneNumbersRevealed;
  final List<AccountUser> participants;
}

class PlatformSnapshot {
  const PlatformSnapshot({
    required this.properties,
    required this.payments,
    required this.maintenance,
    required this.leases,
    required this.applications,
    required this.verifications,
    required this.conversations,
    required this.viewings,
  });

  factory PlatformSnapshot.empty() {
    return const PlatformSnapshot(
      properties: [],
      payments: [],
      maintenance: [],
      leases: [],
      applications: [],
      verifications: [],
      conversations: [],
      viewings: [],
    );
  }

  final List<PropertyListing> properties;
  final List<PaymentItem> payments;
  final List<MaintenanceItem> maintenance;
  final List<LeaseItem> leases;
  final List<ApplicationItem> applications;
  final List<VerificationItem> verifications;
  final List<ConversationItem> conversations;
  final List<ViewingItem> viewings;
}
