import 'package:latlong2/latlong.dart';

/// Rua de um cartão de rua, com as linhas para desenhar no mapa.
class OutingWorkStreet {
  const OutingWorkStreet({
    required this.name,
    required this.meters,
    required this.lines,
    this.worked = false,
  });

  final String name;
  final int meters;
  final List<List<LatLng>> lines;

  /// Rua já trabalhada neste ciclo do cartão (registro rápido de cartões em aberto).
  final bool worked;

  /// Chave de comparação: o servidor também ignora caixa e espaços repetidos.
  String get key => streetKey(name);

  factory OutingWorkStreet.fromJson(Map<String, dynamic> json) =>
      OutingWorkStreet(
        name: json['name'] as String? ?? 'Sem nome',
        meters: (json['meters'] as num?)?.toInt() ?? 0,
        worked: json['worked'] == true,
        lines: (json['lines'] as List? ?? const [])
            .whereType<List>()
            .map(
              (line) => line
                  .whereType<List>()
                  .where((point) => point.length >= 2)
                  .map(
                    (point) => LatLng(
                      (point[0] as num).toDouble(),
                      (point[1] as num).toDouble(),
                    ),
                  )
                  .toList(growable: false),
            )
            .where((line) => line.isNotEmpty)
            .toList(growable: false),
      );
}

String streetKey(String name) {
  final collapsed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  return (collapsed.isEmpty ? 'sem nome' : collapsed).toLowerCase();
}

/// Registro já salvo para a saída (permite editar).
class OutingWorkRecord {
  const OutingWorkRecord({
    required this.id,
    required this.date,
    required this.note,
    required this.streets,
    required this.completed,
  });

  final int id;
  final String date;
  final String? note;
  final List<String> streets;

  /// A conclusão do cartão veio deste registro (desmarcar ruas reabre o cartão).
  final bool completed;

  factory OutingWorkRecord.fromJson(Map<String, dynamic> json) =>
      OutingWorkRecord(
        id: (json['id'] as num).toInt(),
        date: json['date'] as String? ?? '',
        note: json['note'] as String?,
        streets: (json['streets'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        completed: json['completed'] == true,
      );
}

class OutingWorkCandidate {
  const OutingWorkCandidate({
    required this.cardId,
    required this.code,
    required this.name,
    required this.streets,
    this.group,
    this.neighborhood,
    this.distanceKm,
    this.atCard = false,
    this.alreadyRegistered = false,
    this.entryPoint = false,
    this.likely = false,
    this.coverageState,
    this.lastWorkedAt,
    this.whereWorked,
    this.record,
  });

  final int cardId;
  final String code;
  final String name;
  final String? group;
  final String? neighborhood;
  final double? distanceKm;
  final bool atCard;
  final bool alreadyRegistered;
  final bool entryPoint;
  final bool likely;
  final String? coverageState;
  final String? lastWorkedAt;
  final String? whereWorked;
  final List<OutingWorkStreet> streets;
  final OutingWorkRecord? record;

  String get title => name.trim().isEmpty ? code : '$code · ${name.trim()}';

  /// O cartão já está concluído (por outro registro): marcar tudo não muda nada.
  bool get isCompleted => coverageState == 'concluido';

  factory OutingWorkCandidate.fromJson(Map<String, dynamic> json) {
    final record = json['record'];
    return OutingWorkCandidate(
      cardId: (json['card_id'] as num).toInt(),
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      group: json['group'] as String?,
      neighborhood: json['neighborhood'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      atCard: json['at_card'] == true,
      alreadyRegistered: json['already_registered'] == true,
      entryPoint: json['entry_point'] == true,
      likely: json['likely'] == true,
      coverageState: json['coverage_state'] as String?,
      lastWorkedAt: json['last_worked_at'] as String?,
      whereWorked: json['where_worked'] as String?,
      streets: (json['streets'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                OutingWorkStreet.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      record: record is Map
          ? OutingWorkRecord.fromJson(Map<String, dynamic>.from(record))
          : null,
    );
  }
}

class OutingWorkData {
  const OutingWorkData({
    required this.outingId,
    required this.date,
    required this.candidates,
    this.locationName,
    this.locationPoint,
    this.noRecordNeeded = false,
    this.notice,
    this.awaitingMigration = false,
  });

  final int outingId;
  final String date;
  final String? locationName;
  final LatLng? locationPoint;

  /// Saída online/informativa: só a situação da saída precisa ser marcada.
  final bool noRecordNeeded;
  final String? notice;
  final bool awaitingMigration;
  final List<OutingWorkCandidate> candidates;

  factory OutingWorkData.fromJson(Map<String, dynamic> json) {
    final outing = Map<String, dynamic>.from(
      json['outing'] as Map? ?? const {},
    );
    final location = outing['location'];
    LatLng? point;
    String? locationName;
    if (location is Map) {
      locationName = location['name'] as String?;
      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) point = LatLng(lat, lng);
    }
    return OutingWorkData(
      outingId: (outing['id'] as num?)?.toInt() ?? 0,
      date: outing['date'] as String? ?? '',
      locationName: locationName,
      locationPoint: point,
      noRecordNeeded: json['no_record_needed'] == true,
      notice: json['notice'] as String?,
      awaitingMigration: json['awaiting_migration'] == true,
      candidates: (json['candidates'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                OutingWorkCandidate.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}

class OutingWorkResult {
  const OutingWorkResult({
    this.created = 0,
    this.updated = 0,
    this.removed = 0,
    this.completedCardIds = const [],
    this.reopenedCardIds = const [],
  });

  final int created;
  final int updated;
  final int removed;
  final List<int> completedCardIds;
  final List<int> reopenedCardIds;

  factory OutingWorkResult.fromJson(Map<String, dynamic> json) {
    List<int> ids(String key) => (json[key] as List? ?? const [])
        .whereType<num>()
        .map((id) => id.toInt())
        .toList(growable: false);
    return OutingWorkResult(
      created: (json['created'] as num?)?.toInt() ?? 0,
      updated: (json['updated'] as num?)?.toInt() ?? 0,
      removed: (json['removed'] as num?)?.toInt() ?? 0,
      completedCardIds: ids('completed_card_ids'),
      reopenedCardIds: ids('reopened_card_ids'),
    );
  }
}

/// Resultado de uma seleção sobre um cartão.
enum OutingWorkCoverage { none, partial, all }

/// Seleção de ruas por cartão (regra do web: todas as ruas conclui o cartão,
/// parcial só registra o dia; cartão sem ruas conhecidas nunca conclui).
class OutingWorkSelection {
  OutingWorkSelection(this.candidates) {
    for (final candidate in candidates) {
      final saved = candidate.record?.streets.map(streetKey).toSet() ?? {};
      _chosen[candidate.cardId] = candidate.streets
          .map((street) => street.key)
          .where(saved.contains)
          .toSet();
      _initial[candidate.cardId] = {..._chosen[candidate.cardId]!};
    }
  }

  final List<OutingWorkCandidate> candidates;
  final Map<int, Set<String>> _chosen = {};
  final Map<int, Set<String>> _initial = {};

  bool isSelected(OutingWorkCandidate card, OutingWorkStreet street) =>
      _chosen[card.cardId]?.contains(street.key) ?? false;

  void toggleStreet(OutingWorkCandidate card, OutingWorkStreet street) {
    final set = _chosen.putIfAbsent(card.cardId, () => <String>{});
    if (!set.remove(street.key)) set.add(street.key);
  }

  void setAll(OutingWorkCandidate card, bool selected) {
    final set = _chosen.putIfAbsent(card.cardId, () => <String>{});
    set.clear();
    if (selected) set.addAll(card.streets.map((street) => street.key));
  }

  OutingWorkCoverage coverage(OutingWorkCandidate card) {
    final keys = card.streets.map((street) => street.key).toSet();
    final chosen = _chosen[card.cardId] ?? const <String>{};
    final marked = keys.where(chosen.contains).length;
    if (marked == 0) return OutingWorkCoverage.none;
    return marked == keys.length
        ? OutingWorkCoverage.all
        : OutingWorkCoverage.partial;
  }

  /// Este salvamento concluirá o cartão (todas as ruas, e ainda não estava
  /// concluído por este mesmo registro nem por outro).
  bool willComplete(OutingWorkCandidate card) =>
      coverage(card) == OutingWorkCoverage.all &&
      !card.isCompleted &&
      !(card.record?.completed ?? false);

  /// Desmarcar ruas de um registro que concluiu o cartão o reabre.
  bool willReopen(OutingWorkCandidate card) =>
      (card.record?.completed ?? false) &&
      coverage(card) != OutingWorkCoverage.all;

  /// Há diferença em relação ao que já estava salvo na abertura da tela.
  bool get hasChanges {
    for (final card in candidates) {
      final now = _chosen[card.cardId] ?? const <String>{};
      final before = _initial[card.cardId] ?? const <String>{};
      if (now.length != before.length || !now.containsAll(before)) return true;
    }
    return false;
  }

  int get selectedStreetCount =>
      _chosen.values.fold(0, (total, set) => total + set.length);

  /// Corpo de POST /mobile/field-outings/{id}/work-streets.
  /// Vazio quando não há nada a enviar.
  Map<String, Object?> payload({required String defaultDate}) {
    final items = <Map<String, Object?>>[];
    final remove = <int>[];
    for (final card in candidates) {
      final chosen = _chosen[card.cardId] ?? const <String>{};
      final before = _initial[card.cardId] ?? const <String>{};
      // Só o que mudou: registros já salvos e intactos não são reenviados.
      if (chosen.length == before.length && chosen.containsAll(before)) {
        continue;
      }
      final names = card.streets
          .where((street) => chosen.contains(street.key))
          .map((street) => street.name)
          .toList(growable: false);
      if (names.isNotEmpty) {
        final recordDate = card.record?.date ?? '';
        final date = recordDate.isNotEmpty ? recordDate : defaultDate;
        items.add({
          'card_id': card.cardId,
          if (date.isNotEmpty) 'date': date,
          if ((card.record?.note ?? '').isNotEmpty) 'note': card.record!.note,
          'streets': names,
        });
      } else if (card.record != null) {
        remove.add(card.cardId);
      }
    }
    if (items.isEmpty && remove.isEmpty) return const {};
    return {'items': items, if (remove.isNotEmpty) 'remove': remove};
  }
}
