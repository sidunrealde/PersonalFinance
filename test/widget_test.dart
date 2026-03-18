import 'package:flutter_test/flutter_test.dart';

import 'package:personal_finance/core/utils/money.dart';

void main() {
  group('Money', () {
    test('formats Indian currency correctly', () {
      expect(const Money(12345678).format(), '₹1,23,456.78');
    });

    test('fromRupees converts correctly', () {
      expect(Money.fromRupees(500.50).paise, 50050);
    });

    test('zero value', () {
      expect(Money.zero.format(), '₹0.00');
    });

    test('arithmetic', () {
      const a = Money(10000);
      const b = Money(5000);
      expect((a + b).paise, 15000);
      expect((a - b).paise, 5000);
    });

    test('negative formatting', () {
      expect(const Money(-12345678).format(), '-₹1,23,456.78');
    });
  });
}
