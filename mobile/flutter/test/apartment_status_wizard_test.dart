import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartas/models/apartment_status_wizard.dart';
import 'package:cartas/models/mobile_models.dart';
import 'package:cartas/screens/apartment_status_wizard_sheet.dart';

void main() {
  final workflow = ApartmentStatusWorkflow(
    emptyStatus: 'no',
    writtenStatus: 'pending',
    envelopedStatus: 'envelopada',
    deliveredStatus: 'ok',
    statusCountsAsDelivered: const {'ok': true, 'custom_done': true},
  );
  final today = DateTime(2026, 10, 17);

  group('Apartment status wizard stages', () {
    test('maps each PWA status to its guided step', () {
      expect(workflow.stepFor('no'), ApartmentWizardStep.write);
      expect(workflow.stepFor('pending'), ApartmentWizardStep.envelope);
      expect(workflow.stepFor('envelopada'), ApartmentWizardStep.deliver);
      expect(workflow.stepFor('ok'), ApartmentWizardStep.complete);
    });

    test('unknown statuses follow the PWA delivered/fallback rule', () {
      expect(workflow.stepFor('custom_done'), ApartmentWizardStep.complete);
      expect(workflow.stepFor('custom_pending'), ApartmentWizardStep.write);
    });

    test('correct moves back one available stage, skipping missing steps', () {
      expect(workflow.previousStatus('ok'), 'envelopada');
      expect(workflow.previousStatus('envelopada'), 'pending');
      expect(workflow.previousStatus('pending'), 'no');
      expect(workflow.previousStatus('no'), isNull);

      const workflowWithoutEnvelope = ApartmentStatusWorkflow(
        emptyStatus: 'no',
        writtenStatus: 'pending',
        envelopedStatus: null,
        deliveredStatus: 'ok',
      );
      expect(workflowWithoutEnvelope.previousStatus('ok'), 'pending');
      expect(workflowWithoutEnvelope.previousStatus('pending'), 'no');
    });
  });

  test('parses wizard permissions, publication topics and letter metadata', () {
    final detail = CondominiumDetail.fromJson({
      'condominium': {'id': 5, 'name': 'Condomínio Teste'},
      'is_manager': false,
      'is_deliverer': true,
      'publisher_name': 'Ana',
      'congregation_people': ['Ana', 'Bia'],
      'status_flow': {
        'empty': 'no',
        'written': 'pending',
        'enveloped': 'envelopada',
        'delivered': 'ok',
      },
      'letter_statuses': [
        {
          'slug': 'pending',
          'label': 'Escrita',
          'color': '#eab308',
          'counts_as_delivered': false,
        },
        {
          'slug': 'ok',
          'label': 'Entregue',
          'color': '#22c55e',
          'counts_as_delivered': true,
        },
      ],
      'publications': [
        {
          'codigo': 'lmd',
          'titulo': 'Ame as Pessoas',
          'topicos': ['Bondade', 'Empatia'],
        },
      ],
      'apartments': [
        {
          'id': 12,
          'apartment_number': '301',
          'apartment_number_value': '301',
          'status': 'pending',
          'status_label': 'Escrita',
          'status_color': '#eab308',
          'written_by': 'Bia',
          'enveloped_by': 'Ana',
          'letter_written_at': '2026-10-15',
          'publication': 'Ame as Pessoas',
          'subject': 'Bondade',
          'observacao': 'Voltar depois',
          'delivered_box_guard': true,
        },
      ],
    });

    expect(detail.isDeliverer, isTrue);
    expect(detail.isManager, isFalse);
    expect(detail.publisherName, 'Ana');
    expect(detail.congregationPeople, ['Ana', 'Bia']);
    expect(detail.publications.single.label, 'lmd — Ame as Pessoas');
    expect(detail.publications.single.topics, ['Bondade', 'Empatia']);
    expect(detail.apartments.single.statusFields['written_by'], 'Bia');
    expect(
      detail.apartments.single.statusFields['observacao'],
      'Voltar depois',
    );
    expect(detail.apartments.single.deliveredBoxGuard, isTrue);
  });

  group('Apartment status wizard payloads', () {
    test(
      'writing sets today and selected publication while preserving metadata',
      () {
        final payload = workflow.buildPayload(
          action: ApartmentWizardAction.write,
          apartmentNumber: '301',
          currentStatus: 'no',
          currentFields: const {
            'observacao': 'Voltar depois das 18h',
            'delivered_doorman_mail': true,
          },
          today: today,
          publisherName: 'Ana',
          publication: '  Seja Feliz  ',
          subject: '  Esperança  ',
          writtenBy: 'Bia',
        );

        expect(payload, containsPair('status', 'pending'));
        expect(payload, containsPair('letter_written_at', '2026-10-17'));
        expect(payload, containsPair('publication', 'Seja Feliz'));
        expect(payload, containsPair('subject', 'Esperança'));
        expect(payload, containsPair('written_by', 'Bia'));
        expect(payload, containsPair('observacao', 'Voltar depois das 18h'));
        expect(payload, containsPair('delivered_doorman_mail', true));
      },
    );

    test('enveloping changes only the envelope status and actor', () {
      final payload = workflow.buildPayload(
        action: ApartmentWizardAction.envelope,
        apartmentNumber: '301',
        currentStatus: 'pending',
        currentFields: const {
          'written_by': 'Ana',
          'letter_written_at': '2026-10-15',
          'publication': 'Seja Feliz',
          'subject': 'Esperança',
        },
        today: today,
        publisherName: 'Bia',
        envelopedBy: 'Carlos',
      );

      expect(payload, containsPair('status', 'envelopada'));
      expect(payload, containsPair('written_by', 'Ana'));
      expect(payload, containsPair('enveloped_by', 'Carlos'));
      expect(payload, containsPair('publication', 'Seja Feliz'));
      expect(payload, containsPair('letter_written_at', '2026-10-15'));
    });

    test(
      'delivery requires permission and keeps an existing delivery date',
      () {
        final deniedPayload = workflow.buildPayload(
          action: ApartmentWizardAction.deliver,
          apartmentNumber: '301',
          currentStatus: 'envelopada',
          currentFields: const {},
          today: today,
        );
        expect(deniedPayload, isNull);

        final payload = workflow.buildPayload(
          action: ApartmentWizardAction.deliver,
          apartmentNumber: '301',
          currentStatus: 'envelopada',
          currentFields: const {
            'written_by': 'Ana',
            'enveloped_by': 'Bia',
            'last_sent_at': '2026-10-12',
            'publication': 'Seja Feliz',
          },
          today: today,
          deliveredBy: 'Carlos',
          deliveredBoxGuard: true,
          canDeliver: true,
        );

        expect(payload, containsPair('status', 'ok'));
        expect(payload, containsPair('last_sent_at', '2026-10-12'));
        expect(payload, containsPair('delivered_by', 'Carlos'));
        expect(payload, containsPair('delivered_box_guard', true));
        expect(payload, containsPair('written_by', 'Ana'));
        expect(payload, containsPair('enveloped_by', 'Bia'));
      },
    );

    test('correct preserves all recorded letter details', () {
      final payload = workflow.buildPayload(
        action: ApartmentWizardAction.correct,
        apartmentNumber: '301',
        currentStatus: 'envelopada',
        currentFields: const {
          'written_by': 'Ana',
          'enveloped_by': 'Bia',
          'publication': 'Seja Feliz',
          'subject': 'Esperança',
        },
        today: today,
      );

      expect(payload, containsPair('status', 'pending'));
      expect(payload, containsPair('written_by', 'Ana'));
      expect(payload, containsPair('enveloped_by', 'Bia'));
      expect(payload, containsPair('publication', 'Seja Feliz'));
      expect(payload, containsPair('subject', 'Esperança'));
    });

    test('clear resets status, dates, people, delivery methods and text', () {
      final payload = workflow.buildPayload(
        action: ApartmentWizardAction.clear,
        apartmentNumber: '301',
        currentStatus: 'ok',
        currentFields: const {
          'written_by': 'Ana',
          'enveloped_by': 'Bia',
          'delivered_by': 'Carlos',
          'last_sent_at': '2026-10-12',
          'letter_written_at': '2026-10-10',
          'publication': 'Seja Feliz',
          'subject': 'Esperança',
          'observacao': 'Retornar depois',
          'delivered_box_guard': true,
          'delivered_doorman_mail': true,
        },
        today: today,
      );

      expect(payload, containsPair('status', 'no'));
      expect(payload, containsPair('limpar', true));
      expect(payload, containsPair('written_by', ''));
      expect(payload, containsPair('enveloped_by', ''));
      expect(payload, containsPair('delivered_by', ''));
      expect(payload, containsPair('letter_written_at', isNull));
      expect(payload, containsPair('last_sent_at', isNull));
      expect(payload, containsPair('publication', isNull));
      expect(payload, containsPair('subject', isNull));
      expect(payload, containsPair('observacao', isNull));
      expect(payload, containsPair('delivered_box_guard', false));
      expect(payload, containsPair('delivered_doorman_mail', false));
    });
  });

  testWidgets('the write action saves and advances to the envelope step', (
    tester,
  ) async {
    final savedPayloads = <Map<String, Object?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApartmentStatusWizardSheet(
            detail: _detail(),
            apartment: _apartment(),
            today: () => today,
            loadHistory: () async => const [],
            onSave: (payload) async {
              savedPayloads.add(payload);
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Passo 1 · Escrever'), findsOneWidget);
    expect(find.text('Publicações citadas (0/5)'), findsOneWidget);
    expect(find.text('Adicionar publicação citada'), findsOneWidget);
    expect(find.text('Assunto'), findsOneWidget);
    expect(find.text('Quem escreveu'), findsOneWidget);
    expect(find.text('Vazio'), findsNothing);
    expect(find.text('Entregue'), findsNothing);
    await tester.tap(find.text('Marcar como escrita'));
    await tester.pumpAndSettle();

    expect(savedPayloads, hasLength(1));
    expect(savedPayloads.single['status'], 'pending');
    expect(savedPayloads.single['letter_written_at'], '2026-10-17');
    expect(find.text('Passo 2 · Envelopar'), findsOneWidget);
    expect(
      find.text('Confira o endereço antes de fechar o envelope.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a non-deliverer sees the ready-for-delivery step without an action',
    (tester) async {
      final detail = _detail(isManager: false, isDeliverer: false);
      final apartment = _apartment(status: 'envelopada');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApartmentStatusWizardSheet(
              detail: detail,
              apartment: apartment,
              loadHistory: () async => const [],
              onSave: (_) async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Passo 3 · Entregar'), findsOneWidget);
      expect(
        find.text('Carta envelopada e pronta para entrega.'),
        findsOneWidget,
      );
      expect(find.text('Marcar como entregue'), findsNothing);
    },
  );

  testWidgets('a manager records delivery method and completes the step', (
    tester,
  ) async {
    final savedPayloads = <Map<String, Object?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApartmentStatusWizardSheet(
            detail: _detail(),
            apartment: _apartment(status: 'envelopada'),
            today: () => today,
            loadHistory: () async => const [],
            onSave: (payload) async {
              savedPayloads.add(payload);
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Caixa ou vigia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar como entregue'));
    await tester.pumpAndSettle();

    expect(savedPayloads.single['status'], 'ok');
    expect(savedPayloads.single['delivered_box_guard'], isTrue);
    expect(savedPayloads.single['last_sent_at'], '2026-10-17');
    expect(find.text('Concluída'), findsOneWidget);
    expect(find.text('Entregue. Obrigado!'), findsOneWidget);
  });

  test('history entry parses in-progress fields and tolerates old servers', () {
    final inProgress = ApartmentDeliveryHistoryEntry.fromJson({
      'campanha': 'Campanha atual',
      'em_andamento': true,
      'status_label': 'Escrita',
      'written_at': null,
      'publication': 'Despertai',
      'subject': 'Família',
    });
    expect(inProgress.inProgress, isTrue);
    expect(inProgress.statusLabel, 'Escrita');
    expect(inProgress.writtenAt, isNull);

    final legacy = ApartmentDeliveryHistoryEntry.fromJson({
      'campanha': 'Antiga',
      'written_at': '01/09/2026',
    });
    expect(legacy.inProgress, isFalse);
    expect(legacy.statusLabel, isNull);
  });

  testWidgets('history card shows in-progress label instead of Entregue em', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApartmentStatusWizardSheet(
            detail: _detail(),
            apartment: _apartment(),
            loadHistory: () async => [
              ApartmentDeliveryHistoryEntry.fromJson({
                'campanha': 'Campanha atual',
                'em_andamento': true,
                'status_label': 'Escrita',
                'written_at': '05/11/2026',
                'subject': 'Família',
              }),
              ApartmentDeliveryHistoryEntry.fromJson({
                'campanha': 'Campanha antiga',
                'written_at': '01/09/2026',
              }),
            ],
            onSave: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Em andamento · Escrita'), findsOneWidget);
    expect(find.textContaining('Entregue em 05/11/2026'), findsNothing);
    expect(find.textContaining('Assunto: Família'), findsOneWidget);
    expect(find.textContaining('Entregue em 01/09/2026'), findsOneWidget);
  });

  testWidgets(
    'envelope step keeps the chosen publication and subject visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApartmentStatusWizardSheet(
              detail: _detail(),
              apartment: _apartment(status: 'pending'),
              loadHistory: () async => const [],
              onSave: (_) async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Assunto:'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApartmentStatusWizardSheet(
              key: const ValueKey('with-subject'),
              detail: _detail(),
              apartment: ApartmentLetter.fromJson({
                'id': 12,
                'apartment_number': '301',
                'apartment_number_value': '301',
                'status': 'pending',
                'status_label': 'Escrita',
                'status_color': '#eab308',
                'can_update': true,
                'publication': 'Despertai',
                'subject': 'Família',
              }),
              loadHistory: () async => const [],
              onSave: (_) async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Passo 2 · Envelopar'), findsOneWidget);
      expect(find.text('Despertai — antiga'), findsOneWidget);
      expect(find.text('Assunto: Família'), findsOneWidget);
    },
  );

  testWidgets('clear asks for confirmation before sending reset payload', (
    tester,
  ) async {
    final savedPayloads = <Map<String, Object?>>[];
    final apartment = ApartmentLetter.fromJson({
      'id': 12,
      'block_number': 1,
      'floor_number': 3,
      'apartment_number': '301',
      'apartment_number_value': '301',
      'status': 'pending',
      'status_label': 'Escrita',
      'status_color': '#eab308',
      'can_update': true,
      'written_by': 'Ana',
      'publication': 'Seja Feliz',
      'subject': 'Esperança',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApartmentStatusWizardSheet(
            detail: _detail(),
            apartment: apartment,
            today: () => today,
            loadHistory: () async => const [],
            onSave: (payload) async {
              savedPayloads.add(payload);
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();
    expect(savedPayloads, isEmpty);

    await tester.tap(find.text('Limpar').last);
    await tester.pumpAndSettle();
    expect(savedPayloads, hasLength(1));
    expect(savedPayloads.single['status'], 'no');
    expect(savedPayloads.single['limpar'], isTrue);
    expect(savedPayloads.single['publication'], isNull);
  });
}

CondominiumDetail _detail({bool isManager = true, bool isDeliverer = false}) =>
    CondominiumDetail.fromJson({
      'condominium': {
        'id': 5,
        'name': 'Condomínio Teste',
        'address': 'Rua das Flores',
      },
      'campaign': {'id': 8, 'name': 'Campanha atual', 'is_open': true},
      'can_update_status': true,
      'is_manager': isManager,
      'is_deliverer': isDeliverer,
      'publisher_name': 'Ana',
      'congregation_people': ['Ana', 'Bia'],
      'status_flow': {
        'empty': 'no',
        'written': 'pending',
        'enveloped': 'envelopada',
        'delivered': 'ok',
      },
      'letter_statuses': [
        {
          'slug': 'no',
          'label': 'Não registrada',
          'color': '#64748b',
          'counts_as_delivered': false,
        },
        {
          'slug': 'pending',
          'label': 'Escrita',
          'color': '#eab308',
          'counts_as_delivered': false,
        },
        {
          'slug': 'envelopada',
          'label': 'Envelopada',
          'color': '#8b5cf6',
          'counts_as_delivered': false,
        },
        {
          'slug': 'ok',
          'label': 'Entregue',
          'color': '#22c55e',
          'counts_as_delivered': true,
        },
      ],
      'apartments': [],
    });

ApartmentLetter _apartment({String status = 'no'}) => ApartmentLetter.fromJson({
  'id': 12,
  'block_number': 1,
  'floor_number': 3,
  'apartment_number': '301',
  'apartment_number_value': '301',
  'status': status,
  'status_label': status,
  'status_color': '#64748b',
  'can_update': true,
});
