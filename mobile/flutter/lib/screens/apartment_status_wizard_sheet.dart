import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mobile_api.dart';
import '../models/apartment_status_wizard.dart';
import '../models/mobile_models.dart';
import '../models/publication_citation.dart';
import 'publication_citations_widgets.dart';

class ApartmentStatusWizardSheet extends StatefulWidget {
  const ApartmentStatusWizardSheet({
    required this.detail,
    required this.apartment,
    required this.onSave,
    required this.loadHistory,
    super.key,
    this.today,
    this.loadCatalog,
    this.generateQr,
    this.shareQr,
  });

  final CondominiumDetail detail;
  final ApartmentLetter apartment;
  final Future<String?> Function(Map<String, Object?> payload) onSave;
  final Future<List<ApartmentDeliveryHistoryEntry>> Function() loadHistory;
  final DateTime Function()? today;

  /// Catálogo v2 de publicações; sem ele (ou se falhar), usa o catálogo
  /// antigo vindo no detalhe do condomínio.
  final Future<PublicationCatalog> Function()? loadCatalog;

  /// Gera o PDF de QR no servidor; sem ele o botão "Gerar QR" não aparece.
  final Future<Uint8List> Function(QrOption option)? generateQr;

  /// Abre o compartilhamento nativo com o PDF gerado.
  final Future<void> Function(Uint8List bytes, QrOption option)? shareQr;

  @override
  State<ApartmentStatusWizardSheet> createState() =>
      _ApartmentStatusWizardSheetState();
}

class _ApartmentStatusWizardSheetState
    extends State<ApartmentStatusWizardSheet> {
  late ApartmentLetter _apartment;
  late final Future<List<ApartmentDeliveryHistoryEntry>> _history;
  bool _isSaving = false;
  bool _deliveredBoxGuard = false;
  bool _deliveredDoormanMail = false;
  late final Future<PublicationCatalog> _catalog;
  late PublicationCatalog _catalogData;
  List<PublicationCitation> _citations = const [];
  bool _citationsTouched = false;

  /// Texto antigo de `publication` (registro sem citações).
  String _publication = '';
  String _subject = '';
  String _writtenBy = '';
  String _envelopedBy = '';
  String _deliveredBy = '';

  ApartmentStatusWorkflow get _workflow => widget.detail.workflow;
  ApartmentWizardStep get _step => _workflow.stepFor(_apartment.status);
  bool get _canDeliver => widget.detail.isManager || widget.detail.isDeliverer;

  @override
  void initState() {
    super.initState();
    _apartment = widget.apartment;
    _history = widget.loadHistory();
    _catalogData = PublicationCatalog.fromLegacy(widget.detail.publications);
    _catalog = _fetchCatalog();
    _catalog.then((catalog) {
      if (mounted) setState(() => _catalogData = catalog);
    });
    _loadFieldsFromApartment();
  }

  Future<PublicationCatalog> _fetchCatalog() async {
    final fallback = _catalogData;
    try {
      return await (widget.loadCatalog?.call() ?? Future.value(fallback));
    } on Object {
      return fallback;
    }
  }

  void _loadFieldsFromApartment() {
    _citations = _apartment.citations;
    _citationsTouched = false;
    _publication = _citations.isEmpty ? _apartment.publication ?? '' : '';
    _subject = _apartment.subject ?? '';
    _writtenBy = _apartment.writtenBy ?? widget.detail.publisherName;
    _envelopedBy = _apartment.envelopedBy ?? widget.detail.publisherName;
    _deliveredBy = _apartment.deliveredBy ?? widget.detail.publisherName;
    _deliveredBoxGuard = _apartment.deliveredBoxGuard;
    _deliveredDoormanMail = _apartment.deliveredDoormanMail;
  }

  Future<void> _save(ApartmentWizardAction action) async {
    final payload = _workflow.buildPayload(
      action: action,
      apartmentNumber: _apartment.apartmentNumberValue,
      currentStatus: _apartment.status,
      currentFields: _apartment.statusFields,
      today: widget.today?.call() ?? DateTime.now(),
      publisherName: widget.detail.publisherName,
      publication: _publication,
      subject: _subject,
      citations: _citationsTouched || _apartment.citations.isNotEmpty
          ? _citations
          : null,
      writtenBy: _writtenBy,
      envelopedBy: _envelopedBy,
      deliveredBy: _deliveredBy,
      deliveredBoxGuard: _deliveredBoxGuard,
      deliveredDoormanMail: _deliveredDoormanMail,
      canDeliver: _canDeliver,
    );
    if (payload == null) return;

    await _persist(payload);
  }

  Future<void> _persist(Map<String, Object?> payload) async {
    setState(() => _isSaving = true);
    final error = await widget.onSave(payload);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() {
      _apartment = _apartment.withStatusFields(payload, widget.detail.statuses);
      _loadFieldsFromApartment();
    });
  }

  Future<void> _editDetails() async {
    final fields = <String, Object?>{
      ..._apartment.statusFields,
      'status': _apartment.status,
    };
    final result = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ApartmentDetailsEditor(
        fields: fields,
        statuses: widget.detail.statuses,
        citations: _apartment.citations,
        catalog: _catalog,
      ),
    );
    if (result != null && mounted) {
      await _persist(result);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar este apartamento?'),
        content: const Text(
          'O status volta para “Não registrada” e os dados desta carta são apagados. Não dá para desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _save(ApartmentWizardAction.clear);
    }
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.86,
    minChildSize: 0.58,
    maxChildSize: 0.97,
    expand: false,
    builder: (context, scrollController) => Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _apartment.isAvulso
                        ? _apartment.apartmentNumber
                        : 'Apto ${_apartment.apartmentNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StepBadge(step: _step, color: _apartment.statusColor),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                ..._stepContents,
                const SizedBox(height: 18),
                _historyContents,
              ],
            ),
          ),
          _actions,
        ],
      ),
    ),
  );

  List<Widget> get _stepContents {
    switch (_step) {
      case ApartmentWizardStep.write:
        return [
          const _StepHint(
            text: 'Registre as publicações citadas e o assunto da carta. A data de hoje será usada como data de escrita.',
          ),
          const SizedBox(height: 14),
          CitedPublicationsEditor(
            citations: _citations,
            legacy: _publication,
            catalog: _catalog,
            onChanged: (value) => setState(() {
              _citations = value;
              _citationsTouched = true;
            }),
            onLegacyRemoved: () => setState(() => _publication = ''),
          ),
          const SizedBox(height: 12),
          SubjectSuggestField(
            initialValue: _subject,
            suggestions: (term) => CitationRules.subjectSuggestions(
              _catalogData.themes,
              _citations,
              term,
            ),
            onChanged: (value) => setState(() => _subject = value),
          ),
          _qrButton(
            citations: _citations,
            legacy: _publication,
            subject: _subject,
          ),
          const SizedBox(height: 12),
          _personSelector(
            label: 'Quem escreveu',
            value: _writtenBy,
            onChanged: (value) => setState(() => _writtenBy = value),
          ),
        ];
      case ApartmentWizardStep.envelope:
        return [
          const _StepHint(
            text: 'Confira o endereço antes de fechar o envelope.',
          ),
          const SizedBox(height: 12),
          _addressCard,
          if (_apartment.writtenBy?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _MetadataBadge(
              icon: Icons.edit_outlined,
              text: 'Escrita por ${_apartment.writtenBy}',
            ),
          ],
          ..._letterContentBadges,
          const SizedBox(height: 16),
          _personSelector(
            label: 'Quem envelopou',
            value: _envelopedBy,
            onChanged: (value) => setState(() => _envelopedBy = value),
          ),
        ];
      case ApartmentWizardStep.deliver:
        return [
          _addressCard,
          ..._letterContentBadges,
          const SizedBox(height: 16),
          if (_canDeliver) ...[
            const _StepHint(text: 'Como a carta foi entregue?'),
            const SizedBox(height: 8),
            _DeliveryMethodTile(
              title: 'Caixa ou vigia',
              value: _deliveredBoxGuard,
              onChanged: (value) => setState(() => _deliveredBoxGuard = value),
            ),
            _DeliveryMethodTile(
              title: 'Porteiro ou correio',
              value: _deliveredDoormanMail,
              onChanged: (value) =>
                  setState(() => _deliveredDoormanMail = value),
            ),
            const SizedBox(height: 12),
            _personSelector(
              label: 'Quem entregou',
              value: _deliveredBy,
              onChanged: (value) => setState(() => _deliveredBy = value),
            ),
          ] else
            const _CompletionCard(
              icon: Icons.mark_email_read_outlined,
              text: 'Carta envelopada e pronta para entrega.',
            ),
        ];
      case ApartmentWizardStep.complete:
        return [
          const _CompletionCard(
            icon: Icons.check_circle_outline_rounded,
            text: 'Entregue. Obrigado!',
          ),
          ..._letterContentBadges,
        ];
    }
  }

  /// Publicação e assunto já registrados, para o publicador reler depois de
  /// avançar de etapa.
  List<Widget> get _letterContentBadges {
    final legacy = _apartment.publication?.trim() ?? '';
    final subject = _apartment.subject?.trim() ?? '';
    final hasPublications =
        _apartment.citations.isNotEmpty || legacy.isNotEmpty;

    return [
      if (hasPublications) ...[
        const SizedBox(height: 8),
        CitationReadingList(citations: _apartment.citations, legacy: legacy),
      ],
      if (subject.isNotEmpty) ...[
        const SizedBox(height: 8),
        _MetadataBadge(
          icon: Icons.lightbulb_outline_rounded,
          text: 'Assunto: $subject',
        ),
      ],
      _qrButton(
        citations: _apartment.citations,
        legacy: legacy,
        subject: subject,
      ),
    ];
  }

  /// Botão "Gerar QR": some quando nenhuma publicação tem link.
  Widget _qrButton({
    required List<PublicationCitation> citations,
    required String legacy,
    required String subject,
  }) {
    final generate = widget.generateQr;
    final share = widget.shareQr;
    if (generate == null || share == null) return const SizedBox.shrink();
    final options = CitationRules.qrOptions(
      citations: citations,
      legacy: legacy,
      freeSubject: subject,
      catalog: _catalogData,
    );
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _GenerateQrButton(
        options: options,
        generate: generate,
        share: share,
      ),
    );
  }

  Widget get _addressCard {
    final lines = <String>[
      widget.detail.name,
      widget.detail.address,
      if (_apartment.locationLabel.isNotEmpty) _apartment.locationLabel,
      _apartment.isAvulso
          ? _apartment.apartmentNumberValue
          : 'Apto ${_apartment.apartmentNumberValue}',
    ].where((line) => line.trim().isNotEmpty).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.markunread_mailbox_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lines.join('\n'),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.45, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget get _historyContents => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Histórico cumulativo',
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      FutureBuilder<List<ApartmentDeliveryHistoryEntry>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return const _MetadataBadge(
              icon: Icons.info_outline_rounded,
              text: 'Histórico temporariamente indisponível.',
            );
          }
          if (snapshot.data?.isNotEmpty != true) {
            return const Text('Nenhuma entrega anterior registrada.');
          }

          return Column(
            children: snapshot.data!
                .map((entry) => _HistoryCard(entry: entry))
                .toList(growable: false),
          );
        },
      ),
    ],
  );

  Widget get _actions {
    final primaryAction = switch (_step) {
      ApartmentWizardStep.write => ApartmentWizardAction.write,
      ApartmentWizardStep.envelope => ApartmentWizardAction.envelope,
      ApartmentWizardStep.deliver =>
        _canDeliver ? ApartmentWizardAction.deliver : null,
      ApartmentWizardStep.complete => null,
    };
    final primaryLabel = switch (_step) {
      ApartmentWizardStep.write => 'Marcar como escrita',
      ApartmentWizardStep.envelope => 'Envelopar',
      ApartmentWizardStep.deliver => 'Marcar como entregue',
      ApartmentWizardStep.complete => '',
    };
    final canCorrect = _workflow.previousStatus(_apartment.status) != null;
    final canClear = _apartment.status != _workflow.emptyStatus;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (primaryAction != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : () => _save(primaryAction),
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_isSaving ? 'Salvando…' : primaryLabel),
                ),
              ),
            if (primaryAction == null &&
                _step == ApartmentWizardStep.write &&
                _workflow.writtenStatus == null)
              const Text(
                'O fluxo de escrita não está configurado nesta campanha.',
              ),
            if (primaryAction == null &&
                _step == ApartmentWizardStep.envelope &&
                _workflow.envelopedStatus == null)
              const Text(
                'O status de envelope não está configurado nesta campanha.',
              ),
            if (primaryAction == null &&
                _step == ApartmentWizardStep.deliver &&
                _canDeliver &&
                _workflow.deliveredStatus == null)
              const Text(
                'O status de entrega não está configurado nesta campanha.',
              ),
            if (canCorrect || canClear || widget.detail.isManager) ...[
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  if (canCorrect)
                    TextButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _save(ApartmentWizardAction.correct),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Corrigir'),
                    ),
                  if (canClear)
                    TextButton.icon(
                      onPressed: _isSaving ? null : _clear,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Limpar'),
                    ),
                  if (widget.detail.isManager)
                    TextButton.icon(
                      onPressed: _isSaving ? null : _editDetails,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Detalhes / editar'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _personSelector({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final names = <String>{
      if (value.trim().isNotEmpty) value.trim(),
      if (widget.detail.publisherName.trim().isNotEmpty)
        widget.detail.publisherName.trim(),
      ...widget.detail.congregationPeople.map((name) => name.trim()),
    }.toList(growable: false);
    if (names.isEmpty) {
      return TextFormField(
        initialValue: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
    }

    final selected = names.contains(value) ? value : names.first;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: names
          .map(
            (name) => DropdownMenuItem<String>(
              value: name,
              child: Text(
                name == widget.detail.publisherName ? '$name (você)' : name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (name) {
        if (name != null) onChanged(name);
      },
    );
  }
}

class _GenerateQrButton extends StatefulWidget {
  const _GenerateQrButton({
    required this.options,
    required this.generate,
    required this.share,
  });

  final List<QrOption> options;
  final Future<Uint8List> Function(QrOption option) generate;
  final Future<void> Function(Uint8List bytes, QrOption option) share;

  @override
  State<_GenerateQrButton> createState() => _GenerateQrButtonState();
}

class _GenerateQrButtonState extends State<_GenerateQrButton> {
  bool _busy = false;

  Future<QrOption?> _choose() async {
    if (widget.options.length == 1) return widget.options.first;
    return showModalBottomSheet<QrOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Qual publicação no QR?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final option in widget.options)
              ListTile(
                leading: const Icon(Icons.qr_code_2_rounded),
                title: Text(option.label),
                subtitle: option.subject.isEmpty ? null : Text(option.subject),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _run() async {
    final option = await _choose();
    if (option == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await widget.generate(option);
      if (!mounted) return;
      await widget.share(bytes, option);
    } on PlatformException catch (error) {
      _fail(
        error.message == null
            ? 'O iPhone não conseguiu abrir o compartilhamento do arquivo.'
            : 'O iPhone não conseguiu compartilhar: ${error.message}',
      );
    } on MissingPluginException {
      _fail(
        'O compartilhamento não está disponível nesta instalação. Atualize o aplicativo.',
      );
    } on Object catch (error) {
      _fail(
        error is StateError
            ? error.message.toString()
            : MobileApi.messageForError(error),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.qr_code_2_rounded),
      label: Text(_busy ? 'Gerando QR…' : 'Gerar QR'),
    ),
  );
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step, required this.color});

  final ApartmentWizardStep step;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (step) {
      ApartmentWizardStep.write => ('Passo 1 · Escrever', Icons.edit_outlined),
      ApartmentWizardStep.envelope => (
        'Passo 2 · Envelopar',
        Icons.markunread_mailbox_outlined,
      ),
      ApartmentWizardStep.deliver => (
        'Passo 3 · Entregar',
        Icons.outgoing_mail,
      ),
      ApartmentWizardStep.complete => (
        'Concluída',
        Icons.check_circle_outline_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StepHint extends StatelessWidget {
  const _StepHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
  );
}

class _MetadataBadge extends StatelessWidget {
  const _MetadataBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 8),
        Flexible(child: Text(text)),
      ],
    ),
  );
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _DeliveryMethodTile extends StatelessWidget {
  const _DeliveryMethodTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: value,
    onChanged: (checked) => onChanged(checked ?? false),
    controlAffinity: ListTileControlAffinity.leading,
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final ApartmentDeliveryHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final deliveryMethods = [
      if (entry.deliveredBoxGuard) 'Caixa/Vigia',
      if (entry.deliveredDoormanMail) 'Porteiro/Correio',
    ];
    final scheme = Theme.of(context).colorScheme;
    final statusLabel = entry.statusLabel?.trim() ?? '';
    final inProgressLabel = statusLabel.isEmpty
        ? 'Em andamento'
        : 'Em andamento · $statusLabel';
    final lines = [
      if (entry.writtenBy?.isNotEmpty == true) entry.writtenBy!,
      if (!entry.inProgress && entry.writtenAt?.isNotEmpty == true)
        'Entregue em ${entry.writtenAt}',
      if (entry.letterWrittenAt?.isNotEmpty == true)
        'Escrita em ${entry.letterWrittenAt}',
      if (entry.citations.isEmpty && entry.publication?.isNotEmpty == true)
        'Publicação: ${entry.publication}',
      if (entry.subject?.isNotEmpty == true) 'Assunto: ${entry.subject}',
      if (entry.observation?.isNotEmpty == true)
        'Observação: ${entry.observation}',
      if (deliveryMethods.isNotEmpty) 'Via: ${deliveryMethods.join(' · ')}',
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: entry.isCurrentCampaign
            ? Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: 0.45)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.campaign,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (entry.inProgress) ...[
            const SizedBox(height: 5),
            Text(
              inProgressLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              lines.join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (entry.citations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final citation in entry.citations)
                  CitationChip(citation: citation, mini: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ApartmentDetailsEditor extends StatefulWidget {
  const _ApartmentDetailsEditor({
    required this.fields,
    required this.statuses,
    required this.citations,
    required this.catalog,
  });

  final Map<String, Object?> fields;
  final List<LetterStatusOption> statuses;
  final List<PublicationCitation> citations;
  final Future<PublicationCatalog> catalog;

  @override
  State<_ApartmentDetailsEditor> createState() =>
      _ApartmentDetailsEditorState();
}

class _ApartmentDetailsEditorState extends State<_ApartmentDetailsEditor> {
  late final Map<String, Object?> _fields;
  late List<PublicationCitation> _citations;
  String _legacy = '';
  bool _citationsTouched = false;
  List<String> _themes = const [];

  @override
  void initState() {
    super.initState();
    _fields = Map<String, Object?>.from(widget.fields);
    _citations = widget.citations;
    _legacy = _citations.isEmpty
        ? _fields['publication']?.toString() ?? ''
        : '';
    widget.catalog
        .then((catalog) {
          if (mounted) setState(() => _themes = catalog.themes);
        })
        .catchError((Object _) {});
  }

  Map<String, Object?> _result() => {
    ..._fields,
    'publication': CitationRules.publicationLabel(_citations, _legacy),
    if (_citationsTouched || widget.citations.isNotEmpty)
      'citacoes': [for (final c in _citations) c.toJson()],
  };

  @override
  Widget build(BuildContext context) {
    final statusValues = widget.statuses.map((status) => status.slug).toSet();
    final selectedStatus = statusValues.contains(_fields['status'])
        ? _fields['status'] as String
        : widget.statuses.firstOrNull?.slug;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalhes da carta',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  if (widget.statuses.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.statuses
                          .map(
                            (status) => DropdownMenuItem(
                              value: status.slug,
                              child: Text(status.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) => _fields['status'] = value,
                    ),
                  const SizedBox(height: 10),
                  _textField('Quem escreveu', 'written_by'),
                  _textField('Quem envelopou', 'enveloped_by'),
                  _textField('Quem entregou', 'delivered_by'),
                  _textField('Data escrita (AAAA-MM-DD)', 'letter_written_at'),
                  _textField('Data entregue (AAAA-MM-DD)', 'last_sent_at'),
                  CitedPublicationsEditor(
                    citations: _citations,
                    legacy: _legacy,
                    catalog: widget.catalog,
                    onChanged: (value) => setState(() {
                      _citations = value;
                      _citationsTouched = true;
                    }),
                    onLegacyRemoved: () => setState(() => _legacy = ''),
                  ),
                  const SizedBox(height: 12),
                  SubjectSuggestField(
                    initialValue: _fields['subject']?.toString() ?? '',
                    suggestions: (term) => CitationRules.subjectSuggestions(
                      _themes,
                      _citations,
                      term,
                    ),
                    onChanged: (value) => _fields['subject'] =
                        value.trim().isEmpty ? null : value,
                  ),
                  const SizedBox(height: 10),
                  _textField('Observação', 'observacao', maxLines: 3),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Caixa ou vigia'),
                    value: _fields['delivered_box_guard'] == true,
                    onChanged: (value) => setState(
                      () => _fields['delivered_box_guard'] = value ?? false,
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Porteiro ou correio'),
                    value: _fields['delivered_doorman_mail'] == true,
                    onChanged: (value) => setState(
                      () => _fields['delivered_doorman_mail'] = value ?? false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _result()),
                    child: const Text('Salvar detalhes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(String label, String key, {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      initialValue: _fields[key]?.toString() ?? '',
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) => _fields[key] = value.trim().isEmpty ? null : value,
    ),
  );
}
