import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../state/mobile_app_controller.dart';

/// Consulta da assistência às reuniões, por mês (somente leitura).
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  Future<AttendanceMonth>? _future;
  int? _congregationId;
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
      appBar: AppBar(title: const Text('Assistência')),
      body: congregationId == null
          ? const _Message(
              icon: Icons.apartment_outlined,
              title: 'Escolha uma congregação',
              message:
                  'Selecione uma congregação para consultar a assistência.',
            )
          : FutureBuilder<AttendanceMonth>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _Message(
                    icon: Icons.cloud_off_outlined,
                    title: 'Não foi possível carregar',
                    message: snapshot.error is StateError
                        ? (snapshot.error! as StateError).message.toString()
                        : 'Verifique a conexão e tente novamente.',
                    action: TextButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  );
                }
                return _AttendanceBody(
                  data: snapshot.requireData,
                  onRefresh: _reload,
                  onMonth: _go,
                );
              },
            ),
    );
  }

  Future<AttendanceMonth> _load() => ref
      .read(mobileAppControllerProvider.notifier)
      .loadAttendance(month: _month);

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

  void _go(String month) {
    _month = month;
    setState(() {
      _future = _load();
    });
  }
}

class _AttendanceBody extends StatelessWidget {
  const _AttendanceBody({
    required this.data,
    required this.onRefresh,
    required this.onMonth,
  });

  final AttendanceMonth data;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previous = data.previousMonth;
    final next = data.nextMonth;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mês anterior',
                onPressed: previous == null ? null : () => onMonth(previous),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  monthLabel(data.month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Próximo mês',
                onPressed: next == null ? null : () => onMonth(next),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _AveragesCard(averages: data.averages),
          const SizedBox(height: 16),
          Text('Reuniões do mês', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (data.records.isEmpty)
            const _Message(
              icon: Icons.event_busy_outlined,
              title: 'Nenhuma assistência registrada',
              message: 'Não há registros neste mês.',
            )
          else
            ...data.records.map((record) => _RecordCard(record: record)),
        ],
      ),
    );
  }
}

class _AveragesCard extends StatelessWidget {
  const _AveragesCard({required this.averages});

  final List<AttendanceAverage> averages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Médias do mês', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final average in averages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(average.label),
                          Text(
                            _detail(average),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      average.average?.toString() ?? '—',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: average.average == null
                            ? colors.onSurfaceVariant
                            : colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _detail(AttendanceAverage average) {
    if (average.average == null) return 'sem reuniões neste mês';
    final count = average.meetings;
    final base = '$count ${count == 1 ? 'reunião' : 'reuniões'}';
    if (average.inPerson == null && average.zoom == null) return base;
    return '$base · presencial ${average.inPerson ?? '—'} · Zoom ${average.zoom ?? '—'}';
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortDateLabel(record.date),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(record.typeLabel, style: muted),
                  const SizedBox(height: 4),
                  Text(
                    'Presencial ${record.inPerson ?? '—'} · Zoom ${record.zoom ?? '—'}',
                    style: muted,
                  ),
                  if (record.note != null) Text(record.note!, style: muted),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  record.total?.toString() ?? '—',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('total', style: muted),
              ],
            ),
          ],
        ),
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
