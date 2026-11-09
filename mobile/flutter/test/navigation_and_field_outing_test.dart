import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartas/data/mobile_api.dart';
import 'package:cartas/models/mobile_models.dart';
import 'package:cartas/screens/field_outings_screen.dart';
import 'package:cartas/screens/map_screen.dart';
import 'package:cartas/screens/native_sections_screen.dart';
import 'package:cartas/state/mobile_app_controller.dart';

void main() {
  test('export days preserve the date, outing count, and available times', () {
    final day = FieldScheduleExportDay.fromJson({
      'date': '2026-10-18',
      'outings_count': 2,
      'times': ['09:00', '14:00'],
    });

    expect(day.dateKey, '2026-10-18');
    expect(day.outingsCount, 2);
    expect(day.times, ['09:00', '14:00']);
  });

  test('binary API errors still expose the Laravel message', () {
    final request = RequestOptions(path: '/mobile/field-outings/export');
    final error = DioException(
      requestOptions: request,
      response: Response<List<int>>(
        requestOptions: request,
        statusCode: 422,
        data: Uint8List.fromList(
          utf8.encode('{"message":"Marque ao menos um dia."}'),
        ),
      ),
    );

    expect(MobileApi.messageForError(error), 'Marque ao menos um dia.');
  });

  test(
    'circuit overview uses the all-circuit endpoint without plant scope',
    () async {
      RequestOptions? capturedRequest;
      final api = MobileApi(
        dio: Dio(BaseOptions(baseUrl: 'https://unit.example'))
          ..httpClientAdapter = _StaticResponseAdapter(
            utf8.encode(jsonEncode(_circuitOverviewPayload())),
            contentType: 'application/json',
            onRequest: (request) => capturedRequest = request,
          ),
      );

      final overview = await api.circuitOverview(token: 'unit-test');

      expect(capturedRequest?.path, '/mobile/circuit-overview');
      expect(capturedRequest?.headers['Authorization'], 'Bearer unit-test');
      expect(
        capturedRequest?.headers.containsKey('X-Congregation-ID'),
        isFalse,
      );
      expect(overview.circuit, 'RJ-14');
      expect(overview.totals.congregations, 1);
      expect(overview.congregations.single.name, 'Nogueira');
      expect(overview.boundaries.single.congregationId, 17);
    },
  );

  test(
    'automatic route points use the authenticated matching endpoint',
    () async {
      RequestOptions? capturedRequest;
      final api = MobileApi(
        dio: Dio(BaseOptions(baseUrl: 'https://unit.example'))
          ..httpClientAdapter = _StaticResponseAdapter(
            utf8.encode('{"recorded":1,"automatic_matching":true}'),
            contentType: 'application/json',
            onRequest: (request) => capturedRequest = request,
          ),
      );

      final result = await api.uploadAutomaticRoutePoints(
        token: 'unit-test',
        congregationId: 17,
        points: const [
          {
            'client_id': 'e52a1923-276c-4ef3-9f18-69b6b5d871f1',
            'latitude': -22.42,
            'longitude': -43.124,
            'recorded_at': 1792281600,
          },
        ],
      );

      expect(capturedRequest?.path, '/mobile/routes/route-points');
      expect(capturedRequest?.headers['X-Congregation-ID'], '17');
      expect(result['automatic_matching'], isTrue);
    },
  );

  test('map import uploads one source to the selected congregation', () async {
    RequestOptions? capturedRequest;
    final api = MobileApi(
      dio: Dio(BaseOptions(baseUrl: 'https://unit.example'))
        ..httpClientAdapter = _StaticResponseAdapter(
          utf8.encode('{"simulacao":true,"resultado":{}}'),
          contentType: 'application/json',
          onRequest: (request) => capturedRequest = request,
        ),
    );

    final result = await api.importTerritoryMap(
      token: 'unit-test',
      congregationId: 17,
      simulate: true,
      fileBytes: const [0x3c, 0x6b, 0x6d, 0x6c, 0x2f, 0x3e],
      fileName: 'territorios.kml',
      territoryCodes: const ['Nogueira'],
    );

    final form = capturedRequest?.data as FormData;
    expect(capturedRequest?.path, '/mobile/territories/import-map');
    expect(capturedRequest?.headers['Authorization'], 'Bearer unit-test');
    expect(capturedRequest?.headers['X-Congregation-ID'], '17');
    expect(
      form.fields.any((field) => field.key == 'simular' && field.value == '1'),
      isTrue,
    );
    expect(form.files.single.key, 'kml');
    expect(form.files.single.value.filename, 'territorios.kml');
    expect(
      form.fields.any(
        (field) =>
            field.key.startsWith('territorios') && field.value == 'Nogueira',
      ),
      isTrue,
    );
    expect(result['simulacao'], isTrue);
  });

  test(
    'schedule export accepts only files matching the selected format',
    () async {
      final cases = <String, List<int>>{
        'image': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1],
        'pdf': [0x25, 0x50, 0x44, 0x46, 0x2D, 1],
      };

      for (final entry in cases.entries) {
        final api = MobileApi(
          dio: Dio(BaseOptions(baseUrl: 'https://unit.example'))
            ..httpClientAdapter = _StaticResponseAdapter(entry.value),
        );
        final bytes = await api.exportFieldSchedule(
          token: 'unit-test',
          congregationId: 1,
          from: '2026-10-18',
          through: '2026-10-24',
          days: const ['2026-10-18'],
          title: '',
          format: entry.key,
        );

        expect(bytes, entry.value);
      }

      final invalidApi = MobileApi(
        dio: Dio(BaseOptions(baseUrl: 'https://unit.example'))
          ..httpClientAdapter = _StaticResponseAdapter(
            utf8.encode('<html>login</html>'),
          ),
      );
      await expectLater(
        invalidApi.exportFieldSchedule(
          token: 'unit-test',
          congregationId: 1,
          from: '2026-10-18',
          through: '2026-10-24',
          days: const ['2026-10-18'],
          title: '',
          format: 'image',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('condominium summary parses scoped completion and campaign data', () {
    final condominium = CondominiumSummary.fromJson({
      'id': 12,
      'code': '12.007',
      'name': 'Bosque de Montreal',
      'address': 'R. Carvalho Júnior, 113',
      'apartments_count': null,
      'visible_apartments_count': 12,
      'worked_count': 9,
      'delivered_count': 6,
      'progress_percent': 50,
      'campaign_name': 'Normal - 2027',
      'assignment_limited': true,
      'blocks_count': 3,
      'floors_count': 7,
    });

    expect(condominium.displayedApartmentsCount, 12);
    expect(condominium.progressPercent, 50);
    expect(condominium.deliveredCount, 6);
    expect(condominium.campaignName, 'Normal - 2027');
    expect(condominium.assignmentLimited, isTrue);
  });

  testWidgets('bottom navigation keeps every label visible', (tester) async {
    final appState = MobileAppState(
      selectedCongregationId: 1,
      canViewFieldOutings: true,
    );

    await tester.pumpWidget(_testApp(appState, const MapScreen()));
    await tester.pump();

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(
      navigationBar.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysShow,
    );
    expect(
      (navigationBar.destinations.first as NavigationDestination).label,
      'Início',
    );
  });

  testWidgets('account offers native modules for the current permissions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appState = MobileAppState(
      canManageTerritoryDesignations: true,
      canViewPeople: true,
      canViewLetters: true,
      canViewTerritories: true,
      selectedCongregationId: 17,
    );

    await tester.pumpWidget(
      _testApp(appState, const MapScreen(), platform: TargetPlatform.android),
    );
    await tester.pump();
    await tester.tap(find.text('Conta'));
    await tester.pumpAndSettle();

    expect(find.text('Mais recursos'), findsOneWidget);
    expect(find.text('Designações'), findsOneWidget);
    expect(find.text('Pessoas'), findsOneWidget);
    expect(find.text('Estatísticas'), findsOneWidget);
    expect(find.text('Cobertura'), findsOneWidget);
    expect(find.text('Abrir no site'), findsNothing);
    expect(find.text('Mapas JW no SideStore'), findsNothing);
  });

  testWidgets('superadmin can open circuit overview from the initial screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appState = MobileAppState(
      isSuperAdmin: true,
      congregations: const [
        Congregation(id: 17, name: 'Nogueira', slug: 'nogueira'),
      ],
    );
    final controller = _FakeMobileAppController(
      appState,
      exportDays: const [],
      circuitOverview: CircuitOverviewData.fromJson(_circuitOverviewPayload()),
    );

    await tester.pumpWidget(
      _testApp(
        appState,
        const MapScreen(),
        controller: controller,
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todos · Circuito RJ-14'), findsOneWidget);
    await tester.tap(find.text('Todos · Circuito RJ-14'));
    await tester.pumpAndSettle();

    expect(find.text('Visão geral do circuito'), findsOneWidget);
    expect(find.text('Nogueira'), findsOneWidget);
    expect(find.text('2 cartões de rua'), findsOneWidget);
    expect(find.textContaining('5 de 10'), findsOneWidget);
  });

  testWidgets('iOS account shows the SideStore source entry', (tester) async {
    final appState = MobileAppState(selectedCongregationId: 17);

    await tester.pumpWidget(
      _testApp(appState, const MapScreen(), platform: TargetPlatform.iOS),
    );
    await tester.pump();
    await tester.tap(find.text('Conta'));
    await tester.pumpAndSettle();

    expect(find.text('Mapas JW no SideStore'), findsOneWidget);
    expect(find.textContaining('fonte Arthur’s Apps'), findsOneWidget);
  });

  testWidgets('territory administrators can open the map import flow', (
    tester,
  ) async {
    final adminState = MobileAppState(
      selectedCongregationId: 17,
      canViewStreetCards: true,
      canManageTerritoryCards: true,
    );
    await tester.pumpWidget(_testApp(adminState, const StreetCardsScreen()));
    await tester.pump();

    expect(find.text('Gerar cartões pelo mapa'), findsOneWidget);
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(find.text('Importar mapa da congregação'), findsOneWidget);
    expect(find.text('Conferir sem gravar'), findsOneWidget);
  });

  testWidgets('regular users do not see the map import action', (tester) async {
    final regularUserState = MobileAppState(
      selectedCongregationId: 17,
      canViewStreetCards: true,
    );
    await tester.pumpWidget(
      _testApp(regularUserState, const StreetCardsScreen()),
    );
    await tester.pump();
    expect(find.text('Gerar cartões pelo mapa'), findsNothing);
  });

  testWidgets('dashboard exposes automatic route tracking to permitted users', (
    tester,
  ) async {
    final appState = MobileAppState(
      canRecordRoutes: true,
      selectedCongregationId: 17,
    );

    await tester.pumpWidget(
      _testApp(
        appState,
        DashboardScreen(
          onNavigate: (_) {},
          onOpenStreetCard: (_) {},
          onOpenCircuitOverview: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Marcar trajeto'), findsOneWidget);
    expect(find.text('Iniciar trajeto'), findsOneWidget);
  });

  testWidgets('field outing shows location, address, map link, and cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final daysUntilSunday = DateTime.sunday - now.weekday <= 0
        ? DateTime.sunday - now.weekday + 7
        : DateTime.sunday - now.weekday;
    final exportDate = DateTime(now.year, now.month, now.day + daysUntilSunday);
    final appState = MobileAppState(
      selectedCongregationId: 1,
      canViewFieldOutings: true,
      fieldCalendar: FieldCalendarData.fromJson({
        'month': month,
        'outings': [
          {
            'id': 12,
            'date': date,
            'time': '09:00',
            'leader': 'Ana Silva',
            'notes': '',
            'all_groups': false,
            'groups': [
              {'id': 3, 'name': 'Centro', 'color': '#34745A'},
            ],
            'location': {
              'id': 8,
              'name': 'Praça Central',
              'address': 'Rua Principal',
              'maps_url': 'https://maps.example/central',
            },
            'situation': {'slug': 'pendente', 'label': 'Pendente'},
            'territory_cards': [
              {'id': 14, 'code': 'T.14', 'name': 'Jardim Primavera'},
            ],
          },
        ],
        'patterns': [],
        'locations': [],
        'groups': [],
        'leaders': [],
        'permissions': {'can_manage': false, 'can_manage_locations': false},
      }),
    );
    final fakeController = _FakeMobileAppController(
      appState,
      exportDays: [
        FieldScheduleExportDay(
          date: exportDate,
          outingsCount: 1,
          times: const ['09:00'],
        ),
        FieldScheduleExportDay(
          date: exportDate.add(const Duration(days: 2)),
          outingsCount: 1,
          times: const ['14:00'],
        ),
      ],
    );
    const shareChannel = MethodChannel('br.com.mapasjw.cartas/share');
    final sharedFiles = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          sharedFiles.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null),
    );

    await tester.pumpWidget(
      _testApp(
        appState,
        const FieldOutingsScreen(),
        controller: fakeController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Praça Central'), findsOneWidget);
    expect(find.text('Rua Principal'), findsOneWidget);
    expect(find.text('Ver no mapa'), findsOneWidget);
    expect(find.text('Centro'), findsOneWidget);
    expect(find.text('T.14 · Jardim Primavera'), findsOneWidget);
    expect(find.text('Exportar programação'), findsOneWidget);

    await tester.tap(find.text('Exportar programação'));
    await tester.pumpAndSettle();

    expect(find.text('Escolha o período da programação'), findsOneWidget);
    expect(find.text('Carregar dias'), findsOneWidget);
    await tester.tap(find.text('Carregar dias'));
    await tester.pumpAndSettle();

    expect(find.text('Marcar todos'), findsOneWidget);
    expect(find.textContaining('1 saída(s) · 09:00'), findsOneWidget);
    expect(find.text('Compartilhar PDF'), findsOneWidget);
    await tester.tap(
      find.ancestor(
        of: find.textContaining('1 saída(s) · 14:00'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Compartilhar PDF'));
    await tester.pumpAndSettle();

    expect(fakeController.exportRequest, {
      'from': _dateKeyForTest(exportDate),
      'through': _dateKeyForTest(exportDate.add(const Duration(days: 6))),
      'days': [_dateKeyForTest(exportDate)],
      'title': '',
      'format': 'pdf',
    });
    expect(sharedFiles, hasLength(1));
    expect(sharedFiles.single.method, 'shareFile');
  });

  testWidgets(
    'field outing editor lists street points and keeps notes above keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final date = '$month-${now.day.toString().padLeft(2, '0')}';
      final appState = MobileAppState(
        selectedCongregationId: 1,
        canViewFieldOutings: true,
        fieldCalendar: FieldCalendarData.fromJson({
          'month': month,
          'outings': [
            {
              'id': 12,
              'date': date,
              'time': '09:00',
              'leader': 'Ana Silva',
              'notes': '',
              'all_groups': true,
              'groups': [],
              'location': {
                'id': 8,
                'name': 'Praça Central',
                'address': 'Rua Principal, 10',
                'reference': 'Em frente à padaria',
              },
              'situation': {'slug': 'pendente', 'label': 'Pendente'},
              'street_points': [
                {
                  'id': 'p1',
                  'card_code': '11.005',
                  'point_name': 'Entrada Norte',
                  'streets': ['Rua Alfa', 'Rua Beta'],
                  'location': {
                    'id': 9,
                    'name': 'Ponto',
                    'address': 'Av. do Ponto, 5',
                    'reference': 'Perto do mercado',
                  },
                },
              ],
            },
          ],
          'patterns': [],
          'locations': [
            {
              'id': 8,
              'name': 'Praça Central',
              'address': 'Rua Principal, 10',
              'reference': 'Em frente à padaria',
            },
          ],
          'groups': [],
          'leaders': [],
          'permissions': {'can_manage': true, 'can_manage_locations': false},
        }),
      );
      await tester.pumpWidget(
        _testApp(
          appState,
          const FieldOutingsScreen(),
          controller: _FakeMobileAppController(appState, exportDays: const []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ref.: Em frente à padaria'), findsOneWidget);
      expect(find.text('11.005 · Entrada Norte'), findsOneWidget);
      expect(find.text('Rua Alfa, Rua Beta'), findsOneWidget);
      expect(find.text('Av. do Ponto, 5'), findsOneWidget);
      expect(find.text('Ref.: Perto do mercado'), findsOneWidget);

      await tester.tap(find.byTooltip('Opções da saída'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      // A edição não mostra mais trechos nem cartões sugeridos: só o card da saída.
      expect(find.text('TRECHOS DESTA SAÍDA'), findsOneWidget);
      expect(find.text('Rua Alfa, Rua Beta'), findsOneWidget);

      final notes = find.byKey(const ValueKey('outing-notes-field'));
      await tester.dragUntilVisible(
        notes,
        find.byType(ListView).last,
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      await tester.tap(notes);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pumpAndSettle();
      tester.testTextInput.enterText('Levar mapas extras');
      await tester.pumpAndSettle();

      final rect = tester.getRect(notes);
      expect(rect.bottom, lessThanOrEqualTo(900 - 400));
      expect(rect.top, greaterThanOrEqualTo(0));
    },
  );

  testWidgets('letters list shows campaign progress and filters by search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appState = MobileAppState(
      selectedCongregationId: 1,
      canViewLetters: true,
      condominiums: const [
        CondominiumSummary(
          id: 11,
          code: '12.007',
          name: 'Bosque de Montreal',
          address: 'R. Carvalho Júnior, 113',
          apartmentsCount: 336,
          visibleApartmentsCount: 336,
          deliveredCount: 134,
          workedCount: 190,
          progressPercent: 40,
          campaignName: 'Normal - 2027',
          blocksCount: 3,
          floorsCount: 7,
        ),
        CondominiumSummary(
          id: 12,
          code: '12.001',
          name: 'BNH Corrêas',
          address: 'Estr. União e Indústria',
          apartmentsCount: 240,
          visibleApartmentsCount: 240,
          deliveredCount: 240,
          workedCount: 240,
          progressPercent: 100,
          campaignName: 'Normal - 2027',
        ),
      ],
    );

    await tester.pumpWidget(_testApp(appState, const LettersScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('40%'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Campanha · Normal - 2027'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('134 de 336 entregues · Normal - 2027'), findsOneWidget);
    expect(find.text('Todos · 2'), findsOneWidget);
    expect(find.text('Em aberto · 1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'BNH');
    await tester.pumpAndSettle();

    expect(find.text('BNH Corrêas'), findsOneWidget);
    expect(find.text('Bosque de Montreal'), findsNothing);
  });
}

Widget _testApp(
  MobileAppState state,
  Widget screen, {
  List<FieldScheduleExportDay> exportDays = const [],
  _FakeMobileAppController? controller,
  TargetPlatform? platform,
}) => ProviderScope(
  overrides: [
    mobileAppControllerProvider.overrideWith(
      () =>
          controller ?? _FakeMobileAppController(state, exportDays: exportDays),
    ),
  ],
  child: MaterialApp(
    theme: platform == null ? null : ThemeData(platform: platform),
    home: Consumer(
      builder: (context, ref, child) => ref
          .watch(mobileAppControllerProvider)
          .when(
            data: (_) => Scaffold(body: screen),
            error: (error, stackTrace) => Text('$error'),
            loading: () => const SizedBox.shrink(),
          ),
    ),
  ),
);

class _FakeMobileAppController extends MobileAppController {
  _FakeMobileAppController(
    this.initialState, {
    required this.exportDays,
    this.circuitOverview,
  });

  final MobileAppState initialState;
  final List<FieldScheduleExportDay> exportDays;
  final CircuitOverviewData? circuitOverview;
  Map<String, Object?>? exportRequest;

  @override
  Future<MobileAppState> build() async => initialState;

  @override
  Future<CircuitOverviewData> loadCircuitOverview() async {
    final overview = circuitOverview;
    if (overview == null) {
      throw StateError('No circuit overview configured for this test.');
    }

    return overview;
  }

  @override
  Future<List<FieldScheduleExportDay>> fieldScheduleExportDays({
    required String from,
    required String through,
  }) async => exportDays;

  @override
  Future<Uint8List> exportFieldSchedule({
    required String from,
    required String through,
    required List<String> days,
    required String title,
    required String format,
  }) async {
    exportRequest = {
      'from': from,
      'through': through,
      'days': days,
      'title': title,
      'format': format,
    };

    return Uint8List.fromList([1, 2, 3]);
  }
}

class _StaticResponseAdapter implements HttpClientAdapter {
  _StaticResponseAdapter(this.bytes, {this.onRequest, this.contentType});

  final List<int> bytes;
  final void Function(RequestOptions request)? onRequest;
  final String? contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest?.call(options);

    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: contentType == null
          ? null
          : {
              Headers.contentTypeHeader: [contentType!],
            },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _circuitOverviewPayload() => {
  'circuit': 'RJ-14',
  'totals': {
    'congregacoes': 1,
    'limites': 1,
    'cartoes_rua': 2,
    'trechos': 9,
    'cartoes_legados': 10,
    'cartoes_com_trabalho': 5,
    'passagens': 8,
    'dias_percurso': 3,
    'pontos_percurso': 20,
  },
  'summary': [
    {
      'id': 17,
      'congregacao': 'Nogueira',
      'cor': '#1f77b4',
      'limites': 1,
      'cartoes_rua': 2,
      'trechos': 9,
      'cartoes_legados': 10,
      'cartoes_com_trabalho': 5,
      'passagens': 8,
      'dias_percurso': 3,
      'pontos_percurso': 20,
      'uso_legado_percentual': 50,
    },
  ],
  'geojson': {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [-43.15, -22.4],
              [-43.1, -22.4],
              [-43.1, -22.45],
              [-43.15, -22.4],
            ],
          ],
        },
        'properties': {
          'congregacao_id': 17,
          'congregacao': 'Nogueira',
          'limite': 'Limite 1 de 1',
          'cor': '#1f77b4',
        },
      },
    ],
  },
};

String _dateKeyForTest(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
