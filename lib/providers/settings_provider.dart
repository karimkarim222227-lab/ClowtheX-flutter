import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/utils/app_event_bus.dart';

class SettingsProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  final _bus = AppEventBus();

  String _storeName    = AppConstants.defaultStoreName;
  String _storePhone   = '';
  String _storeAddress = '';
  String _currency     = AppConstants.defaultCurrency;
  double _taxRate      = 0;
  bool   _taxEnabled   = false;
  int    _lowStockAlert = AppConstants.defaultLowStockAlert;
  bool   _loaded       = false;

  String get storeName     => _storeName;
  String get storePhone    => _storePhone;
  String get storeAddress  => _storeAddress;
  String get currency      => _currency;
  double get taxRate       => _taxRate;
  bool get taxEnabled      => _taxEnabled;
  int    get lowStockAlert => _lowStockAlert;
  bool   get loaded        => _loaded;

  /// ✅ FIX: استعلام واحد بدل 6 استعلامات منفصلة
  Future<void> load() async {
    final rows = await _db.rawQuery('SELECT key, value FROM ${AppConstants.tableSettings}');
    final map = {for (final r in rows) r['key'] as String: r['value'] as String? ?? ''};

    _storeName    = map[AppConstants.keyStoreName]    ?? AppConstants.defaultStoreName;
    _storePhone   = map[AppConstants.keyStorePhone]   ?? '';
    _storeAddress = map[AppConstants.keyStoreAddress] ?? '';
    _currency     = map[AppConstants.keyCurrency]     ?? AppConstants.defaultCurrency;
    _taxRate      = double.tryParse(map[AppConstants.keyTaxRate] ?? '0') ?? 0;
    _taxEnabled   = (map[AppConstants.keyTaxEnabled] ?? 'false').toLowerCase() == 'true';
    _lowStockAlert = int.tryParse(map[AppConstants.keyLowStockAlert] ?? '5') ?? 5;
    _loaded = true;
    notifyListeners();
  }

  Future<void> updateStoreName(String v) async {
    _storeName = v; await _db.setSetting(AppConstants.keyStoreName, v);
    notifyListeners(); _bus.emit(AppEvent.settingsUpdated);
  }
  Future<void> updateStorePhone(String v) async {
    _storePhone = v; await _db.setSetting(AppConstants.keyStorePhone, v);
    notifyListeners(); _bus.emit(AppEvent.settingsUpdated);
  }
  Future<void> updateStoreAddress(String v) async {
    _storeAddress = v; await _db.setSetting(AppConstants.keyStoreAddress, v);
    notifyListeners(); _bus.emit(AppEvent.settingsUpdated);
  }
  Future<void> updateCurrency(String v) async {
    _currency = v; await _db.setSetting(AppConstants.keyCurrency, v);
    notifyListeners(); _bus.emit(AppEvent.settingsUpdated);
  }
  Future<void> updateTaxRate(double v) async {
    _taxRate = v; await _db.setSetting(AppConstants.keyTaxRate, v.toString());
    notifyListeners(); _bus.emit(AppEvent.settingsUpdated);
  }
  Future<void> updateTaxEnabled(bool enabled) async {
    _taxEnabled = enabled; await _db.setSetting(AppConstants.keyTaxEnabled, enabled.toString());
    notifyListeners(); _bus.emit(AppEvent.settingsUpdated);
  }
  Future<void> updateLowStockAlert(int v) async {
    _lowStockAlert = v; await _db.setSetting(AppConstants.keyLowStockAlert, v.toString());
    notifyListeners(); _bus.emit(AppEvent.settingsUpdated);
  }
}
