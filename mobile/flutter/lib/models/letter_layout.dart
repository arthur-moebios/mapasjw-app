import 'package:flutter/material.dart';

import 'mobile_models.dart';

/// Um andar do bloco: rótulo curto à esquerda e os apartamentos dele.
class LetterFloorRow {
  const LetterFloorRow({
    required this.label,
    required this.floorNumber,
    required this.apartments,
  });

  final String label;
  final int floorNumber;
  final List<ApartmentLetter> apartments;
}

/// Bloco do condomínio (ou grupo de unidades avulsas / sem bloco).
class LetterBlockGroup {
  const LetterBlockGroup({
    required this.key,
    required this.title,
    required this.isBlock,
    required this.floors,
  });

  /// Chave estável (sobrevive ao recarregar) para guardar o estado de recolhido.
  final String key;
  final String title;

  /// Falso para avulsas e unidades sem bloco: uma linha só, sem rótulo de andar.
  final bool isBlock;
  final List<LetterFloorRow> floors;

  int get apartmentCount =>
      floors.fold(0, (total, floor) => total + floor.apartments.length);

  int get floorCount => floors.length;

  /// "12 aptos · 4 andares" (avulsas: só a contagem de unidades).
  String get summary {
    final aptos = apartmentCount == 1 ? '1 apto' : '$apartmentCount aptos';
    if (!isBlock) {
      return apartmentCount == 1 ? '1 unidade' : '$apartmentCount unidades';
    }
    final andares = floorCount == 1 ? '1 andar' : '$floorCount andares';
    return '$aptos · $andares';
  }

  /// Contagem por status, na ordem dos status da campanha; os que não estão
  /// na lista vêm depois, na ordem em que aparecem.
  List<LetterStatusCount> statusCounts(List<LetterStatusOption> statuses) {
    final counts = <String, int>{};
    final labels = <String, String>{};
    final colors = <String, Color>{};
    for (final floor in floors) {
      for (final apartment in floor.apartments) {
        counts[apartment.status] = (counts[apartment.status] ?? 0) + 1;
        labels[apartment.status] = apartment.statusLabel;
        colors[apartment.status] = apartment.statusColor;
      }
    }
    final ordered = [
      ...statuses.map((status) => status.slug).where(counts.containsKey),
      ...counts.keys.where((slug) => !statuses.any((s) => s.slug == slug)),
    ];
    return [
      for (final slug in ordered)
        LetterStatusCount(
          slug: slug,
          label: labels[slug] ?? slug,
          color: colors[slug] ?? Colors.grey,
          count: counts[slug]!,
        ),
    ];
  }
}

class LetterStatusCount {
  const LetterStatusCount({
    required this.slug,
    required this.label,
    required this.color,
    required this.count,
  });

  final String slug;
  final String label;
  final Color color;
  final int count;
}

abstract final class LetterLayout {
  /// Rótulo do andar: nome do pavimento, "Térreo" (0) ou "5º".
  static String floorLabel(ApartmentLetter apartment) {
    if (apartment.floorName.isNotEmpty) return apartment.floorName;
    if (apartment.floorNumber == 0) return 'Térreo';
    if (apartment.floorNumber > 0) return '${apartment.floorNumber}º';
    return '';
  }

  static String blockTitle(ApartmentLetter apartment) =>
      apartment.blockName.isNotEmpty
      ? apartment.blockName
      : 'Bloco ${apartment.blockNumber}';

  static bool _inBlock(ApartmentLetter apartment) =>
      !apartment.isAvulso &&
      (apartment.blockName.isNotEmpty || apartment.blockNumber > 0);

  /// Blocos por número (andares do mais alto ao térreo, como na web) e, depois,
  /// os grupos de avulsas / sem bloco, titulados pelo `locationLabel`.
  static List<LetterBlockGroup> group(List<ApartmentLetter> apartments) {
    final blocks = <String, List<ApartmentLetter>>{};
    final blockOrder = <String, int>{};
    final others = <String, List<ApartmentLetter>>{};
    for (final apartment in apartments) {
      if (_inBlock(apartment)) {
        final key = 'bloco:${apartment.blockNumber}:${apartment.blockName}';
        blocks.putIfAbsent(key, () => []).add(apartment);
        blockOrder[key] = apartment.blockNumber;
      } else {
        final title = apartment.locationLabel.isEmpty
            ? 'Endereços'
            : apartment.locationLabel;
        others.putIfAbsent('outros:$title', () => []).add(apartment);
      }
    }

    final blockKeys = blocks.keys.toList()
      ..sort((a, b) => blockOrder[a]!.compareTo(blockOrder[b]!));

    return [
      for (final key in blockKeys)
        LetterBlockGroup(
          key: key,
          title: blockTitle(blocks[key]!.first),
          isBlock: true,
          floors: _floors(blocks[key]!),
        ),
      for (final entry in others.entries)
        LetterBlockGroup(
          key: entry.key,
          title: entry.key.substring('outros:'.length),
          isBlock: false,
          floors: [
            LetterFloorRow(label: '', floorNumber: 0, apartments: entry.value),
          ],
        ),
    ];
  }

  static List<LetterFloorRow> _floors(List<ApartmentLetter> apartments) {
    final byFloor = <String, List<ApartmentLetter>>{};
    for (final apartment in apartments) {
      byFloor
          .putIfAbsent(
            '${apartment.floorNumber}:${apartment.floorName}',
            () => [],
          )
          .add(apartment);
    }
    final rows = [
      for (final items in byFloor.values)
        LetterFloorRow(
          label: floorLabel(items.first),
          floorNumber: items.first.floorNumber,
          apartments: items,
        ),
    ]..sort((a, b) => b.floorNumber.compareTo(a.floorNumber));
    return rows;
  }
}
