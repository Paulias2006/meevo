import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class MeevoApiException implements Exception {
  const MeevoApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MeevoApi {
  static const _productionUrl = 'https://meevo.onrender.com/api';

  String get _fallbackBaseUrl {
    // Toujours utiliser l'URL Render (production)
    return _productionUrl;
  }

  String get baseUrl => _fallbackBaseUrl;

  String get socketUrl => (baseUrl).replaceFirst(RegExp(r'/api/?$'), '');

  Future<String> _effectiveBaseUrl() async {
    return _productionUrl;
  }

  static const _providersPageSize = 55;

  Future<HomeData> fetchHomeData() async {
    final json = await _get('/dashboard/home');
    return HomeData.fromJson(json);
  }

  static const _venuesPageSize = 55;

  Future<VenueSearchResponse> fetchVenues(VenueSearchFilters filters) async {
    final query = <String, String>{
      'limit': _venuesPageSize.toString(),
      'page': filters.page.toString(),
    };

    if (filters.query.trim().isNotEmpty) {
      query['q'] = filters.query.trim();
    }
    if (filters.city != 'Tout le Togo') {
      query['city'] = filters.city;
    }
    if (filters.eventType.isNotEmpty) {
      query['eventType'] = filters.eventType;
    }
    if (filters.guests > 0) {
      query['minCapacity'] = filters.guests.toString();
    }
    if (filters.maxPrice != null) {
      query['maxPrice'] = filters.maxPrice.toString();
    }
    if (filters.date != null) {
      query['date'] = _asDateString(filters.date!);
    }
    if (filters.startTime != null && filters.endTime != null) {
      query['startTime'] = filters.startTime!;
      query['endTime'] = filters.endTime!;
    }

    final json = await _get('/venues', query: query);
    return VenueSearchResponse.fromJson(json);
  }

  Future<ProviderSearchResponse> fetchProviders(
    ProviderSearchFilters filters, {
    bool featuredOnly = false,
  }) async {
    final query = <String, String>{
      'limit': _providersPageSize.toString(),
      'page': filters.page.toString(),
      if (featuredOnly) 'featured': 'true',
    };

    if (filters.query.trim().isNotEmpty) {
      query['q'] = filters.query.trim();
    }
    if (filters.city != 'Tout le Togo') {
      query['city'] = filters.city;
    }
    if (filters.category.isNotEmpty && filters.category != 'Tous') {
      query['category'] = filters.category;
    }

    final json = await _get('/providers', query: query);
    return ProviderSearchResponse.fromJson(json);
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String city,
  }) async {
    final json = await _post(
      '/auth/register',
      body: {
        'fullName': fullName,
        'email': email,
        'password': password,
        'phone': phone,
        'city': city,
      },
    );

    return AuthSession(
      token: json['token']?.toString() ?? '',
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );

    return AuthSession(
      token: json['token']?.toString() ?? '',
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Future<AppUser> fetchMe(String token) async {
    final json = await _get('/auth/me', token: token);
    return AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {});
  }

  Future<AuthSession> becomePartner(
    String token,
    PartnerOnboardingDraft draft,
  ) async {
    final json = await _post(
      '/auth/become-partner',
      token: token,
      body: draft.toJson(),
    );

    return AuthSession(
      token: json['token']?.toString() ?? token,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Future<SubscriptionOverview> fetchSubscriptionOverview(String token) async {
    final json = await _get('/subscriptions/me', token: token);
    return SubscriptionOverview.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<SubscriptionCheckoutResult> startSubscriptionCheckout({
    required String token,
    required int months,
    required String network,
    required String phoneNumber,
  }) async {
    final json = await _post(
      '/subscriptions/checkout',
      token: token,
      body: {'months': months, 'network': network, 'phoneNumber': phoneNumber},
    );
    return SubscriptionCheckoutResult.fromJson(json);
  }

  Future<SubscriptionVerificationResult> verifySubscriptionPayment({
    required String token,
    String? identifier,
  }) async {
    final json = await _post(
      '/subscriptions/verify',
      token: token,
      body: {
        if (identifier != null && identifier.isNotEmpty)
          'identifier': identifier,
      },
    );
    return SubscriptionVerificationResult.fromJson(json);
  }

  Future<AdminSubscriptionResponse> fetchAdminSubscriptions({
    required String token,
    String query = '',
    String status = 'Tous',
    String subscriptionState = 'Tous',
    String network = 'Tous',
    int? year,
    int? month,
  }) async {
    final json = await _get(
      '/subscriptions/admin',
      token: token,
      query: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (status != 'Tous') 'status': status,
        if (subscriptionState != 'Tous') 'subscriptionState': subscriptionState,
        if (network != 'Tous') 'network': network,
        if (year != null) 'year': year.toString(),
        if (month != null) 'month': month.toString(),
      },
    );
    return AdminSubscriptionResponse.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AdminUsersResponse> fetchAdminUsers({
    required String token,
    String query = '',
    String role = 'Tous',
    String subscriptionStatus = 'Tous',
    String city = '',
    String from = '',
    String to = '',
  }) async {
    final json = await _get(
      '/admin/users',
      token: token,
      query: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (role != 'Tous') 'role': role,
        if (subscriptionStatus != 'Tous')
          'subscriptionStatus': subscriptionStatus,
        if (city.trim().isNotEmpty) 'city': city.trim(),
        if (from.trim().isNotEmpty) 'from': from.trim(),
        if (to.trim().isNotEmpty) 'to': to.trim(),
      },
    );
    return AdminUsersResponse.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AdminUserRecord> createAdminUser({
    required String token,
    required String fullName,
    required String email,
    required String password,
    String phone = '',
    String city = '',
  }) async {
    final json = await _post(
      '/admin/users/admin',
      token: token,
      body: {
        'fullName': fullName,
        'email': email,
        'password': password,
        'phone': phone,
        'city': city,
      },
    );
    return AdminUserRecord.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AdminUserRecord> updateAdminUserAdminStatus({
    required String token,
    required String userId,
    required bool isAdmin,
  }) async {
    final json = await _patch(
      '/admin/users/$userId/admin',
      token: token,
      body: {'isAdmin': isAdmin},
    );
    return AdminUserRecord.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<void> deleteAdminUser({
    required String token,
    required String userId,
  }) async {
    await _delete('/admin/users/$userId', token: token);
  }

  Future<List<BookingItem>> fetchBookings(String token) async {
    final json = await _get('/bookings', token: token);
    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(BookingItem.fromJson)
        .toList();
  }

  Future<BookingCheckoutResult> startBookingCheckout({
    required String token,
    required String venueId,
    required String eventType,
    required DateTime eventDate,
    required String network,
    required String phoneNumber,
    String? startTime,
    String? endTime,
    required int guestCount,
    String notes = '',
    double? budget,
  }) async {
    final body = <String, dynamic>{
      'venueId': venueId,
      'eventType': eventType,
      'eventDate': _asDateString(eventDate),
      'network': network,
      'phoneNumber': phoneNumber,
      'guestCount': guestCount,
      'notes': notes,
      ...?startTime == null ? null : {'startTime': startTime},
      ...?endTime == null ? null : {'endTime': endTime},
      ...?budget == null ? null : {'budget': budget},
    };

    final json = await _post('/bookings/checkout', token: token, body: body);
    return BookingCheckoutResult.fromJson(json);
  }

  Future<BookingPaymentVerificationResult> verifyBookingPayment({
    required String token,
    String? identifier,
  }) async {
    final json = await _post(
      '/bookings/verify-payment',
      token: token,
      body: {
        if (identifier != null && identifier.isNotEmpty)
          'identifier': identifier,
      },
    );
    return BookingPaymentVerificationResult.fromJson(json);
  }

  Future<Set<String>> fetchBlockedDates(String venueId) async {
    final json = await _get('/venues/$venueId/availability');
    final dates = (json['blockedDates'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toSet();
    return dates;
  }

  Future<VenueAvailability> fetchAvailability({
    required String venueId,
    required DateTime date,
  }) async {
    final json = await _get(
      '/venues/$venueId/availability',
      query: {'date': _asDateString(date)},
    );
    return VenueAvailability.fromJson(json);
  }

  Future<MonthlyAvailability> fetchMonthlyAvailability({
    required String venueId,
    required DateTime month,
  }) async {
    final monthString =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final json = await _get(
      '/venues/$venueId/availability/month',
      query: {'month': monthString},
    );
    return MonthlyAvailability.fromJson(json);
  }

  Future<List<Venue>> fetchMyVenues(String token) async {
    final json = await _get('/venues/mine', token: token);
    final items = json['items'] as List<dynamic>? ?? const [];
    return items.whereType<Map<String, dynamic>>().map(Venue.fromJson).toList();
  }

  Future<List<ProviderProfile>> fetchMyProviders(String token) async {
    final json = await _get('/providers/mine', token: token);
    final items = json['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ProviderProfile.fromJson)
        .toList();
  }

  Future<Venue> createVenue({
    required String token,
    required VenueDraft draft,
  }) async {
    final json = await _post('/venues', token: token, body: draft.toJson());
    return Venue.fromJson(json['item'] as Map<String, dynamic>? ?? const {});
  }

  Future<ProviderProfile> createProvider({
    required String token,
    required ProviderDraft draft,
  }) async {
    final json = await _post('/providers', token: token, body: draft.toJson());
    return ProviderProfile.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<Venue> updateVenue({
    required String token,
    required String venueId,
    required Map<String, dynamic> data,
  }) async {
    final json = await _patch('/venues/$venueId', token: token, body: data);
    return Venue.fromJson(json['item'] as Map<String, dynamic>? ?? const {});
  }

  Future<ProviderProfile> updateProvider({
    required String token,
    required String providerId,
    required Map<String, dynamic> data,
  }) async {
    final json = await _patch(
      '/providers/$providerId',
      token: token,
      body: data,
    );
    return ProviderProfile.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<BookingItem> createManualBooking({
    required String token,
    required ManualBookingDraft draft,
  }) async {
    final json = await _post(
      '/bookings/manual',
      token: token,
      body: {
        'venueId': draft.venueId,
        'customerName': draft.customerName,
        'customerPhone': draft.customerPhone,
        'eventType': draft.eventType,
        'eventDate': _asDateString(draft.eventDate),
        'startTime': draft.startTime,
        'endTime': draft.endTime,
        'guestCount': draft.guestCount,
        'notes': draft.notes,
        'status': draft.status,
        if (draft.budget != null) 'budget': draft.budget,
        if (draft.totalAmount != null) 'totalAmount': draft.totalAmount,
        if (draft.depositAmount != null) 'depositAmount': draft.depositAmount,
      },
    );
    return BookingItem.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<MediaUploadResult> uploadCloudinaryMedia({
    required String token,
    required String fileBase64,
    required String fileName,
    required String mimeType,
    required String resourceType,
    String folder = 'meevo/uploads',
  }) async {
    final json = await _post(
      '/uploads/cloudinary',
      token: token,
      body: {
        'fileBase64': fileBase64,
        'fileName': fileName,
        'mimeType': mimeType,
        'resourceType': resourceType,
        'folder': folder,
      },
    );

    return MediaUploadResult.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<void> deleteBooking({
    required String token,
    required String bookingId,
  }) async {
    await _delete('/bookings/$bookingId', token: token);
  }

  Future<AuthSession> updatePayoutProfile({
    required String token,
    required String phoneNumber,
    required String network,
    required String accountName,
  }) async {
    final json = await _patch(
      '/auth/payout-profile',
      token: token,
      body: {
        'phoneNumber': phoneNumber,
        'network': network,
        'accountName': accountName,
      },
    );
    return AuthSession(
      token: token,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
    );
  }

  Future<ReservationFinanceResponse> fetchPartnerReservationFinance({
    required String token,
    String query = '',
    String payoutStatus = 'Tous',
    String withdrawalStatus = 'Tous',
    String network = 'Tous',
    String range = 'all',
    int? year,
    int? month,
  }) async {
    final json = await _get(
      '/bookings/finance/partner',
      token: token,
      query: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (payoutStatus != 'Tous') 'payoutStatus': payoutStatus,
        if (withdrawalStatus != 'Tous') 'withdrawalStatus': withdrawalStatus,
        if (network != 'Tous') 'network': network,
        if (range != 'all') 'range': range,
        if (year != null) 'year': year.toString(),
        if (month != null) 'month': month.toString(),
      },
    );
    return ReservationFinanceResponse.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<ReservationFinanceResponse> fetchAdminReservationFinance({
    required String token,
    String query = '',
    String payoutStatus = 'Tous',
    String withdrawalStatus = 'Tous',
    String network = 'Tous',
    String range = 'all',
    int? year,
    int? month,
  }) async {
    final json = await _get(
      '/bookings/finance/admin',
      token: token,
      query: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (payoutStatus != 'Tous') 'payoutStatus': payoutStatus,
        if (withdrawalStatus != 'Tous') 'withdrawalStatus': withdrawalStatus,
        if (network != 'Tous') 'network': network,
        if (range != 'all') 'range': range,
        if (year != null) 'year': year.toString(),
        if (month != null) 'month': month.toString(),
      },
    );
    return ReservationFinanceResponse.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<ReservationPaymentData> markReservationPayoutPaid({
    required String token,
    required String paymentId,
    String payoutReference = '',
    String payoutNotes = '',
  }) async {
    final json = await _patch(
      '/bookings/finance/admin/$paymentId/payout',
      token: token,
      body: {'payoutReference': payoutReference, 'payoutNotes': payoutNotes},
    );
    return ReservationPaymentData.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<WithdrawalData> createPartnerWithdrawal({
    required String token,
    required double amount,
    String? network,
    String? phoneNumber,
    String? accountName,
  }) async {
    final json = await _post(
      '/bookings/finance/partner/withdrawals',
      token: token,
      body: {
        'amount': amount,
        if (network != null && network.trim().isNotEmpty) 'network': network,
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phoneNumber': phoneNumber,
        if (accountName != null && accountName.trim().isNotEmpty)
          'accountName': accountName,
      },
    );
    return WithdrawalData.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<WithdrawalData> updateAdminWithdrawal({
    required String token,
    required String withdrawalId,
    required String status,
    String adminNotes = '',
  }) async {
    final json = await _patch(
      '/bookings/finance/admin/withdrawals/$withdrawalId',
      token: token,
      body: {'status': status, 'adminNotes': adminNotes},
    );
    return WithdrawalData.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<ResolvedLocationData> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _get(
      '/location/reverse',
      query: {'lat': latitude.toString(), 'lng': longitude.toString()},
    );

    return ResolvedLocationData.fromJson(
      json['item'] as Map<String, dynamic>? ?? const {},
    );
  }

  static const _requestTimeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
    String? token,
  }) async {
    final resolvedBaseUrl = await _effectiveBaseUrl();
    final uri = Uri.parse(
      '$resolvedBaseUrl$path',
    ).replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(
          _requestTimeout,
          onTimeout: () => throw MeevoApiException(
            'La requête a expiré après ${_requestTimeout.inSeconds}s. Verifiez votre connexion.',
          ),
        );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    final resolvedBaseUrl = await _effectiveBaseUrl();
    final uri = Uri.parse('$resolvedBaseUrl$path');
    final response = await http
        .post(uri, headers: _headers(token), body: jsonEncode(body))
        .timeout(
          _requestTimeout,
          onTimeout: () => throw MeevoApiException(
            'La requête a expiré après ${_requestTimeout.inSeconds}s. Verifiez votre connexion.',
          ),
        );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _patch(
    String path, {
    required Map<String, dynamic> body,
    String? token,
  }) async {
    final resolvedBaseUrl = await _effectiveBaseUrl();
    final uri = Uri.parse('$resolvedBaseUrl$path');
    final response = await http
        .patch(uri, headers: _headers(token), body: jsonEncode(body))
        .timeout(
          _requestTimeout,
          onTimeout: () => throw MeevoApiException(
            'La requête a expiré après ${_requestTimeout.inSeconds}s. Verifiez votre connexion.',
          ),
        );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _delete(String path, {String? token}) async {
    final resolvedBaseUrl = await _effectiveBaseUrl();
    final uri = Uri.parse('$resolvedBaseUrl$path');
    final response = await http
        .delete(uri, headers: _headers(token))
        .timeout(
          _requestTimeout,
          onTimeout: () => throw MeevoApiException(
            'La requête a expiré après ${_requestTimeout.inSeconds}s. Verifiez votre connexion.',
          ),
        );
    return _decode(response);
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode >= 400) {
      throw MeevoApiException(
        map['message']?.toString() ?? 'Une erreur est survenue.',
      );
    }

    return map;
  }

  String _asDateString(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
