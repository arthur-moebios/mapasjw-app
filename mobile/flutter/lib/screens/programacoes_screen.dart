import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../models/programacoes.dart';
import '../state/mobile_app_controller.dart';
import 'native_state_message.dart';

/// Designações da reunião, AVA e limpeza, por mês (somente leitura).
class ProgramacoesScreen extends ConsumerStatefulWidget {
  const ProgramacoesScreen({super.key});

  @override
  ConsumerState<ProgramacoesScreen> createState() => _ProgramacoesScreenState();
}

class _ProgramacoesScreenState extends ConsumerState<ProgramacoesScreen> {
  static const _types = <(String, String)>[
    ('reunioes', 'Meio de semana'),
    ('weekend', 'Fim de semana'),
    ('ava', 'AVA'),
    ('limpeza', 'Limpeza'),
  ];

  Future<ProgramacoesMonth>? _future;
  int? _congregationId;
  String _type = 'reunioes';
  String? _month;

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(mobileAppControllerProvider).requireValue;
    final congregationId = app.selectedCongregationId;
    if (_congregationId != congregationId) {
      _congregationId = congregationId;
      _month = null;
      _future = congregationId == null ? null : _load();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Programações')),
      body: congregationId == null
          ? const StateMessage(
              icon: Icons.apartment_outlined,
              title: 'Escolha uma congregação',
              message:
                  'Selecione uma congregação para consultar as programações.',
            )
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      for (final (key, label) in _types)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _type == key,
                            onSelected: (_) => _setType(key),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<ProgramacoesMonth>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (snapshot.hasError) {
                        return StateMessage(
                          icon: Icons.cloud_off_outlined,
                          title: 'Não foi possível carregar',
                          message: loadErrorText(snapshot.error),
                          action: TextButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Tentar novamente'),
                          ),
                        );
                      }
                      return _ProgramacoesBody(
                        data: snapshot.requireData,
                        type: _type,
                        onRefresh: _reload,
                        onMonth: _go,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<ProgramacoesMonth> _load() => ref
      .read(mobileAppControllerProvider.notifier)
      .loadProgramacoes(type: _type, month: _month);

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    try {
      await _future;
    } catch (_) {
      // O erro já aparece na tela, com "Tentar novamente".
    }
  }

  void _setType(String type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _future = _load();
    });
  }

  void _go(String month) {
    setState(() {
      _month = month;
      _future = _load();
    });
  }
}

class _ProgramacoesBody extends StatelessWidget {
  const _ProgramacoesBody({
    required this.data,
    required this.type,
    required this.onRefresh,
    required this.onMonth,
  });

  final ProgramacoesMonth data;
  final String type;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onMonth;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      MonthSwitcher(
        label: monthLabel(data.month),
        previous: data.previousMonth,
        next: data.nextMonth,
        onMonth: onMonth,
      ),
    ];
    if (type == 'ava') {
      if (data.ava.isEmpty) {
        children.add(const _EmptyInline('Nenhuma escala de AVA neste mês'));
      }
      children.addAll(data.ava.map((day) => _AvaCard(day: day)));
    } else if (type == 'limpeza') {
      if (data.cleaning.isEmpty) {
        children.add(const _EmptyInline('Nenhuma escala de limpeza neste mês'));
      }
      children.addAll(data.cleaning.map((entry) => _CleaningTile(entry: entry)));
    } else {
      if (data.meetings.isEmpty) {
        children.add(const _EmptyInline('Nenhuma reunião programada neste mês'));
      }
      children.addAll(
        data.meetings.map((meeting) => _MeetingCard(meeting: meeting)),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: children,
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(child: Text(text, textAlign: TextAlign.center)),
  );
}

String _dateText(String? iso) {
  final date = parseIsoDate(iso);
  return date == null ? (iso ?? '') : shortDateLabel(date);
}

String _assignmentLine(ProgramacaoAssignment a) {
  final who = a.people ?? 'Sem designação';
  final label = a.label ?? a.role;
  final room = a.room == null ? '' : ' (${a.room})';
  return label == null ? '$who$room' : '$label: $who$room';
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting});

  final ProgramacaoMeeting meeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <String, List<ProgramacaoPart>>{};
    final titles = <String, String?>{};
    for (final part in meeting.parts) {
      final key = normalizeSectionKey(part.section);
      groups.putIfAbsent(key, () => []).add(part);
      titles.putIfAbsent(key, () => part.section);
    }
    final general = meeting.generalAssignments;
    final header = [
      _dateText(meeting.date),
      if (meeting.time != null) meeting.time!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(header, style: theme.textTheme.titleMedium),
            if (meeting.event != null)
              Text(meeting.event!, style: theme.textTheme.bodyMedium),
            if (meeting.weeklyReading != null)
              Text(
                'Leitura da semana: ${meeting.weeklyReading}',
                style: theme.textTheme.bodySmall,
              ),
            if (meeting.specialStructure != null)
              Text(
                meeting.specialStructure!,
                style: theme.textTheme.bodySmall,
              ),
            if (!meeting.textbookAvailable)
              Text(
                'Apostila ainda não disponível',
                style: theme.textTheme.bodySmall,
              ),
            if (general.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final a in general)
                Text(_assignmentLine(a), style: theme.textTheme.bodyMedium),
            ],
            for (final entry in groups.entries)
              _SectionBlock(
                section: titles[entry.key],
                parts: entry.value,
                meeting: meeting,
              ),
            if (meeting.outsideTalks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Discursos fora', style: theme.textTheme.titleSmall),
              for (final talk in meeting.outsideTalks)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [
                      _dateText(talk.date),
                      if (talk.number != null) 'Nº ${talk.number}',
                      if (talk.title.isNotEmpty) talk.title,
                      if (talk.speaker != null) talk.speaker!,
                      if (talk.destination != null) '→ ${talk.destination}',
                    ].where((text) => text.isNotEmpty).join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.parts,
    required this.meeting,
  });

  final String? section;
  final List<ProgramacaoPart> parts;
  final ProgramacaoMeeting meeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = sectionColor(section);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              sectionTitle(section),
              style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
            ),
          ),
          for (final part in parts) _PartRow(part: part, meeting: meeting, color: color),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.part,
    required this.meeting,
    required this.color,
  });

  final ProgramacaoPart part;
  final ProgramacaoMeeting meeting;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignments = meeting.assignmentsFor(part.id);
    final title = [
      if (part.number != null) '${part.number}.',
      if (part.title.isNotEmpty) part.title else 'Parte',
      if (part.minutes != null) '(${part.minutes} min)',
    ].join(' ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(right: 8),
            color: color,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                if (part.songNumber != null)
                  Text(
                    'Cântico ${part.songNumber}'
                    '${part.songTitle == null ? '' : ' · ${part.songTitle}'}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (part.info != null)
                  Text(part.info!, style: theme.textTheme.bodySmall),
                if (assignments.isEmpty)
                  Text(
                    'Sem designação',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  )
                else
                  for (final a in assignments)
                    Text(
                      _assignmentLine(a),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvaCard extends StatelessWidget {
  const _AvaCard({required this.day});

  final AvaDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_dateText(day.date), style: theme.textTheme.titleMedium),
            if (day.meetingType != null)
              Text(day.meetingType!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            if (day.assignments.isEmpty)
              const Text('Sem designações')
            else
              for (final a in day.assignments) Text(_assignmentLine(a)),
          ],
        ),
      ),
    );
  }
}

class _CleaningTile extends StatelessWidget {
  const _CleaningTile({required this.entry});

  final CleaningEntry entry;

  @override
  Widget build(BuildContext context) {
    final when = [
      if (entry.week != null) entry.week!,
      if (entry.day != null) entry.day!,
      if (entry.slot != null) entry.slot!,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: Text(entry.label ?? 'Limpeza'),
        subtitle: Text(
          [
            if (when.isNotEmpty) when,
            entry.responsible ?? 'Sem responsável',
          ].join('\n'),
        ),
      ),
    );
  }
}
