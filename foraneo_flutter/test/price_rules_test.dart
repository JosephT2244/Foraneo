import 'package:flutter_test/flutter_test.dart';
import 'package:foraneo/models.dart';

void main() {
  test('inclusive price boundaries work with decimal currency', () {
    for (final pair in [
      (3.4, 3.74),
      (75.25, 81.27),
      (100.25, 104.26),
      (201.0, 207.03),
      (500.5, 510.51),
      (1001.0, 1011.01),
    ]) {
      expect(decidePrice(pair.$1, pair.$2).title, 'No lo compres');
      expect(decidePrice(pair.$1, pair.$2 - .01).title, 'Compra autorizada');
    }
    for (final pair in [
      (3.4, 2.89),
      (75.2, 63.92),
      (100.2, 85.17),
      (201.1, 180.99),
      (500.5, 450.45),
      (1001.1, 900.99),
    ]) {
      expect(decidePrice(pair.$1, pair.$2).title, '¡Cómpralo!');
      expect(decidePrice(pair.$1, pair.$2 + .01).title, 'Compra autorizada');
    }
    expect(decidePrice(75.25, 81.27 - .000001).title, 'Compra autorizada');
    expect(decidePrice(3.4, 2.89 + .000001).title, 'Compra autorizada');
  });

  test('decimal boundary survives normalization across package sizes', () {
    final equivalent = comparablePrice(
      referenceAmount: 250,
      referenceUnit: 'g',
      offeredAmount: .5,
      offeredUnit: 'kg',
      offeredPrice: 162.54,
    );
    expect(equivalent, isNotNull);
    expect(decidePrice(75.25, equivalent!).title, 'No lo compres');
  });

  test('invalid content and incompatible units cannot be compared', () {
    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        comparablePrice(
          referenceAmount: 250,
          referenceUnit: 'g',
          offeredAmount: amount,
          offeredUnit: 'kg',
          offeredPrice: 40,
        ),
        isNull,
      );
      expect(
        comparablePrice(
          referenceAmount: amount,
          referenceUnit: 'g',
          offeredAmount: .5,
          offeredUnit: 'kg',
          offeredPrice: 40,
        ),
        isNull,
      );
    }
    for (final unit in ['ml', 'L', 'pieza', 'rollo', '']) {
      expect(
        comparablePrice(
          referenceAmount: 250,
          referenceUnit: 'g',
          offeredAmount: .5,
          offeredUnit: unit,
          offeredPrice: 40,
        ),
        isNull,
      );
    }
    for (final price in [-1.0, double.nan, double.infinity]) {
      expect(
        comparablePrice(
          referenceAmount: 250,
          referenceUnit: 'g',
          offeredAmount: .5,
          offeredUnit: 'kg',
          offeredPrice: price,
        ),
        isNull,
      );
    }
  });
}
