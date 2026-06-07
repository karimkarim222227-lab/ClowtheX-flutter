import 'package:flutter_test/flutter_test.dart';
import 'package:clowthex/models/product.dart';

void main() {
  test('Product create -> toMap -> fromMap -> copyWith and getters', () {
    final p = Product.create(
      name: 'قميص',
      barcode: '12345',
      purchasePrice: 10.0,
      salePrice: 15.0,
      quantity: 5,
      minQuantity: 2,
      size: 'M',
      color: 'أسود',
      brand: 'ماركة',
      imagePath: null,
    );

    final map = p.toMap();
    final from = Product.fromMap(map);

    expect(from.name, equals(p.name));
    expect(from.barcode, equals(p.barcode));
    expect(from.purchasePrice, equals(10.0));
    expect(from.salePrice, equals(15.0));
    expect(from.quantity, equals(5));
    expect(from.isLowStock, equals(false));

    final copied = from.copyWith(name: 'قميص جديد', imagePath: '/tmp/img.png');
    expect(copied.name, equals('قميص جديد'));
    expect(copied.imagePath, equals('/tmp/img.png'));
  });
}
