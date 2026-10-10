import 'package:flutter_test/flutter_test.dart';
import 'package:errandly/state/errand_store.dart';

void main() {
  test('pre-accept inquiries remain private after another runner accepts', () {
    final s = ErrandStore()..demo();
    final e = s.errands.first;
    s.messages.clear();
    s.send(e, 'Ben inquiry');
    s.demo('maria');
    s.send(e, 'Maria inquiry');
    expect(s.conversationMessages(e, 'anna').map((m) => m.text), [
      'Maria inquiry',
    ]);
    s.demo('anna');
    expect(s.conversations.where((t) => t.$1.id == e.id).map((t) => t.$2), [
      'ben',
      'maria',
    ]);
    s.send(e, 'Reply to Ben', recipientId: 'ben');
    s.send(e, 'Reply to Maria', recipientId: 'maria');
    expect(
      () => s.send(e, 'Unsolicited', recipientId: 'joshua'),
      throwsStateError,
    );
    s.demo('ben');
    s.accept(e);
    expect(s.conversationMessages(e, 'anna').map((m) => m.text), [
      'Ben inquiry',
      'Reply to Ben',
    ]);
    s.demo('maria');
    s.send(e, 'Thanks anyway');
    expect(s.conversationMessages(e, 'anna').map((m) => m.text), [
      'Maria inquiry',
      'Reply to Maria',
      'Thanks anyway',
    ]);
    s.demo('joshua');
    expect(s.conversationMessages(e, 'anna'), isEmpty);
    expect(s.conversations.where((t) => t.$1.id == e.id), isEmpty);
    expect(() => s.send(e, 'Late inquiry'), throwsStateError);
  });

  test('private chat rejects redirected and blocked messages', () {
    final s = ErrandStore()..demo();
    final e = s.errands.first;
    expect(
      () => s.send(e, 'Redirected', recipientId: 'maria'),
      throwsStateError,
    );
    s.blocked['anna'] = {'ben'};
    expect(() => s.send(e, 'Blocked'), throwsStateError);
    expect(s.messages.where((m) => m.text == 'Blocked'), isEmpty);
  });
}
