import 'package:cartas/models/mobile_models.dart';
import 'package:cartas/screens/apartment_status_wizard_sheet.dart';
import 'package:cartas/screens/map_point_sheets.dart';
import 'package:cartas/state/mobile_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// Regressão: campos de texto em folhas modais não podem ficar sob o teclado.
const _screen = Size(390, 844);
const _keyboard = 400.0;

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> typeAndExpectAboveKeyboard(
    WidgetTester tester,
    Finder field,
  ) async {
    if (field.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        field,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('Teste');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rect = tester.getRect(field);
    expect(rect.bottom, lessThanOrEqualTo(_screen.height - _keyboard));
    expect(rect.top, greaterThanOrEqualTo(0));

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(
    WidgetTester tester,
    WidgetBuilder builder, {
    bool dragHandle = false,
    List<Object> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: dragHandle,
                  builder: builder,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  CondominiumDetail detail() => CondominiumDetail.fromJson({
    'condominium': {'id': 5, 'name': 'Condomínio Teste'},
    'campaign': {'id': 8, 'name': 'Campanha', 'is_open': true},
    'can_update_status': true,
    'is_manager': true,
    'publisher_name': 'Ana',
    'congregation_people': ['Ana', 'Bia'],
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
    'publications': [
      {
        'codigo': 'lmd',
        'titulo': 'Ame as Pessoas',
        'topicos': ['Bondade'],
      },
    ],
    'apartments': [],
  });

  Future<void> openWizard(WidgetTester tester) => openSheet(
    tester,
    // Mesmo embrulho de native_sections_screen.dart (_chooseStatus).
    (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ApartmentStatusWizardSheet(
        detail: detail(),
        apartment: ApartmentLetter.fromJson({
          'id': 12,
          'apartment_number': '301',
          'apartment_number_value': '301',
          'status': 'no',
          'status_label': 'no',
          'status_color': '#64748b',
          'can_update': true,
        }),
        loadHistory: () async => const [],
        onSave: (_) async => null,
      ),
    ),
  );

  testWidgets('wizard: Assunto fica acima do teclado', (tester) async {
    phone(tester);
    await openWizard(tester);
    await typeAndExpectAboveKeyboard(
      tester,
      find.widgetWithText(TextField, 'Assunto'),
    );
  });

  testWidgets('folha de publicações: busca e filtro de assuntos acima do teclado', (
    tester,
  ) async {
    phone(tester);
    await openWizard(tester);
    await tester.tap(find.text('Adicionar publicação citada'));
    await tester.pumpAndSettle();
    await typeAndExpectAboveKeyboard(
      tester,
      find.byKey(const ValueKey('citation-search')),
    );
    await tester.enterText(find.byKey(const ValueKey('citation-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ame as Pessoas'));
    await tester.pumpAndSettle();
    await typeAndExpectAboveKeyboard(
      tester,
      find.byKey(const ValueKey('citation-topic-search')),
    );
  });

  testWidgets('detalhes do apartamento: Observação fica acima do teclado', (
    tester,
  ) async {
    phone(tester);
    await openWizard(tester);
    await tester.tap(find.text('Detalhes / editar'));
    await tester.pumpAndSettle();
    await typeAndExpectAboveKeyboard(
      tester,
      find.widgetWithText(TextFormField, 'Observação'),
    );
  });

  testWidgets(
    'ponto do mapa: título, endereço e observações acima do teclado',
    (tester) async {
      phone(tester);
      await openSheet(
        tester,
        (_) => const MapPointFormSheet(position: LatLng(-22.9, -43.2)),
        dragHandle: true,
        overrides: [mobileAppControllerProvider.overrideWith(_Controller.new)],
      );
      for (final key in ['title', 'address', 'notes']) {
        await typeAndExpectAboveKeyboard(
          tester,
          find.byKey(ValueKey('map-point-$key')),
        );
      }
    },
  );
}

class _Controller extends MobileAppController {
  @override
  Future<MobileAppState> build() async => const MobileAppState(
    selectedCongregationId: 1,
    canManageMapPoints: true,
    mapPointTypes: [
      MapPointType(id: 4, name: 'Igreja', color: Color(0xFF8A2580)),
    ],
  );
}
