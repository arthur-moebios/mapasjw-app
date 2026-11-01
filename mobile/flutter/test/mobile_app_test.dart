import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';

import 'package:cartas/data/mobile_api.dart';
import 'package:cartas/models/mobile_models.dart';
import 'package:cartas/screens/field_outings_screen.dart';
import 'package:cartas/screens/login_screen.dart';
import 'package:cartas/screens/map_point_sheets.dart';
import 'package:cartas/screens/map_screen.dart';
import 'package:cartas/screens/native_sections_screen.dart';
import 'package:cartas/state/mobile_app_controller.dart';

void main() {
  test('parses native territory designations from the mobile API', () {
    final data = MobileDesignationsData.fromJson({
      'summary': {'people': 1, 'condominiums': 1},
      'assignments': [
        {
          'id': 7,
          'person_id': 3,
          'person': 'Arthur',
          'condominium_id': 19,
          'condominium': 'Residencial Aurora',
          'place': 'Bloco A · 2º andar',
          'level': 'Pavimento',
          'since': '2026-10-18',
        },
      ],
    });

    expect(data.assignments.single.person, 'Arthur');
    expect(data.assignments.single.place, 'Bloco A · 2º andar');
    expect(data.peopleCount, 1);
    expect(data.condominiumsCount, 1);
  });

  test('parses the native people directory without assuming active access', () {
    final person = MobilePerson.fromJson({
      'id': 12,
      'name': 'Joana',
      'email': 'joana@example.test',
      'profile': 'Publicadora',
      'is_active': false,
      'is_self': false,
    });

    expect(person.name, 'Joana');
    expect(person.profile, 'Publicadora');
    expect(person.isActive, isFalse);
  });

  group('Territory geometry', () {
    test('detects a point inside a Polygon and rejects a point outside', () {
      final territory = Territory.fromJson(
        _territoryJson(
          type: 'Polygon',
          coordinates: [
            [
              [-2, -2],
              [2, -2],
              [2, 2],
              [-2, 2],
              [-2, -2],
            ],
          ],
        ),
      );

      expect(territory.contains(const LatLng(0, 0)), isTrue);
      expect(territory.contains(const LatLng(3, 3)), isFalse);
      expect(territory.polygonRings(), hasLength(1));
    });

    test('keeps holes excluded from a territory', () {
      final territory = Territory.fromJson(
        _territoryJson(
          type: 'Polygon',
          coordinates: [
            [
              [0, 0],
              [6, 0],
              [6, 6],
              [0, 6],
              [0, 0],
            ],
            [
              [2, 2],
              [4, 2],
              [4, 4],
              [2, 4],
              [2, 2],
            ],
          ],
        ),
      );

      expect(territory.contains(const LatLng(1, 1)), isTrue);
      expect(territory.contains(const LatLng(3, 3)), isFalse);
    });

    test('renders all polygons in a MultiPolygon', () {
      final territory = Territory.fromJson(
        _territoryJson(
          type: 'MultiPolygon',
          coordinates: [
            [
              [
                [0, 0],
                [1, 0],
                [1, 1],
                [0, 1],
                [0, 0],
              ],
            ],
            [
              [
                [3, 3],
                [4, 3],
                [4, 4],
                [3, 4],
                [3, 3],
              ],
            ],
          ],
        ),
      );

      expect(territory.polygonRings(), hasLength(2));
      expect(territory.contains(const LatLng(3.5, 3.5)), isTrue);
    });
  });

  test('parses the dashboard summary and its status colors', () {
    final summary = MobileDashboardSummary.fromJson({
      'generated_at': '2026-10-17T14:00:00-03:00',
      'statistics': {
        'letters': {
          'campaign': {'name': 'Normal 2026', 'is_open': true},
          'condominiums_count': 4,
          'apartments_count': 120,
          'delivered_count': 45,
          'worked_count': 72,
          'progress_percent': 38,
          'statuses': [
            {
              'slug': 'ok',
              'label': 'Entregue',
              'color': '#22C55E',
              'count': 45,
              'counts_as_delivered': true,
            },
          ],
        },
        'territories': {
          'total': 12,
          'available': 7,
          'in_progress': 3,
          'completed': 2,
        },
        'street_cards': {'cards': 5, 'streets': 18, 'entrances': 9},
      },
    });

    expect(summary.campaignName, 'Normal 2026');
    expect(summary.deliveredCount, 45);
    expect(summary.letterStatuses.single.countsAsDelivered, isTrue);
    expect(summary.letterStatuses.single.color, const Color(0xFF22C55E));
    expect(summary.completedTerritoriesCount, 2);
    expect(summary.streetSegmentsCount, 18);
  });

  group('Field calendar API data', () {
    test(
      'parses outings, group assignments, recurring patterns and permissions',
      () {
        final calendar = FieldCalendarData.fromJson({
          'month': '2026-10',
          'outings': [
            {
              'id': 12,
              'date': '2026-10-18',
              'time': '09:00',
              'leader': 'Ana Silva',
              'notes': 'Encontrar na praça',
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
              'recurrence_id': 2,
              'territory_cards': [
                {'id': 14, 'code': 'T.14', 'name': 'Jardim Primavera'},
              ],
            },
          ],
          'patterns': [
            {
              'id': 2,
              'name': 'Domingo de manhã',
              'weekdays': [0],
              'time': '09:00',
              'leader': 'Ana Silva',
              'notes': '',
              'all_groups': true,
              'groups': [],
              'location': null,
              'valid_from': null,
              'valid_through': null,
              'is_active': true,
              'description': 'Domingo às 09:00',
            },
          ],
          'locations': [
            {'id': 8, 'name': 'Praça Central', 'address': '', 'maps_url': ''},
          ],
          'groups': [
            {'id': 3, 'name': 'Centro', 'color': '#34745A'},
          ],
          'leaders': ['Ana Silva'],
          'permissions': {'can_manage': true, 'can_manage_locations': false},
        });

        expect(calendar.month, '2026-10');
        expect(calendar.outings.single.time, '09:00');
        expect(calendar.outings.single.groups.single.name, 'Centro');
        expect(calendar.outings.single.location?.name, 'Praça Central');
        expect(calendar.outingsOn(DateTime(2026, 10, 18)), hasLength(1));
        expect(calendar.outingsOn(DateTime(2026, 10, 19)), isEmpty);
        expect(
          calendar.outings.single.territoryCards.single.label,
          'T.14 · Jardim Primavera',
        );
        expect(calendar.patterns.single.weekdays, [0]);
        expect(calendar.canManage, isTrue);
        expect(calendar.canManageLocations, isFalse);
      },
    );

    test(
      'parses territory designation history without marking it editable',
      () {
        final designations = FieldDesignationsData.fromJson({
          'service_year': 2027,
          'available_years': [2027, 2026],
          'designations': [
            {
              'id': 41,
              'territory_number': '12',
              'territory_name': 'Centro',
              'publisher': 'João',
              'assigned_at': '2026-10-01',
              'completed_at': null,
            },
          ],
          'editable': false,
        });

        expect(designations.serviceYear, 2027);
        expect(designations.designations.single.publisher, 'João');
        expect(designations.designations.single.completedAt, isNull);
        expect(designations.editable, isFalse);
      },
    );
  });

  group('Native letters and street cards', () {
    test('parses a condominium campaign and editable letter status', () {
      final detail = CondominiumDetail.fromJson({
        'condominium': {
          'id': 17,
          'code': 'A.12',
          'name': 'Residencial das Flores',
          'address': 'Rua das Flores, 10',
          'observations': '',
          'blocked': false,
        },
        'campaign': {
          'id': 4,
          'name': 'Normal 2026',
          'slug': 'normal',
          'is_open': true,
        },
        'campaigns': [
          {'id': 4, 'name': 'Normal 2026', 'slug': 'normal', 'is_open': true},
        ],
        'can_choose_campaign': false,
        'can_update_status': true,
        'letter_statuses': [
          {'slug': 'no', 'label': 'Não produzida', 'color': '#607D8B'},
          {'slug': 'escrita', 'label': 'Escrita', 'color': '#34745A'},
        ],
        'apartments': [
          {
            'id': 91,
            'block_name': 'Bloco A',
            'floor_name': '2º andar',
            'apartment_number': '203',
            'apartment_number_value': '203',
            'status': 'escrita',
            'status_label': 'Escrita',
            'status_color': '#34745A',
            'written_by': 'Publicador',
            'can_update': true,
            'is_blocked': false,
          },
        ],
      });

      expect(detail.campaign?.name, 'Normal 2026');
      expect(detail.apartments.single.locationLabel, 'Bloco A · 2º andar');
      expect(detail.apartments.single.canUpdate, isTrue);
      expect(detail.apartments.single.apartmentNumberValue, '203');
      expect(detail.statuses, hasLength(2));
    });

    test('converts street GeoJSON coordinates from longitude-latitude', () {
      final detail = StreetCardDetail.fromJson({
        'street_card': {
          'id': 8,
          'code': 'R.04',
          'name': 'Jardim',
          'neighborhood': 'Centro',
          'group': 'Grupo 1',
          'description': '',
          'origin_territory_id': 2,
          'origin_territory_code': '02',
          'origin_territory_name': 'Território 02',
          'route_recording': {
            'permitido': true,
            'motivo': 'Liberado até 12:00.',
          },
          'can_test_route': true,
          'test_route_points_count': 3,
          'streets': [
            {
              'name': 'Rua Um',
              'coordinates': [
                [-43.2, -22.9],
                [-43.21, -22.91],
              ],
              'start_address': '1',
              'end_address': '99',
            },
          ],
          'entrances': [
            {'name': 'Praça', 'latitude': -22.9, 'longitude': -43.2},
          ],
          'recorded_routes': [
            {
              'id': '12-0-20261017-1',
              'user_id': 12,
              'nome': 'Arthur',
              'is_test': false,
              'cor': '#1A73E8',
              'started_at': '2026-10-17T09:00:00-03:00',
              'ended_at': '2026-10-17T09:05:00-03:00',
              'point_count': 2,
              'coordinates': [
                {'latitude': -22.91, 'longitude': -43.21},
                {'latitude': -22.92, 'longitude': -43.22},
              ],
            },
          ],
          'recorded_route_users': [
            {'user_id': 12, 'name': 'Arthur'},
          ],
        },
      });

      expect(detail.canRecordRoute, isTrue);
      expect(detail.canTestRoute, isTrue);
      expect(detail.testRoutePointsCount, 3);
      expect(detail.streets.single.coordinates.first.latitude, -22.9);
      expect(detail.streets.single.coordinates.first.longitude, -43.2);
      expect(detail.entrances.single.name, 'Praça');
      expect(detail.originTerritoryId, 2);
      expect(detail.recordedRoutes.single.name, 'Arthur');
      expect(detail.recordedRoutes.single.userId, 12);
      expect(detail.recordedRoutes.single.pointCount, 2);
      expect(detail.recordedRoutes.single.coordinates.first.latitude, -22.91);
      expect(detail.recordedRouteUsers.single.name, 'Arthur');
    });

    test('filters recorded routes by local day and user', () {
      final routes = [
        _recordedRoute('a', 12, '2026-10-17T09:00:00-03:00'),
        _recordedRoute('b', 19, '2026-10-17T10:00:00-03:00'),
        _recordedRoute('c', 12, '2026-10-18T09:00:00-03:00'),
      ];

      expect(filterStreetRecordedRoutes(routes, dayKey: '2026-10-17'), [
        routes[0],
        routes[1],
      ]);
      expect(
        filterStreetRecordedRoutes(routes, dayKey: '2026-10-17', userId: 12),
        [routes[0]],
      );
    });

    test('identifies the do-not-visit point type and parses its map data', () {
      final point = MapPoint.fromJson({
        'id': 3,
        'latitude': -22.9,
        'longitude': -43.2,
        'title': 'Casa 17',
        'address': 'Rua Um, 17',
        'type': 'Não bater',
        'color': '#C0392B',
      });

      expect(point.isDoNotVisit, isTrue);
      expect(point.position.latitude, -22.9);
      expect(point.color, const Color(0xFFC0392B));
    });

    test('loads visible congregation map points from the mobile API', () async {
      RequestOptions? capturedRequest;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedRequest = options;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'points': [
                      {
                        'id': 31,
                        'latitude': -22.9,
                        'longitude': -43.2,
                        'title': '',
                        'address': '',
                        'type': 'Não bater',
                        'color': '#C0392B',
                        'type_id': 5,
                        'notes': 'Cachorro bravo',
                        'icon': '🚫',
                      },
                    ],
                    'types': [
                      {
                        'id': 5,
                        'name': 'Não bater',
                        'color': '#C0392B',
                        'icon': '🚫',
                      },
                    ],
                    'can_manage': true,
                  },
                ),
              );
            },
          ),
        );

      final points = await MobileApi(dio: dio)
          .mapPoints(token: 'session-token', congregationId: 7);

      expect(capturedRequest?.path, '/mobile/map-points');
      expect(capturedRequest?.headers['X-Congregation-ID'], '7');
      expect(points.points.single.isDoNotVisit, isTrue);
      expect(points.points.single.typeId, 5);
      expect(points.points.single.notes, 'Cachorro bravo');
      expect(points.types.single.name, 'Não bater');
      expect(points.types.single.isDoNotVisit, isTrue);
      expect(points.canManage, isTrue);
    });

    test('creates, edits and removes map points', () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'point': {
                      'id': 9,
                      'latitude': -22.9,
                      'longitude': -43.2,
                      'type': 'Não bater',
                      'color': '#C0392B',
                      'type_id': 5,
                    },
                  },
                ),
              );
            },
          ),
        );
      final api = MobileApi(dio: dio);
      const data = {'type_id': 5, 'latitude': -22.9, 'longitude': -43.2};

      await api.saveMapPoint(token: 't', congregationId: 7, data: data);
      await api.saveMapPoint(
        token: 't',
        congregationId: 7,
        pointId: 9,
        data: data,
      );
      await api.deleteMapPoint(token: 't', congregationId: 7, pointId: 9);

      expect(requests.map((r) => '${r.method} ${r.path}'), [
        'POST /mobile/map-points',
        'PATCH /mobile/map-points/9',
        'DELETE /mobile/map-points/9',
      ]);
      expect(requests.first.headers['X-Congregation-ID'], '7');
    });

    test('shows the first server validation message in Portuguese', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/mobile/map-points'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/mobile/map-points'),
          statusCode: 422,
          data: const {
            'message': 'The given data was invalid.',
            'errors': {
              'type_id': ['Escolha o tipo do ponto.'],
            },
          },
        ),
      );

      expect(MobileApi.messageForError(error), 'Escolha o tipo do ponto.');
    });

    test('requests route history for the selected date and user', () async {
      RequestOptions? capturedRequest;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedRequest = options;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'recorded_routes': [
                      {
                        'id': 'selected-route',
                        'user_id': 12,
                        'nome': 'Arthur',
                        'is_test': false,
                        'cor': '#1A73E8',
                        'started_at': '2026-10-17T09:00:00-03:00',
                        'ended_at': '2026-10-17T09:05:00-03:00',
                        'point_count': 2,
                        'coordinates': [],
                      },
                    ],
                  },
                ),
              );
            },
          ),
        );

      final routes = await MobileApi(dio: dio).streetCardRoutes(
        token: 'session-token',
        congregationId: 7,
        streetCardId: 18,
        routeDate: '2026-10-17',
        routeUserId: 12,
      );

      expect(capturedRequest?.path, '/mobile/street-cards/18/routes');
      expect(capturedRequest?.headers['X-Congregation-ID'], '7');
      expect(capturedRequest?.queryParameters, {
        'route_date': '2026-10-17',
        'route_user_id': 12,
      });
      expect(routes.single.userId, 12);
    });

    test('uploads route points through the street-card endpoint', () async {
      RequestOptions? capturedRequest;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedRequest = options;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 201,
                  data: const {'recorded': 1},
                ),
              );
            },
          ),
        );
      final api = MobileApi(dio: dio);
      final points = [
        {
          'client_id': 'point-1',
          'latitude': -22.9,
          'longitude': -43.2,
          'test_mode': false,
        },
      ];

      final response = await api.uploadStreetCardRoutePoints(
        token: 'session-token',
        congregationId: 7,
        streetCardId: 18,
        points: points,
      );

      expect(response['recorded'], 1);
      expect(capturedRequest?.method, 'POST');
      expect(capturedRequest?.path, '/mobile/street-cards/18/route-points');
      expect(capturedRequest?.headers['X-Congregation-ID'], '7');
      expect((capturedRequest?.data as Map)['points'], points);
    });

    test('searches card names and streets without accent sensitivity', () {
      final card = StreetCardSummary.fromJson({
        'id': 8,
        'code': 'R.04',
        'name': 'Jardim das Flores',
        'description': 'Trechos próximos à praça principal.',
        'neighborhood': 'São José',
        'group': 'Grupo Centro',
        'streets_count': 3,
        'entrances_count': 12,
        'street_names': ['Rua São Pedro', 'Avenida Central'],
      });

      expect(card.streetNames, ['Rua São Pedro', 'Avenida Central']);
      expect(card.description, 'Trechos próximos à praça principal.');
      expect(card.matchesFilters(searchQuery: 'sao pedro'), isTrue);
      expect(card.matchesFilters(searchQuery: 'jardim flores'), isTrue);
      expect(card.matchesFilters(searchQuery: 'praca principal'), isTrue);
      expect(
        card.matchesFilters(
          searchQuery: 'avenida central',
          neighborhoodFilter: 'Sao Jose',
          groupFilter: 'grupo centro',
        ),
        isTrue,
      );
      expect(
        card.matchesFilters(
          neighborhoodFilter: 'Centro',
          groupFilter: 'Grupo Centro',
        ),
        isFalse,
      );
      expect(card.matchesFilters(searchQuery: 'rua inexistente'), isFalse);
    });

    test('keeps compatibility with summaries without street names', () {
      final card = StreetCardSummary.fromJson({
        'id': 9,
        'code': 'R.05',
        'name': 'Centro',
        'streets_count': 1,
        'entrances_count': 2,
      });

      expect(card.streetNames, isEmpty);
      expect(card.matchesFilters(searchQuery: 'centro'), isTrue);
    });
  });

  testWidgets('dashboard shows today outings and reachable territory cards', (
    tester,
  ) async {
    final openedStreetCardIds = <int>[];
    final today = DateTime.now();
    final todayDate =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final currentMonth =
        '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final appState = MobileAppState(
      selectedCongregationId: 1,
      canViewStreetCards: true,
      canViewFieldOutings: true,
      streetCards: [
        StreetCardSummary.fromJson({
          'id': 22,
          'code': 'R.14',
          'name': 'Rua Principal',
          'neighborhood': 'Centro',
          'group': 'Centro',
          'origin_territory_id': 14,
          'streets_count': 1,
          'entrances_count': 4,
        }),
      ],
      fieldCalendar: FieldCalendarData.fromJson({
        'month': currentMonth,
        'outings': [
          {
            'id': 12,
            'date': todayDate,
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
              'maps_url': '',
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileAppControllerProvider.overrideWith(
            () => _FakeMobileAppController(appState),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) => ref
                .watch(mobileAppControllerProvider)
                .when(
                  data: (_) => DashboardScreen(
                    onNavigate: (_) {},
                    onOpenStreetCard: (card) =>
                        openedStreetCardIds.add(card.id),
                    onOpenCircuitOverview: () {},
                  ),
                  error: (error, stackTrace) => Text('$error'),
                  loading: () => const SizedBox.shrink(),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saídas de campo hoje'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('Praça Central'), findsOneWidget);
    expect(find.text('T.14 · Jardim Primavera'), findsOneWidget);
    expect(
      find.text('Abrir cartão de rua · R.14 · Rua Principal'),
      findsOneWidget,
    );

    await tester.tap(find.text('Praça Central'));
    await tester.pumpAndSettle();

    expect(openedStreetCardIds, [22]);
  });

  testWidgets('dashboard asks which street card to open when several match', (
    tester,
  ) async {
    final today = DateTime.now();
    final month = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final openedStreetCardIds = <int>[];
    final appState = MobileAppState(
      selectedCongregationId: 1,
      canViewStreetCards: true,
      canViewFieldOutings: true,
      streetCards: [
        StreetCardSummary(
          id: 22,
          code: 'R.14',
          name: 'Rua Principal',
          neighborhood: 'Centro',
          group: 'Centro',
          streetsCount: 1,
          entrancesCount: 4,
          originTerritoryId: 14,
        ),
        StreetCardSummary(
          id: 23,
          code: 'R.15',
          name: 'Rua das Flores',
          neighborhood: 'Centro',
          group: 'Centro',
          streetsCount: 2,
          entrancesCount: 8,
          originTerritoryId: 14,
        ),
      ],
      fieldCalendar: FieldCalendarData(
        month: month,
        outings: [
          FieldOuting(
            id: 12,
            date: today,
            time: '09:00',
            leader: 'Ana Silva',
            notes: '',
            allGroups: false,
            groups: const [],
            situation: 'pendente',
            situationLabel: 'Pendente',
            territoryCards: const [
              FieldOutingTerritoryCard(
                id: 14,
                code: 'T.14',
                name: 'Jardim Primavera',
              ),
            ],
            location: const FieldLocation(
              id: 8,
              name: 'Praça Central',
              address: 'Rua Principal',
              mapsUrl: '',
            ),
          ),
        ],
        patterns: const [],
        locations: const [],
        groups: const [],
        leaders: const [],
        canManage: false,
        canManageLocations: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileAppControllerProvider.overrideWith(
            () => _FakeMobileAppController(appState),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) => ref
                .watch(mobileAppControllerProvider)
                .when(
                  data: (_) => DashboardScreen(
                    onNavigate: (_) {},
                    onOpenStreetCard: (card) =>
                        openedStreetCardIds.add(card.id),
                    onOpenCircuitOverview: () {},
                  ),
                  error: (error, stackTrace) => Text('$error'),
                  loading: () => const SizedBox.shrink(),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Praça Central'));
    await tester.pumpAndSettle();

    expect(find.text('Escolha o cartão de rua'), findsOneWidget);
    expect(find.text('R.14 · Rua Principal'), findsOneWidget);
    expect(find.text('R.15 · Rua das Flores'), findsOneWidget);
    await tester.tap(find.text('R.15 · Rua das Flores'));
    await tester.pumpAndSettle();

    expect(openedStreetCardIds, [23]);
  });

  testWidgets('field outing shows its location, groups, map link, and cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final todayDate =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final currentMonth =
        '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final appState = MobileAppState(
      selectedCongregationId: 1,
      canViewFieldOutings: true,
      fieldCalendar: FieldCalendarData.fromJson({
        'month': currentMonth,
        'outings': [
          {
            'id': 12,
            'date': todayDate,
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileAppControllerProvider.overrideWith(
            () => _FakeMobileAppController(appState),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) => ref
                .watch(mobileAppControllerProvider)
                .when(
                  data: (_) => const FieldOutingsScreen(),
                  error: (error, stackTrace) => Text('$error'),
                  loading: () => const SizedBox.shrink(),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Praça Central'), findsOneWidget);
    expect(find.text('Rua Principal'), findsOneWidget);
    expect(find.text('Ver no mapa'), findsOneWidget);
    expect(find.text('Centro'), findsOneWidget);
    expect(find.text('T.14 · Jardim Primavera'), findsOneWidget);
  });

  testWidgets(
    'bottom navigation keeps every label visible with a short home label',
    (tester) async {
      final appState = MobileAppState(
        selectedCongregationId: 1,
        canViewFieldOutings: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mobileAppControllerProvider.overrideWith(
              () => _FakeMobileAppController(appState),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) => ref
                  .watch(mobileAppControllerProvider)
                  .when(
                    data: (_) => const MapScreen(),
                    error: (error, stackTrace) => Text('$error'),
                    loading: () => const SizedBox.shrink(),
                  ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

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
    },
  );

  testWidgets('login explains when location permission is requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: LoginScreen(state: const MobileAppState())),
      ),
    );

    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(
      find.textContaining(
        'A localização será solicitada somente quando você tocar em “Minha localização” ou iniciar um trajeto.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('point form defaults to Não bater and saves the position', (
    tester,
  ) async {
    final saved = <Map<String, Object?>>[];
    final appState = MobileAppState(
      selectedCongregationId: 1,
      canManageMapPoints: true,
      mapPointTypes: const [
        MapPointType(id: 4, name: 'Igreja', color: Color(0xFF8A2580)),
        MapPointType(
          id: 5,
          name: 'Não bater',
          color: Color(0xFFC0392B),
          icon: '🚫',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileAppControllerProvider.overrideWith(
            () => _PointSavingController(appState, saved),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MapPointFormSheet(position: LatLng(-22.9, -43.2)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adicionar ponto'), findsOneWidget);
    expect(find.text('Remover ponto'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('map-point-title')),
      'Casa azul',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('map-point-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-point-save')));
    await tester.pumpAndSettle();

    expect(saved.single['type_id'], 5);
    expect(saved.single['title'], 'Casa azul');
    expect(saved.single['latitude'], -22.9);
  });

  testWidgets('point details hide edit and remove without permission', (
    tester,
  ) async {
    final appState = MobileAppState(selectedCongregationId: 1);
    const point = MapPoint(
      id: 1,
      position: LatLng(-22.9, -43.2),
      title: 'Casa azul',
      address: '',
      type: 'Não bater',
      color: Color(0xFFC0392B),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileAppControllerProvider.overrideWith(
            () => _FakeMobileAppController(appState),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MapPointDetailsSheet(point: point)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Casa azul'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-point-edit')), findsNothing);
    expect(find.byKey(const ValueKey('map-point-remove')), findsNothing);
  });
}

class _PointSavingController extends _FakeMobileAppController {
  _PointSavingController(super.initialState, this.saved);

  final List<Map<String, Object?>> saved;

  @override
  Future<void> saveMapPoint(Map<String, Object?> data, {int? pointId}) async {
    saved.add(data);
  }
}

class _FakeMobileAppController extends MobileAppController {
  _FakeMobileAppController(this.initialState);

  final MobileAppState initialState;

  @override
  Future<MobileAppState> build() async => initialState;
}

Map<String, dynamic> _territoryJson({
  required String type,
  required List<dynamic> coordinates,
}) => {
  'id': 1,
  'code': '01',
  'name': 'Território de teste',
  'situation': 'disponivel',
  'geometry': {'type': type, 'coordinates': coordinates},
  'route_recording': {'permitido': true, 'motivo': ''},
};

StreetRecordedRoute _recordedRoute(String id, int userId, String startedAt) =>
    StreetRecordedRoute.fromJson({
      'id': id,
      'user_id': userId,
      'nome': 'Publicador $userId',
      'is_test': false,
      'cor': '#1A73E8',
      'started_at': startedAt,
      'ended_at': startedAt,
      'point_count': 2,
      'coordinates': const [],
    });
