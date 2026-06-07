import 'package:flutter/foundation.dart';
import '../models/debt.dart';
import '../services/debt_service.dart';
import '../core/utils/app_event_bus.dart';

class DebtProvider with ChangeNotifier {
  final DebtService _service = DebtService();
  final _bus = AppEventBus();

  List<Debt> _debtsOwed = [];
  List<Debt> _debtsDue = [];
  Map<String, dynamic> _summary = {};
  bool _loading = false;
  String? _error;

  List<Debt> get debtsOwed => _debtsOwed;
  List<Debt> get debtsDue => _debtsDue;
  List<Debt> get unpaidDebtsOwed => _debtsOwed.where((d) => !d.isPaid).toList();
  List<Debt> get unpaidDebtsDue => _debtsDue.where((d) => !d.isPaid).toList();
  Map<String, dynamic> get summary => _summary;
  bool get loading => _loading;
  String? get error => _error;

  double get totalOwed => (_summary['total_owed'] as num?)?.toDouble() ?? 0;
  double get totalDue  => (_summary['total_due'] as num?)?.toDouble() ?? 0;
  double get netPosition => (_summary['net_position'] as num?)?.toDouble() ?? 0;

  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getDebtsOwed(),
        _service.getDebtsDue(),
        _service.getDebtsSummary(),
      ]);
      _debtsOwed = results[0] as List<Debt>;
      _debtsDue  = results[1] as List<Debt>;
      _summary   = results[2] as Map<String, dynamic>;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> addDebtOwed({
    required String personName, String? phone, required double amount,
    String? description, DateTime? dueDate, String? notes,
  }) async {
    try {
      await _service.addDebtOwed(Debt.create(
        personName: personName, phone: phone, amount: amount,
        description: description, dueDate: dueDate, notes: notes, type: DebtType.owed,
      ));
      await loadAll();
      _bus.emit(AppEvent.debtUpdated);
      return true;
    } catch (e) { _error = e.toString(); notifyListeners(); return false; }
  }

  Future<bool> updateDebtOwed(Debt debt) async {
    try {
      await _service.updateDebtOwed(debt);
      await loadAll();
      _bus.emit(AppEvent.debtUpdated);
      return true;
    } catch (e) { _error = e.toString(); notifyListeners(); return false; }
  }

  Future<bool> markDebtOwedAsPaid(String id) async {
    try {
      await _service.markDebtOwedAsPaid(id);
      await loadAll();
      _bus.emit(AppEvent.debtUpdated);
      return true;
    } catch (e) { _error = e.toString(); notifyListeners(); return false; }
  }

  Future<bool> deleteDebtOwed(String id) async {
    try {
      await _service.deleteDebtOwed(id);
      await loadAll();
      _bus.emit(AppEvent.debtUpdated);
      return true;
    } catch (e) { _error = e.toString(); notifyListeners(); return false; }
  }

  Future<bool> addDebtDue({
    required String personName, String? phone, required double amount,
    String? description, DateTime? dueDate, String? notes,
  }) async {
    try {
      await _service.addDebtDue(Debt.create(
        personName: personName, phone: phone, amount: amount,
        description: description, dueDate: dueDate, notes: notes, type: DebtType.due,
      ));
      await loadAll();
      _bus.emit(AppEvent.debtUpdated);
      return true;
    } catch (e) { _error = e.toString(); notifyListeners(); return false; }
  }

  Future<bool> updateDebtDue(Debt debt) async {
    try {
      await _service.updateDebtDue(debt);
      await loadAll();
      _bus.emit(AppEvent.debtUpdated);
      return true;
    } catch (e) { _error = e.toString(); notifyListeners(); return false; }
  }

  Future<bool> markDebtDueAsPaid(String id) async {
    try {
      await _service.markDebtDueAsPaid(id);
      await loadAll();
      _bus.emit(AppEvent.debtUpdated);
      return true;
    } catch (e) { _error = e.toString(); notifyListeners(); return false; }
  }

  Future<bool> deleteDebtDue(String id) async {
    try {
      await _service.deleteDebtDue(id);
      await loadAll();
      _bus.emit(AppEvent.debtUpdated);
      return true;
    } catch (e) { _error = e.toString(); notifyListeners(); return false; }
  }

  void clearError() { _error = null; notifyListeners(); }
}
