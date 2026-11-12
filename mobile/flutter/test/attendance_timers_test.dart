import 'package:cartas/models/attendance.dart';
import 'package:cartas/screens/attendance_screen.dart';
import 'package:cartas/screens/map_screen.dart';
import 'package:cartas/screens/timers_screen.dart';
import 'package:cartas/state/mobile_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _attendanceJson({bool empty = false}) => {
  'month': '2026-10',
  'previous_month': '2026-09',
  'next_month': '2026-11',
  'is_current_month': false,
  'averages': [
    {
      'type': 'meio_semana',
      'label': 'Meio de semana',
      'meetings': 2,
      'average': 65,
      'in_person': 55,
      'zoom': 10,
    },
    {
      'type': 'outra',
      'label': 'Outra reunião',
      'meetings': 0,
      'average': null,
      'in_person': null,
      'zoom': null,
    },
  ],
  'records': empty
      ? []
      : [
          {
            'id': 1,
            'date': '2026-10-14',
            'type': 'meio_semana',
            'type_label': 'Meio de semana',
            'in_person': 50,
            'zoom': 10,
            'total': 60,
            'manually_edited': false,
            'note': null,
          },
        ],
};

Map<String, dynamic> _timersJson({bool empty = false, bool more = false}) => {
  'available': true,
  'page': 1,
  'has_more': more,
  'days': empty
      ? []
      : [
          {
            'date': '2026-11-11',
            'type': 'meio_semana',
            'type_label': 'Meio de semana',
            'rooms': [
              {
                'room': 'main',
                'label': 'Salão Principal',
                'total_planned_s': 600,
                'total_used_s': 645,
                'difference_s': 45,
                'measured_parts': 1,
                'total_parts': 1,
                'parts': [
                  {
                    'section': 'NOSSA VIDA CRISTÃ',
                    'title': 'Parte do Salão',
                    'assignee': 'Fulano',
                    'assistant': 'Beltrano',
                    'planned_s': 600,
                    'used_s': 645,
                    'difference_s': 45,
                  },
                ],
              },
              {
                'room': 'b',
                'label': 'Sala B',
                'total_planned_s': 180,
                'total_used_s': 0,
                'difference_s': 0,
                'measured_parts': 0,
                'total_parts': 1,
                'parts': [
                  {
                    'section': null,
                    'title': 'Parte da Sala B',
                    'assignee': null,
                    'assistant': null,
                    'planned_s': 180,
                    'used_s': null,
                    'difference_s': null,
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
    this.attendance,
    this.timers,
    this.failAttendance = false,
  });

  final MobileAppState initial;
  final Map<String, dynamic>? attendance;
  final Map<String, dynamic>? timers;
  final bool failAttendance;
  final requestedMonths = <String?>[];
  final requestedPages = <int>[];

  @override
  Future<MobileAppState> build() async => initial;

  @override
  Future<AttendanceMonth> loadAttendance({String? month}) async {
    requestedMonths.add(month);
    if (failAttendance) throw Exception('rede');
    return AttendanceMonth.fromJson(attendance!);
  }

  @override
  Future<TimersPage> loadTimers({int page = 1}) async {
    requestedPages.add(page);
    return TimersPage.fromJson(timers!);
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
    test('parse attendance month', () {
      final month = AttendanceMonth.fromJson(_attendanceJson());
      expect(month.nextMonth, '2026-11');
      expect(month.averages.first.average, 65);
      expect(month.averages.last.average, isNull);
      expect(month.records.single.total, 60);
      expect(month.records.single.date, DateTime(2026, 10, 14));
    });

    test('parse timers and format durations', () {
      final page = TimersPage.fromJson(_timersJson());
      final main = page.days.single.rooms.first;
      expect(main.parts.single.overtime, isTrue);
      expect(main.measuredParts, 1);
      final b = page.days.single.rooms.last;
      expect(b.parts.single.measured, isFalse);
      expect(b.parts.single.usedSeconds, isNull);
      expect(formatSeconds(645), '10:45');
      expect(formatSeconds(45, signed: true), '+0:45');
      expect(formatSeconds(-30, signed: true), '−0:30');
      expect(formatSeconds(3725), '1:02:05');
      expect(formatSeconds(null), '—');
      expect(TimersPage.fromJson(const {}).days, isEmpty);
    });

    test('date labels in pt-BR', () {
      expect(shortDateLabel(DateTime(2026, 11, 11)), 'qua, 11 nov');
      expect(monthLabel('2026-10'), 'outubro de 2026');
    });
  });

  testWidgets('account shortcuts follow canViewAttendance', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final allowed in [true, false]) {
      final state = MobileAppState(
        canViewPeople: true,
        canViewAttendance: allowed,
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
      expect(find.text('Assistência'), allowed ? findsOneWidget : findsNothing);
      expect(find.text('Cronômetros'), allowed ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('attendance screen shows records and navigates months', (
    tester,
  ) async {
    final fake = _Fake(
      MobileAppState(canViewAttendance: true, selectedCongregationId: 17),
      attendance: _attendanceJson(),
    );
    await tester.pumpWidget(_app(fake, const AttendanceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('outubro de 2026'), findsOneWidget);
    expect(find.text('qua, 14 out'), findsOneWidget);
    expect(find.text('65'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(find.textContaining('presencial 55 · Zoom 10'), findsOneWidget);
    expect(find.text('sem reuniões neste mês'), findsOneWidget);

    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();
    expect(fake.requestedMonths, [null, '2026-11']);
  });

  testWidgets('attendance screen empty and error states', (tester) async {
    final state = MobileAppState(
      canViewAttendance: true,
      selectedCongregationId: 17,
    );
    await tester.pumpWidget(
      _app(
        _Fake(state, attendance: _attendanceJson(empty: true)),
        const AttendanceScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma assistência registrada'), findsOneWidget);

    await tester.pumpWidget(
      _app(_Fake(state, failAttendance: true), const AttendanceScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('timers screen shows rooms, sections, overtime and totals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _Fake(
      MobileAppState(canViewAttendance: true, selectedCongregationId: 17),
      timers: _timersJson(more: true),
    );
    await tester.pumpWidget(_app(fake, const TimersScreen()));
    await tester.pumpAndSettle();

    expect(find.text('quarta-feira, 11 de novembro de 2026'), findsOneWidget);
    expect(find.text('Salão Principal'), findsOneWidget);
    expect(find.text('Sala B'), findsOneWidget);
    expect(find.text('Nossa Vida Cristã'), findsOneWidget);
    expect(find.text('Fulano · Ajudante: Beltrano'), findsOneWidget);
    expect(find.text('Usado 10:45'), findsOneWidget);
    expect(find.text('Usado —'), findsOneWidget);
    expect(find.text('1 de 1 partes medidas'), findsOneWidget);
    expect(find.text('0 de 1 partes medidas'), findsOneWidget);
    final overtime = tester.widget<Text>(find.text('Usado 10:45'));
    expect(
      overtime.style?.color,
      ThemeData().colorScheme.error,
      reason: 'passou do tempo usa a cor de erro do tema',
    );

    await tester.scrollUntilVisible(
      find.text('Carregar mais'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    expect(fake.requestedPages, [1, 2]);
  });

  testWidgets('timers screen empty state', (tester) async {
    await tester.pumpWidget(
      _app(
        _Fake(
          MobileAppState(canViewAttendance: true, selectedCongregationId: 17),
          timers: _timersJson(empty: true),
        ),
        const TimersScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhum cronômetro recebido'), findsOneWidget);
  });
}
