/// Modelos do acompanhamento do território no app: cobertura por ano de
/// serviço, cartões em aberto, S-13-T e disponibilidade dos dirigentes.
library;

double _number(Object? value) => value is num ? value.toDouble() : 0;

int _integer(Object? value) => value is num ? value.toInt() : 0;

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _texts(Object? value) =>
    (value as List? ?? const []).whereType<String>().toList(growable: false);

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map(Map<String, dynamic>.from)
    .toList(growable: false);

/// Estados de um cartão no ano de serviço (os mesmos três da web).
enum CoverageState {
  pending('nao_trabalhado', 'Pendente'),
  inProgress('em_andamento', 'Em andamento'),
  done('concluido', 'Concluído');

  const CoverageState(this.key, this.label);

  final String key;
  final String label;

  static CoverageState fromKey(String? key) => CoverageState.values.firstWhere(
    (state) => state.key == key,
    orElse: () => CoverageState.pending,
  );
}

/// Cartões e km por estado.
class CoverageBucket {
  const CoverageBucket({
    required this.cards,
    required this.km,
    required this.percentKm,
  });

  final int cards;
  final double km;
  final double percentKm;

  factory CoverageBucket.fromJson(Map<String, dynamic> json) => CoverageBucket(
    cards: _integer(json['cartoes']),
    km: _number(json['km']),
    percentKm: _number(json['pct_km']),
  );
}

/// Linha das tabelas por grupo, tipo ou bairro.
class CoverageBreakdownRow {
  const CoverageBreakdownRow({
    required this.label,
    required this.total,
    required this.done,
    required this.percentDone,
    required this.kmLeft,
  });

  final String label;
  final int total;
  final int done;
  final double percentDone;
  final double kmLeft;

  factory CoverageBreakdownRow.fromJson(Map<String, dynamic> json) =>
      CoverageBreakdownRow(
        label: _text(json['rotulo']) ?? 'Sem nome',
        total: _integer(json['total']),
        done: _integer(json['concluido']),
        percentDone: _number(json['pct_concluido']),
        kmLeft: _number(json['km_restante']),
      );
}

/// Cartão de uma das colunas do quadro de acompanhamento.
class CoverageBoardItem {
  const CoverageBoardItem({
    required this.cardId,
    required this.code,
    required this.name,
    required this.state,
    required this.km,
    this.neighborhood,
    this.reference,
    this.daysIdle,
    this.daysWorked = 0,
    this.startedAt,
    this.pendency,
  });

  final int cardId;
  final String code;
  final String name;
  final String? neighborhood;
  final CoverageState state;
  final double km;

  /// Data mais recente entre o último trabalho e a última conclusão.
  final String? reference;
  final int? daysIdle;
  final int daysWorked;
  final String? startedAt;

  /// 'sem_registro' (em andamento sem passagem) ou 'andamento'.
  final String? pendency;

  String get title => name.isEmpty ? code : '$code · $name';

  factory CoverageBoardItem.fromJson(Map<String, dynamic> json) =>
      CoverageBoardItem(
        cardId: _integer(json['cartao_id']),
        code: _text(json['codigo']) ?? '',
        name: _text(json['nome']) ?? '',
        neighborhood: _text(json['bairro']),
        state: CoverageState.fromKey(json['estado'] as String?),
        km: _number(json['km']),
        reference: _text(json['referencia']),
        daysIdle: json['dias_sem_atividade'] is num
            ? (json['dias_sem_atividade'] as num).toInt()
            : null,
        daysWorked: _integer(json['dias_trabalhados']),
        startedAt: _text(json['iniciado_em']),
        pendency: _text(json['pendencia']),
      );
}

/// As quatro colunas do quadro, calculadas por regra no servidor.
class CoverageBoard {
  const CoverageBoard({
    required this.weekday,
    required this.weekend,
    required this.oldest,
    required this.unfinished,
    required this.idleLimitDays,
  });

  final List<CoverageBoardItem> weekday;
  final List<CoverageBoardItem> weekend;
  final List<CoverageBoardItem> oldest;
  final List<CoverageBoardItem> unfinished;
  final int idleLimitDays;

  factory CoverageBoard.fromJson(Map<String, dynamic> json) {
    List<CoverageBoardItem> items(String key) =>
        _maps(json[key])
            .map(CoverageBoardItem.fromJson)
            .toList(growable: false);
    return CoverageBoard(
      weekday: items('meio_semana'),
      weekend: items('fim_de_semana'),
      oldest: items('mais_antigos'),
      unfinished: items('fechamento'),
      idleLimitDays: _integer(json['limite_dias_sem_atividade']),
    );
  }
}

/// Dados completos de um cartão para o painel de detalhes da cobertura.
class CoverageCard {
  const CoverageCard({
    required this.cardId,
    required this.code,
    required this.name,
    required this.state,
    required this.km,
    required this.streets,
    required this.assignments,
    this.neighborhood,
    this.group,
    this.type,
    this.lastWorkAt,
    this.completedAt,
    this.lastCompletionAt,
    this.startedAt,
    this.daysWorked = 0,
    this.forced = false,
  });

  final int cardId;
  final String code;
  final String name;
  final String? neighborhood;
  final String? group;
  final String? type;
  final CoverageState state;
  final double km;
  final String? lastWorkAt;
  final String? completedAt;
  final String? lastCompletionAt;
  final String? startedAt;
  final int daysWorked;
  final bool forced;
  final List<String> streets;
  final List<CoverageAssignment> assignments;

  String get title => name.isEmpty ? code : '$code · $name';

  factory CoverageCard.fromJson(Map<String, dynamic> json) => CoverageCard(
    cardId: _integer(json['cartao_id']),
    code: _text(json['codigo']) ?? '',
    name: _text(json['nome']) ?? '',
    neighborhood: _text(json['bairro']),
    group: _text(json['grupo']),
    type: _text(json['tipo']),
    state: CoverageState.fromKey(json['estado'] as String?),
    km: _number(json['km']),
    lastWorkAt: _text(json['ultimo_trabalho_em']),
    completedAt: _text(json['concluido_em']),
    lastCompletionAt: _text(json['ultima_conclusao']),
    startedAt: _text(json['iniciado_em']),
    daysWorked: _integer(json['dias_trabalhados']),
    forced: json['conclusao_forcada'] == true,
    streets: _texts(json['ruas']),
    assignments: _maps(json['ciclos'])
        .map(CoverageAssignment.fromJson)
        .toList(growable: false),
  );
}

class CoverageAssignment {
  const CoverageAssignment({this.publisher, this.assignedAt, this.completedAt});

  final String? publisher;
  final String? assignedAt;
  final String? completedAt;

  factory CoverageAssignment.fromJson(Map<String, dynamic> json) =>
      CoverageAssignment(
        publisher: _text(json['publicador']),
        assignedAt: _text(json['designado_em']),
        completedAt: _text(json['concluido_em']),
      );
}

/// Cobertura do território no ano de serviço.
class CoverageData {
  const CoverageData({
    required this.year,
    required this.currentYear,
    required this.totalCards,
    required this.done,
    required this.inProgress,
    required this.pending,
    required this.totalKm,
    required this.kmLeft,
    required this.perWeek,
    required this.board,
    required this.byGroup,
    required this.byType,
    required this.byNeighborhood,
    required this.cards,
    required this.alerts,
    this.forecastDate,
    this.notice,
  });

  final int year;
  final int currentYear;
  final int totalCards;
  final CoverageBucket done;
  final CoverageBucket inProgress;
  final CoverageBucket pending;
  final double totalKm;
  final double kmLeft;
  final double perWeek;
  final String? forecastDate;
  final String? notice;
  final CoverageBoard board;
  final List<CoverageBreakdownRow> byGroup;
  final List<CoverageBreakdownRow> byType;
  final List<CoverageBreakdownRow> byNeighborhood;
  final List<CoverageCard> cards;
  final List<String> alerts;

  /// Cartões iniciados e ainda sem conclusão: o indicador "iniciados sem
  /// finalizar", para conferir se faltou marcar como concluído.
  int get unfinishedCount => board.unfinished.length;

  CoverageCard? cardById(int id) {
    for (final card in cards) {
      if (card.cardId == id) return card;
    }
    return null;
  }

  factory CoverageData.fromJson(Map<String, dynamic> json) {
    final byState = Map<String, dynamic>.from(
      json['por_estado'] as Map? ?? const {},
    );
    CoverageBucket bucket(String key) => CoverageBucket.fromJson(
      Map<String, dynamic>.from(byState[key] as Map? ?? const {}),
    );
    final km = Map<String, dynamic>.from(json['km'] as Map? ?? const {});
    final pace = Map<String, dynamic>.from(json['ritmo'] as Map? ?? const {});
    final forecast = Map<String, dynamic>.from(
      json['previsao'] as Map? ?? const {},
    );
    List<CoverageBreakdownRow> rows(String key) =>
        _maps(json[key])
            .map(CoverageBreakdownRow.fromJson)
            .toList(growable: false);
    return CoverageData(
      year: _integer(json['ano_servico']),
      currentYear: _integer(json['current_year']),
      totalCards: _integer(json['total_cartoes']),
      done: bucket('concluido'),
      inProgress: bucket('em_andamento'),
      pending: bucket('nao_trabalhado'),
      totalKm: _number(km['total']),
      kmLeft: _number(km['restante']),
      perWeek: _number(pace['cartoes_por_semana']),
      forecastDate: _text(forecast['data']),
      notice: _text(json['aviso']),
      board: CoverageBoard.fromJson(
        Map<String, dynamic>.from(json['quadro'] as Map? ?? const {}),
      ),
      byGroup: rows('por_grupo'),
      byType: rows('por_tipo'),
      byNeighborhood: rows('por_bairro'),
      cards: _maps(json['cartoes'])
          .map(CoverageCard.fromJson)
          .toList(growable: false),
      alerts: _texts(json['alertas']),
    );
  }
}

/// Cartão ainda não concluído no ano de serviço (tela "Em aberto").
class OpenCard {
  const OpenCard({
    required this.id,
    required this.code,
    required this.name,
    required this.state,
    required this.weekend,
    required this.km,
    required this.streets,
    required this.workedStreets,
    required this.daysWorked,
    this.neighborhood,
    this.startedAt,
    this.lastWorkAt,
    this.lastCompletionAt,
  });

  final int id;
  final String code;
  final String name;
  final String? neighborhood;
  final CoverageState state;
  final bool weekend;
  final double km;
  final int daysWorked;
  final String? startedAt;
  final String? lastWorkAt;
  final String? lastCompletionAt;
  final List<String> streets;
  final List<String> workedStreets;

  String get title => name.isEmpty ? code : '$code · $name';

  double get progress =>
      streets.isEmpty ? 0 : workedStreets.length / streets.length;

  /// Texto de busca sem acentos, para filtrar por código, bairro ou rua.
  String get searchText => [
    code,
    code.replaceAll('.', ''),
    name,
    neighborhood ?? '',
    ...streets,
  ].join(' ').toLowerCase();

  factory OpenCard.fromJson(Map<String, dynamic> json) => OpenCard(
    id: _integer(json['id']),
    code: _text(json['code']) ?? '',
    name: _text(json['name']) ?? '',
    neighborhood: _text(json['neighborhood']),
    state: CoverageState.fromKey(json['state'] as String?),
    weekend: json['weekend'] == true,
    km: _number(json['km']),
    daysWorked: _integer(json['days_worked']),
    startedAt: _text(json['started_at']),
    lastWorkAt: _text(json['last_work_at']),
    lastCompletionAt: _text(json['last_completion_at']),
    streets: _texts(json['streets']),
    workedStreets: _texts(json['worked_streets']),
  );
}

class S13Assignment {
  const S13Assignment({this.publisher, this.assignedAt, this.completedAt});

  final String? publisher;
  final String? assignedAt;
  final String? completedAt;

  factory S13Assignment.fromJson(Map<String, dynamic> json) => S13Assignment(
    publisher: _text(json['publisher']),
    assignedAt: _text(json['assigned_at']),
    completedAt: _text(json['completed_at']),
  );
}

class S13Row {
  const S13Row({
    required this.number,
    required this.place,
    required this.continuation,
    required this.assignments,
    this.lastCompletion,
  });

  final String number;
  final String place;
  final bool continuation;
  final String? lastCompletion;
  final List<S13Assignment> assignments;

  factory S13Row.fromJson(Map<String, dynamic> json) => S13Row(
    number: _text(json['number']) ?? '',
    place: _text(json['place']) ?? '',
    continuation: json['continuation'] == true,
    lastCompletion: _text(json['last_completion']),
    assignments: _maps(json['assignments'])
        .map(S13Assignment.fromJson)
        .toList(growable: false),
  );
}

/// Folha do S-13-T de um ano de serviço.
class S13Sheet {
  const S13Sheet({required this.year, required this.years, required this.rows});

  final int year;
  final List<int> years;
  final List<S13Row> rows;

  factory S13Sheet.fromJson(Map<String, dynamic> json) => S13Sheet(
    year: _integer(json['year']),
    years: (json['years'] as List? ?? const [])
        .whereType<num>()
        .map((year) => year.toInt())
        .toList(growable: false),
    rows: _maps(json['rows']).map(S13Row.fromJson).toList(growable: false),
  );
}

/// Dirigente e os dias/períodos ("6:manha") em que pode dirigir saída.
class LeaderAvailability {
  const LeaderAvailability({
    required this.id,
    required this.name,
    required this.slots,
  });

  final int id;
  final String name;
  final Set<String> slots;

  LeaderAvailability withSlots(Set<String> value) =>
      LeaderAvailability(id: id, name: name, slots: value);

  factory LeaderAvailability.fromJson(Map<String, dynamic> json) =>
      LeaderAvailability(
        id: _integer(json['id']),
        name: _text(json['name']) ?? '',
        slots: _texts(json['slots']).toSet(),
      );
}

class LeadersAvailabilityData {
  const LeadersAvailabilityData({
    required this.enabled,
    required this.weekdays,
    required this.periods,
    required this.leaders,
  });

  final bool enabled;
  final List<String> weekdays;
  final List<String> periods;
  final List<LeaderAvailability> leaders;

  factory LeadersAvailabilityData.fromJson(Map<String, dynamic> json) =>
      LeadersAvailabilityData(
        enabled: json['enabled'] == true,
        weekdays: _texts(json['weekdays']),
        periods: _texts(json['periods']),
        leaders: _maps(json['leaders'])
            .map(LeaderAvailability.fromJson)
            .toList(growable: false),
      );
}
