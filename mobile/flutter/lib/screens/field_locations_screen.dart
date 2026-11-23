import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/field_locations.dart';
import '../models/mobile_models.dart';
import '../state/mobile_app_controller.dart';
import 'native_state_message.dart';

/// Locais de campo (pontos de encontro), com desativados em destaque.
class FieldLocationsScreen extends ConsumerStatefulWidget {
  const FieldLocationsScreen({super.key});

  @override
  ConsumerState<FieldLocationsScreen> createState() =>
      _FieldLocationsScreenState();
}

class _FieldLocationsScreenState extends ConsumerState<FieldLocationsScreen> {
  Future<FieldLocationsPage>? _future;
  int? _congregationId;
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _startFor(
      ref.read(mobileAppControllerProvider).value?.selectedCongregationId,
    );
  }

  void _startFor(int? congregationId) {
    _congregationId = congregationId;
    _future = congregationId == null ? null : _load();
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
      appBar: AppBar(title: const Text('Locais de campo')),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _edit(null),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Novo local'),
            )
          : null,
      body: congregationId == null
          ? const StateMessage(
              icon: Icons.apartment_outlined,
              title: 'Escolha uma congregação',
              message: 'Selecione uma congregação para consultar os locais.',
            )
          : FutureBuilder<FieldLocationsPage>(
              future: _future,
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
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  );
                }
                final page = snapshot.requireData;
                if (page.locations.isEmpty) {
                  return const StateMessage(
                    icon: Icons.place_outlined,
                    title: 'Nenhum local cadastrado',
                    message: 'Os pontos de encontro do campo aparecem aqui.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    children: [
                      for (final location in page.locations)
                        _LocationTile(
                          location: location,
                          canManage: page.canManage,
                          onEdit: () => _edit(location),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<FieldLocationsPage> _load() async {
    final page = await ref
        .read(mobileAppControllerProvider.notifier)
        .loadFieldLocations();
    if (mounted && page.canManage != _canManage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _canManage = page.canManage);
      });
    }
    return page;
  }

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

  Future<void> _edit(FieldLocation? location) async {
    final data = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _LocationDialog(location: location),
    );
    if (data == null || !mounted) return;
    final controller = ref.read(mobileAppControllerProvider.notifier);
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    try {
      if (location == null) {
        await controller.createFieldLocation(data, month: month);
      } else {
        await controller.updateFieldLocation(location.id, data, month: month);
      }
      await _reload();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Não foi possível salvar o local. Tente novamente.',
          ),
        ),
      );
    }
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.location,
    required this.canManage,
    required this.onEdit,
  });

  final FieldLocation location;
  final bool canManage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = location.active;
    final muted = theme.colorScheme.outline;
    final scheme = theme.colorScheme;
    final secondary = scheme.onSurfaceVariant;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
    return Opacity(
      opacity: active ? 1 : 0.6,
      child: Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: Icon(
                  location.online
                      ? Icons.videocam_outlined
                      : Icons.place_outlined,
                  color: active ? scheme.primary : muted,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: active ? null : TextDecoration.lineThrough,
                        color: active ? null : muted,
                      ),
                    ),
                    if (!active || location.online)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (!active)
                              _StatusChip(
                                label: 'Desativado',
                                background: scheme.errorContainer,
                                foreground: scheme.onErrorContainer,
                              ),
                            if (location.online)
                              _StatusChip(
                                label: 'Reunião online',
                                background: scheme.secondaryContainer,
                                foreground: scheme.onSecondaryContainer,
                              ),
                          ],
                        ),
                      ),
                    if (location.address.isNotEmpty)
                      line(Icons.signpost_outlined, location.address),
                    if (location.reference.isNotEmpty)
                      line(
                        Icons.info_outline_rounded,
                        'Ref.: ${location.reference}',
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (location.mapsUrl.isNotEmpty)
                    IconButton(
                      tooltip: 'Abrir no mapa',
                      icon: const Icon(Icons.map_outlined),
                      onPressed: () {
                        final uri = Uri.tryParse(location.mapsUrl);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  if (canManage)
                    IconButton(
                      tooltip: 'Editar local',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _LocationDialog extends StatefulWidget {
  const _LocationDialog({this.location});

  final FieldLocation? location;

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _reference;
  late final TextEditingController _maps;
  late bool _active;
  String? _error;

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    _name = TextEditingController(text: location?.name ?? '');
    _address = TextEditingController(text: location?.address ?? '');
    _reference = TextEditingController(text: location?.reference ?? '');
    _maps = TextEditingController(text: location?.mapsUrl ?? '');
    _active = location?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _reference.dispose();
    _maps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    return AlertDialog(
      title: Text(location == null ? 'Novo local' : 'Editar local'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Nome', errorText: _error),
            ),
            TextField(
              controller: _address,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Endereço'),
            ),
            TextField(
              controller: _reference,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Referência'),
            ),
            TextField(
              controller: _maps,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Link do mapa'),
            ),
            if (location != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Local ativo'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _error = 'Informe o nome do local.');
              return;
            }
            final location = widget.location;
            Navigator.pop(context, <String, Object?>{
              'name': _name.text.trim(),
              'address': _address.text.trim(),
              'reference': _reference.text.trim(),
              'maps_url': _maps.text.trim(),
              if (location != null) ...{
                'lat': location.lat,
                'lng': location.lng,
                'virtual': location.online,
                'active': _active,
              },
            });
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
