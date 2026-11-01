import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mobile_models.dart';
import '../state/mobile_app_controller.dart';

class DesignationsScreen extends ConsumerStatefulWidget {
  const DesignationsScreen({super.key});

  @override
  ConsumerState<DesignationsScreen> createState() => _DesignationsScreenState();
}

class _DesignationsScreenState extends ConsumerState<DesignationsScreen> {
  Future<MobileDesignationsData>? _dataFuture;
  int? _congregationId;
  String _search = '';
  bool _groupByPerson = false;

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(mobileAppControllerProvider).requireValue;
    final congregationId = app.selectedCongregationId;

    if (_congregationId != congregationId) {
      _congregationId = congregationId;
      _dataFuture = congregationId == null
          ? null
          : ref
                .read(mobileAppControllerProvider.notifier)
                .loadNativeDesignations();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Designações')),
      body: congregationId == null
          ? const _DesignationsMessage(
              icon: Icons.apartment_outlined,
              title: 'Escolha uma congregação',
              message:
                  'Selecione uma congregação para consultar as designações.',
            )
          : FutureBuilder<MobileDesignationsData>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _DesignationsMessage(
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

                final data = snapshot.data;
                if (data == null) {
                  return const SizedBox.shrink();
                }
                return _content(context, data);
              },
            ),
    );
  }

  Widget _content(BuildContext context, MobileDesignationsData data) {
    final query = _search.trim().toLowerCase();
    final assignments = data.assignments
        .where((item) {
          return query.isEmpty ||
              item.person.toLowerCase().contains(query) ||
              item.condominium.toLowerCase().contains(query) ||
              item.place.toLowerCase().contains(query) ||
              item.level.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final groups = <String, List<MobileDesignation>>{};
    for (final item in assignments) {
      final key = _groupByPerson
          ? 'person:${item.personId}'
          : 'condominium:${item.condominiumId}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Text(
            'Distribuição de territórios',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Confira quem está designado e quais locais estão sob seus cuidados.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryBadge(
                icon: Icons.assignment_outlined,
                label: '${data.assignments.length} locais',
              ),
              _SummaryBadge(
                icon: Icons.people_outline_rounded,
                label: '${data.peopleCount} pessoas',
              ),
              _SummaryBadge(
                icon: Icons.apartment_outlined,
                label: '${data.condominiumsCount} condomínios',
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Buscar pessoa ou local',
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () => setState(() => _search = ''),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Por território'),
                icon: Icon(Icons.apartment_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Por pessoa'),
                icon: Icon(Icons.person_outline_rounded),
              ),
            ],
            selected: {_groupByPerson},
            onSelectionChanged: (selection) =>
                setState(() => _groupByPerson = selection.first),
          ),
          const SizedBox(height: 12),
          if (assignments.isEmpty)
            const _DesignationsMessage(
              icon: Icons.search_off_rounded,
              title: 'Nenhuma designação encontrada',
              message:
                  'Tente alterar a busca ou consulte novamente mais tarde.',
            )
          else
            ...groups.entries.map(
              (group) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  leading: CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.primary,
                    child: Icon(
                      _groupByPerson
                          ? Icons.person_outline_rounded
                          : Icons.apartment_outlined,
                    ),
                  ),
                  title: Text(
                    _groupByPerson
                        ? group.value.first.person
                        : group.value.first.condominium,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${group.value.length} ${group.value.length == 1 ? 'designação' : 'designações'}',
                  ),
                  children: group.value.map(_assignmentTile).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _assignmentTile(MobileDesignation item) {
    final title = _groupByPerson ? item.place : item.person;
    final subtitle = _groupByPerson
        ? '${item.condominium} · ${item.level}'
        : '${item.level} · ${item.condominium}';
    final date = item.since?.split('-').reversed.join('/');

    return ListTile(
      dense: false,
      leading: Icon(
        _groupByPerson ? Icons.place_outlined : Icons.person_outline_rounded,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: date == null ? null : Text(date),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _dataFuture = ref
          .read(mobileAppControllerProvider.notifier)
          .loadNativeDesignations();
    });
    await _dataFuture;
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 17),
    label: Text(label),
    visualDensity: VisualDensity.compact,
  );
}

class _DesignationsMessage extends StatelessWidget {
  const _DesignationsMessage({
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
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
