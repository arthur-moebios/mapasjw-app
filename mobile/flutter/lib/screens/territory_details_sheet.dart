import 'package:flutter/material.dart';

import '../models/mobile_models.dart';

/// Resumo compacto da situação de um cartão: situação, abertura, conclusão,
/// quem concluiu e, se houver, a conclusão forçada com a observação.
class TerritorySituationSummary extends StatelessWidget {
  const TerritorySituationSummary({
    required this.situation,
    required this.situationLabel,
    this.openedAt,
    this.concludedAt,
    this.concludedBy,
    this.forcedCompletion = false,
    this.completionNote,
    super.key,
  });

  factory TerritorySituationSummary.fromTerritory(Territory territory) =>
      TerritorySituationSummary(
        situation: territory.situation,
        situationLabel: territory.situationLabel,
        openedAt: territory.openedAt,
        concludedAt: territory.concludedAt,
        concludedBy: territory.concludedBy,
        forcedCompletion: territory.forcedCompletion,
        completionNote: territory.completionNote,
      );

  factory TerritorySituationSummary.fromDetails(TerritoryDetails details) =>
      TerritorySituationSummary(
        situation: details.situation,
        situationLabel: details.displaySituation,
        openedAt: details.openedAt,
        concludedAt: details.concludedAt,
        concludedBy: details.concludedBy,
        forcedCompletion: details.forcedCompletion,
        completionNote: details.completionNote,
      );

  final String situation;
  final String situationLabel;
  final DateTime? openedAt;
  final DateTime? concludedAt;
  final String? concludedBy;
  final bool forcedCompletion;
  final String? completionNote;

  static Color colorFor(String situation) => switch (situation) {
    'em_andamento' => const Color(0xFFB4531F),
    'concluido' => const Color(0xFF196B24),
    _ => const Color(0xFF156082),
  };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(situation);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: muted, height: 1.4);
    final concluded = concludedAt != null
        ? 'Concluído em ${formatDatePtBr(concludedAt)}'
              '${concludedBy == null ? '' : ' por $concludedBy'}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                situationLabel,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
            if (forcedCompletion)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC47A00).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Conclusão forçada',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF8A5600),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          openedAt == null
              ? 'Sem data de abertura'
              : 'Aberto em ${formatDatePtBr(openedAt)}',
          style: style,
        ),
        if (concluded != null) Text(concluded, style: style),
        if (completionNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Observação: $completionNote', style: style),
          ),
      ],
    );
  }
}

/// Abre a folha com os detalhes completos do cartão. Use [details] quando já
/// estiverem carregados, ou [loader] para buscá-los ao abrir.
Future<void> showTerritoryDetailsSheet(
  BuildContext context, {
  required String title,
  TerritoryDetails? details,
  Future<TerritoryDetails> Function()? loader,
}) {
  assert(details != null || loader != null);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) =>
        _TerritoryDetailsSheet(title: title, details: details, loader: loader),
  );
}

class _TerritoryDetailsSheet extends StatefulWidget {
  const _TerritoryDetailsSheet({
    required this.title,
    this.details,
    this.loader,
  });

  final String title;
  final TerritoryDetails? details;
  final Future<TerritoryDetails> Function()? loader;

  @override
  State<_TerritoryDetailsSheet> createState() => _TerritoryDetailsSheetState();
}

class _TerritoryDetailsSheetState extends State<_TerritoryDetailsSheet> {
  late Future<TerritoryDetails> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.details != null
        ? Future.value(widget.details)
        : widget.loader!();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<TerritoryDetails>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 38),
                          const SizedBox(height: 10),
                          const Text(
                            'Não foi possível carregar os detalhes do cartão.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => setState(_load),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return TerritoryDetailsBody(details: snapshot.data!);
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class TerritoryDetailsBody extends StatelessWidget {
  const TerritoryDetailsBody({required this.details, super.key});

  final TerritoryDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: theme.textTheme.titleMedium),
    );

    Widget empty(String text) =>
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: muted));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (details.group != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              details.group!,
              style: theme.textTheme.labelLarge?.copyWith(color: muted),
            ),
          ),
        TerritorySituationSummary.fromDetails(details),
        heading('Locais'),
        if (details.locations.isEmpty)
          empty('Nenhum local cadastrado neste cartão.')
        else
          ...details.locations.map(
            (location) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                location.worked
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: location.worked ? const Color(0xFF196B24) : muted,
              ),
              title: Text(location.name),
              subtitle: Text(
                [
                  location.address,
                  location.neighborhood,
                ].where((part) => part.isNotEmpty).join(' · '),
              ),
              trailing: Text(
                location.worked ? 'Trabalhado' : 'Pendente',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ),
          ),
        heading('Histórico de ciclos'),
        if (details.cycles.isEmpty)
          empty('Nenhum ciclo registrado.')
        else
          ...details.cycles.map(
            (cycle) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                cycle.closedAt == null
                    ? Icons.autorenew_rounded
                    : Icons.task_alt_rounded,
                color: cycle.closedAt == null
                    ? const Color(0xFFB4531F)
                    : const Color(0xFF196B24),
              ),
              title: Text(
                'Aberto em ${formatDatePtBr(cycle.openedAt)} → '
                '${cycle.closedAt == null ? 'em andamento' : 'concluído em ${formatDatePtBr(cycle.closedAt)}'}',
              ),
              subtitle: cycle.concludedBy == null
                  ? null
                  : Text('Concluído por ${cycle.concludedBy}'),
            ),
          ),
        heading('Últimas passagens'),
        if (details.recentPasses.isEmpty)
          empty('Nenhuma passagem recente.')
        else
          ...details.recentPasses.map(
            (pass) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.directions_walk_rounded),
              title: Text(
                '${formatDatePtBr(pass.date)}'
                '${pass.publisher == null ? '' : ' · ${pass.publisher}'}',
              ),
              subtitle: Text(
                [
                  if (pass.outingLeader != null)
                    'Dirigente: ${pass.outingLeader}',
                  if (pass.location != null) 'Local: ${pass.location}',
                ].join(' · '),
              ),
            ),
          ),
      ],
    );
  }
}
