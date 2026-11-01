import 'package:flutter_test/flutter_test.dart';
import 'package:cartas/models/mobile_models.dart';

void main() {
  group('Territory completeness and filters', () {
    final territories = [
      _territory(
        id: 1,
        code: 'T.01',
        name: 'Centro',
        situation: 'disponivel',
        group: 'Nogueira',
        worked: 0,
        total: 5,
      ),
      _territory(
        id: 2,
        code: 'T.02',
        name: 'Jardim Primavera',
        situation: 'em_andamento',
        group: 'Águas Lindas',
        worked: 3,
        total: 4,
      ),
      _territory(
        id: 3,
        code: 'T.03',
        name: 'Vila Nova',
        situation: 'concluido',
        group: 'Nogueira',
        worked: 8,
        total: 8,
        forced: true,
        canTest: true,
        testPoints: 12,
      ),
    ];

    test('retains legacy status values for historical consultation', () {
      expect(territories.every((territory) => territory.isLegacy), isTrue);
      expect(territories.map((territory) => territory.situation), [
        'disponivel',
        'em_andamento',
        'concluido',
      ]);
      expect(territories.last.forcedCompletion, isTrue);
    });

    test(
      'keeps every territory visible without filters and reports coverage',
      () {
        expect(filterTerritories(territories: territories), hasLength(3));
        expect(territories.map((territory) => territory.coveragePercent), [
          0,
          75,
          100,
        ]);
        expect(territories.last.forcedCompletion, isTrue);
        expect(territories.last.canTestRoute, isTrue);
        expect(territories.last.testRoutePointsCount, 12);
      },
    );

    test('search ignores accents and matches code, territory and group', () {
      expect(
        filterTerritories(territories: territories, searchQuery: 'aguas'),
        [territories[1]],
      );
      expect(
        filterTerritories(territories: territories, searchQuery: 'jardim'),
        [territories[1]],
      );
      expect(filterTerritories(territories: territories, searchQuery: 't.03'), [
        territories[2],
      ]);
    });

    test('combines status, group and free-text filters', () {
      expect(
        filterTerritories(
          territories: territories,
          situation: 'concluido',
          group: 'nogueira',
          searchQuery: 'vila',
        ),
        [territories[2]],
      );
      expect(
        filterTerritories(territories: territories, situation: 'concluido'),
        [territories[2]],
      );
    });

    test('clamps inconsistent API coverage to valid limits', () {
      final territory = _territory(
        id: 4,
        code: 'T.04',
        name: 'Teste',
        situation: 'em_andamento',
        worked: 9,
        total: 2,
        coverage: 140,
      );

      expect(territory.workedPlaces, 2);
      expect(territory.coveragePercent, 100);
    });
  });
}

Territory _territory({
  required int id,
  required String code,
  required String name,
  required String situation,
  String? group,
  int worked = 0,
  int total = 0,
  int? coverage,
  bool forced = false,
  bool canTest = false,
  int testPoints = 0,
}) => Territory.fromJson({
  'id': id,
  'legacy': true,
  'code': code,
  'name': name,
  'situation': situation,
  'group': group,
  'geometry': {
    'type': 'Polygon',
    'coordinates': [
      [
        [-43.2, -22.4],
        [-43.1, -22.4],
        [-43.1, -22.3],
        [-43.2, -22.3],
        [-43.2, -22.4],
      ],
    ],
  },
  'worked_places': worked,
  'total_places': total,
  'coverage_percent':
      coverage ?? (total == 0 ? 0 : (worked / total * 100).round()),
  'forced_completion': forced,
  'can_test_route': canTest,
  'test_route_points_count': testPoints,
  'route_recording': {'permitido': false, 'motivo': 'Fora do horário'},
});
