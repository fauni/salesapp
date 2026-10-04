import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/data/models/item.dart';

void main() {
  const item = Item(code: 'A', name: 'Aceite', litersPerUnit: 10);

  group('Item.quantityForLiters', () {
    test('exact multiple -> units', () {
      expect(item.quantityForLiters(10), 1);
      expect(item.quantityForLiters(30), 3);
    });

    test('non-multiple -> null', () {
      expect(item.quantityForLiters(25), isNull);
      expect(item.quantityForLiters(5), isNull);
    });

    test('zero/negative -> null', () {
      expect(item.quantityForLiters(0), isNull);
      expect(item.quantityForLiters(-10), isNull);
    });

    test('tolerates float noise on fractional liters per unit', () {
      const small = Item(code: 'B', name: 'B', litersPerUnit: 0.1);
      expect(small.quantityForLiters(0.3), 3);
    });

    test('item without liters per unit is not sold by liters', () {
      const plain = Item(code: 'C', name: 'C');
      expect(plain.sellsByLiters, isFalse);
      expect(plain.quantityForLiters(10), isNull);
    });
  });
}
