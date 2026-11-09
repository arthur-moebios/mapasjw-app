import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mobile_models.dart';
import '../state/mobile_app_controller.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  Future<List<MobilePerson>>? _peopleFuture;
  int? _congregationId;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(mobileAppControllerProvider).requireValue;
    final congregationId = app.selectedCongregationId;
    if (_congregationId != congregationId) {
      _congregationId = congregationId;
      _peopleFuture = congregationId == null
          ? null
          : ref.read(mobileAppControllerProvider.notifier).loadNativePeople();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pessoas')),
      body: congregationId == null
          ? const _PeopleMessage(
              icon: Icons.apartment_outlined,
              title: 'Escolha uma congregação',
              message: 'Selecione uma congregação para consultar as pessoas.',
            )
          : FutureBuilder<List<MobilePerson>>(
              future: _peopleFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _PeopleMessage(
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

                final people = (snapshot.data ?? const <MobilePerson>[])
                    .where((person) {
                      final query = _search.trim().toLowerCase();
                      return query.isEmpty ||
                          person.name.toLowerCase().contains(query) ||
                          person.email.toLowerCase().contains(query) ||
                          person.profile.toLowerCase().contains(query);
                    })
                    .toList(growable: false);
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                    children: [
                      Text(
                        'Pessoas da congregação',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${snapshot.data?.length ?? 0} cadastradas',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (value) => setState(() => _search = value),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: 'Buscar nome, e-mail ou perfil',
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
                      if (people.isEmpty)
                        const _PeopleMessage(
                          icon: Icons.search_off_rounded,
                          title: 'Nenhuma pessoa encontrada',
                          message: 'Tente outro nome, e-mail ou perfil.',
                        )
                      else
                        ...people.map((person) => _PersonCard(person: person)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _peopleFuture = ref
          .read(mobileAppControllerProvider.notifier)
          .loadNativePeople();
    });
    await _peopleFuture;
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final MobilePerson person;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.primary,
          child: Text(
            person.name.isEmpty
                ? '?'
                : person.name.characters.first.toUpperCase(),
          ),
        ),
        title: Text(
          '${person.name}${person.isSelf ? ' · Você' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.email),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 5,
                children: [
                  _PersonBadge(
                    label: person.profile,
                    color: colors.secondaryContainer,
                    foreground: colors.onSecondaryContainer,
                  ),
                  _PersonBadge(
                    label: person.isActive ? 'Ativa' : 'Inativa',
                    color: person.isActive
                        ? const Color(0xFFE6F4EA)
                        : colors.errorContainer,
                    foreground: person.isActive
                        ? const Color(0xFF246B45)
                        : colors.onErrorContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _PersonBadge extends StatelessWidget {
  const _PersonBadge({
    required this.label,
    required this.color,
    required this.foreground,
  });

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _PeopleMessage extends StatelessWidget {
  const _PeopleMessage({
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
