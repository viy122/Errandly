import 'package:flutter_test/flutter_test.dart';
import 'package:errandly/models/entities.dart';
import 'package:errandly/state/errand_store.dart';

void main() {
  test(
    'area filters include long-distance errands and unrestricted new addresses',
    () {
      final s = ErrandStore()..demo();
      expect(s.available.any((e) => e.distance >= 65000), isTrue);
      expect(distanceLabel(65000), '65 km');
      s.setBrowseArea('Metro Manila');
      expect(s.available, isNotEmpty);
      expect(s.available.every((e) => e.area == 'Metro Manila'), isTrue);
      final e = Errand(
        id: 'long-distance',
        ownerId: 'ben',
        title: 'Intercity delivery',
        category: 'Delivery',
        description: 'Deliver a sealed parcel',
        pickup: 'Custom pickup address, City A',
        destination: 'Custom delivery address, Province B',
        area: 'A new province',
        transport: 'Car',
        budget: 0,
        fee: 200,
        distance: 240000,
        deadline: DateTime.now().add(const Duration(days: 3)),
      );
      s.post(e, 'Errandly Wallet');
      expect(s.areaOptions, contains('A new province'));
      s.setBrowseArea('A new province');
      expect(s.available, [e]);
      expect(distanceLabel(e.distance), '240 km');
      expect(
        deadlineLabel(e.deadline),
        contains('${e.deadline.month}/${e.deadline.day}'),
      );
    },
  );
  test('yellow pad lifecycle pays only after requester confirmation', () {
    final s = ErrandStore()..demo();
    final e = s.errands.first;
    final benBefore = s.wallet.available;
    final annaBefore = s.wallets['anna']!.available;
    s.accept(e);
    expect(s.available, isNot(contains(e)));
    expect(() => s.accept(e), throwsStateError);
    expect(s.pending, 40);
    s.advance(e);
    s.advance(e);
    expect(() => s.advance(e), throwsStateError);
    expect(
      () => s.uploadProof(e, 51, receipt: true, photo: true),
      throwsStateError,
    );
    expect(
      () => s.uploadProof(e, 45, receipt: false, photo: true),
      throwsStateError,
    );
    s.uploadProof(e, 45, receipt: true, photo: true);
    s.advance(e);
    s.advance(e);
    s.advance(e);
    expect(e.pin, matches(r'^\d{6}$'));
    expect(() => s.verifyPin(e, '000000'), throwsStateError);
    s.verifyPin(e, e.pin!);
    expect(s.wallet.available, benBefore);
    expect(() => s.complete(e), throwsStateError);
    s.demo('anna');
    s.complete(e);
    expect(e.status, ErrandStatus.completed);
    expect(s.wallet.available, annaBefore);
    expect(s.pesoRefunds, 5);
    expect(
      s.transactions
          .singleWhere(
            (t) => t.userId == 'ben' && t.type == 'Purchase Reimbursement',
          )
          .amount,
      45,
    );
    expect(s.wallets['ben']!.available, benBefore + 40);
    expect(() => s.complete(e), throwsStateError);
    expect(
      s.transactions
          .where(
            (t) =>
                t.userId == 'ben' &&
                t.type == 'Runner Earnings' &&
                t.note == e.title,
          )
          .length,
      1,
    );
    s.rate(e, 5, 'Great work!', {'Communication': 5});
    expect(() => s.rate(e, 5, 'Again', {}), throwsStateError);
  });
  test(
    'top-up and cash-out apply distinct conversions and reject invalid amounts',
    () {
      final s = ErrandStore()..demo();
      s.topUp(100);
      expect(s.wallet.available, 560);
      s.cashOut(220, '09171234567');
      expect(s.wallet.available, 340);
      expect(s.transactions.first.note, contains('₱160'));
      expect(() => s.cashOut(400, '09171234567'), throwsStateError);
      expect(() => s.cashOut(double.nan, '09171234567'), throwsStateError);
      expect(() => s.cashOut(10, 'bad'), throwsStateError);
    },
  );
  test(
    'unaccepted cancellation refunds once; accepted cancellation opens review',
    () {
      final s = ErrandStore()..demo('anna');
      final e = s.errands.first;
      final before = s.wallet.available;
      s.cancel(e, 'No longer needed');
      expect(s.wallet.available, before + 45);
      expect(s.pesoRefunds, 50);
      expect(() => s.cancel(e, 'Other'), throwsStateError);
      final accepted = s.errands[3];
      s.demo();
      s.accept(accepted);
      s.demo('anna');
      final balance = s.wallet.available;
      s.cancel(accepted, 'Other');
      expect(accepted.status, ErrandStatus.accepted);
      expect(s.wallet.available, balance);
      expect(s.reports.last.status, 'Submitted');
    },
  );
  test('posting secures funds and expiry refunds them once', () {
    final s = ErrandStore()..demo();
    final before = s.wallet.available;
    final e = Errand(
      id: 'new',
      ownerId: 'ben',
      title: 'Help',
      category: 'Delivery',
      description: 'Bring a book',
      pickup: 'CICS Building',
      destination: 'Library',
      budget: 0,
      fee: 25,
      distance: 100,
      deadline: DateTime.now().add(const Duration(hours: 1)),
    );
    s.post(e, 'Errandly Wallet');
    expect(s.wallet.available, before - 30);
    expect(s.locked, 25);
    expect(() => s.accept(e), throwsStateError);
    s.simulateExpiry(e);
    expect(s.wallet.available, before);
    expect(() => s.simulateExpiry(e), throwsStateError);
  });
  test(
    'registration requires verification for transactions and isolates wallets',
    () {
      final s = ErrandStore();
      s.register(
        UserProfile(
          id: 'new',
          name: 'New UserProfile',
          email: 'new@school.edu',
          verified: false,
        ),
      );
      expect(s.wallet.available, 0);
      expect(() => s.accept(s.errands.first), throwsStateError);
      expect(() => s.verify(), throwsStateError);
      s.user.emailVerified = true;
      s.user.phoneVerified = true;
      s.user.idVerified = true;
      s.verify();
      s.accept(s.errands.first);
      expect(s.pending, 40);
      expect(s.wallets['ben']!.available, 450);
    },
  );
}
