/// Modelos de consulta das programações (reuniões, AVA e limpeza).
/// Somente leitura: o servidor (Laravel) é a fonte dos dados.
library;

import 'package:flutter/material.dart';

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

/// Chave tolerante de seção: minúscula, sem acento e sem espaços/pontuação
/// ("NOSSA VIDA CRISTÃ" e "nossa_vida_crista" viram a mesma chave).
String normalizeSectionKey(String? raw) {
  if (raw == null) return '';
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final rune in raw.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Cores da apostila (iguais às do servidor). Seção desconhecida é neutra.
const Color neutralSectionColor = Color(0xFF6B7280);

Color sectionColor(String? section) {
  switch (normalizeSectionKey(section)) {
    case 'tesouros':
    case 'tesouros_da_palavra_de_deus':
      return const Color(0xFF2F6F73);
    case 'faca_seu_melhor':
    case 'faca_seu_melhor_no_ministerio':
      return const Color(0xFFB8860B);
    case 'nossa_vida_crista':
      return const Color(0xFF7A2438);
    default:
      return neutralSectionColor;
  }
}

String sectionTitle(String? section) {
  switch (normalizeSectionKey(section)) {
    case 'tesouros':
    case 'tesouros_da_palavra_de_deus':
      return 'Tesouros da Palavra de Deus';
    case 'faca_seu_melhor':
    case 'faca_seu_melhor_no_ministerio':
      return 'Faça seu melhor no ministério';
    case 'nossa_vida_crista':
      return 'Nossa Vida Cristã';
    case '':
      return 'Geral';
    default:
      return section!.trim();
  }
}

class ProgramacaoPart {
  const ProgramacaoPart({
    required this.id,
    this.order = 0,
    this.section,
    this.type,
    this.number,
    this.title = '',
    this.info,
    this.minutes,
    this.songNumber,
    this.songTitle,
    this.room,
  });

  factory ProgramacaoPart.fromJson(Map<String, dynamic> json) =>
      ProgramacaoPart(
        id: _int(json['id']),
        order: _int(json['order']),
        section: _text(json['section']),
        type: _text(json['type']),
        number: _intOrNull(json['number']),
        title: _text(json['title']) ?? '',
        info: _text(json['info']),
        minutes: _intOrNull(json['minutes']),
        songNumber: _intOrNull(json['song_number']),
        songTitle: _text(json['song_title']),
        room: _text(json['room']),
      );

  final int id;
  final int order;
  final String? section;
  final String? type;
  final int? number;
  final String title;
  final String? info;
  final int? minutes;
  final int? songNumber;
  final String? songTitle;
  final String? room;
}

class ProgramacaoAssignment {
  const ProgramacaoAssignment({
    required this.id,
    this.partId,
    this.group,
    this.role,
    this.label,
    this.room,
    this.order = 0,
    this.person,
    this.secondPerson,
    this.secondRole,
    this.reviewed = false,
  });

  factory ProgramacaoAssignment.fromJson(Map<String, dynamic> json) =>
      ProgramacaoAssignment(
        id: _int(json['id']),
        partId: _intOrNull(json['part_id']),
        group: _text(json['group']),
        role: _text(json['role']),
        label: _text(json['label']),
        room: _text(json['room']),
        order: _int(json['order']),
        person: _text(json['person']),
        secondPerson: _text(json['second_person']),
        secondRole: _text(json['second_role']),
        reviewed: json['reviewed'] == true,
      );

  final int id;
  final int? partId;
  final String? group;
  final String? role;
  final String? label;
  final String? room;
  final int order;
  final String? person;
  final String? secondPerson;
  final String? secondRole;
  final bool reviewed;

  /// "Fulano · Beltrano" (ou só o titular).
  String? get people {
    final names = [person, secondPerson].whereType<String>().toList();
    return names.isEmpty ? null : names.join(' · ');
  }
}

class ProgramacaoOutsideTalk {
  const ProgramacaoOutsideTalk({
    required this.id,
    this.date,
    this.time,
    this.number,
    this.title = '',
    this.speaker,
    this.destination,
  });

  factory ProgramacaoOutsideTalk.fromJson(Map<String, dynamic> json) =>
      ProgramacaoOutsideTalk(
        id: _int(json['id']),
        date: _text(json['date']),
        time: _text(json['time']),
        number: _intOrNull(json['number']),
        title: _text(json['title']) ?? '',
        speaker: _text(json['speaker']),
        destination: _text(json['destination_congregation']),
      );

  final int id;
  final String? date;
  final String? time;
  final int? number;
  final String title;
  final String? speaker;
  final String? destination;
}

class ProgramacaoMeeting {
  const ProgramacaoMeeting({
    required this.id,
    this.type,
    this.date,
    this.time,
    this.weeklyReading,
    this.specialStructure,
    this.textbookAvailable = true,
    this.event,
    this.parts = const [],
    this.assignments = const [],
    this.outsideTalks = const [],
  });

  factory ProgramacaoMeeting.fromJson(Map<String, dynamic> json) {
    final event = json['event'];
    return ProgramacaoMeeting(
      id: _int(json['id']),
      type: _text(json['type']),
      date: _text(json['date']),
      time: _text(json['time']),
      weeklyReading: _text(json['weekly_reading']),
      specialStructure: _text(json['special_structure']),
      textbookAvailable: json['textbook_available'] != false,
      event: event is String ? _text(event) : null,
      parts: _maps(json['parts']).map(ProgramacaoPart.fromJson).toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
      assignments: _maps(
        json['assignments'],
      ).map(ProgramacaoAssignment.fromJson).toList(growable: false),
      outsideTalks: _maps(
        json['outside_talks'],
      ).map(ProgramacaoOutsideTalk.fromJson).toList(growable: false),
    );
  }

  final int id;
  final String? type;
  final String? date;
  final String? time;
  final String? weeklyReading;
  final String? specialStructure;
  final bool textbookAvailable;
  final String? event;
  final List<ProgramacaoPart> parts;
  final List<ProgramacaoAssignment> assignments;
  final List<ProgramacaoOutsideTalk> outsideTalks;

  /// Designações ligadas à parte por `part_id`.
  List<ProgramacaoAssignment> assignmentsFor(int partId) =>
      assignments.where((a) => a.partId == partId).toList(growable: false)
        ..sort((a, b) => a.order.compareTo(b.order));

  /// Designações sem parte (presidente, leitor, oração...).
  List<ProgramacaoAssignment> get generalAssignments {
    final ids = parts.map((p) => p.id).toSet();
    return assignments
        .where((a) => a.partId == null || !ids.contains(a.partId))
        .toList(growable: false)
      ..sort((a, b) => a.order.compareTo(b.order));
  }
}

class AvaDay {
  const AvaDay({this.date, this.meetingType, this.assignments = const []});

  factory AvaDay.fromJson(Map<String, dynamic> json) => AvaDay(
    date: _text(json['date']),
    meetingType: _text(json['meeting_type']),
    assignments: _maps(
      json['assignments'],
    ).map(ProgramacaoAssignment.fromJson).toList(growable: false),
  );

  final String? date;
  final String? meetingType;
  final List<ProgramacaoAssignment> assignments;
}

class CleaningEntry {
  const CleaningEntry({
    required this.id,
    this.week,
    this.slot,
    this.day,
    this.label,
    this.responsible,
  });

  factory CleaningEntry.fromJson(Map<String, dynamic> json) => CleaningEntry(
    id: _int(json['id']),
    week: _text(json['week']),
    slot: _text(json['slot']),
    day: _text(json['day']),
    label: _text(json['label']),
    responsible: _text(json['responsible']),
  );

  final int id;
  final String? week;
  final String? slot;
  final String? day;
  final String? label;
  final String? responsible;
}

class ProgramacoesMonth {
  const ProgramacoesMonth({
    required this.type,
    required this.month,
    this.previousMonth,
    this.nextMonth,
    this.meetings = const [],
    this.ava = const [],
    this.cleaning = const [],
  });

  factory ProgramacoesMonth.fromJson(Map<String, dynamic> json) =>
      ProgramacoesMonth(
        type: _text(json['type']) ?? 'reunioes',
        month: _text(json['month']) ?? '',
        previousMonth: _text(json['previous_month']),
        nextMonth: _text(json['next_month']),
        meetings: _maps(
          json['meetings'],
        ).map(ProgramacaoMeeting.fromJson).toList(growable: false),
        ava: _maps(
          json['ava'],
        ).map(AvaDay.fromJson).toList(growable: false),
        cleaning: _maps(
          json['cleaning'],
        ).map(CleaningEntry.fromJson).toList(growable: false),
      );

  final String type;
  final String month;
  final String? previousMonth;
  final String? nextMonth;
  final List<ProgramacaoMeeting> meetings;
  final List<AvaDay> ava;
  final List<CleaningEntry> cleaning;

  bool get isEmpty => meetings.isEmpty && ava.isEmpty && cleaning.isEmpty;
}
