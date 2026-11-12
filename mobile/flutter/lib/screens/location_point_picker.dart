import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart';

import 'maps_config_gate.dart';

/// Tela para marcar o ponto de um local de saída tocando no mapa.
/// Retorna o ponto escolhido (ou null se a pessoa voltar sem confirmar).
/// O servidor troca o link do Maps pelo novo ponto, mantendo os dois alinhados.
Future<LatLng?> pickLocationPoint(
  BuildContext context, {
  LatLng? initial,
  LatLng fallbackCenter = const LatLng(-22.45, -43.1),
}) => Navigator.of(context).push<LatLng>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => LocationPointPicker(
      initial: initial,
      center: initial ?? fallbackCenter,
      zoom: initial == null ? 13 : 17,
    ),
  ),
);

class LocationPointPicker extends StatefulWidget {
  const LocationPointPicker({
    required this.center,
    required this.zoom,
    this.initial,
    super.key,
  });

  final LatLng? initial;
  final LatLng center;
  final double zoom;

  @override
  State<LocationPointPicker> createState() => _LocationPointPickerState();
}

class _LocationPointPickerState extends State<LocationPointPicker> {
  LatLng? _point;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    return Scaffold(
      appBar: AppBar(title: const Text('Marcar o ponto no mapa')),
      body: MapsConfigGate(
        builder: (_) => Stack(
          children: [
            google_maps.GoogleMap(
              initialCameraPosition: google_maps.CameraPosition(
                target: google_maps.LatLng(
                  widget.center.latitude,
                  widget.center.longitude,
                ),
                zoom: widget.zoom,
              ),
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: {
                if (point != null)
                  google_maps.Marker(
                    markerId: const google_maps.MarkerId('picked'),
                    position: google_maps.LatLng(
                      point.latitude,
                      point.longitude,
                    ),
                  ),
              },
              onTap: (position) => setState(
                () => _point = LatLng(position.latitude, position.longitude),
              ),
            ),
            const Positioned(
              left: 16,
              right: 16,
              top: 12,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('Toque no mapa onde fica o ponto de encontro.'),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: point == null ? null : () => Navigator.pop(context, point),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Usar este ponto'),
        ),
      ),
    );
  }
}
