import 'package:flutter/material.dart';

import '../models/apartment_status_wizard.dart';
import '../models/mobile_models.dart';

class ApartmentStatusWizardSheet extends StatefulWidget {
  const ApartmentStatusWizardSheet({
    required this.detail,
    required this.apartment,
    required this.onSave,
    required this.loadHistory,
    super.key,
    this.today,
  });

  final CondominiumDetail detail;
  final ApartmentLetter apartment;
  final Future<String?> Function(Map<String, Object?> payload) onSave;
  final Future<List<ApartmentDeliveryHistoryEntry>> Function() loadHistory;
  final DateTime Function()? today;

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
    _loadFieldsFromApartment();
  }

  void _loadFieldsFromApartment() {
    _publication = _apartment.publication ?? '';
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
            text: 'Registre a publicação e o assunto da carta. A data de hoje será usada como data de escrita.',
          ),
          const SizedBox(height: 14),
          _suggestedTextField(
            label: 'Publicação',
            value: _publication,
            options: _publicationOptions,
            onChanged: (value) => setState(() => _publication = value),
            onSelected: (value) => setState(() => _publication = value),
          ),
          const SizedBox(height: 12),
          _suggestedTextField(
            label: 'Assunto',
            value: _subject,
            options: _topicOptions,
            onChanged: (value) => setState(() => _subject = value),
            onSelected: (value) => setState(() => _subject = value),
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
        return const [
          _CompletionCard(
            icon: Icons.check_circle_outline_rounded,
            text: 'Entregue. Obrigado!',
          ),
        ];
    }
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

  Widget _suggestedTextField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onSelected,
  }) => Autocomplete<String>(
    initialValue: TextEditingValue(text: value),
    optionsBuilder: (text) {
      final query = text.text.trim().toLowerCase();
      if (query.isEmpty) return options.take(8);
      return options
          .where((option) => option.toLowerCase().contains(query))
          .take(8);
    },
    onSelected: onSelected,
    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Escolha uma sugestão ou digite',
            border: const OutlineInputBorder(),
            suffixIcon: options.isEmpty
                ? null
                : const Icon(Icons.arrow_drop_down_rounded),
          ),
        ),
  );

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

  List<String> get _publicationOptions => widget.detail.publications
      .map((publication) => publication.label)
      .toList(growable: false);

  List<String> get _topicOptions {
    final selected = widget.detail.publications.where((publication) {
      final query = _publication.trim().toLowerCase();
      return query.isNotEmpty &&
          (publication.label.toLowerCase() == query ||
              publication.title.toLowerCase() == query ||
              (publication.code.isNotEmpty &&
                  query.startsWith('${publication.code.toLowerCase()} ')));
    });
    return selected.isEmpty ? const [] : selected.first.topics;
  }
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
    final lines = [
      if (entry.writtenBy?.isNotEmpty == true) entry.writtenBy!,
      if (entry.writtenAt?.isNotEmpty == true) 'Entregue em ${entry.writtenAt}',
      if (entry.letterWrittenAt?.isNotEmpty == true)
        'Escrita em ${entry.letterWrittenAt}',
      if (entry.publication?.isNotEmpty == true)
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
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              lines.join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ApartmentDetailsEditor extends StatefulWidget {
  const _ApartmentDetailsEditor({required this.fields, required this.statuses});

  final Map<String, Object?> fields;
  final List<LetterStatusOption> statuses;

  @override
  State<_ApartmentDetailsEditor> createState() =>
      _ApartmentDetailsEditorState();
}

class _ApartmentDetailsEditorState extends State<_ApartmentDetailsEditor> {
  late final Map<String, Object?> _fields;

  @override
  void initState() {
    super.initState();
    _fields = Map<String, Object?>.from(widget.fields);
  }

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
                  _textField('Publicação', 'publication'),
                  _textField('Assunto', 'subject'),
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
                    onPressed: () => Navigator.pop(context, _fields),
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
