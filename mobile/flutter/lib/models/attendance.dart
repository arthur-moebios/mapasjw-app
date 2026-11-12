/// Modelos de consulta da assistência às reuniões e do cronômetro das partes.
/// Somente leitura: o servidor (Laravel) é a fonte dos números.
library;

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

int _int(Object? value) => value is num ? value.toInt() : 0;

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map(Map<String, dynamic>.from)
    .toList(growable: false);

DateTime? parseIsoDate(String? value) {
  final parts = value?.split('-');
  if (parts == null || parts.length < 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2].split('T').first);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.type,
    required this.typeLabel,
    this.inPerson,
    this.zoom,
    this.total,
    this.manuallyEdited = false,
    this.note,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: _int(json['id']),
        date: parseIsoDate(json['date'] as String?) ?? DateTime(1970),
        type: json['type'] as String? ?? '',
        typeLabel: json['type_label'] as String? ?? '',
        inPerson: _intOrNull(json['in_person']),
        zoom: _intOrNull(json['zoom']),
        total: _intOrNull(json['total']),
        manuallyEdited: json['manually_edited'] == true,
        note: _text(json['note']),
      );

  final int id;
  final DateTime date;
  final String type;
  final String typeLabel;
  final int? inPerson;
  final int? zoom;
  final int? total;
  final bool manuallyEdited;
  final String? note;
}

class AttendanceAverage {
  const AttendanceAverage({
    required this.type,
    required this.label,
    required this.meetings,
    this.average,
    this.inPerson,
    this.zoom,
  });

  factory AttendanceAverage.fromJson(Map<String, dynamic> json) =>
      AttendanceAverage(
        type: json['type'] as String? ?? '',
        label: json['label'] as String? ?? '',
        meetings: _int(json['meetings']),
        average: _intOrNull(json['average']),
        inPerson: _intOrNull(json['in_person']),
        zoom: _intOrNull(json['zoom']),
      );

  final String type;
  final String label;
  final int meetings;
  final int? average;
  final int? inPerson;
  final int? zoom;
}

class AttendanceMonth {
  const AttendanceMonth({
    required this.month,
    required this.previousMonth,
    required this.nextMonth,
    required this.isCurrentMonth,
    required this.averages,
    required this.records,
  });

  factory AttendanceMonth.fromJson(Map<String, dynamic> json) =>
      AttendanceMonth(
        month: json['month'] as String? ?? '',
        previousMonth: _text(json['previous_month']),
        nextMonth: _text(json['next_month']),
        isCurrentMonth: json['is_current_month'] == true,
        averages: _maps(json['averages'])
            .map(AttendanceAverage.fromJson)
            .toList(growable: false),
        records: _maps(json['records'])
            .map(AttendanceRecord.fromJson)
            .toList(growable: false),
      );

  /// "YYYY-MM".
  final String month;
  final String? previousMonth;
  final String? nextMonth;
  final bool isCurrentMonth;
  final List<AttendanceAverage> averages;
  final List<AttendanceRecord> records;
}

class TimerPart {
  const TimerPart({
    required this.title,
    required this.plannedSeconds,
    this.section,
    this.assignee,
    this.assistant,
    this.usedSeconds,
    this.differenceSeconds,
  });

  factory TimerPart.fromJson(Map<String, dynamic> json) => TimerPart(
    title: json['title'] as String? ?? '',
    section: _text(json['section']),
    assignee: _text(json['assignee']),
    assistant: _text(json['assistant']),
    plannedSeconds: _int(json['planned_s']),
    usedSeconds: _intOrNull(json['used_s']),
    differenceSeconds: _intOrNull(json['difference_s']),
  );

  final String title;
  final String? section;
  final String? assignee;
  final String? assistant;
  final int plannedSeconds;
  final int? usedSeconds;
  final int? differenceSeconds;

  bool get measured => usedSeconds != null;
  bool get overtime => (differenceSeconds ?? 0) > 0;
}

class TimerRoom {
  const TimerRoom({
    required this.room,
    required this.label,
    required this.parts,
    required this.totalPlannedSeconds,
    required this.totalUsedSeconds,
    required this.differenceSeconds,
    required this.measuredParts,
    required this.totalParts,
  });

  factory TimerRoom.fromJson(Map<String, dynamic> json) => TimerRoom(
    room: json['room'] as String? ?? '',
    label: json['label'] as String? ?? '',
    parts: _maps(json['parts']).map(TimerPart.fromJson).toList(growable: false),
    totalPlannedSeconds: _int(json['total_planned_s']),
    totalUsedSeconds: _int(json['total_used_s']),
    differenceSeconds: _int(json['difference_s']),
    measuredParts: _int(json['measured_parts']),
    totalParts: _int(json['total_parts']),
  );

  final String room;
  final String label;
  final List<TimerPart> parts;
  final int totalPlannedSeconds;
  final int totalUsedSeconds;
  final int differenceSeconds;
  final int measuredParts;
  final int totalParts;
}

class TimerDay {
  const TimerDay({
    required this.date,
    required this.typeLabel,
    required this.rooms,
  });

  factory TimerDay.fromJson(Map<String, dynamic> json) => TimerDay(
    date: parseIsoDate(json['date'] as String?) ?? DateTime(1970),
    typeLabel: json['type_label'] as String? ?? '',
    rooms: _maps(json['rooms']).map(TimerRoom.fromJson).toList(growable: false),
  );

  final DateTime date;
  final String typeLabel;
  final List<TimerRoom> rooms;
}

class TimersPage {
  const TimersPage({
    required this.available,
    required this.page,
    required this.hasMore,
    required this.days,
  });

  factory TimersPage.fromJson(Map<String, dynamic> json) => TimersPage(
    available: json['available'] != false,
    page: _int(json['page']) == 0 ? 1 : _int(json['page']),
    hasMore: json['has_more'] == true,
    days: _maps(json['days']).map(TimerDay.fromJson).toList(growable: false),
  );

  final bool available;
  final int page;
  final bool hasMore;
  final List<TimerDay> days;
}

const _weekdays = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];
const _monthsShort = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];
const _monthsLong = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// "qua, 11 nov" (data curta por extenso).
String shortDateLabel(DateTime date) =>
    '${_weekdays[date.weekday - 1].substring(0, 3)}, ${date.day} ${_monthsShort[date.month - 1]}';

/// "quarta-feira, 11 de novembro de 2026".
String longDateLabel(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} de ${_monthsLong[date.month - 1]} de ${date.year}';

/// "novembro de 2026" a partir de "2026-11".
String monthLabel(String month) {
  final date = parseIsoDate('$month-01');
  if (date == null) return month;
  return '${_monthsLong[date.month - 1]} de ${date.year}';
}

/// m:ss (ou h:mm:ss); a diferença leva sinal. null vira "—".
String formatSeconds(int? seconds, {bool signed = false}) {
  if (seconds == null) return '—';
  final abs = seconds.abs();
  final body = abs >= 3600
      ? '${abs ~/ 3600}:${((abs % 3600) ~/ 60).toString().padLeft(2, '0')}:${(abs % 60).toString().padLeft(2, '0')}'
      : '${abs ~/ 60}:${(abs % 60).toString().padLeft(2, '0')}';
  if (!signed) return body;
  return '${seconds < 0 ? '−' : (seconds > 0 ? '+' : '')}$body';
}
