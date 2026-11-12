import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../state/mobile_app_controller.dart';

/// Consulta do cronômetro das partes das reuniões (somente leitura).
class TimersScreen extends ConsumerStatefulWidget {
  const TimersScreen({super.key});

  @override
  ConsumerState<TimersScreen> createState() => _TimersScreenState();
}

class _TimersScreenState extends ConsumerState<TimersScreen> {
  final List<TimerDay> _days = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _available = true;
  Object? _error;
  int _page = 1;
  int? _congregationId;

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(mobileAppControllerProvider).requireValue;
    final congregationId = app.selectedCongregationId;
    if (_congregationId != congregationId) {
      _congregationId = congregationId;
      if (congregationId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cronômetros')),
      body: congregationId == null
          ? const _Message(
              icon: Icons.apartment_outlined,
              title: 'Escolha uma congregação',
              message:
                  'Selecione uma congregação para consultar os cronômetros.',
            )
          : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _days.isEmpty) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar',
        message: _error is StateError
            ? (_error! as StateError).message.toString()
            : 'Verifique a conexão e tente novamente.',
        action: TextButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          if (!_available)
            const _Message(
              icon: Icons.hourglass_empty_rounded,
              title: 'Histórico ainda indisponível',
              message: 'O histórico do cronômetro ainda não está disponível neste servidor.',
            )
          else if (_days.isEmpty)
            const _Message(
              icon: Icons.timer_off_outlined,
              title: 'Nenhum cronômetro recebido',
              message: 'Quando o painel do Salão do Reino enviar as partes medidas de uma reunião, elas aparecem aqui.',
            )
          else ...[
            ..._days.map((day) => _DayCard(day: day)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Não foi possível carregar mais. Tente novamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_hasMore)
              Center(
                child: _loadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      )
                    : OutlinedButton(
                        onPressed: _more,
                        child: const Text('Carregar mais'),
                      ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _loading = _days.isEmpty;
      _error = null;
    });
    try {
      final page = await ref
          .read(mobileAppControllerProvider.notifier)
          .loadTimers(page: 1);
      if (!mounted) return;
      setState(() {
        _days
          ..clear()
          ..addAll(page.days);
        _page = 1;
        _hasMore = page.hasMore;
        _available = page.available;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _more() async {
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(mobileAppControllerProvider.notifier)
          .loadTimers(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _days.addAll(page.days);
        _page += 1;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingMore = false;
      });
    }
  }
}

/// A KMC manda a seção em caixa alta; normaliza para os três títulos da reunião.
String sectionTitle(String raw) {
  final key = raw.toUpperCase();
  if (key.contains('TESOURO')) return 'Tesouros da Palavra de Deus';
  if (key.contains('MINIST')) return 'Faça Seu Melhor no Ministério';
  if (key.contains('VIDA CRIST')) return 'Nossa Vida Cristã';
  final lower = raw.trim().toLowerCase();
  return lower.isEmpty ? raw : lower[0].toUpperCase() + lower.substring(1);
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final TimerDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(longDateLabel(day.date), style: theme.textTheme.titleMedium),
            Text(
              day.typeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final room in day.rooms) _RoomSection(room: room),
          ],
        ),
      ),
    );
  }
}

class _RoomSection extends StatelessWidget {
  const _RoomSection({required this.room});

  final TimerRoom room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final children = <Widget>[];
    String? lastSection;
    for (final part in room.parts) {
      final section = part.section;
      if (section != null && section != lastSection) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Text(
              sectionTitle(section),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.secondary,
              ),
            ),
          ),
        );
        lastSection = section;
      }
      children.add(_PartRow(part: part));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            room.label,
            style: theme.textTheme.titleSmall?.copyWith(color: colors.primary),
          ),
          ...children,
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total · previsto ${formatSeconds(room.totalPlannedSeconds)}'
                  ' · usado ${formatSeconds(room.totalUsedSeconds)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatSeconds(room.differenceSeconds, signed: true),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: room.differenceSeconds > 0 ? colors.error : null,
                ),
              ),
            ],
          ),
          Text(
            '${room.measuredParts} de ${room.totalParts} partes medidas',
            style: muted,
          ),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.part});

  final TimerPart part;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final who = [
      if (part.assignee != null) part.assignee!,
      if (part.assistant != null) 'Ajudante: ${part.assistant}',
    ].join(' · ');
    final overtimeStyle = theme.textTheme.bodyMedium?.copyWith(
      color: part.overtime ? colors.error : null,
      fontWeight: part.overtime ? FontWeight.w700 : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(part.title, style: theme.textTheme.bodyMedium),
          if (who.isNotEmpty) Text(who, style: muted),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Previsto ${formatSeconds(part.plannedSeconds)}',
                  style: muted,
                ),
              ),
              Expanded(
                child: Text(
                  'Usado ${formatSeconds(part.usedSeconds)}',
                  style: overtimeStyle,
                ),
              ),
              Text(
                formatSeconds(part.differenceSeconds, signed: true),
                style: overtimeStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    ),
  );
}
