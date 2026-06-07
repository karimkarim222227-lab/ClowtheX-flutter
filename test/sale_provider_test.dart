import 'package:flutter_test/flutter_test.dart';
import 'package:clowthex/providers/sale_provider.dart';
import 'package:clowthex/models/product.dart';
import 'package:clowthex/models/sale.dart';
import 'package:clowthex/services/sale_service.dart';

class FakeSaleService implements SaleServiceBase {
  @override
  Future<Sale> completeSale({required List<CartItem> cartItems, String? customerId, String? customerName, double discount = 0, DiscountType discountType = DiscountType.fixed, double taxRate = 0, double paid = 0, PaymentMethod paymentMethod = PaymentMethod.cash, String? notes}) async {
    return Sale(
      id: 's1', invoiceNumber: 'INV-FAKE', customerId: customerId, customerName: customerName,
      items: cartItems.map((c) => c.toSaleItem('s1')).toList(), subtotal: 100, discount: discount, discountType: discountType,
      tax: taxRate, total: 100, paid: paid, changeAmount: (paid - 100).clamp(0, double.infinity), paymentMethod: paymentMethod,
      notes: notes, status: SaleStatus.completed, createdAt: DateTime.now(), updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Sale>> getAllSales({int limit = 200, int offset = 0}) async {
    return [];
  }

  // Other methods can throw if called in tests
  @override
  Future<Sale?> getSaleById(String id) => throw UnimplementedError();
  @override
  Future<List<Sale>> getSalesByDateRange(DateTime from, DateTime to) => throw UnimplementedError();
  @override
  Future<void> returnSale(String saleId) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getTodayStats() => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> getTopProducts({int limit = 10, DateTime? from, DateTime? to}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> getDailySalesChart({int days = 30}) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getProfitSummary({DateTime? from, DateTime? to}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> getProfitByDay({int days = 30}) => throw UnimplementedError();
  @override
  Future<List<Map<String, dynamic>>> getProfitByMonth({int months = 6}) => throw UnimplementedError();
}

void main() {
  test('SaleProvider cart operations and completeSale', () async {
    final fake = FakeSaleService();
    final provider = SaleProvider(service: fake);

    final p = Product.create(name: 'قميص', purchasePrice: 10, salePrice: 20, quantity: 5);
    provider.addToCart(p, quantity: 2);
    expect(provider.cartCount, equals(2));
    expect(provider.subtotal, equals(40));

    provider.setTaxEnabled(false);
    provider.setPaymentMethod(PaymentMethod.card);
    // since card sets paid to total automatically
    expect(provider.paid, equals(provider.total));

    final sale = await provider.completeSale();
    expect(sale.invoiceNumber, equals('INV-FAKE'));
    expect(provider.cartCount, equals(0));
  });
}
