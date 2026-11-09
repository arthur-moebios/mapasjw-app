import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../data/mobile_api.dart';
import '../models/mobile_models.dart';
import '../services/field_schedule_share_service.dart';
import '../state/mobile_app_controller.dart';
import 'card_suggestions_panel.dart';
import 'location_point_picker.dart';
import 'outing_work_screen.dart';

class FieldOutingsScreen extends ConsumerStatefulWidget {
  const FieldOutingsScreen({super.key});

  @override
  ConsumerState<FieldOutingsScreen> createState() => _FieldOutingsScreenState();
}

class _FieldOutingsScreenState extends ConsumerState<FieldOutingsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();
  int _section = 0;
  int? _observedCongregationId;
  int? _selectedServiceYear;
  bool _isExportingSchedule = false;

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (mounted) {
        ref
            .read(mobileAppControllerProvider.notifier)
            .refreshFieldCalendar(month: _monthKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(mobileAppControllerProvider).requireValue;
    final controller = ref.read(mobileAppControllerProvider.notifier);
    if (_observedCongregationId != app.selectedCongregationId) {
      _observedCongregationId = app.selectedCongregationId;
      _selectedServiceYear = null;
      if (app.selectedCongregationId != null && app.canViewFieldOutings) {
        scheduleMicrotask(() {
          if (mounted) {
            controller.refreshFieldCalendar(month: _monthKey, force: true);
            if (_section == 2) _loadDesignations(app);
          }
        });
      }
    }

    if (app.isSuperAdmin && app.selectedCongregationId == null) {
      return const _FieldMessage(
        icon: Icons.apartment_rounded,
        title: 'Escolha uma congregação',
        message: 'Selecione a congregação para abrir o calendário de campo.',
      );
    }

    final calendar = app.fieldCalendar;
    final loadingCurrentMonth = calendar?.month != _monthKey;
    final outings =
        calendar?.outings
            .where((outing) => _sameDate(outing.date, _selectedDay))
            .toList(growable: false) ??
        const <FieldOuting>[];

    return RefreshIndicator(
      onRefresh: () =>
          controller.refreshFieldCalendar(month: _monthKey, force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('Campo', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            app.selectedCongregation == null
                ? 'Saídas, agenda e designações'
                : [
                    app.selectedCongregation!.name,
                    app.selectedCongregation!.subtitle,
                  ].where((part) => part.isNotEmpty).join(' · '),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Calendário'),
                icon: Icon(Icons.calendar_month_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Padrões'),
                icon: Icon(Icons.repeat_rounded),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Designações'),
                icon: Icon(Icons.assignment_outlined),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (selection) {
              setState(() => _section = selection.first);
              if (_section == 2) _loadDesignations(app);
            },
          ),
          if (app.fieldCalendarError != null) ...[
            const SizedBox(height: 12),
            _FieldMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar o calendário',
              message: app.fieldCalendarError!,
              actionLabel: 'Tentar novamente',
              onAction: () => controller.refreshFieldCalendar(
                month: _monthKey,
                force: true,
              ),
            ),
          ],
          if (_section == 0) ...[
            const SizedBox(height: 14),
            _monthCard(context, calendar, loadingCurrentMonth),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isExportingSchedule ? null : _exportSchedule,
              icon: _isExportingSchedule
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(
                _isExportingSchedule
                    ? 'Preparando programação…'
                    : 'Exportar programação',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _longDate(_selectedDay),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (calendar?.canManage == true)
                  IconButton.filledTonal(
                    tooltip: 'Adicionar saída',
                    onPressed: calendar == null
                        ? null
                        : () => _editOuting(calendar),
                    icon: const Icon(Icons.add_rounded),
                  ),
              ],
            ),
            if (calendar?.canManage == true) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _repeatWeek(controller),
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Repetir saídas da semana anterior'),
              ),
            ],
            const SizedBox(height: 8),
            if (app.isLoadingFieldCalendar && loadingCurrentMonth)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (outings.isEmpty)
              _FieldMessage(
                icon: Icons.event_available_outlined,
                title: 'Nenhuma saída neste dia',
                message: calendar?.canManage == true
                    ? 'Toque no botão + para incluir uma saída e designar grupo, dirigente e local.'
                    : 'As saídas programadas para este dia aparecerão aqui.',
              )
            else
              ...outings.map(
                (outing) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _outingCard(context, outing, calendar!),
                ),
              ),
          ] else if (_section == 1) ...[
            const SizedBox(height: 14),
            _patternsSection(context, calendar, controller),
          ] else ...[
            const SizedBox(height: 14),
            _designationsSection(context, app, controller),
          ],
        ],
      ),
    );
  }

  Widget _monthCard(
    BuildContext context,
    FieldCalendarData? calendar,
    bool loadingCurrentMonth,
  ) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final firstOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cellCount = ((firstOffset + daysInMonth + 6) ~/ 7) * 7;
    final counts = <String, int>{};
    for (final outing in calendar?.outings ?? const <FieldOuting>[]) {
      final date = outing.date;
      if (date != null) {
        counts[_dateKey(date)] = (counts[_dateKey(date)] ?? 0) + 1;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[_month.month - 1]} de ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (loadingCurrentMonth)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Próximo mês',
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: _weekdays
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 5),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cellCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - firstOffset + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(_month.year, _month.month, dayNumber);
                final selected = _sameDate(date, _selectedDay);
                final count = counts[_dateKey(date)] ?? 0;
                final colorScheme = Theme.of(context).colorScheme;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedDay = date),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? colorScheme.primary : null,
                      borderRadius: BorderRadius.circular(14),
                      border: count > 0 && !selected
                          ? Border.all(
                              color: colorScheme.primary.withValues(alpha: .3),
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: selected ? colorScheme.onPrimary : null,
                                fontWeight: count > 0 || selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: count > 0
                              ? 5 + (count.clamp(1, 3) - 1) * 2
                              : 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: count > 0
                                ? (selected
                                      ? colorScheme.onPrimary
                                      : colorScheme.primary)
                                : (selected
                                      ? colorScheme.onPrimary.withValues(
                                          alpha: .55,
                                        )
                                      : Colors.transparent),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _outingCard(
    BuildContext context,
    FieldOuting outing,
    FieldCalendarData calendar,
  ) {
    final color = switch (outing.situation) {
      'concluida' => const Color(0xFF36835D),
      'cancelada' => const Color(0xFFB64E4E),
      _ => const Color(0xFFD18A25),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      outing.time.isEmpty ? 'Horário a definir' : outing.time,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  _StatusBadge(label: outing.situationLabel, color: color),
                  const Spacer(),
                  if (calendar.canManage)
                    PopupMenuButton<String>(
                      tooltip: 'Opções da saída',
                      onSelected: (action) =>
                          _outingAction(action, outing, calendar),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                        const PopupMenuItem(
                          value: 'done',
                          child: Text('Marcar como concluída'),
                        ),
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Marcar que não houve'),
                        ),
                        const PopupMenuItem(
                          value: 'pending',
                          child: Text('Voltar para pendente'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Excluir'),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 13),
              _FieldDetailRow(
                icon: Icons.place_outlined,
                text: outing.location?.name ?? 'Local não definido',
                action: outing.location?.mapsUrl.isNotEmpty == true
                    ? () => launchUrl(
                        Uri.parse(outing.location!.mapsUrl),
                        mode: LaunchMode.externalApplication,
                      )
                    : null,
              ),
              if ((outing.location?.address ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 29, top: 2),
                  child: Text(
                    outing.location!.address,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if ((outing.location?.reference ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 29, top: 2),
                  child: Text(
                    'Ref.: ${outing.location!.reference}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (outing.location?.mapsUrl.isNotEmpty == true)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(outing.location!.mapsUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Ver no mapa'),
                  ),
                ),
              if (outing.leader.isNotEmpty) ...[
                const SizedBox(height: 8),
                _FieldDetailRow(
                  icon: Icons.person_outline_rounded,
                  text: outing.leader,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: outing.allGroups
                    ? [
                        _GroupBadge(
                          label: 'Todos os grupos',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ]
                    : outing.groups.isEmpty
                    ? const [
                        _GroupBadge(
                          label: 'Grupo não designado',
                          color: Color(0xFF65736B),
                        ),
                      ]
                    : outing.groups
                          .map(
                            (group) => _GroupBadge(
                              label: group.name,
                              color: group.color,
                            ),
                          )
                          .toList(growable: false),
              ),
              if (outing.streetPoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StreetPointsList(points: outing.streetPoints),
              ],
              if (outing.territoryCards.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'CARTÕES ALCANÇADOS A PARTIR DO LOCAL',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: outing.territoryCards
                      .map(
                        (card) => _InfoPill(
                          icon: Icons.map_outlined,
                          label: card.label,
                        ),
                      )
                      .toList(growable: false),
                ),
              ] else if (outing.location != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Nenhum cartão em aberto é alcançado a partir de ${outing.location!.name}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (calendar.canManage)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showCardSuggestionsSheet(
                      context,
                      requestKey: 'outing-${outing.id}',
                      weekday: (outing.date ?? _selectedDay).weekday % 7,
                      loader: () => ref
                          .read(mobileAppControllerProvider.notifier)
                          .loadOutingCardSuggestions(outing.id),
                    ),
                    icon: const Icon(Icons.lightbulb_outline_rounded),
                    label: const Text('Cartões sugeridos'),
                  ),
                ),
              if (outing.informational)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Saída informativa ou online: não há trabalho de rua a '
                    'registrar, só marque a situação da saída.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showOutingWorkScreen(
                      context,
                      outingId: outing.id,
                      month: _monthKey,
                      canSave:
                          ref
                              .watch(mobileAppControllerProvider)
                              .value
                              ?.canManageTerritoryCards ??
                          false,
                    ),
                    icon: const Icon(Icons.route_outlined),
                    label: const Text('Onde foi trabalhado?'),
                  ),
                ),
              if (outing.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  outing.notes,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (outing.recurrenceId != null) ...[
                const SizedBox(height: 9),
                const _InfoPill(
                  icon: Icons.repeat_rounded,
                  label: 'Criada por padrão semanal',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _patternsSection(
    BuildContext context,
    FieldCalendarData? calendar,
    MobileAppController controller,
  ) {
    if (calendar == null) {
      return _FieldMessage(
        icon: Icons.repeat_rounded,
        title: 'Padrões de agenda',
        message: 'Carregando os horários que se repetem durante a semana.',
        actionLabel: 'Atualizar',
        onAction: () =>
            controller.refreshFieldCalendar(month: _monthKey, force: true),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Agenda semanal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (calendar.canManage)
              IconButton.filledTonal(
                tooltip: 'Novo padrão',
                onPressed: () => _editPattern(calendar, controller),
                icon: const Icon(Icons.add_rounded),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Cadastre os dias e horários que se repetem. Depois escolha um período para criar as saídas no calendário.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (calendar.canManage) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: calendar.patterns.any((pattern) => pattern.isActive)
                ? () => _generateOutings(controller)
                : null,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Gerar saídas para um período'),
          ),
        ],
        const SizedBox(height: 12),
        if (calendar.patterns.isEmpty)
          _FieldMessage(
            icon: Icons.event_repeat_outlined,
            title: 'Nenhum padrão cadastrado',
            message: calendar.canManage
                ? 'Adicione um padrão para automatizar a programação da semana.'
                : 'Os padrões semanais cadastrados aparecerão aqui.',
          )
        else
          ...calendar.patterns.map(
            (pattern) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(15, 7, 8, 7),
                leading: CircleAvatar(
                  backgroundColor: pattern.isActive
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    pattern.isActive
                        ? Icons.repeat_rounded
                        : Icons.pause_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  pattern.name.isEmpty ? pattern.description : pattern.name,
                ),
                subtitle: Text(
                  [
                    if (pattern.name.isNotEmpty) pattern.description,
                    pattern.location?.name ?? 'Local a definir',
                    pattern.allGroups
                        ? 'Todos os grupos'
                        : pattern.groups.map((group) => group.name).join(', '),
                    if (!pattern.isActive) 'Padrão pausado',
                  ].where((value) => value.isNotEmpty).join(' · '),
                ),
                trailing: calendar.canManage
                    ? PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'edit') {
                            await _editPattern(
                              calendar,
                              controller,
                              pattern: pattern,
                            );
                          } else if (action == 'delete') {
                            await _deletePattern(controller, pattern);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Excluir padrão'),
                          ),
                        ],
                      )
                    : null,
                isThreeLine: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _designationsSection(
    BuildContext context,
    MobileAppState app,
    MobileAppController controller,
  ) {
    final data = app.fieldDesignations;
    final year =
        _selectedServiceYear ?? data?.serviceYear ?? _currentServiceYear;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Designações de territórios',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        Text(
          'Histórico do ano de serviço. Esses registros vêm da integração existente e são consultados no app.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (data != null && data.availableYears.isNotEmpty)
          DropdownButtonFormField<int>(
            key: ValueKey('designation-year-$year'),
            initialValue: data.availableYears.contains(year)
                ? year
                : data.availableYears.first,
            decoration: const InputDecoration(labelText: 'Ano de serviço'),
            items: data.availableYears
                .map(
                  (item) => DropdownMenuItem(value: item, child: Text('$item')),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedServiceYear = value);
                controller.refreshFieldDesignations(
                  serviceYear: value,
                  force: true,
                );
              }
            },
          ),
        if (app.fieldDesignationsError != null)
          _FieldMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Não foi possível carregar as designações',
            message: app.fieldDesignationsError!,
            actionLabel: 'Tentar novamente',
            onAction: () => controller.refreshFieldDesignations(
              serviceYear: year,
              force: true,
            ),
          )
        else if (app.isLoadingFieldDesignations && data == null)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (data == null)
          _FieldMessage(
            icon: Icons.assignment_outlined,
            title: 'Carregando designações',
            message: 'Consultando os registros do ano de serviço.',
          )
        else if (data.designations.isEmpty)
          _FieldMessage(
            icon: Icons.assignment_outlined,
            title: 'Nenhum registro neste ano',
            message:
                'Não há designações de territórios disponíveis para consulta.',
          )
        else
          ...data.designations.map(
            (designation) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Text(designation.territoryNumber.split('.').first),
                ),
                title: Text('Território ${designation.territoryNumber}'),
                subtitle: Text(
                  [
                    if (designation.territoryName.isNotEmpty)
                      designation.territoryName,
                    if (designation.publisher.isNotEmpty)
                      'Designado para ${designation.publisher}',
                    if (designation.assignedAt != null)
                      'Desde ${_shortDate(designation.assignedAt!)}',
                  ].join(' · '),
                ),
                trailing: designation.completedAt == null
                    ? const _StatusBadge(
                        label: 'Em andamento',
                        color: Color(0xFFD18A25),
                      )
                    : _StatusBadge(
                        label:
                            'Concluído ${_shortDate(designation.completedAt!)}',
                        color: const Color(0xFF36835D),
                      ),
                isThreeLine: true,
              ),
            ),
          ),
        if (data != null) ...[
          const SizedBox(height: 10),
          const _InfoPill(
            icon: Icons.info_outline_rounded,
            label: 'A edição das designações continua no sistema de origem.',
          ),
        ],
      ],
    );
  }

  Future<void> _loadDesignations(MobileAppState app) async {
    if (app.selectedCongregationId == null || !app.canViewFieldOutings) return;
    await ref
        .read(mobileAppControllerProvider.notifier)
        .refreshFieldDesignations(
          serviceYear:
              app.fieldDesignations?.serviceYear ?? _currentServiceYear,
        );
  }

  Future<void> _editOuting(
    FieldCalendarData calendar, {
    FieldOuting? outing,
  }) async {
    final payload = await _showScheduleEditor(
      calendar,
      initialDate: outing?.date ?? _selectedDay,
      initialTime: outing?.time ?? '',
      initialLeader: outing?.leader ?? '',
      initialNotes: outing?.notes ?? '',
      initialLocationId: outing?.location?.id,
      initialGroupIds: outing?.groups.map((group) => group.id).toSet() ?? {},
      initialAllGroups: outing?.allGroups ?? false,
      includeWeekdays: false,
      isEditing: outing != null,
      leaders: calendar.leaders,
    );
    if (payload == null || !mounted) return;
    try {
      await ref
          .read(mobileAppControllerProvider.notifier)
          .saveFieldOuting(payload, outingId: outing?.id);
      if (mounted) {
        _showMessage(
          outing == null
              ? 'Saída adicionada ao calendário.'
              : 'Saída atualizada.',
        );
      }
    } on Object catch (error) {
      if (mounted) _showMessage(_friendlyError(error), isError: true);
    }
  }

  Future<Map<String, Object?>?> _showScheduleEditor(
    FieldCalendarData calendar, {
    required DateTime initialDate,
    required String initialTime,
    required String initialLeader,
    required String initialNotes,
    required int? initialLocationId,
    required Set<int> initialGroupIds,
    required bool initialAllGroups,
    required bool includeWeekdays,
    required bool isEditing,
    required List<String> leaders,
    FieldOutingPattern? pattern,
  }) async {
    final nameController = TextEditingController(text: pattern?.name ?? '');
    final notesController = TextEditingController(text: initialNotes);
    DateTime date = initialDate;
    DateTime? validFrom = pattern == null ? DateTime.now() : pattern.validFrom;
    DateTime? validThrough = pattern?.validThrough;
    String time = initialTime;
    String leader = initialLeader;
    int? locationId = initialLocationId;
    bool allGroups = initialAllGroups;
    Set<int> groupIds = {...initialGroupIds};
    Set<int> weekdays = {...?pattern?.weekdays};
    bool patternIsActive = pattern?.isActive ?? true;
    final locations = List<FieldLocation>.of(calendar.locations);
    final selectableLeaders = [
      ...leaders,
      if (leader.isNotEmpty && !leaders.contains(leader)) leader,
    ];

    final result = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => AnimatedPadding(
          duration: const Duration(milliseconds: 100),
          // Sobe a folha acima do teclado para o campo em edição ficar visível.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: FractionallySizedBox(
              heightFactor: .92,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            includeWeekdays
                                ? (pattern == null
                                      ? 'Novo padrão semanal'
                                      : 'Editar padrão')
                                : (isEditing
                                      ? 'Editar saída de campo'
                                      : 'Nova saída de campo'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        if (includeWeekdays) ...[
                          TextField(
                            controller: nameController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Nome do padrão',
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Dias da semana',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 6,
                            children: List.generate(
                              7,
                              (day) => FilterChip(
                                label: Text(_weekdays[day]),
                                selected: weekdays.contains(day),
                                onSelected: (value) => setSheetState(() {
                                  value
                                      ? weekdays.add(day)
                                      : weekdays.remove(day);
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_available_outlined),
                            title: const Text('Válido a partir de'),
                            subtitle: Text(
                              validFrom == null
                                  ? 'Sem data inicial'
                                  : _longDate(validFrom!),
                            ),
                            trailing: validFrom == null
                                ? null
                                : IconButton(
                                    tooltip: 'Remover data inicial',
                                    onPressed: () =>
                                        setSheetState(() => validFrom = null),
                                    icon: const Icon(Icons.clear_rounded),
                                  ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: validFrom ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  validFrom = picked;
                                  if (validThrough != null &&
                                      validThrough!.isBefore(picked)) {
                                    validThrough = null;
                                  }
                                });
                              }
                            },
                          ),
                        ] else ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_today_outlined),
                            title: const Text('Data'),
                            subtitle: Text(_longDate(date)),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setSheetState(() => date = picked);
                              }
                            },
                          ),
                        ],
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule_rounded),
                          title: const Text('Horário'),
                          subtitle: Text(
                            time.isEmpty ? 'Escolher horário' : time,
                          ),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _parseTime(time),
                            );
                            if (picked != null) {
                              setSheetState(() => time = _timeString(picked));
                            }
                          },
                        ),
                        if (includeWeekdays)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_busy_outlined),
                            title: const Text('Válido até'),
                            subtitle: Text(
                              validThrough == null
                                  ? 'Sem data final'
                                  : _longDate(validThrough!),
                            ),
                            trailing: validThrough == null
                                ? null
                                : IconButton(
                                    tooltip: 'Remover data final',
                                    onPressed: () => setSheetState(
                                      () => validThrough = null,
                                    ),
                                    icon: const Icon(Icons.clear_rounded),
                                  ),
                            onTap: () async {
                              final firstValidDate =
                                  validFrom ?? DateTime(2020);
                              final suggestedEnd =
                                  validThrough ??
                                  DateTime.now().add(const Duration(days: 90));
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    suggestedEnd.isBefore(firstValidDate)
                                    ? firstValidDate
                                    : suggestedEnd,
                                firstDate: firstValidDate,
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setSheetState(() => validThrough = picked);
                              }
                            },
                          ),
                        DropdownButtonFormField<int?>(
                          key: ValueKey('local-$locationId'),
                          initialValue: locationId,
                          decoration: const InputDecoration(
                            labelText: 'Ponto de encontro',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('A definir'),
                            ),
                            ...locations.map(
                              (local) => DropdownMenuItem<int?>(
                                value: local.id,
                                child: Text(
                                  local.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setSheetState(() => locationId = value),
                        ),
                        ...() {
                          final selected = locations
                              .where((local) => local.id == locationId)
                              .firstOrNull;
                          if (selected == null) return <Widget>[];
                          final lines = [
                            selected.address,
                            if (selected.reference.isNotEmpty)
                              'Ref.: ${selected.reference}',
                          ].where((line) => line.isNotEmpty);
                          return <Widget>[
                            for (final line in lines)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  line,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ];
                        }(),
                        if (calendar.canManageLocations &&
                            locations
                                .where((local) => local.id == locationId)
                                .any((local) => !local.online))
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () async {
                                final current = locations.firstWhere(
                                  (local) => local.id == locationId,
                                );
                                final point = await pickLocationPoint(
                                  sheetContext,
                                  initial: current.hasPoint
                                      ? LatLng(current.lat!, current.lng!)
                                      : null,
                                );
                                if (point == null || !mounted) return;
                                try {
                                  final updated = await ref
                                      .read(
                                        mobileAppControllerProvider.notifier,
                                      )
                                      .updateFieldLocation(current.id, {
                                        'name': current.name,
                                        'address': current.address,
                                        'reference': current.reference,
                                        'maps_url': current.mapsUrl,
                                        'lat': point.latitude,
                                        'lng': point.longitude,
                                      }, month: _monthKey);
                                  setSheetState(() {
                                    final index = locations.indexWhere(
                                      (local) => local.id == updated.id,
                                    );
                                    if (index >= 0) locations[index] = updated;
                                  });
                                } on Object catch (error) {
                                  if (mounted) {
                                    _showMessage(
                                      _friendlyError(error),
                                      isError: true,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.edit_location_alt_outlined,
                              ),
                              label: Text(
                                locations
                                        .where(
                                          (local) => local.id == locationId,
                                        )
                                        .any((local) => local.hasPoint)
                                    ? 'Ajustar o ponto no mapa'
                                    : 'Marcar o ponto no mapa',
                              ),
                            ),
                          ),
                        if (calendar.canManageLocations)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () async {
                                final locationData = await _showLocationForm(
                                  sheetContext,
                                  fallbackCenter: locations
                                      .where((local) => local.hasPoint)
                                      .map(
                                        (local) =>
                                            LatLng(local.lat!, local.lng!),
                                      )
                                      .firstOrNull,
                                );
                                if (locationData == null || !mounted) return;
                                try {
                                  final location = await ref
                                      .read(
                                        mobileAppControllerProvider.notifier,
                                      )
                                      .createFieldLocation(
                                        locationData,
                                        month: _monthKey,
                                      );
                                  setSheetState(() {
                                    locations.add(location);
                                    locationId = location.id;
                                  });
                                } on Object catch (error) {
                                  if (mounted) {
                                    _showMessage(
                                      _friendlyError(error),
                                      isError: true,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: const Text('Adicionar ponto de encontro'),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (selectableLeaders.isNotEmpty)
                          DropdownButtonFormField<String?>(
                            key: ValueKey('leader-$leader'),
                            initialValue:
                                leader.isEmpty ||
                                    !selectableLeaders.contains(leader)
                                ? null
                                : leader,
                            decoration: const InputDecoration(
                              labelText: 'Dirigente',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Sem dirigente definido'),
                              ),
                              ...selectableLeaders.map(
                                (name) => DropdownMenuItem<String?>(
                                  value: name,
                                  child: Text(name),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setSheetState(() => leader = value ?? ''),
                          )
                        else
                          TextFormField(
                            initialValue: leader,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Dirigente',
                            ),
                            onChanged: (value) =>
                                setSheetState(() => leader = value),
                          ),
                        const SizedBox(height: 18),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Todos os grupos'),
                          subtitle: const Text(
                            'Esta saída ocupa o horário da congregação inteira.',
                          ),
                          value: allGroups,
                          onChanged: (value) =>
                              setSheetState(() => allGroups = value),
                        ),
                        if (!allGroups) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Designar grupos',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 7),
                          if (calendar.groups.isEmpty)
                            Text(
                              'Nenhum grupo ativo foi cadastrado.',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            Wrap(
                              spacing: 7,
                              runSpacing: 2,
                              children: calendar.groups
                                  .map(
                                    (group) => FilterChip(
                                      label: Text(group.name),
                                      selected: groupIds.contains(group.id),
                                      avatar: CircleAvatar(
                                        backgroundColor: group.color,
                                        radius: 7,
                                      ),
                                      onSelected: (value) => setSheetState(() {
                                        value
                                            ? groupIds.add(group.id)
                                            : groupIds.remove(group.id);
                                      }),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          key: const ValueKey('outing-notes-field'),
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Observações',
                          ),
                        ),
                        if (includeWeekdays && pattern != null) ...[
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Padrão ativo'),
                            value: patternIsActive,
                            onChanged: (value) =>
                                setSheetState(() => patternIsActive = value),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            if (time.isEmpty) {
                              _showMessage(
                                'Escolha um horário.',
                                isError: true,
                              );
                              return;
                            }
                            if (includeWeekdays && weekdays.isEmpty) {
                              _showMessage(
                                'Escolha ao menos um dia da semana.',
                                isError: true,
                              );
                              return;
                            }
                            final values = <String, Object?>{
                              if (includeWeekdays) ...{
                                'name': nameController.text.trim(),
                                'weekdays': weekdays.toList()..sort(),
                                'valid_from': validFrom == null
                                    ? null
                                    : _dateKey(validFrom!),
                                'valid_through': validThrough == null
                                    ? null
                                    : _dateKey(validThrough!),
                                if (pattern != null)
                                  'is_active': patternIsActive,
                              } else
                                'date': _dateKey(date),
                              'time': time,
                              'leader': leader.trim(),
                              'notes': notesController.text.trim(),
                              'location_id': locationId,
                              'all_groups': allGroups,
                              'group_ids': allGroups
                                  ? <int>[]
                                  : (groupIds.toList()..sort()),
                            };
                            Navigator.pop(sheetContext, values);
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                            includeWeekdays ? 'Salvar padrão' : 'Salvar saída',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameController.dispose();
    notesController.dispose();
    return result;
  }

  Future<void> _editPattern(
    FieldCalendarData calendar,
    MobileAppController controller, {
    FieldOutingPattern? pattern,
  }) async {
    final result = await _showScheduleEditor(
      calendar,
      initialDate: pattern?.validFrom ?? DateTime.now(),
      initialTime: pattern?.time ?? '',
      initialLeader: pattern?.leader ?? '',
      initialNotes: pattern?.notes ?? '',
      initialLocationId: pattern?.location?.id,
      initialGroupIds: pattern?.groups.map((group) => group.id).toSet() ?? {},
      initialAllGroups: pattern?.allGroups ?? false,
      includeWeekdays: true,
      isEditing: pattern != null,
      leaders: calendar.leaders,
      pattern: pattern,
    );
    if (result == null || !mounted) return;
    try {
      await controller.saveFieldPattern(
        result,
        patternId: pattern?.id,
        month: _monthKey,
      );
      if (mounted) {
        _showMessage(
          pattern == null ? 'Padrão semanal criado.' : 'Padrão atualizado.',
        );
      }
    } on Object catch (error) {
      if (mounted) _showMessage(_friendlyError(error), isError: true);
    }
  }

  Future<Map<String, Object?>?> _showLocationForm(
    BuildContext parentContext, {
    LatLng? fallbackCenter,
  }) async {
    LatLng? pickedPoint;
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final mapsController = TextEditingController();
    final notesController = TextEditingController();
    final result = await showDialog<Map<String, Object?>>(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Novo ponto de encontro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: addressController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Endereço'),
                ),
                TextField(
                  controller: mapsController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Link do mapa'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final point = await pickLocationPoint(
                        dialogContext,
                        initial: pickedPoint,
                        fallbackCenter:
                            fallbackCenter ?? const LatLng(-22.45, -43.1),
                      );
                      if (point != null) {
                        setDialogState(() => pickedPoint = point);
                      }
                    },
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: Text(
                      pickedPoint == null
                          ? 'Marcar o ponto no mapa'
                          : 'Ponto marcado (toque para ajustar)',
                    ),
                  ),
                ),
                TextField(
                  controller: notesController,
                  textCapitalization: TextCapitalization.sentences,
                  scrollPadding: const EdgeInsets.only(bottom: 120),
                  decoration: const InputDecoration(labelText: 'Observações'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  _showMessage(
                    'Informe o nome do ponto de encontro.',
                    isError: true,
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'name': nameController.text.trim(),
                  'address': addressController.text.trim(),
                  'maps_url': mapsController.text.trim(),
                  'notes': notesController.text.trim(),
                  if (pickedPoint != null) 'lat': pickedPoint!.latitude,
                  if (pickedPoint != null) 'lng': pickedPoint!.longitude,
                });
              },
              child: const Text('Salvar local'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    addressController.dispose();
    mapsController.dispose();
    notesController.dispose();
    return result;
  }

  Future<void> _generateOutings(MobileAppController controller) async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 13)),
      ),
      helpText: 'Escolha o período para gerar as saídas',
      saveText: 'Gerar período',
    );
    if (selected == null || !mounted) return;
    try {
      final result = await controller.generateFieldOutings(
        from: _dateKey(selected.start),
        through: _dateKey(selected.end),
        month: _monthKey,
      );
      if (mounted) {
        _showMessage(
          '${result['criadas'] ?? 0} saída(s) criada(s); ${result['existentes'] ?? 0} já estavam no calendário.',
        );
      }
    } on Object catch (error) {
      if (mounted) _showMessage(_friendlyError(error), isError: true);
    }
  }

  Future<void> _repeatWeek(MobileAppController controller) async {
    try {
      final result = await controller.repeatPreviousFieldWeek(
        _dateKey(_selectedDay),
      );
      if (mounted) {
        _showMessage(
          '${result['created'] ?? 0} saída(s) repetida(s); ${result['skipped'] ?? 0} já existiam.',
        );
      }
    } on Object catch (error) {
      if (mounted) _showMessage(_friendlyError(error), isError: true);
    }
  }

  Future<void> _exportSchedule() async {
    final today = DateTime.now();
    var daysUntilSunday = DateTime.sunday - today.weekday;
    if (daysUntilSunday <= 0) daysUntilSunday += 7;
    final defaultStart = DateTime(
      today.year,
      today.month,
      today.day + daysUntilSunday,
    );
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 10),
      lastDate: DateTime(today.year + 10, 12, 31),
      initialDateRange: DateTimeRange(
        start: defaultStart,
        end: defaultStart.add(const Duration(days: 6)),
      ),
      helpText: 'Escolha o período da programação',
      saveText: 'Carregar dias',
    );
    if (range == null || !mounted) return;

    setState(() => _isExportingSchedule = true);
    try {
      final from = _dateKey(range.start);
      final through = _dateKey(range.end);
      final controller = ref.read(mobileAppControllerProvider.notifier);
      final days = await controller.fieldScheduleExportDays(
        from: from,
        through: through,
      );
      if (!mounted) return;
      if (days.isEmpty) {
        _showMessage('Nenhuma saída de campo nesse período.');
        return;
      }

      setState(() => _isExportingSchedule = false);
      final selection = await _selectScheduleDays(
        from: range.start,
        through: range.end,
        days: days,
      );
      if (selection == null || !mounted) return;

      setState(() => _isExportingSchedule = true);
      final bytes = await controller.exportFieldSchedule(
        from: selection.from,
        through: selection.through,
        days: selection.days,
        title: selection.title,
        format: selection.format,
      );
      if (!mounted) return;

      final isPdf = selection.format == 'pdf';
      await FieldScheduleShareService.shareFile(
        bytes: bytes,
        fileName:
            'programacao-campo-${selection.from}-a-${selection.through}.${isPdf ? 'pdf' : 'png'}',
        mimeType: isPdf ? 'application/pdf' : 'image/png',
        title:
            'Programação de campo · ${_longDate(range.start)} a ${_longDate(range.end)}',
      );
    } on PlatformException catch (error) {
      if (mounted) {
        _showMessage(
          error.message == null
              ? 'O iPhone não conseguiu abrir o compartilhamento do arquivo.'
              : 'O iPhone não conseguiu compartilhar: ${error.message}',
          isError: true,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        final message = error is StateError
            ? error.message.toString()
            : error is MissingPluginException
            ? 'O compartilhamento não está disponível nesta instalação. Atualize o aplicativo.'
            : MobileApi.messageForError(error);
        _showMessage(message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isExportingSchedule = false);
    }
  }

  Future<_ScheduleExportSelection?> _selectScheduleDays({
    required DateTime from,
    required DateTime through,
    required List<FieldScheduleExportDay> days,
  }) async {
    final selectedDays = days.map((day) => day.dateKey).toSet();
    final titleController = TextEditingController();
    final selection = await showModalBottomSheet<_ScheduleExportSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .88,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exportar programação',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_longDate(from)} a ${_longDate(through)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setSheetState(
                        () =>
                            selectedDays
                              ..addAll(days.map((day) => day.dateKey)),
                      ),
                      child: const Text('Marcar todos'),
                    ),
                    TextButton(
                      onPressed: () => setSheetState(selectedDays.clear),
                      child: const Text('Desmarcar'),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final day = days[index];
                      final isSelected = selectedDays.contains(day.dateKey);
                      final times = day.times.join(', ');
                      return CheckboxListTile(
                        value: isSelected,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(_longDate(day.date)),
                        subtitle: Text(
                          '${day.outingsCount} saída(s)${times.isEmpty ? '' : ' · $times'}',
                        ),
                        onChanged: (checked) => setSheetState(() {
                          if (checked == true) {
                            selectedDays.add(day.dateKey);
                          } else {
                            selectedDays.remove(day.dateKey);
                          }
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Título da programação',
                    hintText: 'Arranjo para o serviço de campo',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: selectedDays.isEmpty
                      ? null
                      : () => Navigator.of(sheetContext).pop(
                          _ScheduleExportSelection(
                            from: _dateKey(from),
                            through: _dateKey(through),
                            days: _orderedSelectedDays(days, selectedDays),
                            title: titleController.text.trim(),
                            format: 'image',
                          ),
                        ),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Imagem para mensagem'),
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: selectedDays.isEmpty
                      ? null
                      : () => Navigator.of(sheetContext).pop(
                          _ScheduleExportSelection(
                            from: _dateKey(from),
                            through: _dateKey(through),
                            days: _orderedSelectedDays(days, selectedDays),
                            title: titleController.text.trim(),
                            format: 'pdf',
                          ),
                        ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Compartilhar PDF'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    titleController.dispose();
    return selection;
  }

  List<String> _orderedSelectedDays(
    List<FieldScheduleExportDay> days,
    Set<String> selectedDays,
  ) => days
      .where((day) => selectedDays.contains(day.dateKey))
      .map((day) => day.dateKey)
      .toList(growable: false);

  Future<void> _outingAction(
    String action,
    FieldOuting outing,
    FieldCalendarData calendar,
  ) async {
    final controller = ref.read(mobileAppControllerProvider.notifier);
    try {
      switch (action) {
        case 'edit':
          await _editOuting(calendar, outing: outing);
          break;
        case 'done':
          await controller.setFieldOutingSituation(
            outing.id,
            'concluida',
            month: _monthKey,
          );
          break;
        case 'cancel':
          await controller.setFieldOutingSituation(
            outing.id,
            'cancelada',
            month: _monthKey,
          );
          break;
        case 'pending':
          await controller.setFieldOutingSituation(
            outing.id,
            'pendente',
            month: _monthKey,
          );
          break;
        case 'delete':
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Excluir saída?'),
              content: const Text(
                'A programação e os vínculos desta saída serão removidos.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Excluir'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await controller.deleteFieldOuting(outing.id, month: _monthKey);
            if (mounted) _showMessage('Saída excluída.');
          }
          break;
      }
    } on Object catch (error) {
      if (mounted) _showMessage(_friendlyError(error), isError: true);
    }
  }

  Future<void> _deletePattern(
    MobileAppController controller,
    FieldOutingPattern pattern,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir padrão semanal?'),
        content: const Text(
          'As saídas já criadas no calendário serão preservadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir padrão'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await controller.deleteFieldPattern(pattern.id, month: _monthKey);
      if (mounted) {
        _showMessage('Padrão excluído; as saídas existentes foram mantidas.');
      }
    } on Object catch (error) {
      if (mounted) _showMessage(_friendlyError(error), isError: true);
    }
  }

  void _changeMonth(int difference) {
    setState(() {
      _month = DateTime(_month.year, _month.month + difference);
      if (_selectedDay.year != _month.year ||
          _selectedDay.month != _month.month) {
        _selectedDay = DateTime(_month.year, _month.month, 1);
      }
    });
    unawaited(
      ref
          .read(mobileAppControllerProvider.notifier)
          .refreshFieldCalendar(month: _monthKey),
    );
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final response = error.response?.data;
      if (response is Map) {
        final errors = response['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty && value.first is String) {
              return value.first as String;
            }
          }
        }
        final message = response['message'];
        if (message is String &&
            message.isNotEmpty &&
            message != 'The given data was invalid.') {
          return message;
        }
      }
      return MobileApi.messageForError(error);
    }
    return 'Não foi possível salvar agora. Confira a conexão e tente novamente.';
  }

  int get _currentServiceYear {
    final today = DateTime.now();
    return today.month >= 9 ? today.year + 1 : today.year;
  }

  static bool _sameDate(DateTime? first, DateTime second) =>
      first != null &&
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _longDate(DateTime date) =>
      '${date.day} de ${_monthNames[date.month - 1]} de ${date.year}';

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  static String _timeString(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  static const _monthNames = [
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
  static const _weekdays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
}

/// Trechos a que a saída se refere: cartão, ponto de entrada e ruas; quando o
/// ponto tem local próprio, endereço e referência para reconhecê-lo.
class _StreetPointsList extends StatelessWidget {
  const _StreetPointsList({required this.points});

  final List<FieldOutingStreetPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRECHOS DESTA SAÍDA',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.label, style: theme.textTheme.bodyMedium),
                if (point.streets.isNotEmpty)
                  Text(point.streets.join(', '), style: muted),
                if ((point.location?.address ?? '').isNotEmpty)
                  Text(point.location!.address, style: muted),
                if ((point.location?.reference ?? '').isNotEmpty)
                  Text('Ref.: ${point.location!.reference}', style: muted),
              ],
            ),
          ),
      ],
    );
  }
}

class _FieldMessage extends StatelessWidget {
  const _FieldMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

class _FieldDetailRow extends StatelessWidget {
  const _FieldDetailRow({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(8),
    child: Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
        if (action != null) const Icon(Icons.open_in_new_rounded, size: 16),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 150),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}

class _GroupBadge extends StatelessWidget {
  const _GroupBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: .7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ],
    ),
  );
}

class _ScheduleExportSelection {
  const _ScheduleExportSelection({
    required this.from,
    required this.through,
    required this.days,
    required this.title,
    required this.format,
  });

  final String from;
  final String through;
  final List<String> days;
  final String title;
  final String format;
}
