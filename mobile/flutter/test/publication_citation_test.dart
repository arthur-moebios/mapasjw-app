import 'package:cartas/models/apartment_status_wizard.dart';
import 'package:cartas/models/mobile_models.dart';
import 'package:cartas/models/publication_citation.dart';
import 'package:cartas/screens/apartment_status_wizard_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _workflow = ApartmentStatusWorkflow(
  emptyStatus: 'no',
  writtenStatus: 'pending',
  envelopedStatus: 'envelopada',
  deliveredStatus: 'ok',
);

PublicationCitation _cit(String title, {String topic = '', String code = ''}) =>
    PublicationCitation(title: title, code: code, topic: topic);

PublicationCatalog _catalog() => PublicationCatalog.fromJson({
  'temas': ['Depressão', 'Profissionais da saúde'],
  'publicacoes': [
    {
      'codigo': 'lmd',
      'titulo': 'Ame as Pessoas',
      'tipo': 'livro',
      'link': 'https://example.org/lmd',
      'capa': 'https://example.org/lmd.jpg',
      'novo': true,
      'topicos': [
        {'titulo': 'Bondade', 'link': 'https://example.org/lmd/bondade'},
        {'titulo': 'Esperança', 'link': null},
      ],
    },
    {
      'codigo': 'wp',
      'titulo': 'A Sentinela',
      'tipo': 'revista',
      'link': 'http://inseguro.example/wp',
      'capa': null,
      'topicos': ['Família'],
    },
  ],
});

void main() {
  group('PublicationCitation', () {
    test('fromJson tolerante e toJson', () {
      final c = PublicationCitation.tryFromJson({
        'codigo': 'lmd',
        'titulo': 'Ame as Pessoas',
        'tipo': 'livro',
        'link': 'https://a.org/x',
        'capa': 'http://a.org/capa.jpg',
        'topico': 'Bondade',
        'topico_link': 'https://a.org/x/b',
      })!;
      expect(c.cover, isNull, reason: 'http é descartado');
      expect(c.qrLink, 'https://a.org/x/b');
      expect(c.toJson()['topico'], 'Bondade');
      expect(PublicationCitation.tryFromJson({'titulo': '  '}), isNull);
      expect(PublicationCitation.tryFromJson('x'), isNull);
      expect(PublicationCitation.listFromJson(null), isEmpty);
      expect(PublicationCitation.listFromJson('lixo'), isEmpty);
      expect(
        PublicationCitation.listFromJson([
          for (var i = 0; i < 8; i++) {'titulo': 'P$i'},
        ]),
        hasLength(5),
      );
      expect(PublicationCitation.tryFromJson({'titulo': 'T'})!.qrLink, isNull);
    });

    test('ApartmentLetter e histórico leem citacoes (ausente = vazia)', () {
      final letter = ApartmentLetter.fromJson({
        'id': 1,
        'citacoes': [
          {'titulo': 'Despertai'},
        ],
      });
      expect(letter.citations.single.title, 'Despertai');
      expect(ApartmentLetter.fromJson({'id': 1}).citations, isEmpty);
      expect(
        ApartmentDeliveryHistoryEntry.fromJson({
          'citacoes': [
            {'titulo': 'A'},
            {'titulo': 'B'},
          ],
        }).citations,
        hasLength(2),
      );
      expect(ApartmentDeliveryHistoryEntry.fromJson({}).citations, isEmpty);
    });

    test('withStatusFields: citacoes ausente preserva, [] limpa', () {
      final letter = ApartmentLetter.fromJson({
        'id': 1,
        'status': 'pending',
        'citacoes': [
          {'titulo': 'Despertai'},
        ],
      });
      expect(
        letter.withStatusFields({'status': 'ok'}, const []).citations,
        hasLength(1),
      );
      expect(
        letter.withStatusFields({
          'status': 'ok',
          'citacoes': [],
        }, const []).citations,
        isEmpty,
      );
    });
  });

  group('regras', () {
    test('limite de 5 e repetida ignorada', () {
      var list = <PublicationCitation>[];
      for (var i = 0; i < 7; i++) {
        list = CitationRules.add(list, _cit('P$i'));
      }
      expect(list, hasLength(5));
      expect(CitationRules.add([_cit('A')], _cit('a')), hasLength(1));
      expect(
        CitationRules.add([_cit('A')], _cit('A', topic: 'x')),
        hasLength(2),
      );
      expect(CitationRules.removeAt(list, 0).first.title, 'P1');
    });

    test('rótulo de publication: 1ª citação ou legado intacto', () {
      expect(CitationRules.publicationLabel([_cit('X')], 'velho'), 'X');
      expect(CitationRules.publicationLabel(const [], ' velho '), 'velho');
      expect(CitationRules.publicationLabel(const [], ''), isNull);
    });

    test(
      'busca ignora acento e caixa; assunto lista tópicos antes dos temas',
      () {
        final cat = _catalog();
        expect(
          CitationRules.filterPublications(cat, 'SENTINELA'),
          hasLength(1),
        );
        expect(CitationRules.filterPublications(cat, 'revista'), hasLength(1));
        expect(CitationRules.filterPublications(cat, 'zzz'), isEmpty);
        expect(
          CitationRules.filterTopics(cat.publications.first, 'esperanca'),
          hasLength(1),
        );
        expect(
          CitationRules.subjectSuggestions(cat.themes, [
            _cit('A', topic: 'Bondade'),
          ], ''),
          ['Bondade', 'Depressão', 'Profissionais da saúde'],
        );
        expect(
          CitationRules.subjectSuggestions(cat.themes, const [], 'depressao'),
          ['Depressão'],
        );
        expect(
          CitationRules.readingText([_cit('A', topic: 'B')], null, 'tema'),
          'Publicação: A (B) · Assunto: tema',
        );
      },
    );

    test('catálogo v2: tópico string/objeto, link http descartado', () {
      final cat = _catalog();
      expect(cat.themes, hasLength(2));
      expect(cat.publications.first.isNew, isTrue);
      expect(cat.publications[1].link, isNull);
      expect(cat.publications[1].topics.single.title, 'Família');
      final c = cat.publications.first.cite(
        cat.publications.first.topics.first,
      );
      expect(c.qrLink, 'https://example.org/lmd/bondade');
    });

    test('payload: citacoes só quando fornecidas; limpar envia []', () {
      Map<String, Object?>? build(
        List<PublicationCitation>? citations, {
        ApartmentWizardAction action = ApartmentWizardAction.write,
      }) => _workflow.buildPayload(
        action: action,
        apartmentNumber: '1',
        currentStatus: 'no',
        currentFields: const {},
        today: DateTime(2026, 11, 8),
        publication: 'legado',
        citations: citations,
      );
      expect(build(null)!.containsKey('citacoes'), isFalse);
      expect(build(null)!['publication'], 'legado');
      final withC = build([_cit('Despertai')])!;
      expect(
        (withC['citacoes'] as List).single,
        containsPair('titulo', 'Despertai'),
      );
      expect(withC['publication'], 'Despertai');
      final empty = build(const [])!;
      expect(empty['citacoes'], isEmpty);
      expect(empty['publication'], 'legado');
      expect(
        build(null, action: ApartmentWizardAction.clear)!['citacoes'],
        isEmpty,
      );
      expect(
        build(
          null,
          action: ApartmentWizardAction.envelope,
        )!.containsKey('citacoes'),
        isFalse,
      );
    });
  });

  group('folha de seleção', () {
    CondominiumDetail detail() => CondominiumDetail.fromJson({
      'condominium': {'id': 5, 'name': 'Cond'},
      'campaign': {'id': 8, 'name': 'C', 'is_open': true},
      'is_manager': true,
      'publisher_name': 'Ana',
      'status_flow': {
        'empty': 'no',
        'written': 'pending',
        'enveloped': 'envelopada',
        'delivered': 'ok',
      },
      'letter_statuses': [
        for (final s in ['no', 'pending', 'envelopada', 'ok'])
          {
            'slug': s,
            'label': s,
            'color': '#64748b',
            'counts_as_delivered': s == 'ok',
          },
      ],
      'apartments': [],
    });

    Future<List<Map<String, Object?>>> pump(
      WidgetTester tester, {
      Map<String, Object?> extra = const {},
      PublicationCatalog? catalog,
      Future<PublicationCatalog> Function()? loader,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <Map<String, Object?>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApartmentStatusWizardSheet(
              detail: detail(),
              apartment: ApartmentLetter.fromJson({
                'id': 12,
                'apartment_number': '301',
                'apartment_number_value': '301',
                'status': 'no',
                'status_label': 'no',
                'status_color': '#64748b',
                'can_update': true,
                ...extra,
              }),
              loadHistory: () async => const [],
              loadCatalog: loader ?? () async => catalog ?? _catalog(),
              onSave: (p) async {
                saved.add(p);
                return null;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return saved;
    }

    testWidgets('busca filtra, passo 2, chip criado e payload com citacoes', (
      tester,
    ) async {
      final saved = await pump(tester);
      await tester.tap(find.text('Adicionar publicação citada'));
      await tester.pumpAndSettle();
      expect(find.text('Ame as Pessoas'), findsOneWidget);
      expect(find.text('A Sentinela'), findsOneWidget);
      expect(find.text('Novo'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('citation-search')),
        'sentinela',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ame as Pessoas'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('citation-search')),
        'AME',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ame as Pessoas'));
      await tester.pumpAndSettle();

      expect(
        find.text('Só a publicação (sem assunto interno)'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('citation-topic-search')),
        'bond',
      );
      await tester.pumpAndSettle();
      expect(find.text('Esperança'), findsNothing);
      await tester.tap(find.text('Bondade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();

      expect(find.text('Publicações citadas (1/5)'), findsOneWidget);
      expect(find.text('Ame as Pessoas'), findsOneWidget);
      expect(find.text('Bondade'), findsOneWidget);

      await tester.tap(find.text('Marcar como escrita'));
      await tester.pumpAndSettle();
      final citacoes = saved.single['citacoes'] as List;
      expect(citacoes.single, containsPair('topico', 'Bondade'));
      expect(
        citacoes.single,
        containsPair('topico_link', 'https://example.org/lmd/bondade'),
      );
      expect(saved.single['publication'], 'Ame as Pessoas');
    });

    testWidgets('sem mexer e sem citações, payload não traz citacoes', (
      tester,
    ) async {
      final saved = await pump(tester);
      await tester.tap(find.text('Marcar como escrita'));
      await tester.pumpAndSettle();
      expect(saved.single.containsKey('citacoes'), isFalse);
    });

    testWidgets('assunto livre é aceito e sugestões vêm dos temas', (
      tester,
    ) async {
      final saved = await pump(tester);
      final field = find.widgetWithText(TextField, 'Assunto');
      await tester.ensureVisible(field);
      await tester.enterText(field, 'depress');
      await tester.pumpAndSettle();
      expect(find.text('Depressão'), findsOneWidget);
      await tester.tap(find.text('Depressão'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar como escrita'));
      await tester.pumpAndSettle();
      expect(saved.single['subject'], 'Depressão');
    });

    testWidgets('limite de 5 desabilita o botão', (tester) async {
      await pump(
        tester,
        extra: {
          'citacoes': [
            for (var i = 0; i < 5; i++) {'titulo': 'P$i'},
          ],
        },
      );
      expect(find.text('Publicações citadas (5/5)'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Adicionar publicação citada'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Limite de 5 publicações citadas.'), findsOneWidget);
    });

    testWidgets('publicação repetida é ignorada com aviso', (tester) async {
      await pump(
        tester,
        extra: {
          'citacoes': [
            {'codigo': 'lmd', 'titulo': 'Ame as Pessoas'},
          ],
        },
      );
      await tester.tap(find.text('Adicionar publicação citada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ame as Pessoas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      expect(find.text('Publicações citadas (1/5)'), findsOneWidget);
      expect(find.text('Esta publicação já foi citada.'), findsOneWidget);
    });

    testWidgets('legado: chip "— antiga" preservado; remover apaga o texto', (
      tester,
    ) async {
      final saved = await pump(tester, extra: {'publication': 'Despertai'});
      expect(find.text('Despertai — antiga'), findsOneWidget);
      await tester.tap(find.text('Marcar como escrita'));
      await tester.pumpAndSettle();
      expect(saved.single['publication'], 'Despertai');
      expect(saved.single.containsKey('citacoes'), isFalse);
    });

    testWidgets('legado removido de propósito envia publication nula', (
      tester,
    ) async {
      final saved = await pump(tester, extra: {'publication': 'Despertai'});
      await tester.tap(find.byTooltip('Remover Despertai — antiga'));
      await tester.pumpAndSettle();
      expect(find.text('Despertai — antiga'), findsNothing);
      await tester.tap(find.text('Marcar como escrita'));
      await tester.pumpAndSettle();
      expect(saved.single['publication'], isNull);
    });

    testWidgets('remover a única citação envia citacoes vazio', (tester) async {
      final saved = await pump(
        tester,
        extra: {
          'citacoes': [
            {'titulo': 'Despertai'},
          ],
          'publication': 'Despertai',
        },
      );
      await tester.tap(find.byTooltip('Remover Despertai'));
      await tester.pumpAndSettle();
      expect(find.text('Despertai — antiga'), findsNothing);
      await tester.tap(find.text('Marcar como escrita'));
      await tester.pumpAndSettle();
      expect(saved.single['citacoes'], isEmpty);
      expect(saved.single['publication'], isNull);
    });

    testWidgets('falha do catálogo cai no catálogo antigo sem quebrar', (
      tester,
    ) async {
      await pump(tester, loader: () async => throw StateError('404'));
      await tester.tap(find.text('Adicionar publicação citada'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Nenhuma publicação encontrada.'), findsOneWidget);
    });

    testWidgets(
      'capa https com erro mostra placeholder e histórico mostra chips',
      (tester) async {
        final saved = await pump(
          tester,
          extra: {
            'status': 'pending',
            'citacoes': [
              {
                'titulo': 'Ame as Pessoas',
                'topico': 'Bondade',
                'capa': 'https://example.invalid/c.jpg',
              },
            ],
            'subject': 'Depressão',
          },
        );
        expect(saved, isEmpty);
        expect(find.text('Ame as Pessoas'), findsOneWidget);
        expect(find.text('Bondade'), findsOneWidget);
        expect(find.text('Assunto: Depressão'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
