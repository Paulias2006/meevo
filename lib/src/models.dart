class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.partnerProfile,
    this.subscription,
    this.phone,
    this.city,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final PartnerProfileData? partnerProfile;
  final PartnerSubscriptionData? subscription;
  final String? phone;
  final String? city;
  final String? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'customer',
      partnerProfile: json['partnerProfile'] is Map<String, dynamic>
          ? PartnerProfileData.fromJson(
              json['partnerProfile'] as Map<String, dynamic>,
            )
          : null,
      subscription: json['subscription'] is Map<String, dynamic>
          ? PartnerSubscriptionData.fromJson(
              json['subscription'] as Map<String, dynamic>,
            )
          : null,
      phone: json['phone']?.toString(),
      city: json['city']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class PartnerProfileData {
  const PartnerProfileData({
    required this.businessName,
    required this.partnerType,
    required this.whatsapp,
    this.district,
    this.description,
    this.payoutPhoneNumber,
    this.payoutNetwork,
    this.payoutAccountName,
    this.payoutUpdatedAt,
    this.submittedAt,
  });

  final String businessName;
  final String partnerType;
  final String whatsapp;
  final String? district;
  final String? description;
  final String? payoutPhoneNumber;
  final String? payoutNetwork;
  final String? payoutAccountName;
  final String? payoutUpdatedAt;
  final String? submittedAt;

  factory PartnerProfileData.fromJson(Map<String, dynamic> json) {
    return PartnerProfileData(
      businessName: json['businessName']?.toString() ?? '',
      partnerType: json['partnerType']?.toString() ?? '',
      whatsapp: json['whatsapp']?.toString() ?? '',
      district: json['district']?.toString(),
      description: json['description']?.toString(),
      payoutPhoneNumber: json['payoutPhoneNumber']?.toString(),
      payoutNetwork: json['payoutNetwork']?.toString(),
      payoutAccountName: json['payoutAccountName']?.toString(),
      payoutUpdatedAt: json['payoutUpdatedAt']?.toString(),
      submittedAt: json['submittedAt']?.toString(),
    );
  }
}

class PartnerSubscriptionData {
  const PartnerSubscriptionData({
    required this.status,
    required this.cycle,
    required this.months,
    required this.monthlyPrice,
    required this.grossAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.isActive,
    this.paymentNetwork,
    this.paymentMethod,
    this.currentPaymentIdentifier,
    this.startedAt,
    this.endsAt,
    this.lastPaymentAt,
  });

  const PartnerSubscriptionData.empty()
      : status = 'inactive',
        cycle = 'monthly',
        months = 0,
        monthlyPrice = 0,
        grossAmount = 0,
        discountAmount = 0,
        totalAmount = 0,
        isActive = false,
        paymentNetwork = null,
        paymentMethod = null,
        currentPaymentIdentifier = null,
        startedAt = null,
        endsAt = null,
        lastPaymentAt = null;

  final String status;
  final String cycle;
  final int months;
  final double monthlyPrice;
  final double grossAmount;
  final double discountAmount;
  final double totalAmount;
  final bool isActive;
  final String? paymentNetwork;
  final String? paymentMethod;
  final String? currentPaymentIdentifier;
  final String? startedAt;
  final String? endsAt;
  final String? lastPaymentAt;

  factory PartnerSubscriptionData.fromJson(Map<String, dynamic> json) {
    return PartnerSubscriptionData(
      status: json['status']?.toString() ?? 'inactive',
      cycle: json['cycle']?.toString() ?? 'monthly',
      months: (json['months'] as num?)?.toInt() ?? 0,
      monthlyPrice: (json['monthlyPrice'] as num?)?.toDouble() ?? 0,
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] == true,
      paymentNetwork: json['paymentNetwork']?.toString() ?? json['paygateNetwork']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      currentPaymentIdentifier: json['currentPaymentIdentifier']?.toString(),
      startedAt: json['startedAt']?.toString(),
      endsAt: json['endsAt']?.toString(),
      lastPaymentAt: json['lastPaymentAt']?.toString(),
    );
  }
}

class SubscriptionPresetData {
  const SubscriptionPresetData({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.months,
    required this.monthlyPrice,
    required this.grossAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.cycle,
  });

  final String code;
  final String title;
  final String subtitle;
  final String badge;
  final int months;
  final double monthlyPrice;
  final double grossAmount;
  final double discountAmount;
  final double totalAmount;
  final String cycle;

  factory SubscriptionPresetData.fromJson(Map<String, dynamic> json) {
    return SubscriptionPresetData(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      badge: json['badge']?.toString() ?? '',
      months: (json['months'] as num?)?.toInt() ?? 1,
      monthlyPrice: (json['monthlyPrice'] as num?)?.toDouble() ?? 0,
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      cycle: json['cycle']?.toString() ?? 'monthly',
    );
  }
}

class SubscriptionNetworkData {
  const SubscriptionNetworkData({
    required this.code,
    required this.label,
    required this.paymentMethodLabel,
  });

  final String code;
  final String label;
  final String paymentMethodLabel;

  factory SubscriptionNetworkData.fromJson(Map<String, dynamic> json) {
    return SubscriptionNetworkData(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      paymentMethodLabel: json['paymentMethodLabel']?.toString() ?? '',
    );
  }
}

class SubscriptionPaymentData {
  const SubscriptionPaymentData({
    required this.id,
    required this.identifier,
    required this.months,
    required this.cycle,
    required this.monthlyPrice,
    required this.grossAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.network,
    required this.status,
    this.phoneNumber,
    this.partnerType,
    this.description,
    this.paymentUrl,
    this.txReference,
    this.paymentReference,
    this.paymentMethod,
    this.paidAt,
    this.appliedAt,
    this.createdAt,
  });

  final String id;
  final String identifier;
  final int months;
  final String cycle;
  final double monthlyPrice;
  final double grossAmount;
  final double discountAmount;
  final double totalAmount;
  final String network;
  final String status;
  final String? phoneNumber;
  final String? partnerType;
  final String? description;
  final String? paymentUrl;
  final String? txReference;
  final String? paymentReference;
  final String? paymentMethod;
  final String? paidAt;
  final String? appliedAt;
  final String? createdAt;

  factory SubscriptionPaymentData.fromJson(Map<String, dynamic> json) {
    return SubscriptionPaymentData(
      id: json['id']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      months: (json['months'] as num?)?.toInt() ?? 0,
      cycle: json['cycle']?.toString() ?? 'monthly',
      monthlyPrice: (json['monthlyPrice'] as num?)?.toDouble() ?? 0,
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      network: json['network']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      phoneNumber: json['phoneNumber']?.toString(),
      partnerType: json['partnerType']?.toString(),
      description: json['description']?.toString(),
      paymentUrl: json['paymentUrl']?.toString(),
      txReference: json['txReference']?.toString(),
      paymentReference: json['paymentReference']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      paidAt: json['paidAt']?.toString(),
      appliedAt: json['appliedAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class SubscriptionOverview {
  const SubscriptionOverview({
    required this.paymentConfigured,
    required this.monthlyPrice,
    required this.maxMonths,
    required this.presets,
    required this.networks,
    required this.payments,
    required this.canAccessDashboard,
    this.subscription,
  });

  const SubscriptionOverview.empty()
      : paymentConfigured = false,
        monthlyPrice = 50000,
        maxMonths = 24,
        presets = const [],
        networks = const [],
        payments = const [],
        canAccessDashboard = false,
        subscription = const PartnerSubscriptionData.empty();

  final bool paymentConfigured;
  final double monthlyPrice;
  final int maxMonths;
  final List<SubscriptionPresetData> presets;
  final List<SubscriptionNetworkData> networks;
  final List<SubscriptionPaymentData> payments;
  final bool canAccessDashboard;
  final PartnerSubscriptionData? subscription;

  factory SubscriptionOverview.fromJson(Map<String, dynamic> json) {
    return SubscriptionOverview(
      paymentConfigured:
          json['paymentConfigured'] == true || json['paygateConfigured'] == true,
      monthlyPrice: (json['monthlyPrice'] as num?)?.toDouble() ?? 50000,
      maxMonths: (json['maxMonths'] as num?)?.toInt() ?? 24,
      presets: (json['presets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPresetData.fromJson)
          .toList(),
      networks: (json['networks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionNetworkData.fromJson)
          .toList(),
      payments: (json['payments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPaymentData.fromJson)
          .toList(),
      canAccessDashboard: json['canAccessDashboard'] == true,
      subscription: json['subscription'] is Map<String, dynamic>
          ? PartnerSubscriptionData.fromJson(
              json['subscription'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class SubscriptionCheckoutResult {
  const SubscriptionCheckoutResult({
    required this.payment,
    required this.overview,
    required this.user,
    required this.paymentUrl,
  });

  final SubscriptionPaymentData payment;
  final SubscriptionOverview overview;
  final AppUser user;
  final String paymentUrl;

  factory SubscriptionCheckoutResult.fromJson(Map<String, dynamic> json) {
    return SubscriptionCheckoutResult(
      payment: SubscriptionPaymentData.fromJson(
        json['item'] as Map<String, dynamic>? ?? const {},
      ),
      overview: SubscriptionOverview.fromJson(
        json['overview'] as Map<String, dynamic>? ?? const {},
      ),
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
      paymentUrl: json['paymentUrl']?.toString() ?? '',
    );
  }
}

class SubscriptionVerificationResult {
  const SubscriptionVerificationResult({
    required this.payment,
    required this.overview,
    required this.user,
    required this.paymentStatus,
  });

  final SubscriptionPaymentData payment;
  final SubscriptionOverview overview;
  final AppUser user;
  final Map<String, dynamic> paymentStatus;

  factory SubscriptionVerificationResult.fromJson(Map<String, dynamic> json) {
    return SubscriptionVerificationResult(
      payment: SubscriptionPaymentData.fromJson(
        json['item'] as Map<String, dynamic>? ?? const {},
      ),
      overview: SubscriptionOverview.fromJson(
        json['overview'] as Map<String, dynamic>? ?? const {},
      ),
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
      paymentStatus: (json['paymentStatus'] as Map<String, dynamic>?) ??
          (json['paygateStatus'] as Map<String, dynamic>?) ??
          const {},
    );
  }
}

class AdminSubscriptionSummary {
  const AdminSubscriptionSummary({
    required this.totalPayments,
    required this.successfulPayments,
    required this.pendingPayments,
    required this.failedPayments,
    required this.activePartners,
    required this.expiringSoonPartners,
    required this.gracePartners,
    required this.hiddenPartners,
    required this.totalRevenue,
    required this.currentMonthRevenue,
  });

  const AdminSubscriptionSummary.empty()
      : totalPayments = 0,
        successfulPayments = 0,
        pendingPayments = 0,
        failedPayments = 0,
        activePartners = 0,
        expiringSoonPartners = 0,
        gracePartners = 0,
        hiddenPartners = 0,
        totalRevenue = 0,
        currentMonthRevenue = 0;

  final int totalPayments;
  final int successfulPayments;
  final int pendingPayments;
  final int failedPayments;
  final int activePartners;
  final int expiringSoonPartners;
  final int gracePartners;
  final int hiddenPartners;
  final double totalRevenue;
  final double currentMonthRevenue;

  factory AdminSubscriptionSummary.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionSummary(
      totalPayments: (json['totalPayments'] as num?)?.toInt() ?? 0,
      successfulPayments: (json['successfulPayments'] as num?)?.toInt() ?? 0,
      pendingPayments: (json['pendingPayments'] as num?)?.toInt() ?? 0,
      failedPayments: (json['failedPayments'] as num?)?.toInt() ?? 0,
      activePartners: (json['activePartners'] as num?)?.toInt() ?? 0,
      expiringSoonPartners:
          (json['expiringSoonPartners'] as num?)?.toInt() ?? 0,
      gracePartners: (json['gracePartners'] as num?)?.toInt() ?? 0,
      hiddenPartners: (json['hiddenPartners'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      currentMonthRevenue:
          (json['currentMonthRevenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminSubscriptionTimelinePoint {
  const AdminSubscriptionTimelinePoint({
    required this.key,
    required this.label,
    required this.count,
    required this.revenue,
  });

  final String key;
  final String label;
  final int count;
  final double revenue;

  factory AdminSubscriptionTimelinePoint.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionTimelinePoint(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdminSubscriptionRecord {
  const AdminSubscriptionRecord({
    required this.payment,
    required this.user,
    required this.subscriptionState,
    required this.isVisiblePublicly,
    required this.inGracePeriod,
    this.daysUntilExpiry,
    this.daysUntilGraceEnd,
    this.expiresAt,
    this.graceEndsAt,
  });

  final SubscriptionPaymentData payment;
  final AppUser user;
  final String subscriptionState;
  final bool isVisiblePublicly;
  final bool inGracePeriod;
  final int? daysUntilExpiry;
  final int? daysUntilGraceEnd;
  final String? expiresAt;
  final String? graceEndsAt;

  factory AdminSubscriptionRecord.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionRecord(
      payment: SubscriptionPaymentData.fromJson(
        json['payment'] as Map<String, dynamic>? ?? const {},
      ),
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
      subscriptionState: json['subscriptionState']?.toString() ?? 'inactive',
      isVisiblePublicly: json['isVisiblePublicly'] == true,
      inGracePeriod: json['inGracePeriod'] == true,
      daysUntilExpiry: (json['daysUntilExpiry'] as num?)?.toInt(),
      daysUntilGraceEnd: (json['daysUntilGraceEnd'] as num?)?.toInt(),
      expiresAt: json['expiresAt']?.toString(),
      graceEndsAt: json['graceEndsAt']?.toString(),
    );
  }
}

class AdminSubscriptionResponse {
  const AdminSubscriptionResponse({
    required this.summary,
    required this.timeline,
    required this.items,
  });

  const AdminSubscriptionResponse.empty()
      : summary = const AdminSubscriptionSummary.empty(),
        timeline = const [],
        items = const [];

  final AdminSubscriptionSummary summary;
  final List<AdminSubscriptionTimelinePoint> timeline;
  final List<AdminSubscriptionRecord> items;

  factory AdminSubscriptionResponse.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionResponse(
      summary: AdminSubscriptionSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      timeline: (json['timeline'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminSubscriptionTimelinePoint.fromJson)
          .toList(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminSubscriptionRecord.fromJson)
          .toList(),
    );
  }
}

class AdminUsersSummary {
  const AdminUsersSummary({
    required this.totalUsers,
    required this.admins,
    required this.partners,
    required this.customers,
    required this.activeSubscriptions,
  });

  const AdminUsersSummary.empty()
      : totalUsers = 0,
        admins = 0,
        partners = 0,
        customers = 0,
        activeSubscriptions = 0;

  final int totalUsers;
  final int admins;
  final int partners;
  final int customers;
  final int activeSubscriptions;

  factory AdminUsersSummary.fromJson(Map<String, dynamic> json) {
    return AdminUsersSummary(
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
      admins: (json['admins'] as num?)?.toInt() ?? 0,
      partners: (json['partners'] as num?)?.toInt() ?? 0,
      customers: (json['customers'] as num?)?.toInt() ?? 0,
      activeSubscriptions: (json['activeSubscriptions'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminUserRecord {
  const AdminUserRecord({
    required this.user,
    required this.businessName,
    required this.partnerType,
    required this.whatsapp,
    required this.subscriptionState,
    required this.hasPartnerProfile,
  });

  final AppUser user;
  final String businessName;
  final String partnerType;
  final String whatsapp;
  final String subscriptionState;
  final bool hasPartnerProfile;

  factory AdminUserRecord.fromJson(Map<String, dynamic> json) {
    return AdminUserRecord(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
      businessName: json['businessName']?.toString() ?? '',
      partnerType: json['partnerType']?.toString() ?? '',
      whatsapp: json['whatsapp']?.toString() ?? '',
      subscriptionState: json['subscriptionState']?.toString() ?? 'inactive',
      hasPartnerProfile: json['hasPartnerProfile'] == true,
    );
  }
}

class AdminUsersResponse {
  const AdminUsersResponse({required this.summary, required this.items});

  const AdminUsersResponse.empty()
      : summary = const AdminUsersSummary.empty(),
        items = const [];

  final AdminUsersSummary summary;
  final List<AdminUserRecord> items;

  factory AdminUsersResponse.fromJson(Map<String, dynamic> json) {
    return AdminUsersResponse(
      summary: AdminUsersSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminUserRecord.fromJson)
          .toList(),
    );
  }
}

class HomeStats {
  const HomeStats({
    required this.venuesCount,
    required this.citiesCount,
    required this.providersCount,
    required this.bookingsCount,
  });

  const HomeStats.empty()
    : venuesCount = 0,
      citiesCount = 0,
      providersCount = 0,
      bookingsCount = 0;

  final int venuesCount;
  final int citiesCount;
  final int providersCount;
  final int bookingsCount;

  factory HomeStats.fromJson(Map<String, dynamic> json) {
    return HomeStats(
      venuesCount: (json['venuesCount'] as num?)?.toInt() ?? 0,
      citiesCount: (json['citiesCount'] as num?)?.toInt() ?? 0,
      providersCount: (json['providersCount'] as num?)?.toInt() ?? 0,
      bookingsCount: (json['bookingsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class BusinessHours {
  const BusinessHours({required this.opensAt, required this.closesAt});

  const BusinessHours.defaults() : opensAt = '08:00', closesAt = '23:00';

  final String opensAt;
  final String closesAt;

  factory BusinessHours.fromJson(Map<String, dynamic> json) {
    return BusinessHours(
      opensAt: json['opensAt']?.toString() ?? '08:00',
      closesAt: json['closesAt']?.toString() ?? '23:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {'opensAt': opensAt, 'closesAt': closesAt};
  }
}

class ManualBlock {
  const ManualBlock({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.reason = '',
  });

  final String date;
  final String startTime;
  final String endTime;
  final String reason;

  factory ManualBlock.fromJson(Map<String, dynamic> json) {
    return ManualBlock(
      date: json['date']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'reason': reason,
    };
  }
}

class AvailabilitySlot {
  const AvailabilitySlot({
    required this.source,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.status,
    this.eventType,
    this.reason,
    this.bookingId,
    this.slotId,
  });

  final String source;
  final String date;
  final String startTime;
  final String endTime;
  final String? status;
  final String? eventType;
  final String? reason;
  final String? bookingId;
  final String? slotId;

  bool get isManualBlock => source == 'manual';

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      source: json['source']?.toString() ?? 'booking',
      date: json['date']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      status: json['status']?.toString(),
      eventType: json['eventType']?.toString(),
      reason: json['reason']?.toString(),
      bookingId: json['bookingId']?.toString(),
      slotId: json['slotId']?.toString(),
    );
  }
}

class VenueAvailability {
  const VenueAvailability({
    required this.date,
    required this.businessHours,
    required this.blockedDates,
    required this.slots,
  });

  const VenueAvailability.empty()
    : date = '',
      businessHours = const BusinessHours.defaults(),
      blockedDates = const [],
      slots = const [];

  final String date;
  final BusinessHours businessHours;
  final List<String> blockedDates;
  final List<AvailabilitySlot> slots;

  factory VenueAvailability.fromJson(Map<String, dynamic> json) {
    return VenueAvailability(
      date: json['date']?.toString() ?? '',
      businessHours: BusinessHours.fromJson(
        json['businessHours'] as Map<String, dynamic>? ?? const {},
      ),
      blockedDates: (json['blockedDates'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      slots: (json['slots'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AvailabilitySlot.fromJson)
          .toList(),
    );
  }
}

class MonthlyAvailability {
  const MonthlyAvailability({
    required this.month,
    required this.busyDates,
    required this.bookedDates,
    required this.manualDates,
    required this.blockedDates,
  });

  const MonthlyAvailability.empty()
    : month = '',
      busyDates = const [],
      bookedDates = const [],
      manualDates = const [],
      blockedDates = const [];

  final String month;
  final List<String> busyDates;
  final List<String> bookedDates;
  final List<String> manualDates;
  final List<String> blockedDates;

  factory MonthlyAvailability.fromJson(Map<String, dynamic> json) {
    return MonthlyAvailability(
      month: json['month']?.toString() ?? '',
      busyDates: (json['busyDates'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      bookedDates: (json['bookedDates'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      manualDates: (json['manualDates'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      blockedDates: (json['blockedDates'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.venueType,
    required this.slug,
    required this.city,
    required this.capacity,
    required this.startingPrice,
    required this.currency,
    required this.eventTypes,
    required this.amenities,
    required this.photos,
    required this.rating,
    required this.reviewCount,
    required this.isPopular,
    required this.isFeatured,
    required this.businessHours,
    required this.blockedDates,
    required this.manualBlocks,
    this.shortDescription,
    this.description,
    this.district,
    this.address,
    this.googleMapsUrl,
    this.country,
    this.coverPhoto,
    this.videoUrl,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String venueType;
  final String slug;
  final String city;
  final int capacity;
  final double startingPrice;
  final String currency;
  final List<String> eventTypes;
  final List<String> amenities;
  final List<String> photos;
  final double rating;
  final int reviewCount;
  final bool isPopular;
  final bool isFeatured;
  final BusinessHours businessHours;
  final List<String> blockedDates;
  final List<ManualBlock> manualBlocks;
  final String? shortDescription;
  final String? description;
  final String? district;
  final String? address;
  final String? googleMapsUrl;
  final String? country;
  final String? coverPhoto;
  final String? videoUrl;
  final double? latitude;
  final double? longitude;

  String get primaryImage {
    if ((coverPhoto ?? '').isNotEmpty) return coverPhoto!;
    if (photos.isNotEmpty) return photos.first;
    return '';
  }

  String get locationLabel {
    final districtLabel = (district ?? '').trim();
    if (districtLabel.isNotEmpty) {
      return '$districtLabel, $city';
    }
    return city;
  }

  factory Venue.fromJson(Map<String, dynamic> json) {
    final coordinates = json['coordinates'] as Map<String, dynamic>?;
    return Venue(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      venueType: json['venueType']?.toString() ?? 'salle',
      slug: json['slug']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      startingPrice: (json['startingPrice'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'FCFA',
      eventTypes: (json['eventTypes'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      amenities: (json['amenities'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      isPopular: json['isPopular'] == true,
      isFeatured: json['isFeatured'] == true,
      businessHours: BusinessHours.fromJson(
        json['businessHours'] as Map<String, dynamic>? ?? const {},
      ),
      blockedDates: (json['blockedDates'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      manualBlocks: (json['manualBlocks'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ManualBlock.fromJson)
          .toList(),
      shortDescription: json['shortDescription']?.toString(),
      description: json['description']?.toString(),
      district: json['district']?.toString(),
      address: json['address']?.toString(),
      googleMapsUrl: json['googleMapsUrl']?.toString(),
      country: json['country']?.toString(),
      coverPhoto: json['coverPhoto']?.toString(),
      videoUrl: json['videoUrl']?.toString(),
      latitude: (coordinates?['latitude'] as num?)?.toDouble(),
      longitude: (coordinates?['longitude'] as num?)?.toDouble(),
    );
  }
}

class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.city,
    required this.startingPrice,
    required this.currency,
    required this.rating,
    required this.reviewCount,
    required this.isFeatured,
    this.photoUrl,
    this.phone,
    this.whatsapp,
    this.email,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String city;
  final double startingPrice;
  final String currency;
  final double rating;
  final int reviewCount;
  final bool isFeatured;
  final String? photoUrl;
  final String? phone;
  final String? whatsapp;
  final String? email;

  factory ProviderProfile.fromJson(Map<String, dynamic> json) {
    return ProviderProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      startingPrice: (json['startingPrice'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'FCFA',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      isFeatured: json['isFeatured'] == true,
      photoUrl: json['photoUrl']?.toString(),
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

class ProviderSearchFilters {
  const ProviderSearchFilters({
    this.query = '',
    this.city = 'Tout le Togo',
    this.category = 'Tous',
    this.page = 1,
  });

  final String query;
  final String city;
  final String category;
  final int page;

  ProviderSearchFilters copyWith({
    String? query,
    String? city,
    String? category,
    int? page,
  }) {
    return ProviderSearchFilters(
      query: query ?? this.query,
      city: city ?? this.city,
      category: category ?? this.category,
      page: page ?? this.page,
    );
  }
}

class ProviderSearchResponse {
  const ProviderSearchResponse({
    required this.items,
    required this.pagination,
  });

  final List<ProviderProfile> items;
  final PaginationInfo pagination;

  factory ProviderSearchResponse.fromJson(Map<String, dynamic> json) {
    return ProviderSearchResponse(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ProviderProfile.fromJson)
          .toList(),
      pagination: PaginationInfo.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class BookingItem {
  const BookingItem({
    required this.id,
    required this.eventType,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.guestCount,
    required this.status,
    required this.totalAmount,
    required this.source,
    this.depositAmount = 0,
    this.budget,
    this.notes,
    this.customerName,
    this.customerPhone,
    this.venue,
  });

  final String id;
  final String eventType;
  final String eventDate;
  final String startTime;
  final String endTime;
  final int guestCount;
  final String status;
  final double totalAmount;
  final String source;
  final double depositAmount;
  final double? budget;
  final String? notes;
  final String? customerName;
  final String? customerPhone;
  final Venue? venue;

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    final venueJson = json['venue'];
    return BookingItem(
      id: json['id']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? '',
      eventDate: json['eventDate']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '08:00',
      endTime: json['endTime']?.toString() ?? '23:00',
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      source: json['source']?.toString() ?? 'platform',
      depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0,
      budget: (json['budget'] as num?)?.toDouble(),
      notes: json['notes']?.toString(),
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      venue: venueJson is Map<String, dynamic>
          ? Venue.fromJson(venueJson)
          : null,
    );
  }
}

class ReservationPaymentData {
  const ReservationPaymentData({
    required this.id,
    required this.identifier,
    required this.description,
    required this.customerName,
    required this.customerEmail,
    required this.eventType,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.guestCount,
    required this.grossAmount,
    required this.platformFeeRate,
    required this.platformFeeAmount,
    required this.partnerNetAmount,
    required this.network,
    required this.phoneNumber,
    required this.status,
    required this.payoutStatus,
    this.paymentUrl,
    this.txReference,
    this.paymentReference,
    this.paymentMethod,
    this.paidAt,
    this.bookingCreatedAt,
    this.holdExpiresAt,
    this.payoutPhoneNumber,
    this.payoutNetwork,
    this.payoutAccountName,
    this.payoutPaidAt,
    this.payoutReference,
    this.payoutNotes,
    this.createdAt,
    this.venue,
    this.booking,
    this.customer,
    this.partner,
    this.budget,
    this.notes,
  });

  final String id;
  final String identifier;
  final String description;
  final String customerName;
  final String customerEmail;
  final String eventType;
  final String eventDate;
  final String startTime;
  final String endTime;
  final int guestCount;
  final double grossAmount;
  final double platformFeeRate;
  final double platformFeeAmount;
  final double partnerNetAmount;
  final String network;
  final String phoneNumber;
  final String status;
  final String payoutStatus;
  final String? paymentUrl;
  final String? txReference;
  final String? paymentReference;
  final String? paymentMethod;
  final String? paidAt;
  final String? bookingCreatedAt;
  final String? holdExpiresAt;
  final String? payoutPhoneNumber;
  final String? payoutNetwork;
  final String? payoutAccountName;
  final String? payoutPaidAt;
  final String? payoutReference;
  final String? payoutNotes;
  final String? createdAt;
  final Venue? venue;
  final BookingItem? booking;
  final AppUser? customer;
  final AppUser? partner;
  final double? budget;
  final String? notes;

  bool get isSuccessful => status == 'success';
  bool get isPayoutReady => payoutStatus == 'ready';
  bool get isPayoutPaid => payoutStatus == 'paid';

  factory ReservationPaymentData.fromJson(Map<String, dynamic> json) {
    final venueJson = json['venue'];
    final bookingJson = json['booking'];
    final customerJson = json['customer'];
    final partnerJson = json['partner'];
    final paymentJson = json['payment'];

    if (paymentJson is Map<String, dynamic>) {
      return ReservationPaymentData.fromJson({
        ...paymentJson,
        'venue': venueJson,
        'booking': bookingJson,
        'customer': customerJson,
        'partner': partnerJson,
      });
    }

    return ReservationPaymentData(
      id: json['id']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerEmail: json['customerEmail']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? '',
      eventDate: json['eventDate']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '08:00',
      endTime: json['endTime']?.toString() ?? '23:00',
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 0,
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0,
      platformFeeRate: (json['platformFeeRate'] as num?)?.toDouble() ?? 0,
      platformFeeAmount: (json['platformFeeAmount'] as num?)?.toDouble() ?? 0,
      partnerNetAmount: (json['partnerNetAmount'] as num?)?.toDouble() ?? 0,
      network: json['network']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      payoutStatus: json['payoutStatus']?.toString() ?? 'pending_profile',
      paymentUrl: json['paymentUrl']?.toString(),
      txReference: json['txReference']?.toString(),
      paymentReference: json['paymentReference']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      paidAt: json['paidAt']?.toString(),
      bookingCreatedAt: json['bookingCreatedAt']?.toString(),
      holdExpiresAt: json['holdExpiresAt']?.toString(),
      payoutPhoneNumber: json['payoutPhoneNumber']?.toString(),
      payoutNetwork: json['payoutNetwork']?.toString(),
      payoutAccountName: json['payoutAccountName']?.toString(),
      payoutPaidAt: json['payoutPaidAt']?.toString(),
      payoutReference: json['payoutReference']?.toString(),
      payoutNotes: json['payoutNotes']?.toString(),
      createdAt: json['createdAt']?.toString(),
      venue: venueJson is Map<String, dynamic>
          ? Venue.fromJson(venueJson)
          : null,
      booking: bookingJson is Map<String, dynamic>
          ? BookingItem.fromJson(bookingJson)
          : null,
      customer: customerJson is Map<String, dynamic>
          ? AppUser.fromJson(customerJson)
          : null,
      partner: partnerJson is Map<String, dynamic>
          ? AppUser.fromJson(partnerJson)
          : null,
      budget: (json['budget'] as num?)?.toDouble(),
      notes: json['notes']?.toString(),
    );
  }
}

class ReservationFinanceSummary {
  const ReservationFinanceSummary({
    required this.successfulReservations,
    required this.totalGrossAmount,
    required this.totalPlatformFee,
    required this.totalPartnerNet,
    required this.readyPayoutAmount,
    required this.pendingProfileAmount,
    required this.settledPayoutAmount,
    required this.currentMonthGrossAmount,
  });

  const ReservationFinanceSummary.empty()
      : successfulReservations = 0,
        totalGrossAmount = 0,
        totalPlatformFee = 0,
        totalPartnerNet = 0,
        readyPayoutAmount = 0,
        pendingProfileAmount = 0,
        settledPayoutAmount = 0,
        currentMonthGrossAmount = 0;

  final int successfulReservations;
  final double totalGrossAmount;
  final double totalPlatformFee;
  final double totalPartnerNet;
  final double readyPayoutAmount;
  final double pendingProfileAmount;
  final double settledPayoutAmount;
  final double currentMonthGrossAmount;

  factory ReservationFinanceSummary.fromJson(Map<String, dynamic> json) {
    return ReservationFinanceSummary(
      successfulReservations:
          (json['successfulReservations'] as num?)?.toInt() ?? 0,
      totalGrossAmount: (json['totalGrossAmount'] as num?)?.toDouble() ?? 0,
      totalPlatformFee: (json['totalPlatformFee'] as num?)?.toDouble() ?? 0,
      totalPartnerNet: (json['totalPartnerNet'] as num?)?.toDouble() ?? 0,
      readyPayoutAmount: (json['readyPayoutAmount'] as num?)?.toDouble() ?? 0,
      pendingProfileAmount:
          (json['pendingProfileAmount'] as num?)?.toDouble() ?? 0,
      settledPayoutAmount:
          (json['settledPayoutAmount'] as num?)?.toDouble() ?? 0,
      currentMonthGrossAmount:
          (json['currentMonthGrossAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReservationFinanceResponse {
  const ReservationFinanceResponse({
    required this.summary,
    required this.items,
    required this.wallet,
    required this.withdrawalsSummary,
    required this.withdrawals,
    required this.partnerTotals,
    this.payoutProviderAvailableBalance,
  });

  const ReservationFinanceResponse.empty()
      : summary = const ReservationFinanceSummary.empty(),
        items = const [],
        wallet = const PartnerWalletSummary.empty(),
        withdrawalsSummary = const WithdrawalSummary.empty(),
        withdrawals = const [],
        partnerTotals = const [],
        payoutProviderAvailableBalance = null;

  final ReservationFinanceSummary summary;
  final List<ReservationPaymentData> items;
  final PartnerWalletSummary wallet;
  final WithdrawalSummary withdrawalsSummary;
  final List<WithdrawalData> withdrawals;
  final List<PartnerRevenueAggregate> partnerTotals;
  final double? payoutProviderAvailableBalance;

  factory ReservationFinanceResponse.fromJson(Map<String, dynamic> json) {
    return ReservationFinanceResponse(
      summary: ReservationFinanceSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReservationPaymentData.fromJson)
          .toList(),
      wallet: PartnerWalletSummary.fromJson(
        json['wallet'] as Map<String, dynamic>? ?? const {},
      ),
      withdrawalsSummary: WithdrawalSummary.fromJson(
        json['withdrawalsSummary'] as Map<String, dynamic>? ?? const {},
      ),
      withdrawals: (json['withdrawals'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WithdrawalData.fromJson)
          .toList(),
      partnerTotals: (json['partnerTotals'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PartnerRevenueAggregate.fromJson)
          .toList(),
      payoutProviderAvailableBalance:
          (json['payoutProviderAvailableBalance'] as num?)?.toDouble(),
    );
  }
}

class PartnerWalletSummary {
  const PartnerWalletSummary({
    required this.totalNetRevenue,
    required this.readyBalance,
    required this.lockedPendingProfile,
    required this.reservedWithdrawals,
    required this.paidWithdrawals,
    required this.availableBalance,
    this.payoutProviderAvailableBalance,
    this.payoutProviderRawBalance,
  });

  const PartnerWalletSummary.empty()
      : totalNetRevenue = 0,
        readyBalance = 0,
        lockedPendingProfile = 0,
        reservedWithdrawals = 0,
        paidWithdrawals = 0,
        availableBalance = 0,
        payoutProviderAvailableBalance = null,
        payoutProviderRawBalance = null;

  final double totalNetRevenue;
  final double readyBalance;
  final double lockedPendingProfile;
  final double reservedWithdrawals;
  final double paidWithdrawals;
  final double availableBalance;
  final double? payoutProviderAvailableBalance;
  final double? payoutProviderRawBalance;

  factory PartnerWalletSummary.fromJson(Map<String, dynamic> json) {
    return PartnerWalletSummary(
      totalNetRevenue: (json['totalNetRevenue'] as num?)?.toDouble() ?? 0,
      readyBalance: (json['readyBalance'] as num?)?.toDouble() ?? 0,
      lockedPendingProfile:
          (json['lockedPendingProfile'] as num?)?.toDouble() ?? 0,
      reservedWithdrawals:
          (json['reservedWithdrawals'] as num?)?.toDouble() ?? 0,
      paidWithdrawals: (json['paidWithdrawals'] as num?)?.toDouble() ?? 0,
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0,
      payoutProviderAvailableBalance:
          (json['payoutProviderAvailableBalance'] as num?)?.toDouble(),
      payoutProviderRawBalance:
          (json['payoutProviderRawBalance'] as num?)?.toDouble(),
    );
  }
}

class WithdrawalSummary {
  const WithdrawalSummary({
    required this.totalRequestedAmount,
    required this.pendingAmount,
    required this.paidAmount,
  });

  const WithdrawalSummary.empty()
      : totalRequestedAmount = 0,
        pendingAmount = 0,
        paidAmount = 0;

  final double totalRequestedAmount;
  final double pendingAmount;
  final double paidAmount;

  factory WithdrawalSummary.fromJson(Map<String, dynamic> json) {
    return WithdrawalSummary(
      totalRequestedAmount:
          (json['totalRequestedAmount'] as num?)?.toDouble() ?? 0,
      pendingAmount: (json['pendingAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WithdrawalData {
  const WithdrawalData({
    required this.id,
    required this.amount,
    required this.currency,
    required this.network,
    required this.phoneNumber,
    required this.accountName,
    required this.clientTransferId,
    required this.status,
    this.cinetpayTransferId,
    this.lot,
    this.transferStatus,
    this.sendingStatus,
    this.comment,
    this.adminNotes,
    this.requestedAt,
    this.processedAt,
    this.paidAt,
    this.createdAt,
    this.partner,
  });

  final String id;
  final double amount;
  final String currency;
  final String network;
  final String phoneNumber;
  final String accountName;
  final String clientTransferId;
  final String status;
  final String? cinetpayTransferId;
  final String? lot;
  final String? transferStatus;
  final String? sendingStatus;
  final String? comment;
  final String? adminNotes;
  final String? requestedAt;
  final String? processedAt;
  final String? paidAt;
  final String? createdAt;
  final AppUser? partner;

  factory WithdrawalData.fromJson(Map<String, dynamic> json) {
    final withdrawalJson =
        json['withdrawal'] as Map<String, dynamic>? ?? json;
    final partnerJson = json['partner'];
    return WithdrawalData(
      id: withdrawalJson['id']?.toString() ?? '',
      amount: (withdrawalJson['amount'] as num?)?.toDouble() ?? 0,
      currency: withdrawalJson['currency']?.toString() ?? 'XOF',
      network: withdrawalJson['network']?.toString() ?? '',
      phoneNumber: withdrawalJson['phoneNumber']?.toString() ?? '',
      accountName: withdrawalJson['accountName']?.toString() ?? '',
      clientTransferId: withdrawalJson['clientTransferId']?.toString() ?? '',
      status: withdrawalJson['status']?.toString() ?? 'pending',
      cinetpayTransferId: withdrawalJson['cinetpayTransferId']?.toString(),
      lot: withdrawalJson['lot']?.toString(),
      transferStatus: withdrawalJson['transferStatus']?.toString(),
      sendingStatus: withdrawalJson['sendingStatus']?.toString(),
      comment: withdrawalJson['comment']?.toString(),
      adminNotes: withdrawalJson['adminNotes']?.toString(),
      requestedAt: withdrawalJson['requestedAt']?.toString(),
      processedAt: withdrawalJson['processedAt']?.toString(),
      paidAt: withdrawalJson['paidAt']?.toString(),
      createdAt: withdrawalJson['createdAt']?.toString(),
      partner: partnerJson is Map<String, dynamic>
          ? AppUser.fromJson(partnerJson)
          : null,
    );
  }
}

class PartnerRevenueAggregate {
  const PartnerRevenueAggregate({
    required this.reservations,
    required this.grossAmount,
    required this.platformFeeAmount,
    required this.partnerNetAmount,
    this.partner,
  });

  final int reservations;
  final double grossAmount;
  final double platformFeeAmount;
  final double partnerNetAmount;
  final AppUser? partner;

  factory PartnerRevenueAggregate.fromJson(Map<String, dynamic> json) {
    final partnerJson = json['partner'];
    return PartnerRevenueAggregate(
      reservations: (json['reservations'] as num?)?.toInt() ?? 0,
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0,
      platformFeeAmount:
          (json['platformFeeAmount'] as num?)?.toDouble() ?? 0,
      partnerNetAmount:
          (json['partnerNetAmount'] as num?)?.toDouble() ?? 0,
      partner: partnerJson is Map<String, dynamic>
          ? AppUser.fromJson(partnerJson)
          : null,
    );
  }
}

class BookingCheckoutResult {
  const BookingCheckoutResult({
    required this.payment,
    required this.paymentUrl,
  });

  final ReservationPaymentData payment;
  final String paymentUrl;

  factory BookingCheckoutResult.fromJson(Map<String, dynamic> json) {
    return BookingCheckoutResult(
      payment: ReservationPaymentData.fromJson(
        json['item'] as Map<String, dynamic>? ?? const {},
      ),
      paymentUrl: json['paymentUrl']?.toString() ?? '',
    );
  }
}

class BookingPaymentVerificationResult {
  const BookingPaymentVerificationResult({
    required this.payment,
    this.booking,
    this.paymentStatus,
  });

  final ReservationPaymentData payment;
  final BookingItem? booking;
  final Map<String, dynamic>? paymentStatus;

  factory BookingPaymentVerificationResult.fromJson(Map<String, dynamic> json) {
    return BookingPaymentVerificationResult(
      payment: ReservationPaymentData.fromJson(
        json['item'] as Map<String, dynamic>? ?? const {},
      ),
      booking: json['booking'] is Map<String, dynamic>
          ? BookingItem.fromJson(json['booking'] as Map<String, dynamic>)
          : null,
      paymentStatus: json['paymentStatus'] is Map<String, dynamic>
          ? json['paymentStatus'] as Map<String, dynamic>
          : json['paygateStatus'] is Map<String, dynamic>
              ? json['paygateStatus'] as Map<String, dynamic>
          : null,
    );
  }
}

class HomeData {
  const HomeData({
    required this.stats,
    required this.featuredVenues,
    required this.featuredProviders,
  });

  const HomeData.empty()
    : stats = const HomeStats.empty(),
      featuredVenues = const [],
      featuredProviders = const [];

  final HomeStats stats;
  final List<Venue> featuredVenues;
  final List<ProviderProfile> featuredProviders;

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      stats: HomeStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? const {},
      ),
      featuredVenues: (json['featuredVenues'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Venue.fromJson)
          .toList(),
      featuredProviders: (json['featuredProviders'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ProviderProfile.fromJson)
          .toList(),
    );
  }
}

class VenueSearchFilters {
  const VenueSearchFilters({
    this.query = '',
    this.city = 'Tout le Togo',
    this.eventType = '',
    this.date,
    this.startTime,
    this.endTime,
    this.guests = 0,
    this.maxPrice,
    this.page = 1,
  });

  final String query;
  final String city;
  final String eventType;
  final DateTime? date;
  final String? startTime;
  final String? endTime;
  final int guests;
  final int? maxPrice;
  final int page;

  VenueSearchFilters copyWith({
    String? query,
    String? city,
    String? eventType,
    DateTime? date,
    bool clearDate = false,
    String? startTime,
    String? endTime,
    bool clearTime = false,
    int? guests,
    int? maxPrice,
    bool clearMaxPrice = false,
    int? page,
  }) {
    return VenueSearchFilters(
      query: query ?? this.query,
      city: city ?? this.city,
      eventType: eventType ?? this.eventType,
      date: clearDate ? null : (date ?? this.date),
      startTime: clearTime ? null : (startTime ?? this.startTime),
      endTime: clearTime ? null : (endTime ?? this.endTime),
      guests: guests ?? this.guests,
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      page: page ?? this.page,
    );
  }
}

class PaginationInfo {
  const PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  const PaginationInfo.empty()
      : page = 1,
        limit = 55,
        total = 0,
        totalPages = 1;

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 55,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class VenueSearchResponse {
  const VenueSearchResponse({
    required this.items,
    required this.pagination,
  });

  final List<Venue> items;
  final PaginationInfo pagination;

  factory VenueSearchResponse.fromJson(Map<String, dynamic> json) {
    return VenueSearchResponse(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Venue.fromJson)
          .toList(),
      pagination: PaginationInfo.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class MediaUploadResult {
  const MediaUploadResult({
    required this.publicId,
    required this.secureUrl,
    required this.resourceType,
    this.bytes,
    this.format,
    this.duration,
  });

  final String publicId;
  final String secureUrl;
  final String resourceType;
  final int? bytes;
  final String? format;
  final double? duration;

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      publicId: json['publicId']?.toString() ?? '',
      secureUrl: json['secureUrl']?.toString() ?? '',
      resourceType: json['resourceType']?.toString() ?? 'image',
      bytes: (json['bytes'] as num?)?.toInt(),
      format: json['format']?.toString(),
      duration: (json['duration'] as num?)?.toDouble(),
    );
  }
}

class ResolvedLocationData {
  const ResolvedLocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.googleMapsUrl,
    this.district = '',
    this.address = '',
  });

  final double latitude;
  final double longitude;
  final String city;
  final String district;
  final String address;
  final String googleMapsUrl;

  factory ResolvedLocationData.fromJson(Map<String, dynamic> json) {
    return ResolvedLocationData(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      googleMapsUrl: json['googleMapsUrl']?.toString() ?? '',
    );
  }
}

class PartnerOnboardingDraft {
  const PartnerOnboardingDraft({
    required this.businessName,
    required this.partnerType,
    required this.city,
    required this.whatsapp,
    required this.description,
    this.district = '',
  });

  final String businessName;
  final String partnerType;
  final String city;
  final String whatsapp;
  final String description;
  final String district;

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'partnerType': partnerType,
      'city': city,
      'district': district,
      'whatsapp': whatsapp,
      'description': description,
    };
  }
}

class VenueDraft {
  const VenueDraft({
    required this.name,
    required this.venueType,
    required this.city,
    required this.capacity,
    required this.startingPrice,
    required this.eventTypes,
    required this.amenities,
    required this.photos,
    required this.businessHours,
    this.shortDescription = '',
    this.description = '',
    this.district = '',
    this.address = '',
    this.googleMapsUrl = '',
    this.country = 'Togo',
    this.coverPhoto = '',
    this.videoUrl = '',
    this.latitude,
    this.longitude,
  });

  final String name;
  final String venueType;
  final String city;
  final int capacity;
  final double startingPrice;
  final List<String> eventTypes;
  final List<String> amenities;
  final List<String> photos;
  final BusinessHours businessHours;
  final String shortDescription;
  final String description;
  final String district;
  final String address;
  final String googleMapsUrl;
  final String country;
  final String coverPhoto;
  final String videoUrl;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'venueType': venueType,
      'shortDescription': shortDescription,
      'description': description,
      'city': city,
      'district': district,
      'address': address,
      'googleMapsUrl': googleMapsUrl,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'startingPrice': startingPrice,
      'eventTypes': eventTypes,
      'amenities': amenities,
      'photos': photos,
      'videoUrl': videoUrl,
      'coverPhoto': coverPhoto,
      'businessHours': businessHours.toJson(),
    };
  }
}

class ProviderDraft {
  const ProviderDraft({
    required this.name,
    required this.category,
    required this.city,
    required this.startingPrice,
    this.description = '',
    this.photoUrl = '',
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
  });

  final String name;
  final String category;
  final String city;
  final double startingPrice;
  final String description;
  final String photoUrl;
  final String phone;
  final String whatsapp;
  final String email;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'city': city,
      'startingPrice': startingPrice,
      'description': description,
      'photoUrl': photoUrl,
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
    };
  }
}

class ManualBookingDraft {
  const ManualBookingDraft({
    required this.venueId,
    required this.customerName,
    required this.customerPhone,
    required this.eventType,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.guestCount,
    this.notes = '',
    this.budget,
    this.totalAmount,
    this.depositAmount,
    this.status = 'confirmed',
  });

  final String venueId;
  final String customerName;
  final String customerPhone;
  final String eventType;
  final DateTime eventDate;
  final String startTime;
  final String endTime;
  final int guestCount;
  final String notes;
  final double? budget;
  final double? totalAmount;
  final double? depositAmount;
  final String status;
}
