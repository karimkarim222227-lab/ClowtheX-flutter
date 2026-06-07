import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../models/product.dart';
import '../models/category.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class ProductService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Product>> getAllProducts({bool activeOnly = true}) async {
    final whereClause = activeOnly ? 'WHERE p.is_active = 1' : '';
    final rows = await _db.rawQuery('''
      SELECT p.*, c.name as category_name, s.name as supplier_name
      FROM ${AppConstants.tableProducts} p
      LEFT JOIN ${AppConstants.tableCategories} c ON p.category_id = c.id
      LEFT JOIN ${AppConstants.tableSuppliers} s ON p.supplier_id = s.id
      $whereClause ORDER BY p.name ASC
    ''');
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<Product?> getByBarcode(String barcode) async {
    final rows = await _db.rawQuery('''
      SELECT p.*, c.name as category_name, s.name as supplier_name
      FROM ${AppConstants.tableProducts} p
      LEFT JOIN ${AppConstants.tableCategories} c ON p.category_id = c.id
      LEFT JOIN ${AppConstants.tableSuppliers} s ON p.supplier_id = s.id
      WHERE p.barcode = ?
    ''', [barcode]);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  /// ✅ FIX: إضافة منتج مع التحقق من الباركود المكرر
  Future<String> addProduct(Product product) async {
    // تحقق من الباركود المكرر
    if (product.barcode != null && product.barcode!.isNotEmpty) {
      final existing = await getByBarcode(product.barcode!);
      if (existing != null) {
        throw Exception('الباركود موجود مسبقاً: ${existing.name}');
      }
    }

    // التحقق من صحة البيانات الأساسية
    if (product.name.trim().isEmpty) throw Exception('اسم المنتج لا يمكن أن يكون فارغاً');
    if (product.salePrice < product.purchasePrice) throw Exception('سعر البيع أقل من سعر الشراء');
    if (product.quantity < 0) throw Exception('الكمية لا يمكن أن تكون سالبة');

    try {
      Product toInsert = product;
      if (product.imagePath != null && product.imagePath!.isNotEmpty) {
        final src = product.imagePath!;
        if (await File(src).exists()) {
          final copied = await _copyImageToAppDir(src);
          toInsert = product.copyWith(imagePath: copied);
        }
      }
      return await _db.insert(AppConstants.tableProducts, toInsert.toMap());
    } on sqflite.DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw Exception('خطأ: قد يكون الباركود أو SKU موجود مسبقاً');
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    // تحقق من تعارض الباركود مع منتجات أخرى
    if (product.barcode != null && product.barcode!.isNotEmpty) {
      final existing = await _db.rawQuery(
        'SELECT id FROM ${AppConstants.tableProducts} WHERE barcode = ? AND id != ?',
        [product.barcode, product.id]);
      if (existing.isNotEmpty) {
        throw Exception('الباركود مستخدم من قبل منتج آخر');
      }
    }

    // تحقق من صحة البيانات الأساسية
    if (product.name.trim().isEmpty) throw Exception('اسم المنتج لا يمكن أن يكون فارغاً');
    if (product.salePrice < product.purchasePrice) throw Exception('سعر البيع أقل من سعر الشراء');
    if (product.quantity < 0) throw Exception('الكمية لا يمكن أن تكون سالبة');

    try {
      // احصل على المنتج القديم لحذف الصورة إذا تغيّرت
      final existing = await _db.getById(AppConstants.tableProducts, product.id);
      String? oldImage = existing?['image_path'] as String?;

      Product toUpdate = product;
      if (product.imagePath != null && product.imagePath!.isNotEmpty && product.imagePath != oldImage) {
        final src = product.imagePath!;
        if (await File(src).exists()) {
          final copied = await _copyImageToAppDir(src);
          toUpdate = product.copyWith(imagePath: copied);
        }
      }

      await _db.update(AppConstants.tableProducts, toUpdate.toMap(), product.id);

      // حذف الصورة القديمة إن وجدت واختلفت
      if (oldImage != null && oldImage.isNotEmpty && oldImage != toUpdate.imagePath) {
        try {
          final f = File(oldImage);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    } on sqflite.DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw Exception('خطأ: قد يكون الباركود أو SKU مستخدماً');
      }
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    // حذف ملف الصورة إن وُجد
    try {
      final existing = await _db.getById(AppConstants.tableProducts, id);
      final img = existing?['image_path'] as String?;
      if (img != null && img.isNotEmpty) {
        try {
          final f = File(img);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
    await _db.delete(AppConstants.tableProducts, id);
  }

  Future<String> _copyImageToAppDir(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) throw Exception('ملف الصورة غير موجود');
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'product_images'));
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
    final ext = p.extension(sourcePath);
    final newName = '${const Uuid().v4()}$ext';
    final newPath = p.join(imagesDir.path, newName);
    await src.copy(newPath);
    return newPath;
  }

  Future<Map<String, dynamic>> getInventoryStats() async {
    final result = await _db.rawQuery('''
      SELECT
        COUNT(*) as total_products,
        COALESCE(SUM(CASE WHEN quantity <= min_quantity THEN 1 ELSE 0 END), 0) as low_stock,
        COALESCE(SUM(CASE WHEN quantity = 0 THEN 1 ELSE 0 END), 0) as out_of_stock,
        COALESCE(SUM(quantity * purchase_price), 0) as total_cost_value,
        COALESCE(SUM(quantity * sale_price), 0) as total_sale_value
      FROM ${AppConstants.tableProducts}
      WHERE is_active = 1
    ''');
    return result.isNotEmpty ? result.first : {
      'total_products': 0, 'low_stock': 0, 'out_of_stock': 0,
      'total_cost_value': 0.0, 'total_sale_value': 0.0,
    };
  }

  // Categories
  Future<List<Category>> getAllCategories() async {
    final rows = await _db.getAll(AppConstants.tableCategories);
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  Future<void> addCategory(Category cat) async {
    await _db.insert(AppConstants.tableCategories, cat.toMap());
  }

  Future<void> updateCategory(Category cat) async {
    await _db.update(AppConstants.tableCategories, cat.toMap(), cat.id);
  }

  Future<void> deleteCategory(String id) async {
    await _db.delete(AppConstants.tableCategories, id);
  }
}
