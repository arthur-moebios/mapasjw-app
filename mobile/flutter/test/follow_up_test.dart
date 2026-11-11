import 'package:flutter_test/flutter_test.dart';

import 'package:cartas/models/follow_up.dart';
import 'package:cartas/models/outing_work.dart';

Map<String, dynamic> _board(String code, String state, {String? pendency}) => {
  'cartao_id': 1,
  'codigo': code,
  'nome': 'Nogueira — Rua A',
  'estado': state,
  'km': 1.5,
  'referencia': '2026-09-10',
  'dias_sem_atividade': 62,
  'dias_trabalhados': 2,
  'iniciado_em': '2026-09-08',
  'pendencia': pendency,
};

void main() {
  test('cobertura: estados, quadro e iniciados sem finalizar', () {
    final data = CoverageData.fromJson({
      'ano_servico': 2027,
      'current_year': 2027,
      'total_cartoes': 110,
      'por_estado': {
        'concluido': {'cartoes': 48, 'km': 80.5, 'pct_km': 40.2},
        'em_andamento': {'cartoes': 14, 'km': 20.0, 'pct_km': 10.0},
        'nao_trabalhado': {'cartoes': 48, 'km': 100.0, 'pct_km': 49.8},
      },
      'km': {'total': 200.5, 'restante': 120.0},
      'ritmo': {'cartoes_por_semana': 1.5},
      'previsao': {'data': '2027-03-01'},
      'quadro': {
        'meio_semana': [_board('1.001', 'em_andamento')],
        'fim_de_semana': [_board('9.001', 'nao_trabalhado')],
        'mais_antigos': [_board('2.001', 'nao_trabalhado')],
        'fechamento': [
          _board('3.001', 'em_andamento', pendency: 'sem_registro'),
        ],
        'limite_dias_sem_atividade': 30,
      },
      'por_grupo': [
        {
          'rotulo': 'Sem grupo',
          'total': 49,
          'concluido': 18,
          'pct_concluido': 36.7,
          'km_restante': 55.1,
        },
      ],
      'cartoes': [
        {
          'cartao_id': 1,
          'codigo': '1.001',
          'nome': 'Nogueira',
          'estado': 'concluido',
          'km': 2,
          'conclusao_forcada': true,
          'ruas': ['Rua A', 'Rua B'],
          'ciclos': [
            {
              'publicador': 'Fulano',
              'designado_em': '2026-09-01',
              'concluido_em': null,
            },
          ],
        },
      ],
      'alertas': ['3 cartões sem atividade'],
    });

    expect(data.year, 2027);
    expect(data.done.cards, 48);
    expect(data.done.percentKm, closeTo(40.2, .001));
    expect(data.inProgress.cards, 14);
    expect(data.pending.cards, 48);
    expect(data.unfinishedCount, 1);
    expect(data.board.unfinished.single.pendency, 'sem_registro');
    expect(data.board.unfinished.single.state, CoverageState.inProgress);
    expect(data.board.weekend.single.state, CoverageState.pending);
    expect(data.board.idleLimitDays, 30);
    expect(data.byGroup.single.done, 18);
    expect(data.alerts, ['3 cartões sem atividade']);

    final card = data.cardById(1)!;
    expect(card.state, CoverageState.done);
    expect(card.forced, isTrue);
    expect(card.streets, ['Rua A', 'Rua B']);
    expect(card.assignments.single.completedAt, isNull);
    expect(data.cardById(99), isNull);
  });

  test('estados desconhecidos viram pendente (vermelho)', () {
    expect(CoverageState.fromKey('qualquer'), CoverageState.pending);
    expect(CoverageState.fromKey('em_andamento'), CoverageState.inProgress);
    expect(CoverageState.fromKey('concluido').label, 'Concluído');
  });

  test('cartão em aberto: progresso e texto de busca', () {
    final card = OpenCard.fromJson({
      'id': 5,
      'code': '4.005',
      'name': 'Nogueira — Rua Piauí e Rua Amazonas',
      'neighborhood': 'Nogueira',
      'state': 'em_andamento',
      'weekend': false,
      'km': 1.0,
      'days_worked': 1,
      'streets': ['Rua Piauí', 'Rua Amazonas'],
      'worked_streets': ['Rua Piauí'],
    });
    expect(card.progress, .5);
    expect(card.title, '4.005 · Nogueira — Rua Piauí e Rua Amazonas');
    expect(card.searchText, contains('4005'));
    expect(card.searchText, contains('rua amazonas'));
    expect(
      OpenCard.fromJson({'id': 1, 'code': '1.001', 'streets': <String>[]})
          .progress,
      0,
    );
  });

  test('S-13 e disponibilidade', () {
    final sheet = S13Sheet.fromJson({
      'year': 2026,
      'years': [2027, 2026],
      'rows': [
        {
          'number': '1.001',
          'place': 'Salão do Reino',
          'continuation': false,
          'last_completion': '2025-04-26',
          'assignments': [
            {
              'publisher': 'PAULO',
              'assigned_at': '2025-09-14',
              'completed_at': '2025-09-27',
            },
          ],
        },
      ],
    });
    expect(sheet.years, [2027, 2026]);
    expect(sheet.rows.single.assignments.single.publisher, 'PAULO');
    expect(sheet.rows.single.lastCompletion, '2025-04-26');

    final leaders = LeadersAvailabilityData.fromJson({
      'enabled': true,
      'weekdays': ['domingo', 'segunda'],
      'periods': ['manha', 'tarde', 'noite'],
      'leaders': [
        {
          'id': 3,
          'name': 'ALEX',
          'slots': ['0:manha', '6:tarde'],
        },
      ],
    });
    expect(leaders.enabled, isTrue);
    final alex = leaders.leaders.single;
    expect(alex.slots, {'0:manha', '6:tarde'});
    expect(alex.withSlots({'1:noite'}).slots, {'1:noite'});
    expect(alex.slots.length, 2);
  });

  test('rua já trabalhada vem marcada no contrato de trabalho', () {
    final street = OutingWorkStreet.fromJson({
      'name': 'Rua A',
      'meters': 0,
      'worked': true,
      'lines': [
        [
          [-22.4, -43.1],
          [-22.41, -43.11],
        ],
      ],
    });
    expect(street.worked, isTrue);
    expect(OutingWorkStreet.fromJson({'name': 'B'}).worked, isFalse);
  });
}
