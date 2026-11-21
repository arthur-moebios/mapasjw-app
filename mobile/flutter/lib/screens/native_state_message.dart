import 'package:flutter/material.dart';

/// Mensagem centralizada para vazio, erro e aviso das telas de consulta.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
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

/// Texto do erro de carregamento: StateError traz a mensagem do app.
String loadErrorText(Object? error) => error is StateError
    ? error.message.toString()
    : 'Verifique a conexão e tente novamente.';

/// Cabeçalho com navegação de mês (anterior/próximo).
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.label,
    required this.previous,
    required this.next,
    required this.onMonth,
  });

  final String label;
  final String? previous;
  final String? next;
  final ValueChanged<String> onMonth;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Mês anterior',
        onPressed: previous == null ? null : () => onMonth(previous!),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(
        tooltip: 'Próximo mês',
        onPressed: next == null ? null : () => onMonth(next!),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}
