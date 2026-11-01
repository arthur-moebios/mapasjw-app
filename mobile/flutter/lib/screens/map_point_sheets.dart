import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/mobile_api.dart';
import '../models/mobile_models.dart';
import '../state/mobile_app_controller.dart';

/// Dica mostrada junto aos mapas que aceitam marcar pontos.
const String mapPointLongPressHint =
    'Toque e segure no mapa para marcar um ponto';

/// Sentido horário do matiz (0-360) usado pelo marcador padrão do Google Maps.
double mapPointMarkerHue(Color color) {
  final hsv = HSVColor.fromColor(color);
  return hsv.hue;
}

/// Pontos que ficam dentro (ou perto) da área desenhada pelo cartão.
List<MapPoint> mapPointsNear(
  List<MapPoint> points,
  Iterable<LatLng> area, {
  double margin = 0.0015,
}) {
  final coordinates = area.toList(growable: false);
  if (coordinates.isEmpty) return const [];
  var minLat = coordinates.first.latitude;
  var maxLat = minLat;
  var minLng = coordinates.first.longitude;
  var maxLng = minLng;
  for (final c in coordinates) {
    if (c.latitude < minLat) minLat = c.latitude;
    if (c.latitude > maxLat) maxLat = c.latitude;
    if (c.longitude < minLng) minLng = c.longitude;
    if (c.longitude > maxLng) maxLng = c.longitude;
  }
  return points
      .where(
        (p) =>
            p.position.latitude >= minLat - margin &&
            p.position.latitude <= maxLat + margin &&
            p.position.longitude >= minLng - margin &&
            p.position.longitude <= maxLng + margin,
      )
      .toList(growable: false);
}

/// Pega a localização atual e abre o formulário de novo ponto.
Future<void> addMapPointAtCurrentLocation(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = ref.read(mobileAppControllerProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Buscando sua localização…')),
  );
  final error = await controller.locateCurrentPosition();
  messenger.hideCurrentSnackBar();
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  final position = ref
      .read(mobileAppControllerProvider)
      .asData
      ?.value
      .currentPosition;
  if (position == null || !context.mounted) return;
  await showMapPointFormSheet(context, position: position);
}

/// Formulário para marcar um ponto novo ou editar/remover um existente.
Future<void> showMapPointFormSheet(
  BuildContext context, {
  required LatLng position,
  MapPoint? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => MapPointFormSheet(position: position, existing: existing),
);

/// Detalhes de um ponto; quem pode gerenciar vê Editar e Remover.
Future<void> showMapPointDetailsSheet(BuildContext context, MapPoint point) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => MapPointDetailsSheet(point: point),
    );

class MapPointDetailsSheet extends ConsumerWidget {
  const MapPointDetailsSheet({required this.point, super.key});

  final MapPoint point;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage =
        ref
            .watch(mobileAppControllerProvider)
            .asData
            ?.value
            .canManageMapPoints ??
        false;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeDot(color: point.color, icon: point.icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    point.title.isNotEmpty ? point.title : point.type,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Chip(
              avatar: CircleAvatar(backgroundColor: point.color, radius: 6),
              label: Text(point.type),
            ),
            if (point.address.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(point.address),
              ),
            if (point.notes.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notes_rounded),
                title: Text(point.notes),
              ),
            if (canManage) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('map-point-edit'),
                onPressed: () {
                  Navigator.pop(context);
                  showMapPointFormSheet(
                    context,
                    position: point.position,
                    existing: point,
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar ponto'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('map-point-remove'),
                onPressed: () => _confirmRemove(context, ref, point),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remover ponto'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmRemove(
  BuildContext context,
  WidgetRef ref,
  MapPoint point,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remover este ponto?'),
      content: Text(
        'O ponto “${point.title.isNotEmpty ? point.title : point.type}” '
        'sairá do mapa para todos. Isso não pode ser desfeito.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remover'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await ref
        .read(mobileAppControllerProvider.notifier)
        .deleteMapPoint(point.id);
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Ponto removido.')));
    return true;
  } on Object catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(MobileApi.messageForError(error))),
    );
    return false;
  }
}

class MapPointFormSheet extends ConsumerStatefulWidget {
  const MapPointFormSheet({required this.position, this.existing, super.key});

  final LatLng position;
  final MapPoint? existing;

  @override
  ConsumerState<MapPointFormSheet> createState() => _MapPointFormSheetState();
}

class _MapPointFormSheetState extends ConsumerState<MapPointFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  int? _typeId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _address = TextEditingController(text: existing?.address ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _typeId = existing?.typeId;
  }

  @override
  void dispose() {
    _title.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Tipo escolhido; sem escolha, "Não bater" (ou o primeiro da lista).
  int? _effectiveTypeId(List<MapPointType> types) =>
      _typeId ??
      types.where((type) => type.isDoNotVisit).firstOrNull?.id ??
      types.firstOrNull?.id;

  Future<void> _save() async {
    final types =
        ref.read(mobileAppControllerProvider).asData?.value.mapPointTypes ??
        const <MapPointType>[];
    final typeId = _effectiveTypeId(types);
    if (typeId == null) {
      setState(() => _error = 'Escolha o tipo do ponto.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final isEdit = widget.existing != null;
    try {
      await ref.read(mobileAppControllerProvider.notifier).saveMapPoint({
        'type_id': typeId,
        'title': _title.text.trim(),
        'address': _address.text.trim(),
        'notes': _notes.text.trim(),
        'latitude': widget.position.latitude,
        'longitude': widget.position.longitude,
      }, pointId: widget.existing?.id);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Ponto atualizado.' : 'Ponto marcado no mapa.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = MobileApi.messageForError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final types =
        ref.watch(mobileAppControllerProvider).asData?.value.mapPointTypes ??
        const <MapPointType>[];
    final theme = Theme.of(context);
    final existing = widget.existing;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Adicionar ponto' : 'Editar ponto',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Local: ${widget.position.latitude.toStringAsFixed(5)}, '
                '${widget.position.longitude.toStringAsFixed(5)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Text('Tipo de ponto', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              if (types.isEmpty)
                const Text('Nenhum tipo de ponto disponível.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in types)
                      ChoiceChip(
                        key: ValueKey('map-point-type-${type.id}'),
                        selected: _effectiveTypeId(types) == type.id,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _typeId = type.id),
                        avatar: type.icon != null
                            ? Text(type.icon!)
                            : CircleAvatar(
                                backgroundColor: type.color,
                                radius: 7,
                              ),
                        label: Text(type.name),
                        selectedColor: type.color.withValues(alpha: 0.28),
                        side: BorderSide(color: type.color),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('map-point-title'),
                controller: _title,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 191,
                decoration: const InputDecoration(
                  labelText: 'Título (opcional)',
                  hintText: 'Ex.: Casa do portão azul',
                ),
              ),
              TextField(
                key: const ValueKey('map-point-address'),
                controller: _address,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                maxLength: 191,
                decoration: const InputDecoration(
                  labelText: 'Endereço (opcional)',
                  hintText: 'Rua e número',
                ),
              ),
              TextField(
                key: const ValueKey('map-point-notes'),
                controller: _notes,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  hintText: 'Algo que os outros precisam saber',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    key: const ValueKey('map-point-error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('map-point-save'),
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar'),
                    ),
                  ),
                ],
              ),
              if (existing != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('map-point-form-remove'),
                  onPressed: _saving
                      ? null
                      : () => _confirmRemove(context, ref, existing),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remover ponto'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeDot extends StatelessWidget {
  const _TypeDot({required this.color, this.icon});

  final Color color;
  final String? icon;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: color.withValues(alpha: 0.2),
    child: icon != null ? Text(icon!) : Icon(Icons.place_rounded, color: color),
  );
}
