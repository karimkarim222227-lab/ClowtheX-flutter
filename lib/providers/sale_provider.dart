import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../services/sale_service.dart';
import '../core/utils/app_event_bus.dart';

class SaleException implements Exception {
  final String message;
  SaleException(this.message);
  @override
  String toString() => message;
}

class SaleProvider with ChangeNotifier {
  final dynamic _service; // SaleServiceBase (use dynamic to avoid import cycles in tests)
  SaleProvider({dynamic service}) : _service = service ?? (SaleService());
  final _bus = AppEventBus();

  // ─── Cart state ───────────────────────────────────────────────────────────
  final List<CartItem> _cart = [];
  String? _customerId;
  String? _customerName;
  double _discount = 0;
  DiscountType _discountType = DiscountType.fixed;
  double _taxRate = 0;
  bool _taxEnabled = false;
  double _paid = 0;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String? _notes;
  String? _errorMessage;

  // ─── Sales history ────────────────────────────────────────────────────────
  List<Sale> _sales = [];
  bool _loading = false;

  // ─── Getters ──────────────────────────────────────────────────────────────
  List<CartItem> get cart => List.unmodifiable(_cart);
  List<Sale> get sales => _sales;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  String? get customerId => _customerId;
  String? get customerName => _customerName;
  double get discount => _discount;
  DiscountType get discountType => _discountType;
  double get taxRate => _taxRate;
  bool get taxEnabled => _taxEnabled;
  double get paid => _paid;
  PaymentMethod get paymentMethod => _paymentMethod;
  String? get notes => _notes;

  double get subtotal => _cart.fold(0, (s, i) => s + (i.unitPrice * i.quantity));

  // ✅ FIX: الخصم لا يتجاوز المجموع أبداً
  double get discountAmount {
    final amt = _discountType == DiscountType.percentage
        ? subtotal * (_discount / 100)
        : _discount;
    return amt.clamp(0, subtotal);
  }

  double get afterDiscount => subtotal - discountAmount;
  double get taxAmount => _taxEnabled ? afterDiscount * (_taxRate / 100) : 0;
  double get total => afterDiscount + taxAmount;
  double get change => (_paid - total).clamp(0, double.infinity);
  int get cartCount => _cart.fold(0, (s, i) => s + i.quantity);

  // ─── Cart Management ──────────────────────────────────────────────────────

  void addToCart(Product product, {int quantity = 1}) {
    final existing = _cart.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      final item = _cart[existing];
      // ✅ FIX: لا تتجاوز الكمية المتاحة
      final newQty = item.quantity + quantity;
      if (newQty <= product.quantity) {
        _cart[existing] = CartItem(
          productId: item.productId, productName: item.productName,
          barcode: item.barcode, unitPrice: item.unitPrice,
          purchasePrice: item.purchasePrice, quantity: newQty, discount: item.discount,
          maxQuantity: product.quantity,
        );
      }
    } else {
      if (product.quantity > 0) {
        _cart.add(CartItem(
          productId: product.id, productName: product.name,
          barcode: product.barcode, unitPrice: product.salePrice,
          purchasePrice: product.purchasePrice, quantity: quantity,
          maxQuantity: product.quantity,
        ));
      }
    }
    notifyListeners();
  }

  void updateCartItemQuantity(String productId, int quantity) {
    final idx = _cart.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    if (quantity <= 0) {
      _cart.removeAt(idx);
    } else {
      // ✅ FIX: لا تتجاوز الكمية المتاحة في المخزون
      final max = _cart[idx].maxQuantity;
      _cart[idx] = _cart[idx].copyWith(quantity: quantity.clamp(1, max));
    }
    notifyListeners();
  }

  void updateCartItemPrice(String productId, double price) {
    final idx = _cart.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    final item = _cart[idx];
    _cart[idx] = CartItem(
      productId: item.productId, productName: item.productName,
      barcode: item.barcode, unitPrice: price,
      purchasePrice: item.purchasePrice, quantity: item.quantity,
      discount: item.discount, maxQuantity: item.maxQuantity,
    );
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _discount = 0;
    _discountType = DiscountType.fixed;
    _paid = 0;
    _notes = null;
    _customerId = null;
    _customerName = null;
    notifyListeners();
  }

  void setCustomer(String? id, String? name) {
    _customerId = id; _customerName = name; notifyListeners();
  }

  void setDiscount(double value, DiscountType type) {
    _discount = value.clamp(0, double.infinity);
    _discountType = type;
    notifyListeners();
  }

  // ✅ FIX: الضريبة تُطبَّق تلقائياً من الإعدادات
  void setTaxRate(double rate) {
    _taxRate = rate.clamp(0, 100);
    notifyListeners();
  }

  void setTaxEnabled(bool enabled) {
    _taxEnabled = enabled;
    notifyListeners();
  }

  void setPaid(double amount) {
    _paid = amount.clamp(0, double.infinity);
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    // نقداً → المبلغ المدفوع يُدخله المستخدم
    // بطاقة/تحويل → المبلغ المدفوع = الإجمالي تلقائياً
    if (method != PaymentMethod.cash) setPaid(total);
    notifyListeners();
  }

  void setNotes(String? notes) { _notes = notes; notifyListeners(); }

  void clearError() { _errorMessage = null; notifyListeners(); }

  // ─── Sale Operations ──────────────────────────────────────────────────────

  Future<Sale> completeSale() async {
    if (_cart.isEmpty) throw SaleException('السلة فارغة');
    if (_paymentMethod == PaymentMethod.cash && _paid < total) {
      throw SaleException('المبلغ المدفوع أقل من الإجمالي');
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final cartCopy = _cart.map((item) => CartItem(
        productId: item.productId, productName: item.productName,
        barcode: item.barcode, unitPrice: item.unitPrice,
        purchasePrice: item.purchasePrice, quantity: item.quantity,
        discount: item.discount, maxQuantity: item.maxQuantity,
      )).toList();

      final sale = await _service.completeSale(
        cartItems: cartCopy,
        customerId: _customerId, customerName: _customerName,
        discount: _discount, discountType: _discountType,
        taxRate: _taxEnabled ? _taxRate : 0.0, paid: _paid,
        paymentMethod: _paymentMethod, notes: _notes,
      );

      clearCart();
      await loadSales();
      _bus.emit(AppEvent.saleCompleted); // 🔔 إشعار فوري لكل الشاشات
      return sale;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadSales({int limit = 200}) async {
    _loading = true;
    notifyListeners();
    try {
      _sales = await _service.getAllSales(limit: limit); // ✅ FIX: limit=200 بدل 50
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Sale?> getSaleById(String id) => _service.getSaleById(id);
  Future<List<Sale>> getSalesByDateRange(DateTime from, DateTime to) =>
      _service.getSalesByDateRange(from, to);
  Future<Map<String, dynamic>> getTodayStats() => _service.getTodayStats();
  Future<List<Map<String, dynamic>>> getTopProducts({int limit = 10}) =>
      _service.getTopProducts(limit: limit);
  Future<List<Map<String, dynamic>>> getDailySalesChart({int days = 30}) =>
      _service.getDailySalesChart(days: days);
  Future<Map<String, dynamic>> getProfitSummary({DateTime? from, DateTime? to}) =>
      _service.getProfitSummary(from: from, to: to);
  Future<List<Map<String, dynamic>>> getProfitByDay({int days = 30}) =>
      _service.getProfitByDay(days: days);
  Future<List<Map<String, dynamic>>> getProfitByMonth({int months = 6}) =>
      _service.getProfitByMonth(months: months);

  Future<void> returnSale(String id) async {
    await _service.returnSale(id);
    await loadSales();
    _bus.emit(AppEvent.saleCompleted);
  }
}
