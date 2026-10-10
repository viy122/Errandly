import 'dart:convert';

import 'package:errandly/data/entity_codec.dart';
import 'package:errandly/data/errand_api.dart';
import 'package:errandly/models/entities.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> stateFor(String id, {String status = 'ongoing'}) => {
  'currentId': id,
  'demo': true,
  'users': [
    for (final name in ['anna', 'ben'])
      {
        ...profileJson(
          UserProfile(
            id: name,
            name: name == 'anna' ? 'Anna Cruz' : 'Ben Santos',
            email: name == id ? '$name@example.com' : '',
          ),
        ),
        'verified': true,
        'completed': 0,
        'rating': 0,
      },
  ],
  'errands': [
    {
      ...errandJson(
        Errand(
          id: 'db1',
          ownerId: 'anna',
          title: 'Database errand',
          category: 'Delivery',
          description: 'Documents',
          pickup: 'QC',
          destination: 'Cavite',
          budget: 50,
          fee: 40,
          distance: 65000,
          deadline: DateTime.now().add(const Duration(days: 1)),
        ),
      ),
      'ownerId': 'anna',
      'runnerId': 'ben',
      'postedAt': '2026-10-07T00:00:00Z',
      'status': status,
      'progress': 5,
      'actualCost': 45,
      'receipt': true,
      'itemPhoto': true,
      'handoffVerified': false,
      'pin': id == 'anna' ? '123456' : null,
      'cancellationReason': null,
      'history': {'5': '2026-10-07T01:00:00Z'},
    },
  ],
  'wallet': {
    'available': id == 'anna' ? 900 : 450,
    'totalEarnings': 0,
    'refunds': 0,
  },
  'transactions': [],
  'notifications': [],
  'messages': [],
  'reviews': [],
  'reports': [],
  'saved': [],
  'friends': [],
  'favorites': [],
  'blocked': [],
};

http.Response response(Map<String, dynamic> value, [int code = 200]) =>
    http.Response(
      jsonEncode(value),
      code,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('database store starts empty and switches authenticated accounts while clearing the PIN', () async {
    final actions = <String>[];
    final client = MockClient((request) async {
      final data = jsonDecode(request.body);
      actions.add(data['action']);
      if (data['action'] == 'health') {
        return response({'ok': true, 'demo': true});
      }
      return response({'token': 'a' * 64, 'state': stateFor(data['userId'])});
    });
    final s = ErrandStore.mysql(
      ErrandApi(url: 'http://localhost/api', client: client),
    );
    addTearDown(s.dispose);
    expect(s.errands, isEmpty);
    await s.initialize();
    expect(s.databaseReady, isTrue);
    expect(s.currentId, isNull);
    await s.demo('anna');
    final openTask = s.errands.single;
    expect(openTask.pin, '123456');
    expect(s.wallet.available, 900);
    await s.demo('ben');
    expect(identical(openTask, s.errands.single), isTrue);
    expect(openTask.pin, isNull);
    expect(s.wallet.available, 450);
    expect(s.users['anna']!.password, isEmpty);
    expect(s.wallets.keys, ['ben']);
    expect(actions, ['health', 'demo', 'demo']);
  });

  test(
    'failed server actions preserve the task and expose the save failure',
    () async {
      final client = MockClient((request) async {
        final data = jsonDecode(request.body);
        if (data['action'] == 'demo') {
          return response({
            'token': 'b' * 64,
            'state': stateFor('ben', status: 'posted'),
          });
        }
        expect(request.headers['Authorization'], 'Bearer ${'b' * 64}');
        return response({'error': 'This errand is no longer available.'}, 409);
      });
      final s = ErrandStore.mysql(
        ErrandApi(url: 'http://localhost/api', client: client),
      );
      addTearDown(s.dispose);
      await s.demo();
      final task = s.errands.single;
      await expectLater(s.accept(task), throwsStateError);
      expect(task.status, ErrandStatus.posted);
      expect(s.wallet.available, 450);
      expect(s.connectionError, contains('no longer available'));
      expect(s.busy, isFalse);
    },
  );

  test('server identity replaces the client registration id and errors never seed fallback data', () async {
    final client = MockClient((request) async {
      final data = jsonDecode(request.body);
      expect(data['profile'].containsKey('password'), isFalse);
      expect(data['password'], 'test-password');
      final state = stateFor('anna');
      state['currentId'] = 'server-user';
      state['users'][0]['id'] = 'server-user';
      return response({'token': 'c' * 64, 'state': state});
    });
    final s = ErrandStore.mysql(
      ErrandApi(url: 'http://localhost/api', client: client),
    );
    addTearDown(s.dispose);
    await s.register(
      UserProfile(
        id: 'client-id',
        name: 'Anna',
        email: 'anna@example.com',
        password: 'test-password',
      ),
    );
    expect(s.currentId, 'server-user');
    expect(s.users.containsKey('client-id'), isFalse);

    final failed = ErrandStore.mysql(
      ErrandApi(
        url: 'http://localhost/api',
        client: MockClient(
          (_) async =>
              response({'error': 'Database service unavailable.'}, 503),
        ),
      ),
    );
    addTearDown(failed.dispose);
    await failed.initialize();
    expect(failed.errands, isEmpty);
    expect(failed.users, isEmpty);
    expect(failed.databaseReady, isFalse);
    expect(failed.connectionError, contains('unavailable'));
  });
}
