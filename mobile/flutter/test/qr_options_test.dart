import 'dart:typed_data';

import 'package:cartas/models/mobile_models.dart';
import 'package:cartas/models/publication_citation.dart';
import 'package:cartas/screens/apartment_status_wizard_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PublicationCatalog _catalog() => PublicationCatalog.fromJson({
  'publicacoes': [
    {
      'codigo': 'lmd',
      'titulo': 'Ame as Pessoas',
      'link': 'https://www.jw.org/pt/lmd',
      'topicos': [
        {'titulo': 'Bondade', 'link': 'https://www.jw.org/pt/lmd/bondade'},
        {'titulo': 'Esperança'},
      ],
    },
    {'titulo': 'Sem link'},
  ],
});

void main() {
  group('CitationRules.qrOptions', () {
    test('usa o link do assunto interno, senão o da publicação', () {
      final options = CitationRules.qrOptions(
        citations: const [
          PublicationCitation(
            title: 'Ame',
            code: 'lmd',
            link: 'https://www.jw.org/a',
            topic: 'Bondade',
            topicLink: 'https://www.jw.org/a/bondade',
          ),
          PublicationCitation(title: 'Outra', link: 'https://www.jw.org/b'),
          PublicationCitation(title: 'Sem link'),
        ],
        freeSubject: 'Paz',
      );

      expect(options.map((o) => o.link), [
        'https://www.jw.org/a/bondade',
        'https://www.jw.org/b',
      ]);
      expect(options.first.subject, 'Bondade — Paz');
      expect(options.first.label, 'Ame — Bondade');
      expect(options.first.code, 'lmd');
      expect(options.last.subject, 'Paz');
      expect(options.last.label, 'Outra');
    });

    test('não repete o assunto livre igual ao tópico', () {
      final options = CitationRules.qrOptions(
        citations: const [
          PublicationCitation(
            title: 'Ame',
            link: 'https://www.jw.org/a',
            topic: 'Bondade',
          ),
        ],
        freeSubject: ' bondade ',
      );
      expect(options.single.subject, 'Bondade');
    });

    test(
      'sem citações: texto legado achado no catálogo, com link do tópico',
      () {
        final byCode = CitationRules.qrOptions(
          citations: const [],
          legacy: 'LMD — Ame as Pessoas',
          freeSubject: 'bondade',
          catalog: _catalog(),
        );
        expect(byCode.single.link, 'https://www.jw.org/pt/lmd/bondade');
        expect(byCode.single.subject, 'bondade');

        final byTitle = CitationRules.qrOptions(
          citations: const [],
          legacy: 'ame as pessoas',
          freeSubject: 'Esperança',
          catalog: _catalog(),
        );
        expect(byTitle.single.link, 'https://www.jw.org/pt/lmd');
      },
    );

    test('sem link, sem catálogo ou texto livre: nenhuma opção', () {
      expect(
        CitationRules.qrOptions(
          citations: const [],
          legacy: 'Sem link',
          catalog: _catalog(),
        ),
        isEmpty,
      );
      expect(
        CitationRules.qrOptions(citations: const [], legacy: 'Ame as Pessoas'),
        isEmpty,
      );
      expect(
        CitationRules.qrOptions(
          citations: const [],
          legacy: 'qualquer coisa',
          catalog: _catalog(),
        ),
        isEmpty,
      );
    });

    test('só aceita https e monta o corpo do endpoint', () {
      final options = CitationRules.qrOptions(
        citations: const [
          PublicationCitation(title: 'X', link: 'http://www.jw.org/x'),
        ],
      );
      expect(options, isEmpty);
      const option = QrOption(
        title: 'Ame',
        code: 'lmd',
        link: 'https://www.jw.org/a',
        subject: 'Paz',
        label: 'Ame',
      );
      expect(option.toJson(), {
        'titulo': 'Ame',
        'codigo': 'lmd',
        'assunto': 'Paz',
        'link': 'https://www.jw.org/a',
      });
    });
  });

  group('botão Gerar QR no assistente', () {
    Widget sheet({
      required List<PublicationCitation> citations,
      Future<Uint8List> Function(QrOption)? generate,
      Future<void> Function(Uint8List, QrOption)? share,
    }) {
      final detail = CondominiumDetail.fromJson({
        'condominium': {'id': 1, 'name': 'Prédio'},
        'can_update_status': true,
        'letter_statuses': [
          {'slug': 'no', 'label': 'Não registrada', 'color': '#888888'},
        ],
      });
      final apartment = ApartmentLetter.fromJson({
        'id': 1,
        'apartment_number': '101',
        'status': 'no',
        'can_update': true,
        'citacoes': [for (final c in citations) c.toJson()],
      });
      return MaterialApp(
        home: Scaffold(
          body: ApartmentStatusWizardSheet(
            detail: detail,
            apartment: apartment,
            onSave: (_) async => null,
            loadHistory: () async => const [],
            generateQr: generate,
            shareQr: share,
          ),
        ),
      );
    }

    testWidgets('gera e compartilha com uma única opção', (tester) async {
      QrOption? generated;
      Uint8List? shared;
      await tester.pumpWidget(
        sheet(
          citations: const [
            PublicationCitation(title: 'Ame', link: 'https://www.jw.org/a'),
          ],
          generate: (option) async {
            generated = option;
            return Uint8List.fromList([1, 2, 3]);
          },
          share: (bytes, option) async => shared = bytes,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gerar QR'), findsOneWidget);
      await tester.tap(find.text('Gerar QR'));
      await tester.pumpAndSettle();

      expect(generated?.link, 'https://www.jw.org/a');
      expect(shared, [1, 2, 3]);
    });

    testWidgets('com várias opções pede a escolha; erro vira SnackBar', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      QrOption? generated;
      await tester.pumpWidget(
        sheet(
          citations: const [
            PublicationCitation(title: 'Ame', link: 'https://www.jw.org/a'),
            PublicationCitation(title: 'Outra', link: 'https://www.jw.org/b'),
          ],
          generate: (option) async {
            generated = option;
            throw StateError('Falhou no servidor.');
          },
          share: (bytes, option) async {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gerar QR'));
      await tester.pumpAndSettle();
      expect(find.text('Qual publicação no QR?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Outra'),
        ),
      );
      await tester.pumpAndSettle();

      expect(generated?.title, 'Outra');
      expect(find.text('Falhou no servidor.'), findsOneWidget);
    });

    testWidgets('sem link ou sem callbacks, o botão não aparece', (
      tester,
    ) async {
      await tester.pumpWidget(
        sheet(
          citations: const [PublicationCitation(title: 'Sem link')],
          generate: (_) async => Uint8List(0),
          share: (_, _) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gerar QR'), findsNothing);

      await tester.pumpWidget(
        sheet(
          citations: const [
            PublicationCitation(title: 'Ame', link: 'https://www.jw.org/a'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gerar QR'), findsNothing);
    });
  });
}
