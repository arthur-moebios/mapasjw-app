// Future.ignore() é extensão de dart:async: sem este import a extensão não
// entra em escopo. Mesma convenção dos outros arquivos que usam unawaited().
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../models/cart.dart';
import '../state/mobile_app_controller.dart';
import 'native_state_message.dart';

/// Carrinho: calendário de turnos e minhas inscrições (somente leitura).
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  Future<CartCalendar>? _calendar;
  Future<CartMySignups>? _signups;
  int? _congregationId;
  bool _showSignups = false;
  String? _month;
  int? _spotId;

  @override
  void initState() {
    super.initState();
    _startFor(
      ref.read(mobileAppControllerProvider).value?.selectedCongregationId,
    );
  }

  void _startFor(int? congregationId) {
    _congregationId = congregationId;
    _month = null;
    _spotId = null;
    _calendar = congregationId == null ? null : _loadCalendar();
    _signups = congregationId == null ? null : _loadSignups();
    // A aba oculta não escuta o seu Future; sem isto, um erro nela viraria
    // exceção não tratada. O FutureBuilder continua recebendo o erro.
    _calendar?.ignore();
    _signups?.ignore();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(
      mobileAppControllerProvider.select(
        (value) => value.value?.selectedCongregationId,
      ),
      (previous, next) {
        if (next != _congregationId) setState(() => _startFor(next));
      },
    );
    final app = ref.watch(mobileAppControllerProvider).requireValue;
    final congregationId = app.selectedCongregationId;

    return Scaffold(
      appBar: AppBar(title: const Text('Carrinho')),
      body: congregationId == null
          ? const StateMessage(
              icon: Icons.apartment_outlined,
              title: 'Escolha uma congregação',
              message: 'Selecione uma congregação para consultar o carrinho.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('Calendário'),
                        selected: !_showSignups,
                        onSelected: (_) => setState(() => _showSignups = false),
                      ),
                      ChoiceChip(
                        label: const Text('Minhas inscrições'),
                        selected: _showSignups,
                        onSelected: (_) => setState(() => _showSignups = true),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _showSignups ? _signupsView() : _calendarView(),
                ),
              ],
            ),
    );
  }

  Widget _calendarView() => FutureBuilder<CartCalendar>(
    future: _calendar,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return StateMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Não foi possível carregar',
          message: loadErrorText(snapshot.error),
          action: TextButton.icon(
            onPressed: _reloadCalendar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        );
      }
      return _CalendarBody(
        data: snapshot.requireData,
        spotId: _spotId,
        onRefresh: _reloadCalendar,
        onMonth: (month) {
          _month = month;
          _reloadCalendar();
        },
        onSpot: (spot) {
          _spotId = spot;
          _reloadCalendar();
        },
      );
    },
  );

  Widget _signupsView() => FutureBuilder<CartMySignups>(
    future: _signups,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return StateMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Não foi possível carregar',
          message: loadErrorText(snapshot.error),
          action: TextButton.icon(
            onPressed: _reloadSignups,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        );
      }
      final data = snapshot.requireData;
      if (!data.linked) {
        return const StateMessage(
          icon: Icons.link_off_outlined,
          title: 'Conta sem publicador vinculado',
          message:
              'Esta conta não está vinculada a um publicador, por isso não há inscrições para mostrar. Peça a um responsável para vincular sua conta.',
        );
      }
      if (data.signups.isEmpty) {
        return const StateMessage(
          icon: Icons.event_busy_outlined,
          title: 'Nenhuma inscrição',
          message: 'Você ainda não se inscreveu em turnos do carrinho.',
        );
      }
      return RefreshIndicator(
        onRefresh: _reloadSignups,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            for (final signup in data.signups) _SignupTile(signup: signup),
          ],
        ),
      );
    },
  );

  // `async` garante que até um erro síncrono vire um Future com erro,
  // exibido pelo FutureBuilder em vez de escapar do ciclo de vida do widget.
  Future<CartCalendar> _loadCalendar() async => ref
      .read(mobileAppControllerProvider.notifier)
      .loadCartCalendar(month: _month, spotId: _spotId);

  Future<CartMySignups> _loadSignups() async =>
      ref.read(mobileAppControllerProvider.notifier).loadCartMySignups();

  Future<void> _reloadCalendar() async {
    setState(() {
      _calendar = _loadCalendar();
    });
    try {
      await _calendar;
    } catch (_) {
      // O erro já aparece na tela, com "Tentar novamente".
    }
  }

  Future<void> _reloadSignups() async {
    setState(() {
      _signups = _loadSignups();
    });
    try {
      await _signups;
    } catch (_) {
      // O erro já aparece na tela, com "Tentar novamente".
    }
  }
}

String _dayText(String? iso) {
  final date = parseIsoDate(iso);
  return date == null ? (iso ?? '') : shortDateLabel(date);
}

String _range(String? start, String? end) {
  if (start == null && end == null) return '';
  if (end == null) return start!;
  if (start == null) return end;
  return '$start–$end';
}

Color _stateColor(String state) {
  switch (state) {
    case 'cheio':
      return const Color(0xFF2E7D32);
    case 'parcial':
      return const Color(0xFFB8860B);
    case 'buraco':
      return const Color(0xFFC62828);
    default:
      return const Color(0xFF6B7280);
  }
}

String _stateLabel(String state) {
  switch (state) {
    case 'cheio':
      return 'Completo';
    case 'parcial':
      return 'Parcial';
    case 'buraco':
      return 'Com buraco';
    default:
      return 'Livre';
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.data,
    required this.spotId,
    required this.onRefresh,
    required this.onMonth,
    required this.onSpot,
  });

  final CartCalendar data;
  final int? spotId;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onMonth;
  final ValueChanged<int?> onSpot;

  @override
  Widget build(BuildContext context) {
    final days = data.days
        .where((day) => day.inMonth && day.shifts.isNotEmpty)
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          MonthSwitcher(
            label: monthLabel(data.month),
            previous: data.previousMonth,
            next: data.nextMonth,
            onMonth: onMonth,
          ),
          if (data.spots.length > 1)
            DropdownButtonFormField<int?>(
              key: ValueKey('spot-$spotId'),
              initialValue: spotId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ponto'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todos os pontos'),
                ),
                for (final spot in data.spots)
                  DropdownMenuItem<int?>(
                    value: spot.id,
                    child: Text(spot.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onSpot,
            ),
          if (!data.hasShifts || days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Nenhum turno neste mês')),
            ),
          for (final day in days) _DayCard(day: day),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final CartDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    day.today ? '${_dayText(day.date)} · hoje' : _dayText(day.date),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (!day.past && day.openSlots > 0)
                  Text(
                    '${day.openSlots} vaga(s)',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            for (final shift in day.shifts) _ShiftRow(shift: shift),
          ],
        ),
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.shift});

  final CartShift shift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _stateColor(shift.state);
    final names = shift.people
        .map((p) => p.firstName ?? 'Sem nome')
        .join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            margin: const EdgeInsets.only(right: 8),
            color: color,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shift.spot} · ${_range(shift.start, shift.end)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  [
                    if (shift.type != null) shift.type!.toUpperCase(),
                    _stateLabel(shift.state),
                    '${shift.occupied}/${shift.capacity}',
                    if (shift.pending > 0) '${shift.pending} pendente(s)',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
                if (names.isNotEmpty)
                  Text(names, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupTile extends StatelessWidget {
  const _SignupTile({required this.signup});

  final CartSignup signup;

  @override
  Widget build(BuildContext context) {
    final status = switch (signup.status) {
      'aprovada' => 'Aprovada',
      'recusada' => 'Recusada',
      _ => 'Pendente',
    };
    final when = signup.weekly
        ? 'Toda semana${signup.weekday == null ? '' : ' · ${signup.weekday}'}'
        : (signup.date == null ? 'Data a definir' : _dayText(signup.date));
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        title: Text(signup.spot?.name ?? 'Ponto do carrinho'),
        subtitle: Text(
          [
            when,
            if (_range(signup.start, signup.end).isNotEmpty)
              _range(signup.start, signup.end),
            if (signup.role != null) signup.role!,
            if (signup.spot?.address != null) signup.spot!.address!,
          ].join(' · '),
        ),
        trailing: Text(status),
      ),
    );
  }
}
