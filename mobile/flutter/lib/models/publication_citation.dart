import 'mobile_models.dart';

/// Máximo de publicações citadas por carta (mesmo limite do servidor e da web).
const int maxPublicationCitations = 5;

String _cut(String value, int max) => value.runes.length <= max
    ? value
    : String.fromCharCodes(value.runes.take(max));

String _text(Object? value) => value is String ? value : '';

/// Só aceita URLs https (capas e links vindos do servidor nunca são http).
String? httpsOnly(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return RegExp(r'^https://\S+$', caseSensitive: false).hasMatch(text)
      ? text
      : null;
}

const _accents = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Minúsculas e sem acentos, para busca.
String normalizeSearch(String? value) {
  final lower = (value ?? '').toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

List<String> _searchParts(String term) =>
    normalizeSearch(term)
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

/// Publicação citada numa carta. Imutável. [legacy] marca o texto antigo de
/// `publication` (sem capa, sem citação gravada no servidor).
class PublicationCitation {
  const PublicationCitation({
    required this.title,
    this.code = '',
    this.type = '',
    this.link,
    this.cover,
    this.topic = '',
    this.topicLink,
    this.legacy = false,
  });

  final String code;
  final String title;
  final String type;
  final String? link;
  final String? cover;
  final String topic;
  final String? topicLink;
  final bool legacy;

  /// Link do QR: o do assunto interno, senão o da publicação.
  String? get qrLink => topicLink ?? link;

  /// Chave de duplicidade (código + título + assunto interno).
  String get key => normalizeSearch('$code|$title|$topic');

  /// Tolerante: sem título, devolve null.
  static PublicationCitation? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = _text(raw['titulo']).trim();
    if (title.isEmpty) return null;
    return PublicationCitation(
      code: _cut(_text(raw['codigo']), 40),
      title: _cut(title, 160),
      type: _cut(_text(raw['tipo']), 20),
      link: httpsOnly(raw['link']),
      cover: httpsOnly(raw['capa']),
      topic: _cut(_text(raw['topico']), 160),
      topicLink: httpsOnly(raw['topico_link']),
    );
  }

  /// Lista tolerante: aceita lista, JSON em texto ou nulo (= vazia); descarta
  /// itens sem título e limita a [maxPublicationCitations].
  static List<PublicationCitation> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map(tryFromJson)
        .whereType<PublicationCitation>()
        .take(maxPublicationCitations)
        .toList(growable: false);
  }

  Map<String, Object?> toJson() => {
    'codigo': code,
    'titulo': title,
    'tipo': type,
    'link': link,
    'capa': cover,
    'topico': topic,
    'topico_link': topicLink,
  };

  @override
  bool operator ==(Object other) =>
      other is PublicationCitation &&
      other.code == code &&
      other.title == title &&
      other.type == type &&
      other.link == link &&
      other.cover == cover &&
      other.topic == topic &&
      other.topicLink == topicLink &&
      other.legacy == legacy;

  @override
  int get hashCode =>
      Object.hash(code, title, type, link, cover, topic, topicLink, legacy);
}

class TopicEntry {
  const TopicEntry({required this.title, this.link});

  final String title;
  final String? link;

  static TopicEntry? tryFromJson(Object? raw) {
    if (raw is String) {
      return raw.trim().isEmpty ? null : TopicEntry(title: raw.trim());
    }
    if (raw is Map) {
      final title = _text(raw['titulo']).trim();
      if (title.isEmpty) return null;
      return TopicEntry(title: title, link: httpsOnly(raw['link']));
    }
    return null;
  }
}

class PublicationEntry {
  const PublicationEntry({
    required this.title,
    this.code = '',
    this.type = '',
    this.link,
    this.cover,
    this.isNew = false,
    this.topics = const [],
  });

  final String code;
  final String title;
  final String type;
  final String? link;
  final String? cover;
  final bool isNew;
  final List<TopicEntry> topics;

  String get label => code.isEmpty ? title : '$code — $title';

  static PublicationEntry? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final title = _text(raw['titulo']).trim();
    if (title.isEmpty) return null;
    return PublicationEntry(
      code: _text(raw['codigo']),
      title: title,
      type: _text(raw['tipo']),
      link: httpsOnly(raw['link']),
      cover: httpsOnly(raw['capa']),
      isNew: raw['novo'] == true,
      topics: (raw['topicos'] is List ? raw['topicos'] as List : const [])
          .map(TopicEntry.tryFromJson)
          .whereType<TopicEntry>()
          .toList(growable: false),
    );
  }

  /// Citação desta publicação, com ou sem assunto interno.
  PublicationCitation cite([TopicEntry? topic]) => PublicationCitation(
    code: _cut(code, 40),
    title: _cut(title, 160),
    type: _cut(type, 20),
    link: link,
    cover: cover,
    topic: topic == null ? '' : _cut(topic.title, 160),
    topicLink: topic?.link,
  );
}

/// Catálogo v2 (`GET /mobile/letters/publications`) ou, no fallback, o
/// catálogo antigo do detalhe do condomínio.
class PublicationCatalog {
  const PublicationCatalog({
    this.themes = const [],
    this.publications = const [],
  });

  final List<String> themes;
  final List<PublicationEntry> publications;

  bool get isEmpty => publications.isEmpty && themes.isEmpty;

  factory PublicationCatalog.fromJson(Map<String, dynamic> json) =>
      PublicationCatalog(
        themes: (json['temas'] is List ? json['temas'] as List : const [])
            .whereType<String>()
            .where((theme) => theme.trim().isNotEmpty)
            .toList(growable: false),
        publications:
            (json['publicacoes'] is List
                    ? json['publicacoes'] as List
                    : const [])
                .map(PublicationEntry.tryFromJson)
                .whereType<PublicationEntry>()
                .toList(growable: false),
      );

  /// Catálogo antigo (tópicos como texto; capa/link se o servidor já mandar).
  factory PublicationCatalog.fromLegacy(List<PublicationSuggestion> items) =>
      PublicationCatalog(
        publications: [
          for (final item in items)
            PublicationEntry(
              code: item.code,
              title: item.title,
              type: item.type,
              link: item.link,
              cover: item.cover,
              isNew: item.isNew,
              topics: [for (final t in item.topics) TopicEntry(title: t)],
            ),
        ],
      );
}

/// Uma folha de QR possível: publicação (ou tópico) com link para o QR.
class QrOption {
  const QrOption({
    required this.title,
    required this.link,
    required this.label,
    this.code = '',
    this.subject = '',
  });

  final String title;
  final String code;
  final String link;
  final String subject;

  /// Texto para o seletor: título, mais o assunto interno quando houver.
  final String label;

  /// Corpo de `POST /mobile/publications/qr`.
  Map<String, Object?> toJson() => {
    'titulo': title,
    'codigo': code,
    'assunto': subject,
    'link': link,
  };

  @override
  bool operator ==(Object other) =>
      other is QrOption &&
      other.title == title &&
      other.code == code &&
      other.link == link &&
      other.subject == subject &&
      other.label == label;

  @override
  int get hashCode => Object.hash(title, code, link, subject, label);
}

/// Regras puras (testáveis sem widgets).
abstract final class CitationRules {
  /// Acrescenta [citation] respeitando limite e duplicidade (repetida ou
  /// acima do limite: devolve a mesma lista).
  static List<PublicationCitation> add(
    List<PublicationCitation> current,
    PublicationCitation citation,
  ) {
    if (current.length >= maxPublicationCitations) return current;
    if (current.any((item) => item.key == citation.key)) return current;
    return [...current, citation];
  }

  static List<PublicationCitation> removeAt(
    List<PublicationCitation> current,
    int index,
  ) => [
    for (var i = 0; i < current.length; i++)
      if (i != index) current[i],
  ];

  /// Valor gravado em `publication`: título da 1ª citação; sem citações, o
  /// texto legado intacto (ou null).
  static String? publicationLabel(
    List<PublicationCitation> citations,
    String? legacy,
  ) {
    if (citations.isNotEmpty) return _cut(citations.first.title, 120);
    final text = (legacy ?? '').trim();
    return text.isEmpty ? null : text;
  }

  static List<PublicationEntry> filterPublications(
    PublicationCatalog catalog,
    String term,
  ) {
    final parts = _searchParts(term);
    return catalog.publications
        .where((p) {
          final haystack = normalizeSearch('${p.label} ${p.type}');
          return parts.every(haystack.contains);
        })
        .take(60)
        .toList(growable: false);
  }

  static List<TopicEntry> filterTopics(PublicationEntry entry, String term) {
    final parts = _searchParts(term);
    return entry.topics
        .where((t) {
          final haystack = normalizeSearch(t.title);
          return parts.every(haystack.contains);
        })
        .take(120)
        .toList(growable: false);
  }

  /// Assunto livre: tópicos das publicações citadas primeiro, depois os temas.
  static List<String> subjectSuggestions(
    List<String> themes,
    List<PublicationCitation> citations,
    String term,
  ) {
    final parts = _searchParts(term);
    final seen = <String>{};
    final out = <String>[];
    final all = [
      ...citations.map((c) => c.topic).where((t) => t.isNotEmpty),
      ...themes,
    ];
    for (final item in all) {
      final key = normalizeSearch(item);
      if (item.isEmpty || seen.contains(key)) continue;
      if (!parts.every(key.contains)) continue;
      seen.add(key);
      out.add(item);
    }
    return out.take(80).toList(growable: false);
  }

  /// Linha de leitura: "Publicações: A (tópico); B · Assunto: tema".
  static String readingText(
    List<PublicationCitation> citations,
    String? legacy,
    String? subject,
  ) {
    final pubs = citations.isNotEmpty
        ? citations
              .map((c) => c.topic.isEmpty ? c.title : '${c.title} (${c.topic})')
              .join('; ')
        : (legacy ?? '').trim();
    final label = citations.length > 1 ? 'Publicações' : 'Publicação';
    final topic = (subject ?? '').trim();
    return [
      if (pubs.isNotEmpty) '$label: $pubs',
      if (topic.isNotEmpty) 'Assunto: $topic',
    ].join(' · ');
  }

  /// Publicação do catálogo a partir do texto antigo: rótulo completo, só o
  /// título ou o código no começo.
  static PublicationEntry? findPublication(
    PublicationCatalog catalog,
    String? text,
  ) {
    final value = normalizeSearch(text).trim();
    if (value.isEmpty) return null;
    for (final entry in catalog.publications) {
      if (normalizeSearch(entry.label) == value ||
          normalizeSearch(entry.title) == value ||
          (entry.code.isNotEmpty &&
              value.startsWith('${normalizeSearch(entry.code)} '))) {
        return entry;
      }
    }
    return null;
  }

  /// Link do QR de uma publicação: o do tópico quando o assunto bate com um
  /// tópico que tem link; senão o da publicação.
  static String? linkForQr(PublicationEntry? entry, String? subject) {
    if (entry == null) return null;
    final wanted = normalizeSearch(subject).trim();
    if (wanted.isNotEmpty) {
      for (final topic in entry.topics) {
        if (normalizeSearch(topic.title) == wanted && topic.link != null) {
          return topic.link;
        }
      }
    }
    return entry.link;
  }

  /// Opções de QR (mesma regra da web): cada citação com link (o do assunto
  /// interno, senão o da publicação); sem citações, o caminho legado pelo
  /// texto da publicação, procurado no [catalog].
  static List<QrOption> qrOptions({
    required List<PublicationCitation> citations,
    String? legacy,
    String? freeSubject,
    PublicationCatalog catalog = const PublicationCatalog(),
  }) {
    final free = (freeSubject ?? '').trim();
    String join(String topic) {
      final seen = <String>{};
      final parts = [topic.trim(), free].where((part) {
        final key = normalizeSearch(part);
        return part.isNotEmpty && seen.add(key);
      });
      return _cut(parts.join(' — '), 255);
    }

    if (citations.isNotEmpty) {
      return [
        for (final c in citations)
          if (httpsOnly(c.topicLink) ?? httpsOnly(c.link) case final link?)
            QrOption(
              title: c.title,
              code: c.code,
              link: link,
              subject: join(c.topic),
              label: c.topic.isEmpty ? c.title : '${c.title} — ${c.topic}',
            ),
      ];
    }

    final entry = findPublication(catalog, legacy);
    final link = linkForQr(entry, free);
    if (entry == null || link == null) return const [];
    return [
      QrOption(
        title: entry.title,
        code: entry.code,
        link: link,
        subject: free,
        label: entry.label,
      ),
    ];
  }
}
