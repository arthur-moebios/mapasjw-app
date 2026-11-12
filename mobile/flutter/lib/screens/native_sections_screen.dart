import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart';

import '../data/mobile_api.dart';
import '../models/letter_layout.dart';
import '../models/mobile_models.dart';
import '../models/publication_citation.dart';
import '../services/field_schedule_share_service.dart';
import 'apartment_status_wizard_sheet.dart';
import 'map_point_sheets.dart';
import 'territory_details_sheet.dart';
import '../state/mobile_app_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    required this.onNavigate,
    required this.onOpenStreetCard,
    required this.onOpenCircuitOverview,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ValueChanged<StreetCardSummary> onOpenStreetCard;
  final VoidCallback onOpenCircuitOverview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mobileAppControllerProvider).requireValue;
    final controller = ref.read(mobileAppControllerProvider.notifier);
    final summary = state.dashboardSummary;
    final today = DateTime.now();
    final currentMonth = _dashboardMonthKey(today);

    if (state.isSuperAdmin && state.selectedCongregationId == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Text(
            'Estatísticas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Acompanhe o circuito ou escolha uma congregação para consultar seus dados.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _CircuitOverviewEntry(onTap: onOpenCircuitOverview),
          const SizedBox(height: 14),
          const _SectionMessage(
            icon: Icons.apartment_rounded,
            title: 'Escolha uma congregação',
            message: 'As estatísticas individuais aparecem depois que você escolhe uma congregação.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final refreshes = <Future<void>>[
          if (state.canViewTerritories ||
              state.canViewLetters ||
              state.canViewStreetCards)
            controller.refreshDashboard(force: true),
          if (state.canViewStreetCards)
            controller.refreshStreetCards(force: true),
          if (state.canViewFieldOutings)
            controller.refreshFieldCalendar(month: currentMonth, force: true),
        ];
        await Future.wait(refreshes);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Text(
            'Estatísticas',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            state.selectedCongregation?.name ??
                'Acompanhe o andamento da congregação.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (state.isSuperAdmin) ...[
            const SizedBox(height: 16),
            _CircuitOverviewEntry(onTap: onOpenCircuitOverview),
          ],
          if (state.canRecordRoutes) ...[
            const SizedBox(height: 16),
            _DashboardRouteRecorderCard(
              isStarting: state.isStartingRoute,
              isTracking: state.isTracking,
              isAutomaticTracking:
                  state.isTracking &&
                  state.trackingTerritoryId == null &&
                  state.trackingStreetCardId == null,
              pendingPoints: state.pendingRoutePoints,
              onStart: () async {
                final message = await controller.startAutomaticRoute();
                if (!context.mounted || message == null) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              },
              onStop: controller.stopRoute,
              onOpenCards: () => onNavigate('Cartões'),
            ),
          ],
          if (state.canViewFieldOutings) ...[
            const SizedBox(height: 18),
            _DashboardTodayFieldOutingsCard(
              calendar: state.fieldCalendar,
              streetCards: state.streetCards,
              isLoading: state.isLoadingFieldCalendar,
              error: state.fieldCalendarError,
              onOpen: () => onNavigate('Campo'),
              onOpenStreetCard: onOpenStreetCard,
              onRetry: () => controller.refreshFieldCalendar(
                month: currentMonth,
                force: true,
              ),
            ),
          ],
          if (state.dashboardError != null) ...[
            const SizedBox(height: 14),
            _SectionMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar as estatísticas',
              message: state.dashboardError!,
              actionLabel: 'Tentar novamente',
              onAction: () => controller.refreshDashboard(force: true),
            ),
          ],
          if (summary == null && state.isLoadingDashboard)
            const Padding(
              padding: EdgeInsets.only(top: 38),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (summary != null) ...[
            if (summary.condominiumsCount != null) ...[
              const SizedBox(height: 18),
              _DashboardLetterCard(
                summary: summary,
                onTap: () => onNavigate('Cartas'),
              ),
            ],
            if (summary.streetCardsCount != null) ...[
              const SizedBox(height: 12),
              _DashboardStreetCard(
                summary: summary,
                onTap: () => onNavigate('Cartões'),
              ),
            ],
            if (summary.territoriesCount != null) ...[
              const SizedBox(height: 12),
              _DashboardTerritoryCard(
                summary: summary,
                onTap: () => onNavigate('Mapa'),
              ),
            ],
            if (summary.condominiumsCount == null &&
                summary.territoriesCount == null &&
                summary.streetCardsCount == null)
              const Padding(
                padding: EdgeInsets.only(top: 42),
                child: _SectionMessage(
                  icon: Icons.query_stats_rounded,
                  title: 'Ainda sem estatísticas',
                  message: 'Não há dados disponíveis para as áreas que sua conta pode consultar.',
                ),
              ),
            if (summary.generatedAt != null) ...[
              const SizedBox(height: 14),
              Text(
                'Atualizado ${TimeOfDay.fromDateTime(summary.generatedAt!).format(context)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ] else if (state.dashboardError == null &&
              !state.canViewFieldOutings) ...[
            const SizedBox(height: 42),
            const _SectionMessage(
              icon: Icons.query_stats_rounded,
              title: 'Estatísticas indisponíveis',
              message: 'Sua conta ainda não tem acesso a estas estatísticas.',
            ),
          ],
        ],
      ),
    );
  }
}

class _CircuitOverviewEntry extends StatelessWidget {
  const _CircuitOverviewEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.public_outlined),
      ),
      title: const Text('Todos · Circuito RJ-14'),
      subtitle: const Text(
        'Limites e atividade agregada de todas as congregações',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _DashboardRouteRecorderCard extends StatelessWidget {
  const _DashboardRouteRecorderCard({
    required this.isStarting,
    required this.isTracking,
    required this.isAutomaticTracking,
    required this.pendingPoints,
    required this.onStart,
    required this.onStop,
    required this.onOpenCards,
  });

  final bool isStarting;
  final bool isTracking;
  final bool isAutomaticTracking;
  final int pendingPoints;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final VoidCallback onOpenCards;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = isAutomaticTracking
        ? 'Trajeto em andamento'
        : isTracking
        ? 'Outro trajeto já está ativo'
        : 'Marcar trajeto';
    final description = isAutomaticTracking
        ? 'O percurso será associado aos cartões de rua correspondentes.'
        : isTracking
        ? 'Encerre o registro iniciado pelo cartão antes de começar outro.'
        : 'Registre seu percurso agora; o sistema identificará os cartões de rua.';

    return Card(
      color: isAutomaticTracking ? colors.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isAutomaticTracking ? Icons.location_searching : Icons.route,
                  color: colors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isAutomaticTracking && pendingPoints > 0) ...[
              const SizedBox(height: 10),
              Text(
                pendingPoints == 1
                    ? '1 ponto aguardando sincronização'
                    : '$pendingPoints pontos aguardando sincronização',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: isAutomaticTracking
                  ? OutlinedButton.icon(
                      onPressed: isStarting ? null : onStop,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Encerrar trajeto'),
                    )
                  : isTracking
                  ? OutlinedButton.icon(
                      onPressed: onOpenCards,
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('Ver cartões'),
                    )
                  : FilledButton.icon(
                      onPressed: isStarting ? null : onStart,
                      icon: isStarting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                      label: Text(
                        isStarting ? 'Preparando…' : 'Iniciar trajeto',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dashboardMonthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

class _DashboardTodayFieldOutingsCard extends StatelessWidget {
  const _DashboardTodayFieldOutingsCard({
    required this.calendar,
    required this.streetCards,
    required this.isLoading,
    required this.error,
    required this.onOpen,
    required this.onOpenStreetCard,
    required this.onRetry,
  });

  final FieldCalendarData? calendar;
  final List<StreetCardSummary> streetCards;
  final bool isLoading;
  final String? error;
  final VoidCallback onOpen;
  final ValueChanged<StreetCardSummary> onOpenStreetCard;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isCurrentMonth = calendar?.month == _dashboardMonthKey(today);
    final outings = isCurrentMonth
        ? calendar!.outingsOn(today)
        : const <FieldOuting>[];
    final subtitle = isCurrentMonth
        ? '${_dashboardTodayLabel(today)} · ${outings.length} ${outings.length == 1 ? 'saída' : 'saídas'}'
        : 'Agenda de hoje';

    return _DashboardCard(
      icon: Icons.groups_2_outlined,
      title: 'Saídas de campo hoje',
      subtitle: subtitle,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (calendar == null || !isCurrentMonth) ...[
            if (isLoading)
              const LinearProgressIndicator(minHeight: 3)
            else ...[
              Text(
                error == null
                    ? 'A agenda de hoje ainda não foi carregada.'
                    : 'Não foi possível consultar as saídas de hoje.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
              ),
            ],
          ] else if (outings.isEmpty)
            Text(
              'Nenhuma saída programada para hoje.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            for (final (index, outing) in outings.indexed) ...[
              if (index > 0) const Divider(height: 22),
              _DashboardTodayOutingTile(
                outing: outing,
                streetCards: _streetCardsForOuting(outing, streetCards),
                onFallbackTap: onOpen,
                onOpenStreetCard: onOpenStreetCard,
              ),
            ],
          ],
          if (error != null && calendar != null && isCurrentMonth) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mostrando a agenda carregada anteriormente.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Atualizar')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardTodayOutingTile extends StatelessWidget {
  const _DashboardTodayOutingTile({
    required this.outing,
    required this.streetCards,
    required this.onFallbackTap,
    required this.onOpenStreetCard,
  });

  final FieldOuting outing;
  final List<StreetCardSummary> streetCards;
  final VoidCallback onFallbackTap;
  final ValueChanged<StreetCardSummary> onOpenStreetCard;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (outing.situation) {
      'concluida' => const Color(0xFF34745A),
      'cancelada' => colors.error,
      _ => const Color(0xFFB7791F),
    };
    final groupLabel = outing.allGroups
        ? 'Todos os grupos'
        : outing.groups.map((group) => group.name).join(' · ');

    final tapLabel = streetCards.length == 1
        ? 'Abrir cartão ${_streetCardDisplayName(streetCards.single)}'
        : streetCards.isEmpty
        ? 'Abrir agenda de campo'
        : 'Escolher um dos ${streetCards.length} cartões de rua';

    return Semantics(
      button: true,
      label: tapLabel,
      child: InkWell(
        onTap: streetCards.isEmpty
            ? onFallbackTap
            : () => _openStreetCard(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 62,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      outing.time.isEmpty ? '—:—' : outing.time,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          outing.location?.name ?? 'Local a definir',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (outing.location?.address.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            outing.location!.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DashboardStatusBadge(
                    label: outing.situationLabel,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (groupLabel.isNotEmpty)
                    _DashboardOutingBadge(
                      icon: Icons.groups_outlined,
                      label: groupLabel,
                    ),
                  if (outing.leader.isNotEmpty)
                    _DashboardOutingBadge(
                      icon: Icons.person_outline_rounded,
                      label: outing.leader,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'CARTÕES ALCANÇADOS PELO LOCAL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              if (outing.territoryCards.isEmpty)
                Text(
                  outing.location == null
                      ? 'Defina um local para identificar os cartões.'
                      : 'Nenhum cartão em aberto está associado a este local.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: outing.territoryCards
                      .map(
                        (card) => _DashboardOutingBadge(
                          icon: Icons.map_outlined,
                          label: card.label,
                          emphasized: true,
                        ),
                      )
                      .toList(growable: false),
                ),
              if (streetCards.isNotEmpty) ...[
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(Icons.route_outlined, size: 17, color: colors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        streetCards.length == 1
                            ? 'Abrir cartão de rua · ${_streetCardDisplayName(streetCards.single)}'
                            : '${streetCards.length} cartões de rua · toque para escolher',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStreetCard(BuildContext context) async {
    if (streetCards.length == 1) {
      onOpenStreetCard(streetCards.single);
      return;
    }

    final selectedCard = await showModalBottomSheet<StreetCardSummary>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escolha o cartão de rua',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Este local alcança mais de um cartão. Selecione o cartão relacionado ao percurso.',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              for (final card in streetCards)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.route_outlined),
                  title: Text(_streetCardDisplayName(card)),
                  subtitle: Text(
                    [
                      if (card.neighborhood.isNotEmpty) card.neighborhood,
                      '${card.streetsCount} ${card.streetsCount == 1 ? 'rua' : 'ruas'}',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(sheetContext).pop(card),
                ),
            ],
          ),
        ),
      ),
    );

    if (selectedCard != null && context.mounted) {
      onOpenStreetCard(selectedCard);
    }
  }
}

List<StreetCardSummary> _streetCardsForOuting(
  FieldOuting outing,
  List<StreetCardSummary> streetCards,
) {
  final territoryIds = outing.territoryCards.map((card) => card.id).toSet();
  if (territoryIds.isEmpty) return const [];

  return streetCards
      .where(
        (streetCard) =>
            streetCard.originTerritoryId != null &&
            territoryIds.contains(streetCard.originTerritoryId),
      )
      .toList(growable: false);
}

String _streetCardDisplayName(StreetCardSummary card) =>
    [card.code, card.name].where((part) => part.isNotEmpty).join(' · ');

class _DashboardOutingBadge extends StatelessWidget {
  const _DashboardOutingBadge({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: emphasized ? colors.primary : null),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: emphasized ? colors.primary : null,
                fontWeight: emphasized ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatusBadge extends StatelessWidget {
  const _DashboardStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w700),
    ),
  );
}

String _dashboardTodayLabel(DateTime date) {
  const monthNames = [
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
  return '${date.day} de ${monthNames[date.month - 1]}';
}

class _DashboardLetterCard extends StatelessWidget {
  const _DashboardLetterCard({required this.summary, required this.onTap});

  final MobileDashboardSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = summary.apartmentsCount ?? 0;
    final delivered = summary.deliveredCount ?? 0;
    final progress = (summary.progressPercent ?? 0).clamp(0, 100) / 100;
    final campaignLabel = summary.campaignName == null
        ? 'Sem campanha ativa'
        : '${summary.campaignIsOpen == true ? 'Campanha aberta' : 'Campanha em uso'} · ${summary.campaignName}';

    return _DashboardCard(
      icon: Icons.mail_outline_rounded,
      title: 'Cartas',
      subtitle: campaignLabel,
      onTap: onTap,
      child: summary.campaignName == null
          ? Text(
              '${summary.condominiumsCount ?? 0} condomínios · $total endereços cadastrados',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$delivered',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 7, bottom: 5),
                      child: Text('de $total entregues'),
                    ),
                    const Spacer(),
                    _CountBadge(
                      count: summary.progressPercent ?? 0,
                      label: '%',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: progress, minHeight: 8),
                ),
                if (summary.letterStatuses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: summary.letterStatuses
                        .where((status) => status.count > 0)
                        .map(
                          (status) => _LetterStatusBadge(
                            label: '${status.label} · ${status.count}',
                            color: status.color,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '${summary.condominiumsCount ?? 0} condomínios · ${summary.workedCount ?? 0} endereços trabalhados',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}

class _DashboardTerritoryCard extends StatelessWidget {
  const _DashboardTerritoryCard({required this.summary, required this.onTap});

  final MobileDashboardSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _DashboardCard(
    icon: Icons.layers_outlined,
    title: 'Limites históricos',
    subtitle: '${summary.territoriesCount} referências KML',
    onTap: onTap,
    child: Text(
      'Os limites e indicadores de cobertura pertencem ao cadastro antigo. '
      'O andamento atual é acompanhado pelos cartões de rua.',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

google_maps.LatLng _googleLatLng(LatLng point) =>
    google_maps.LatLng(point.latitude, point.longitude);

class _DashboardStreetCard extends StatelessWidget {
  const _DashboardStreetCard({required this.summary, required this.onTap});

  final MobileDashboardSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _DashboardCard(
    icon: Icons.route_outlined,
    title: 'Cartões de rua',
    subtitle: '${summary.streetCardsCount} cartões',
    onTap: onTap,
    child: Row(
      children: [
        Expanded(
          child: _DashboardNumber(
            value: summary.streetSegmentsCount ?? 0,
            label: 'trechos de rua',
          ),
        ),
        Expanded(
          child: _DashboardNumber(
            value: summary.streetEntrancesCount ?? 0,
            label: 'entradas marcadas',
          ),
        ),
      ],
    ),
  );
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    ),
  );
}

class _DashboardNumber extends StatelessWidget {
  const _DashboardNumber({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$value',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class LettersScreen extends ConsumerStatefulWidget {
  const LettersScreen({super.key});

  @override
  ConsumerState<LettersScreen> createState() => _LettersScreenState();
}

class _LettersScreenState extends ConsumerState<LettersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final state = ref.watch(mobileAppControllerProvider).requireValue;
    final controller = ref.read(mobileAppControllerProvider.notifier);

    if (state.selectedCongregationId == null && state.isSuperAdmin) {
      return const _SectionMessage(
        icon: Icons.apartment_rounded,
        title: 'Escolha uma congregação',
        message: 'Selecione uma congregação para consultar as cartas e os endereços.',
      );
    }
    if (!state.canViewLetters) {
      return const _SectionMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Acesso não habilitado',
        message: 'Seu perfil não tem permissão para consultar Cartas.',
      );
    }

    if (state.isLoadingLetters && state.condominiums.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final campaignNames = state.condominiums
        .map((condominium) => condominium.campaignName)
        .whereType<String>()
        .toList(growable: false);
    final campaignName = campaignNames.isEmpty ? null : campaignNames.first;
    final normalizedQuery = _normalizeLetterSearch(_searchQuery);
    final filteredCondominiums = state.condominiums
        .where((condominium) {
          final searchText = _normalizeLetterSearch(
            '${condominium.code} ${condominium.name} ${condominium.address}',
          );
          if (normalizedQuery.isNotEmpty &&
              !searchText.contains(normalizedQuery)) {
            return false;
          }

          return switch (_filter) {
            'abertos' =>
              condominium.displayedApartmentsCount > 0 &&
                  condominium.progressPercent != null &&
                  condominium.progressPercent! < 100,
            'concluidos' =>
              condominium.displayedApartmentsCount > 0 &&
                  condominium.progressPercent == 100,
            'bloqueados' => condominium.isBlocked,
            _ => true,
          };
        })
        .toList(growable: false);
    final openCount = state.condominiums
        .where(
          (condominium) =>
              condominium.displayedApartmentsCount > 0 &&
              condominium.progressPercent != null &&
              condominium.progressPercent! < 100,
        )
        .length;
    final completedCount = state.condominiums
        .where(
          (condominium) =>
              condominium.displayedApartmentsCount > 0 &&
              condominium.progressPercent == 100,
        )
        .length;
    final blockedCount = state.condominiums
        .where((condominium) => condominium.isBlocked)
        .length;

    return RefreshIndicator(
      onRefresh: () => controller.refreshCondominiums(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Text('Cartas', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          Text(
            'Acompanhe os endereços e atualize o andamento das cartas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (campaignName != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _LetterCampaignBadge(name: campaignName),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Pesquisar código, nome ou endereço',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar pesquisa',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 1,
            runSpacing: 0,
            children: [
              _LetterFilterChip(
                label: 'Todos',
                count: state.condominiums.length,
                selected: _filter == 'todos',
                onSelected: () => setState(() => _filter = 'todos'),
              ),
              _LetterFilterChip(
                label: 'Em aberto',
                count: openCount,
                selected: _filter == 'abertos',
                onSelected: () => setState(() => _filter = 'abertos'),
              ),
              _LetterFilterChip(
                label: 'Concluídos',
                count: completedCount,
                selected: _filter == 'concluidos',
                onSelected: () => setState(() => _filter = 'concluidos'),
              ),
              _LetterFilterChip(
                label: 'Bloqueados',
                count: blockedCount,
                selected: _filter == 'bloqueados',
                onSelected: () => setState(() => _filter = 'bloqueados'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.lettersError != null) ...[
            const SizedBox(height: 14),
            _SectionMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar Cartas',
              message: state.lettersError!,
              actionLabel: 'Tentar novamente',
              onAction: () => controller.refreshCondominiums(force: true),
            ),
          ],
          if (state.condominiums.isEmpty && state.lettersError == null)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: _SectionMessage(
                icon: Icons.mail_outline_rounded,
                title: 'Nenhum endereço disponível',
                message: 'Os condomínios autorizados aparecerão aqui.',
              ),
            ),
          if (state.condominiums.isNotEmpty && filteredCondominiums.isEmpty)
            const _SectionMessage(
              icon: Icons.search_off_rounded,
              title: 'Nenhum local encontrado',
              message: 'Tente mudar a pesquisa ou o filtro selecionado.',
            ),
          ...filteredCondominiums.map(
            (condominium) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _CondominiumListCard(
                condominium: condominium,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CondominiumLettersScreen(condominium: condominium),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _normalizeLetterSearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c')
    .trim();

class _LetterCampaignBadge extends StatelessWidget {
  const _LetterCampaignBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.campaign_outlined, size: 16),
          const SizedBox(width: 6),
          Text(
            'Campanha · $name',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    ),
  );
}

class _LetterFilterChip extends StatelessWidget {
  const _LetterFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      label: Text('$label · $count'),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    ),
  );
}

class _CondominiumListCard extends StatelessWidget {
  const _CondominiumListCard({required this.condominium, required this.onTap});

  final CondominiumSummary condominium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = condominium.progressPercent;
    final progressColor = progress == null
        ? colors.primary
        : progress >= 100
        ? const Color(0xFF26734D)
        : progress == 0
        ? const Color(0xFFB64E4E)
        : const Color(0xFFB66427);
    final count = condominium.displayedApartmentsCount;
    final countLabel = condominium.assignmentLimited
        ? '$count designado(s)'
        : '$count ${count == 1 ? 'endereço' : 'endereços'}';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: progressColor, width: 5)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: progressColor.withValues(alpha: .12),
                      foregroundColor: progressColor,
                      child: const Icon(Icons.apartment_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (condominium.code.isNotEmpty)
                            Text(
                              condominium.code,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          Text(
                            condominium.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                if (condominium.address.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  Text(
                    condominium.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _LetterInfoBadge(
                      icon: Icons.mail_outline_rounded,
                      label: countLabel,
                    ),
                    if (condominium.blocksCount > 0)
                      _LetterInfoBadge(
                        icon: Icons.domain_outlined,
                        label:
                            '${condominium.blocksCount} ${condominium.blocksCount == 1 ? 'bloco' : 'blocos'}',
                      ),
                    if (condominium.floorsCount > 0)
                      _LetterInfoBadge(
                        icon: Icons.stairs_rounded,
                        label:
                            '${condominium.floorsCount} ${condominium.floorsCount == 1 ? 'andar' : 'andares'}',
                      ),
                    if (condominium.isBlocked)
                      const _LetterInfoBadge(
                        icon: Icons.lock_outline_rounded,
                        label: 'Bloqueado',
                        isAlert: true,
                      ),
                  ],
                ),
                if (progress != null) ...[
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0, 100) / 100,
                            minHeight: 8,
                            color: progressColor,
                            backgroundColor: progressColor.withValues(
                              alpha: .16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$progress%',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: progressColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${condominium.deliveredCount} de $count entregues${condominium.campaignName == null ? '' : ' · ${condominium.campaignName}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterInfoBadge extends StatelessWidget {
  const _LetterInfoBadge({
    required this.icon,
    required this.label,
    this.isAlert = false,
  });

  final IconData icon;
  final String label;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final color = isAlert
        ? const Color(0xFFB64E4E)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isAlert
            ? color.withValues(alpha: .1)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class CondominiumLettersScreen extends ConsumerStatefulWidget {
  const CondominiumLettersScreen({required this.condominium, super.key});

  final CondominiumSummary condominium;

  @override
  ConsumerState<CondominiumLettersScreen> createState() =>
      _CondominiumLettersScreenState();
}

class _CondominiumLettersScreenState
    extends ConsumerState<CondominiumLettersScreen> {
  late Future<CondominiumDetail> _detail;
  int? _campaignId;
  int? _savingApartmentId;

  /// Blocos recolhidos (chave de [LetterBlockGroup]); sobrevive ao recarregar.
  final Set<String> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    _detail = ref
        .read(mobileAppControllerProvider.notifier)
        .loadCondominium(widget.condominium.id);
  }

  void _load({int? campaignId}) {
    setState(() {
      _campaignId = campaignId;
      _detail = ref
          .read(mobileAppControllerProvider.notifier)
          .loadCondominium(widget.condominium.id, campaignId: campaignId);
    });
  }

  Future<void> _refresh() async => _load(campaignId: _campaignId);

  void _toggleGroup(String key) => setState(() {
    if (!_collapsedGroups.remove(key)) _collapsedGroups.add(key);
  });

  void _toggleAllGroups(List<LetterBlockGroup> groups) => setState(() {
    final allCollapsed = groups.every((g) => _collapsedGroups.contains(g.key));
    if (allCollapsed) {
      _collapsedGroups.removeAll(groups.map((g) => g.key));
    } else {
      _collapsedGroups.addAll(groups.map((g) => g.key));
    }
  });

  Future<Uint8List> _generateQr(QrOption option) =>
      ref.read(mobileAppControllerProvider.notifier).publicationQrPdf(option);

  Future<void> _shareQr(
    Uint8List bytes,
    QrOption option,
  ) => FieldScheduleShareService.shareFile(
    bytes: bytes,
    fileName:
        'qr-${normalizeSearch(option.code.isEmpty ? option.title : option.code).replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.pdf',
    mimeType: 'application/pdf',
    title: 'QR · ${option.label}',
  );

  Future<void> _chooseStatus(
    CondominiumDetail detail,
    ApartmentLetter apartment,
  ) async {
    if (!apartment.canUpdate || detail.campaign == null) return;
    final controller = ref.read(mobileAppControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ApartmentStatusWizardSheet(
          detail: detail,
          apartment: apartment,
          today: DateTime.now,
          loadCatalog: () => controller.loadPublicationCatalog(detail),
          generateQr: _generateQr,
          shareQr: _shareQr,
          loadHistory: () => controller.loadApartmentHistory(
            condominiumId: detail.id,
            campaignId: detail.campaign!.id,
            apartmentId: apartment.id,
          ),
          onSave: (payload) async {
            if (!mounted) return 'Esta tela não está mais disponível.';
            setState(() => _savingApartmentId = apartment.id);
            final message = await controller.updateApartmentStatus(
              condominiumId: detail.id,
              campaignId: detail.campaign!.id,
              apartment: apartment,
              payload: payload,
            );
            if (!mounted) return message;
            setState(() => _savingApartmentId = null);
            if (message == null) {
              _load(campaignId: detail.campaign!.id);
            }
            return message;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.condominium.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: FutureBuilder<CondominiumDetail>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _SectionMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Não foi possível abrir os endereços',
            message: snapshot.error?.toString() ?? 'Tente novamente.',
            actionLabel: 'Tentar novamente',
            onAction: _refresh,
          );
        }

        final detail = snapshot.data!;
        final canSelectCampaign =
            detail.canChooseCampaign && detail.campaigns.isNotEmpty;
        final groups = LetterLayout.group(detail.apartments);
        final canTap = detail.canUpdateStatus;
        final allCollapsed =
            groups.isNotEmpty &&
            groups.every((group) => _collapsedGroups.contains(group.key));
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: [
              if (detail.address.isNotEmpty)
                _InfoCard(icon: Icons.place_outlined, text: detail.address),
              if (detail.observations.isNotEmpty)
                _InfoCard(
                  icon: Icons.info_outline_rounded,
                  text: detail.observations,
                ),
              if (canSelectCampaign)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<int>(
                    initialValue: _campaignId ?? detail.campaign?.id,
                    decoration: const InputDecoration(
                      labelText: 'Campanha',
                      border: OutlineInputBorder(),
                    ),
                    items: detail.campaigns
                        .map(
                          (campaign) => DropdownMenuItem(
                            value: campaign.id,
                            child: Text(
                              campaign.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (id) {
                      if (id != null) _load(campaignId: id);
                    },
                  ),
                )
              else if (detail.campaign != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InfoCard(
                    icon: Icons.campaign_outlined,
                    text: 'Campanha atual: ${detail.campaign!.name}',
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Endereços',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _CountBadge(
                    count: detail.apartments.length,
                    label: 'unidades',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (detail.statuses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: detail.statuses
                        .map((status) {
                          final count = detail.apartments
                              .where(
                                (apartment) => apartment.status == status.slug,
                              )
                              .length;
                          return _LetterStatusBadge(
                            label:
                                '${status.label} · $count${status.countsAsDelivered ? ' · entregue' : ''}',
                            color: status.color,
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              if (detail.apartments.isEmpty)
                const _SectionMessage(
                  icon: Icons.mail_outline_rounded,
                  title: 'Nenhum endereço nesta lista',
                  message:
                      'Confira a campanha selecionada ou suas designações.',
                ),
              if (groups.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _toggleAllGroups(groups),
                    icon: Icon(
                      allCollapsed
                          ? Icons.unfold_more_rounded
                          : Icons.unfold_less_rounded,
                    ),
                    label: Text(
                      allCollapsed
                          ? 'Expandir todos os blocos'
                          : 'Recolher todos os blocos',
                    ),
                  ),
                ),
              ...groups.map(
                (group) => _LetterBlockCard(
                  group: group,
                  statuses: detail.statuses,
                  expanded: !_collapsedGroups.contains(group.key),
                  savingApartmentId: _savingApartmentId,
                  canTap: canTap,
                  onToggle: () => _toggleGroup(group.key),
                  onTapApartment: (apartment) =>
                      _chooseStatus(detail, apartment),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class StreetCardsScreen extends ConsumerStatefulWidget {
  const StreetCardsScreen({super.key});

  @override
  ConsumerState<StreetCardsScreen> createState() => _StreetCardsScreenState();
}

class _StreetCardsScreenState extends ConsumerState<StreetCardsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedNeighborhood;
  String? _selectedGroup;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showMapImport(MobileAppController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _TerritoryMapImportSheet(
        controller: controller,
        onImported: () => controller.refreshStreetCards(force: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mobileAppControllerProvider).requireValue;
    final controller = ref.read(mobileAppControllerProvider.notifier);
    if (state.selectedCongregationId == null && state.isSuperAdmin) {
      return const _SectionMessage(
        icon: Icons.apartment_rounded,
        title: 'Escolha uma congregação',
        message: 'Selecione uma congregação para abrir seus cartões de rua.',
      );
    }
    if (!state.canViewStreetCards) {
      return const _SectionMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Acesso não habilitado',
        message: 'Seu perfil não tem permissão para consultar cartões de rua.',
      );
    }
    if (state.isLoadingStreetCards && state.streetCards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final neighborhoods = _streetCardFilterOptions(
      state.streetCards.map((card) => card.neighborhood),
    );
    final groups = _streetCardFilterOptions(
      state.streetCards.map((card) => card.group),
    );
    final selectedNeighborhood = neighborhoods.contains(_selectedNeighborhood)
        ? _selectedNeighborhood
        : null;
    final selectedGroup = groups.contains(_selectedGroup)
        ? _selectedGroup
        : null;
    final filteredCards = state.streetCards
        .where(
          (card) => card.matchesFilters(
            searchQuery: _searchQuery,
            neighborhoodFilter: selectedNeighborhood,
            groupFilter: selectedGroup,
          ),
        )
        .toList(growable: false);
    final activeFilterCount =
        (selectedNeighborhood == null ? 0 : 1) +
        (selectedGroup == null ? 0 : 1);

    return RefreshIndicator(
      onRefresh: () => controller.refreshStreetCards(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Text(
            'Cartões de rua',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 5),
          Text(
            'Pesquise pelo cartão ou por uma rua e filtre por bairro ou grupo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (state.canManageTerritoryCards) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.map_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gerar cartões pelo mapa',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Importe os polígonos da congregação e encontre as ruas automaticamente.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => _showMapImport(controller),
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Importar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Nome, código ou rua',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar pesquisa',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showStreetCardFilters(
                  neighborhoods: neighborhoods,
                  groups: groups,
                  selectedNeighborhood: selectedNeighborhood,
                  selectedGroup: selectedGroup,
                ),
                icon: const Icon(Icons.tune_rounded),
                label: Text(
                  activeFilterCount == 0
                      ? 'Filtrar bairro e grupo'
                      : 'Filtros · $activeFilterCount',
                ),
              ),
              const Spacer(),
              Text(
                '${filteredCards.length} de ${state.streetCards.length}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (state.streetCardsError != null) ...[
            const SizedBox(height: 14),
            _SectionMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar os cartões',
              message: state.streetCardsError!,
              actionLabel: 'Tentar novamente',
              onAction: () => controller.refreshStreetCards(force: true),
            ),
          ],
          if (state.streetCards.isEmpty && state.streetCardsError == null)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: _SectionMessage(
                icon: Icons.route_outlined,
                title: 'Nenhum cartão de rua disponível',
                message: 'Os cartões cadastrados para esta congregação aparecerão aqui.',
              ),
            ),
          if (state.streetCards.isNotEmpty && filteredCards.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 26),
              child: _SectionMessage(
                icon: Icons.search_off_rounded,
                title: 'Nenhum cartão encontrado',
                message: 'Tente outro nome de rua ou remova os filtros selecionados.',
                actionLabel: 'Limpar pesquisa e filtros',
                onAction: _clearStreetCardFilters,
              ),
            ),
          ...filteredCards.map(
            (card) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _StreetCardListItem(
                card: card,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StreetCardDetailScreen(card: card),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStreetCardFilters({
    required List<String> neighborhoods,
    required List<String> groups,
    required String? selectedNeighborhood,
    required String? selectedGroup,
  }) async {
    var draftNeighborhood = selectedNeighborhood;
    var draftGroup = selectedGroup;
    final filters =
        await showModalBottomSheet<({String? neighborhood, String? group})>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setSheetState) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Filtrar cartões',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: draftNeighborhood ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Bairro'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Todos os bairros'),
                        ),
                        ...neighborhoods.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (value) => setSheetState(
                        () => draftNeighborhood = value == null || value.isEmpty
                            ? null
                            : value,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: draftGroup ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Grupo'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Todos os grupos'),
                        ),
                        ...groups.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (value) => setSheetState(
                        () => draftGroup = value == null || value.isEmpty
                            ? null
                            : value,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setSheetState(() {
                            draftNeighborhood = null;
                            draftGroup = null;
                          }),
                          child: const Text('Limpar filtros'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop((
                            neighborhood: draftNeighborhood,
                            group: draftGroup,
                          )),
                          child: const Text('Mostrar cartões'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    if (!mounted || filters == null) return;
    setState(() {
      _selectedNeighborhood = filters.neighborhood;
      _selectedGroup = filters.group;
    });
  }

  void _clearStreetCardFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedNeighborhood = null;
      _selectedGroup = null;
    });
  }
}

class _TerritoryMapImportSheet extends StatefulWidget {
  const _TerritoryMapImportSheet({
    required this.controller,
    required this.onImported,
  });

  final MobileAppController controller;
  final Future<void> Function() onImported;

  @override
  State<_TerritoryMapImportSheet> createState() =>
      _TerritoryMapImportSheetState();
}

class _TerritoryMapImportSheetState extends State<_TerritoryMapImportSheet> {
  static const MethodChannel _filePicker = MethodChannel(
    'br.com.mapasjw.cartas/map_import',
  );
  static const int _maximumFileBytes = 20 * 1024 * 1024;

  final TextEditingController _mapsUrlController = TextEditingController();
  List<int>? _fileBytes;
  String? _fileName;
  Map<String, dynamic>? _preview;
  String? _errorMessage;
  bool _isBusy = false;
  bool _isImported = false;
  bool _selectionSimulated = false;
  Set<String> _selectedTerritoryCodes = {};

  @override
  void dispose() {
    _mapsUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final selection = await _filePicker.invokeMapMethod<String, Object?>(
        'pickMapFile',
      );
      if (!mounted || selection == null) return;

      final fileName = selection['fileName'] as String? ?? 'territorios.kml';
      final bytes = selection['bytes'];
      final extension = fileName.split('.').last.toLowerCase();
      if (bytes is! List<int>) {
        throw StateError('Não consegui ler o arquivo selecionado.');
      }
      if (!{'kml', 'kmz', 'xml'}.contains(extension)) {
        throw StateError('Escolha um arquivo KML ou KMZ.');
      }
      if (bytes.isEmpty || bytes.length > _maximumFileBytes) {
        throw StateError('O arquivo deve ter até 20 MB.');
      }

      setState(() {
        _fileName = fileName;
        _fileBytes = bytes;
        _mapsUrlController.clear();
        _preview = null;
        _selectedTerritoryCodes = {};
        _selectionSimulated = false;
        _errorMessage = null;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _errorMessage = error.message ?? 'Não consegui abrir os arquivos.',
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(error));
    }
  }

  Future<void> _simulate() => _submit(simulate: true);

  Future<void> _simulateSelection() => _submit(
    simulate: true,
    territoryCodes: _selectedTerritoryCodes.toList()..sort(),
  );

  Future<void> _submit({
    required bool simulate,
    List<String>? territoryCodes,
  }) async {
    if (_isBusy || _isImported) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.controller.importTerritoryMap(
        simulate: simulate,
        fileBytes: _fileBytes,
        fileName: _fileName,
        mapsUrl: _fileBytes == null ? _mapsUrlController.text : null,
        territoryCodes: territoryCodes,
      );
      if (!mounted) return;

      setState(() {
        _preview = response;
        _isImported = !simulate;
        if (!simulate || territoryCodes != null) {
          _selectionSimulated = true;
        } else {
          final territories = _territoriesFrom(response);
          _selectedTerritoryCodes = territories.length == 1
              ? {_territoryKey(territories.single)}
              : {};
          _selectionSimulated = territories.length == 1;
        }
      });
      if (!simulate) {
        await widget.onImported();
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerar cartões de rua?'),
        content: Text(
          'A prévia encontrou ${_count('criados')} território(s) novo(s) e '
          '${_count('atualizados')} cartão(ões) existente(s) com ruas que '
          'ainda não estão representadas. Serão preparados '
          '${_count('cartoes_rua_preparados')} cartão(ões) de rua com '
          '${_count('trechos_rua_preparados')} trecho(s) novo(s); '
          '${_count('territorios_ja_contemplados')} território(s) já coberto(s) '
          'serão ignorados. O histórico e os trajetos existentes serão mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Gerar cartões'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final territoryCodes = _selectedTerritoryCodes.toList()..sort();
      await _submit(simulate: false, territoryCodes: territoryCodes);
    }
  }

  int _count(String key) {
    final result = _preview?['resultado'];
    if (result is! Map) return 0;
    return (result[key] as num?)?.toInt() ?? 0;
  }

  List<String> _sampleNames() {
    final result = _preview?['resultado'];
    final sample = result is Map ? result['amostra'] : null;
    if (sample is! List) return const [];
    return sample
        .whereType<Map>()
        .map((item) => '${item['codigo'] ?? ''} · ${item['nome'] ?? ''}'.trim())
        .where((name) => name != '·')
        .take(4)
        .toList(growable: false);
  }

  List<String> _distributionSummary() {
    final result = _preview?['resultado'];
    final distribution = result is Map ? result['distribuicao'] : null;
    if (distribution is! List) return const [];
    return distribution
        .whereType<Map>()
        .map((item) {
          final existing = item['tipo'] == 'cartao_existente';
          final label = existing ? 'Cartão existente' : 'Fora dos limites';
          return '$label · ${item['codigo'] ?? ''} · ${item['nome'] ?? ''} · '
              '${item['trechos'] ?? 0} trecho(s)';
        })
        .take(8)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _territories() => _territoriesFrom(_preview ?? {});

  List<Map<String, dynamic>> _territoriesFrom(Map<String, dynamic> response) {
    final result = response['resultado'];
    final territories = result is Map ? result['territorios'] : null;
    if (territories is! List) return const [];
    return territories
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  String _territoryCode(Map<String, dynamic> territory) =>
      '${territory['codigo'] ?? ''}'.trim();

  String _territoryKey(Map<String, dynamic> territory) =>
      '${territory['chave'] ?? _territoryCode(territory)}'.trim();

  String _territoryStatus(Map<String, dynamic> territory) {
    final status = territory['situacao'];
    return switch (status) {
      'trechos_novos' => '${territory['trechos_novos'] ?? 0} trecho(s) novo(s)',
      'ja_contemplado' => 'Ruas já representadas',
      'sem_ruas' => 'Sem ruas nomeadas no mapa',
      _ => 'Aguardando seleção para conferir',
    };
  }

  void _setAllTerritoriesSelected(bool selected) {
    setState(() {
      _selectedTerritoryCodes = selected
          ? _territories()
                .map(_territoryKey)
                .where((key) => key.isNotEmpty)
                .toSet()
          : {};
      _selectionSimulated = false;
    });
  }

  Widget _territorySelection(ThemeData theme) {
    final territories = _territories();
    if (territories.isEmpty) return const SizedBox.shrink();

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quais territórios são desta congregação?',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Selecione somente os seus. O mapa pode conter territórios de outras localidades.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (territories.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isBusy
                      ? null
                      : () => _setAllTerritoriesSelected(true),
                  child: const Text('Selecionar todos'),
                ),
              ),
            for (final territory in territories)
              CheckboxListTile(
                value: _selectedTerritoryCodes.contains(
                  _territoryKey(territory),
                ),
                onChanged: _isBusy
                    ? null
                    : (selected) => setState(() {
                        final code = _territoryKey(territory);
                        if (selected == true) {
                          _selectedTerritoryCodes.add(code);
                        } else {
                          _selectedTerritoryCodes.remove(code);
                        }
                        _selectionSimulated = false;
                      }),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${_territoryCode(territory)}${(territory['nome'] as String? ?? '').trim().isEmpty ? '' : ' · ${territory['nome']}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_territoryStatus(territory)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            if (_selectedTerritoryCodes.isNotEmpty && !_selectionSimulated)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'A seleção mudou. Confira novamente os números antes de importar.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _warnings() {
    final result = _preview?['resultado'];
    final warnings = result is Map ? result['avisos'] : null;
    if (warnings is! List) return const [];
    return warnings.whereType<String>().take(4).toList(growable: false);
  }

  String _friendlyError(Object error) {
    if (error is DioException) return MobileApi.messageForError(error);
    return error.toString().replaceFirst('Bad state: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Importar mapa da congregação',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Depois da análise, escolha os territórios desta congregação. Só ruas ainda não representadas serão acrescentadas aos cartões.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _pickFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Escolher arquivo KML ou KMZ'),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.map_outlined),
                title: Text(
                  _fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${((_fileBytes?.length ?? 0) / 1024).ceil()} KB',
                ),
                trailing: IconButton(
                  tooltip: 'Remover arquivo',
                  onPressed: _isBusy
                      ? null
                      : () => setState(() {
                          _fileName = null;
                          _fileBytes = null;
                          _preview = null;
                          _selectedTerritoryCodes = {};
                          _selectionSimulated = false;
                        }),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _mapsUrlController,
              enabled: !_isBusy,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onChanged: (value) {
                if (value.trim().isNotEmpty && _fileBytes != null) {
                  setState(() {
                    _fileName = null;
                    _fileBytes = null;
                    _preview = null;
                    _selectedTerritoryCodes = {};
                    _selectionSimulated = false;
                  });
                } else if (_preview != null) {
                  setState(() {
                    _preview = null;
                    _selectedTerritoryCodes = {};
                    _selectionSimulated = false;
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Ou link/código do Google My Maps',
                hintText: 'Cole o link ou o código <iframe>',
                prefixIcon: Icon(Icons.link_rounded),
                border: OutlineInputBorder(),
                counterText: '',
              ),
              maxLength: 2048,
            ),
            const SizedBox(height: 8),
            Text(
              'O mapa precisa estar compartilhado para qualquer pessoa com o link. Você pode colar a URL ou o código de incorporação. Links de rotas comuns não incluem polígonos.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 16),
              _territorySelection(theme),
              const SizedBox(height: 8),
              if (!_selectionSimulated)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _selectedTerritoryCodes.isEmpty
                        ? 'Marque os territórios da congregação para conferir somente esses itens.'
                        : 'A prévia abaixo ainda não corresponde à seleção atual. Confira novamente antes de importar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              _ImportMapSummary(
                count: _count,
                sampleNames: _sampleNames(),
                distribution: _distributionSummary(),
                warnings: _warnings(),
                imported: _isImported,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            if (_isImported)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Concluir'),
              )
            else if (_preview == null)
              FilledButton.icon(
                onPressed: _isBusy ? null : _simulate,
                icon: _isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(
                  _isBusy ? 'Analisando mapa…' : 'Conferir sem gravar',
                ),
              )
            else if (!_selectionSimulated)
              FilledButton.icon(
                onPressed: _isBusy || _selectedTerritoryCodes.isEmpty
                    ? null
                    : _simulateSelection,
                icon: _isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(
                  _isBusy
                      ? 'Conferindo seleção…'
                      : 'Conferir ${_selectedTerritoryCodes.length} selecionado(s)',
                ),
              )
            else
              FilledButton.icon(
                onPressed: _isBusy ? null : _confirmImport,
                icon: _isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _isBusy ? 'Gerando cartões…' : 'Importar selecionados',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImportMapSummary extends StatelessWidget {
  const _ImportMapSummary({
    required this.count,
    required this.sampleNames,
    required this.distribution,
    required this.warnings,
    required this.imported,
  });

  final int Function(String key) count;
  final List<String> sampleNames;
  final List<String> distribution;
  final List<String> warnings;
  final bool imported;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              imported ? 'Importação concluída' : 'Prévia da importação',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ImportCountChip('Territórios novos', count('criados')),
                _ImportCountChip('Com ruas novas', count('atualizados')),
                _ImportCountChip('Cartões', count('cartoes_rua_preparados')),
                _ImportCountChip(
                  'Trechos novos',
                  count('trechos_rua_preparados'),
                ),
                _ImportCountChip('Sem ruas', count('territorios_sem_ruas')),
                _ImportCountChip(
                  'Já cobertos',
                  count('territorios_ja_contemplados'),
                ),
                _ImportCountChip('Ignorados', count('ignorados')),
              ],
            ),
            if (!imported) ...[
              const SizedBox(height: 10),
              const Text('Esta conferência não grava nenhuma alteração.'),
            ],
            if (sampleNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Exemplos', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              for (final name in sampleNames)
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (distribution.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Destino dos trechos', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              for (final item in distribution)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(item),
                ),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Observações', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              for (final warning in warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(warning),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportCountChip extends StatelessWidget {
  const _ImportCountChip(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text('$label · $count'),
    visualDensity: VisualDensity.compact,
  );
}

List<String> _streetCardFilterOptions(Iterable<String> values) {
  final options = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return options;
}

class _StreetCardListItem extends StatelessWidget {
  const _StreetCardListItem({required this.card, required this.onTap});

  final StreetCardSummary card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = card.name.isNotEmpty
        ? card.name
        : 'Cartão ${card.code}'.trim();
    final visibleStreetNames = card.streetNames.take(3).toList();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.primary,
                    child: const Icon(Icons.route_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (card.code.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Cartão ${card.code}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              if (card.neighborhood.isNotEmpty || card.group.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (card.neighborhood.isNotEmpty)
                      _StreetCardBadge(
                        icon: Icons.place_outlined,
                        label: card.neighborhood,
                      ),
                    if (card.group.isNotEmpty)
                      _StreetCardBadge(
                        icon: Icons.groups_outlined,
                        label: card.group,
                      ),
                  ],
                ),
              ],
              if (card.description.isNotEmpty) ...[
                const SizedBox(height: 11),
                Text(
                  card.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'RUAS ATENDIDAS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              if (visibleStreetNames.isEmpty)
                Text(
                  'Nomes das ruas ainda não cadastrados.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    ...visibleStreetNames.map(
                      (name) => _StreetNameBadge(name: name),
                    ),
                    if (card.streetNames.length > visibleStreetNames.length)
                      _StreetNameBadge(
                        name:
                            '+${card.streetNames.length - visibleStreetNames.length}',
                        isEmphasized: true,
                      ),
                  ],
                ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StreetCardBadge(
                    icon: Icons.alt_route_rounded,
                    label:
                        '${card.streetsCount} ${card.streetsCount == 1 ? 'trecho' : 'trechos'}',
                  ),
                  _StreetCardBadge(
                    icon: Icons.meeting_room_outlined,
                    label:
                        '${card.entrancesCount} ${card.entrancesCount == 1 ? 'entrada' : 'entradas'}',
                  ),
                  if (card.originTerritoryCode.isNotEmpty)
                    _StreetCardBadge(
                      icon: Icons.map_outlined,
                      label: 'Território ${card.originTerritoryCode}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreetCardBadge extends StatelessWidget {
  const _StreetCardBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    ),
  );
}

class _StreetNameBadge extends StatelessWidget {
  const _StreetNameBadge({required this.name, this.isEmphasized = false});

  final String name;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: isEmphasized
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class StreetCardDetailScreen extends ConsumerStatefulWidget {
  const StreetCardDetailScreen({required this.card, super.key});

  final StreetCardSummary card;

  @override
  ConsumerState<StreetCardDetailScreen> createState() =>
      _StreetCardDetailScreenState();
}

class _StreetCardDetailScreenState
    extends ConsumerState<StreetCardDetailScreen> {
  late Future<StreetCardDetail> _detail;
  String? _recordedRouteDayFilter;
  int? _recordedRouteUserFilter;
  List<StreetRecordedRoute>? _serverFilteredRoutes;
  bool _isLoadingRecordedRoutes = false;
  String? _recordedRoutesError;
  int _recordedRouteFilterRequestId = 0;

  @override
  void initState() {
    super.initState();
    _detail = ref
        .read(mobileAppControllerProvider.notifier)
        .loadStreetCard(widget.card.id);
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(mobileAppControllerProvider).asData?.value;
    ref.listen(mobileAppControllerProvider, (previous, next) {
      final previousState = previous?.asData?.value;
      final currentState = next.asData?.value;
      if (previousState?.isTracking == true &&
          currentState?.isTracking == false &&
          previousState?.trackingStreetCardId == widget.card.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _detail = ref
                .read(mobileAppControllerProvider.notifier)
                .loadStreetCard(widget.card.id);
            _resetRecordedRouteFilters();
          });
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            widget.card.code,
            widget.card.name,
          ].where((part) => part.isNotEmpty).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<StreetCardDetail>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _SectionMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível abrir o cartão',
              message: snapshot.error?.toString() ?? 'Tente novamente.',
              actionLabel: 'Tentar novamente',
              onAction: () => setState(() {
                _detail = ref
                    .read(mobileAppControllerProvider.notifier)
                    .loadStreetCard(widget.card.id);
                _resetRecordedRouteFilters();
              }),
            );
          }

          final detail = snapshot.data!;
          final routeUsers = {
            for (final user in detail.recordedRouteUsers) user.id: user.name,
          };
          final selectedRouteUser =
              routeUsers.containsKey(_recordedRouteUserFilter)
              ? _recordedRouteUserFilter
              : null;
          final visibleRoutes = _serverFilteredRoutes ?? detail.recordedRoutes;
          final isTrackingThisCard =
              appState?.isTracking == true &&
              appState?.trackingStreetCardId == detail.summary.id;
          final isTrackingAnotherCard =
              appState?.isTracking == true && !isTrackingThisCard;
          final isPreparingRoute = appState?.isStartingRoute == true;
          return RefreshIndicator(
            onRefresh: () async {
              final refresh = ref
                  .read(mobileAppControllerProvider.notifier)
                  .loadStreetCard(widget.card.id);
              setState(() {
                _detail = refresh;
                _resetRecordedRouteFilters();
              });
              try {
                await refresh;
              } on Object {
                // O FutureBuilder mantém a mensagem de erro e oferece nova tentativa.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
              children: [
                _StreetCardQuickActions(
                  canManagePoints: appState?.canManageMapPoints ?? false,
                  isTrackingThisCard: isTrackingThisCard,
                  canStartRoute:
                      detail.canRecordRoute &&
                      !isPreparingRoute &&
                      !isTrackingAnotherCard,
                  isPreparingRoute: isPreparingRoute,
                  onExploreMap: () => _openStreetCardMap(
                    context,
                    detail,
                    routes: visibleRoutes,
                  ),
                  onAddPoint: () => _chooseAddPointMode(detail, visibleRoutes),
                  onToggleRoute: isTrackingThisCard
                      ? () => ref
                            .read(mobileAppControllerProvider.notifier)
                            .stopRoute()
                      : _startRoute,
                ),
                const SizedBox(height: 10),
                if (detail.description.isNotEmpty)
                  _InfoCard(
                    icon: Icons.info_outline_rounded,
                    text: detail.description,
                  ),
                if (detail.summary.neighborhood.isNotEmpty)
                  _InfoCard(
                    icon: Icons.place_outlined,
                    text: detail.summary.neighborhood,
                  ),
                if (detail.territoryDetails != null)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TerritorySituationSummary.fromDetails(
                            detail.territoryDetails!,
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            key: const ValueKey('card-territory-details'),
                            onPressed: () => showTerritoryDetailsSheet(
                              context,
                              title: 'Cartão ${detail.territoryDetails!.title}',
                              details: detail.territoryDetails,
                            ),
                            icon: const Icon(Icons.info_outline_rounded),
                            label: const Text('Ver detalhes do cartão'),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(
                  height: 340,
                  child: _StreetCardMapView(
                    detail: detail,
                    routes: visibleRoutes,
                    currentPosition: isTrackingThisCard
                        ? appState?.currentPosition
                        : null,
                    onExpand: () => _openStreetCardMap(
                      context,
                      detail,
                      routes: visibleRoutes,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openStreetCardMap(
                    context,
                    detail,
                    routes: visibleRoutes,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Explorar mapa'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
                if (appState?.canManageMapPoints == true) ...[
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    key: const ValueKey('card-add-point'),
                    onPressed: () => _chooseAddPointMode(detail, visibleRoutes),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Adicionar ponto'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '$mapPointLongPressHint (por exemplo, “Não bater”).',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _MapLegend(
                      color: Theme.of(context).colorScheme.primary,
                      label: 'Ruas do cartão',
                    ),
                    _MapLegend(
                      color: detail.recordedRoutes.isEmpty
                          ? const Color(0xFF188038)
                          : detail.recordedRoutes.first.color,
                      label: 'Percursos salvos',
                    ),
                    if (detail.canTestRoute)
                      const _MapLegend(
                        color: Color(0xFFC47A00),
                        label: 'Teste',
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Percursos registrados',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _CountBadge(count: visibleRoutes.length, label: 'trajetos'),
                  ],
                ),
                if (detail.recordedRoutes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('route-day-filter'),
                          onPressed: () => _chooseRecordedRouteDate(detail),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            _recordedRouteDayFilter == null
                                ? 'Todas as datas recentes'
                                : _recordedRouteDayLabel(
                                    _recordedRouteDayFilter!,
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          key: ValueKey('route-user-$selectedRouteUser'),
                          initialValue: selectedRouteUser,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Pessoa',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Todas'),
                            ),
                            ...routeUsers.entries.map(
                              (entry) => DropdownMenuItem<int?>(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) => _loadRecordedRoutes(
                            detail,
                            routeDate: _recordedRouteDayFilter,
                            routeUserId: value,
                          ),
                        ),
                      ),
                      if (_recordedRouteDayFilter != null ||
                          _recordedRouteUserFilter != null)
                        IconButton(
                          tooltip: 'Limpar filtros de percurso',
                          onPressed: () => _loadRecordedRoutes(detail),
                          icon: const Icon(Icons.filter_alt_off_rounded),
                        ),
                    ],
                  ),
                  if (_isLoadingRecordedRoutes)
                    const LinearProgressIndicator(minHeight: 2),
                  if (_recordedRoutesError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _InfoCard(
                        icon: Icons.cloud_off_outlined,
                        text: _recordedRoutesError!,
                      ),
                    ),
                ],
                if (detail.recordedRoutes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _InfoCard(
                      icon: Icons.route_outlined,
                      text: isTrackingThisCard
                          ? 'O percurso está ativo. Os pontos aguardando envio ficam indicados abaixo e aparecerão no mapa quando sincronizados.'
                          : 'Ainda não há trajetos sincronizados neste cartão. Puxe a tela para atualizar após registrar um percurso.',
                    ),
                  )
                else if (visibleRoutes.isEmpty)
                  const _InfoCard(
                    icon: Icons.filter_alt_off_rounded,
                    text: 'Nenhum percurso corresponde a estes filtros.',
                  )
                else
                  ...visibleRoutes.map(
                    (route) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        route.isTest
                            ? Icons.science_outlined
                            : Icons.route_rounded,
                        color: route.color,
                      ),
                      title: Text(
                        '${route.isTest ? 'Teste' : 'Percurso'} · ${route.name}',
                      ),
                      subtitle: Text(
                        '${_recordedRouteTimeLabel(route)} · '
                        '${route.pointCount} posições salvas',
                      ),
                      trailing: const Icon(Icons.open_in_full_rounded),
                      onTap: () => _openStreetCardMap(
                        context,
                        detail,
                        focusRouteId: route.id,
                        routes: visibleRoutes,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Trechos de rua',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _CountBadge(count: detail.streets.length, label: 'trechos'),
                  ],
                ),
                ...detail.streets.map(
                  (street) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timeline_rounded),
                    title: Text(street.name),
                    subtitle: Text(
                      [
                        if (street.startAddress.isNotEmpty) street.startAddress,
                        if (street.endAddress.isNotEmpty)
                          'até ${street.endAddress}',
                      ].join(' · '),
                    ),
                  ),
                ),
                const Divider(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Entradas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _CountBadge(
                      count: detail.entrances.length,
                      label: 'entradas',
                    ),
                  ],
                ),
                ...detail.entrances.map(
                  (entrance) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.meeting_room_outlined),
                    title: Text(entrance.name),
                    subtitle: Text(
                      '${entrance.position.latitude.toStringAsFixed(5)}, ${entrance.position.longitude.toStringAsFixed(5)}',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: isTrackingThisCard || detail.canRecordRoute
                      ? Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: 0.55)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Percurso deste cartão',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (isTrackingThisCard)
                              const _LetterStatusBadge(
                                label: 'Em andamento',
                                color: Color(0xFF16794B),
                              )
                            else if (detail.canRecordRoute)
                              const _LetterStatusBadge(
                                label: 'Liberado',
                                color: Color(0xFF16794B),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detail.routeMessage.isEmpty
                              ? 'O percurso será associado diretamente a este cartão de rua.'
                              : detail.routeMessage,
                        ),
                        if (detail.originTerritoryId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Referência legada: ${detail.summary.originTerritoryCode} · ${detail.summary.originTerritoryName}. A cobertura histórica do território continuará preservada.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (isTrackingThisCard && appState != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            appState.isTestTracking
                                ? 'Percurso de teste: não altera a cobertura real.'
                                : 'A localização continua sendo registrada com a tela bloqueada.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (appState.pendingRoutePoints > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                '${appState.pendingRoutePoints} ponto(s) aguardando envio',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                        ],
                        if (isTrackingAnotherCard)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Há outro cartão com percurso ativo. Encerre-o antes de iniciar um novo.',
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (isTrackingThisCard)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => ref
                                  .read(mobileAppControllerProvider.notifier)
                                  .stopRoute(),
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text('Encerrar percurso'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .error,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  isPreparingRoute ||
                                      isTrackingAnotherCard ||
                                      !detail.canRecordRoute
                                  ? null
                                  : () => _startRoute(),
                              icon: isPreparingRoute
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location_rounded),
                              label: Text(
                                isPreparingRoute
                                    ? 'Preparando…'
                                    : 'Iniciar percurso neste cartão',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        if (detail.canTestRoute) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  isPreparingRoute ||
                                      appState?.isTracking == true
                                  ? null
                                  : () => _startRoute(testMode: true),
                              icon: const Icon(Icons.science_outlined),
                              label: const Text('Testar percurso neste cartão'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                              ),
                            ),
                          ),
                          if (detail.testRoutePointsCount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${detail.testRoutePointsCount} ponto(s) de teste',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: appState?.isTracking == true
                                      ? null
                                      : () => _clearTestPoints(detail),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  label: const Text('Limpar'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _resetRecordedRouteFilters() {
    _recordedRouteFilterRequestId++;
    _recordedRouteDayFilter = null;
    _recordedRouteUserFilter = null;
    _serverFilteredRoutes = null;
    _isLoadingRecordedRoutes = false;
    _recordedRoutesError = null;
  }

  Future<void> _chooseRecordedRouteDate(StreetCardDetail detail) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(_recordedRouteDayFilter ?? '') ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selectedDate == null || !mounted) return;

    await _loadRecordedRoutes(
      detail,
      routeDate: _recordedRouteDayKey(selectedDate),
      routeUserId: _recordedRouteUserFilter,
    );
  }

  Future<void> _loadRecordedRoutes(
    StreetCardDetail detail, {
    String? routeDate,
    int? routeUserId,
  }) async {
    final requestId = ++_recordedRouteFilterRequestId;
    setState(() {
      _recordedRouteDayFilter = routeDate;
      _recordedRouteUserFilter = routeUserId;
      _serverFilteredRoutes = routeDate == null && routeUserId == null
          ? null
          : const [];
      _isLoadingRecordedRoutes = routeDate != null || routeUserId != null;
      _recordedRoutesError = null;
    });
    if (routeDate == null && routeUserId == null) return;

    try {
      final routes = await ref
          .read(mobileAppControllerProvider.notifier)
          .loadStreetCardRoutes(
            streetCardId: detail.summary.id,
            routeDate: routeDate,
            routeUserId: routeUserId,
          );
      if (!mounted || requestId != _recordedRouteFilterRequestId) return;
      setState(() {
        _serverFilteredRoutes = routes;
        _isLoadingRecordedRoutes = false;
      });
    } on Object catch (error) {
      if (!mounted || requestId != _recordedRouteFilterRequestId) return;
      setState(() {
        _isLoadingRecordedRoutes = false;
        _recordedRoutesError = error.toString();
      });
    }
  }

  Future<void> _startRoute({bool testMode = false}) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          testMode ? Icons.science_outlined : Icons.my_location_rounded,
        ),
        title: Text(
          testMode
              ? 'Testar percurso deste cartão?'
              : 'Iniciar percurso neste cartão?',
        ),
        content: Text(
          testMode
              ? 'O teste ficará associado somente ao cartão de rua e poderá ser apagado por um administrador.'
              : 'O Mapas JW registrará o caminho percorrido para este cartão de rua. O registro continuará com a tela bloqueada até você encerrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(testMode ? 'Iniciar teste' : 'Iniciar percurso'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    final message = await ref
        .read(mobileAppControllerProvider.notifier)
        .startStreetCardRoute(widget.card.id, testMode: testMode);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _clearTestPoints(StreetCardDetail detail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Limpar percurso de teste?'),
        content: Text(
          'Serão apagados somente ${detail.testRoutePointsCount} ponto(s) de teste deste cartão. Percursos reais e outros cartões serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar teste'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final message = await ref
        .read(mobileAppControllerProvider.notifier)
        .clearStreetCardTestRoutePoints(widget.card.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message ?? 'Teste limpo.')));
    setState(() {
      _detail = ref
          .read(mobileAppControllerProvider.notifier)
          .loadStreetCard(widget.card.id);
      _resetRecordedRouteFilters();
    });
  }

  Future<void> _chooseAddPointMode(
    StreetCardDetail detail,
    List<StreetRecordedRoute> routes,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.my_location_rounded),
              title: const Text('Usar minha localização'),
              subtitle: const Text('Marca o ponto onde você está agora'),
              onTap: () => Navigator.pop(sheetContext, 'here'),
            ),
            ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.touch_app_outlined),
              title: const Text('Escolher no mapa'),
              subtitle: const Text(mapPointLongPressHint),
              onTap: () => Navigator.pop(sheetContext, 'map'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'here') {
      await addMapPointAtCurrentLocation(context, ref);
    } else {
      _openStreetCardMap(context, detail, routes: routes);
    }
  }

  void _openStreetCardMap(
    BuildContext context,
    StreetCardDetail detail, {
    String? focusRouteId,
    List<StreetRecordedRoute>? routes,
  }) {
    final appState = ref.read(mobileAppControllerProvider).asData?.value;
    final currentPosition =
        appState?.isTracking == true &&
            appState?.trackingStreetCardId == detail.summary.id
        ? appState?.currentPosition
        : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StreetCardMapScreen(
          detail: detail,
          routes: routes,
          focusRouteId: focusRouteId,
          currentPosition: currentPosition,
        ),
      ),
    );
  }
}

class _StreetCardQuickActions extends StatelessWidget {
  const _StreetCardQuickActions({
    required this.canManagePoints,
    required this.isTrackingThisCard,
    required this.canStartRoute,
    required this.isPreparingRoute,
    required this.onExploreMap,
    required this.onAddPoint,
    required this.onToggleRoute,
  });

  final bool canManagePoints;
  final bool isTrackingThisCard;
  final bool canStartRoute;
  final bool isPreparingRoute;
  final VoidCallback onExploreMap;
  final VoidCallback onAddPoint;
  final VoidCallback onToggleRoute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final routeEnabled = isTrackingThisCard || canStartRoute;
    return Row(
      key: const ValueKey('card-quick-actions'),
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.map_outlined,
            label: 'Explorar mapa',
            onPressed: onExploreMap,
          ),
        ),
        if (canManagePoints) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _QuickAction(
              key: const ValueKey('quick-add-point'),
              icon: Icons.add_location_alt_outlined,
              label: 'Adicionar ponto',
              onPressed: onAddPoint,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: _QuickAction(
            key: const ValueKey('quick-route'),
            icon: isTrackingThisCard
                ? Icons.stop_circle_outlined
                : Icons.my_location_rounded,
            label: isTrackingThisCard
                ? 'Encerrar percurso'
                : (isPreparingRoute ? 'Preparando…' : 'Iniciar percurso'),
            color: isTrackingThisCard ? scheme.error : null,
            onPressed: routeEnabled ? onToggleRoute : null,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(68),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      foregroundColor: color,
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );
}

class StreetCardMapScreen extends StatelessWidget {
  const StreetCardMapScreen({
    required this.detail,
    this.routes,
    this.focusRouteId,
    this.currentPosition,
    super.key,
  });

  final StreetCardDetail detail;
  final List<StreetRecordedRoute>? routes;
  final String? focusRouteId;
  final LatLng? currentPosition;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Mapa · ${detail.summary.code}')),
    body: _StreetCardMapView(
      detail: detail,
      routes: routes,
      expanded: true,
      focusRouteId: focusRouteId,
      currentPosition: currentPosition,
    ),
  );
}

class _StreetCardMapView extends ConsumerStatefulWidget {
  const _StreetCardMapView({
    required this.detail,
    this.routes,
    this.expanded = false,
    this.onExpand,
    this.focusRouteId,
    this.currentPosition,
  });

  final StreetCardDetail detail;
  final List<StreetRecordedRoute>? routes;
  final bool expanded;
  final VoidCallback? onExpand;
  final String? focusRouteId;
  final LatLng? currentPosition;

  @override
  ConsumerState<_StreetCardMapView> createState() => _StreetCardMapViewState();
}

class _StreetCardMapViewState extends ConsumerState<_StreetCardMapView> {
  google_maps.GoogleMapController? _mapController;

  List<LatLng> get _mapPoints {
    final routes = widget.routes ?? widget.detail.recordedRoutes;
    StreetRecordedRoute? focusedRoute;
    for (final route in routes) {
      if (route.id == widget.focusRouteId) {
        focusedRoute = route;
        break;
      }
    }
    if (focusedRoute != null && focusedRoute.coordinates.isNotEmpty) {
      return focusedRoute.coordinates;
    }

    return [
      for (final street in widget.detail.streets) ...street.coordinates,
      for (final entrance in widget.detail.entrances) entrance.position,
      for (final route in routes) ...route.coordinates,
      if (widget.currentPosition != null) widget.currentPosition!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visibleRoutes = widget.routes ?? widget.detail.recordedRoutes;
    final mapPoints = _mapPoints;
    final appState = ref.watch(mobileAppControllerProvider).asData?.value;
    final canManagePoints = appState?.canManageMapPoints ?? false;
    final cardPoints = mapPointsNear(appState?.mapPoints ?? const [], [
      for (final street in widget.detail.streets) ...street.coordinates,
      for (final entrance in widget.detail.entrances) entrance.position,
    ]);
    final initialTarget = mapPoints.isNotEmpty
        ? _googleLatLng(mapPoints.first)
        : const google_maps.LatLng(-23.5505, -46.6333);

    final map = google_maps.GoogleMap(
      initialCameraPosition: google_maps.CameraPosition(
        target: initialTarget,
        zoom: 15,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitMap());
      },
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onLongPress: canManagePoints
          ? (position) => showMapPointFormSheet(
              context,
              position: LatLng(position.latitude, position.longitude),
            )
          : null,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      polylines: {
        for (final entry in widget.detail.streets.asMap().entries)
          if (entry.value.coordinates.length > 1)
            google_maps.Polyline(
              polylineId: google_maps.PolylineId('street-${entry.key}'),
              points: entry.value.coordinates.map(_googleLatLng).toList(),
              width: 5,
              color: Theme.of(context).colorScheme.primary,
            ),
        for (final route in visibleRoutes)
          if (route.coordinates.length > 1)
            google_maps.Polyline(
              polylineId: google_maps.PolylineId('route-${route.id}'),
              points: route.coordinates.map(_googleLatLng).toList(),
              width: route.id == widget.focusRouteId
                  ? 9
                  : (route.isTest ? 5 : 7),
              color: route.color,
            ),
      },
      markers: {
        for (final point in cardPoints)
          google_maps.Marker(
            markerId: google_maps.MarkerId('map-point-${point.id}'),
            position: _googleLatLng(point.position),
            icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
              mapPointMarkerHue(point.color),
            ),
            infoWindow: google_maps.InfoWindow(
              title: point.title.isNotEmpty ? point.title : point.type,
              snippet: point.type,
            ),
            onTap: () => showMapPointDetailsSheet(context, point),
          ),
        for (final entry in widget.detail.entrances.asMap().entries)
          google_maps.Marker(
            markerId: google_maps.MarkerId('entrance-${entry.key}'),
            position: _googleLatLng(entry.value.position),
            icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
              google_maps.BitmapDescriptor.hueAzure,
            ),
            infoWindow: google_maps.InfoWindow(title: entry.value.name),
          ),
        if (widget.currentPosition != null)
          google_maps.Marker(
            markerId: const google_maps.MarkerId('current-position'),
            position: _googleLatLng(widget.currentPosition!),
            icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
              google_maps.BitmapDescriptor.hueAzure,
            ),
            infoWindow: const google_maps.InfoWindow(
              title: 'Sua localização atual',
            ),
          ),
      },
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.expanded ? 0 : 22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          map,
          if (!widget.expanded && widget.onExpand != null)
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  tooltip: 'Abrir mapa em tela cheia',
                  onPressed: widget.onExpand,
                  icon: const Icon(Icons.open_in_full_rounded),
                ),
              ),
            ),
          if (widget.expanded)
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _MapControlButton(
                    tooltip: 'Aproximar',
                    icon: Icons.add_rounded,
                    onPressed: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  _MapControlButton(
                    tooltip: 'Afastar',
                    icon: Icons.remove_rounded,
                    onPressed: () => _zoomBy(-1),
                  ),
                  const SizedBox(height: 8),
                  _MapControlButton(
                    tooltip: 'Enquadrar cartão e percursos',
                    icon: Icons.center_focus_strong_rounded,
                    onPressed: _fitMap,
                  ),
                ],
              ),
            ),
          if (widget.expanded)
            Positioned(
              left: 12,
              right: 12,
              bottom: 14,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    '${widget.detail.streets.length} trechos · ${visibleRoutes.length} percursos exibidos'
                    '${cardPoints.isEmpty ? '' : ' · ${cardPoints.length} ponto(s)'}'
                    '${canManagePoints ? '\n$mapPointLongPressHint' : ''}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _fitMap() async {
    final controller = _mapController;
    final points = _mapPoints;
    if (controller == null || points.isEmpty) return;

    if (points.length == 1) {
      await controller.animateCamera(
        google_maps.CameraUpdate.newCameraPosition(
          google_maps.CameraPosition(
            target: _googleLatLng(points.single),
            zoom: 16,
          ),
        ),
      );
      return;
    }

    final minLatitude = points
        .map((point) => point.latitude)
        .reduce((first, second) => first < second ? first : second);
    final maxLatitude = points
        .map((point) => point.latitude)
        .reduce((first, second) => first > second ? first : second);
    final minLongitude = points
        .map((point) => point.longitude)
        .reduce((first, second) => first < second ? first : second);
    final maxLongitude = points
        .map((point) => point.longitude)
        .reduce((first, second) => first > second ? first : second);
    const minimumSpan = 0.001;
    final latitudePadding = max(
      (maxLatitude - minLatitude) * 0.08,
      minimumSpan,
    ).toDouble();
    final longitudePadding = max(
      (maxLongitude - minLongitude) * 0.08,
      minimumSpan,
    ).toDouble();
    final bounds = google_maps.LatLngBounds(
      southwest: google_maps.LatLng(
        minLatitude - latitudePadding,
        minLongitude - longitudePadding,
      ),
      northeast: google_maps.LatLng(
        maxLatitude + latitudePadding,
        maxLongitude + longitudePadding,
      ),
    );

    await controller.animateCamera(
      google_maps.CameraUpdate.newLatLngBounds(
        bounds,
        widget.expanded ? 76 : 46,
      ),
    );
  }

  Future<void> _zoomBy(double amount) async {
    final controller = _mapController;
    if (controller == null) return;
    final currentZoom = await controller.getZoomLevel();
    await controller.animateCamera(
      google_maps.CameraUpdate.zoomTo(currentZoom + amount),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    elevation: 3,
    child: IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon)),
  );
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

String _recordedRouteTimeLabel(StreetRecordedRoute route) {
  final start = route.startedAt;
  if (start == null) return 'Horário não disponível';

  final end = route.endedAt ?? start;
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final day = '${twoDigits(start.day)}/${twoDigits(start.month)}/${start.year}';
  final startTime = '${twoDigits(start.hour)}:${twoDigits(start.minute)}';
  final endTime = '${twoDigits(end.hour)}:${twoDigits(end.minute)}';

  return '$day · $startTime–$endTime';
}

String _recordedRouteDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _recordedRouteDayLabel(String dayKey) {
  final day = DateTime.tryParse(dayKey);
  if (day == null) return dayKey;
  return '${day.day.toString().padLeft(2, '0')}/'
      '${day.month.toString().padLeft(2, '0')}/${day.year}';
}

class _LetterStatusBadge extends StatelessWidget {
  const _LetterStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: 0.72)),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w700),
    ),
  );
}

class _LetterBlockCard extends StatelessWidget {
  const _LetterBlockCard({
    required this.group,
    required this.statuses,
    required this.expanded,
    required this.savingApartmentId,
    required this.canTap,
    required this.onToggle,
    required this.onTapApartment,
  });

  final LetterBlockGroup group;
  final List<LetterStatusOption> statuses;
  final bool expanded;
  final int? savingApartmentId;
  final bool canTap;
  final VoidCallback onToggle;
  final void Function(ApartmentLetter apartment) onTapApartment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = group.statusCounts(statuses);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label:
                '${group.title}, ${group.summary}. ${expanded ? 'Toque para recolher' : 'Toque para expandir'}',
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(group.summary, style: theme.textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              for (final count in counts)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: count.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${count.count}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.expand_more_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            for (var i = 0; i < group.floors.length; i++) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.isBlock)
                      SizedBox(
                        width: 40,
                        height: 62,
                        child: Center(
                          child: Text(
                            group.floors[i].label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    if (group.isBlock) const SizedBox(width: 6),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final apartment in group.floors[i].apartments)
                            _ApartmentStatusTile(
                              apartment: apartment,
                              isSaving: savingApartmentId == apartment.id,
                              onTap: apartment.canUpdate && canTap
                                  ? () => onTapApartment(apartment)
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _ApartmentStatusTile extends StatelessWidget {
  const _ApartmentStatusTile({
    required this.apartment,
    required this.isSaving,
    required this.onTap,
  });

  final ApartmentLetter apartment;
  final bool isSaving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = apartment.statusColor;
    return Semantics(
      button: onTap != null,
      label: '${apartment.apartmentNumber}, ${apartment.statusLabel}',
      child: Material(
        color: color.withValues(alpha: apartment.isBlocked ? 0.07 : 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: color, width: 1.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 64,
            height: 62,
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(3, 5, 3, 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          apartment.apartmentNumber.isEmpty
                              ? '—'
                              : apartment.apartmentNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          apartment.statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: color,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (apartment.writtenBy?.isNotEmpty == true)
                          Text(
                            apartment.writtenBy!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontSize: 7.5),
                          ),
                      ],
                    ),
                  ),
                ),
                if (apartment.isBlocked)
                  Positioned(
                    top: 3,
                    right: 4,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 13,
                      color: color,
                    ),
                  ),
                if (isSaving)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.78),
                      child: const Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 11),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Text(
        '$count $label',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    ),
  );
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({
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
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
