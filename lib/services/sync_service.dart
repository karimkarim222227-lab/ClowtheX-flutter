import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String get _userId => _auth.currentUser?.uid ?? 'guest';

  Future<void> syncData() async {
    if (_userId == 'guest') return;

    try {
      await _uploadPendingChanges();
      await _downloadNewChanges();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Sync Error: $e');
    }
  }

  Future<void> _uploadPendingChanges() async {
    final tables = [
      AppConstants.tableProducts, AppConstants.tableCategories, AppConstants.tableSales,
      AppConstants.tableSuppliers, AppConstants.tableCustomers, AppConstants.tableExpenses,
      AppConstants.tableDebtsOwed, AppConstants.tableDebtsDue
    ];

    for (final table in tables) {
      final pendingItems = await _dbHelper.rawQuery(
        'SELECT * FROM $table WHERE ${AppConstants.colSyncStatus} = ?',
        [AppConstants.syncStatusPending]
      );

      for (final item in pendingItems) {
        final data = Map<String, dynamic>.from(item);
        final id = data['id'];
        data[AppConstants.colUserId] = _userId;
        data[AppConstants.colSyncStatus] = AppConstants.syncStatusSynced;
        
        await _firestore.collection('users').doc(_userId).collection(table).doc(id).set(data);
        
        await _dbHelper.rawUpdate(
          'UPDATE $table SET ${AppConstants.colSyncStatus} = ? WHERE id = ?',
          [AppConstants.syncStatusSynced, id]
        );
      }
      
      // Handle soft deletes
      final deletedItems = await _dbHelper.rawQuery(
        'SELECT * FROM $table WHERE ${AppConstants.colIsDeleted} = 1'
      );
      
      for (final item in deletedItems) {
        await _firestore.collection('users').doc(_userId).collection(table).doc(item['id']).delete();
        await _dbHelper.delete(table, item['id']);
      }
    }
  }

  Future<void> _downloadNewChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('last_sync_time');
    
    final tables = [
      AppConstants.tableProducts, AppConstants.tableCategories, AppConstants.tableSales,
      AppConstants.tableSuppliers, AppConstants.tableCustomers, AppConstants.tableExpenses,
      AppConstants.tableDebtsOwed, AppConstants.tableDebtsDue
    ];

    for (final table in tables) {
      Query query = _firestore.collection('users').doc(_userId).collection(table);
      
      if (lastSyncStr != null) {
        query = query.where(AppConstants.colLastUpdated, isGreaterThan: lastSyncStr);
      }

      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        final cloudData = doc.data() as Map<String, dynamic>;
        final localData = await _dbHelper.getById(table, doc.id);

        if (localData == null || 
            (cloudData[AppConstants.colLastUpdated] as String).compareTo(localData[AppConstants.colLastUpdated] ?? '') > 0) {
          await _dbHelper.insert(table, cloudData);
        }
      }
    }
  }

  Future<void> restoreFromCloud() async {
    if (_userId == 'guest') return;
    
    final tables = [
      AppConstants.tableProducts, AppConstants.tableCategories, AppConstants.tableSales,
      AppConstants.tableSuppliers, AppConstants.tableCustomers, AppConstants.tableExpenses,
      AppConstants.tableDebtsOwed, AppConstants.tableDebtsDue
    ];

    for (final table in tables) {
      final snapshot = await _firestore.collection('users').doc(_userId).collection(table).get();
      for (final doc in snapshot.docs) {
        await _dbHelper.insert(table, doc.data());
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
  }
}
