import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'meevo_api.dart';
import 'models.dart';

class MeevoState extends ChangeNotifier {
  MeevoState(this._api);

  final MeevoApi _api;

  static const _tokenKey = 'meevo_token';
  static const _subscriptionReminderKey = 'meevo_subscription_reminder';

  HomeData homeData = const HomeData.empty();
  List<Venue> searchResults = const [];
  PaginationInfo searchPagination = const PaginationInfo.empty();
  List<ProviderProfile> providers = const [];
  ProviderSearchFilters providerFilters = const ProviderSearchFilters();
  PaginationInfo providerPagination = const PaginationInfo.empty();
  List<BookingItem> bookings = const [];
  List<Venue> myVenues = const [];
  List<ProviderProfile> myProviders = const [];
  SubscriptionOverview subscriptionOverview =
      const SubscriptionOverview.empty();
  ReservationPaymentData? currentReservationPayment;
  VenueSearchFilters filters = const VenueSearchFilters();
  final Map<String, VenueAvailability> _availabilityCache = {};
  final Map<String, MonthlyAvailability> _monthlyAvailabilityCache = {};

  AppUser? currentUser;
  String? _token;
  String authMode = 'login';
  String? errorMessage;
  String? infoMessage;

  bool isBootstrapping = true;
  bool isHomeLoading = false;
  bool isSearchLoading = false;
  bool isAuthLoading = false;
  bool isBookingsLoading = false;
  bool isPartnerLoading = false;
  bool isPartnerSaving = false;
  bool isMediaUploading = false;
  bool isSubscriptionLoading = false;
  bool isSubscriptionStarting = false;
  bool isSubscriptionVerifying = false;
  bool isBookingPaymentStarting = false;
  bool isBookingPaymentVerifying = false;
  bool isPayoutProfileSaving = false;
  bool realtimeConnected = false;
  int realtimeUpdateVersion = 0;
  int pageIndex = 0;

  io.Socket? _socket;
  Timer? _refreshDebounce;

  bool get isAuthenticated => _token != null && currentUser != null;
  bool get isAdmin => currentUser?.role == 'admin';
  PartnerSubscriptionData? get partnerSubscription =>
      subscriptionOverview.subscription ?? currentUser?.subscription;
  bool get hasPartnerProfile =>
      currentUser?.partnerProfile != null ||
      currentUser?.role == 'partner' ||
      currentUser?.role == 'admin';
  bool get hasActivePartnerSubscription =>
      isAdmin || partnerSubscription?.isActive == true;
  bool get needsPartnerSubscription =>
      hasPartnerProfile && !hasActivePartnerSubscription;
  bool get hasPartnerAccess =>
      currentUser != null &&
      ((currentUser!.role == 'partner' && hasActivePartnerSubscription) ||
          currentUser!.role == 'admin');
  bool get hasVenuePartnerAccess {
    if (!hasPartnerAccess) return false;
    final type = currentUser?.partnerProfile?.partnerType.toLowerCase().trim();
    if (type == null || type.isEmpty) {
      return true;
    }
    return type.contains('salle') ||
        type.contains('hotel') ||
        type.contains('lieu');
  }

  bool get hasProviderPartnerAccess {
    if (!hasPartnerAccess) return false;
    final type = currentUser?.partnerProfile?.partnerType.toLowerCase().trim();
    if (type == null || type.isEmpty) {
      return false;
    }
    return type.contains('presta');
  }

  String? get token => _token;
  MeevoApi get api => _api;

  Future<void> bootstrap() async {
    isBootstrapping = true;
    notifyListeners();

    const fallbackTimeout = Duration(seconds: 35);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);

      if (savedToken != null && savedToken.isNotEmpty) {
        try {
          final user = await _api.fetchMe(savedToken);
          _token = savedToken;
          currentUser = user;
          _connectRealtime();
        } catch (_) {
          await prefs.remove(_tokenKey);
        }
      }

      await Future.wait([
        loadHome(silent: true),
        searchVenues(silent: true),
        loadProviders(silent: true),
        if (isAuthenticated) loadBookings(silent: true),
        if (isAuthenticated && hasPartnerProfile)
          loadSubscriptionOverview(silent: true),
        if (hasPartnerAccess) loadPartnerData(silent: true),
      ]).timeout(fallbackTimeout);
    } on TimeoutException {
      errorMessage = 'Chargement initial trop lent. Rechargez la page.';
    } finally {
      isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> loadHome({bool silent = false}) async {
    if (!silent) {
      isHomeLoading = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      homeData = await _api.fetchHomeData();
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Impossible de charger l accueil.';
    } finally {
      isHomeLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProviders({
    ProviderSearchFilters? newFilters,
    bool silent = false,
  }) async {
    if (!silent) {
      notifyListeners();
    }

    try {
      if (newFilters != null) {
        providerFilters = newFilters;
      }
      final response = await _api.fetchProviders(providerFilters);
      providers = response.items;
      providerPagination = response.pagination;
    } catch (_) {
      if (providers.isEmpty) {
        providers = const [];
        providerPagination = const PaginationInfo.empty();
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> searchVenues({
    VenueSearchFilters? newFilters,
    bool silent = false,
  }) async {
    if (newFilters != null) {
      filters = newFilters;
    }

    if (!silent) {
      isSearchLoading = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      final fetched = await _api.fetchVenues(filters);
      if (filters.eventType.isNotEmpty && fetched.items.isEmpty) {
        final relaxed = await _api.fetchVenues(filters.copyWith(eventType: ''));
        searchResults = relaxed.items;
        searchPagination = relaxed.pagination;
        infoMessage =
            'Aucun lieu pour cet evenement. Affichage des lieux disponibles.';
        return;
      }
      final rawQuery = filters.query.trim();
      if (rawQuery.isNotEmpty) {
        final fuzzy = _applyFuzzyQuery(fetched.items, rawQuery);
        if (fuzzy.isNotEmpty) {
          searchResults = fuzzy;
          searchPagination = fetched.pagination;
        } else {
          final relaxedFilters = filters.copyWith(query: '');
          final relaxed = await _api.fetchVenues(relaxedFilters);
          searchResults = _applyFuzzyQuery(relaxed.items, rawQuery);
          searchPagination = relaxed.pagination;
        }
      } else {
        searchResults = fetched.items;
        searchPagination = fetched.pagination;
      }
      infoMessage = null;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      if (searchResults.isEmpty) {
        searchResults = const [];
        searchPagination = const PaginationInfo.empty();
      }
    } catch (_) {
      errorMessage = 'La recherche des salles a echoue.';
      if (searchResults.isEmpty) {
        searchResults = const [];
        searchPagination = const PaginationInfo.empty();
      }
    } finally {
      isSearchLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBookings({bool silent = false}) async {
    if (!isAuthenticated) return;

    if (!silent) {
      isBookingsLoading = true;
      notifyListeners();
    }

    try {
      bookings = await _api.fetchBookings(_token!);
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Impossible de charger les reservations.';
    } finally {
      isBookingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPartnerData({bool silent = false}) async {
    if (!hasPartnerAccess || _token == null) return;

    if (!silent) {
      isPartnerLoading = true;
      notifyListeners();
    }

    try {
      myVenues = await _api.fetchMyVenues(_token!);
      myProviders = await _api.fetchMyProviders(_token!);
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Impossible de charger l espace partenaire.';
    } finally {
      isPartnerLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    isAuthLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final session = await _api.login(email: email, password: password);
      await _persistSession(session);
      infoMessage = 'Connexion reussie.';
      authMode = 'login';
      pageIndex = 0;
      await loadBookings(silent: true);
      await loadSubscriptionOverview(silent: true);
      await loadPartnerData(silent: true);
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Connexion impossible pour le moment.';
    } finally {
      isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String city,
  }) async {
    isAuthLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final session = await _api.register(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
        city: city,
      );
      await _persistSession(session);
      infoMessage = 'Compte cree avec succes.';
      authMode = 'login';
      pageIndex = 0;
      await loadSubscriptionOverview(silent: true);
      await loadPartnerData(silent: true);
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Inscription impossible pour le moment.';
    } finally {
      isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    currentUser = null;
    bookings = const [];
    myVenues = const [];
    myProviders = const [];
    subscriptionOverview = const SubscriptionOverview.empty();
    currentReservationPayment = null;
    _availabilityCache.clear();
    _socket?.dispose();
    _socket = null;
    realtimeConnected = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    infoMessage = 'Vous etes deconnecte.';
    notifyListeners();
  }

  Future<bool> becomePartner(PartnerOnboardingDraft draft) async {
    if (!isAuthenticated || _token == null) {
      pageIndex = 3;
      authMode = 'login';
      notifyListeners();
      return false;
    }

    isAuthLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final session = await _api.becomePartner(_token!, draft);
      await _persistSession(session);
      currentUser = session.user;
      infoMessage =
          'Dossier partenaire enregistre. Choisissez maintenant votre abonnement.';
      pageIndex = 3;
      await loadSubscriptionOverview(silent: true);
      notifyListeners();
      return true;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = 'Activation du mode partenaire impossible pour le moment.';
      notifyListeners();
      return false;
    } finally {
      isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSubscriptionOverview({bool silent = false}) async {
    if (!isAuthenticated || _token == null || !hasPartnerProfile) return;

    if (!silent) {
      isSubscriptionLoading = true;
      notifyListeners();
    }

    try {
      subscriptionOverview = await _api.fetchSubscriptionOverview(_token!);
      await _scheduleSubscriptionReminder();
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Impossible de charger l abonnement partenaire.';
    } finally {
      isSubscriptionLoading = false;
      notifyListeners();
    }
  }

  Future<AdminSubscriptionResponse> loadAdminSubscriptions({
    String paymentStatus = 'Tous',
    int? year,
    int? month,
  }) async {
    if (_token == null) return const AdminSubscriptionResponse.empty();

    try {
      return await _api.fetchAdminSubscriptions(
        token: _token!,
        status: paymentStatus,
        year: year,
        month: month,
      );
    } catch (_) {
      return const AdminSubscriptionResponse.empty();
    }
  }

  Future<SubscriptionCheckoutResult?> startSubscriptionCheckout({
    required int months,
    required String network,
    required String phoneNumber,
  }) async {
    if (!isAuthenticated || _token == null) return null;

    isSubscriptionStarting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.startSubscriptionCheckout(
        token: _token!,
        months: months,
        network: network,
        phoneNumber: phoneNumber,
      );
      currentUser = result.user;
      subscriptionOverview = result.overview;
      infoMessage = 'Paiement initialise. Finalisez maintenant sur CinetPay.';
      return result;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (_) {
      errorMessage = 'Impossible de lancer le paiement pour le moment.';
      return null;
    } finally {
      isSubscriptionStarting = false;
      notifyListeners();
    }
  }

  Future<SubscriptionVerificationResult?> verifySubscriptionPayment({
    String? identifier,
  }) async {
    if (!isAuthenticated || _token == null) return null;

    final wasAlreadyActive = partnerSubscription?.isActive == true;
    isSubscriptionVerifying = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.verifySubscriptionPayment(
        token: _token!,
        identifier: identifier,
      );
      currentUser = result.user;
      subscriptionOverview = result.overview;
      if (result.user.subscription?.isActive == true) {
        infoMessage = wasAlreadyActive
            ? 'Abonnement renouvele avec succes.'
            : 'Abonnement actif. Votre dashboard partenaire est ouvert.';
        await loadPartnerData(silent: true);
      } else {
        infoMessage = 'Statut du paiement actualise.';
      }
      return result;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (_) {
      errorMessage = 'Verification du paiement impossible pour le moment.';
      return null;
    } finally {
      isSubscriptionVerifying = false;
      notifyListeners();
    }
  }

  Future<BookingCheckoutResult?> startBookingCheckout({
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
    if (!isAuthenticated) {
      errorMessage = 'Connectez-vous pour reserver.';
      pageIndex = 3;
      authMode = 'login';
      notifyListeners();
      return null;
    }

    isBookingPaymentStarting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.startBookingCheckout(
        token: _token!,
        venueId: venueId,
        eventType: eventType,
        eventDate: eventDate,
        network: network,
        phoneNumber: phoneNumber,
        startTime: startTime,
        endTime: endTime,
        guestCount: guestCount,
        notes: notes,
        budget: budget,
      );
      currentReservationPayment = result.payment;
      infoMessage =
          'Paiement reservation initialise. Finalisez maintenant sur CinetPay.';
      _invalidateAvailabilityForVenue(venueId, eventDate);
      _invalidateMonthlyAvailability(venueId, eventDate);
      notifyListeners();
      return result;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return null;
    } catch (_) {
      errorMessage = 'Impossible de lancer le paiement de reservation.';
      notifyListeners();
      return null;
    } finally {
      isBookingPaymentStarting = false;
      notifyListeners();
    }
  }

  Future<BookingPaymentVerificationResult?> verifyBookingPayment({
    String? identifier,
  }) async {
    if (!isAuthenticated || _token == null) return null;

    isBookingPaymentVerifying = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.verifyBookingPayment(
        token: _token!,
        identifier: identifier,
      );
      currentReservationPayment = result.payment;
      if (result.booking != null) {
        bookings = [result.booking!, ...bookings];
        final eventDate =
            DateTime.tryParse(result.booking!.eventDate) ?? DateTime.now();
        final venueId = result.booking!.venue?.id;
        if (venueId != null) {
          _invalidateAvailabilityForVenue(venueId, eventDate);
          _invalidateMonthlyAvailability(venueId, eventDate);
        }
        infoMessage = 'Reservation payee et confirmee avec succes.';
        pageIndex = 2;
      } else {
        infoMessage = 'Statut du paiement de reservation actualise.';
      }
      notifyListeners();
      return result;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return null;
    } catch (_) {
      errorMessage = 'Verification du paiement reservation impossible.';
      notifyListeners();
      return null;
    } finally {
      isBookingPaymentVerifying = false;
      notifyListeners();
    }
  }

  Future<bool> updatePayoutProfile({
    required String phoneNumber,
    required String network,
    required String accountName,
  }) async {
    if (!isAuthenticated || _token == null) return false;

    isPayoutProfileSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final session = await _api.updatePayoutProfile(
        token: _token!,
        phoneNumber: phoneNumber,
        network: network,
        accountName: accountName,
      );
      currentUser = session.user;
      infoMessage = 'Numero de reversement enregistre.';
      notifyListeners();
      return true;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = 'Impossible d enregistrer le numero de reversement.';
      notifyListeners();
      return false;
    } finally {
      isPayoutProfileSaving = false;
      notifyListeners();
    }
  }

  Future<Set<String>> fetchBlockedDates(String venueId) {
    return _api.fetchBlockedDates(venueId);
  }

  Future<VenueAvailability> fetchAvailability({
    required String venueId,
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    final key = _availabilityKey(venueId, date);
    if (!forceRefresh && _availabilityCache.containsKey(key)) {
      return _availabilityCache[key]!;
    }

    final availability = await _api.fetchAvailability(
      venueId: venueId,
      date: date,
    );
    _availabilityCache[key] = availability;
    notifyListeners();
    return availability;
  }

  Future<MonthlyAvailability> fetchMonthlyAvailability({
    required String venueId,
    required DateTime month,
    bool forceRefresh = false,
  }) async {
    final key = _monthlyKey(venueId, month);
    if (!forceRefresh && _monthlyAvailabilityCache.containsKey(key)) {
      return _monthlyAvailabilityCache[key]!;
    }

    final availability = await _api.fetchMonthlyAvailability(
      venueId: venueId,
      month: month,
    );
    _monthlyAvailabilityCache[key] = availability;
    notifyListeners();
    return availability;
  }

  VenueAvailability? cachedAvailability({
    required String venueId,
    required DateTime date,
  }) {
    return _availabilityCache[_availabilityKey(venueId, date)];
  }

  Future<Venue?> createVenue(VenueDraft draft) async {
    if (!hasPartnerAccess || _token == null) return null;

    isPartnerSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final venue = await _api.createVenue(token: _token!, draft: draft);
      myVenues = [venue, ...myVenues];
      infoMessage = 'Lieu ajoute avec succes.';
      await loadHome(silent: true);
      await searchVenues(silent: true);
      return venue;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (_) {
      errorMessage = 'Ajout du lieu impossible pour le moment.';
      return null;
    } finally {
      isPartnerSaving = false;
      notifyListeners();
    }
  }

  Future<Venue?> updateVenue({
    required String venueId,
    required Map<String, dynamic> data,
  }) async {
    if (!hasPartnerAccess || _token == null) return null;

    isPartnerSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final venue = await _api.updateVenue(
        token: _token!,
        venueId: venueId,
        data: data,
      );
      myVenues = [
        for (final item in myVenues)
          if (item.id == venueId) venue else item,
      ];
      searchResults = [
        for (final item in searchResults)
          if (item.id == venueId) venue else item,
      ];
      infoMessage = 'Lieu mis a jour.';
      await loadHome(silent: true);
      await searchVenues(silent: true);
      return venue;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (_) {
      errorMessage = 'Impossible de modifier le lieu.';
      return null;
    } finally {
      isPartnerSaving = false;
      notifyListeners();
    }
  }

  Future<ProviderProfile?> createProvider(ProviderDraft draft) async {
    if (!hasPartnerAccess || _token == null) return null;

    isPartnerSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final provider = await _api.createProvider(token: _token!, draft: draft);
      myProviders = [provider, ...myProviders];
      infoMessage = 'Prestataire ajoute avec succes.';
      await loadProviders(
        silent: true,
        newFilters: providerFilters.copyWith(page: 1),
      );
      return provider;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (_) {
      errorMessage = 'Ajout du prestataire impossible pour le moment.';
      return null;
    } finally {
      isPartnerSaving = false;
      notifyListeners();
    }
  }

  Future<ProviderProfile?> updateProvider({
    required String providerId,
    required Map<String, dynamic> data,
  }) async {
    if (!hasPartnerAccess || _token == null) return null;

    isPartnerSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final provider = await _api.updateProvider(
        token: _token!,
        providerId: providerId,
        data: data,
      );
      myProviders = [
        for (final item in myProviders)
          if (item.id == providerId) provider else item,
      ];
      providers = [
        for (final item in providers)
          if (item.id == providerId) provider else item,
      ];
      infoMessage = 'Prestataire mis a jour.';
      await loadProviders(
        silent: true,
        newFilters: providerFilters.copyWith(page: 1),
      );
      return provider;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (_) {
      errorMessage = 'Impossible de modifier le prestataire.';
      return null;
    } finally {
      isPartnerSaving = false;
      notifyListeners();
    }
  }

  Future<BookingItem?> createManualBooking(ManualBookingDraft draft) async {
    if (!hasPartnerAccess || _token == null) return null;

    isPartnerSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final booking = await _api.createManualBooking(
        token: _token!,
        draft: draft,
      );
      bookings = [booking, ...bookings];
      _invalidateAvailabilityForVenue(draft.venueId, draft.eventDate);
      _invalidateMonthlyAvailability(draft.venueId, draft.eventDate);
      infoMessage = 'Reservation hors plateforme ajoutee.';
      return booking;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (_) {
      errorMessage = 'Reservation manuelle impossible pour le moment.';
      return null;
    } finally {
      isPartnerSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteBooking(BookingItem booking) async {
    if (!isAuthenticated || _token == null) {
      errorMessage = 'Connectez-vous pour supprimer une reservation.';
      pageIndex = 3;
      authMode = 'login';
      notifyListeners();
      return false;
    }

    try {
      await _api.deleteBooking(token: _token!, bookingId: booking.id);
      bookings = bookings.where((item) => item.id != booking.id).toList();
      final venueId = booking.venue?.id;
      final eventDate = DateTime.tryParse(booking.eventDate);
      if (venueId != null && eventDate != null) {
        _invalidateAvailabilityForVenue(venueId, eventDate);
        _invalidateMonthlyAvailability(venueId, eventDate);
      }
      infoMessage = 'Reservation supprimee.';
      notifyListeners();
      return true;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = 'Suppression impossible pour le moment.';
      notifyListeners();
      return false;
    }
  }

  Future<MediaUploadResult?> uploadPartnerMedia({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required String resourceType,
    String folder = 'meevo/uploads',
  }) async {
    if (!hasPartnerAccess || _token == null) return null;

    isMediaUploading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.uploadCloudinaryMedia(
        token: _token!,
        fileBase64: base64Encode(bytes),
        fileName: fileName,
        mimeType: mimeType,
        resourceType: resourceType,
        folder: folder,
      );
      infoMessage = 'Media televerse avec succes.';
      return result;
    } on MeevoApiException catch (error) {
      errorMessage = error.message;
      return null;
    } catch (_) {
      errorMessage = 'Televersement impossible pour le moment.';
      return null;
    } finally {
      isMediaUploading = false;
      notifyListeners();
    }
  }

  void setPageIndex(int value) {
    pageIndex = value;
    notifyListeners();
  }

  void setAuthMode(String value) {
    authMode = value;
    notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    infoMessage = null;
    notifyListeners();
  }

  Future<void> _scheduleSubscriptionReminder() async {
    if (isAdmin) return;

    final subscription = partnerSubscription;
    if (subscription == null) return;

    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();

    String? reminderMessage;
    bool reminderIsError = false;

    if (subscription.status == 'pending') {
      reminderMessage =
          'Votre abonnement partenaire est en attente. Finalisez ou verifiez le paiement CinetPay.';
    } else {
      final endsAt = subscription.endsAt == null
          ? null
          : DateTime.tryParse(subscription.endsAt!);
      if (endsAt != null) {
        final limit = DateTime(endsAt.year, endsAt.month, endsAt.day);
        final current = DateTime(today.year, today.month, today.day);
        final daysRemaining = limit.difference(current).inDays;

        if (subscription.isActive && daysRemaining <= 7 && daysRemaining >= 0) {
          if (daysRemaining == 0) {
            reminderMessage =
                'Votre abonnement expire aujourd hui. Renouvelez-le maintenant pour garder le dashboard actif.';
          } else if (daysRemaining == 1) {
            reminderMessage =
                'Votre abonnement expire demain. Pensez a le renouveler aujourd hui.';
          } else {
            reminderMessage =
                'Votre abonnement expire dans $daysRemaining jours. Renouvelez-le pour eviter toute interruption.';
          }
        } else if (!subscription.isActive && daysRemaining < 0) {
          reminderMessage =
              'Votre abonnement partenaire a expire. Renouvelez-le pour reactiver vos outils de gestion.';
          reminderIsError = true;
        }
      }
    }

    if (reminderMessage == null) return;

    final reminderFingerprint =
        '${subscription.status}|${subscription.endsAt ?? ''}|$todayKey';
    final savedFingerprint = prefs.getString(_subscriptionReminderKey);
    if (savedFingerprint == reminderFingerprint) return;
    if (errorMessage != null || infoMessage != null) return;

    if (reminderIsError) {
      errorMessage = reminderMessage;
    } else {
      infoMessage = reminderMessage;
    }
    await prefs.setString(_subscriptionReminderKey, reminderFingerprint);
  }

  void refreshFromRealtime() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
      _availabilityCache.clear();
      _monthlyAvailabilityCache.clear();
      unawaited(loadHome(silent: true));
      unawaited(searchVenues(silent: true));
      unawaited(loadProviders(silent: true));
      if (isAuthenticated) {
        unawaited(loadBookings(silent: true));
      }
      if (hasPartnerAccess) {
        unawaited(loadPartnerData(silent: true));
      }
    });
  }

  void _handleRealtimeUpdateEvent() {
    realtimeUpdateVersion++;
    notifyListeners();
    refreshFromRealtime();
  }

  List<Venue> _applyFuzzyQuery(List<Venue> venues, String rawQuery) {
    final query = _normalizeSearch(rawQuery);
    if (query.isEmpty) return venues;

    final scored = <_ScoredVenue>[];
    for (final venue in venues) {
      final score = _scoreVenue(venue, query);
      if (score != null) {
        scored.add(_ScoredVenue(venue, score));
      }
    }

    scored.sort((a, b) {
      final scoreDiff = a.score.compareTo(b.score);
      if (scoreDiff != 0) return scoreDiff;
      return a.venue.name.compareTo(b.venue.name);
    });
    return scored.map((item) => item.venue).toList();
  }

  int? _scoreVenue(Venue venue, String query) {
    final candidates = <String>[
      venue.name,
      venue.city,
      venue.district ?? '',
      venue.venueType,
      venue.shortDescription ?? '',
    ];

    int? bestScore;
    for (final candidate in candidates) {
      final score = _scoreText(candidate, query);
      if (score == null) continue;
      if (bestScore == null || score < bestScore) {
        bestScore = score;
      }
    }
    return bestScore;
  }

  int? _scoreText(String value, String query) {
    final normalized = _normalizeSearch(value);
    if (normalized.isEmpty) return null;
    if (normalized.contains(query)) return 0;

    final maxDistance = query.length <= 4 ? 1 : 2;
    int? bestDistance;
    final parts = normalized.split(RegExp(r'[^a-z0-9]+'));
    for (final part in parts) {
      if (part.isEmpty) continue;
      if (part.contains(query)) return 0;
      final distance = _levenshteinDistance(
        query,
        part,
        maxDistance: maxDistance,
      );
      if (distance <= maxDistance) {
        bestDistance = min(bestDistance ?? distance, distance);
      }
    }

    return bestDistance;
  }

  String _normalizeSearch(String input) {
    final lower = input.toLowerCase();
    final sanitized = lower.replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ');
    return sanitized.replaceAll(RegExp(r'\\s+'), ' ').trim();
  }

  int _levenshteinDistance(
    String source,
    String target, {
    required int maxDistance,
  }) {
    final sourceLength = source.length;
    final targetLength = target.length;
    if ((sourceLength - targetLength).abs() > maxDistance) {
      return maxDistance + 1;
    }

    var previous = List<int>.generate(targetLength + 1, (index) => index);
    for (var i = 1; i <= sourceLength; i++) {
      final current = List<int>.filled(targetLength + 1, 0);
      current[0] = i;
      var bestInRow = current[0];
      for (var j = 1; j <= targetLength; j++) {
        final cost = source[i - 1] == target[j - 1] ? 0 : 1;
        current[j] = min(
          min(previous[j] + 1, current[j - 1] + 1),
          previous[j - 1] + cost,
        );
        if (current[j] < bestInRow) {
          bestInRow = current[j];
        }
      }
      if (bestInRow > maxDistance) {
        return maxDistance + 1;
      }
      previous = current;
    }

    return previous[targetLength];
  }

  Future<void> _persistSession(AuthSession session) async {
    _token = session.token;
    currentUser = session.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    _connectRealtime();
  }

  void _connectRealtime() {
    _socket?.dispose();

    _socket = io.io(
      _api.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket?.onConnect((_) {
      realtimeConnected = true;
      notifyListeners();
    });

    _socket?.onDisconnect((_) {
      realtimeConnected = false;
      notifyListeners();
    });

    _socket?.on('booking:created', (_) => _handleRealtimeUpdateEvent());
    _socket?.on('booking:updated', (_) => _handleRealtimeUpdateEvent());
    _socket?.on('booking:deleted', (_) => _handleRealtimeUpdateEvent());
    _socket?.on('venue:created', (_) => _handleRealtimeUpdateEvent());
    _socket?.on('venue:updated', (_) => _handleRealtimeUpdateEvent());
    _socket?.on('calendar:updated', (_) => _handleRealtimeUpdateEvent());
  }

  String _availabilityKey(String venueId, DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$venueId-$year-$month-$day';
  }

  String _monthlyKey(String venueId, DateTime month) {
    final year = month.year.toString().padLeft(4, '0');
    final monthLabel = month.month.toString().padLeft(2, '0');
    return '$venueId-$year-$monthLabel';
  }

  void _invalidateAvailabilityForVenue(String venueId, DateTime date) {
    _availabilityCache.remove(_availabilityKey(venueId, date));
  }

  void _invalidateMonthlyAvailability(String venueId, DateTime date) {
    _monthlyAvailabilityCache.remove(
      _monthlyKey(venueId, DateTime(date.year, date.month)),
    );
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _socket?.dispose();
    super.dispose();
  }
}

class _ScoredVenue {
  const _ScoredVenue(this.venue, this.score);

  final Venue venue;
  final int score;
}
