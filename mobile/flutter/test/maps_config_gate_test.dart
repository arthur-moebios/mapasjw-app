import 'package:cartas/screens/maps_config_gate.dart';
import 'package:cartas/state/mobile_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake extends MobileAppController {
  _Fake(this.initial);

  final MobileAppState initial;
  int requests = 0;

  @override
  Future<MobileAppState> build() async => initial;

  @override
  Future<void> ensureMapsConfigured() async {
    requests++;
  }

  void finish() =>
      state = AsyncData(state.requireValue.copyWith(isMapsConfigured: true));
}

Widget _app(_Fake controller) => ProviderScope(
  overrides: [mobileAppControllerProvider.overrideWith(() => controller)],
  child: MaterialApp(
    home: Consumer(
      builder: (context, ref, child) => ref
          .watch(mobileAppControllerProvider)
          .when(
            data: (_) => MapsConfigGate(
              builder: (_) => const Text('mapa', key: ValueKey('map')),
            ),
            error: (error, stackTrace) => Text('$error'),
            loading: () => const SizedBox.shrink(),
          ),
    ),
  ),
);

void main() {
  testWidgets('não monta o mapa antes de a chave ser configurada', (
    tester,
  ) async {
    final controller = _Fake(
      const MobileAppState(isAuthenticated: true, isMapsConfigured: false),
    );
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('map')), findsNothing);
    expect(find.text('Preparando o mapa…'), findsOneWidget);
    expect(controller.requests, 1);

    controller.finish();
    await tester.pump();

    expect(find.byKey(const ValueKey('map')), findsOneWidget);
    expect(find.byKey(const ValueKey('maps-config-pending')), findsNothing);
  });

  testWidgets('mostra o erro e deixa tentar de novo', (tester) async {
    final controller = _Fake(
      const MobileAppState(
        isAuthenticated: true,
        isMapsConfigured: false,
        mapsConfigError: 'Esta congregação ainda não tem o mapa configurado.',
      ),
    );
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Esta congregação ainda não tem o mapa configurado.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    expect(controller.requests, 2);
    expect(find.byKey(const ValueKey('map')), findsNothing);
  });

  testWidgets('com a chave pronta mostra o mapa direto', (tester) async {
    final controller = _Fake(
      const MobileAppState(isAuthenticated: true, isMapsConfigured: true),
    );
    await tester.pumpWidget(_app(controller));
    await tester.pump();

    expect(find.byKey(const ValueKey('map')), findsOneWidget);
    expect(controller.requests, 0);
  });
}
