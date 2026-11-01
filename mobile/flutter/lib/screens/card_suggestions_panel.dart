import 'dart:async';

import 'package:flutter/material.dart';

import '../models/mobile_models.dart';

const _weekdayNames = [
  'domingo',
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
];

/// Painel "Cartões sugeridos" de uma saída de campo (somente leitura).
///
/// Recarrega quando [requestKey] muda, aguardando [debounce] para não
/// consultar o servidor a cada tecla digitada.
class CardSuggestionsPanel extends StatefulWidget {
  const CardSuggestionsPanel({
    required this.loader,
    required this.requestKey,
    required this.weekday,
    this.debounce = const Duration(milliseconds: 500),
    super.key,
  });

  final Future<CardSuggestions> Function() loader;
  final Object requestKey;

  /// Dia da semana da saída, 0 = domingo ... 6 = sábado.
  final int weekday;
  final Duration debounce;

  @override
  State<CardSuggestionsPanel> createState() => _CardSuggestionsPanelState();
}

class _CardSuggestionsPanelState extends State<CardSuggestionsPanel> {
  Timer? _timer;
  Future<CardSuggestions>? _future;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  void didUpdateWidget(CardSuggestionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestKey != widget.requestKey) {
      _timer?.cancel();
      _timer = Timer(widget.debounce, _reload);
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _requestId++;
      _future = widget.loader();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      key: ValueKey('card-suggestions-$_requestId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cartões sugeridos', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        FutureBuilder<CardSuggestions>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Não foi possível carregar as sugestões.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              );
            }
            final data = snapshot.data!;
            final regions = data.regionsForWeekday(widget.weekday);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (regions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.place_outlined, size: 18, color: muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Região do dirigente: ${regions.join(', ')} '
                            '(${_weekdayNames[widget.weekday % 7]})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (data.suggestions.isEmpty)
                  Text(
                    'Nenhum cartão para sugerir no momento.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  )
                else
                  ...data.suggestions.map(
                    (suggestion) => _SuggestionTile(suggestion: suggestion),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion});

  final CardSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  suggestion.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (suggestion.nearRegion != null)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.near_me_outlined, size: 16),
                  label: Text('Perto: ${suggestion.nearRegion}'),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (suggestion.group != null) suggestion.group!,
              suggestion.idleLabel,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (suggestion.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(suggestion.reason, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Abre as sugestões de uma saída já existente em uma folha.
Future<void> showCardSuggestionsSheet(
  BuildContext context, {
  required Future<CardSuggestions> Function() loader,
  required Object requestKey,
  required int weekday,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheetContext) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .85,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          CardSuggestionsPanel(
            loader: loader,
            requestKey: requestKey,
            weekday: weekday,
          ),
        ],
      ),
    ),
  ),
);
