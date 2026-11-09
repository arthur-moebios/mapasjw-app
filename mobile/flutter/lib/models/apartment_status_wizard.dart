import 'publication_citation.dart';

enum ApartmentWizardStep { write, envelope, deliver, complete }

enum ApartmentWizardAction { write, envelope, deliver, correct, clear }

/// Holds the status transitions used by the PWA's guided apartment workflow.
class ApartmentStatusWorkflow {
  const ApartmentStatusWorkflow({
    required this.emptyStatus,
    required this.writtenStatus,
    required this.envelopedStatus,
    required this.deliveredStatus,
    this.statusCountsAsDelivered = const {},
  });

  final String emptyStatus;
  final String? writtenStatus;
  final String? envelopedStatus;
  final String? deliveredStatus;
  final Map<String, bool> statusCountsAsDelivered;

  factory ApartmentStatusWorkflow.fromJson(
    Map<String, dynamic> json,
    Iterable<({String slug, bool countsAsDelivered})> statuses,
  ) {
    String? optionalStatus(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return ApartmentStatusWorkflow(
      emptyStatus: json['empty'] as String? ?? 'no',
      writtenStatus: optionalStatus('written'),
      envelopedStatus: optionalStatus('enveloped'),
      deliveredStatus: optionalStatus('delivered'),
      statusCountsAsDelivered: {
        for (final status in statuses) status.slug: status.countsAsDelivered,
      },
    );
  }

  ApartmentWizardStep stepFor(String status) {
    if (status == deliveredStatus) {
      return ApartmentWizardStep.complete;
    }
    if (envelopedStatus != null && status == envelopedStatus) {
      return ApartmentWizardStep.deliver;
    }
    if (writtenStatus != null && status == writtenStatus) {
      return ApartmentWizardStep.envelope;
    }
    if (status == emptyStatus) {
      return ApartmentWizardStep.write;
    }

    return statusCountsAsDelivered[status] == true
        ? ApartmentWizardStep.complete
        : ApartmentWizardStep.write;
  }

  String? previousStatus(String status) {
    if (status == deliveredStatus) {
      return envelopedStatus ?? writtenStatus ?? emptyStatus;
    }
    if (envelopedStatus != null && status == envelopedStatus) {
      return writtenStatus ?? emptyStatus;
    }
    if (writtenStatus != null && status == writtenStatus) {
      return emptyStatus;
    }

    return null;
  }

  /// Builds the same metadata-preserving payload sent by the PWA.
  Map<String, Object?>? buildPayload({
    required ApartmentWizardAction action,
    required String apartmentNumber,
    required String currentStatus,
    required Map<String, Object?> currentFields,
    required DateTime today,
    String publisherName = '',
    String publication = '',
    String subject = '',

    /// null = o usuário não mexeu e não havia citações: a chave `citacoes` não
    /// vai no payload (o servidor não altera). Lista vazia = limpa.
    List<PublicationCitation>? citations,
    String writtenBy = '',
    String envelopedBy = '',
    String deliveredBy = '',
    bool deliveredBoxGuard = false,
    bool deliveredDoormanMail = false,
    bool canDeliver = false,
  }) {
    final payload = <String, Object?>{
      'apartment_number': apartmentNumber,
      'status': currentStatus,
      'written_by': currentFields['written_by'] ?? '',
      'enveloped_by': currentFields['enveloped_by'] ?? '',
      'delivered_by': currentFields['delivered_by'] ?? '',
      'last_sent_at': currentFields['last_sent_at'],
      'letter_written_at': currentFields['letter_written_at'],
      'publication': currentFields['publication'],
      'subject': currentFields['subject'],
      'observacao': currentFields['observacao'],
      'delivered_box_guard': currentFields['delivered_box_guard'] == true,
      'delivered_doorman_mail': currentFields['delivered_doorman_mail'] == true,
    };

    switch (action) {
      case ApartmentWizardAction.write:
        if (writtenStatus == null) return null;
        payload.addAll({
          'status': writtenStatus,
          'publication': citations == null
              ? _nullableText(publication)
              : CitationRules.publicationLabel(citations, publication),
          'subject': _nullableText(subject),
          if (citations != null)
            'citacoes': [for (final c in citations) c.toJson()],
          'letter_written_at':
              _textOrNull(currentFields['letter_written_at']) ??
              _dateOnly(today),
          'written_by':
              _nullableText(writtenBy) ?? _nullableText(publisherName),
        });
      case ApartmentWizardAction.envelope:
        if (envelopedStatus == null) return null;
        payload.addAll({
          'status': envelopedStatus,
          'enveloped_by':
              _nullableText(envelopedBy) ?? _nullableText(publisherName),
        });
      case ApartmentWizardAction.deliver:
        if (deliveredStatus == null || !canDeliver) return null;
        payload.addAll({
          'status': deliveredStatus,
          'last_sent_at':
              _textOrNull(currentFields['last_sent_at']) ?? _dateOnly(today),
          'delivered_box_guard': deliveredBoxGuard,
          'delivered_doorman_mail': deliveredDoormanMail,
          'delivered_by':
              _nullableText(deliveredBy) ?? _nullableText(publisherName),
        });
      case ApartmentWizardAction.correct:
        final previous = previousStatus(currentStatus);
        if (previous == null) return null;
        payload['status'] = previous;
      case ApartmentWizardAction.clear:
        payload.addAll({
          'status': emptyStatus,
          'written_by': '',
          'enveloped_by': '',
          'delivered_by': '',
          'last_sent_at': null,
          'letter_written_at': null,
          'publication': null,
          'subject': null,
          'citacoes': <Object?>[],
          'observacao': null,
          'delivered_box_guard': false,
          'delivered_doorman_mail': false,
          'limpar': true,
        });
    }

    return payload;
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String? _textOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _nullableText(String value) => _textOrNull(value);
}
