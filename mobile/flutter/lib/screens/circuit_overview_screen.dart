import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;

import '../models/mobile_models.dart';
import '../state/mobile_app_controller.dart';

class CircuitOverviewScreen extends ConsumerStatefulWidget {
  const CircuitOverviewScreen({super.key});

  @override
  ConsumerState<CircuitOverviewScreen> createState() =>
      _CircuitOverviewScreenState();
}

class _CircuitOverviewScreenState extends ConsumerState<CircuitOverviewScreen> {
  Future<CircuitOverviewData>? _overviewFuture;
  google_maps.GoogleMapController? _mapController;
  int? _congregationFilter;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _load();
  }

  Future<CircuitOverviewData> _load() =>
      ref.read(mobileAppControllerProvider.notifier).loadCircuitOverview();

  Future<void> _refresh() async {
    setState(() => _overviewFuture = _load());
    await _overviewFuture;
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(mobileAppControllerProvider).requireValue;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos · Circuito RJ-14'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<CircuitOverviewData>(
        future: _overviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is StateError
                ? (snapshot.error! as StateError).message.toString()
                : 'Confira sua conexão e tente carregar novamente.';
            return _OverviewMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar o circuito',
              message: message,
              action: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            );
          }

          final overview = snapshot.data!;
          final congregations = overview.congregations
              .where(
                (item) =>
                    _congregationFilter == null ||
                    item.id == _congregationFilter,
              )
              .toList(growable: false);
          final boundaries = overview.boundaries
              .where(
                (item) =>
                    _congregationFilter == null ||
                    item.congregationId == _congregationFilter,
              )
              .toList(growable: false);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Visão geral do circuito',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Limites e atividade por congregação, sem dados pessoais.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _CircuitTotals(totals: overview.totals),
                const SizedBox(height: 18),
                Text(
                  'Limites históricos',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: _congregationFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mostrar congregação',
                    prefixIcon: Icon(Icons.filter_list_rounded),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Todas as congregações',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...overview.congregations.map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _congregationFilter = value;
                    _fitBounds();
                  }),
                ),
                const SizedBox(height: 10),
                _CircuitMap(
                  boundaries: boundaries,
                  isConfigured: app.isMapsConfigured,
                  configurationError: app.mapsConfigError,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _fitBounds(boundaries);
                    });
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  'Atividade por congregação',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (congregations.isEmpty)
                  const _OverviewMessage(
                    icon: Icons.map_outlined,
                    title: 'Nenhuma congregação neste circuito',
                    message: 'Os limites ainda não foram cadastrados.',
                  )
                else
                  ...congregations.map(
                    (item) => _CongregationSummaryCard(summary: item),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Os dias de percurso são somados por congregação. Percursos de teste ficam fora dos totais.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _fitBounds([List<CircuitBoundary>? overrideBoundaries]) {
    final controller = _mapController;
    final future = _overviewFuture;
    if (controller == null || future == null) return;
    future.then((overview) {
      if (!mounted) return;
      final boundaries =
          overrideBoundaries ??
          overview.boundaries
              .where(
                (item) =>
                    _congregationFilter == null ||
                    item.congregationId == _congregationFilter,
              )
              .toList(growable: false);
      final points = boundaries.expand(_boundaryPoints).toList(growable: false);
      if (points.isEmpty) return;

      final bounds = google_maps.LatLngBounds(
        southwest: google_maps.LatLng(
          points.map((point) => point.latitude).reduce((a, b) => a < b ? a : b),
          points
              .map((point) => point.longitude)
              .reduce((a, b) => a < b ? a : b),
        ),
        northeast: google_maps.LatLng(
          points.map((point) => point.latitude).reduce((a, b) => a > b ? a : b),
          points
              .map((point) => point.longitude)
              .reduce((a, b) => a > b ? a : b),
        ),
      );
      controller.animateCamera(
        google_maps.CameraUpdate.newLatLngBounds(bounds, 28),
      );
    });
  }
}

class _CircuitTotals extends StatelessWidget {
  const _CircuitTotals({required this.totals});

  final CircuitOverviewTotals totals;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 1.65,
    children: [
      _TotalTile(value: totals.congregations, label: 'Congregações'),
      _TotalTile(value: totals.boundaries, label: 'Limites históricos'),
      _TotalTile(value: totals.streetCards, label: 'Cartões de rua'),
      _TotalTile(value: totals.streetSegments, label: 'Trechos de rua'),
      _TotalTile(value: totals.workEntries, label: 'Registros de trabalho'),
      _TotalTile(value: totals.routePoints, label: 'Pontos de percurso'),
    ],
  );
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CircuitMap extends StatelessWidget {
  const _CircuitMap({
    required this.boundaries,
    required this.isConfigured,
    required this.configurationError,
    required this.onMapCreated,
  });

  final List<CircuitBoundary> boundaries;
  final bool isConfigured;
  final String? configurationError;
  final ValueChanged<google_maps.GoogleMapController> onMapCreated;

  @override
  Widget build(BuildContext context) {
    if (!isConfigured) {
      return Container(
        height: 270,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 36),
            const SizedBox(height: 10),
            Text(
              configurationError ?? 'Preparando o mapa do circuito…',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final polygons = <google_maps.Polygon>{};
    for (final boundary in boundaries) {
      final geometry = boundary.geometry;
      final type = geometry['type'];
      final coordinates = geometry['coordinates'];
      if (type == 'Polygon' && coordinates is List) {
        _addPolygon(polygons, boundary, coordinates, 0);
      } else if (type == 'MultiPolygon' && coordinates is List) {
        for (var index = 0; index < coordinates.length; index++) {
          final polygon = coordinates[index];
          if (polygon is List) _addPolygon(polygons, boundary, polygon, index);
        }
      }
    }

    final points = boundaries.expand(_boundaryPoints).toList(growable: false);
    final target = points.isEmpty
        ? const google_maps.LatLng(-22.43, -43.13)
        : points.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 300,
        child: google_maps.GoogleMap(
          initialCameraPosition: google_maps.CameraPosition(
            target: target,
            zoom: 9,
          ),
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
          polygons: polygons,
          onMapCreated: onMapCreated,
        ),
      ),
    );
  }

  void _addPolygon(
    Set<google_maps.Polygon> result,
    CircuitBoundary boundary,
    List<dynamic> rings,
    int part,
  ) {
    if (rings.isEmpty) return;
    final outer = _coordinates(rings.first);
    if (outer.length < 3) return;
    final holes = rings
        .skip(1)
        .map(_coordinates)
        .where((ring) => ring.length >= 3)
        .toList();
    result.add(
      google_maps.Polygon(
        polygonId: google_maps.PolygonId(
          'boundary-${boundary.congregationId}-${boundary.label}-$part',
        ),
        points: outer,
        holes: holes,
        strokeColor: boundary.color,
        strokeWidth: 2,
        fillColor: boundary.color.withValues(alpha: 0.18),
      ),
    );
  }
}

List<google_maps.LatLng> _coordinates(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<List>()
      .where((pair) => pair.length >= 2)
      .map((pair) {
        final longitude = (pair[0] as num).toDouble();
        final latitude = (pair[1] as num).toDouble();
        return google_maps.LatLng(latitude, longitude);
      })
      .toList(growable: false);
}

Iterable<google_maps.LatLng> _boundaryPoints(CircuitBoundary boundary) sync* {
  final coordinates = boundary.geometry['coordinates'];
  if (coordinates is! List) return;
  final type = boundary.geometry['type'];
  if (type == 'Polygon') {
    for (final ring in coordinates) {
      yield* _coordinates(ring);
    }
  } else if (type == 'MultiPolygon') {
    for (final polygon in coordinates) {
      if (polygon is! List) continue;
      for (final ring in polygon) {
        yield* _coordinates(ring);
      }
    }
  }
}

class _CongregationSummaryCard extends StatelessWidget {
  const _CongregationSummaryCard({required this.summary});

  final CircuitCongregationSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final usage = summary.legacyUsagePercent;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: summary.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    summary.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _MetricBadge(
                  label:
                      '${summary.boundaries} ${summary.boundaries == 1 ? 'limite' : 'limites'}',
                  color: summary.color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricBadge(
                  label: '${summary.streetCards} cartões de rua',
                  color: colors.primary,
                ),
                _MetricBadge(
                  label: '${summary.streetSegments} trechos',
                  color: colors.secondary,
                ),
                _MetricBadge(
                  label: '${summary.routeDays} dias de percurso',
                  color: colors.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              summary.legacyCards == 0
                  ? 'Sem cartões históricos para medir uso'
                  : 'Cartões históricos com registro: ${summary.legacyCardsWorked} de ${summary.legacyCards}${usage == null ? '' : ' · $usage%'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${summary.workEntries} registros de trabalho · ${summary.routePoints} pontos de percurso',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _OverviewMessage extends StatelessWidget {
  const _OverviewMessage({
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
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    ),
  );
}
