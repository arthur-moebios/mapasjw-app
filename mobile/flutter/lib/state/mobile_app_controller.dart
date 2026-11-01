import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/mobile_api.dart';
import '../data/pending_route_store.dart';
import '../models/mobile_models.dart';
import '../services/route_tracking_service.dart';

final mobileApiProvider = Provider<MobileApi>((ref) => MobileApi());

final routeTrackingServiceProvider = Provider<RouteTrackingService>((ref) {
  final service = RouteTrackingService(api: ref.watch(mobileApiProvider));
  ref.onDispose(() => service.dispose());
  return service;
});

final mobileAppControllerProvider =
    AsyncNotifierProvider<MobileAppController, MobileAppState>(
      MobileAppController.new,
    );

class MobileAppState {
  const MobileAppState({
    this.isAuthenticated = false,
    this.isSigningIn = false,
    this.isLoadingTerritories = false,
    this.isLoadingMapPoints = false,
    this.isLoadingLetters = false,
    this.isLoadingStreetCards = false,
    this.isLoadingDashboard = false,
    this.isLoadingFieldCalendar = false,
    this.isLoadingFieldDesignations = false,
    this.isMapsConfigured = false,
    this.isLoadingMapsConfig = false,
    this.isLocating = false,
    this.isSuperAdmin = false,
    this.canViewTerritories = false,
    this.canViewLetters = false,
    this.canViewStreetCards = false,
    this.canManageTerritoryCards = false,
    this.canRecordRoutes = false,
    this.canViewFieldOutings = false,
    this.canManageFieldOutings = false,
    this.canManageFieldLocations = false,
    this.canUpdateLetterStatus = false,
    this.canManageTerritoryDesignations = false,
    this.canViewPeople = false,
    this.userId,
    this.userName = '',
    this.userEmail = '',
    this.selectedCongregationId,
    this.selectedTerritoryId,
    this.congregations = const [],
    this.territories = const [],
    this.mapPoints = const [],
    this.mapPointTypes = const [],
    this.canManageMapPoints = false,
    this.condominiums = const [],
    this.streetCards = const [],
    this.dashboardSummary,
    this.fieldCalendar,
    this.fieldDesignations,
    this.isStartingRoute = false,
    this.isTracking = false,
    this.isTestTracking = false,
    this.trackingTerritoryId,
    this.trackingStreetCardId,
    this.currentPosition,
    this.currentAccuracy,
    this.pendingRoutePoints = 0,
    this.errorMessage,
    this.mapPointsError,
    this.lettersError,
    this.streetCardsError,
    this.dashboardError,
    this.fieldCalendarError,
    this.fieldDesignationsError,
    this.mapsConfigError,
    this.trackingMessage,
  });

  final bool isAuthenticated;
  final bool isSigningIn;
  final bool isLoadingTerritories;
  final bool isLoadingMapPoints;
  final bool isLoadingLetters;
  final bool isLoadingStreetCards;
  final bool isLoadingDashboard;
  final bool isLoadingFieldCalendar;
  final bool isLoadingFieldDesignations;
  final bool isMapsConfigured;
  final bool isLoadingMapsConfig;
  final bool isLocating;
  final bool isSuperAdmin;
  final bool canViewTerritories;
  final bool canViewLetters;
  final bool canViewStreetCards;
  final bool canManageTerritoryCards;
  final bool canRecordRoutes;
  final bool canViewFieldOutings;
  final bool canManageFieldOutings;
  final bool canManageFieldLocations;
  final bool canUpdateLetterStatus;
  final bool canManageTerritoryDesignations;
  final bool canViewPeople;
  final int? userId;
  final String userName;
  final String userEmail;
  final int? selectedCongregationId;
  final int? selectedTerritoryId;
  final List<Congregation> congregations;
  final List<Territory> territories;
  final List<MapPoint> mapPoints;
  final List<MapPointType> mapPointTypes;
  final bool canManageMapPoints;
  final List<CondominiumSummary> condominiums;
  final List<StreetCardSummary> streetCards;
  final MobileDashboardSummary? dashboardSummary;
  final FieldCalendarData? fieldCalendar;
  final FieldDesignationsData? fieldDesignations;
  final bool isStartingRoute;
  final bool isTracking;
  final bool isTestTracking;
  final int? trackingTerritoryId;
  final int? trackingStreetCardId;
  final LatLng? currentPosition;
  final double? currentAccuracy;
  final int pendingRoutePoints;
  final String? errorMessage;
  final String? mapPointsError;
  final String? lettersError;
  final String? streetCardsError;
  final String? dashboardError;
  final String? fieldCalendarError;
  final String? fieldDesignationsError;
  final String? mapsConfigError;
  final String? trackingMessage;

  Territory? get selectedTerritory {
    for (final territory in territories) {
      if (territory.id == selectedTerritoryId) return territory;
    }
    return null;
  }

  Congregation? get selectedCongregation {
    for (final congregation in congregations) {
      if (congregation.id == selectedCongregationId) return congregation;
    }
    return null;
  }

  MobileAppState copyWith({
    bool? isAuthenticated,
    bool? isSigningIn,
    bool? isLoadingTerritories,
    bool? isLoadingMapPoints,
    bool? isLoadingLetters,
    bool? isLoadingStreetCards,
    bool? isLoadingDashboard,
    bool? isLoadingFieldCalendar,
    bool? isLoadingFieldDesignations,
    bool? isMapsConfigured,
    bool? isLoadingMapsConfig,
    bool? isLocating,
    bool? isSuperAdmin,
    bool? canViewTerritories,
    bool? canViewLetters,
    bool? canViewStreetCards,
    bool? canManageTerritoryCards,
    bool? canRecordRoutes,
    bool? canViewFieldOutings,
    bool? canManageFieldOutings,
    bool? canManageFieldLocations,
    bool? canUpdateLetterStatus,
    bool? canManageTerritoryDesignations,
    bool? canViewPeople,
    int? userId,
    String? userName,
    String? userEmail,
    int? selectedCongregationId,
    bool clearSelectedCongregation = false,
    int? selectedTerritoryId,
    bool clearSelectedTerritory = false,
    List<Congregation>? congregations,
    List<Territory>? territories,
    List<MapPoint>? mapPoints,
    List<MapPointType>? mapPointTypes,
    bool? canManageMapPoints,
    List<CondominiumSummary>? condominiums,
    List<StreetCardSummary>? streetCards,
    MobileDashboardSummary? dashboardSummary,
    bool clearDashboardSummary = false,
    FieldCalendarData? fieldCalendar,
    bool clearFieldCalendar = false,
    FieldDesignationsData? fieldDesignations,
    bool clearFieldDesignations = false,
    bool? isStartingRoute,
    bool? isTracking,
    bool? isTestTracking,
    int? trackingTerritoryId,
    bool clearTrackingTerritory = false,
    int? trackingStreetCardId,
    bool clearTrackingStreetCard = false,
    LatLng? currentPosition,
    bool clearCurrentPosition = false,
    double? currentAccuracy,
    int? pendingRoutePoints,
    String? errorMessage,
    String? mapPointsError,
    bool clearMapPointsError = false,
    bool clearError = false,
    String? lettersError,
    bool clearLettersError = false,
    String? streetCardsError,
    bool clearStreetCardsError = false,
    String? dashboardError,
    bool clearDashboardError = false,
    String? fieldCalendarError,
    bool clearFieldCalendarError = false,
    String? fieldDesignationsError,
    bool clearFieldDesignationsError = false,
    String? mapsConfigError,
    bool clearMapsConfigError = false,
    String? trackingMessage,
    bool clearTrackingMessage = false,
  }) {
    return MobileAppState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isSigningIn: isSigningIn ?? this.isSigningIn,
      isLoadingTerritories: isLoadingTerritories ?? this.isLoadingTerritories,
      isLoadingMapPoints: isLoadingMapPoints ?? this.isLoadingMapPoints,
      isLoadingLetters: isLoadingLetters ?? this.isLoadingLetters,
      isLoadingStreetCards: isLoadingStreetCards ?? this.isLoadingStreetCards,
      isLoadingDashboard: isLoadingDashboard ?? this.isLoadingDashboard,
      isLoadingFieldCalendar:
          isLoadingFieldCalendar ?? this.isLoadingFieldCalendar,
      isLoadingFieldDesignations:
          isLoadingFieldDesignations ?? this.isLoadingFieldDesignations,
      isMapsConfigured: isMapsConfigured ?? this.isMapsConfigured,
      isLoadingMapsConfig: isLoadingMapsConfig ?? this.isLoadingMapsConfig,
      isLocating: isLocating ?? this.isLocating,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      canViewTerritories: canViewTerritories ?? this.canViewTerritories,
      canViewLetters: canViewLetters ?? this.canViewLetters,
      canViewStreetCards: canViewStreetCards ?? this.canViewStreetCards,
      canManageTerritoryCards:
          canManageTerritoryCards ?? this.canManageTerritoryCards,
      canRecordRoutes: canRecordRoutes ?? this.canRecordRoutes,
      canViewFieldOutings: canViewFieldOutings ?? this.canViewFieldOutings,
      canManageFieldOutings:
          canManageFieldOutings ?? this.canManageFieldOutings,
      canManageFieldLocations:
          canManageFieldLocations ?? this.canManageFieldLocations,
      canUpdateLetterStatus:
          canUpdateLetterStatus ?? this.canUpdateLetterStatus,
      canManageTerritoryDesignations:
          canManageTerritoryDesignations ?? this.canManageTerritoryDesignations,
      canViewPeople: canViewPeople ?? this.canViewPeople,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      selectedCongregationId: clearSelectedCongregation
          ? null
          : selectedCongregationId ?? this.selectedCongregationId,
      selectedTerritoryId: clearSelectedTerritory
          ? null
          : selectedTerritoryId ?? this.selectedTerritoryId,
      congregations: congregations ?? this.congregations,
      territories: territories ?? this.territories,
      mapPoints: mapPoints ?? this.mapPoints,
      mapPointTypes: mapPointTypes ?? this.mapPointTypes,
      canManageMapPoints: canManageMapPoints ?? this.canManageMapPoints,
      condominiums: condominiums ?? this.condominiums,
      streetCards: streetCards ?? this.streetCards,
      dashboardSummary: clearDashboardSummary
          ? null
          : dashboardSummary ?? this.dashboardSummary,
      fieldCalendar: clearFieldCalendar
          ? null
          : fieldCalendar ?? this.fieldCalendar,
      fieldDesignations: clearFieldDesignations
          ? null
          : fieldDesignations ?? this.fieldDesignations,
      isStartingRoute: isStartingRoute ?? this.isStartingRoute,
      isTracking: isTracking ?? this.isTracking,
      isTestTracking: isTestTracking ?? this.isTestTracking,
      trackingTerritoryId: clearTrackingTerritory
          ? null
          : trackingTerritoryId ?? this.trackingTerritoryId,
      trackingStreetCardId: clearTrackingStreetCard
          ? null
          : trackingStreetCardId ?? this.trackingStreetCardId,
      currentPosition: clearCurrentPosition
          ? null
          : currentPosition ?? this.currentPosition,
      currentAccuracy: currentAccuracy ?? this.currentAccuracy,
      pendingRoutePoints: pendingRoutePoints ?? this.pendingRoutePoints,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      mapPointsError: clearMapPointsError
          ? null
          : mapPointsError ?? this.mapPointsError,
      lettersError: clearLettersError
          ? null
          : lettersError ?? this.lettersError,
      streetCardsError: clearStreetCardsError
          ? null
          : streetCardsError ?? this.streetCardsError,
      dashboardError: clearDashboardError
          ? null
          : dashboardError ?? this.dashboardError,
      fieldCalendarError: clearFieldCalendarError
          ? null
          : fieldCalendarError ?? this.fieldCalendarError,
      fieldDesignationsError: clearFieldDesignationsError
          ? null
          : fieldDesignationsError ?? this.fieldDesignationsError,
      mapsConfigError: clearMapsConfigError
          ? null
          : mapsConfigError ?? this.mapsConfigError,
      trackingMessage: clearTrackingMessage
          ? null
          : trackingMessage ?? this.trackingMessage,
    );
  }
}

class MobileAppController extends AsyncNotifier<MobileAppState> {
  static const MethodChannel _googleMapsChannel = MethodChannel(
    'br.com.mapasjw.cartas/google_maps',
  );
  static const _tokenKey = 'mapasjw_access_token';
  static const _expiresKey = 'mapasjw_access_expires_at';
  static const _verifierKey = 'mapasjw_pkce_verifier';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late MobileApi _api;
  late RouteTrackingService _tracking;
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _appLinksSubscription;
  StreamSubscription<RouteTrackingEvent>? _trackingSubscription;
  Uri? _pendingOAuthUri;
  String? _lastProcessedOAuthUri;
  String? _token;
  bool _routeStartInProgress = false;
  int? _territoriesLoadedForCongregation;
  int? _mapPointsLoadedForCongregation;
  int? _lettersLoadedForCongregation;
  int? _streetCardsLoadedForCongregation;
  int? _streetCardsGeometryLoadedForCongregation;
  int? _dashboardLoadedForCongregation;
  int? _fieldCalendarLoadedForCongregation;
  String? _fieldCalendarLoadedMonth;
  int _fieldCalendarRequestId = 0;
  int? _fieldDesignationsLoadedForCongregation;
  int? _fieldDesignationsLoadedYear;
  int? _mapsConfigLoadingForCongregation;

  @override
  Future<MobileAppState> build() async {
    _api = ref.watch(mobileApiProvider);
    _tracking = ref.watch(routeTrackingServiceProvider);
    _trackingSubscription ??= _tracking.events.listen(_applyTrackingEvent);
    ref.onDispose(() {
      unawaited(_appLinksSubscription?.cancel());
      unawaited(_trackingSubscription?.cancel());
    });

    _appLinks = AppLinks();
    _appLinksSubscription ??= _appLinks!.uriLinkStream.listen(_handleOAuthUri);

    final initialUri = await _appLinks!.getInitialLink();
    if (initialUri != null && _isOAuthCallback(initialUri)) {
      _lastProcessedOAuthUri = initialUri.toString();
      return _completeOAuthCallback(initialUri);
    }

    if (_pendingOAuthUri != null) {
      final pendingUri = _pendingOAuthUri!;
      _pendingOAuthUri = null;
      _lastProcessedOAuthUri = pendingUri.toString();
      return _completeOAuthCallback(pendingUri);
    }

    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return const MobileAppState();
    _token = token;

    try {
      final loadedState = await _loadBootstrap(token);
      unawaited(_tracking.requestCurrentStatus());
      if (_pendingOAuthUri != null) {
        final pendingUri = _pendingOAuthUri!;
        _pendingOAuthUri = null;
        scheduleMicrotask(() => _handleOAuthUri(pendingUri));
      }
      return loadedState;
    } on Object catch (error) {
      await _clearCredentials();
      return MobileAppState(errorMessage: MobileApi.messageForError(error));
    }
  }

  Future<void> signInWithGoogle() async {
    final current = state.asData?.value ?? const MobileAppState();
    state = AsyncData(current.copyWith(isSigningIn: true, clearError: true));

    final verifier = _createVerifier();
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    await _storage.write(key: _verifierKey, value: verifier);

    final apiUri = Uri.parse(MobileApi.baseUrl);
    final signInUri = Uri.https(apiUri.host, '/auth/google/redirect', {
      'mobile': '1',
      'mobile_challenge': challenge,
    });

    final opened = await launchUrl(
      signInUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      state = AsyncData(
        current.copyWith(
          isSigningIn: false,
          errorMessage: 'Não foi possível abrir o Google. Tente novamente.',
        ),
      );
    }
  }

  Future<void> _handleOAuthUri(Uri uri) async {
    if (!_isOAuthCallback(uri)) return;
    if (_lastProcessedOAuthUri == uri.toString()) return;
    if (state.asData == null) {
      _pendingOAuthUri = uri;
      return;
    }

    _lastProcessedOAuthUri = uri.toString();
    state = AsyncData(await _completeOAuthCallback(uri));
  }

  bool _isOAuthCallback(Uri uri) =>
      uri.scheme == 'br.com.mapasjw.cartas' &&
      uri.host == 'auth' &&
      uri.path == '/callback';

  Future<MobileAppState> _completeOAuthCallback(Uri uri) async {
    final current = state.asData?.value ?? const MobileAppState();
    final code = uri.queryParameters['code'];
    if (uri.queryParameters.containsKey('error')) {
      return current.copyWith(
        isSigningIn: false,
        errorMessage: 'O login foi cancelado. Você pode tentar novamente.',
      );
    }
    if (code == null || code.isEmpty) {
      return current.copyWith(
        isSigningIn: false,
        errorMessage: 'O Google não concluiu o login. Tente novamente.',
      );
    }

    try {
      final verifier = await _storage.read(key: _verifierKey);
      if (verifier == null) {
        throw StateError('O login expirou. Tente novamente.');
      }

      final tokenResult = await _api.exchangeMobileCode(
        code: code,
        verifier: verifier,
        deviceName: Platform.isIOS ? 'iPhone Mapas JW' : 'Android Mapas JW',
      );
      final token = tokenResult['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw StateError('Não foi possível iniciar a sessão.');
      }

      _token = token;
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(
        key: _expiresKey,
        value: tokenResult['expires_at'] as String?,
      );
      await _storage.delete(key: _verifierKey);
      return await _loadBootstrap(token);
    } on Object catch (error) {
      await _storage.delete(key: _verifierKey);
      return current.copyWith(
        isSigningIn: false,
        errorMessage: MobileApi.messageForError(error),
      );
    }
  }

  Future<MobileAppState> _loadBootstrap(String token) async {
    final bootstrap = await _api.bootstrap(token);
    final user = Map<String, dynamic>.from(
      bootstrap['user'] as Map? ?? const {},
    );
    final congregations = (bootstrap['congregations'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Congregation.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    final isSuperAdmin = bootstrap['is_superadmin'] == true;
    final selectedId = isSuperAdmin
        ? null
        : (bootstrap['selected_congregation_id'] as num?)?.toInt();

    var result = MobileAppState(
      isAuthenticated: true,
      userId: (user['id'] as num?)?.toInt(),
      userName: user['name'] as String? ?? '',
      userEmail: user['email'] as String? ?? '',
      isSuperAdmin: isSuperAdmin,
      canViewTerritories: bootstrap['can_view_territories'] == true,
      canViewLetters: bootstrap['can_view_letters'] == true,
      canViewStreetCards: bootstrap['can_view_street_cards'] == true,
      canManageTerritoryCards: bootstrap['can_manage_territory_cards'] == true,
      canRecordRoutes: bootstrap['can_record_routes'] == true,
      canViewFieldOutings: bootstrap['can_view_field_outings'] == true,
      canManageFieldOutings: bootstrap['can_manage_field_outings'] == true,
      canManageFieldLocations: bootstrap['can_manage_field_locations'] == true,
      canUpdateLetterStatus: bootstrap['can_update_letter_status'] == true,
      canManageTerritoryDesignations:
          bootstrap['can_manage_territory_designations'] == true,
      canViewPeople: bootstrap['can_view_people'] == true,
      isMapsConfigured: !Platform.isIOS,
      selectedCongregationId: selectedId,
      congregations: congregations,
    );

    if (selectedId != null && result.canViewTerritories) {
      result = await _loadTerritoriesForState(result, token, selectedId);
      result = await _loadMapPointsForState(result, token, selectedId);
    }
    if (selectedId != null &&
        (result.canViewTerritories || result.canViewLetters)) {
      result = await _loadDashboardForState(result, token, selectedId);
    }
    if (selectedId != null && result.canViewStreetCards) {
      result = await _loadStreetCardsForState(result, token, selectedId);
    }
    if (selectedId != null && result.canViewFieldOutings) {
      result = await _loadFieldCalendarForState(
        result,
        token,
        selectedId,
        _monthKey(DateTime.now()),
      );
    }
    return result;
  }

  Future<void> selectCongregation(int congregationId) async {
    final current = state.requireValue;
    if (current.isTracking || _routeStartInProgress) return;
    if (!current.congregations.any(
      (congregation) => congregation.id == congregationId,
    )) {
      return;
    }
    final token = _token;
    if (token == null) return;
    _territoriesLoadedForCongregation = null;
    _mapPointsLoadedForCongregation = null;
    _lettersLoadedForCongregation = null;
    _streetCardsLoadedForCongregation = null;
    _streetCardsGeometryLoadedForCongregation = null;
    _dashboardLoadedForCongregation = null;
    _fieldCalendarLoadedForCongregation = null;
    _fieldCalendarLoadedMonth = null;
    _fieldDesignationsLoadedForCongregation = null;
    _fieldDesignationsLoadedYear = null;
    state = AsyncData(
      current.copyWith(
        selectedCongregationId: congregationId,
        clearSelectedTerritory: true,
        territories: const [],
        mapPoints: const [],
        mapPointTypes: const [],
        canManageMapPoints: false,
        condominiums: const [],
        streetCards: const [],
        isLoadingDashboard: false,
        isMapsConfigured: !Platform.isIOS,
        isLoadingMapsConfig: false,
        clearDashboardSummary: true,
        clearFieldCalendar: true,
        clearFieldDesignations: true,
        isLoadingTerritories: current.canViewTerritories,
        isLoadingMapPoints: current.canViewTerritories,
        isLoadingFieldCalendar: current.canViewFieldOutings,
        isLoadingLetters: false,
        isLoadingStreetCards: false,
        clearLettersError: true,
        clearStreetCardsError: true,
        clearDashboardError: true,
        clearFieldCalendarError: true,
        clearFieldDesignationsError: true,
        clearMapsConfigError: true,
        clearMapPointsError: true,
        clearError: true,
      ),
    );

    await Future.wait([
      if (current.canViewTerritories) refreshTerritories(force: true),
      if (current.canViewTerritories) refreshMapPoints(force: true),
      if (current.canViewLetters) refreshCondominiums(force: true),
      if (current.canViewStreetCards) refreshStreetCards(force: true),
      if (current.canViewTerritories || current.canViewLetters)
        refreshDashboard(force: true),
      if (current.canViewFieldOutings)
        refreshFieldCalendar(month: _monthKey(DateTime.now()), force: true),
      if (Platform.isIOS &&
          (current.canViewTerritories || current.canViewStreetCards))
        ensureMapsConfigured(),
    ]);
  }

  Future<void> ensureMapsConfigured() async {
    final congregationId = state.asData?.value.selectedCongregationId;
    if (congregationId != null) {
      await ensureMapsConfiguredForCongregation(congregationId);
    }
  }

  Future<void> ensureMapsConfiguredForCongregation(int congregationId) async {
    if (!Platform.isIOS) return;

    final current = state.asData?.value;
    final token = _token;
    final canUseCongregation = current?.isSuperAdmin == true
        ? current!.congregations.any((item) => item.id == congregationId)
        : current?.selectedCongregationId == congregationId &&
              (current?.canViewTerritories == true ||
                  current?.canViewStreetCards == true);
    if (current == null ||
        token == null ||
        !canUseCongregation ||
        current.isMapsConfigured ||
        _mapsConfigLoadingForCongregation == congregationId) {
      return;
    }

    final selectedCongregationAtStart = current.selectedCongregationId;
    _mapsConfigLoadingForCongregation = congregationId;
    state = AsyncData(
      current.copyWith(isLoadingMapsConfig: true, clearMapsConfigError: true),
    );

    try {
      final apiKey = await _api.mapsApiKey(
        token: token,
        congregationId: congregationId,
      );
      if (apiKey == null) {
        throw StateError('Esta congregação ainda não tem o mapa configurado.');
      }

      final configured = await _googleMapsChannel.invokeMethod<bool>(
        'configureGoogleMaps',
        apiKey,
      );
      if (configured != true) {
        throw StateError('O iPhone não aceitou a configuração do mapa.');
      }

      if (state.asData?.value.selectedCongregationId !=
          selectedCongregationAtStart) {
        return;
      }
      state = AsyncData(
        state.requireValue.copyWith(
          isMapsConfigured: true,
          isLoadingMapsConfig: false,
          clearMapsConfigError: true,
        ),
      );
    } on PlatformException catch (error) {
      if (state.asData?.value.selectedCongregationId !=
          selectedCongregationAtStart) {
        return;
      }
      final message = error.code == 'maps_key_conflict'
          ? 'Esta congregação usa outra chave de mapas. Feche e abra o aplicativo para trocar.'
          : 'Não foi possível configurar o mapa neste iPhone.';
      state = AsyncData(
        state.requireValue.copyWith(
          isLoadingMapsConfig: false,
          mapsConfigError: message,
        ),
      );
    } on Object catch (error) {
      if (state.asData?.value.selectedCongregationId !=
          selectedCongregationAtStart) {
        return;
      }
      final message = error is StateError
          ? error.message.toString()
          : MobileApi.messageForError(error);
      state = AsyncData(
        state.requireValue.copyWith(
          isLoadingMapsConfig: false,
          mapsConfigError: message,
        ),
      );
    } finally {
      if (_mapsConfigLoadingForCongregation == congregationId) {
        _mapsConfigLoadingForCongregation = null;
      }
    }
  }

  Future<void> refreshDashboard({bool force = false}) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        (!current.canViewTerritories && !current.canViewLetters)) {
      return;
    }
    if (!force && _dashboardLoadedForCongregation == congregationId) return;
    if (current.isLoadingDashboard) return;

    state = AsyncData(
      current.copyWith(isLoadingDashboard: true, clearDashboardError: true),
    );
    try {
      final dashboard = await _api.dashboard(
        token: token,
        congregationId: congregationId,
      );
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      _dashboardLoadedForCongregation = congregationId;
      state = AsyncData(
        state.requireValue.copyWith(
          dashboardSummary: dashboard,
          isLoadingDashboard: false,
          clearDashboardError: true,
        ),
      );
    } on Object catch (error) {
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      state = AsyncData(
        state.requireValue.copyWith(
          isLoadingDashboard: false,
          dashboardError: MobileApi.messageForError(error),
        ),
      );
    }
  }

  Future<void> refreshFieldCalendar({
    required String month,
    bool force = false,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        !current.canViewFieldOutings) {
      return;
    }
    if (!force &&
        _fieldCalendarLoadedForCongregation == congregationId &&
        _fieldCalendarLoadedMonth == month) {
      return;
    }

    final requestId = ++_fieldCalendarRequestId;
    state = AsyncData(
      current.copyWith(
        isLoadingFieldCalendar: true,
        clearFieldCalendarError: true,
      ),
    );
    try {
      final calendar = await _api.fieldCalendar(
        token: token,
        congregationId: congregationId,
        month: month,
      );
      if (state.asData?.value.selectedCongregationId != congregationId ||
          requestId != _fieldCalendarRequestId) {
        return;
      }
      _fieldCalendarLoadedForCongregation = congregationId;
      _fieldCalendarLoadedMonth = month;
      state = AsyncData(
        state.requireValue.copyWith(
          fieldCalendar: calendar,
          isLoadingFieldCalendar: false,
          clearFieldCalendarError: true,
        ),
      );
    } on Object catch (error) {
      if (state.asData?.value.selectedCongregationId != congregationId ||
          requestId != _fieldCalendarRequestId) {
        return;
      }
      state = AsyncData(
        state.requireValue.copyWith(
          isLoadingFieldCalendar: false,
          fieldCalendarError: MobileApi.messageForError(error),
        ),
      );
    }
  }

  Future<List<FieldScheduleExportDay>> fieldScheduleExportDays({
    required String from,
    required String through,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        !current.canViewFieldOutings) {
      throw StateError('Entre e selecione uma congregação para exportar.');
    }

    return _api.fieldScheduleExportDays(
      token: token,
      congregationId: congregationId,
      from: from,
      through: through,
    );
  }

  Future<Uint8List> exportFieldSchedule({
    required String from,
    required String through,
    required List<String> days,
    required String title,
    required String format,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        !current.canViewFieldOutings) {
      throw StateError('Entre e selecione uma congregação para exportar.');
    }

    return _api.exportFieldSchedule(
      token: token,
      congregationId: congregationId,
      from: from,
      through: through,
      days: days,
      title: title,
      format: format,
    );
  }

  Future<void> refreshFieldDesignations({
    required int serviceYear,
    bool force = false,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        !current.canViewFieldOutings) {
      return;
    }
    if (!force &&
        _fieldDesignationsLoadedForCongregation == congregationId &&
        _fieldDesignationsLoadedYear == serviceYear) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        isLoadingFieldDesignations: true,
        clearFieldDesignationsError: true,
      ),
    );
    try {
      final designations = await _api.fieldDesignations(
        token: token,
        congregationId: congregationId,
        serviceYear: serviceYear,
      );
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      _fieldDesignationsLoadedForCongregation = congregationId;
      _fieldDesignationsLoadedYear = serviceYear;
      state = AsyncData(
        state.requireValue.copyWith(
          fieldDesignations: designations,
          isLoadingFieldDesignations: false,
          clearFieldDesignationsError: true,
        ),
      );
    } on Object catch (error) {
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      state = AsyncData(
        state.requireValue.copyWith(
          isLoadingFieldDesignations: false,
          fieldDesignationsError: MobileApi.messageForError(error),
        ),
      );
    }
  }

  Future<MobileDesignationsData> loadNativeDesignations() async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        !current.canManageTerritoryDesignations) {
      throw StateError(
        'Selecione uma congregação e confirme seu acesso às designações.',
      );
    }

    return _api.designations(token: token, congregationId: congregationId);
  }

  Future<CircuitOverviewData> loadCircuitOverview() async {
    final current = state.requireValue;
    final token = _token;
    if (!current.isSuperAdmin || token == null) {
      throw StateError(
        'A visão do circuito está disponível somente para superadministradores.',
      );
    }

    final overview = await _api.circuitOverview(token: token);
    if (Platform.isIOS &&
        !current.isMapsConfigured &&
        overview.congregations.isNotEmpty) {
      await ensureMapsConfiguredForCongregation(
        overview.congregations.first.id,
      );
    }

    return overview;
  }

  Future<List<MobilePerson>> loadNativePeople() async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null || congregationId == null || !current.canViewPeople) {
      throw StateError(
        'Selecione uma congregação e confirme seu acesso às pessoas.',
      );
    }

    return _api.people(token: token, congregationId: congregationId);
  }

  Future<void> saveFieldOuting(
    Map<String, Object?> data, {
    int? outingId,
  }) async {
    final (token, congregationId) = _fieldSession();
    await _api.saveFieldOuting(
      token: token,
      congregationId: congregationId,
      data: data,
      outingId: outingId,
    );
    await refreshFieldCalendar(
      month: _monthKey(
        DateTime.tryParse(data['date'] as String? ?? '') ?? DateTime.now(),
      ),
      force: true,
    );
  }

  Future<FieldLocation> createFieldLocation(
    Map<String, Object?> data, {
    required String month,
  }) async {
    final (token, congregationId) = _fieldSession();
    final location = await _api.createFieldLocation(
      token: token,
      congregationId: congregationId,
      data: data,
    );
    await refreshFieldCalendar(month: month, force: true);
    return location;
  }

  Future<void> deleteFieldOuting(int outingId, {required String month}) async {
    final (token, congregationId) = _fieldSession();
    await _api.deleteFieldOuting(
      token: token,
      congregationId: congregationId,
      outingId: outingId,
    );
    await refreshFieldCalendar(month: month, force: true);
  }

  Future<void> setFieldOutingSituation(
    int outingId,
    String situation, {
    required String month,
  }) async {
    final (token, congregationId) = _fieldSession();
    await _api.updateFieldOutingSituation(
      token: token,
      congregationId: congregationId,
      outingId: outingId,
      situation: situation,
    );
    await refreshFieldCalendar(month: month, force: true);
  }

  Future<Map<String, dynamic>> repeatPreviousFieldWeek(String date) async {
    final (token, congregationId) = _fieldSession();
    final result = await _api.repeatPreviousFieldWeek(
      token: token,
      congregationId: congregationId,
      date: date,
    );
    await refreshFieldCalendar(
      month: _monthKey(DateTime.parse(date)),
      force: true,
    );
    return result;
  }

  Future<void> saveFieldPattern(
    Map<String, Object?> data, {
    int? patternId,
    required String month,
  }) async {
    final (token, congregationId) = _fieldSession();
    await _api.saveFieldPattern(
      token: token,
      congregationId: congregationId,
      data: data,
      patternId: patternId,
    );
    await refreshFieldCalendar(month: month, force: true);
  }

  Future<void> deleteFieldPattern(
    int patternId, {
    required String month,
  }) async {
    final (token, congregationId) = _fieldSession();
    await _api.deleteFieldPattern(
      token: token,
      congregationId: congregationId,
      patternId: patternId,
    );
    await refreshFieldCalendar(month: month, force: true);
  }

  Future<Map<String, dynamic>> generateFieldOutings({
    required String from,
    required String through,
    required String month,
  }) async {
    final (token, congregationId) = _fieldSession();
    final result = await _api.generateFieldOutings(
      token: token,
      congregationId: congregationId,
      from: from,
      through: through,
    );
    await refreshFieldCalendar(month: month, force: true);
    return result;
  }

  (String, int) _fieldSession() {
    final token = _token;
    final congregationId = state.requireValue.selectedCongregationId;
    if (token == null || congregationId == null) {
      throw StateError('Escolha uma congregação e entre novamente.');
    }
    return (token, congregationId);
  }

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Future<void> refreshTerritories({bool force = false}) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        !current.canViewTerritories) {
      return;
    }
    if (!force && _territoriesLoadedForCongregation == congregationId) return;

    state = AsyncData(
      current.copyWith(isLoadingTerritories: true, clearError: true),
    );
    try {
      final territories = await _api.territories(
        token: token,
        congregationId: congregationId,
      );
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      _territoriesLoadedForCongregation = congregationId;
      state = AsyncData(
        state.requireValue.copyWith(
          territories: territories,
          isLoadingTerritories: false,
        ),
      );
    } on Object catch (error) {
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      state = AsyncData(
        state.requireValue.copyWith(
          isLoadingTerritories: false,
          errorMessage: MobileApi.messageForError(error),
        ),
      );
    }
  }

  Future<void> refreshMapPoints({bool force = false}) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        !current.canViewTerritories) {
      return;
    }
    if (!force && _mapPointsLoadedForCongregation == congregationId) return;

    state = AsyncData(
      current.copyWith(isLoadingMapPoints: true, clearMapPointsError: true),
    );
    try {
      final points = await _api.mapPoints(
        token: token,
        congregationId: congregationId,
      );
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      _mapPointsLoadedForCongregation = congregationId;
      state = AsyncData(
        state.requireValue.copyWith(
          mapPoints: points.points,
          mapPointTypes: points.types,
          canManageMapPoints: points.canManage,
          isLoadingMapPoints: false,
        ),
      );
    } on Object catch (error) {
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      state = AsyncData(
        state.requireValue.copyWith(
          isLoadingMapPoints: false,
          mapPointsError: MobileApi.messageForError(error),
        ),
      );
    }
  }

  /// Cria (pointId nulo) ou atualiza um ponto do mapa e recarrega a lista.
  /// Erros de validação do servidor chegam como [DioException].
  Future<void> saveMapPoint(Map<String, Object?> data, {int? pointId}) async {
    final (token, congregationId) = _fieldSession();
    await _api.saveMapPoint(
      token: token,
      congregationId: congregationId,
      pointId: pointId,
      data: data,
    );
    await refreshMapPoints(force: true);
  }

  Future<void> deleteMapPoint(int pointId) async {
    final (token, congregationId) = _fieldSession();
    await _api.deleteMapPoint(
      token: token,
      congregationId: congregationId,
      pointId: pointId,
    );
    await refreshMapPoints(force: true);
  }

  Future<void> refreshCondominiums({bool force = false}) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null || congregationId == null || !current.canViewLetters) {
      return;
    }
    if (!force && _lettersLoadedForCongregation == congregationId) return;
    if (current.isLoadingLetters) return;

    state = AsyncData(
      current.copyWith(isLoadingLetters: true, clearLettersError: true),
    );
    try {
      final condominiums = await _api.condominiums(
        token: token,
        congregationId: congregationId,
      );
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      _lettersLoadedForCongregation = congregationId;
      state = AsyncData(
        state.requireValue.copyWith(
          condominiums: condominiums,
          isLoadingLetters: false,
          clearLettersError: true,
        ),
      );
    } on Object catch (error) {
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      state = AsyncData(
        state.requireValue.copyWith(
          isLoadingLetters: false,
          lettersError: MobileApi.messageForError(error),
        ),
      );
    }
  }

  Future<void> refreshStreetCards({
    bool force = false,
    bool includeGeometry = false,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        !current.canViewStreetCards) {
      return;
    }
    if (!force &&
        _streetCardsLoadedForCongregation == congregationId &&
        (!includeGeometry ||
            _streetCardsGeometryLoadedForCongregation == congregationId)) {
      return;
    }
    if (current.isLoadingStreetCards) return;

    state = AsyncData(
      current.copyWith(isLoadingStreetCards: true, clearStreetCardsError: true),
    );
    try {
      final streetCards = await _api.streetCards(
        token: token,
        congregationId: congregationId,
        includeGeometry: includeGeometry,
      );
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      _streetCardsLoadedForCongregation = congregationId;
      _streetCardsGeometryLoadedForCongregation = includeGeometry
          ? congregationId
          : null;
      state = AsyncData(
        state.requireValue.copyWith(
          streetCards: streetCards,
          isLoadingStreetCards: false,
          clearStreetCardsError: true,
        ),
      );
    } on Object catch (error) {
      if (state.asData?.value.selectedCongregationId != congregationId) return;
      state = AsyncData(
        state.requireValue.copyWith(
          isLoadingStreetCards: false,
          streetCardsError: MobileApi.messageForError(error),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> importTerritoryMap({
    required bool simulate,
    List<int>? fileBytes,
    String? fileName,
    String? mapsUrl,
    List<String>? territoryCodes,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;

    if (!current.canManageTerritoryCards) {
      throw StateError('Sua conta não pode importar mapas de território.');
    }
    if (token == null || congregationId == null) {
      throw StateError('Selecione uma congregação antes de importar o mapa.');
    }
    if (fileBytes != null && (fileName == null || fileName.trim().isEmpty)) {
      throw StateError(
        'Não consegui identificar o nome do arquivo selecionado.',
      );
    }
    if ((fileBytes == null) == (mapsUrl?.trim().isEmpty ?? true)) {
      throw StateError(
        'Escolha um arquivo ou informe um link do Google My Maps.',
      );
    }

    return _api.importTerritoryMap(
      token: token,
      congregationId: congregationId,
      simulate: simulate,
      fileBytes: fileBytes,
      fileName: fileName,
      mapsUrl: mapsUrl,
      territoryCodes: territoryCodes,
    );
  }

  Future<CondominiumDetail> loadCondominium(
    int condominiumId, {
    int? campaignId,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null || congregationId == null || !current.canViewLetters) {
      throw StateError('Selecione uma congregação com acesso a Cartas.');
    }
    return _api.condominium(
      token: token,
      congregationId: congregationId,
      condominiumId: condominiumId,
      campaignId: campaignId,
    );
  }

  Future<String?> updateApartmentStatus({
    required int condominiumId,
    required int campaignId,
    required ApartmentLetter apartment,
    required Map<String, Object?> payload,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null || congregationId == null) {
      return 'Selecione uma congregação antes de salvar.';
    }
    try {
      await _api.updateApartmentStatus(
        token: token,
        congregationId: congregationId,
        condominiumId: condominiumId,
        campaignId: campaignId,
        apartmentId: apartment.id,
        apartmentNumber: apartment.apartmentNumberValue,
        payload: payload,
      );
      return null;
    } on Object catch (error) {
      return MobileApi.messageForError(error);
    }
  }

  Future<List<ApartmentDeliveryHistoryEntry>> loadApartmentHistory({
    required int condominiumId,
    required int campaignId,
    required int apartmentId,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null || congregationId == null || !current.canViewLetters) {
      throw StateError('Selecione uma congregação com acesso a Cartas.');
    }

    return _api.apartmentHistory(
      token: token,
      congregationId: congregationId,
      condominiumId: condominiumId,
      campaignId: campaignId,
      apartmentId: apartmentId,
    );
  }

  Future<TerritoryDetails> loadTerritoryDetails(int territoryId) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null || congregationId == null) {
      throw StateError('Selecione uma congregação para abrir o cartão.');
    }
    return _api.territoryDetails(
      token: token,
      congregationId: congregationId,
      territoryId: territoryId,
    );
  }

  Future<CardSuggestions> loadOutingCardSuggestions(int outingId) async {
    final (token, congregationId) = _fieldSession();
    return _api.outingCardSuggestions(
      token: token,
      congregationId: congregationId,
      outingId: outingId,
    );
  }

  Future<CardSuggestions> loadDraftCardSuggestions({
    required String date,
    String leader = '',
    List<int> groupIds = const [],
  }) async {
    final (token, congregationId) = _fieldSession();
    return _api.draftCardSuggestions(
      token: token,
      congregationId: congregationId,
      date: date,
      leader: leader,
      groupIds: groupIds,
    );
  }

  Future<StreetCardDetail> loadStreetCard(int streetCardId) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        !current.canViewStreetCards) {
      throw StateError('Selecione uma congregação para abrir cartões de rua.');
    }
    return _api.streetCard(
      token: token,
      congregationId: congregationId,
      streetCardId: streetCardId,
    );
  }

  Future<List<StreetRecordedRoute>> loadStreetCardRoutes({
    required int streetCardId,
    String? routeDate,
    int? routeUserId,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    if (token == null ||
        congregationId == null ||
        !current.canViewStreetCards) {
      throw StateError('Selecione uma congregação para consultar percursos.');
    }
    return _api.streetCardRoutes(
      token: token,
      congregationId: congregationId,
      streetCardId: streetCardId,
      routeDate: routeDate,
      routeUserId: routeUserId,
    );
  }

  Future<String?> locateCurrentPosition() async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isLocating: true, clearError: true));
    try {
      final position = await _tracking.getCurrentPosition();
      state = AsyncData(
        state.requireValue.copyWith(
          isLocating: false,
          currentPosition: LatLng(position.latitude, position.longitude),
          currentAccuracy: position.accuracy,
        ),
      );
      return null;
    } on Object catch (error) {
      final message = error is StateError
          ? error.message.toString()
          : MobileApi.messageForError(error);
      state = AsyncData(state.requireValue.copyWith(isLocating: false));
      return message;
    }
  }

  void selectTerritory(int? territoryId) {
    final current = state.requireValue;
    if (_routeStartInProgress ||
        (current.isTracking && territoryId != current.trackingTerritoryId)) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        selectedTerritoryId: territoryId,
        clearSelectedTerritory: territoryId == null,
        clearError: true,
      ),
    );
  }

  Future<String?> startAutomaticRoute() async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    final userId = current.userId;

    if (!current.canRecordRoutes) {
      return 'Sua conta não tem permissão para registrar trajetos.';
    }
    if (token == null || congregationId == null || userId == null) {
      return current.isSuperAdmin
          ? 'Selecione uma congregação antes de registrar o trajeto.'
          : 'Entre novamente antes de registrar o trajeto.';
    }
    if (current.isTracking || _routeStartInProgress) {
      return 'Já existe um trajeto em registro ou preparação.';
    }

    _routeStartInProgress = true;
    state = AsyncData(
      current.copyWith(isStartingRoute: true, clearError: true),
    );

    try {
      final permissionMessage = await _tracking.requestPermissions();
      if (permissionMessage != null) return permissionMessage;

      final latestState = state.requireValue;
      if (!latestState.isAuthenticated ||
          latestState.userId != userId ||
          latestState.selectedCongregationId != congregationId) {
        return 'A congregação selecionada mudou. Confira e tente novamente.';
      }

      await _tracking.start(
        token: token,
        userId: userId,
        congregationId: congregationId,
        automaticMatching: true,
      );
      state = AsyncData(
        state.requireValue.copyWith(
          isStartingRoute: false,
          isTracking: true,
          isTestTracking: false,
          clearTrackingTerritory: true,
          clearTrackingStreetCard: true,
          trackingMessage: 'Trajeto em registro. Os cartões serão reconhecidos automaticamente.',
          pendingRoutePoints: 0,
          clearError: true,
        ),
      );

      return null;
    } on Object catch (error) {
      return MobileApi.messageForError(error);
    } finally {
      _routeStartInProgress = false;
      final latestState = state.asData?.value;
      if (latestState?.isStartingRoute == true) {
        state = AsyncData(latestState!.copyWith(isStartingRoute: false));
      }
    }
  }

  Future<String?> startStreetCardRoute(
    int streetCardId, {
    bool testMode = false,
  }) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    final userId = current.userId;

    if (token == null || congregationId == null || userId == null) {
      return 'Entre novamente e selecione uma congregação antes de registrar o percurso.';
    }
    if (current.isTracking || _routeStartInProgress) {
      return 'Já existe um percurso em registro ou preparação.';
    }

    _routeStartInProgress = true;
    state = AsyncData(
      current.copyWith(isStartingRoute: true, clearError: true),
    );
    try {
      final detail = await _api.streetCard(
        token: token,
        congregationId: congregationId,
        streetCardId: streetCardId,
      );
      var latestState = state.requireValue;
      if (!latestState.isAuthenticated ||
          latestState.userId != userId ||
          latestState.selectedCongregationId != congregationId) {
        return 'A congregação selecionada mudou. Confira e tente novamente.';
      }
      if (detail.originTerritoryId == null) {
        return detail.routeMessage.isNotEmpty
            ? detail.routeMessage
            : 'Este cartão de rua não está associado a um território válido.';
      }
      if (testMode && !detail.canTestRoute) {
        return 'Somente administradores podem registrar percursos de teste.';
      }
      if (!testMode && !detail.canRecordRoute) return detail.routeMessage;

      final permissionMessage = await _tracking.requestPermissions();
      if (permissionMessage != null) return permissionMessage;

      latestState = state.requireValue;
      if (!latestState.isAuthenticated ||
          latestState.userId != userId ||
          latestState.selectedCongregationId != congregationId) {
        return 'A congregação selecionada mudou. Confira e tente novamente.';
      }

      await _tracking.start(
        token: token,
        userId: userId,
        congregationId: congregationId,
        territoryId: detail.originTerritoryId!,
        streetCardId: detail.summary.id,
        testMode: testMode,
      );
      state = AsyncData(
        state.requireValue.copyWith(
          isStartingRoute: false,
          isTracking: true,
          isTestTracking: testMode,
          trackingTerritoryId: detail.originTerritoryId,
          trackingStreetCardId: detail.summary.id,
          trackingMessage: testMode
              ? 'Percurso de teste em registro neste cartão de rua.'
              : 'Percurso em registro neste cartão de rua.',
          clearError: true,
        ),
      );
      return null;
    } on Object catch (error) {
      return MobileApi.messageForError(error);
    } finally {
      _routeStartInProgress = false;
      final latestState = state.asData?.value;
      if (latestState?.isStartingRoute == true) {
        state = AsyncData(latestState!.copyWith(isStartingRoute: false));
      }
    }
  }

  Future<void> stopRoute() async {
    await _tracking.stop();
  }

  Future<String?> clearStreetCardTestRoutePoints(int streetCardId) async {
    final current = state.requireValue;
    final token = _token;
    final congregationId = current.selectedCongregationId;
    final userId = current.userId;

    if (token == null || congregationId == null || userId == null) {
      return 'Entre novamente para limpar os percursos de teste.';
    }
    if (current.isTracking && current.trackingStreetCardId == streetCardId) {
      return 'Encerre o percurso de teste antes de limpar os pontos.';
    }

    try {
      final deletedOnServer = await _api.clearStreetCardTestRoutePoints(
        token: token,
        congregationId: congregationId,
        streetCardId: streetCardId,
      );
      final deletedLocally = await PendingRouteStore.instance.clearTestPoints(
        userId: userId,
        congregationId: congregationId,
        territoryId: null,
        streetCardId: streetCardId,
      );

      return 'Limpos ${deletedOnServer + deletedLocally} ponto(s) de teste.';
    } on Object catch (error) {
      return MobileApi.messageForError(error);
    }
  }

  Future<void> signOut() async {
    if (_routeStartInProgress) return;
    await _tracking.stop(flushPending: false);
    final token = _token;
    if (token != null) {
      try {
        await _api.revokeSession(token);
      } on Object {
        // A sessão local é removida mesmo quando a conexão estiver indisponível.
      }
    }
    await PendingRouteStore.instance.clearAll();
    await _clearCredentials();
    state = const AsyncData(MobileAppState());
  }

  Future<MobileAppState> _loadTerritoriesForState(
    MobileAppState current,
    String token,
    int congregationId,
  ) async {
    try {
      final territories = await _api.territories(
        token: token,
        congregationId: congregationId,
      );
      _territoriesLoadedForCongregation = congregationId;
      return current.copyWith(territories: territories);
    } on Object catch (error) {
      return current.copyWith(errorMessage: MobileApi.messageForError(error));
    }
  }

  Future<MobileAppState> _loadMapPointsForState(
    MobileAppState current,
    String token,
    int congregationId,
  ) async {
    try {
      final points = await _api.mapPoints(
        token: token,
        congregationId: congregationId,
      );
      _mapPointsLoadedForCongregation = congregationId;
      return current.copyWith(
        mapPoints: points.points,
        mapPointTypes: points.types,
        canManageMapPoints: points.canManage,
      );
    } on Object catch (error) {
      return current.copyWith(mapPointsError: MobileApi.messageForError(error));
    }
  }

  Future<MobileAppState> _loadDashboardForState(
    MobileAppState current,
    String token,
    int congregationId,
  ) async {
    try {
      final dashboard = await _api.dashboard(
        token: token,
        congregationId: congregationId,
      );
      _dashboardLoadedForCongregation = congregationId;
      return current.copyWith(dashboardSummary: dashboard);
    } on Object catch (error) {
      return current.copyWith(dashboardError: MobileApi.messageForError(error));
    }
  }

  Future<MobileAppState> _loadFieldCalendarForState(
    MobileAppState current,
    String token,
    int congregationId,
    String month,
  ) async {
    try {
      final calendar = await _api.fieldCalendar(
        token: token,
        congregationId: congregationId,
        month: month,
      );
      _fieldCalendarLoadedForCongregation = congregationId;
      _fieldCalendarLoadedMonth = month;
      return current.copyWith(fieldCalendar: calendar);
    } on Object catch (error) {
      return current.copyWith(
        fieldCalendarError: MobileApi.messageForError(error),
      );
    }
  }

  Future<MobileAppState> _loadStreetCardsForState(
    MobileAppState current,
    String token,
    int congregationId,
  ) async {
    try {
      final streetCards = await _api.streetCards(
        token: token,
        congregationId: congregationId,
      );
      _streetCardsLoadedForCongregation = congregationId;
      return current.copyWith(streetCards: streetCards);
    } on Object catch (error) {
      return current.copyWith(
        streetCardsError: MobileApi.messageForError(error),
      );
    }
  }

  Future<void> _clearCredentials() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresKey);
    await _storage.delete(key: _verifierKey);
  }

  void _applyTrackingEvent(RouteTrackingEvent event) {
    final current = state.asData?.value;
    if (current == null) return;
    final isProblem =
        event.message != null &&
        !const {
          'Trajeto em registro.',
          'Trajeto em registro. Os cartões serão reconhecidos automaticamente.',
          'Trajeto de teste em registro.',
          'Trajeto encerrado.',
          'Nenhum trajeto ativo.',
        }.contains(event.message);
    state = AsyncData(
      current.copyWith(
        isTracking: event.active ?? current.isTracking,
        isTestTracking: event.active == false
            ? false
            : event.isTest ?? current.isTestTracking,
        trackingTerritoryId: event.territoryId,
        clearTrackingTerritory: event.active == false,
        trackingStreetCardId: event.streetCardId,
        clearTrackingStreetCard:
            event.active == false ||
            (event.active == true && event.streetCardId == null),
        currentPosition: event.latitude != null && event.longitude != null
            ? LatLng(event.latitude!, event.longitude!)
            : null,
        currentAccuracy: event.accuracy,
        pendingRoutePoints: event.pendingCount,
        trackingMessage: event.message,
        clearTrackingMessage: event.active == false && !isProblem,
        errorMessage: isProblem ? event.message : null,
        clearError: !isProblem,
      ),
    );
  }

  static String _createVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
