import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import 'package:latlong2/latlong.dart';

import '../data/mobile_api.dart';
import '../models/outing_work.dart';
import '../state/mobile_app_controller.dart';

/// Cores por cartão no mapa e na lista.
const outingWorkPalette = <Color>[
  Color(0xFF147D72),
  Color(0xFFC2410C),
  Color(0xFF6D28D9),
  Color(0xFF1D4ED8),
  Color(0xFFBE185D),
  Color(0xFF4D7C0F),
  Color(0xFF0E7490),
  Color(0xFFB45309),
];

Color outingWorkColor(int index) =>
    outingWorkPalette[index % outingWorkPalette.length];

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// "Onde foi trabalhado?" depois da saída: mapa com as ruas coloridas por
/// cartão e seleção POR RUA. Todas as ruas de um cartão concluem o cartão;
/// marcar só algumas registra o dia e deixa o cartão em andamento.
/// Retorna true quando algo foi salvo.
Future<bool?> showOutingWorkScreen(
  BuildContext context, {
  required int outingId,
  required String month,
  required bool canSave,
}) => Navigator.of(context).push<bool>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) =>
        OutingWorkScreen(outingId: outingId, month: month, canSave: canSave),
  ),
);

class OutingWorkScreen extends ConsumerStatefulWidget {
  const OutingWorkScreen({
    required this.outingId,
    required this.month,
    required this.canSave,
    super.key,
  });

  final int outingId;
  final String month;
  final bool canSave;

  @override
  ConsumerState<OutingWorkScreen> createState() => _OutingWorkScreenState();
}

class _OutingWorkScreenState extends ConsumerState<OutingWorkScreen> {
  OutingWorkData? _data;
  OutingWorkSelection? _selection;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  String _date = _dateKey(DateTime.now());
  int? _focusedCardId;
  google_maps.GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_load);
  }

  @override
  void dispose() {
    _mapController = null;
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(mobileAppControllerProvider.notifier)
          .loadOutingWorkCandidates(widget.outingId);
      if (!mounted) return;
      final today = _dateKey(DateTime.now());
      setState(() {
        _data = data;
        _selection = OutingWorkSelection(data.candidates);
        // O servidor recusa data futura: usa a da saída só se já passou.
        _date = data.date.isNotEmpty && data.date.compareTo(today) <= 0
            ? data.date
            : today;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = MobileApi.messageForError(error);
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_date) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? now : current,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = _dateKey(picked));
  }

  Future<void> _save() async {
    final data = _data;
    final selection = _selection;
    if (data == null || selection == null || _saving) return;
    final payload = selection.payload(defaultDate: _date);
    if (payload.isEmpty) return;
    final completing = data.candidates
        .where(selection.willComplete)
        .toList(growable: false);
    final reopening = data.candidates
        .where(selection.willReopen)
        .toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Salvar onde foi trabalhado?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (completing.isNotEmpty) ...[
              const Text(
                'Estes cartões serão CONCLUÍDOS (todas as ruas marcadas):',
              ),
              const SizedBox(height: 6),
              for (final card in completing) Text('• ${card.title}'),
              const SizedBox(height: 10),
            ],
            if (reopening.isNotEmpty) ...[
              const Text('Estes cartões serão reabertos:'),
              const SizedBox(height: 6),
              for (final card in reopening) Text('• ${card.title}'),
              const SizedBox(height: 10),
            ],
            if (completing.isEmpty && reopening.isEmpty)
              const Text(
                'Será registrado só o dia. Nenhum cartão será concluído.',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(mobileAppControllerProvider.notifier)
          .saveOutingWork(widget.outingId, payload, month: widget.month);
      if (!mounted) return;
      final parts = <String>[
        if (result.completedCardIds.isNotEmpty)
          '${result.completedCardIds.length} cartão(ões) concluído(s)',
        if (result.reopenedCardIds.isNotEmpty)
          '${result.reopenedCardIds.length} reaberto(s)',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parts.isEmpty
                ? 'Registro salvo.'
                : 'Registro salvo: ${parts.join(', ')}.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MobileApi.messageForError(error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final selection = _selection;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onde foi trabalhado?'),
        actions: [
          if (data != null && !data.noRecordNeeded && widget.canSave)
            TextButton.icon(
              onPressed: _saving ? null : _pickDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_date),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _Message(
              icon: Icons.error_outline_rounded,
              text: _error!,
              actionLabel: 'Tentar de novo',
              onAction: _load,
            )
          : data == null || selection == null
          ? const SizedBox.shrink()
          : data.noRecordNeeded
          ? const _Message(
              icon: Icons.videocam_outlined,
              text:
                  'Esta saída é informativa ou online: não há trabalho de rua '
                  'a registrar. Basta marcar a situação da saída '
                  '(Pendente, Concluída ou Não houve).',
            )
          : _body(context, data, selection),
      bottomNavigationBar:
          data == null ||
              selection == null ||
              data.noRecordNeeded ||
              !widget.canSave
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: _saving || !selection.hasChanges ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  selection.selectedStreetCount == 0
                      ? 'Salvar'
                      : 'Salvar (${selection.selectedStreetCount} rua(s))',
                ),
              ),
            ),
    );
  }

  Widget _body(
    BuildContext context,
    OutingWorkData data,
    OutingWorkSelection selection,
  ) {
    final height = MediaQuery.sizeOf(context).height;
    return Column(
      children: [
        SizedBox(
          height: (height * .38).clamp(220, 420).toDouble(),
          child: _buildMap(data, selection),
        ),
        if (data.notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              data.notice!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: data.candidates.isEmpty
              ? const _Message(
                  icon: Icons.map_outlined,
                  text: 'Nenhum cartão de rua perto do local desta saída.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: data.candidates.length,
                  itemBuilder: (context, index) => _cardTile(
                    context,
                    data.candidates[index],
                    index,
                    selection,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMap(OutingWorkData data, OutingWorkSelection selection) {
    final polylines = <google_maps.Polyline>{};
    final allPoints = <LatLng>[];
    for (var cardIndex = 0; cardIndex < data.candidates.length; cardIndex++) {
      final card = data.candidates[cardIndex];
      final color = outingWorkColor(cardIndex);
      final focused = _focusedCardId == card.cardId;
      for (
        var streetIndex = 0;
        streetIndex < card.streets.length;
        streetIndex++
      ) {
        final street = card.streets[streetIndex];
        final selected = selection.isSelected(card, street);
        for (var lineIndex = 0; lineIndex < street.lines.length; lineIndex++) {
          final line = street.lines[lineIndex];
          allPoints.addAll(line);
          if (line.length < 2) continue;
          polylines.add(
            google_maps.Polyline(
              polylineId: google_maps.PolylineId(
                'w-${card.cardId}-$streetIndex-$lineIndex',
              ),
              points: line
                  .map((p) => google_maps.LatLng(p.latitude, p.longitude))
                  .toList(growable: false),
              color: selected || focused ? color : color.withValues(alpha: .45),
              width: selected ? 8 : (focused ? 6 : 4),
              consumeTapEvents: widget.canSave,
              onTap: widget.canSave
                  ? () => setState(() => selection.toggleStreet(card, street))
                  : null,
            ),
          );
        }
      }
    }
    final point = data.locationPoint;
    if (point != null) allPoints.add(point);
    final center = allPoints.isEmpty
        ? const LatLng(-22.45, -43.1)
        : allPoints[allPoints.length ~/ 2];
    return google_maps.GoogleMap(
      initialCameraPosition: google_maps.CameraPosition(
        target: google_maps.LatLng(center.latitude, center.longitude),
        zoom: 15,
      ),
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      polylines: polylines,
      markers: {
        if (point != null)
          google_maps.Marker(
            markerId: const google_maps.MarkerId('outing-location'),
            position: google_maps.LatLng(point.latitude, point.longitude),
            infoWindow: google_maps.InfoWindow(
              title: data.locationName ?? 'Local da saída',
            ),
          ),
      },
      onMapCreated: (controller) {
        _mapController = controller;
        _fitCamera(allPoints);
      },
    );
  }

  void _fitCamera(List<LatLng> points) {
    if (points.length < 2) return;
    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    if (minLat == maxLat && minLng == maxLng) return;
    final bounds = google_maps.LatLngBounds(
      southwest: google_maps.LatLng(minLat, minLng),
      northeast: google_maps.LatLng(maxLat, maxLng),
    );
    Future<void>.delayed(const Duration(milliseconds: 350), () async {
      try {
        await _mapController?.animateCamera(
          google_maps.CameraUpdate.newLatLngBounds(bounds, 48),
        );
      } on Object {
        // O mapa pode ter sido fechado ou ainda não ter tamanho: mantém a câmera.
      }
    });
  }

  Widget _cardTile(
    BuildContext context,
    OutingWorkCandidate card,
    int index,
    OutingWorkSelection selection,
  ) {
    final color = outingWorkColor(index);
    final coverage = selection.coverage(card);
    final willComplete = selection.willComplete(card);
    final willReopen = selection.willReopen(card);
    final theme = Theme.of(context);
    final details = <String>[
      if (card.distanceKm != null)
        card.atCard ? 'no cartão' : '${card.distanceKm!.toStringAsFixed(1)} km',
      if (card.neighborhood != null && card.neighborhood!.isNotEmpty)
        card.neighborhood!,
      if (card.group != null && card.group!.isNotEmpty) card.group!,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        key: PageStorageKey<int>(card.cardId),
        initiallyExpanded: card.likely || card.record != null,
        onExpansionChanged: (open) =>
            setState(() => _focusedCardId = open ? card.cardId : null),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 12,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        title: Text(
          card.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (details.isNotEmpty)
              Text(details.join(' · '), style: theme.textTheme.bodySmall),
            if (card.isCompleted) const _Badge('concluído', Color(0xFF196B24)),
            if (willComplete) _Badge('concluirá', color),
            if (willReopen) const _Badge('reabrirá', Color(0xFFB45309)),
            if (coverage == OutingWorkCoverage.partial && !willReopen)
              const _Badge('em andamento', Color(0xFF65736B)),
          ],
        ),
        children: [
          if (widget.canSave && card.streets.isNotEmpty)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              tristate: true,
              value: switch (coverage) {
                OutingWorkCoverage.all => true,
                OutingWorkCoverage.none => false,
                OutingWorkCoverage.partial => null,
              },
              title: const Text('Todas as ruas (conclui o cartão)'),
              onChanged: (_) => setState(
                () =>
                    selection.setAll(card, coverage != OutingWorkCoverage.all),
              ),
            ),
          if (card.streets.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Este cartão não tem ruas cadastradas; não é possível '
                'registrar nem concluir por aqui.',
              ),
            ),
          for (final street in card.streets)
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: selection.isSelected(card, street),
              title: Text(street.name),
              subtitle: street.meters > 0 ? Text('${street.meters} m') : null,
              onChanged: widget.canSave
                  ? (_) => setState(() => selection.toggleStreet(card, street))
                  : null,
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
