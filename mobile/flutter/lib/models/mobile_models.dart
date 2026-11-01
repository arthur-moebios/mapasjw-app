import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'apartment_status_wizard.dart';

class MobileDashboardSummary {
  const MobileDashboardSummary({
    this.campaignName,
    this.campaignIsOpen,
    this.condominiumsCount,
    this.apartmentsCount,
    this.deliveredCount,
    this.workedCount,
    this.progressPercent,
    this.letterStatuses = const [],
    this.territoriesCount,
    this.availableTerritoriesCount,
    this.inProgressTerritoriesCount,
    this.completedTerritoriesCount,
    this.streetCardsCount,
    this.streetSegmentsCount,
    this.streetEntrancesCount,
    this.generatedAt,
  });

  final String? campaignName;
  final bool? campaignIsOpen;
  final int? condominiumsCount;
  final int? apartmentsCount;
  final int? deliveredCount;
  final int? workedCount;
  final int? progressPercent;
  final List<DashboardLetterStatus> letterStatuses;
  final int? territoriesCount;
  final int? availableTerritoriesCount;
  final int? inProgressTerritoriesCount;
  final int? completedTerritoriesCount;
  final int? streetCardsCount;
  final int? streetSegmentsCount;
  final int? streetEntrancesCount;
  final DateTime? generatedAt;

  factory MobileDashboardSummary.fromJson(Map<String, dynamic> json) {
    final statistics = Map<String, dynamic>.from(
      json['statistics'] as Map? ?? const {},
    );
    final letters = statistics['letters'] is Map
        ? Map<String, dynamic>.from(statistics['letters'] as Map)
        : const <String, dynamic>{};
    final campaign = letters['campaign'] is Map
        ? Map<String, dynamic>.from(letters['campaign'] as Map)
        : const <String, dynamic>{};
    final territories = statistics['territories'] is Map
        ? Map<String, dynamic>.from(statistics['territories'] as Map)
        : const <String, dynamic>{};
    final streetCards = statistics['street_cards'] is Map
        ? Map<String, dynamic>.from(statistics['street_cards'] as Map)
        : const <String, dynamic>{};

    return MobileDashboardSummary(
      campaignName: campaign['name'] as String?,
      campaignIsOpen: campaign['is_open'] as bool?,
      condominiumsCount: (letters['condominiums_count'] as num?)?.toInt(),
      apartmentsCount: (letters['apartments_count'] as num?)?.toInt(),
      deliveredCount: (letters['delivered_count'] as num?)?.toInt(),
      workedCount: (letters['worked_count'] as num?)?.toInt(),
      progressPercent: (letters['progress_percent'] as num?)?.toInt(),
      letterStatuses: (letters['statuses'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                DashboardLetterStatus.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      territoriesCount: (territories['total'] as num?)?.toInt(),
      availableTerritoriesCount: (territories['available'] as num?)?.toInt(),
      inProgressTerritoriesCount: (territories['in_progress'] as num?)?.toInt(),
      completedTerritoriesCount: (territories['completed'] as num?)?.toInt(),
      streetCardsCount: (streetCards['cards'] as num?)?.toInt(),
      streetSegmentsCount: (streetCards['streets'] as num?)?.toInt(),
      streetEntrancesCount: (streetCards['entrances'] as num?)?.toInt(),
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
    );
  }
}

class DashboardLetterStatus {
  const DashboardLetterStatus({
    required this.slug,
    required this.label,
    required this.color,
    required this.count,
    required this.countsAsDelivered,
  });

  final String slug;
  final String label;
  final Color color;
  final int count;
  final bool countsAsDelivered;

  factory DashboardLetterStatus.fromJson(Map<String, dynamic> json) =>
      DashboardLetterStatus(
        slug: json['slug'] as String? ?? '',
        label: json['label'] as String? ?? '',
        color: _colorFromHex(json['color'] as String?),
        count: (json['count'] as num?)?.toInt() ?? 0,
        countsAsDelivered: json['counts_as_delivered'] == true,
      );
}

class Congregation {
  const Congregation({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;
  final String slug;

  factory Congregation.fromJson(Map<String, dynamic> json) => Congregation(
    id: json['id'] as int,
    name: json['name'] as String? ?? 'Congregação',
    slug: json['slug'] as String? ?? '',
  );
}

class CircuitOverviewData {
  const CircuitOverviewData({
    required this.circuit,
    required this.totals,
    required this.congregations,
    required this.boundaries,
  });

  final String circuit;
  final CircuitOverviewTotals totals;
  final List<CircuitCongregationSummary> congregations;
  final List<CircuitBoundary> boundaries;

  factory CircuitOverviewData.fromJson(Map<String, dynamic> json) {
    final geojson = Map<String, dynamic>.from(
      json['geojson'] as Map? ?? const {},
    );
    return CircuitOverviewData(
      circuit: json['circuit'] as String? ?? '',
      totals: CircuitOverviewTotals.fromJson(
        Map<String, dynamic>.from(json['totals'] as Map? ?? const {}),
      ),
      congregations: (json['summary'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => CircuitCongregationSummary.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      boundaries: (geojson['features'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (feature) =>
                CircuitBoundary.fromFeature(Map<String, dynamic>.from(feature)),
          )
          .toList(growable: false),
    );
  }
}

class CircuitOverviewTotals {
  const CircuitOverviewTotals({
    required this.congregations,
    required this.boundaries,
    required this.streetCards,
    required this.streetSegments,
    required this.legacyCards,
    required this.legacyCardsWorked,
    required this.workEntries,
    required this.routeDays,
    required this.routePoints,
  });

  final int congregations;
  final int boundaries;
  final int streetCards;
  final int streetSegments;
  final int legacyCards;
  final int legacyCardsWorked;
  final int workEntries;
  final int routeDays;
  final int routePoints;

  factory CircuitOverviewTotals.fromJson(Map<String, dynamic> json) =>
      CircuitOverviewTotals(
        congregations: _intValue(json['congregacoes']),
        boundaries: _intValue(json['limites']),
        streetCards: _intValue(json['cartoes_rua']),
        streetSegments: _intValue(json['trechos']),
        legacyCards: _intValue(json['cartoes_legados']),
        legacyCardsWorked: _intValue(json['cartoes_com_trabalho']),
        workEntries: _intValue(json['passagens']),
        routeDays: _intValue(json['dias_percurso']),
        routePoints: _intValue(json['pontos_percurso']),
      );
}

class CircuitCongregationSummary {
  const CircuitCongregationSummary({
    required this.id,
    required this.name,
    required this.color,
    required this.boundaries,
    required this.streetCards,
    required this.streetSegments,
    required this.legacyCards,
    required this.legacyCardsWorked,
    required this.workEntries,
    required this.routeDays,
    required this.routePoints,
    this.legacyUsagePercent,
  });

  final int id;
  final String name;
  final Color color;
  final int boundaries;
  final int streetCards;
  final int streetSegments;
  final int legacyCards;
  final int legacyCardsWorked;
  final int workEntries;
  final int routeDays;
  final int routePoints;
  final int? legacyUsagePercent;

  factory CircuitCongregationSummary.fromJson(Map<String, dynamic> json) =>
      CircuitCongregationSummary(
        id: _intValue(json['id']),
        name: json['congregacao'] as String? ?? 'Congregação',
        color: _colorFromHex(json['cor'] as String?),
        boundaries: _intValue(json['limites']),
        streetCards: _intValue(json['cartoes_rua']),
        streetSegments: _intValue(json['trechos']),
        legacyCards: _intValue(json['cartoes_legados']),
        legacyCardsWorked: _intValue(json['cartoes_com_trabalho']),
        workEntries: _intValue(json['passagens']),
        routeDays: _intValue(json['dias_percurso']),
        routePoints: _intValue(json['pontos_percurso']),
        legacyUsagePercent: (json['uso_legado_percentual'] as num?)?.toInt(),
      );
}

class CircuitBoundary {
  const CircuitBoundary({
    required this.congregationId,
    required this.congregationName,
    required this.label,
    required this.color,
    required this.geometry,
  });

  final int congregationId;
  final String congregationName;
  final String label;
  final Color color;
  final Map<String, dynamic> geometry;

  factory CircuitBoundary.fromFeature(Map<String, dynamic> feature) {
    final properties = Map<String, dynamic>.from(
      feature['properties'] as Map? ?? const {},
    );
    return CircuitBoundary(
      congregationId: _intValue(properties['congregacao_id']),
      congregationName: properties['congregacao'] as String? ?? 'Congregação',
      label: properties['limite'] as String? ?? 'Limite histórico',
      color: _colorFromHex(properties['cor'] as String?),
      geometry: Map<String, dynamic>.from(
        feature['geometry'] as Map? ?? const {},
      ),
    );
  }
}

int _intValue(Object? value) => (value as num?)?.toInt() ?? 0;

class MobileDesignation {
  const MobileDesignation({
    required this.id,
    required this.personId,
    required this.person,
    required this.condominiumId,
    required this.condominium,
    required this.place,
    required this.level,
    this.since,
    this.observation,
  });

  final int id;
  final int personId;
  final String person;
  final int condominiumId;
  final String condominium;
  final String place;
  final String level;
  final String? since;
  final String? observation;

  factory MobileDesignation.fromJson(Map<String, dynamic> json) =>
      MobileDesignation(
        id: (json['id'] as num?)?.toInt() ?? 0,
        personId: (json['person_id'] as num?)?.toInt() ?? 0,
        person: json['person'] as String? ?? 'Usuário removido',
        condominiumId: (json['condominium_id'] as num?)?.toInt() ?? 0,
        condominium: json['condominium'] as String? ?? 'Condomínio',
        place: json['place'] as String? ?? 'Local não informado',
        level: json['level'] as String? ?? 'Local',
        since: json['since'] as String?,
        observation: json['observation'] as String?,
      );
}

class MobileDesignationsData {
  const MobileDesignationsData({
    required this.assignments,
    required this.peopleCount,
    required this.condominiumsCount,
  });

  final List<MobileDesignation> assignments;
  final int peopleCount;
  final int condominiumsCount;

  factory MobileDesignationsData.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(
      json['summary'] as Map? ?? const {},
    );
    return MobileDesignationsData(
      assignments: (json['assignments'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                MobileDesignation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      peopleCount: (summary['people'] as num?)?.toInt() ?? 0,
      condominiumsCount: (summary['condominiums'] as num?)?.toInt() ?? 0,
    );
  }
}

class MobilePerson {
  const MobilePerson({
    required this.id,
    required this.name,
    required this.email,
    required this.profile,
    required this.isActive,
    required this.isSelf,
  });

  final int id;
  final String name;
  final String email;
  final String profile;
  final bool isActive;
  final bool isSelf;

  factory MobilePerson.fromJson(Map<String, dynamic> json) => MobilePerson(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    profile: json['profile'] as String? ?? 'Sem perfil',
    isActive: json['is_active'] == true,
    isSelf: json['is_self'] == true,
  );
}

class CampaignOption {
  const CampaignOption({
    required this.id,
    required this.name,
    required this.isOpen,
  });

  final int id;
  final String name;
  final bool isOpen;

  factory CampaignOption.fromJson(Map<String, dynamic> json) => CampaignOption(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? 'Campanha',
    isOpen: json['is_open'] == true,
  );
}

class CondominiumSummary {
  const CondominiumSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.apartmentsCount,
    this.latitude,
    this.longitude,
    this.isBlocked = false,
    this.visibleApartmentsCount,
    this.workedCount = 0,
    this.deliveredCount = 0,
    this.progressPercent,
    this.campaignName,
    this.assignmentLimited = false,
    this.blocksCount = 0,
    this.floorsCount = 0,
  });

  final int id;
  final String code;
  final String name;
  final String address;
  final int? apartmentsCount;
  final double? latitude;
  final double? longitude;
  final bool isBlocked;
  final int? visibleApartmentsCount;
  final int workedCount;
  final int deliveredCount;
  final int? progressPercent;
  final String? campaignName;
  final bool assignmentLimited;
  final int blocksCount;
  final int floorsCount;

  int get displayedApartmentsCount =>
      visibleApartmentsCount ?? apartmentsCount ?? 0;

  factory CondominiumSummary.fromJson(Map<String, dynamic> json) =>
      CondominiumSummary(
        id: (json['id'] as num).toInt(),
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? 'Condomínio',
        address: json['address'] as String? ?? '',
        apartmentsCount: (json['apartments_count'] as num?)?.toInt(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        isBlocked: json['blocked'] == true,
        visibleApartmentsCount: (json['visible_apartments_count'] as num?)
            ?.toInt(),
        workedCount: (json['worked_count'] as num?)?.toInt() ?? 0,
        deliveredCount: (json['delivered_count'] as num?)?.toInt() ?? 0,
        progressPercent: (json['progress_percent'] as num?)?.toInt(),
        campaignName: json['campaign_name'] as String?,
        assignmentLimited: json['assignment_limited'] == true,
        blocksCount: (json['blocks_count'] as num?)?.toInt() ?? 0,
        floorsCount: (json['floors_count'] as num?)?.toInt() ?? 0,
      );
}

class LetterStatusOption {
  const LetterStatusOption({
    required this.slug,
    required this.label,
    required this.color,
    required this.countsAsDelivered,
  });

  final String slug;
  final String label;
  final Color color;
  final bool countsAsDelivered;

  factory LetterStatusOption.fromJson(Map<String, dynamic> json) =>
      LetterStatusOption(
        slug: json['slug'] as String? ?? 'no',
        label: json['label'] as String? ?? 'Não registrada',
        color: _colorFromHex(json['color'] as String?),
        countsAsDelivered: json['counts_as_delivered'] == true,
      );
}

class ApartmentLetter {
  const ApartmentLetter({
    required this.id,
    required this.blockName,
    required this.blockNumber,
    required this.floorName,
    required this.floorNumber,
    required this.apartmentNumber,
    required this.apartmentNumberValue,
    this.isAvulso = false,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.canUpdate,
    required this.isBlocked,
    this.writtenBy,
    this.envelopedBy,
    this.deliveredBy,
    this.lastSentAt,
    this.letterWrittenAt,
    this.publication,
    this.subject,
    this.observation,
    this.deliveredBoxGuard = false,
    this.deliveredDoormanMail = false,
  });

  final int id;
  final String blockName;
  final int blockNumber;
  final String floorName;
  final int floorNumber;
  final String apartmentNumber;
  final String apartmentNumberValue;
  final bool isAvulso;
  final String status;
  final String statusLabel;
  final Color statusColor;
  final bool canUpdate;
  final bool isBlocked;
  final String? writtenBy;
  final String? envelopedBy;
  final String? deliveredBy;
  final String? lastSentAt;
  final String? letterWrittenAt;
  final String? publication;
  final String? subject;
  final String? observation;
  final bool deliveredBoxGuard;
  final bool deliveredDoormanMail;

  String get locationLabel {
    final resolvedBlock = blockName.isNotEmpty
        ? blockName
        : blockNumber > 0
        ? 'Bloco $blockNumber'
        : '';
    final resolvedFloor = floorName.isNotEmpty
        ? floorName
        : floorNumber == 0
        ? 'Térreo'
        : floorNumber > 0
        ? '$floorNumberº andar'
        : '';

    return [
      if (resolvedBlock.isNotEmpty) resolvedBlock,
      if (resolvedFloor.isNotEmpty) resolvedFloor,
    ].join(' · ');
  }

  factory ApartmentLetter.fromJson(Map<String, dynamic> json) =>
      ApartmentLetter(
        id: (json['id'] as num).toInt(),
        blockName: json['block_name'] as String? ?? '',
        blockNumber: (json['block_number'] as num?)?.toInt() ?? 0,
        floorName: json['floor_name'] as String? ?? '',
        floorNumber: (json['floor_number'] as num?)?.toInt() ?? -1,
        apartmentNumber: json['apartment_number'] as String? ?? '',
        apartmentNumberValue:
            json['apartment_number_value'] as String? ??
            json['apartment_number'] as String? ??
            '',
        isAvulso: json['is_avulso'] == true,
        status: json['status'] as String? ?? 'no',
        statusLabel: json['status_label'] as String? ?? 'Não registrada',
        statusColor: _colorFromHex(json['status_color'] as String?),
        canUpdate: json['can_update'] == true,
        isBlocked: json['is_blocked'] == true,
        writtenBy: json['written_by'] as String?,
        envelopedBy: json['enveloped_by'] as String?,
        deliveredBy: json['delivered_by'] as String?,
        lastSentAt: json['last_sent_at'] as String?,
        letterWrittenAt: json['letter_written_at'] as String?,
        publication: json['publication'] as String?,
        subject: json['subject'] as String?,
        observation: json['observacao'] as String?,
        deliveredBoxGuard: json['delivered_box_guard'] == true,
        deliveredDoormanMail: json['delivered_doorman_mail'] == true,
      );

  Map<String, Object?> get statusFields => {
    'written_by': writtenBy ?? '',
    'enveloped_by': envelopedBy ?? '',
    'delivered_by': deliveredBy ?? '',
    'last_sent_at': lastSentAt,
    'letter_written_at': letterWrittenAt,
    'publication': publication,
    'subject': subject,
    'observacao': observation,
    'delivered_box_guard': deliveredBoxGuard,
    'delivered_doorman_mail': deliveredDoormanMail,
  };

  ApartmentLetter withStatusFields(
    Map<String, Object?> fields,
    List<LetterStatusOption> statuses,
  ) {
    final nextStatus = fields['status'] as String? ?? status;
    final selectedStatus = statuses.where((item) => item.slug == nextStatus);
    final statusOption = selectedStatus.isEmpty ? null : selectedStatus.first;

    return ApartmentLetter(
      id: id,
      blockName: blockName,
      blockNumber: blockNumber,
      floorName: floorName,
      floorNumber: floorNumber,
      apartmentNumber: apartmentNumber,
      apartmentNumberValue: apartmentNumberValue,
      isAvulso: isAvulso,
      status: nextStatus,
      statusLabel: statusOption?.label ?? statusLabel,
      statusColor: statusOption?.color ?? statusColor,
      canUpdate: canUpdate,
      isBlocked: isBlocked,
      writtenBy: fields['written_by'] as String?,
      envelopedBy: fields['enveloped_by'] as String?,
      deliveredBy: fields['delivered_by'] as String?,
      lastSentAt: fields['last_sent_at'] as String?,
      letterWrittenAt: fields['letter_written_at'] as String?,
      publication: fields['publication'] as String?,
      subject: fields['subject'] as String?,
      observation: fields['observacao'] as String?,
      deliveredBoxGuard: fields['delivered_box_guard'] == true,
      deliveredDoormanMail: fields['delivered_doorman_mail'] == true,
    );
  }
}

class PublicationSuggestion {
  const PublicationSuggestion({
    required this.title,
    required this.code,
    required this.topics,
  });

  final String title;
  final String code;
  final List<String> topics;

  String get label => code.isEmpty ? title : '$code — $title';

  factory PublicationSuggestion.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['topicos'] as List? ?? const [];

    return PublicationSuggestion(
      title: json['titulo'] as String? ?? '',
      code: json['codigo'] as String? ?? '',
      topics: rawTopics
          .map((topic) {
            if (topic is String) return topic;
            if (topic is Map) return topic['titulo'] as String? ?? '';
            return '';
          })
          .where((topic) => topic.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class ApartmentDeliveryHistoryEntry {
  const ApartmentDeliveryHistoryEntry({
    required this.campaign,
    required this.writtenBy,
    required this.writtenAt,
    required this.letterWrittenAt,
    required this.publication,
    required this.subject,
    required this.observation,
    required this.deliveredBoxGuard,
    required this.deliveredDoormanMail,
    required this.isCurrentCampaign,
  });

  final String campaign;
  final String? writtenBy;
  final String? writtenAt;
  final String? letterWrittenAt;
  final String? publication;
  final String? subject;
  final String? observation;
  final bool deliveredBoxGuard;
  final bool deliveredDoormanMail;
  final bool isCurrentCampaign;

  factory ApartmentDeliveryHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ApartmentDeliveryHistoryEntry(
        campaign: json['campanha'] as String? ?? 'Campanha',
        writtenBy: json['written_by'] as String?,
        writtenAt: json['written_at'] as String?,
        letterWrittenAt: json['letter_written_at'] as String?,
        publication: json['publication'] as String?,
        subject: json['subject'] as String?,
        observation: json['observacao'] as String?,
        deliveredBoxGuard: json['delivered_box_guard'] == true,
        deliveredDoormanMail: json['delivered_doorman_mail'] == true,
        isCurrentCampaign: json['desta_campanha'] == true,
      );
}

class CondominiumDetail {
  const CondominiumDetail({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.observations,
    required this.isBlocked,
    required this.campaign,
    required this.campaigns,
    required this.canChooseCampaign,
    required this.canUpdateStatus,
    required this.statuses,
    required this.apartments,
    required this.workflow,
    required this.isManager,
    required this.isDeliverer,
    required this.publisherName,
    required this.congregationPeople,
    required this.publications,
  });

  final int id;
  final String name;
  final String code;
  final String address;
  final String observations;
  final bool isBlocked;
  final CampaignOption? campaign;
  final List<CampaignOption> campaigns;
  final bool canChooseCampaign;
  final bool canUpdateStatus;
  final List<LetterStatusOption> statuses;
  final List<ApartmentLetter> apartments;
  final ApartmentStatusWorkflow workflow;
  final bool isManager;
  final bool isDeliverer;
  final String publisherName;
  final List<String> congregationPeople;
  final List<PublicationSuggestion> publications;

  factory CondominiumDetail.fromJson(Map<String, dynamic> json) {
    final condominium = Map<String, dynamic>.from(
      json['condominium'] as Map? ?? const {},
    );
    final campaign = json['campaign'];
    final campaigns = (json['campaigns'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CampaignOption.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    final statuses = (json['letter_statuses'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              LetterStatusOption.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    final apartments = (json['apartments'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => ApartmentLetter.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    final workflowJson = Map<String, dynamic>.from(
      json['status_flow'] as Map? ?? const {},
    );
    final workflow = ApartmentStatusWorkflow.fromJson(
      workflowJson,
      statuses.map(
        (status) =>
            (slug: status.slug, countsAsDelivered: status.countsAsDelivered),
      ),
    );
    final publications = (json['publications'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              PublicationSuggestion.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((publication) => publication.title.isNotEmpty)
        .toList(growable: false);

    return CondominiumDetail(
      id: (condominium['id'] as num).toInt(),
      name: condominium['name'] as String? ?? 'Condomínio',
      code: condominium['code'] as String? ?? '',
      address: condominium['address'] as String? ?? '',
      observations: condominium['observations'] as String? ?? '',
      isBlocked: condominium['blocked'] == true,
      campaign: campaign is Map
          ? CampaignOption.fromJson(Map<String, dynamic>.from(campaign))
          : null,
      campaigns: campaigns,
      canChooseCampaign: json['can_choose_campaign'] == true,
      canUpdateStatus: json['can_update_status'] == true,
      statuses: statuses,
      apartments: apartments,
      workflow: workflow,
      isManager: json['is_manager'] == true,
      isDeliverer: json['is_deliverer'] == true,
      publisherName: json['publisher_name'] as String? ?? '',
      congregationPeople: (json['congregation_people'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      publications: publications,
    );
  }
}

class StreetCardSummary {
  const StreetCardSummary({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
    required this.neighborhood,
    required this.group,
    required this.streetsCount,
    required this.entrancesCount,
    this.streetNames = const [],
    this.streetLines = const [],
    this.originTerritoryId,
    this.originTerritoryCode = '',
    this.originTerritoryName = '',
  });

  final int id;
  final String code;
  final String name;
  final String description;
  final String neighborhood;
  final String group;
  final int streetsCount;
  final int entrancesCount;
  final List<String> streetNames;
  final List<StreetLine> streetLines;
  final int? originTerritoryId;
  final String originTerritoryCode;
  final String originTerritoryName;

  bool matchesFilters({
    String searchQuery = '',
    String? neighborhoodFilter,
    String? groupFilter,
  }) {
    if (neighborhoodFilter != null &&
        _normalizeStreetCardText(neighborhood) !=
            _normalizeStreetCardText(neighborhoodFilter)) {
      return false;
    }
    if (groupFilter != null &&
        _normalizeStreetCardText(group) !=
            _normalizeStreetCardText(groupFilter)) {
      return false;
    }

    final searchableText = _normalizeStreetCardText(
      [
        code,
        name,
        description,
        neighborhood,
        group,
        originTerritoryCode,
        originTerritoryName,
        ...streetNames,
      ].join(' '),
    );
    final searchTerms = _normalizeStreetCardText(searchQuery)
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);

    return searchTerms.every(searchableText.contains);
  }

  factory StreetCardSummary.fromJson(Map<String, dynamic> json) {
    final streetNames = (json['street_names'] as List? ?? const [])
        .whereType<String>()
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final streetLines = (json['street_lines'] as List? ?? const [])
        .whereType<Map>()
        .map((line) => StreetLine.fromJson(Map<String, dynamic>.from(line)))
        .where((line) => line.coordinates.length >= 2)
        .toList(growable: false);

    return StreetCardSummary(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      neighborhood: json['neighborhood'] as String? ?? '',
      group: json['group'] as String? ?? '',
      streetsCount: (json['streets_count'] as num?)?.toInt() ?? 0,
      entrancesCount: (json['entrances_count'] as num?)?.toInt() ?? 0,
      streetNames: streetNames,
      streetLines: streetLines,
      originTerritoryId: (json['origin_territory_id'] as num?)?.toInt(),
      originTerritoryCode: json['origin_territory_code'] as String? ?? '',
      originTerritoryName: json['origin_territory_name'] as String? ?? '',
    );
  }
}

String _normalizeStreetCardText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class StreetLine {
  const StreetLine({
    required this.name,
    required this.coordinates,
    required this.startAddress,
    required this.endAddress,
  });

  final String name;
  final List<LatLng> coordinates;
  final String startAddress;
  final String endAddress;

  factory StreetLine.fromJson(Map<String, dynamic> json) {
    final rawCoordinates = json['coordinates'] as List? ?? const [];
    final coordinates = rawCoordinates
        .whereType<List>()
        .where(
          (point) => point.length >= 2 && point[0] is num && point[1] is num,
        )
        .map(
          (point) => LatLng(
            (point[1] as num).toDouble(),
            (point[0] as num).toDouble(),
          ),
        )
        .toList(growable: false);

    return StreetLine(
      name: json['name'] as String? ?? 'Rua',
      coordinates: coordinates,
      startAddress: json['start_address'] as String? ?? '',
      endAddress: json['end_address'] as String? ?? '',
    );
  }
}

class StreetEntrance {
  const StreetEntrance({required this.name, required this.position});

  final String name;
  final LatLng position;

  factory StreetEntrance.fromJson(Map<String, dynamic> json) => StreetEntrance(
    name: json['name'] as String? ?? 'Entrada',
    position: LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
  );
}

class StreetRecordedRoute {
  const StreetRecordedRoute({
    required this.id,
    required this.userId,
    required this.name,
    required this.isTest,
    required this.color,
    required this.startedAt,
    required this.endedAt,
    required this.pointCount,
    required this.coordinates,
  });

  final String id;
  final int? userId;
  final String name;
  final bool isTest;
  final Color color;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int pointCount;
  final List<LatLng> coordinates;

  factory StreetRecordedRoute.fromJson(Map<String, dynamic> json) {
    final coordinates = (json['coordinates'] as List? ?? const [])
        .whereType<Map>()
        .where((point) => point['latitude'] is num && point['longitude'] is num)
        .map(
          (point) => LatLng(
            (point['latitude'] as num).toDouble(),
            (point['longitude'] as num).toDouble(),
          ),
        )
        .toList(growable: false);

    return StreetRecordedRoute(
      id: json['id'] as String? ?? '',
      userId: (json['user_id'] as num?)?.toInt(),
      name: json['nome'] as String? ?? 'Publicador',
      isTest: json['is_test'] == true,
      color: _colorFromHex(json['cor'] as String?),
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? '')
          ?.toLocal(),
      endedAt: DateTime.tryParse(json['ended_at'] as String? ?? '')?.toLocal(),
      pointCount: (json['point_count'] as num?)?.toInt() ?? coordinates.length,
      coordinates: coordinates,
    );
  }
}

List<StreetRecordedRoute> filterStreetRecordedRoutes(
  Iterable<StreetRecordedRoute> routes, {
  String? dayKey,
  int? userId,
}) => routes
    .where((route) {
      final routeDay = route.startedAt == null
          ? null
          : _streetRouteDayKey(route.startedAt!);
      return (dayKey == null || routeDay == dayKey) &&
          (userId == null || route.userId == userId);
    })
    .toList(growable: false);

String _streetRouteDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class MapPoint {
  const MapPoint({
    required this.id,
    required this.position,
    required this.title,
    required this.address,
    required this.type,
    required this.color,
    this.typeId,
    this.notes = '',
    this.icon,
  });

  final int id;
  final LatLng position;
  final String title;
  final String address;
  final String type;
  final Color color;
  final int? typeId;
  final String notes;
  final String? icon;

  bool get isDoNotVisit {
    final normalizedType = type
        .toLowerCase()
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('â', 'a');
    return normalizedType.trim() == 'nao bater';
  }

  factory MapPoint.fromJson(Map<String, dynamic> json) => MapPoint(
    id: (json['id'] as num?)?.toInt() ?? 0,
    position: LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
    title: json['title'] as String? ?? '',
    address: json['address'] as String? ?? '',
    type: json['type'] as String? ?? 'Ponto do mapa',
    color: _colorFromHex(json['color'] as String?),
    typeId: (json['type_id'] as num?)?.toInt(),
    notes: json['notes'] as String? ?? '',
    icon: _nonEmptyOrNull(json['icon'] as String?),
  );
}

String? _nonEmptyOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Tipo de ponto do mapa ("Não bater", "Igreja"...) escolhido ao marcar.
class MapPointType {
  const MapPointType({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
  });

  final int id;
  final String name;
  final Color color;
  final String? icon;

  bool get isDoNotVisit => MapPoint(
    id: 0,
    position: const LatLng(0, 0),
    title: '',
    address: '',
    type: name,
    color: color,
  ).isDoNotVisit;

  factory MapPointType.fromJson(Map<String, dynamic> json) => MapPointType(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Ponto',
    color: _colorFromHex(json['color'] as String?),
    icon: _nonEmptyOrNull(json['icon'] as String?),
  );
}

/// Resposta de GET /mobile/map-points.
class MapPointsData {
  const MapPointsData({
    this.points = const [],
    this.types = const [],
    this.canManage = false,
  });

  final List<MapPoint> points;
  final List<MapPointType> types;
  final bool canManage;
}

class RecordedRouteUser {
  const RecordedRouteUser({required this.id, required this.name});

  final int id;
  final String name;

  factory RecordedRouteUser.fromJson(Map<String, dynamic> json) =>
      RecordedRouteUser(
        id: (json['user_id'] as num).toInt(),
        name: json['name'] as String? ?? 'Publicador',
      );
}

class StreetCardDetail {
  const StreetCardDetail({
    required this.summary,
    required this.description,
    required this.originTerritoryId,
    required this.routeRecording,
    this.isLegacy = true,
    required this.canTestRoute,
    required this.testRoutePointsCount,
    required this.streets,
    required this.entrances,
    this.recordedRoutes = const [],
    this.recordedRouteUsers = const [],
    this.territoryDetails,
  });

  final TerritoryDetails? territoryDetails;
  final StreetCardSummary summary;
  final String description;
  final int? originTerritoryId;
  final Map<String, dynamic> routeRecording;
  final bool isLegacy;
  final bool canTestRoute;
  final int testRoutePointsCount;
  final List<StreetLine> streets;
  final List<StreetEntrance> entrances;
  final List<StreetRecordedRoute> recordedRoutes;
  final List<RecordedRouteUser> recordedRouteUsers;

  bool get canRecordRoute => routeRecording['permitido'] == true;
  String get routeMessage => routeRecording['motivo'] as String? ?? '';

  factory StreetCardDetail.fromJson(Map<String, dynamic> json) {
    final card = Map<String, dynamic>.from(json['street_card'] as Map);
    final detailsJson = card['territory_details'];
    return StreetCardDetail(
      territoryDetails: detailsJson is Map
          ? TerritoryDetails.fromJson(Map<String, dynamic>.from(detailsJson))
          : null,
      summary: StreetCardSummary.fromJson(card),
      description: card['description'] as String? ?? '',
      originTerritoryId: (card['origin_territory_id'] as num?)?.toInt(),
      routeRecording: Map<String, dynamic>.from(
        card['route_recording'] as Map? ?? const {},
      ),
      canTestRoute: card['can_test_route'] == true,
      testRoutePointsCount:
          (card['test_route_points_count'] as num?)?.toInt() ?? 0,
      streets: (card['streets'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => StreetLine.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      entrances: (card['entrances'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => StreetEntrance.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      recordedRoutes: (card['recorded_routes'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                StreetRecordedRoute.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      recordedRouteUsers: (card['recorded_route_users'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                RecordedRouteUser.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}

Color _colorFromHex(String? value) {
  final hex = value?.replaceFirst('#', '');
  final parsed = hex == null ? null : int.tryParse(hex, radix: 16);
  if (parsed == null || hex!.length != 6) return const Color(0xFF64748B);
  return Color(0xFF000000 | parsed);
}

DateTime? _parseApiDate(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Formata uma data como dd/MM/yyyy (pt-BR); retorna [fallback] quando nula.
String formatDatePtBr(DateTime? date, {String fallback = '—'}) {
  if (date == null) return fallback;
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year.toString().padLeft(4, '0')}';
}

class TerritoryDetailLocation {
  const TerritoryDetailLocation({
    required this.id,
    required this.name,
    this.address = '',
    this.neighborhood = '',
    this.worked = false,
  });

  final int id;
  final String name;
  final String address;
  final String neighborhood;
  final bool worked;

  factory TerritoryDetailLocation.fromJson(Map<String, dynamic> json) =>
      TerritoryDetailLocation(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        neighborhood: json['neighborhood'] as String? ?? '',
        worked: json['worked'] == true,
      );
}

class TerritoryCycle {
  const TerritoryCycle({this.openedAt, this.closedAt, this.concludedBy});

  final DateTime? openedAt;
  final DateTime? closedAt;
  final String? concludedBy;

  factory TerritoryCycle.fromJson(Map<String, dynamic> json) => TerritoryCycle(
    openedAt: _parseApiDate(json['opened_at']),
    closedAt: _parseApiDate(json['closed_at']),
    concludedBy: _nonEmptyString(json['concluded_by']),
  );
}

class TerritoryPass {
  const TerritoryPass({
    this.date,
    this.outingId,
    this.publisher,
    this.outingLeader,
    this.location,
  });

  final DateTime? date;
  final int? outingId;
  final String? publisher;
  final String? outingLeader;
  final String? location;

  factory TerritoryPass.fromJson(Map<String, dynamic> json) => TerritoryPass(
    date: _parseApiDate(json['date']),
    outingId: (json['outing_id'] as num?)?.toInt(),
    publisher: _nonEmptyString(json['publisher']),
    outingLeader: _nonEmptyString(json['outing_leader']),
    location: _nonEmptyString(json['location']),
  );
}

/// Detalhes de um cartão de território (situação, ciclos e passagens).
class TerritoryDetails {
  const TerritoryDetails({
    required this.id,
    required this.code,
    required this.name,
    required this.situation,
    this.group,
    this.situationLabel = '',
    this.openedAt,
    this.concludedAt,
    this.concludedBy,
    this.forcedCompletion = false,
    this.completionNote,
    this.locations = const [],
    this.cycles = const [],
    this.recentPasses = const [],
  });

  final int id;
  final String code;
  final String name;
  final String situation;
  final String? group;
  final String situationLabel;
  final DateTime? openedAt;
  final DateTime? concludedAt;
  final String? concludedBy;
  final bool forcedCompletion;
  final String? completionNote;
  final List<TerritoryDetailLocation> locations;
  final List<TerritoryCycle> cycles;
  final List<TerritoryPass> recentPasses;

  String get title => [code, name].where((part) => part.isNotEmpty).join(' · ');

  String get displaySituation {
    if (situationLabel.isNotEmpty) return situationLabel;
    return switch (situation) {
      'disponivel' => 'Disponível',
      'em_andamento' => 'Em andamento',
      'concluido' => 'Concluído',
      _ => 'Cartão',
    };
  }

  factory TerritoryDetails.fromJson(Map<String, dynamic> json) {
    // Aceita tanto o objeto direto quanto o envelope {"territory": {...}}.
    final inner = json['territory'];
    final data = inner is Map ? Map<String, dynamic>.from(inner) : json;
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        (data[key] as List? ?? const [])
            .whereType<Map>()
            .map((item) => parse(Map<String, dynamic>.from(item)))
            .toList(growable: false);

    return TerritoryDetails(
      id: (data['id'] as num?)?.toInt() ?? 0,
      code: data['code'] as String? ?? '',
      name: data['name'] as String? ?? '',
      situation: data['situation'] as String? ?? '',
      group: _nonEmptyString(data['group']),
      situationLabel: data['situation_label'] as String? ?? '',
      openedAt: _parseApiDate(data['opened_at']),
      concludedAt: _parseApiDate(data['concluded_at']),
      concludedBy: _nonEmptyString(data['concluded_by']),
      forcedCompletion: data['forced_completion'] == true,
      completionNote: _nonEmptyString(data['completion_note']),
      locations: list('locations', TerritoryDetailLocation.fromJson),
      cycles: list('cycles', TerritoryCycle.fromJson),
      recentPasses: list('recent_passes', TerritoryPass.fromJson),
    );
  }
}

class CardSuggestion {
  const CardSuggestion({
    required this.cardId,
    required this.code,
    required this.name,
    this.group,
    this.lastConcludedAt,
    this.daysWithoutConclusion,
    this.nearRegion,
    this.distanceKm,
    this.reason = '',
  });

  final int cardId;
  final String code;
  final String name;
  final String? group;
  final DateTime? lastConcludedAt;
  final int? daysWithoutConclusion;
  final String? nearRegion;
  final double? distanceKm;
  final String reason;

  String get label => [code, name].where((part) => part.isNotEmpty).join(' · ');

  String get idleLabel {
    final days = daysWithoutConclusion;
    if (days == null) return 'nunca concluído';
    return 'sem concluir há $days ${days == 1 ? 'dia' : 'dias'}';
  }

  factory CardSuggestion.fromJson(Map<String, dynamic> json) => CardSuggestion(
    cardId: (json['card_id'] as num?)?.toInt() ?? 0,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    group: _nonEmptyString(json['group']),
    lastConcludedAt: _parseApiDate(json['last_concluded_at']),
    daysWithoutConclusion: (json['days_without_conclusion'] as num?)?.toInt(),
    nearRegion: _nonEmptyString(json['near_region']),
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    reason: json['reason'] as String? ?? '',
  );
}

class LeaderRegion {
  const LeaderRegion({this.weekday, required this.neighborhood});

  /// 0 = domingo ... 6 = sábado; nulo vale para qualquer dia.
  final int? weekday;
  final String neighborhood;

  factory LeaderRegion.fromJson(Map<String, dynamic> json) => LeaderRegion(
    weekday: (json['weekday'] as num?)?.toInt(),
    neighborhood: json['neighborhood'] as String? ?? '',
  );
}

class CardSuggestions {
  const CardSuggestions({
    this.suggestions = const [],
    this.leaderRegions = const [],
  });

  final List<CardSuggestion> suggestions;
  final List<LeaderRegion> leaderRegions;

  /// Regiões do dirigente para o dia da semana (0 = domingo), incluindo as
  /// regiões sem dia definido.
  List<String> regionsForWeekday(int weekday) => {
    for (final region in leaderRegions)
      if (region.neighborhood.isNotEmpty &&
          (region.weekday == null || region.weekday == weekday))
        region.neighborhood,
  }.toList(growable: false);

  factory CardSuggestions.fromJson(
    Map<String, dynamic> json,
  ) => CardSuggestions(
    suggestions: (json['suggestions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CardSuggestion.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.cardId != 0)
        .toList(growable: false),
    leaderRegions: (json['leader_regions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => LeaderRegion.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
  );
}

class Territory {
  const Territory({
    required this.id,
    required this.code,
    required this.name,
    required this.situation,
    required this.geometry,
    required this.routeRecording,
    this.group,
    this.isLegacy = true,
    this.center,
    this.workedPlaces = 0,
    this.totalPlaces = 0,
    this.coveragePercent = 0,
    this.forcedCompletion = false,
    this.canTestRoute = false,
    this.testRoutePointsCount = 0,
    this.serverSituationLabel = '',
    this.openedAt,
    this.concludedAt,
    this.concludedBy,
    this.completionNote,
  });

  final int id;
  final String code;
  final String name;
  final String situation;
  final String? group;
  final String serverSituationLabel;
  final DateTime? openedAt;
  final DateTime? concludedAt;
  final String? concludedBy;
  final String? completionNote;
  final Map<String, dynamic> geometry;
  final Map<String, dynamic> routeRecording;
  final bool isLegacy;
  final LatLng? center;
  final int workedPlaces;
  final int totalPlaces;
  final int coveragePercent;
  final bool forcedCompletion;
  final bool canTestRoute;
  final int testRoutePointsCount;

  bool get canRecordRoute => routeRecording['permitido'] == true;
  String get routeMessage => routeRecording['motivo'] as String? ?? '';

  bool matchesSearch(String query) {
    final normalizedQuery = _normalizeTerritorySearch(query);
    if (normalizedQuery.isEmpty) return true;

    return _normalizeTerritorySearch('$code $name ${group ?? ''}')
        .contains(normalizedQuery);
  }

  String get situationLabel => serverSituationLabel.isNotEmpty
      ? serverSituationLabel
      : switch (situation) {
          'disponivel' => 'Disponível',
          'em_andamento' => 'Em andamento',
          'concluido' => 'Concluído',
          _ => 'Território',
        };

  Color get color => switch (situation) {
    'em_andamento' => const Color(0xFFB4531F),
    'concluido' => const Color(0xFF196B24),
    _ => const Color(0xFF156082),
  };

  factory Territory.fromJson(Map<String, dynamic> json) {
    final centerJson = json['center'];
    final workedPlaces = (json['worked_places'] as num?)?.toInt() ?? 0;
    final totalPlaces = (json['total_places'] as num?)?.toInt() ?? 0;
    final coveragePercent =
        (json['coverage_percent'] as num?)?.toInt() ??
        (totalPlaces == 0 ? 0 : (workedPlaces / totalPlaces * 100).round());

    return Territory(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? 'Território',
      situation: json['situation'] as String? ?? 'disponivel',
      group: json['group'] as String?,
      geometry: Map<String, dynamic>.from(json['geometry'] as Map),
      routeRecording: Map<String, dynamic>.from(
        json['route_recording'] as Map? ?? const {},
      ),
      isLegacy: json['legacy'] != false,
      center: centerJson is Map
          ? LatLng(
              (centerJson['latitude'] as num).toDouble(),
              (centerJson['longitude'] as num).toDouble(),
            )
          : null,
      workedPlaces: workedPlaces.clamp(0, totalPlaces),
      totalPlaces: totalPlaces,
      coveragePercent: coveragePercent.clamp(0, 100),
      forcedCompletion: json['forced_completion'] == true,
      canTestRoute: json['can_test_route'] == true,
      testRoutePointsCount:
          (json['test_route_points_count'] as num?)?.toInt() ?? 0,
      serverSituationLabel: json['situation_label'] as String? ?? '',
      openedAt: _parseApiDate(json['opened_at']),
      concludedAt: _parseApiDate(json['concluded_at']),
      concludedBy: _nonEmptyString(json['concluded_by']),
      completionNote: _nonEmptyString(json['completion_note']),
    );
  }

  List<List<List<LatLng>>> polygonRings() {
    final type = geometry['type'];
    final rawCoordinates = geometry['coordinates'];
    if (rawCoordinates is! List) return const [];

    final polygonCoordinates = type == 'Polygon'
        ? [rawCoordinates]
        : type == 'MultiPolygon'
        ? rawCoordinates
        : const [];
    final output = <List<List<LatLng>>>[];

    for (final polygon in polygonCoordinates) {
      if (polygon is! List || polygon.isEmpty || polygon.first is! List) {
        continue;
      }

      final rings = polygon.whereType<List>().toList();
      final outer = _ringToPoints(rings.first);
      if (outer.length < 3) continue;

      final holes = rings
          .skip(1)
          .map(_ringToPoints)
          .where((ring) => ring.length >= 3)
          .toList(growable: false);
      output.add([outer, ...holes]);
    }

    return output;
  }

  LatLng? get preferredCenter {
    if (center != null) return center;
    final firstPolygon = polygonRings();
    if (firstPolygon.isEmpty) return null;
    final points = firstPolygon.first.first;
    final latitude =
        points.map((point) => point.latitude).reduce((a, b) => a + b) /
        points.length;
    final longitude =
        points.map((point) => point.longitude).reduce((a, b) => a + b) /
        points.length;
    return LatLng(latitude, longitude);
  }

  bool contains(LatLng point) {
    for (final polygon in polygonRings()) {
      if (_insideRing(polygon.first, point) &&
          !polygon.skip(1).any((ring) => _insideRing(ring, point))) {
        return true;
      }
    }

    return false;
  }

  static List<LatLng> _ringToPoints(List ring) => ring
      .whereType<List>()
      .where((pair) => pair.length >= 2 && pair[0] is num && pair[1] is num)
      .map(
        (pair) =>
            LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
      )
      .toList(growable: false);

  static bool _insideRing(List<LatLng> ring, LatLng point) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i];
      final b = ring[j];
      final crosses =
          (a.latitude > point.latitude) != (b.latitude > point.latitude);
      if (crosses &&
          point.longitude <
              (b.longitude - a.longitude) *
                      (point.latitude - a.latitude) /
                      ((b.latitude - a.latitude).abs() < 1e-12
                          ? 1e-12
                          : b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }
}

List<Territory> filterTerritories({
  required Iterable<Territory> territories,
  String searchQuery = '',
  String situation = 'todos',
  String? group,
}) => territories
    .where(
      (territory) => situation == 'todos' || territory.situation == situation,
    )
    .where(
      (territory) =>
          group == null ||
          _normalizeTerritorySearch(territory.group ?? '') ==
              _normalizeTerritorySearch(group),
    )
    .where((territory) => territory.matchesSearch(searchQuery))
    .toList(growable: false);

String _normalizeTerritorySearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class FieldLocation {
  const FieldLocation({
    required this.id,
    required this.name,
    this.address = '',
    this.mapsUrl = '',
  });

  final int id;
  final String name;
  final String address;
  final String mapsUrl;

  factory FieldLocation.fromJson(Map<String, dynamic> json) => FieldLocation(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? 'Local de encontro',
    address: json['address'] as String? ?? '',
    mapsUrl: json['maps_url'] as String? ?? '',
  );
}

class FieldGroup {
  const FieldGroup({required this.id, required this.name, required this.color});

  final int id;
  final String name;
  final Color color;

  factory FieldGroup.fromJson(Map<String, dynamic> json) => FieldGroup(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? 'Grupo',
    color: _colorFromHex(json['color'] as String?),
  );
}

class FieldOutingTerritoryCard {
  const FieldOutingTerritoryCard({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;

  String get label => [code, name].where((part) => part.isNotEmpty).join(' · ');

  factory FieldOutingTerritoryCard.fromJson(Map<String, dynamic> json) =>
      FieldOutingTerritoryCard(
        id: (json['id'] as num).toInt(),
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

class FieldOuting {
  const FieldOuting({
    required this.id,
    required this.date,
    required this.time,
    required this.leader,
    required this.notes,
    required this.allGroups,
    required this.groups,
    required this.situation,
    required this.situationLabel,
    this.territoryCards = const [],
    this.location,
    this.recurrenceId,
  });

  final int id;
  final DateTime? date;
  final String time;
  final String leader;
  final String notes;
  final bool allGroups;
  final List<FieldGroup> groups;
  final String situation;
  final String situationLabel;
  final List<FieldOutingTerritoryCard> territoryCards;
  final FieldLocation? location;
  final int? recurrenceId;

  factory FieldOuting.fromJson(Map<String, dynamic> json) {
    final locationJson = json['location'];
    final situationJson = Map<String, dynamic>.from(
      json['situation'] as Map? ?? const {},
    );
    return FieldOuting(
      id: (json['id'] as num).toInt(),
      date: DateTime.tryParse(json['date'] as String? ?? ''),
      time: json['time'] as String? ?? '',
      leader: json['leader'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      allGroups: json['all_groups'] == true,
      groups: (json['groups'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => FieldGroup.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      situation: situationJson['slug'] as String? ?? 'pendente',
      situationLabel: situationJson['label'] as String? ?? 'Pendente',
      territoryCards: (json['territory_cards'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => FieldOutingTerritoryCard.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      location: locationJson is Map
          ? FieldLocation.fromJson(Map<String, dynamic>.from(locationJson))
          : null,
      recurrenceId: (json['recurrence_id'] as num?)?.toInt(),
    );
  }
}

class FieldOutingPattern {
  const FieldOutingPattern({
    required this.id,
    required this.name,
    required this.weekdays,
    required this.time,
    required this.leader,
    required this.notes,
    required this.allGroups,
    required this.groups,
    required this.isActive,
    required this.description,
    this.location,
    this.validFrom,
    this.validThrough,
  });

  final int id;
  final String name;
  final List<int> weekdays;
  final String time;
  final String leader;
  final String notes;
  final bool allGroups;
  final List<FieldGroup> groups;
  final FieldLocation? location;
  final DateTime? validFrom;
  final DateTime? validThrough;
  final bool isActive;
  final String description;

  factory FieldOutingPattern.fromJson(Map<String, dynamic> json) {
    final locationJson = json['location'];
    return FieldOutingPattern(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      weekdays: (json['weekdays'] as List? ?? const [])
          .whereType<num>()
          .map((day) => day.toInt())
          .toList(growable: false),
      time: json['time'] as String? ?? '',
      leader: json['leader'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      allGroups: json['all_groups'] == true,
      groups: (json['groups'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => FieldGroup.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      location: locationJson is Map
          ? FieldLocation.fromJson(Map<String, dynamic>.from(locationJson))
          : null,
      validFrom: DateTime.tryParse(json['valid_from'] as String? ?? ''),
      validThrough: DateTime.tryParse(json['valid_through'] as String? ?? ''),
      isActive: json['is_active'] == true,
      description: json['description'] as String? ?? '',
    );
  }
}

class FieldScheduleExportDay {
  const FieldScheduleExportDay({
    required this.date,
    required this.outingsCount,
    required this.times,
  });

  final DateTime date;
  final int outingsCount;
  final List<String> times;

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  factory FieldScheduleExportDay.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.tryParse(json['date'] as String? ?? '');
    if (parsedDate == null) {
      throw const FormatException('Data inválida na programação de campo.');
    }

    return FieldScheduleExportDay(
      date: parsedDate,
      outingsCount: (json['outings_count'] as num?)?.toInt() ?? 0,
      times: (json['times'] as List? ?? const []).whereType<String>().toList(
        growable: false,
      ),
    );
  }
}

class FieldCalendarData {
  const FieldCalendarData({
    required this.month,
    required this.outings,
    required this.patterns,
    required this.locations,
    required this.groups,
    required this.leaders,
    required this.canManage,
    required this.canManageLocations,
  });

  final String month;
  final List<FieldOuting> outings;
  final List<FieldOutingPattern> patterns;
  final List<FieldLocation> locations;
  final List<FieldGroup> groups;
  final List<String> leaders;
  final bool canManage;
  final bool canManageLocations;

  List<FieldOuting> outingsOn(DateTime date) => outings
      .where((outing) => DateUtils.isSameDay(outing.date, date))
      .toList(growable: false);

  factory FieldCalendarData.fromJson(Map<String, dynamic> json) {
    final permissions = Map<String, dynamic>.from(
      json['permissions'] as Map? ?? const {},
    );
    return FieldCalendarData(
      month: json['month'] as String? ?? '',
      outings: (json['outings'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => FieldOuting.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      patterns: (json['patterns'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                FieldOutingPattern.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      locations: (json['locations'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => FieldLocation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      groups: (json['groups'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => FieldGroup.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      leaders: (json['leaders'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      canManage: permissions['can_manage'] == true,
      canManageLocations: permissions['can_manage_locations'] == true,
    );
  }
}

class FieldDesignation {
  const FieldDesignation({
    required this.id,
    required this.territoryNumber,
    required this.territoryName,
    required this.publisher,
    this.assignedAt,
    this.completedAt,
  });

  final int id;
  final String territoryNumber;
  final String territoryName;
  final String publisher;
  final DateTime? assignedAt;
  final DateTime? completedAt;

  factory FieldDesignation.fromJson(Map<String, dynamic> json) =>
      FieldDesignation(
        id: (json['id'] as num).toInt(),
        territoryNumber: json['territory_number'] as String? ?? '',
        territoryName: json['territory_name'] as String? ?? '',
        publisher: json['publisher'] as String? ?? '',
        assignedAt: DateTime.tryParse(json['assigned_at'] as String? ?? ''),
        completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
      );
}

class FieldDesignationsData {
  const FieldDesignationsData({
    required this.serviceYear,
    required this.availableYears,
    required this.designations,
    required this.editable,
  });

  final int serviceYear;
  final List<int> availableYears;
  final List<FieldDesignation> designations;
  final bool editable;

  factory FieldDesignationsData.fromJson(Map<String, dynamic> json) =>
      FieldDesignationsData(
        serviceYear: (json['service_year'] as num?)?.toInt() ?? 0,
        availableYears: (json['available_years'] as List? ?? const [])
            .whereType<num>()
            .map((year) => year.toInt())
            .toList(growable: false),
        designations: (json['designations'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  FieldDesignation.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        editable: json['editable'] == true,
      );
}
