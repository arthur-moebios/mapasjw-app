import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mobile_api.dart';
import '../models/follow_up.dart';
import '../state/mobile_app_controller.dart';
import 'outing_work_screen.dart';

/// Cores dos três estados (as mesmas da web): pendente vermelho, em andamento
/// laranja e concluído verde.
const Color followUpPendingColor = Color(0xFFB3261E);
const Color followUpProgressColor = Color(0xFFD98A00);
const Color followUpDoneColor = Color(0xFF196B24);

Color followUpStateColor(CoverageState state) => switch (state) {
  CoverageState.pending => followUpPendingColor,
  CoverageState.inProgress => followUpProgressColor,
  CoverageState.done => followUpDoneColor,
};

/// Uma cor por dia da semana (domingo a sábado) para ler a disponibilidade.
const List<Color> followUpWeekdayColors = <Color>[
  Color(0xFFC2410C),
  Color(0xFF2563EB),
  Color(0xFF059669),
  Color(0xFF7C3AED),
  Color(0xFFD97706),
  Color(0xFFDB2777),
  Color(0xFF0E7490),
];

String _formatDate(String? iso) {
  if (iso == null || iso.length < 10) return '—';
  final parts = iso.substring(0, 10).split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Ano de serviço = 1º/set a 31/ago (set/2026 a ago/2027 é o ano 2027).
int _currentServiceYear() {
  final now = DateTime.now();
  return now.month >= 9 ? now.year + 1 : now.year;
}

String _daysText(int? days) {
  if (days == null) return '';
  if (days == 0) return 'hoje';
  if (days < 60) return 'há $days d';
  return 'há ${(days / 30).round()} meses';
}

/// Acompanhamento do território: cobertura por ano de serviço, cartões em
/// aberto, S-13-T e disponibilidade dos dirigentes.
class FollowUpScreen extends StatefulWidget {
  const FollowUpScreen({required this.active, super.key});

  /// A aba está selecionada. As abas só carregam dados na primeira vez que
  /// ficam visíveis: o app constrói todas de uma vez ao abrir.
  final bool active;

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  bool _seen = false;

  @override
  Widget build(BuildContext context) {
    _seen = _seen || widget.active;
    if (!_seen) return const SizedBox.shrink();
    return const DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Cobertura'),
                Tab(text: 'Em aberto'),
                Tab(text: 'S-13'),
                Tab(text: 'Dirigentes'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CoverageTab(),
                _OpenCardsTab(),
                _S13Tab(),
                _AvailabilityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mensagem centralizada (erro, vazio) com ação opcional.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

class _StateChip extends StatelessWidget {
  const _StateChip(this.state, {this.label});

  final CoverageState state;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = followUpStateColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label ?? state.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Base das quatro abas: carrega uma vez, mantém o estado e permite recarregar.
abstract class _LoadingTabState<T extends ConsumerStatefulWidget, D>
    extends ConsumerState<T>
    with AutomaticKeepAliveClientMixin<T> {
  D? data;
  String? error;
  bool loading = true;

  @override
  bool get wantKeepAlive => true;

  Future<D> fetch();

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await fetch();
      if (!mounted) return;
      setState(() {
        data = result;
        loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        error = MobileApi.messageForError(e);
        loading = false;
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Cobertura
// ---------------------------------------------------------------------------

class _CoverageTab extends ConsumerStatefulWidget {
  const _CoverageTab();

  @override
  ConsumerState<_CoverageTab> createState() => _CoverageTabState();
}

class _CoverageTabState extends _LoadingTabState<_CoverageTab, CoverageData> {
  int _year = _currentServiceYear();

  @override
  Future<CoverageData> fetch() =>
      ref.read(mobileAppControllerProvider.notifier).loadCoverage(year: _year);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final d = data;
    if (loading && d == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && d == null) {
      return _Notice(
        icon: Icons.error_outline_rounded,
        text: error!,
        actionLabel: 'Tentar de novo',
        onAction: reload,
      );
    }
    if (d == null) return const SizedBox.shrink();
    if (d.totalCards == 0) {
      return const _Notice(
        icon: Icons.route_outlined,
        text: 'Nenhum cartão de rua ativo.',
      );
    }
    final theme = Theme.of(context);
    final canRegister =
        ref.watch(mobileAppControllerProvider).value?.canManageTerritoryCards ??
        false;
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          _yearPicker(),
          const SizedBox(height: 8),
          _hero(theme, d),
          const SizedBox(height: 12),
          _kpis(d),
          for (final alert in d.alerts)
            Card(
              color: followUpProgressColor.withValues(alpha: .1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(alert, style: theme.textTheme.bodySmall),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Acompanhamento do fechamento',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          _boardColumn(
            d,
            'Meio de semana',
            'Residencial e comercial. Em andamento primeiro, depois os pendentes do mais antigo.',
            d.board.weekday,
            canRegister,
          ),
          _boardColumn(
            d,
            'Fim de semana',
            'Fim de semana e isolado (só sábado e domingo). Mesma ordem.',
            d.board.weekend,
            canRegister,
          ),
          _boardColumn(
            d,
            'Trabalho mais antigo',
            'Os há mais tempo sem passagem ou conclusão, de qualquer tipo.',
            d.board.oldest,
            canRegister,
          ),
          _boardColumn(
            d,
            'Iniciados sem finalizar',
            'Têm início (ou passagens) neste ano e nenhuma conclusão: confira se faltou marcar como concluído.',
            d.board.unfinished,
            canRegister,
            highlight: true,
          ),
          const SizedBox(height: 8),
          _breakdown('Por grupo', d.byGroup),
          _breakdown('Por tipo', d.byType),
          _breakdown('Por bairro', d.byNeighborhood),
        ],
      ),
    );
  }

  Widget _yearPicker() {
    final current = _currentServiceYear();
    return Row(
      children: [
        const Text(
          'Ano de serviço',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: _year,
          items: [
            for (var y = current; y >= current - 4; y--)
              DropdownMenuItem(
                value: y,
                child: Text('$y (set/${y - 1} a ago/$y)'),
              ),
          ],
          onChanged: (value) {
            if (value == null || value == _year) return;
            setState(() => _year = value);
            unawaited(reload());
          },
        ),
      ],
    );
  }

  Widget _hero(ThemeData theme, CoverageData d) {
    final done = d.done.percentKm;
    Widget segment(CoverageBucket bucket, Color color) => Expanded(
      flex: (bucket.percentKm * 10).round().clamp(0, 1000),
      child: ColoredBox(color: color, child: const SizedBox(height: 18)),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              children: [
                Text(
                  '${done.toStringAsFixed(0)}%',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: followUpDoneColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'do território concluído em ${d.year} · ${d.done.cards} de ${d.totalCards} cartões',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Row(
                children: [
                  segment(d.done, followUpDoneColor),
                  segment(d.inProgress, followUpProgressColor),
                  segment(d.pending, followUpPendingColor),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _legend(CoverageState.done, d.done),
                _legend(CoverageState.inProgress, d.inProgress),
                _legend(CoverageState.pending, d.pending),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(CoverageState state, CoverageBucket bucket) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 11, color: followUpStateColor(state)),
      const SizedBox(width: 6),
      Text(
        '${state.label} ${bucket.cards} · ${bucket.km.toStringAsFixed(1)} km',
      ),
    ],
  );

  Widget _kpis(CoverageData d) {
    Widget tile(String value, String label, {Color? color}) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
    final tiles = <Widget>[
      tile('${d.totalKm.toStringAsFixed(1)} km', 'território total'),
      tile(
        '${d.kmLeft.toStringAsFixed(1)} km',
        'restante a cobrir',
        color: followUpProgressColor,
      ),
      tile(d.perWeek.toStringAsFixed(2), 'cartões concluídos por semana'),
      tile(_formatDate(d.forecastDate), 'previsão de término'),
      if (d.unfinishedCount > 0)
        tile(
          '${d.unfinishedCount}',
          'iniciados sem finalizar (confira se faltou concluir)',
          color: followUpProgressColor,
        ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.1,
      children: tiles,
    );
  }

  Widget _boardColumn(
    CoverageData d,
    String title,
    String rule,
    List<CoverageBoardItem> items,
    bool canRegister, {
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    return Card(
      shape: highlight && items.isNotEmpty
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: followUpProgressColor, width: 1.5),
            )
          : null,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: highlight && items.isNotEmpty,
        title: Text(
          '$title (${items.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(rule, style: theme.textTheme.bodySmall),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Nada pendente aqui.'),
            ),
          for (final item in items.take(6)) _boardTile(d, item, canRegister),
          if (items.length > 6)
            ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: EdgeInsets.zero,
              title: Text('ver todos (${items.length})'),
              children: [
                for (final item in items.skip(6))
                  _boardTile(d, item, canRegister),
              ],
            ),
        ],
      ),
    );
  }

  Widget _boardTile(CoverageData d, CoverageBoardItem item, bool canRegister) {
    final details = <String>[
      if (item.startedAt != null) 'iniciado em ${_formatDate(item.startedAt)}',
      if (item.state == CoverageState.inProgress) '${item.daysWorked} dia(s)',
      if (item.pendency == 'sem_registro')
        'sem passagem'
      else if (item.daysIdle != null)
        'última atividade ${_daysText(item.daysIdle)}',
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      trailing: _StateChip(item.state),
      onTap: () => _showCard(d, item.cardId, canRegister),
    );
  }

  Widget _breakdown(String title, List<CoverageBreakdownRow> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(row.label, overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        '${row.done}/${row.total} · ${row.percentDone.toStringAsFixed(0)}% · '
                        '${row.kmLeft.toStringAsFixed(1)} km faltam',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  LinearProgressIndicator(
                    value: (row.percentDone / 100).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    color: followUpDoneColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Painel com os dados do cartão, sem sair da cobertura.
  void _showCard(CoverageData d, int cardId, bool canRegister) {
    final card = d.cardById(cardId);
    if (card == null) return;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => _CoverageCardSheet(
          card: card,
          canRegister: canRegister,
          onRegister: () async {
            Navigator.of(sheetContext).pop();
            final saved = await showCardWorkScreen(
              context,
              cardId: cardId,
              canSave: canRegister,
            );
            if (saved == true && mounted) unawaited(reload());
          },
        ),
      ),
    );
  }
}

class _CoverageCardSheet extends StatelessWidget {
  const _CoverageCardSheet({
    required this.card,
    required this.canRegister,
    required this.onRegister,
  });

  final CoverageCard card;
  final bool canRegister;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget fact(String value, String label) => SizedBox(
      width: 150,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cartão ${card.title}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StateChip(
                  card.state,
                  label: card.state == CoverageState.done && card.forced
                      ? 'Concluído (forçado)'
                      : null,
                ),
                Text(
                  [
                    card.neighborhood,
                    card.group,
                  ].whereType<String>().join(' · '),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                fact('${card.km.toStringAsFixed(1)} km', 'extensão'),
                fact((card.type ?? 'residencial').replaceAll('_', ' '), 'tipo'),
                fact(
                  card.state == CoverageState.done
                      ? _formatDate(card.completedAt)
                      : _formatDate(card.lastWorkAt),
                  card.state == CoverageState.done
                      ? 'concluído em'
                      : 'último trabalho',
                ),
                fact('${card.daysWorked}', 'dia(s) trabalhado(s) no ciclo'),
                if (card.startedAt != null)
                  fact(
                    _formatDate(card.startedAt),
                    'iniciado em (sem conclusão)',
                  ),
                if (card.lastCompletionAt != null)
                  fact(
                    _formatDate(card.lastCompletionAt),
                    'última conclusão registrada',
                  ),
              ],
            ),
            if (card.streets.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Ruas (${card.streets.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              for (final street in card.streets) Text('• $street'),
            ],
            if (card.assignments.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Últimas designações',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              for (final item in card.assignments)
                Text(
                  '${item.publisher ?? 'sem publicador'} · ${_formatDate(item.assignedAt)} → '
                  '${item.completedAt == null ? 'em aberto' : _formatDate(item.completedAt)}',
                ),
            ],
            if (canRegister && card.state != CoverageState.done) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRegister,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Registrar trabalho'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cartões em aberto
// ---------------------------------------------------------------------------

class _OpenCardsTab extends ConsumerStatefulWidget {
  const _OpenCardsTab();

  @override
  ConsumerState<_OpenCardsTab> createState() => _OpenCardsTabState();
}

enum _OpenFilter { inProgress, pending, all }

enum _WeekFilter { any, weekday, weekend }

class _OpenCardsTabState
    extends _LoadingTabState<_OpenCardsTab, List<OpenCard>> {
  _OpenFilter _filter = _OpenFilter.inProgress;
  _WeekFilter _week = _WeekFilter.any;
  String _query = '';
  int? _busyId;

  @override
  Future<List<OpenCard>> fetch() =>
      ref.read(mobileAppControllerProvider.notifier).loadOpenCards();

  List<OpenCard> _visible(List<OpenCard> cards) {
    final q = _query.trim().toLowerCase();
    return cards
        .where((card) {
          final stateOk = switch (_filter) {
            _OpenFilter.inProgress => card.state == CoverageState.inProgress,
            _OpenFilter.pending => card.state != CoverageState.inProgress,
            _OpenFilter.all => true,
          };
          final weekOk = switch (_week) {
            _WeekFilter.any => true,
            _WeekFilter.weekday => !card.weekend,
            _WeekFilter.weekend => card.weekend,
          };
          return stateOk &&
              weekOk &&
              (q.isEmpty || card.searchText.contains(q));
        })
        .toList(growable: false);
  }

  Future<void> _register(OpenCard card, bool canSave) async {
    final saved = await showCardWorkScreen(
      context,
      cardId: card.id,
      canSave: canSave,
    );
    if (saved == true && mounted) unawaited(reload());
  }

  Future<void> _complete(OpenCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Concluir o cartão ${card.code}?'),
        content: const Text(
          'Todas as ruas serão marcadas como trabalhadas e o cartão ficará '
          'FECHADO (concluído) hoje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sim, concluir o cartão'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = card.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(mobileAppControllerProvider.notifier).saveCardWork(
        card.id,
        {
          'items': [
            {
              'card_id': card.id,
              'date': _dateKey(DateTime.now()),
              'streets': card.streets,
            },
          ],
        },
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Cartão ${card.code} concluído com todas as ruas.'),
        ),
      );
      if (mounted) await reload();
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(MobileApi.messageForError(e))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cards = data;
    if (loading && cards == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && cards == null) {
      return _Notice(
        icon: Icons.error_outline_rounded,
        text: error!,
        actionLabel: 'Tentar de novo',
        onAction: reload,
      );
    }
    if (cards == null) return const SizedBox.shrink();
    final canSave =
        ref.watch(mobileAppControllerProvider).value?.canManageTerritoryCards ??
        false;
    final inProgress = cards
        .where((c) => c.state == CoverageState.inProgress)
        .length;
    final visible = _visible(cards);
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Text(
            'Cartões ainda não concluídos neste ano de serviço. Em andamento primeiro; '
            'os pendentes (sem início no ano) ficam em vermelho.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar por código, bairro ou rua',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text('Em andamento ($inProgress)'),
                selected: _filter == _OpenFilter.inProgress,
                onSelected: (_) =>
                    setState(() => _filter = _OpenFilter.inProgress),
              ),
              ChoiceChip(
                label: Text('Pendentes (${cards.length - inProgress})'),
                selected: _filter == _OpenFilter.pending,
                onSelected: (_) =>
                    setState(() => _filter = _OpenFilter.pending),
              ),
              ChoiceChip(
                label: Text('Todos (${cards.length})'),
                selected: _filter == _OpenFilter.all,
                onSelected: (_) => setState(() => _filter = _OpenFilter.all),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Meio e fim de semana'),
                selected: _week == _WeekFilter.any,
                onSelected: (_) => setState(() => _week = _WeekFilter.any),
              ),
              ChoiceChip(
                label: const Text('Meio de semana'),
                selected: _week == _WeekFilter.weekday,
                onSelected: (_) => setState(() => _week = _WeekFilter.weekday),
              ),
              ChoiceChip(
                label: const Text('Fim de semana'),
                selected: _week == _WeekFilter.weekend,
                onSelected: (_) => setState(() => _week = _WeekFilter.weekend),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Nenhum cartão combina com a busca e os filtros.'),
              ),
            ),
          for (final card in visible) _card(card, canSave),
        ],
      ),
    );
  }

  Widget _card(OpenCard card, bool canSave) {
    final theme = Theme.of(context);
    final color = followUpStateColor(card.state);
    final details = <String>[
      card.weekend ? 'Fim de semana' : 'Meio de semana',
      '${card.km.toStringAsFixed(1)} km',
      if (card.startedAt != null) 'iniciado em ${_formatDate(card.startedAt)}',
      '${card.daysWorked} dia(s) trabalhado(s)',
      if (card.lastWorkAt != null || card.lastCompletionAt != null)
        'última atividade ${_formatDate(card.lastWorkAt ?? card.lastCompletionAt)}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: .6), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StateChip(
                  card.state,
                  label: card.state == CoverageState.inProgress
                      ? 'em andamento'
                      : 'pendente',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(details.join(' · '), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              '${card.workedStreets.length} de ${card.streets.length} rua(s) trabalhada(s)',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: card.progress,
              minHeight: 7,
              color: followUpDoneColor,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final street in card.streets)
                  Chip(
                    label: Text(street, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: card.workedStreets.contains(street)
                        ? const Color(0xFFE7F4EA)
                        : null,
                    side: BorderSide(
                      color: card.workedStreets.contains(street)
                          ? const Color(0xFF9CCAA4)
                          : theme.dividerColor,
                    ),
                  ),
              ],
            ),
            if (canSave && card.streets.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busyId == card.id
                          ? null
                          : () => _register(card, canSave),
                      icon: const Icon(
                        Icons.edit_location_alt_outlined,
                        size: 18,
                      ),
                      label: const Text('Registrar trabalho'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busyId == card.id
                          ? null
                          : () => _complete(card),
                      icon: _busyId == card.id
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                      label: const Text('Concluir'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// S-13-T
// ---------------------------------------------------------------------------

class _S13Tab extends ConsumerStatefulWidget {
  const _S13Tab();

  @override
  ConsumerState<_S13Tab> createState() => _S13TabState();
}

class _S13TabState extends _LoadingTabState<_S13Tab, S13Sheet> {
  int _year = _currentServiceYear();
  String _query = '';

  @override
  Future<S13Sheet> fetch() =>
      ref.read(mobileAppControllerProvider.notifier).loadS13(year: _year);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sheet = data;
    if (loading && sheet == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && sheet == null) {
      return _Notice(
        icon: Icons.error_outline_rounded,
        text: error!,
        actionLabel: 'Tentar de novo',
        onAction: reload,
      );
    }
    if (sheet == null) return const SizedBox.shrink();
    final q = _query.trim().toLowerCase();
    final rows = sheet.rows
        .where(
          (row) =>
              q.isEmpty ||
              row.number.contains(q) ||
              row.place.toLowerCase().contains(q),
        )
        .toList(growable: false);
    final years = sheet.years.isEmpty ? <int>[_year] : sheet.years;
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Row(
            children: [
              const Text(
                'Ano de serviço',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: years.contains(_year) ? _year : years.first,
                items: [
                  for (final y in years)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (value) {
                  if (value == null || value == _year) return;
                  setState(() => _year = value);
                  unawaited(reload());
                },
              ),
            ],
          ),
          Text(
            'Registro de designação de território (S-13-T): uma linha por cartão de rua. '
            'A última data concluída é a última conclusão de anos anteriores.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar por número ou bairro',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          row.number,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            row.place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        if (row.lastCompletion != null)
                          Text(
                            'última: ${_formatDate(row.lastCompletion)}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                    if (row.assignments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          row.continuation ? '' : 'Sem designação neste ano.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    for (final item in row.assignments)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${(item.publisher ?? '---').toUpperCase()}\n'
                          '${_formatDate(item.assignedAt)} → '
                          '${item.completedAt == null ? 'em aberto' : _formatDate(item.completedAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Nenhum território encontrado.')),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Disponibilidade dos dirigentes
// ---------------------------------------------------------------------------

class _AvailabilityTab extends ConsumerStatefulWidget {
  const _AvailabilityTab();

  @override
  ConsumerState<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState
    extends _LoadingTabState<_AvailabilityTab, LeadersAvailabilityData> {
  String _query = '';
  int? _day;
  String? _period;
  List<LeaderAvailability> _leaders = const [];
  String? _message;

  @override
  Future<LeadersAvailabilityData> fetch() async {
    final result = await ref
        .read(mobileAppControllerProvider.notifier)
        .loadLeadersAvailability();
    _leaders = result.leaders;
    return result;
  }

  Future<void> _toggle(LeaderAvailability leader, String slot) async {
    final next = {...leader.slots};
    if (!next.add(slot)) next.remove(slot);
    final index = _leaders.indexWhere((l) => l.id == leader.id);
    final before = leader;
    setState(() {
      _leaders = [..._leaders]..[index] = leader.withSlots(next);
      _message = 'Salvando…';
    });
    try {
      await ref
          .read(mobileAppControllerProvider.notifier)
          .saveLeaderAvailability(leader.id, next.toList()..sort());
      if (mounted) setState(() => _message = 'Salvo.');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _leaders = [..._leaders]..[index] = before;
        _message = 'Não foi possível salvar: ${MobileApi.messageForError(e)}';
      });
    }
  }

  bool _available(LeaderAvailability leader) {
    if (_day == null && _period == null) return true;
    return leader.slots.any((slot) {
      final parts = slot.split(':');
      return (_day == null || parts[0] == '$_day') &&
          (_period == null || parts[1] == _period);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final info = data;
    if (loading && info == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && info == null) {
      return _Notice(
        icon: Icons.error_outline_rounded,
        text: error!,
        actionLabel: 'Tentar de novo',
        onAction: reload,
      );
    }
    if (info == null) return const SizedBox.shrink();
    final canEdit =
        ref.watch(mobileAppControllerProvider).value?.canManageTerritoryCards ??
        false;
    final q = _query.trim().toLowerCase();
    final visible = _leaders
        .where(
          (l) =>
              (q.isEmpty || l.name.toLowerCase().contains(q)) && _available(l),
        )
        .toList(growable: false);
    final theme = Theme.of(context);
    const periodLabels = {'manha': 'Manhã', 'tarde': 'Tarde', 'noite': 'Noite'};
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Text(
            'Dias e períodos em que cada dirigente pode dirigir saída: M manhã, T tarde, N noite. '
            'Dirigente sem marca ainda não informou a disponibilidade.',
            style: theme.textTheme.bodySmall,
          ),
          if (!info.enabled)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'A disponibilidade ainda não está habilitada no servidor.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar dirigente',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<int?>(
                value: _day,
                hint: const Text('Qualquer dia'),
                items: [
                  const DropdownMenuItem<int?>(child: Text('Qualquer dia')),
                  for (var i = 0; i < info.weekdays.length; i++)
                    DropdownMenuItem<int?>(
                      value: i,
                      child: Text(info.weekdays[i]),
                    ),
                ],
                onChanged: (value) => setState(() => _day = value),
              ),
              DropdownButton<String?>(
                value: _period,
                hint: const Text('Qualquer período'),
                items: [
                  const DropdownMenuItem<String?>(
                    child: Text('Qualquer período'),
                  ),
                  for (final p in info.periods)
                    DropdownMenuItem<String?>(
                      value: p,
                      child: Text(periodLabels[p] ?? p),
                    ),
                ],
                onChanged: (value) => setState(() => _period = value),
              ),
              if (_day != null || _period != null)
                Text('${visible.length} de ${_leaders.length} disponíveis'),
            ],
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(_message!, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 4),
          for (final leader in visible)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leader.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (leader.slots.isEmpty)
                      Text('não informou', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var day = 0; day < info.weekdays.length; day++)
                            _dayColumn(
                              info,
                              leader,
                              day,
                              canEdit && info.enabled,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Nenhum dirigente encontrado.')),
            ),
        ],
      ),
    );
  }

  Widget _dayColumn(
    LeadersAvailabilityData info,
    LeaderAvailability leader,
    int day,
    bool editable,
  ) {
    final color = followUpWeekdayColors[day % followUpWeekdayColors.length];
    final name = info.weekdays[day];
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              name.substring(0, 3).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final period in info.periods)
                _slotButton(
                  leader,
                  '$day:$period',
                  period.substring(0, 1).toUpperCase(),
                  color,
                  editable,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotButton(
    LeaderAvailability leader,
    String slot,
    String label,
    Color color,
    bool editable,
  ) {
    final on = leader.slots.contains(slot);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: on ? color : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: .5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: editable ? () => unawaited(_toggle(leader, slot)) : null,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: on ? Colors.white : color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
