import 'package:flutter_test/flutter_test.dart';
import 'package:clowthex/models/sale.dart';

void main() {
  test('CartItem -> toSaleItem and totals', () {
    final cart = CartItem(
      productId: 'p1', productName: 'قميص', barcode: 'b1',
      unitPrice: 20.0, purchasePrice: 10.0, quantity: 2, discount: 1.0,
    );

    final saleItem = cart.toSaleItem('s1');
    expect(saleItem.productId, equals('p1'));
    expect(cart.total, equals((20.0 - 1.0) * 2));
    expect(cart.profit, equals((20.0 - 10.0 - 1.0) * 2));
  });

  test('Sale toMap/fromMap roundtrip', () {
    final sale = Sale(
      id: 's1', invoiceNumber: 'INV-1',
      customerId: null, customerName: null,
      items: [], subtotal: 100, discount: 0, discountType: DiscountType.fixed,
      tax: 0, total: 100, paid: 100, changeAmount: 0,
      paymentMethod: PaymentMethod.cash, notes: null,
      status: SaleStatus.completed, createdAt: DateTime.now(), updatedAt: DateTime.now(),
    );

    final map = sale.toMap();
    final from = Sale.fromMap(map);
    expect(from.total, equals(100));
    expect(from.invoiceNumber, equals('INV-1'));
  });
}
