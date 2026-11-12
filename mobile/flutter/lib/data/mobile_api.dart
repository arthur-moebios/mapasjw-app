import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/follow_up.dart';
import '../models/mobile_models.dart';
import '../models/outing_work.dart';
import '../models/publication_citation.dart';

class MobileApi {
  MobileApi({Dio? dio}) : _dio = dio ?? Dio(_options);

  static const String baseUrl = String.fromEnvironment(
    'MAPASJW_API_BASE_URL',
    defaultValue: 'https://mapasjw.com.br/api',
  );

  static final BaseOptions _options = BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: const {'Accept': 'application/json'},
  );

  final Dio _dio;

  Future<Map<String, dynamic>> exchangeMobileCode({
    required String code,
    required String verifier,
    required String deviceName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mobile/auth/token',
      data: {'code': code, 'verifier': verifier, 'device_name': deviceName},
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> bootstrap(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/bootstrap',
      options: _authenticated(token),
    );
    return response.data ?? const {};
  }

  Future<CircuitOverviewData> circuitOverview({required String token}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/circuit-overview',
      options: _authenticated(token),
    );
    return CircuitOverviewData.fromJson(response.data ?? const {});
  }

  Future<MobileDashboardSummary> dashboard({
    required String token,
    required int congregationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/dashboard',
      options: _authenticated(token, congregationId),
    );
    return MobileDashboardSummary.fromJson(response.data ?? const {});
  }

  Future<FieldCalendarData> fieldCalendar({
    required String token,
    required int congregationId,
    required String month,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/field-outings',
      queryParameters: {'month': month},
      options: _authenticated(token, congregationId),
    );
    return FieldCalendarData.fromJson(response.data ?? const {});
  }

  Future<List<FieldScheduleExportDay>> fieldScheduleExportDays({
    required String token,
    required int congregationId,
    required String from,
    required String through,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/field-outings/export-options',
      queryParameters: {'from': from, 'through': through},
      options: _authenticated(token, congregationId),
    );
    return (response.data?['days'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (day) =>
              FieldScheduleExportDay.fromJson(Map<String, dynamic>.from(day)),
        )
        .toList(growable: false);
  }

  /// Folha A4 de QR (PDF) gerada pelo servidor.
  Future<Uint8List> publicationQrPdf({
    required String token,
    required int congregationId,
    required Map<String, Object?> body,
  }) async {
    final response = await _dio.post<List<int>>(
      '/mobile/publications/qr',
      data: body,
      options: _authenticated(
        token,
        congregationId,
      ).copyWith(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('O servidor retornou um arquivo vazio.');
    }
    const signature = [0x25, 0x50, 0x44, 0x46, 0x2D];
    final isPdf =
        bytes.length >= signature.length &&
        List<int>.generate(
          signature.length,
          (index) => index,
        ).every((index) => bytes[index] == signature[index]);
    if (!isPdf) {
      throw StateError(
        'O servidor não retornou um PDF válido. Confira a conexão e tente novamente.',
      );
    }
    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> exportFieldSchedule({
    required String token,
    required int congregationId,
    required String from,
    required String through,
    required List<String> days,
    required String title,
    required String format,
  }) async {
    final response = await _dio.post<List<int>>(
      '/mobile/field-outings/export',
      data: {
        'from': from,
        'through': through,
        'days': days,
        'title': title,
        'format': format,
      },
      options: _authenticated(
        token,
        congregationId,
      ).copyWith(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('O servidor retornou um arquivo vazio.');
    }

    final signature = switch (format) {
      'image' => const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      'pdf' => const [0x25, 0x50, 0x44, 0x46, 0x2D],
      _ => null,
    };
    final hasExpectedSignature =
        signature != null &&
        bytes.length >= signature.length &&
        List<int>.generate(
          signature.length,
          (index) => index,
        ).every((index) => bytes[index] == signature[index]);
    if (!hasExpectedSignature) {
      throw StateError(
        format == 'image'
            ? 'O servidor não retornou uma imagem válida. Confira a conexão e tente novamente.'
            : 'O servidor não retornou um PDF válido. Confira a conexão e tente novamente.',
      );
    }

    return Uint8List.fromList(bytes);
  }

  Future<FieldDesignationsData> fieldDesignations({
    required String token,
    required int congregationId,
    required int serviceYear,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/field-designations',
      queryParameters: {'service_year': serviceYear},
      options: _authenticated(token, congregationId),
    );
    return FieldDesignationsData.fromJson(response.data ?? const {});
  }

  Future<MobileDesignationsData> designations({
    required String token,
    required int congregationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/designations',
      options: _authenticated(token, congregationId),
    );
    return MobileDesignationsData.fromJson(response.data ?? const {});
  }

  Future<List<MobilePerson>> people({
    required String token,
    required int congregationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/people',
      options: _authenticated(token, congregationId),
    );
    return (response.data?['people'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => MobilePerson.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> saveFieldOuting({
    required String token,
    required int congregationId,
    required Map<String, Object?> data,
    int? outingId,
  }) async {
    final path = outingId == null
        ? '/mobile/field-outings'
        : '/mobile/field-outings/$outingId';
    final options = _authenticated(token, congregationId);
    if (outingId == null) {
      await _dio.post<void>(path, data: data, options: options);
    } else {
      await _dio.patch<void>(path, data: data, options: options);
    }
  }

  Future<FieldLocation> createFieldLocation({
    required String token,
    required int congregationId,
    required Map<String, Object?> data,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mobile/field-locations',
      data: data,
      options: _authenticated(token, congregationId),
    );
    return FieldLocation.fromJson(
      Map<String, dynamic>.from(response.data?['location'] as Map? ?? const {}),
    );
  }

  Future<FieldLocation> updateFieldLocation({
    required String token,
    required int congregationId,
    required int locationId,
    required Map<String, Object?> data,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/mobile/field-locations/$locationId',
      data: data,
      options: _authenticated(token, congregationId),
    );
    return FieldLocation.fromJson(
      Map<String, dynamic>.from(response.data?['location'] as Map? ?? const {}),
    );
  }

  /// Cartões de rua perto do local da saída, com ruas e linhas para o mapa.
  Future<OutingWorkData> outingWorkCandidates({
    required String token,
    required int congregationId,
    required int outingId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/field-outings/$outingId/work-candidates',
      options: _authenticated(token, congregationId),
    );
    return OutingWorkData.fromJson(response.data ?? const {});
  }

  /// Salva o registro por ruas (todas as ruas de um cartão conclui o cartão).
  Future<OutingWorkResult> saveOutingWork({
    required String token,
    required int congregationId,
    required int outingId,
    required Map<String, Object?> data,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mobile/field-outings/$outingId/work-streets',
      data: data,
      options: _authenticated(token, congregationId),
    );
    return OutingWorkResult.fromJson(response.data ?? const {});
  }

  /// Cobertura do território no ano de serviço (padrão: o atual).
  Future<CoverageData> coverage({
    required String token,
    required int congregationId,
    int? year,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/coverage',
      queryParameters: {'year': ?year},
      options: _authenticated(token, congregationId),
    );
    return CoverageData.fromJson(response.data ?? const {});
  }

  /// Cartões ainda não concluídos no ano de serviço atual.
  Future<List<OpenCard>> openCards({
    required String token,
    required int congregationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/open-cards',
      options: _authenticated(token, congregationId),
    );
    return (response.data?['cards'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => OpenCard.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  /// Um cartão no contrato de "Onde foi trabalhado?" (ruas, linhas e ruas já feitas).
  Future<OutingWorkData> cardWorkCandidates({
    required String token,
    required int congregationId,
    required int cardId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/street-cards/$cardId/work-candidates',
      options: _authenticated(token, congregationId),
    );
    return OutingWorkData.fromJson(response.data ?? const {});
  }

  /// Registro rápido de trabalho no cartão (todas as ruas marcadas o concluem).
  Future<OutingWorkResult> saveCardWork({
    required String token,
    required int congregationId,
    required int cardId,
    required Map<String, Object?> data,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mobile/street-cards/$cardId/work-streets',
      data: data,
      options: _authenticated(token, congregationId),
    );
    return OutingWorkResult.fromJson(response.data ?? const {});
  }

  /// Folha do S-13-T no ano de serviço (padrão: o atual).
  Future<S13Sheet> s13({
    required String token,
    required int congregationId,
    int? year,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/s13',
      queryParameters: {'year': ?year},
      options: _authenticated(token, congregationId),
    );
    return S13Sheet.fromJson(response.data ?? const {});
  }

  Future<LeadersAvailabilityData> leadersAvailability({
    required String token,
    required int congregationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/leaders/availability',
      options: _authenticated(token, congregationId),
    );
    return LeadersAvailabilityData.fromJson(response.data ?? const {});
  }

  /// Substitui os dias/períodos ("6:manha") em que o dirigente pode dirigir.
  Future<void> saveLeaderAvailability({
    required String token,
    required int congregationId,
    required int leaderId,
    required List<String> slots,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/mobile/leaders/$leaderId/availability',
      data: {'slots': slots},
      options: _authenticated(token, congregationId),
    );
  }

  Future<void> deleteFieldOuting({
    required String token,
    required int congregationId,
    required int outingId,
  }) async {
    await _dio.delete<void>(
      '/mobile/field-outings/$outingId',
      options: _authenticated(token, congregationId),
    );
  }

  Future<void> updateFieldOutingSituation({
    required String token,
    required int congregationId,
    required int outingId,
    required String situation,
  }) async {
    await _dio.patch<void>(
      '/mobile/field-outings/$outingId/situation',
      data: {'situation': situation},
      options: _authenticated(token, congregationId),
    );
  }

  Future<Map<String, dynamic>> repeatPreviousFieldWeek({
    required String token,
    required int congregationId,
    required String date,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mobile/field-outings/repeat-previous-week',
      data: {'date': date},
      options: _authenticated(token, congregationId),
    );
    return response.data ?? const {};
  }

  Future<void> saveFieldPattern({
    required String token,
    required int congregationId,
    required Map<String, Object?> data,
    int? patternId,
  }) async {
    final path = patternId == null
        ? '/mobile/field-outing-patterns'
        : '/mobile/field-outing-patterns/$patternId';
    final options = _authenticated(token, congregationId);
    if (patternId == null) {
      await _dio.post<void>(path, data: data, options: options);
    } else {
      await _dio.patch<void>(path, data: data, options: options);
    }
  }

  Future<void> deleteFieldPattern({
    required String token,
    required int congregationId,
    required int patternId,
  }) async {
    await _dio.delete<void>(
      '/mobile/field-outing-patterns/$patternId',
      options: _authenticated(token, congregationId),
    );
  }

  Future<Map<String, dynamic>> generateFieldOutings({
    required String token,
    required int congregationId,
    required String from,
    required String through,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mobile/field-outings/generate',
      data: {'from': from, 'through': through},
      options: _authenticated(token, congregationId),
    );
    return response.data ?? const {};
  }

  Future<String?> mapsApiKey({
    required String token,
    required int congregationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/maps/config',
      options: _authenticated(token, congregationId),
    );
    final apiKey = response.data?['google_maps_api_key'];
    if (response.data?['configured'] != true || apiKey is! String) {
      return null;
    }

    final normalizedApiKey = apiKey.trim();
    return normalizedApiKey.isEmpty ? null : normalizedApiKey;
  }

  Future<List<Territory>> territories({
    required String token,
    required int congregationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/territories',
      options: _authenticated(token, congregationId),
    );
    final items = response.data?['territories'] as List? ?? const [];
    return items
        .whereType<Map>()
        .map((item) => Territory.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<TerritoryDetails> territoryDetails({
    required String token,
    required int congregationId,
    required int territoryId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/territories/$territoryId',
      options: _authenticated(token, congregationId),
    );
    return TerritoryDetails.fromJson(response.data ?? const {});
  }

  Future<CardSuggestions> outingCardSuggestions({
    required String token,
    required int congregationId,
    required int outingId,
    int limit = 30,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/field-outings/$outingId/suggestions',
      queryParameters: {'limit': limit},
      options: _authenticated(token, congregationId),
    );
    return CardSuggestions.fromJson(response.data ?? const {});
  }

  Future<CardSuggestions> draftCardSuggestions({
    required String token,
    required int congregationId,
    required String date,
    String leader = '',
    List<int> groupIds = const [],
    int limit = 30,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/field-outings/suggestions',
      queryParameters: {
        'date': date,
        if (leader.trim().isNotEmpty) 'leader': leader.trim(),
        if (groupIds.isNotEmpty) 'group_ids[]': groupIds,
        'limit': limit,
      },
      options: _authenticated(token, congregationId),
    );
    return CardSuggestions.fromJson(response.data ?? const {});
  }

  Future<MapPointsData> mapPoints({
    required String token,
    required int congregationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/map-points',
      options: _authenticated(token, congregationId),
    );
    final items = response.data?['points'] as List? ?? const [];
    final types = response.data?['types'] as List? ?? const [];
    return MapPointsData(
      points: items
          .whereType<Map>()
          .map((item) => MapPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      types: types
          .whereType<Map>()
          .map((item) => MapPointType.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      canManage: response.data?['can_manage'] == true,
    );
  }

  Future<MapPoint> saveMapPoint({
    required String token,
    required int congregationId,
    int? pointId,
    required Map<String, Object?> data,
  }) async {
    final options = _authenticated(token, congregationId);
    final response = pointId == null
        ? await _dio.post<Map<String, dynamic>>(
            '/mobile/map-points',
            data: data,
            options: options,
          )
        : await _dio.patch<Map<String, dynamic>>(
            '/mobile/map-points/$pointId',
            data: data,
            options: options,
          );
    return MapPoint.fromJson(
      Map<String, dynamic>.from(response.data?['point'] as Map? ?? const {}),
    );
  }

  Future<void> deleteMapPoint({
    required String token,
    required int congregationId,
    required int pointId,
  }) async {
    await _dio.delete<void>(
      '/mobile/map-points/$pointId',
      options: _authenticated(token, congregationId),
    );
  }

  Future<List<CondominiumSummary>> condominiums({
    required String token,
    required int congregationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/letters/condominiums',
      options: _authenticated(token, congregationId),
    );
    final items = response.data?['condominiums'] as List? ?? const [];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              CondominiumSummary.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<CondominiumDetail> condominium({
    required String token,
    required int congregationId,
    required int condominiumId,
    int? campaignId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/letters/condominiums/$condominiumId',
      queryParameters: campaignId == null ? null : {'campaign_id': campaignId},
      options: _authenticated(token, congregationId),
    );
    return CondominiumDetail.fromJson(response.data ?? const {});
  }

  /// Catálogo v2 de publicações. Servidor antigo (404) lança: quem chama cai
  /// no catálogo antigo do detalhe do condomínio.
  Future<PublicationCatalog> publicationCatalog({
    required String token,
    required int congregationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/letters/publications',
      options: _authenticated(token, congregationId),
    );
    return PublicationCatalog.fromJson(response.data ?? const {});
  }

  Future<void> updateApartmentStatus({
    required String token,
    required int congregationId,
    required int condominiumId,
    required int campaignId,
    required int apartmentId,
    required String apartmentNumber,
    required Map<String, Object?> payload,
  }) async {
    await _dio.patch<void>(
      '/mobile/letters/condominiums/$condominiumId/campaigns/$campaignId/apartments/$apartmentId/status',
      data: {...payload, 'apartment_number': apartmentNumber},
      options: _authenticated(token, congregationId),
    );
  }

  Future<List<ApartmentDeliveryHistoryEntry>> apartmentHistory({
    required String token,
    required int congregationId,
    required int condominiumId,
    required int campaignId,
    required int apartmentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/letters/condominiums/$condominiumId/campaigns/$campaignId/apartments/$apartmentId/history',
      options: _authenticated(token, congregationId),
    );
    final items = response.data?['history'] as List? ?? const [];

    return items
        .whereType<Map>()
        .map(
          (item) => ApartmentDeliveryHistoryEntry.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<List<StreetCardSummary>> streetCards({
    required String token,
    required int congregationId,
    bool includeGeometry = false,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/street-cards',
      queryParameters: {'include_geometry': includeGeometry},
      options: _authenticated(token, congregationId),
    );
    final items = response.data?['street_cards'] as List? ?? const [];
    return items
        .whereType<Map>()
        .map(
          (item) => StreetCardSummary.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> importTerritoryMap({
    required String token,
    required int congregationId,
    required bool simulate,
    List<int>? fileBytes,
    String? fileName,
    String? mapsUrl,
    List<String>? territoryCodes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mobile/territories/import-map',
      data: FormData.fromMap({
        'simular': simulate ? '1' : '0',
        if (fileBytes != null && fileName != null)
          'kml': MultipartFile.fromBytes(fileBytes, filename: fileName),
        if (mapsUrl != null && mapsUrl.trim().isNotEmpty)
          'maps_url': mapsUrl.trim(),
        'territorios': ?territoryCodes,
      }),
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'X-Congregation-ID': congregationId.toString(),
        },
        contentType: Headers.multipartFormDataContentType,
        receiveTimeout: const Duration(minutes: 2),
      ),
    );

    return response.data ?? const {};
  }

  Future<StreetCardDetail> streetCard({
    required String token,
    required int congregationId,
    required int streetCardId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/street-cards/$streetCardId',
      options: _authenticated(token, congregationId),
    );
    return StreetCardDetail.fromJson(response.data ?? const {});
  }

  Future<List<StreetRecordedRoute>> streetCardRoutes({
    required String token,
    required int congregationId,
    required int streetCardId,
    String? routeDate,
    int? routeUserId,
  }) async {
    final queryParameters = <String, Object>{};
    if (routeDate != null) {
      queryParameters['route_date'] = routeDate;
    }
    if (routeUserId != null) {
      queryParameters['route_user_id'] = routeUserId;
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '/mobile/street-cards/$streetCardId/routes',
      queryParameters: queryParameters,
      options: _authenticated(token, congregationId),
    );
    final items = response.data?['recorded_routes'] as List? ?? const [];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              StreetRecordedRoute.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> uploadRoutePoints({
    required String token,
    required int congregationId,
    required int territoryId,
    required List<Map<String, Object?>> points,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mobile/territories/$territoryId/route-points',
      data: {'points': points},
      options: _authenticated(token, congregationId),
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> uploadStreetCardRoutePoints({
    required String token,
    required int congregationId,
    required int streetCardId,
    required List<Map<String, Object?>> points,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mobile/street-cards/$streetCardId/route-points',
      data: {'points': points},
      options: _authenticated(token, congregationId),
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> uploadAutomaticRoutePoints({
    required String token,
    required int congregationId,
    required List<Map<String, Object?>> points,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/mobile/routes/route-points',
      data: {'points': points},
      options: _authenticated(token, congregationId),
    );
    return response.data ?? const {};
  }

  Future<int> clearStreetCardTestRoutePoints({
    required String token,
    required int congregationId,
    required int streetCardId,
  }) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/mobile/street-cards/$streetCardId/test-route-points',
      options: _authenticated(token, congregationId),
    );
    return (response.data?['deleted'] as num?)?.toInt() ?? 0;
  }

  Future<void> revokeSession(String token) async {
    await _dio.delete<void>('/mobile/session', options: _authenticated(token));
  }

  Options _authenticated(String token, [int? congregationId]) => Options(
    headers: {
      'Authorization': 'Bearer $token',
      if (congregationId != null)
        'X-Congregation-ID': congregationId.toString(),
    },
  );

  /// A API responde 403 com `code: account_pending` quando a conta existe mas
  /// ainda não foi liberada para nenhuma congregação.
  static bool isAccountPending(Object error) {
    if (error is! DioException) return false;
    final data = error.response?.data;
    final body = switch (data) {
      Map map => map,
      List<int> bytes => _decodeJsonResponse(bytes),
      _ => null,
    };
    return error.response?.statusCode == 403 &&
        body?['code'] == 'account_pending';
  }

  static String messageForError(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      final responseBody = switch (responseData) {
        Map data => data,
        List<int> bytes => _decodeJsonResponse(bytes),
        _ => null,
      };
      final validationErrors = responseBody?['errors'];
      if (validationErrors is Map) {
        for (final messages in validationErrors.values) {
          if (messages is List && messages.isNotEmpty) {
            final first = messages.first;
            if (first is String && first.isNotEmpty) return first;
          }
        }
      }
      final responseMessage = responseBody?['message'];
      if (responseMessage is String && responseMessage.isNotEmpty) {
        return responseMessage;
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Sem conexão. Verifique a internet e tente novamente.';
      }
    }
    return 'Não foi possível concluir agora. Tente novamente.';
  }

  static Map<String, dynamic>? _decodeJsonResponse(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
