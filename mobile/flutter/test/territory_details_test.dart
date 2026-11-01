import 'package:cartas/models/mobile_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TerritoryDetails interpreta o envelope completo', () {
    final details = TerritoryDetails.fromJson({
      'territory': {
        'id': 7,
        'code': 'A-12',
        'name': 'Centro',
        'situation': 'concluido',
        'group': 'Grupo 2',
        'situation_label': 'Concluído',
        'opened_at': '2026-09-01',
        'concluded_at': '2026-10-05',
        'concluded_by': 'Maria S.',
        'forced_completion': true,
        'completion_note': 'Encerrado pelo superintendente',
        'locations': [
          {
            'id': 1,
            'name': 'Rua A',
            'address': null,
            'neighborhood': 'Corrêas',
            'worked': true,
          },
        ],
        'cycles': [
          {'opened_at': '2026-09-01', 'closed_at': null, 'concluded_by': null},
        ],
        'recent_passes': [
          {
            'date': '2026-09-10',
            'outing_id': null,
            'publisher': 'João P.',
            'outing_leader': null,
            'location': 'Rua A',
          },
        ],
      },
    });

    expect(details.title, 'A-12 · Centro');
    expect(formatDatePtBr(details.concludedAt), '05/10/2026');
    expect(details.forcedCompletion, isTrue);
    expect(details.completionNote, 'Encerrado pelo superintendente');
    expect(details.locations.single.worked, isTrue);
    expect(details.locations.single.address, '');
    expect(details.cycles.single.closedAt, isNull);
    expect(details.recentPasses.single.publisher, 'João P.');
    expect(details.recentPasses.single.outingId, isNull);
  });

  test('TerritoryDetails tolera servidores antigos sem os novos campos', () {
    final details = TerritoryDetails.fromJson({
      'id': 3,
      'code': 'B',
      'situation': 'em_andamento',
    });
    expect(details.displaySituation, 'Em andamento');
    expect(details.openedAt, isNull);
    expect(details.locations, isEmpty);
    expect(formatDatePtBr(null), '—');
  });

  test('StreetCardDetail expõe territory_details quando presente', () {
    final card = <String, dynamic>{'id': 1, 'code': 'C1', 'name': 'Cartão'};
    expect(
      StreetCardDetail.fromJson({'street_card': card}).territoryDetails,
      isNull,
    );
    final withDetails = StreetCardDetail.fromJson({
      'street_card': {
        ...card,
        'territory_details': {'id': 1, 'code': 'C1', 'situation': 'disponivel'},
      },
    });
    expect(withDetails.territoryDetails?.code, 'C1');
  });

  test('Territory lê situação e datas e mantém rótulo local como reserva', () {
    final base = <String, dynamic>{
      'id': 5,
      'code': 'T',
      'name': 'N',
      'situation': 'em_andamento',
      'geometry': {'type': 'Polygon', 'coordinates': []},
    };
    expect(Territory.fromJson(base).situationLabel, 'Em andamento');
    final territory = Territory.fromJson({
      ...base,
      'situation_label': 'Em andamento (rótulo)',
      'opened_at': '2026-10-01',
      'concluded_by': '  ',
    });
    expect(territory.situationLabel, 'Em andamento (rótulo)');
    expect(formatDatePtBr(territory.openedAt), '01/10/2026');
    expect(territory.concludedBy, isNull);
  });

  test('CardSuggestions interpreta sugestões e regiões do dirigente', () {
    final data = CardSuggestions.fromJson({
      'suggestions': [
        {
          'card_id': 9,
          'code': 'X1',
          'name': 'Praça',
          'group': null,
          'last_concluded_at': null,
          'days_without_conclusion': null,
          'near_region': 'Corrêas',
          'distance_km': 1,
          'reason': 'Nunca concluído',
        },
        {'card_id': 10, 'code': 'X2', 'name': '', 'days_without_conclusion': 1},
      ],
      'leader_regions': [
        {'weekday': 6, 'neighborhood': 'Corrêas'},
        {'weekday': null, 'neighborhood': 'Centro'},
        {'weekday': 2, 'neighborhood': 'Itaipava'},
      ],
    });

    expect(data.suggestions.first.idleLabel, 'nunca concluído');
    expect(data.suggestions.first.nearRegion, 'Corrêas');
    expect(data.suggestions.first.distanceKm, 1.0);
    expect(data.suggestions.last.idleLabel, 'sem concluir há 1 dia');
    expect(data.regionsForWeekday(6), ['Corrêas', 'Centro']);
    expect(CardSuggestions.fromJson(const {}).suggestions, isEmpty);
  });
}
