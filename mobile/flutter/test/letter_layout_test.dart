import 'package:cartas/models/letter_layout.dart';
import 'package:cartas/models/mobile_models.dart';
import 'package:cartas/screens/native_sections_screen.dart';
import 'package:cartas/state/mobile_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(
  int id,
  String number, {
  int block = 1,
  String blockName = '',
  int floor = 1,
  String floorName = '',
  String status = 'no',
  String statusLabel = 'Não registrada',
  String color = '#888888',
  bool avulso = false,
}) => {
  'id': id,
  'block_name': blockName,
  'block_number': avulso ? 0 : block,
  'floor_name': floorName,
  'floor_number': avulso ? -1 : floor,
  'apartment_number': number,
  'is_avulso': avulso,
  'status': status,
  'status_label': statusLabel,
  'status_color': color,
  'can_update': true,
};

ApartmentLetter _apt(
  int id,
  String number, {
  int block = 1,
  String blockName = '',
  int floor = 1,
  String floorName = '',
  String status = 'no',
  String statusLabel = 'Não registrada',
  String color = '#888888',
  bool avulso = false,
}) => ApartmentLetter.fromJson(
  _json(
    id,
    number,
    block: block,
    blockName: blockName,
    floor: floor,
    floorName: floorName,
    status: status,
    statusLabel: statusLabel,
    color: color,
    avulso: avulso,
  ),
);

List<Map<String, dynamic>> _buildingJson() => [
  _json(1, '101', blockName: 'Bloco A', floor: 1),
  _json(2, '102', blockName: 'Bloco A', floor: 1),
  _json(
    3,
    '501',
    blockName: 'Bloco A',
    floor: 5,
    status: 'ok',
    statusLabel: 'OK',
    color: '#00AA00',
  ),
  _json(4, 'T1', blockName: 'Bloco A', floor: 0),
  _json(
    5,
    '201',
    block: 2,
    blockName: 'Bloco B',
    floor: 2,
    floorName: 'Cobertura',
  ),
  _json(6, 'Portaria', avulso: true),
];

List<ApartmentLetter> _building() => [
  _apt(1, '101', block: 1, blockName: 'Bloco A', floor: 1),
  _apt(2, '102', block: 1, blockName: 'Bloco A', floor: 1),
  _apt(
    3,
    '501',
    block: 1,
    blockName: 'Bloco A',
    floor: 5,
    status: 'ok',
    statusLabel: 'OK',
    color: '#00AA00',
  ),
  _apt(4, 'T1', block: 1, blockName: 'Bloco A', floor: 0),
  _apt(
    5,
    '201',
    block: 2,
    blockName: 'Bloco B',
    floor: 2,
    floorName: 'Cobertura',
  ),
  _apt(6, 'Portaria', avulso: true),
];

class _FakeController extends MobileAppController {
  _FakeController(this.apartments);

  final List<Map<String, dynamic>> apartments;

  @override
  Future<MobileAppState> build() async =>
      const MobileAppState(selectedCongregationId: 1);

  @override
  Future<CondominiumDetail> loadCondominium(
    int condominiumId, {
    int? campaignId,
  }) async => CondominiumDetail.fromJson({
    'condominium': {'id': condominiumId, 'name': 'Prédio Teste'},
    'can_update_status': true,
    'letter_statuses': [
      {'slug': 'no', 'label': 'Não registrada', 'color': '#888888'},
      {
        'slug': 'ok',
        'label': 'OK',
        'color': '#00AA00',
        'counts_as_delivered': true,
      },
    ],
    'apartments': apartments,
  });
}

void main() {
  group('LetterLayout.group', () {
    test(
      'agrupa por bloco, andares decrescentes, rótulos e avulsas à parte',
      () {
        final groups = LetterLayout.group(_building());

        expect(groups.map((g) => g.title), ['Bloco A', 'Bloco B', 'Endereços']);
        final a = groups.first;
        expect(a.isBlock, isTrue);
        expect(a.floors.map((f) => f.label), ['5º', '1º', 'Térreo']);
        expect(a.floors[1].apartments.map((x) => x.apartmentNumber), [
          '101',
          '102',
        ]);
        expect(a.summary, '4 aptos · 3 andares');
        expect(groups[1].floors.single.label, 'Cobertura');
        expect(groups.last.isBlock, isFalse);
        expect(groups.last.summary, '1 unidade');
      },
    );

    test('resumo por status segue a ordem dos status e ignora zerados', () {
      final a = LetterLayout.group(_building()).first;
      final counts = a.statusCounts(const [
        LetterStatusOption(
          slug: 'ok',
          label: 'OK',
          color: Colors.green,
          countsAsDelivered: true,
        ),
        LetterStatusOption(
          slug: 'no',
          label: 'Não registrada',
          color: Colors.grey,
          countsAsDelivered: false,
        ),
        LetterStatusOption(
          slug: 'x',
          label: 'Outro',
          color: Colors.red,
          countsAsDelivered: false,
        ),
      ]);
      expect(counts.map((c) => '${c.slug}:${c.count}'), ['ok:1', 'no:3']);
    });
  });

  testWidgets('blocos recolhem, expandem e mantêm o estado ao recarregar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mobileAppControllerProvider.overrideWith(
            () => _FakeController(_buildingJson()),
          ),
        ],
        child: const MaterialApp(
          home: CondominiumLettersScreen(
            condominium: CondominiumSummary(
              id: 9,
              name: 'Prédio Teste',
              code: '',
              address: '',
              apartmentsCount: 6,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bloco A'), findsOneWidget);
    expect(find.text('4 aptos · 3 andares'), findsOneWidget);
    expect(find.text('5º'), findsOneWidget);
    expect(find.text('Térreo'), findsOneWidget);
    expect(find.text('Cobertura'), findsOneWidget);
    expect(find.text('501'), findsOneWidget);
    expect(find.text('Recolher todos os blocos'), findsOneWidget);

    await tester.tap(find.text('Bloco A'));
    await tester.pumpAndSettle();
    expect(find.text('501'), findsNothing);
    expect(find.text('201'), findsOneWidget);

    // Recarregar (puxar para atualizar) não reabre o bloco recolhido.
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('501'), findsNothing);

    await tester.tap(find.text('Recolher todos os blocos'));
    await tester.pumpAndSettle();
    expect(find.text('201'), findsNothing);
    expect(find.text('Portaria'), findsNothing);
    expect(find.text('Expandir todos os blocos'), findsOneWidget);

    await tester.tap(find.text('Expandir todos os blocos'));
    await tester.pumpAndSettle();
    expect(find.text('501'), findsOneWidget);
    expect(find.text('201'), findsOneWidget);
    expect(find.text('Portaria'), findsOneWidget);
  });
}
