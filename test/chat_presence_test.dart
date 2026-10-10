import 'package:flutter_test/flutter_test.dart';
import 'package:property24_zimbabwe/models/rental_models.dart';

void main() {
  group('AccountUser chat presence', () {
    test('accepts a recently active user as online', () {
      final user = AccountUser.fromJson({
        'id': '42',
        'name': 'Property owner',
        'online': true,
        'last_seen_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(seconds: 10))
            .toIso8601String(),
      });

      expect(user.isCurrentlyOnline, isTrue);
    });

    test('does not show stale online activity as current', () {
      final user = AccountUser.fromJson({
        'id': '42',
        'name': 'Property owner',
        'online': true,
        'last_seen_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 2))
            .toIso8601String(),
      });

      expect(user.isCurrentlyOnline, isFalse);
    });
  });
}
