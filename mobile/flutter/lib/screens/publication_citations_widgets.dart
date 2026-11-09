import 'package:flutter/material.dart';

import '../models/publication_citation.dart';

/// Capa em miniatura: só https, decodificada pequena, com placeholder neutro
/// enquanto carrega e quando falha ou não existe.
class CitationCover extends StatelessWidget {
  const CitationCover({this.url, this.width = 40, this.height = 54, super.key});

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = httpsOnly(url);
    Widget placeholder() => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.menu_book_outlined,
        size: width * 0.5,
        color: scheme.onSurfaceVariant,
      ),
    );
    if (cover == null) return placeholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        cover,
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: 120,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => placeholder(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder(),
      ),
    );
  }
}

/// Publicação citada: mini capa, título e assunto interno. Com [onRemove]
/// mostra o botão de remover; [mini] gera a versão compacta do histórico.
class CitationChip extends StatelessWidget {
  const CitationChip({
    required this.citation,
    this.onRemove,
    this.mini = false,
    super.key,
  });

  final PublicationCitation citation;
  final VoidCallback? onRemove;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = citation.legacy
        ? '${citation.title} — antiga'
        : citation.title;
    final topic = citation.topic;

    if (mini) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CitationCover(url: citation.cover, width: 22, height: 30),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                topic.isEmpty ? title : '$title · $topic',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CitationCover(url: citation.cover),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (topic.isNotEmpty)
                  Text(
                    topic,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remover $title',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

/// Leitura das citações (passos seguintes): chips sem remover; o texto
/// legado aparece como chip "— antiga".
class CitationReadingList extends StatelessWidget {
  const CitationReadingList({
    required this.citations,
    required this.legacy,
    super.key,
  });

  final List<PublicationCitation> citations;
  final String legacy;

  @override
  Widget build(BuildContext context) {
    final shown = citations.isNotEmpty
        ? citations
        : [
            if (legacy.trim().isNotEmpty)
              PublicationCitation(title: legacy.trim(), legacy: true),
          ];
    return Column(
      children: [
        for (final citation in shown) CitationChip(citation: citation),
      ],
    );
  }
}

/// Campo "Publicações citadas": chips + "Adicionar publicação citada".
class CitedPublicationsEditor extends StatelessWidget {
  const CitedPublicationsEditor({
    required this.citations,
    required this.legacy,
    required this.catalog,
    required this.onChanged,
    required this.onLegacyRemoved,
    super.key,
  });

  final List<PublicationCitation> citations;

  /// Texto antigo de `publication`, sem citações gravadas.
  final String legacy;
  final Future<PublicationCatalog> catalog;
  final ValueChanged<List<PublicationCitation>> onChanged;
  final VoidCallback onLegacyRemoved;

  Future<void> _add(BuildContext context) async {
    final picked = await showPublicationPicker(context, catalog);
    if (picked == null || !context.mounted) return;
    final next = CitationRules.add(citations, picked);
    if (next.length == citations.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta publicação já foi citada.')),
      );
      return;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final full = citations.length >= maxPublicationCitations;
    final hasLegacy = citations.isEmpty && legacy.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Publicações citadas (${citations.length}/$maxPublicationCitations)',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < citations.length; i++)
          CitationChip(
            citation: citations[i],
            onRemove: () => onChanged(CitationRules.removeAt(citations, i)),
          ),
        if (hasLegacy)
          CitationChip(
            citation: PublicationCitation(title: legacy.trim(), legacy: true),
            onRemove: onLegacyRemoved,
          ),
        OutlinedButton.icon(
          onPressed: full ? null : () => _add(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar publicação citada'),
        ),
        if (full)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Limite de $maxPublicationCitations publicações citadas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Assunto: tema livre com sugestões (tópicos das citadas, depois temas).
/// Texto livre é sempre válido.
class SubjectSuggestField extends StatelessWidget {
  const SubjectSuggestField({
    required this.initialValue,
    required this.suggestions,
    required this.onChanged,
    super.key,
  });

  final String initialValue;
  final List<String> Function(String term) suggestions;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Autocomplete<String>(
    initialValue: TextEditingValue(text: initialValue),
    optionsBuilder: (text) => suggestions(text.text).take(12),
    onSelected: onChanged,
    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          decoration: const InputDecoration(
            labelText: 'Assunto',
            hintText: 'Tema livre (ex.: depressão) ou escolha uma sugestão',
            border: OutlineInputBorder(),
          ),
        ),
  );
}

/// Folha em dois passos: (1) escolher a publicação; (2) escolher o assunto
/// interno (ou só a publicação). Devolve a citação montada.
Future<PublicationCitation?> showPublicationPicker(
  BuildContext context,
  Future<PublicationCatalog> catalog,
) => showModalBottomSheet<PublicationCitation>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => PublicationPickerSheet(catalog: catalog),
);

class PublicationPickerSheet extends StatefulWidget {
  const PublicationPickerSheet({required this.catalog, super.key});

  final Future<PublicationCatalog> catalog;

  @override
  State<PublicationPickerSheet> createState() => _PublicationPickerSheetState();
}

class _PublicationPickerSheetState extends State<PublicationPickerSheet> {
  final _search = TextEditingController();
  final _topicSearch = TextEditingController();
  PublicationEntry? _selected;
  TopicEntry? _topic;

  @override
  void dispose() {
    _search.dispose();
    _topicSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      // A folha não sobe sozinha com o teclado: o inset vira padding e a
      // lista encolhe, mantendo o campo de busca visível.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.9,
        child: _selected == null ? _stepPublication() : _stepTopic(_selected!),
      ),
    );
  }

  Widget _title(String text, {VoidCallback? onBack}) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
    child: Row(
      children: [
        if (onBack != null)
          IconButton(
            tooltip: 'Voltar',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          )
        else
          const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Fechar',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _searchField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: TextField(
      key: key,
      controller: controller,
      onChanged: (_) => setState(() {}),
      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.search_rounded),
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _stepPublication() => Column(
    children: [
      _title('Adicionar publicação citada'),
      _searchField(
        key: const ValueKey('citation-search'),
        controller: _search,
        label: 'Buscar publicação',
      ),
      Expanded(
        child: FutureBuilder<PublicationCatalog>(
          future: widget.catalog,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final found = CitationRules.filterPublications(
              snapshot.data ?? const PublicationCatalog(),
              _search.text,
            );
            if (found.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhuma publicação encontrada.'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: found.length,
              itemBuilder: (context, index) {
                final entry = found[index];
                return _PublicationTile(
                  entry: entry,
                  onTap: () => setState(() {
                    _selected = entry;
                    _topic = null;
                    _topicSearch.clear();
                  }),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  Widget _stepTopic(PublicationEntry entry) {
    final topics = CitationRules.filterTopics(entry, _topicSearch.text);

    return Column(
      children: [
        _title(
          'Assunto interno',
          onBack: () => setState(() {
            _selected = null;
            _topic = null;
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              CitationCover(url: entry.cover),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (entry.topics.isNotEmpty)
          _searchField(
            key: const ValueKey('citation-topic-search'),
            controller: _topicSearch,
            label: 'Filtrar assuntos',
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: topics.length + 1,
            itemBuilder: (context, index) {
              final topic = index == 0 ? null : topics[index - 1];
              final selected = identical(_topic, topic);
              return ListTile(
                onTap: () => setState(() => _topic = topic),
                selected: selected,
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                title: Text(
                  topic?.title ?? 'Só a publicação (sem assunto interno)',
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, entry.cite(_topic)),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Adicionar'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PublicationTile extends StatelessWidget {
  const _PublicationTile({required this.entry, required this.onTap});

  final PublicationEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          CitationCover(url: entry.cover, width: 48, height: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (entry.type.isNotEmpty)
                      Text(
                        entry.type,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (entry.isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Novo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}
