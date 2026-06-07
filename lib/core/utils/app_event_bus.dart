import 'dart:async';

/// أنواع الأحداث في التطبيق
enum AppEvent {
  saleCompleted,    // اكتملت عملية بيع
  productUpdated,   // تغيّر المخزون
  debtUpdated,      // تغيّرت الديون
  expenseUpdated,   // تغيّرت المصروفات
  settingsUpdated,  // تغيّرت الإعدادات
}

/// ناقل الأحداث المركزي — Singleton
/// يتيح لأي Provider أو Screen الاستماع لأي حدث بدون اقتران مباشر
class AppEventBus {
  static final AppEventBus _instance = AppEventBus._internal();
  factory AppEventBus() => _instance;
  AppEventBus._internal();

  final _controller = StreamController<AppEvent>.broadcast();

  /// Stream للاشتراك في الأحداث
  Stream<AppEvent> get stream => _controller.stream;

  /// Stream مُصفَّى لحدث واحد فقط
  Stream<AppEvent> on(AppEvent event) =>
      _controller.stream.where((e) => e == event);

  /// إطلاق حدث
  void emit(AppEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }
}
