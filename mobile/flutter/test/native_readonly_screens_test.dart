import 'package:cartas/models/cart.dart';
import 'package:cartas/models/field_locations.dart';
import 'package:cartas/models/programacoes.dart';
import 'package:cartas/screens/cart_screen.dart';
import 'package:cartas/screens/field_locations_screen.dart';
import 'package:cartas/screens/map_screen.dart';
import 'package:cartas/screens/programacoes_screen.dart';
import 'package:cartas/state/mobile_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _programacoesJson({bool empty = false}) => {
  'type': 'reunioes',
  'month': '2026-11',
  'previous_month': '2026-10',
  'next_month': '2026-12',
  'meetings': empty
      ? []
      : [
          {
            'id': 1,
            'type': 'meio_semana',
            'date': '2026-11-11',
            'time': '19:30',
            'weekly_reading': 'Isaías 1',
            'special_structure': null,
            'textbook_available': true,
            'event': null,
            'parts': [
              {
                'id': 10,
                'order': 1,
                'section': 'TESOUROS DA PALAVRA DE DEUS',
                'type': 'discurso',
                'number': 1,
                'title': 'Joias espirituais',
                'info': null,
                'minutes': 10,
                'song_number': null,
                'song_title': null,
                'room': null,
              },
              {
                'id': 11,
                'order': 2,
                'section': 'Faça seu melhor no ministério',
                'number': 4,
                'title': 'Iniciando conversas',
                'minutes': 3,
              },
              {
                'id': 12,
                'order': 3,
                'section': 'nossa_vida_crista',
                'number': 6,
                'title': 'Necessidades locais',
                'minutes': 15,
              },
              {'id': 13, 'order': 0, 'section': 'inicio', 'title': 'Cântico'},
            ],
            'assignments': [
              {
                'id': 100,
                'part_id': 10,
                'label': 'Orador',
                'person': 'Fulano de Tal',
                'order': 1,
              },
              {
                'id': 101,
                'part_id': 11,
                'label': 'Estudante',
                'person': 'Beltrano',
                'second_person': 'Sicrano',
                'order': 1,
              },
              {'id': 102, 'part_id': null, 'label': 'Presidente', 'person': 'Ciclano'},
            ],
            'outside_talks': [],
          },
        ],
  'ava': [],
  'cleaning': [],
};

Map<String, dynamic> _calendarJson({bool empty = false}) => {
  'month': '2026-11',
  'previous_month': '2026-10',
  'next_month': '2026-12',
  'is_current_month': true,
  'filtered_spot_id': null,
  'has_shifts': !empty,
  'spots': [
    {'id': 1, 'name': 'Praça Central', 'type': 'tpl'},
    {'id': 2, 'name': 'Rodoviária', 'type': 'tpe'},
  ],
  'days': empty
      ? []
      : [
          {
            'date': '2026-10-31',
            'in_month': false,
            'today': false,
            'past': true,
            'open_slots': 0,
            'shifts': [],
          },
          {
            'date': '2026-11-12',
            'in_month': true,
            'today': false,
            'past': false,
            'open_slots': 1,
            'shifts': [
              {
                'key': 'a',
                'spot_id': 1,
                'spot': 'Praça Central',
                'type': 'tpl',
                'weekday': 'quinta',
                'date': '2026-11-12',
                'start': '09:00',
                'end': '11:00',
                'capacity': 2,
                'occupied': 1,
                'open_slots': 1,
                'state': 'parcial',
                'pending': 0,
                'people': [
                  {
                    'first_name': 'Maria',
                    'role': 'publicador',
                    'free_time': false,
                    'start': '09:00',
                    'end': '11:00',
                  },
                ],
              },
            ],
          },
        ],
};

class _Fake extends MobileAppController {
  _Fake(
    this.initial, {
    this.programacoes,
    this.calendar,
    this.signups,
    this.locations,
    this.fail = false,
  });

  final MobileAppState initial;
  final Map<String, dynamic>? programacoes;
  final Map<String, dynamic>? calendar;
  final Map<String, dynamic>? signups;
  final Map<String, dynamic>? locations;
  final bool fail;
  final requested = <String>[];

  @override
  Future<MobileAppState> build() async => initial;

  @override
  Future<ProgramacoesMonth> loadProgramacoes({
    required String type,
    String? month,
  }) async {
    requested.add('$type|$month');
    if (fail) throw Exception('rede');
    return ProgramacoesMonth.fromJson(programacoes!);
  }

  @override
  Future<CartCalendar> loadCartCalendar({String? month, int? spotId}) async {
    if (fail) throw Exception('rede');
    return CartCalendar.fromJson(calendar!);
  }

  @override
  Future<CartMySignups> loadCartMySignups() async {
    if (fail) throw Exception('rede');
    return CartMySignups.fromJson(signups!);
  }

  @override
  Future<FieldLocationsPage> loadFieldLocations() async {
    if (fail) throw Exception('rede');
    return FieldLocationsPage.fromJson(locations!);
  }
}

Widget _app(_Fake controller, Widget screen) => ProviderScope(
  key: UniqueKey(),
  overrides: [mobileAppControllerProvider.overrideWith(() => controller)],
  child: MaterialApp(
    home: Consumer(
      builder: (context, ref, child) => ref
          .watch(mobileAppControllerProvider)
          .when(
            data: (_) => screen,
            error: (error, stackTrace) => Text('$error'),
            loading: () => const SizedBox.shrink(),
          ),
    ),
  ),
);

void main() {
  group('models', () {
    test('normalize section keys and colors', () {
      expect(normalizeSectionKey('NOSSA VIDA CRISTÃ'), 'nossa_vida_crista');
      expect(normalizeSectionKey('Faça seu melhor'), 'faca_seu_melhor');
      expect(sectionColor('Tesouros'), const Color(0xFF2F6F73));
      expect(sectionColor('faca_seu_melhor'), const Color(0xFFB8860B));
      expect(sectionColor('Nossa Vida Cristã'), const Color(0xFF7A2438));
      expect(sectionColor('inicio'), neutralSectionColor);
      expect(sectionColor(null), neutralSectionColor);
    });

    test('parse defensively', () {
      final month = ProgramacoesMonth.fromJson(_programacoesJson());
      final meeting = month.meetings.single;
      expect(meeting.assignmentsFor(11).single.people, 'Beltrano · Sicrano');
      expect(meeting.generalAssignments.single.label, 'Presidente');
      expect(ProgramacoesMonth.fromJson(const {}).isEmpty, isTrue);
      expect(CartCalendar.fromJson(const {}).days, isEmpty);
      expect(CartMySignups.fromJson(const {}).linked, isFalse);
      expect(FieldLocationsPage.fromJson(const {}).locations, isEmpty);
      final shift = CartShift.fromJson(const {'key': 'x', 'people': [{}]});
      expect(shift.people.single.firstName, isNull);
    });
  });

  testWidgets('menu entries follow permissions', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final allowed in [true, false]) {
      final state = MobileAppState(
        canViewPeople: true,
        canViewProgramacoes: allowed,
        canViewCart: allowed,
        canViewFieldOutings: allowed,
        selectedCongregationId: 17,
      );
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(allowed),
          overrides: [
            mobileAppControllerProvider.overrideWith(() => _Fake(state)),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Consumer(
              builder: (context, ref, child) => ref
                  .watch(mobileAppControllerProvider)
                  .when(
                    data: (_) => const Scaffold(body: MapScreen()),
                    error: (e, s) => Text('$e'),
                    loading: () => const SizedBox.shrink(),
                  ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Conta'));
      await tester.pumpAndSettle();

      expect(find.text('Pessoas'), findsOneWidget);
      expect(find.text('Programações'), allowed ? findsOneWidget : findsNothing);
      expect(find.text('Carrinho'), allowed ? findsOneWidget : findsNothing);
      expect(
        find.text('Locais de campo'),
        allowed ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('programacoes shows sections, parts and people', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _Fake(
      MobileAppState(canViewProgramacoes: true, selectedCongregationId: 17),
      programacoes: _programacoesJson(),
    );
    await tester.pumpWidget(_app(fake, const ProgramacoesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('novembro de 2026'), findsOneWidget);
    expect(find.text('Tesouros da Palavra de Deus'), findsOneWidget);
    expect(find.text('Faça seu melhor no ministério'), findsOneWidget);
    expect(find.text('Nossa Vida Cristã'), findsOneWidget);
    expect(find.textContaining('Joias espirituais'), findsOneWidget);
    expect(find.text('Orador: Fulano de Tal'), findsOneWidget);
    expect(find.text('Estudante: Beltrano · Sicrano'), findsOneWidget);
    expect(find.text('Presidente: Ciclano'), findsOneWidget);

    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AVA'));
    await tester.pumpAndSettle();
    expect(fake.requested, ['reunioes|null', 'reunioes|2026-12', 'ava|2026-12']);
  });

  testWidgets('programacoes empty and error states', (tester) async {
    final state = MobileAppState(
      canViewProgramacoes: true,
      selectedCongregationId: 17,
    );
    await tester.pumpWidget(
      _app(
        _Fake(state, programacoes: _programacoesJson(empty: true)),
        const ProgramacoesScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma reunião programada neste mês'), findsOneWidget);

    await tester.pumpWidget(
      _app(_Fake(state, fail: true), const ProgramacoesScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('cart shows shifts and signups', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _Fake(
      MobileAppState(canViewCart: true, selectedCongregationId: 17),
      calendar: _calendarJson(),
      signups: {
        'linked': true,
        'signups': [
          {
            'id': 5,
            'status': 'aprovada',
            'role': 'publicador',
            'weekly': false,
            'date': '2026-11-12',
            'weekday': null,
            'start': '09:00',
            'end': '11:00',
            'spot': {'id': 1, 'name': 'Praça Central', 'address': 'Rua A'},
          },
        ],
      },
    );
    await tester.pumpWidget(_app(fake, const CartScreen()));
    await tester.pumpAndSettle();

    expect(find.text('novembro de 2026'), findsOneWidget);
    expect(find.text('Praça Central · 09:00–11:00'), findsOneWidget);
    expect(find.text('TPL · Parcial · 1/2'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);

    await tester.tap(find.text('Minhas inscrições'));
    await tester.pumpAndSettle();
    expect(find.text('Aprovada'), findsOneWidget);
    expect(find.textContaining('Rua A'), findsOneWidget);
  });

  testWidgets('cart warns when account has no linked publisher', (
    tester,
  ) async {
    final fake = _Fake(
      MobileAppState(canViewCart: true, selectedCongregationId: 17),
      calendar: _calendarJson(empty: true),
      signups: {'linked': false, 'signups': []},
    );
    await tester.pumpWidget(_app(fake, const CartScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum turno neste mês'), findsOneWidget);

    await tester.tap(find.text('Minhas inscrições'));
    await tester.pumpAndSettle();
    expect(find.text('Conta sem publicador vinculado'), findsOneWidget);
  });

  testWidgets('cart error state', (tester) async {
    await tester.pumpWidget(
      _app(
        _Fake(
          MobileAppState(canViewCart: true, selectedCongregationId: 17),
          fail: true,
        ),
        const CartScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('field locations list shows inactive and manage action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final locations = {
      'locations': [
        {'id': 1, 'name': 'Salão do Reino', 'address': 'Rua B, 10', 'active': true},
        {'id': 2, 'name': 'Praça Velha', 'active': false},
      ],
      'permissions': {'can_manage': true},
    };
    final state = MobileAppState(
      canViewFieldOutings: true,
      selectedCongregationId: 17,
    );
    await tester.pumpWidget(
      _app(_Fake(state, locations: locations), const FieldLocationsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Salão do Reino'), findsOneWidget);
    expect(find.text('Praça Velha'), findsOneWidget);
    expect(find.text('Desativado'), findsOneWidget);
    expect(find.text('Novo local'), findsOneWidget);
    expect(find.byTooltip('Editar local'), findsNWidgets(2));

    await tester.pumpWidget(
      _app(
        _Fake(
          state,
          locations: {
            ...locations,
            'permissions': {'can_manage': false},
          },
        ),
        const FieldLocationsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Novo local'), findsNothing);
    expect(find.byTooltip('Editar local'), findsNothing);
  });

  testWidgets('field locations empty and error states', (tester) async {
    final state = MobileAppState(
      canViewFieldOutings: true,
      selectedCongregationId: 17,
    );
    await tester.pumpWidget(
      _app(
        _Fake(state, locations: {'locations': []}),
        const FieldLocationsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhum local cadastrado'), findsOneWidget);

    await tester.pumpWidget(
      _app(_Fake(state, fail: true), const FieldLocationsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}
