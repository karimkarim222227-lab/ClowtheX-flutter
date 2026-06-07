import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _service = BackupService();
  bool _loading = false;

  Future<void> _run(Future<BackupResult> Function() action) async {
    setState(() => _loading = true);
    try {
      final result = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message ?? (result.success ? '✅ تمت العملية' : '❌ فشلت العملية'),
          style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
        duration: const Duration(seconds: 4)));
      // ✅ FIX: إعادة تحميل كل الـ Providers بعد الاستيراد
      if (result.success && result.isImport) _refreshAll();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _refreshAll() {
    context.read<ProductProvider>().loadAll();
    context.read<SaleProvider>().loadSales();
    context.read<DebtProvider>().loadAll();     // ✅ FIX: إضافة الديون
    context.read<ExpenseProvider>().loadAll();   // ✅ FIX: إضافة المصروفات
    context.read<SettingsProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاستيراد')),
      body: _loading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: AppColors.gold),
              SizedBox(height: 16),
              Text('جارٍ المعالجة...', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
            ]))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('النسخ الاحتياطي الكامل (JSON)', Icons.cloud_upload_outlined, [
                  _tile('تصدير نسخة احتياطية كاملة', Icons.backup_outlined, AppColors.gold,
                    'جميع البيانات: منتجات، مبيعات، ديون، مصروفات، إعدادات',
                    () => _run(_service.exportFullBackup)),
                  _tile('استيراد نسخة احتياطية', Icons.restore_outlined, AppColors.info,
                    'استعادة جميع البيانات من ملف JSON',
                    () => _run(_service.importFullBackup)),
                ]),
                const SizedBox(height: 16),
                _section('تصدير Excel', Icons.table_chart_outlined, [
                  _tile('تصدير المنتجات', Icons.inventory_2_outlined, AppColors.success,
                    'تصدير كامل قائمة المنتجات',
                    () => _run(_service.exportProductsToExcel)),
                  _tile('تصدير المبيعات', Icons.receipt_long_outlined, AppColors.info,
                    'تصدير سجل الفواتير والمبيعات',
                    () => _run(_service.exportSalesToExcel)),
                ]),
                const SizedBox(height: 16),
                _section('استيراد', Icons.download_outlined, [
                  _tile('استيراد منتجات من Excel', Icons.file_upload_outlined, AppColors.warning,
                    'استيراد قائمة منتجات من ملف xlsx',
                    () => _run(_service.importProductsFromExcel)),
                ]),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3))),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'الاستيراد سيحذف جميع البيانات الحالية ويستبدلها بالبيانات المستوردة. تأكد من أن الملف صحيح قبل الاستيراد.',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.warning))),
                  ])),
              ]));
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: AppColors.gold, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
          fontWeight: FontWeight.w700, color: AppColors.gold)),
      ]),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder)),
        child: Column(children: children.asMap().entries.map((e) {
          return Column(children: [
            e.value,
            if (e.key < children.length - 1) const Divider(height: 1, color: AppColors.divider),
          ]);
        }).toList())),
    ]);
  }

  Widget _tile(String title, IconData icon, Color color, String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600,
        color: AppColors.textPrimary, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11,
        color: AppColors.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
      onTap: onTap);
  }
}
