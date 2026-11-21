import 'mobile_models.dart';

/// Resposta de `GET /mobile/field-locations` (inclui os desativados).
class FieldLocationsPage {
  const FieldLocationsPage({this.locations = const [], this.canManage = false});

  factory FieldLocationsPage.fromJson(Map<String, dynamic> json) {
    final permissions = json['permissions'];
    return FieldLocationsPage(
      locations: (json['locations'] as List? ?? const [])
          .whereType<Map>()
          .where((item) => item['id'] is num)
          .map((item) => FieldLocation.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      canManage: permissions is Map && permissions['can_manage'] == true,
    );
  }

  final List<FieldLocation> locations;
  final bool canManage;
}
