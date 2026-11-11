import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/mobile_models.dart';
import '../state/mobile_app_controller.dart';
import 'designations_screen.dart';
import 'circuit_overview_screen.dart';
import 'field_outings_screen.dart';
import 'map_point_sheets.dart';
import 'follow_up_screen.dart';
import 'native_sections_screen.dart';
import 'people_screen.dart';
import 'territory_details_sheet.dart';

const Color _historicalBoundaryColor = Color(0xFF75808A);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  google_maps.GoogleMapController? _mapController;
  LatLng? _pendingMapCenter;
  double _pendingMapZoom = 14;
  int _tab = 0;
  String _territorySearchQuery = '';
  String _mapLayerFilter = 'todos';
  String? _territoryGroupFilter;
  bool _showMapPoints = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mobileAppControllerProvider).requireValue;
    final controller = ref.read(mobileAppControllerProvider.notifier);
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.query_stats_outlined),
        selectedIcon: Icon(Icons.query_stats_rounded),
        label: 'Início',
      ),
    ];
    if (state.canViewTerritories || state.canViewStreetCards) {
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Mapa',
        ),
      );
    }
    if (state.canViewLetters) {
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.mail_outline_rounded),
          selectedIcon: Icon(Icons.mail_rounded),
          label: 'Cartas',
        ),
      );
    }
    if (state.canViewStreetCards) {
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route_rounded),
          label: 'Cartões',
        ),
      );
    }
    if (state.canViewStreetCards) {
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check_rounded),
          label: 'Acompanhar',
        ),
      );
    }
    if (state.canViewFieldOutings) {
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Campo',
        ),
      );
    }
    destinations.add(
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Conta',
      ),
    );
    final children = <Widget>[
      DashboardScreen(
        onNavigate: (label) {
          final index = destinations.indexWhere(
            (destination) => destination.label == label,
          );
          if (index >= 0) {
            _selectTab(index, destinations[index].label, controller);
          }
        },
        onOpenStreetCard: (card) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StreetCardDetailScreen(card: card),
          ),
        ),
        onOpenCircuitOverview: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CircuitOverviewScreen(),
          ),
        ),
      ),
      if (state.canViewTerritories || state.canViewStreetCards) ...[
        _MapTab(
          state: state,
          onMapCreated: _onMapCreated,
          onSelectTerritory: _selectTerritory,
          onSelectStreetCard: (card) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StreetCardDetailScreen(card: card),
            ),
          ),
          searchQuery: _territorySearchQuery,
          layerFilter: _mapLayerFilter,
          groupFilter: _territoryGroupFilter,
          onSearchQueryChanged: (value) => setState(() {
            _territorySearchQuery = value;
          }),
          onLayerFilterChanged: (value) => setState(() {
            _mapLayerFilter = value;
          }),
          onGroupFilterChanged: (value) => setState(() {
            _territoryGroupFilter = value;
          }),
          onLocateCurrentPosition: _locateCurrentPosition,
          isLocating: state.isLocating,
          showMapPoints: _showMapPoints,
          onShowMapPointsChanged: (value) => setState(() {
            _showMapPoints = value;
          }),
        ),
      ],
      if (state.canViewLetters) const LettersScreen(),
      if (state.canViewStreetCards) const StreetCardsScreen(),
      if (state.canViewStreetCards)
        FollowUpScreen(
          active:
              destinations[_tab.clamp(0, destinations.length - 1)].label ==
              'Acompanhar',
        ),
      if (state.canViewFieldOutings) const FieldOutingsScreen(),
      _AccountTab(
        state: state,
        onNavigate: (label) {
          final index = destinations.indexWhere(
            (destination) => destination.label == label,
          );
          if (index >= 0) {
            _selectTab(index, destinations[index].label, controller);
          }
        },
      ),
    ];
    final selectedTab = _tab.clamp(0, children.length - 1);

    VoidCallback? refreshAction;
    final selectedLabel = destinations[selectedTab].label;
    if (selectedLabel == 'Início') {
      refreshAction = () {
        unawaited(controller.refreshDashboard(force: true));
        if (state.canViewFieldOutings) {
          final now = DateTime.now();
          unawaited(
            controller.refreshFieldCalendar(
              month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
              force: true,
            ),
          );
        }
      };
    } else if (selectedLabel == 'Mapa') {
      refreshAction = () {
        unawaited(controller.refreshTerritories(force: true));
        unawaited(controller.refreshMapPoints(force: true));
        if (state.canViewStreetCards) {
          unawaited(
            controller.refreshStreetCards(force: true, includeGeometry: true),
          );
        }
      };
    } else if (selectedLabel == 'Cartas') {
      refreshAction = () => controller.refreshCondominiums(force: true);
    } else if (selectedLabel == 'Cartões') {
      refreshAction = () => controller.refreshStreetCards(force: true);
    } else if (selectedLabel == 'Campo') {
      final now = DateTime.now();
      refreshAction = () => controller.refreshFieldCalendar(
        month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
        force: true,
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: state.isSuperAdmin
            ? _congregationPicker(state, controller)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mapas JW'),
                  Text(
                    _congregationLine(state.selectedCongregation) ??
                        'Sua congregação',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
        actions: [
          if (refreshAction != null)
            IconButton(
              tooltip: 'Atualizar',
              onPressed:
                  state.isLoadingTerritories ||
                      state.isLoadingMapPoints ||
                      state.isLoadingLetters ||
                      state.isLoadingStreetCards ||
                      state.isLoadingDashboard ||
                      state.isLoadingFieldCalendar
                  ? null
                  : refreshAction,
              icon:
                  state.isLoadingTerritories ||
                      state.isLoadingMapPoints ||
                      state.isLoadingLetters ||
                      state.isLoadingStreetCards ||
                      state.isLoadingDashboard ||
                      state.isLoadingFieldCalendar
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: selectedTab, children: children),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          _selectTab(index, destinations[index].label, controller);
        },
        destinations: destinations,
      ),
    );
  }

  void _selectTab(int index, String label, MobileAppController controller) {
    setState(() => _tab = index);
    switch (label) {
      case 'Início':
        unawaited(controller.refreshDashboard());
        break;
      case 'Mapa':
        unawaited(controller.ensureMapsConfigured());
        unawaited(controller.refreshTerritories());
        unawaited(controller.refreshMapPoints());
        unawaited(controller.refreshStreetCards(includeGeometry: true));
        break;
      case 'Cartas':
        unawaited(controller.refreshCondominiums());
        break;
      case 'Cartões':
        unawaited(controller.refreshStreetCards());
        break;
      case 'Campo':
        final now = DateTime.now();
        unawaited(
          controller.refreshFieldCalendar(
            month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          ),
        );
        break;
    }
  }

  void _onMapCreated(google_maps.GoogleMapController controller) {
    _mapController = controller;
    final center = _pendingMapCenter;
    if (center != null) {
      unawaited(
        controller.animateCamera(
          google_maps.CameraUpdate.newLatLngZoom(
            _googleLatLng(center),
            _pendingMapZoom,
          ),
        ),
      );
      _pendingMapCenter = null;
    }
  }

  void _moveMap(LatLng center, double zoom) {
    _pendingMapCenter = center;
    _pendingMapZoom = zoom;
    final mapController = _mapController;
    if (mapController != null) {
      unawaited(
        mapController.animateCamera(
          google_maps.CameraUpdate.newLatLngZoom(_googleLatLng(center), zoom),
        ),
      );
      _pendingMapCenter = null;
    }
  }

  Widget _congregationPicker(
    MobileAppState state,
    MobileAppController controller,
  ) {
    return DropdownButton<int>(
      value: state.selectedCongregationId,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      hint: const Text('Escolher congregação'),
      items: state.congregations
          .map(
            (congregation) => DropdownMenuItem<int>(
              value: congregation.id,
              child: Text(congregation.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged:
          state.isTracking ||
              state.isStartingRoute ||
              state.isLoadingTerritories ||
              state.isLoadingLetters ||
              state.isLoadingStreetCards ||
              state.isLoadingDashboard ||
              state.isLoadingMapsConfig
          ? null
          : (id) {
              if (id != null) controller.selectCongregation(id);
            },
    );
  }

  void _selectTerritory(Territory territory) {
    ref
        .read(mobileAppControllerProvider.notifier)
        .selectTerritory(territory.id);
    setState(() => _tab = 1);
    final center = territory.preferredCenter;
    if (center != null) _moveMap(center, 15);
  }

  Future<void> _locateCurrentPosition() async {
    final message = await ref
        .read(mobileAppControllerProvider.notifier)
        .locateCurrentPosition();
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final position = ref
        .read(mobileAppControllerProvider)
        .requireValue
        .currentPosition;
    if (position != null) _moveMap(position, 17);
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab({
    required this.state,
    required this.onMapCreated,
    required this.onSelectTerritory,
    required this.onSelectStreetCard,
    required this.searchQuery,
    required this.layerFilter,
    required this.groupFilter,
    required this.onSearchQueryChanged,
    required this.onLayerFilterChanged,
    required this.onGroupFilterChanged,
    required this.onLocateCurrentPosition,
    required this.isLocating,
    required this.showMapPoints,
    required this.onShowMapPointsChanged,
  });

  final MobileAppState state;
  final ValueChanged<google_maps.GoogleMapController> onMapCreated;
  final ValueChanged<Territory> onSelectTerritory;
  final ValueChanged<StreetCardSummary> onSelectStreetCard;
  final String searchQuery;
  final String layerFilter;
  final String? groupFilter;
  final ValueChanged<String> onSearchQueryChanged;
  final ValueChanged<String> onLayerFilterChanged;
  final ValueChanged<String?> onGroupFilterChanged;
  final VoidCallback onLocateCurrentPosition;
  final bool isLocating;
  final bool showMapPoints;
  final ValueChanged<bool> onShowMapPointsChanged;

  @override
  Widget build(BuildContext context) {
    if (state.selectedCongregationId == null && state.isSuperAdmin) {
      return _StateMessage(
        icon: Icons.apartment_rounded,
        title: 'Escolha uma congregação',
        message: 'Os cartões só aparecem depois que você seleciona a congregação que deseja consultar.',
      );
    }
    if (!state.canViewTerritories && !state.canViewStreetCards) {
      return _StateMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Acesso não habilitado',
        message: 'Sua conta ainda não tem permissão para visualizar os cartões desta congregação.',
      );
    }
    if (!state.isMapsConfigured) {
      if (state.isLoadingMapsConfig) {
        return const Center(child: CircularProgressIndicator());
      }

      return _StateMessage(
        icon: state.mapsConfigError == null
            ? Icons.map_outlined
            : Icons.error_outline_rounded,
        title: state.mapsConfigError == null
            ? 'Preparando o mapa'
            : 'Mapa indisponível',
        message: state.mapsConfigError ?? 'A configuração segura do Google Maps será carregada ao abrir esta aba.',
      );
    }
    if ((state.isLoadingTerritories ||
            state.isLoadingMapPoints ||
            state.isLoadingStreetCards) &&
        state.territories.isEmpty &&
        state.streetCards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final allStreetCardsWithGeometry = state.streetCards
        .where(
          (card) =>
              card.streetLines.any((line) => line.coordinates.length >= 2),
        )
        .toList(growable: false);
    if (state.territories.isEmpty &&
        allStreetCardsWithGeometry.isEmpty &&
        state.mapPoints.isEmpty) {
      return _StateMessage(
        icon: Icons.map_outlined,
        title: 'Nenhum cartão com mapa',
        message: 'Os cartões de rua aparecerão aqui quando tiverem trechos cadastrados.',
      );
    }

    final visibleTerritories = filterTerritories(
      territories: state.canViewTerritories && layerFilter != 'cartoes_rua'
          ? state.territories
          : const <Territory>[],
      searchQuery: searchQuery,
      situation: 'todos',
      group: groupFilter,
    );
    final visibleStreetCards =
        state.canViewStreetCards && layerFilter != 'limites_historicos'
        ? allStreetCardsWithGeometry
              .where(
                (card) => card.matchesFilters(
                  searchQuery: searchQuery,
                  groupFilter: groupFilter,
                ),
              )
              .toList(growable: false)
        : const <StreetCardSummary>[];
    final selected = visibleTerritories
        .where((territory) => territory.id == state.selectedTerritoryId)
        .firstOrNull;
    final firstStreetPoint = visibleStreetCards
        .expand((card) => card.streetLines)
        .expand((line) => line.coordinates)
        .firstOrNull;
    final visibleMapPoints = showMapPoints
        ? state.mapPoints
        : const <MapPoint>[];
    final initialCenter =
        selected?.preferredCenter ??
        firstStreetPoint ??
        (showMapPoints ? state.mapPoints.firstOrNull?.position : null) ??
        state.territories.firstOrNull?.preferredCenter ??
        const LatLng(-15.78, -47.93);
    final groups =
        <String>{
          ...state.territories.map(
            (territory) => territory.group?.trim() ?? '',
          ),
          ...state.streetCards.map((card) => card.group.trim()),
        }.where((group) => group.isNotEmpty).toList()..sort(
          (first, second) =>
              first.toLowerCase().compareTo(second.toLowerCase()),
        );
    final polygons = <google_maps.Polygon>{};
    for (final territory in visibleTerritories) {
      final isSelected = territory.id == selected?.id;
      for (final entry in territory.polygonRings().asMap().entries) {
        final rings = entry.value;
        polygons.add(
          google_maps.Polygon(
            polygonId: google_maps.PolygonId('${territory.id}-${entry.key}'),
            points: rings.first.map(_googleLatLng).toList(growable: false),
            holes: rings
                .skip(1)
                .map((ring) => ring.map(_googleLatLng).toList(growable: false))
                .toList(growable: false),
            fillColor: _historicalBoundaryColor.withValues(
              alpha: isSelected ? 0.12 : 0.045,
            ),
            strokeColor: _historicalBoundaryColor,
            strokeWidth: isSelected ? 3 : 2,
            consumeTapEvents: true,
            onTap: () {
              final linkedStreetCard = state.streetCards
                  .where((card) => card.originTerritoryId == territory.id)
                  .firstOrNull;
              if (linkedStreetCard != null) {
                onSelectStreetCard(linkedStreetCard);
              } else {
                onSelectTerritory(territory);
              }
            },
          ),
        );
      }
    }
    final markers = <google_maps.Marker>{
      for (final point in visibleMapPoints)
        google_maps.Marker(
          markerId: google_maps.MarkerId('map-point-${point.id}'),
          position: _googleLatLng(point.position),
          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
            _markerHueFor(point.color),
          ),
          infoWindow: google_maps.InfoWindow(
            title: point.title.isNotEmpty ? point.title : point.type,
            snippet: [
              point.type,
              point.address,
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
          onTap: () => showMapPointDetailsSheet(context, point),
        ),
      if (state.currentPosition != null)
        google_maps.Marker(
          markerId: const google_maps.MarkerId('current-position'),
          position: _googleLatLng(state.currentPosition!),
          icon: google_maps.BitmapDescriptor.defaultMarkerWithHue(
            google_maps.BitmapDescriptor.hueAzure,
          ),
          infoWindow: const google_maps.InfoWindow(title: 'Sua localização'),
        ),
    };
    final polylines = <google_maps.Polyline>{};
    for (final card in visibleStreetCards) {
      for (final entry in card.streetLines.asMap().entries) {
        final coordinates = entry.value.coordinates;
        if (coordinates.length < 2) continue;
        polylines.add(
          google_maps.Polyline(
            polylineId: google_maps.PolylineId(
              'street-${card.id}-${entry.key}',
            ),
            points: coordinates.map(_googleLatLng).toList(growable: false),
            color: const Color(0xFF147D72),
            width: 5,
            consumeTapEvents: true,
            onTap: () => onSelectStreetCard(card),
          ),
        );
      }
    }

    return Column(
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _InlineMessage(message: state.errorMessage!),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            key: const ValueKey('territory-search'),
            onChanged: onSearchQueryChanged,
            decoration: InputDecoration(
              hintText: 'Buscar cartão, limite ou grupo',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () => onSearchQueryChanged(''),
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('map-layer-$layerFilter'),
                  initialValue: layerFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Camada do mapa',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'todos',
                      child: Text('Cartões e histórico'),
                    ),
                    DropdownMenuItem(
                      value: 'cartoes_rua',
                      child: Text('Cartões de rua'),
                    ),
                    DropdownMenuItem(
                      value: 'limites_historicos',
                      child: Text('Limites históricos'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onLayerFilterChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    'territory-group-${groupFilter ?? '__todos__'}',
                  ),
                  initialValue: groupFilter ?? '__todos__',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Grupo',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '__todos__',
                      child: Text('Todos'),
                    ),
                    ...groups.map(
                      (group) => DropdownMenuItem(
                        value: group,
                        child: Text(group, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => onGroupFilterChanged(
                    value == null || value == '__todos__' ? null : value,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile.adaptive(
              key: const ValueKey('map-points-visibility'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              secondary: Icon(
                Icons.place_outlined,
                color: showMapPoints
                    ? const Color(0xFFC0392B)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text('Pontos do mapa · ${state.mapPoints.length}'),
              subtitle: Text(
                state.mapPointsError ??
                    (state.canManageMapPoints
                        ? '$mapPointLongPressHint.'
                        : 'Inclui locais marcados como “Não bater”.'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              value: showMapPoints,
              onChanged: onShowMapPointsChanged,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 16, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${visibleStreetCards.length} cartão(ões) de rua · ${visibleTerritories.length} limite(s) histórico(s)'
                  '${showMapPoints ? ' · ${visibleMapPoints.length} ponto(s)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              TextButton.icon(
                onPressed: visibleTerritories.isEmpty
                    ? null
                    : () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (context) => _TerritoryListSheet(
                          territories: visibleTerritories,
                          totalTerritories: state.territories.length,
                          onSelect: (territory) {
                            Navigator.pop(context);
                            final linkedStreetCard = state.streetCards
                                .where(
                                  (card) =>
                                      card.originTerritoryId == territory.id,
                                )
                                .firstOrNull;
                            if (linkedStreetCard != null) {
                              onSelectStreetCard(linkedStreetCard);
                            } else {
                              onSelectTerritory(territory);
                            }
                          },
                        ),
                      ),
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('Limites'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: const [
              _StatusBadge(
                label: 'Cartão de rua · operacional',
                color: Color(0xFF147D72),
              ),
              _StatusBadge(
                label: 'Limite KML · histórico',
                color: _historicalBoundaryColor,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected == null
                      ? 'Toque em um cartão de rua ou limite histórico'
                      : 'Limite histórico · ${selected.code} · ${selected.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (state.isTracking)
                const _StatusBadge(
                  label: 'Registrando',
                  color: Color(0xFFC45F3D),
                )
              else if (state.isStartingRoute)
                const _StatusBadge(
                  label: 'Preparando',
                  color: Color(0xFF71836F),
                )
              else if (selected != null)
                const _StatusBadge(
                  label: 'Histórico',
                  color: _historicalBoundaryColor,
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: google_maps.GoogleMap(
                      initialCameraPosition: google_maps.CameraPosition(
                        target: _googleLatLng(initialCenter),
                        zoom: 14,
                      ),
                      minMaxZoomPreference:
                          const google_maps.MinMaxZoomPreference(4, 20),
                      mapToolbarEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      compassEnabled: true,
                      markers: markers,
                      polygons: polygons,
                      polylines: polylines,
                      onMapCreated: onMapCreated,
                      onLongPress: state.canManageMapPoints
                          ? (position) => showMapPointFormSheet(
                              context,
                              position: LatLng(
                                position.latitude,
                                position.longitude,
                              ),
                            )
                          : null,
                      onTap: (point) {
                        final selectedPoint = LatLng(
                          point.latitude,
                          point.longitude,
                        );
                        for (final territory in visibleTerritories.reversed) {
                          if (territory.contains(selectedPoint)) {
                            final linkedStreetCard = state.streetCards
                                .where(
                                  (card) =>
                                      card.originTerritoryId == territory.id,
                                )
                                .firstOrNull;
                            if (linkedStreetCard != null) {
                              onSelectStreetCard(linkedStreetCard);
                            } else {
                              onSelectTerritory(territory);
                            }
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'mapas-jw-current-location',
                    tooltip: 'Minha localização',
                    onPressed: isLocating ? null : onLocateCurrentPosition,
                    child: isLocating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
                if (state.currentAccuracy != null)
                  Positioned(
                    top: 62,
                    right: 12,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.93),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Text(
                            'Precisão ~${state.currentAccuracy!.round()} m',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (selected != null)
          _SelectedTerritoryCard(territory: selected, state: state)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Text(
              'Cartões de rua são a camada operacional. Limites KML e cobertura antiga permanecem identificados como histórico.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectedTerritoryCard extends StatelessWidget {
  const _SelectedTerritoryCard({required this.territory, required this.state});

  final Territory territory;
  final MobileAppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _historicalBoundaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.layers_outlined,
                  color: _historicalBoundaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${territory.code} · ${territory.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (territory.group != null)
                      Text(
                        territory.group!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const _StatusBadge(
                label: 'Histórico',
                color: _historicalBoundaryColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TerritorySituationSummary.fromTerritory(territory),
          Consumer(
            builder: (context, ref, _) => Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showTerritoryDetailsSheet(
                  context,
                  title: 'Cartão ${territory.code} · ${territory.name}',
                  loader: () => ref
                      .read(mobileAppControllerProvider.notifier)
                      .loadTerritoryDetails(territory.id),
                ),
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('Ver detalhes do cartão'),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (territory.totalPlaces > 0)
            Text(
              'Histórico do polígono: ${territory.workedPlaces} de ${territory.totalPlaces} locais registrados (${territory.coveragePercent}%). Esse dado não representa a situação atual do cartão de rua.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(height: 1.4),
            )
          else
            Text(
              'Este limite KML foi preservado para consulta. O trabalho atual é acompanhado pelo cartão de rua correspondente.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(height: 1.4),
            ),
          if (state.isStartingRoute || state.isTracking) ...[
            const SizedBox(height: 10),
            Text(
              state.isStartingRoute
                  ? 'Preparando o percurso do cartão de rua…'
                  : 'Há um percurso ativo. Acompanhe e encerre pelo cartão de rua correspondente.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (state.pendingRoutePoints > 0 && state.isTracking) ...[
            const SizedBox(height: 8),
            Text(
              '${state.pendingRoutePoints} ponto(s) do percurso aguardando envio',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _TerritoryListSheet extends StatelessWidget {
  const _TerritoryListSheet({
    required this.territories,
    required this.totalTerritories,
    required this.onSelect,
  });

  final List<Territory> territories;
  final int totalTerritories;
  final ValueChanged<Territory> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.78,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Limites históricos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${territories.length} de $totalTerritories referências KML nesta congregação',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: territories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final territory = territories[index];
                return Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onSelect(territory),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TerritoryShapeTile(territory: territory),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${territory.code} · ${territory.name}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const _StatusBadge(
                                          label: 'Histórico',
                                          color: _historicalBoundaryColor,
                                        ),
                                        if (territory.group?.isNotEmpty == true)
                                          Text(
                                            territory.group!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            [
                              territory.situationLabel,
                              if (territory.openedAt != null)
                                'aberto em ${formatDatePtBr(territory.openedAt)}',
                              if (territory.concludedAt != null)
                                'concluído em ${formatDatePtBr(territory.concludedAt)}'
                                    '${territory.concludedBy == null ? '' : ' por ${territory.concludedBy}'}',
                              if (territory.forcedCompletion)
                                'conclusão forçada'
                                    '${territory.completionNote == null ? '' : ' (${territory.completionNote})'}',
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: LinearProgressIndicator(
                                    value: territory.coveragePercent / 100,
                                    minHeight: 7,
                                    color: _historicalBoundaryColor,
                                    backgroundColor: _historicalBoundaryColor
                                        .withValues(alpha: 0.12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${territory.coveragePercent}%',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _historicalBoundaryColor,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            territory.totalPlaces == 0
                                ? 'Sem dados de cobertura legados'
                                : '${territory.workedPlaces} de ${territory.totalPlaces} locais no registro histórico',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _TerritoryShapeTile extends StatelessWidget {
  const _TerritoryShapeTile({required this.territory});

  final Territory territory;

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: _historicalBoundaryColor.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: _historicalBoundaryColor.withValues(alpha: .28),
      ),
    ),
    child: CustomPaint(painter: _TerritoryShapePainter(territory: territory)),
  );
}

class _TerritoryShapePainter extends CustomPainter {
  _TerritoryShapePainter({required this.territory})
    : polygons = territory.polygonRings();

  final Territory territory;
  final List<List<List<LatLng>>> polygons;

  @override
  void paint(Canvas canvas, Size size) {
    final outerRings = polygons
        .where((polygon) => polygon.isNotEmpty)
        .map((polygon) => polygon.first)
        .where((ring) => ring.length >= 3)
        .toList(growable: false);
    if (outerRings.isEmpty) return;

    final points = outerRings.expand((ring) => ring).toList(growable: false);

    final minLatitude = points.map((point) => point.latitude).reduce(math.min);
    final maxLatitude = points.map((point) => point.latitude).reduce(math.max);
    final minLongitude = points
        .map((point) => point.longitude)
        .reduce(math.min);
    final maxLongitude = points
        .map((point) => point.longitude)
        .reduce(math.max);
    final latitudeSpan = math.max(maxLatitude - minLatitude, 1e-9);
    final longitudeSpan = math.max(maxLongitude - minLongitude, 1e-9);
    const inset = 9.0;
    final scale = math.min(
      (size.width - inset * 2) / longitudeSpan,
      (size.height - inset * 2) / latitudeSpan,
    );
    final shapeWidth = longitudeSpan * scale;
    final shapeHeight = latitudeSpan * scale;
    final offsetX = (size.width - shapeWidth) / 2;
    final offsetY = (size.height - shapeHeight) / 2;
    final path = ui.Path()..fillType = ui.PathFillType.evenOdd;

    for (final polygon in polygons) {
      for (final ring in polygon) {
        if (ring.length < 3) continue;

        for (var index = 0; index < ring.length; index++) {
          final point = ring[index];
          final offset = Offset(
            offsetX + (point.longitude - minLongitude) * scale,
            offsetY + (maxLatitude - point.latitude) * scale,
          );
          if (index == 0) {
            path.moveTo(offset.dx, offset.dy);
          } else {
            path.lineTo(offset.dx, offset.dy);
          }
        }
        path.close();
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = _historicalBoundaryColor.withValues(alpha: .2)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _historicalBoundaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TerritoryShapePainter oldDelegate) =>
      oldDelegate.territory != territory;
}

class _AccountTab extends ConsumerWidget {
  const _AccountTab({required this.state, required this.onNavigate});

  final MobileAppState state;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Conta', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Acesse recursos nativos disponíveis para sua conta.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.primary,
                  child: Text(
                    state.userName.isEmpty
                        ? 'M'
                        : state.userName.substring(0, 1).toUpperCase(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.userName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        state.userEmail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Localização'),
                subtitle: const Text(
                  'Solicitada somente para registrar um trajeto, com indicação de atividade em segundo plano.',
                ),
                isThreeLine: true,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: const Text('Congregação ativa'),
                subtitle: Text(
                  _congregationLine(state.selectedCongregation) ??
                      'Nenhuma selecionada',
                ),
              ),
            ],
          ),
        ),
        if (Theme.of(context).platform == TargetPlatform.iOS) ...[
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.install_mobile_outlined),
              title: const Text('Mapas JW no SideStore'),
              subtitle: const Text(
                'Para quem usa SideStore, o app nativo e suas atualizações estão disponíveis na fonte Arthur’s Apps.',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _openSideStoreSource(context),
            ),
          ),
        ],
        if (_nativeShortcuts.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            'Mais recursos',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Estas áreas abrem dentro do aplicativo.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: _nativeShortcuts.indexed
                  .expand(
                    (entry) => [
                      if (entry.$1 > 0) const Divider(height: 1, indent: 58),
                      ListTile(
                        leading: Icon(entry.$2.icon),
                        title: Text(entry.$2.label),
                        subtitle: Text(entry.$2.description),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openNativeShortcut(context, entry.$2.id),
                      ),
                    ],
                  )
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(mobileAppControllerProvider.notifier).signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sair da conta'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ],
    );
  }

  Future<void> _openSideStoreSource(BuildContext context) async {
    const sourceUrl = 'https://app.moebiosenergy.com.br/sidestore/source.json';
    final sideStoreUrl = Uri.parse(
      'sidestore://source?url=${Uri.encodeComponent(sourceUrl)}',
    );

    try {
      final opened = await launchUrl(
        sideStoreUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Adicione esta fonte no SideStore: app.moebiosenergy.com.br/sidestore/source.json',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Adicione a fonte Arthur’s Apps em Sources no SideStore.',
            ),
          ),
        );
      }
    }
  }

  List<_NativeShortcut> get _nativeShortcuts => [
    if (state.isSuperAdmin)
      const _NativeShortcut(
        id: 'circuit-overview',
        label: 'Todos · Circuito RJ-14',
        description: 'Consultar limites e atividade agregada das congregações.',
        icon: Icons.public_outlined,
      ),
    if (state.canManageTerritoryDesignations)
      const _NativeShortcut(
        id: 'designations',
        label: 'Designações',
        description: 'Consultar a distribuição por território e pessoa.',
        icon: Icons.assignment_ind_outlined,
      ),
    if (state.canViewPeople)
      const _NativeShortcut(
        id: 'people',
        label: 'Pessoas',
        description: 'Consultar pessoas, perfis e situação de acesso.',
        icon: Icons.groups_outlined,
      ),
    if (state.canViewLetters ||
        state.canViewTerritories ||
        state.canViewStreetCards)
      const _NativeShortcut(
        id: 'statistics',
        label: 'Estatísticas',
        description: 'Ver o andamento da congregação.',
        icon: Icons.query_stats_outlined,
      ),
    if (state.canViewTerritories || state.canViewStreetCards)
      const _NativeShortcut(
        id: 'coverage',
        label: 'Cobertura',
        description: 'Abrir o mapa de territórios e cartões de rua.',
        icon: Icons.donut_large_outlined,
      ),
  ];

  void _openNativeShortcut(BuildContext context, String id) {
    switch (id) {
      case 'circuit-overview':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const CircuitOverviewScreen(),
          ),
        );
        break;
      case 'designations':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DesignationsScreen()),
        );
        break;
      case 'people':
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const PeopleScreen()));
        break;
      case 'statistics':
        onNavigate('Início');
        break;
      case 'coverage':
        onNavigate('Mapa');
        break;
    }
  }
}

class _NativeShortcut {
  const _NativeShortcut({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

google_maps.LatLng _googleLatLng(LatLng point) =>
    google_maps.LatLng(point.latitude, point.longitude);

double _markerHueFor(Color color) {
  final red = color.r;
  final green = color.g;
  final blue = color.b;
  final maximum = math.max(red, math.max(green, blue));
  final minimum = math.min(red, math.min(green, blue));
  final delta = maximum - minimum;
  if (delta == 0) return 0;

  final hue = maximum == red
      ? 60 * (((green - blue) / delta) % 6)
      : maximum == green
      ? 60 * ((blue - red) / delta + 2)
      : 60 * ((red - green) / delta + 4);
  return (hue < 0 ? hue + 360 : hue).toDouble();
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(message, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Nome da congregação e, quando o servidor informa, circuito e cidade.
String? _congregationLine(Congregation? congregation) {
  if (congregation == null) return null;
  final subtitle = congregation.subtitle;
  return subtitle.isEmpty
      ? congregation.name
      : '${congregation.name} · $subtitle';
}
