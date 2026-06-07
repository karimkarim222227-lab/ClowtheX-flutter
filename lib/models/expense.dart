import 'package:uuid/uuid.dart';

enum ExpenseType { general, salary, utilities, supplies, marketing, other }

extension ExpenseTypeExtension on ExpenseType {
  String get typeText {
    switch (this) {
      case ExpenseType.salary:
        return 'رواتب';
      case ExpenseType.utilities:
        return 'فواتير';
      case ExpenseType.supplies:
        return 'لوازم';
      case ExpenseType.marketing:
        return 'تسويق';
      case ExpenseType.other:
        return 'أخرى';
      case ExpenseType.general:
      default:
        return 'عام';
    }
  }

  String get typeIcon {
    switch (this) {
      case ExpenseType.salary:
        return '💼';
      case ExpenseType.utilities:
        return '⚡';
      case ExpenseType.supplies:
        return '📦';
      case ExpenseType.marketing:
        return '📣';
      case ExpenseType.other:
        return '🔧';
      case ExpenseType.general:
      default:
        return '💰';
    }
  }
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final ExpenseType type;
  final String? category;
  final String? notes;
  final DateTime date;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    this.type = ExpenseType.general,
    this.category,
    this.notes,
    required this.date,
    required this.createdAt,
  });

  factory Expense.create({
    required String title,
    required double amount,
    ExpenseType type = ExpenseType.general,
    String? category,
    String? notes,
    DateTime? date,
  }) {
    final now = DateTime.now();
    return Expense(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      type: type,
      category: category,
      notes: notes,
      date: date ?? now,
      createdAt: now,
    );
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: _parseExpenseType(map['expense_type'] as String?),
      category: map['category'] as String?,
      notes: map['notes'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static ExpenseType _parseExpenseType(String? value) {
    switch (value) {
      case 'salary':
        return ExpenseType.salary;
      case 'utilities':
        return ExpenseType.utilities;
      case 'supplies':
        return ExpenseType.supplies;
      case 'marketing':
        return ExpenseType.marketing;
      case 'other':
        return ExpenseType.other;
      case 'general':
      default:
        return ExpenseType.general;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'expense_type': type.name,
      'category': category,
      'notes': notes,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get typeIcon => type.typeIcon;
  String get typeText => type.typeText;
}
