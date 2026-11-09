import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartas/data/mobile_api.dart';
import 'package:cartas/models/mobile_models.dart';
import 'package:cartas/models/outing_work.dart';

Map<String, dynamic> _candidate(
  int id,
  List<String> streets, {
  Map<String, dynamic>? record,
  String coverage = 'em_andamento',
}) => {
  'card_id': id,
  'code': '4.00$id',
  'name': '',
  'coverage_state': coverage,
  'streets': [
    for (final name in streets)
      {
        'name': name,
        'meters': 300,
        'lines': [
          [
            [-22.4, -43.1],
            [-22.41, -43.11],
          ],
        ],
      },
  ],
  'record': record,
};

Map<String, dynamic> _payload() => {
  'outing': {
    'id': 7,
    'date': '2026-11-07',
    'location': {'id': 3, 'name': 'Salão', 'lat': -22.4, 'lng': -43.1},
  },
  'no_record_needed': false,
  'notice': null,
  'awaiting_migration': false,
  'candidates': [
    _candidate(1, ['Rua A', 'Rua B']),
    _candidate(
      2,
      ['Rua C'],
      record: {
        'id': 9,
        'date': '2026-11-01',
        'note': null,
        'streets': ['Rua C'],
        'completed': true,
      },
    ),
  ],
};

void main() {
  test('candidates JSON is parsed with streets, lines and record', () {
    final data = OutingWorkData.fromJson(_payload());

    expect(data.outingId, 7);
    expect(data.locationName, 'Salão');
    expect(data.locationPoint?.latitude, -22.4);
    expect(data.noRecordNeeded, isFalse);
    expect(data.candidates, hasLength(2));
    final first = data.candidates.first;
    expect(first.title, '4.001');
    expect(first.streets.map((s) => s.name), ['Rua A', 'Rua B']);
    expect(first.streets.first.lines.single, hasLength(2));
    expect(first.record, isNull);
    expect(data.candidates.last.record?.completed, isTrue);
  });

  test('informational outing needs no record', () {
    final data = OutingWorkData.fromJson({
      'outing': {'id': 8, 'date': '2026-11-07', 'location': null},
      'no_record_needed': true,
      'candidates': const [],
    });

    expect(data.noRecordNeeded, isTrue);
    expect(data.locationPoint, isNull);
    expect(data.candidates, isEmpty);
  });

  test('all streets of a card complete it, partial only registers the day', () {
    final data = OutingWorkData.fromJson(_payload());
    final selection = OutingWorkSelection(data.candidates);
    final card = data.candidates.first;

    expect(selection.hasChanges, isFalse);
    selection.toggleStreet(card, card.streets.first);
    expect(selection.coverage(card), OutingWorkCoverage.partial);
    expect(selection.willComplete(card), isFalse);

    selection.toggleStreet(card, card.streets.last);
    expect(selection.coverage(card), OutingWorkCoverage.all);
    expect(selection.willComplete(card), isTrue);

    final payload = selection.payload(defaultDate: '2026-11-07');
    final items = payload['items'] as List;
    expect(items, hasLength(1));
    expect((items.first as Map)['card_id'], 1);
    expect((items.first as Map)['date'], '2026-11-07');
    expect((items.first as Map)['streets'], ['Rua A', 'Rua B']);
    // O registro já salvo do cartão 2 não mudou: não é reenviado nem removido.
    expect(payload.containsKey('remove'), isFalse);
  });

  test('editing a record that concluded the card reopens it', () {
    final data = OutingWorkData.fromJson(_payload());
    final selection = OutingWorkSelection(data.candidates);
    final card = data.candidates.last;

    // O registro já traz a rua marcada.
    expect(selection.coverage(card), OutingWorkCoverage.all);
    expect(selection.willComplete(card), isFalse);
    expect(selection.willReopen(card), isFalse);

    selection.setAll(card, false);
    expect(selection.willReopen(card), isTrue);
    final payload = selection.payload(defaultDate: '2026-11-07');
    expect(payload['remove'], [2]);
  });

  test('street keys ignore case and repeated spaces like the server', () {
    expect(streetKey('  Rua   Alfa '), streetKey('rua alfa'));
    expect(streetKey(''), 'sem nome');
  });

  test('save result lists concluded and reopened cards', () {
    final result = OutingWorkResult.fromJson({
      'created': 1,
      'updated': 0,
      'removed': 1,
      'completed_card_ids': [4],
      'reopened_card_ids': [5],
    });

    expect(result.completedCardIds, [4]);
    expect(result.reopenedCardIds, [5]);
  });

  test(
    'field models read the new backend fields and tolerate old payloads',
    () {
      final outing = FieldOuting.fromJson({
        'id': 1,
        'date': '2026-11-07',
        'informational': true,
        'situation': {'slug': 'pendente', 'label': 'Pendente'},
        'location': {
          'id': 2,
          'name': 'Zoom',
          'online': true,
          'active': true,
          'lat': null,
          'lng': null,
        },
      });
      expect(outing.informational, isTrue);
      expect(outing.location?.online, isTrue);
      expect(outing.location?.hasPoint, isFalse);

      final old = FieldOuting.fromJson({'id': 2, 'date': '2026-11-08'});
      expect(old.informational, isFalse);

      final location = FieldLocation.fromJson({
        'id': 3,
        'name': 'Salão',
        'lat': -22.4,
        'lng': -43.1,
      });
      expect(location.hasPoint, isTrue);
      expect(location.active, isTrue);
    },
  );

  test('congregation shows circuit and city when the server sends them', () {
    final congregation = Congregation.fromJson({
      'id': 1,
      'name': 'Central — Petrópolis',
      'slug': 'central',
      'circuit': 'RJ-14',
      'city': 'Petrópolis',
    });
    expect(congregation.subtitle, 'RJ-14 · Petrópolis');

    final old = Congregation.fromJson({'id': 2, 'name': 'X', 'slug': 'x'});
    expect(old.subtitle, isEmpty);
  });

  test('API calls the work endpoints with the congregation scope', () async {
    final requests = <RequestOptions>[];
    final api = MobileApi(
      dio: Dio(BaseOptions(baseUrl: 'https://unit.example'))
        ..httpClientAdapter = _JsonAdapter((request) {
          requests.add(request);
          return request.method == 'GET'
              ? _payload()
              : {
                  'created': 1,
                  'updated': 0,
                  'removed': 0,
                  'completed_card_ids': [1],
                  'reopened_card_ids': <int>[],
                };
        }),
    );

    final data = await api.outingWorkCandidates(
      token: 'tk',
      congregationId: 17,
      outingId: 7,
    );
    final result = await api.saveOutingWork(
      token: 'tk',
      congregationId: 17,
      outingId: 7,
      data: {
        'items': [
          {
            'card_id': 1,
            'streets': ['Rua A', 'Rua B'],
          },
        ],
      },
    );

    expect(data.candidates, hasLength(2));
    expect(result.completedCardIds, [1]);
    expect(requests.first.path, '/mobile/field-outings/7/work-candidates');
    expect(requests.last.path, '/mobile/field-outings/7/work-streets');
    expect(requests.last.method, 'POST');
    expect(requests.last.headers['X-Congregation-ID'], '17');
    expect(requests.last.headers['Authorization'], 'Bearer tk');
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.respond);

  final Map<String, dynamic> Function(RequestOptions request) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    utf8.encode(jsonEncode(respond(options))),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
