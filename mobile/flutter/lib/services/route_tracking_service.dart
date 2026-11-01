import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/mobile_api.dart';
import '../data/pending_route_store.dart';

class RouteTrackingEvent {
  const RouteTrackingEvent({
    this.active,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.pendingCount,
    this.message,
    this.territoryId,
    this.streetCardId,
    this.isTest,
  });

  final bool? active;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final int? pendingCount;
  final String? message;
  final int? territoryId;
  final int? streetCardId;
  final bool? isTest;
}

Future<void> configureRouteBackgroundService() async {
  await FlutterBackgroundService().configure(
    iosConfiguration: IosConfiguration(autoStart: false),
    androidConfiguration: AndroidConfiguration(
      onStart: androidRouteServiceEntrypoint,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      initialNotificationTitle: 'Mapas JW · trajeto ativo',
      initialNotificationContent: 'Preparando o registro do trajeto…',
      foregroundServiceNotificationId: 8642,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
  );
}

@pragma('vm:entry-point')
void androidRouteServiceEntrypoint(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  _AndroidRouteWorker(service).attach();
}

class RouteTrackingService {
  RouteTrackingService({MobileApi? api, PendingRouteStore? store})
    : _api = api ?? MobileApi(),
      _store = store ?? PendingRouteStore.instance {
    _service.on('route_status').listen(_onServiceStatus);
    _service.on('route_position').listen(_onServicePosition);
    _service.on('route_queue').listen(_onServiceQueue);
    _service.on('route_problem').listen(_onServiceProblem);
  }

  final MobileApi _api;
  final PendingRouteStore _store;
  final FlutterBackgroundService _service = FlutterBackgroundService();
  final StreamController<RouteTrackingEvent> _events =
      StreamController<RouteTrackingEvent>.broadcast();

  StreamSubscription<Position>? _iosPositionSubscription;
  Timer? _iosFlushTimer;
  Map<String, Object?>? _iosSession;
  bool _iosFlushInProgress = false;

  Stream<RouteTrackingEvent> get events => _events.stream;

  Future<void> dispose() async {
    await _iosPositionSubscription?.cancel();
    _iosFlushTimer?.cancel();
    await _events.close();
  }

  Future<Position> getCurrentPosition() async {
    var permission = await Permission.locationWhenInUse.status;
    if (!permission.isGranted) {
      permission = await Permission.locationWhenInUse.request();
    }
    if (!permission.isGranted) {
      final message = permission.isPermanentlyDenied || permission.isRestricted
          ? 'A localização está bloqueada nas configurações do aparelho. Ative-a para o Mapas JW.'
          : 'Permita o acesso à localização durante o uso para encontrar sua posição no mapa.';
      throw StateError(message);
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Ative a localização do aparelho e tente novamente.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
    } on TimeoutException {
      throw StateError(
        'Ainda não foi possível obter uma posição precisa. Vá para um local aberto e tente novamente.',
      );
    } on PermissionDeniedException {
      throw StateError(
        'A localização foi negada. Ative a permissão do Mapas JW nas configurações do aparelho.',
      );
    }
  }

  Future<String?> requestPermissions() async {
    final foreground = await Permission.locationWhenInUse.request();
    if (!foreground.isGranted) {
      return 'A localização durante o uso é necessária para registrar o trajeto.';
    }

    final background = await Permission.locationAlways.request();
    if (!background.isGranted) {
      return 'Permita o acesso à localização em segundo plano para continuar registrando com a tela bloqueada.';
    }

    if (Platform.isAndroid) {
      final notification = await Permission.notification.request();
      if (!notification.isGranted) {
        return 'Permita a notificação para que o Android mostre quando um trajeto estiver sendo registrado.';
      }
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Ative os serviços de localização do aparelho e tente novamente.';
    }

    return null;
  }

  Future<void> start({
    required String token,
    required int userId,
    required int congregationId,
    int? territoryId,
    int? streetCardId,
    bool automaticMatching = false,
    bool testMode = false,
  }) async {
    if (automaticMatching && (territoryId != null || streetCardId != null)) {
      throw ArgumentError(
        'Percursos automáticos não devem receber cartão prévio.',
      );
    }
    if (!automaticMatching && territoryId == null && streetCardId == null) {
      throw ArgumentError(
        'Informe um cartão ou habilite a associação automática.',
      );
    }

    final session = <String, Object?>{
      'token': token,
      'user_id': userId,
      'congregation_id': congregationId,
      'territory_id': territoryId,
      'street_card_id': streetCardId,
      'automatic_matching': automaticMatching,
      'test_mode': testMode,
    };

    await _store.clearForOtherUsers(userId);

    if (Platform.isAndroid) {
      if (await _service.isRunning()) {
        _service.invoke('stop_tracking', {'flush_pending': false});
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      final started = await _service.startService();
      if (!started) throw StateError('O serviço de localização não iniciou.');
      _service.invoke('start_tracking', session);
      return;
    }

    _iosSession = session;
    _events.add(
      RouteTrackingEvent(
        active: true,
        territoryId: territoryId,
        streetCardId: streetCardId,
        isTest: testMode,
        message: _trackingMessage(automaticMatching, testMode),
      ),
    );
    _iosPositionSubscription =
        Geolocator.getPositionStream(
          locationSettings: AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.fitness,
            distanceFilter: 8,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          ),
        ).listen(
          _recordIosPosition,
          onError: (Object error) {
            unawaited(
              stop(
                flushPending: false,
                message: MobileApi.messageForError(error),
              ),
            );
          },
        );
    _iosFlushTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_flushIosQueue());
    });
  }

  Future<void> stop({bool flushPending = true, String? message}) async {
    if (Platform.isAndroid) {
      if (await _service.isRunning()) {
        _service.invoke('stop_tracking', {
          'flush_pending': flushPending,
          ...?(message == null ? null : {'message': message}),
        });
      }
      return;
    }

    _iosFlushTimer?.cancel();
    _iosFlushTimer = null;
    await _iosPositionSubscription?.cancel();
    _iosPositionSubscription = null;
    final previousSession = _iosSession;
    _iosSession = null;
    var finalMessage = message;

    if (flushPending && previousSession != null) {
      try {
        await _uploadPending(previousSession);
      } on Object catch (error) {
        finalMessage ??= MobileApi.messageForError(error);
      }
    }

    _events.add(
      RouteTrackingEvent(
        active: false,
        isTest: previousSession?['test_mode'] as bool?,
        message: finalMessage ?? 'Trajeto encerrado.',
      ),
    );
  }

  Future<void> requestCurrentStatus() async {
    if (Platform.isAndroid && await _service.isRunning()) {
      _service.invoke('route_status_request');
    }
  }

  Future<void> _recordIosPosition(Position position) async {
    final session = _iosSession;
    if (session == null || position.accuracy > 80) return;

    await _store.insert(_pointFor(position, session));
    _events.add(
      RouteTrackingEvent(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        pendingCount: await _queueCount(session),
      ),
    );
    await _flushIosQueue();
  }

  Future<void> _flushIosQueue() async {
    final session = _iosSession;
    if (session == null || _iosFlushInProgress) return;

    _iosFlushInProgress = true;
    try {
      await _uploadPending(session);
      _events.add(RouteTrackingEvent(pendingCount: await _queueCount(session)));
    } on Object catch (error) {
      _events.add(
        RouteTrackingEvent(message: MobileApi.messageForError(error)),
      );
      final statusCode = error is DioException
          ? error.response?.statusCode
          : null;
      if ([401, 403, 409].contains(statusCode)) {
        await stop(
          flushPending: false,
          message: MobileApi.messageForError(error),
        );
      }
    } finally {
      _iosFlushInProgress = false;
    }
  }

  Future<void> _uploadPending(Map<String, Object?> session) async {
    await _uploadPendingForSession(_api, _store, session);
  }

  Future<int> _queueCount(Map<String, Object?> session) => _store.count(
    userId: session['user_id']! as int,
    congregationId: session['congregation_id']! as int,
  );

  void _onServiceStatus(Map<String, dynamic>? data) {
    if (data == null) return;
    _events.add(
      RouteTrackingEvent(
        active: data['active'] as bool?,
        territoryId: data['territory_id'] as int?,
        streetCardId: data['street_card_id'] as int?,
        isTest: data['test_mode'] as bool?,
        message: data['message'] as String?,
      ),
    );
  }

  void _onServicePosition(Map<String, dynamic>? data) {
    if (data == null) return;
    _events.add(
      RouteTrackingEvent(
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        accuracy: (data['accuracy'] as num?)?.toDouble(),
        pendingCount: data['pending_count'] as int?,
      ),
    );
  }

  void _onServiceQueue(Map<String, dynamic>? data) {
    if (data == null) return;
    _events.add(
      RouteTrackingEvent(pendingCount: data['pending_count'] as int?),
    );
  }

  void _onServiceProblem(Map<String, dynamic>? data) {
    if (data == null) return;
    _events.add(
      RouteTrackingEvent(
        active: data['active'] as bool?,
        territoryId: data['territory_id'] as int?,
        streetCardId: data['street_card_id'] as int?,
        isTest: data['test_mode'] as bool?,
        message: data['message'] as String?,
      ),
    );
  }

  static Map<String, Object?> _pointFor(
    Position position,
    Map<String, Object?> session,
  ) => {
    'client_id': _newUuid(),
    'user_id': session['user_id'] as int,
    'congregation_id': session['congregation_id'] as int,
    'territory_id': (session['territory_id'] as int?) ?? 0,
    'street_card_id': session['street_card_id'] as int?,
    'latitude': position.latitude,
    'longitude': position.longitude,
    'accuracy': position.accuracy,
    'recorded_at': position.timestamp.toUtc().millisecondsSinceEpoch ~/ 1000,
    'is_test': session['test_mode'] == true ? 1 : 0,
  };

  static Map<String, Object?> _apiPoint(Map<String, Object?> point) => {
    'client_id': point['client_id'],
    'latitude': point['latitude'],
    'longitude': point['longitude'],
    'accuracy': point['accuracy'],
    'recorded_at': point['recorded_at'],
    'test_mode': point['is_test'] == 1 || point['is_test'] == true,
  };

  static List<String> _acknowledgedIds(Map<String, dynamic> response) => [
    ...(response['accepted_client_ids'] as List? ?? const []).cast<String>(),
    ...(response['discarded_client_ids'] as List? ?? const []).cast<String>(),
  ];

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

String _trackingMessage(bool automaticMatching, bool testMode) {
  if (testMode) return 'Trajeto de teste em registro.';
  if (automaticMatching) {
    return 'Trajeto em registro. Os cartões serão reconhecidos automaticamente.';
  }

  return 'Trajeto em registro.';
}

class _AndroidRouteWorker {
  _AndroidRouteWorker(this.service);

  final ServiceInstance service;
  final MobileApi api = MobileApi();
  final PendingRouteStore store = PendingRouteStore.instance;
  StreamSubscription<Position>? positions;
  Timer? flushTimer;
  Map<String, Object?>? session;
  bool flushing = false;

  void attach() {
    service.on('start_tracking').listen((data) {
      if (data != null) unawaited(start(Map<String, Object?>.from(data)));
    });
    service.on('stop_tracking').listen((data) {
      final flushPending = data?['flush_pending'] != false;
      unawaited(
        stop(flushPending: flushPending, message: data?['message'] as String?),
      );
    });
    service.on('route_status_request').listen((_) => publishStatus());
  }

  Future<void> start(Map<String, Object?> newSession) async {
    await positions?.cancel();
    session = newSession;
    positions =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 8,
            intervalDuration: const Duration(seconds: 10),
          ),
        ).listen(
          record,
          onError: (Object error) {
            unawaited(
              stop(
                flushPending: false,
                message: MobileApi.messageForError(error),
              ),
            );
          },
        );
    flushTimer?.cancel();
    flushTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(flush());
    });
    publishStatus();
  }

  Future<void> record(Position position) async {
    final activeSession = session;
    if (activeSession == null || position.accuracy > 80) return;

    await store.insert(RouteTrackingService._pointFor(position, activeSession));
    service.invoke('route_position', {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'pending_count': await queueCount(activeSession),
    });
    await flush();
  }

  Future<void> flush() async {
    final activeSession = session;
    if (activeSession == null || flushing) return;
    flushing = true;

    try {
      await uploadPending(activeSession);
      service.invoke('route_queue', {
        'pending_count': await queueCount(activeSession),
      });
    } on Object catch (error) {
      final statusCode = error is DioException
          ? error.response?.statusCode
          : null;
      if ([401, 403, 409].contains(statusCode)) {
        await stop(
          flushPending: false,
          message: MobileApi.messageForError(error),
        );
      } else {
        service.invoke('route_problem', {
          'active': true,
          'territory_id': activeSession['territory_id'],
          'street_card_id': activeSession['street_card_id'],
          'message': MobileApi.messageForError(error),
        });
      }
    } finally {
      flushing = false;
    }
  }

  Future<void> uploadPending(Map<String, Object?> activeSession) async {
    await _uploadPendingForSession(api, store, activeSession);
  }

  Future<int> queueCount(Map<String, Object?> activeSession) => store.count(
    userId: activeSession['user_id']! as int,
    congregationId: activeSession['congregation_id']! as int,
  );

  void publishStatus() {
    final automaticMatching = session?['automatic_matching'] == true;
    final testMode = session?['test_mode'] == true;

    service.invoke('route_status', {
      'active': session != null,
      'territory_id': session?['territory_id'],
      'street_card_id': session?['street_card_id'],
      'test_mode': testMode,
      'message': session == null
          ? 'Nenhum trajeto ativo.'
          : _trackingMessage(automaticMatching, testMode),
    });
  }

  Future<void> stop({bool flushPending = true, String? message}) async {
    flushTimer?.cancel();
    flushTimer = null;
    await positions?.cancel();
    positions = null;
    final previousSession = session;
    session = null;

    var finalMessage = message;
    if (flushPending && previousSession != null) {
      try {
        await uploadPending(previousSession);
      } on Object catch (error) {
        finalMessage ??= MobileApi.messageForError(error);
      }
    }

    service.invoke('route_status', {
      'active': false,
      'territory_id': previousSession?['territory_id'],
      'street_card_id': previousSession?['street_card_id'],
      'test_mode': previousSession?['test_mode'] == true,
      'message': finalMessage ?? 'Trajeto encerrado.',
    });
    await service.stopSelf();
  }
}

Future<void> _uploadPendingForSession(
  MobileApi api,
  PendingRouteStore store,
  Map<String, Object?> session,
) async {
  if (session['automatic_matching'] == true) {
    await _uploadPendingQueue(
      api,
      store,
      session,
      null,
      automaticMatching: true,
    );
    return;
  }

  final streetCardId = session['street_card_id'] as int?;
  if (streetCardId != null) {
    await _uploadPendingQueue(api, store, session, streetCardId);
  }

  // Flush points queued by pre-street-card app versions through the legacy
  // territory endpoint. Never attach those old points to an arbitrary card.
  await _uploadPendingQueue(api, store, session, null);
}

Future<void> _uploadPendingQueue(
  MobileApi api,
  PendingRouteStore store,
  Map<String, Object?> session,
  int? streetCardId, {
  bool automaticMatching = false,
}) async {
  final territoryId = (session['territory_id'] as int?) ?? 0;
  final points = await store.pending(
    userId: session['user_id']! as int,
    congregationId: session['congregation_id']! as int,
    territoryId: territoryId,
    streetCardId: streetCardId,
  );
  if (points.isEmpty) return;

  for (final isTest in [false, true]) {
    final modePoints = points
        .where((point) => (point['is_test'] == 1) == isTest)
        .toList(growable: false);
    if (modePoints.isEmpty) continue;

    final apiPoints = modePoints
        .map(RouteTrackingService._apiPoint)
        .toList(growable: false);
    final response = automaticMatching
        ? await api.uploadAutomaticRoutePoints(
            token: session['token']! as String,
            congregationId: session['congregation_id']! as int,
            points: apiPoints,
          )
        : streetCardId == null
        ? await api.uploadRoutePoints(
            token: session['token']! as String,
            congregationId: session['congregation_id']! as int,
            territoryId: territoryId,
            points: apiPoints,
          )
        : await api.uploadStreetCardRoutePoints(
            token: session['token']! as String,
            congregationId: session['congregation_id']! as int,
            streetCardId: streetCardId,
            points: apiPoints,
          );
    await store.deleteClientIds(
      RouteTrackingService._acknowledgedIds(response),
    );
  }
}
