import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../services/backup_service.dart';
import '../../services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storeName = TextEditingController();
  final _storePhone = TextEditingController();
  final _storeAddress = TextEditingController();
  final _currency = TextEditingController();
  final _taxRate = TextEditingController();
  final _lowStock = TextEditingController();
  bool _taxEnabled = true;
  String _lastSync = 'لم تتم المزامنة بعد';
  bool _isSyncing = false;
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _storeName.text = s.storeName;
    _storePhone.text = s.storePhone;
    _storeAddress.text = s.storeAddress;
    _currency.text = s.currency;
    _taxRate.text = s.taxRate.toString();
    _lowStock.text = s.lowStockAlert.toString();
    _taxEnabled = s.taxEnabled;
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_sync_time');
    if (lastSync != null) {
      if (mounted) {
        setState(() {
          _lastSync = DateTime.parse(lastSync).toString().split('.')[0];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإعدادات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('معلومات المتجر'),
          _settingField('اسم المتجر', _storeName, Icons.store_outlined),
          const SizedBox(height: 12),
          _settingField('رقم الهاتف', _storePhone, Icons.phone_outlined, type: TextInputType.phone),
          const SizedBox(height: 12),
          _settingField('العنوان', _storeAddress, Icons.location_on_outlined, maxLines: 2),
          const SizedBox(height: 20),
          _sectionTitle('الإعدادات المالية'),
          Row(children: [
            Expanded(child: _settingField('العملة', _currency, Icons.payments_outlined)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
              child: Row(children: [
                const Text('تفعيل الضريبة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary, fontSize: 13)),
                Switch(value: _taxEnabled, onChanged: (v) => setState(() => _taxEnabled = v), activeColor: AppColors.gold),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          _settingField('نسبة الضريبة (%)', _taxRate, Icons.percent,
            type: TextInputType.number, formatter: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))], enabled: _taxEnabled),
          const SizedBox(height: 12),
          _settingField('حد تنبيه المخزون المنخفض', _lowStock, Icons.warning_amber_outlined,
            type: TextInputType.number, formatter: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ الإعدادات', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('المزامنة السحابية'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
            child: Column(children: [
              _infoRow('آخر مزامنة ناجحة', _lastSync),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : () async {
                      setState(() => _isSyncing = true);
                      await _syncService.syncData();
                      await _loadLastSync();
                      setState(() => _isSyncing = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت المزامنة بنجاح')));
                    },
                    icon: _isSyncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
                    label: const Text('مزامنة الآن', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('استعادة البيانات'),
                          content: const Text('سيتم استبدال البيانات المحلية بالبيانات السحابية. هل أنت متأكد؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        setState(() => _isSyncing = true);
                        await _syncService.restoreFromCloud();
                        await _loadLastSync();
                        setState(() => _isSyncing = false);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة البيانات بنجاح')));
                      }
                    },
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('استعادة', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          _sectionTitle('النسخ الاحتياطي والاستيراد'),
          ListTile(
            tileColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.cardBorder)),
            leading: const Icon(Icons.backup_outlined, color: AppColors.gold),
            title: const Text('إدارة النسخ الاحتياطي والاستيراد/التصدير', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
            onTap: () {
              if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()));
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle('معلومات التطبيق'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
            child: Column(children: [
              _infoRow('اسم التطبيق', 'ClowtheX'),
              const Divider(color: AppColors.divider, height: 16),
              _infoRow('الإصدار', '1.0.0'),
              const Divider(color: AppColors.divider, height: 16),
              _infoRow('المطور', 'Haythem Group'),
            ]),
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gold, fontFamily: 'Cairo')),
    );
  }
  Widget _settingField(String label, TextEditingController ctrl, IconData icon, {TextInputType type = TextInputType.text, List<TextInputFormatter>? formatter, int maxLines = 1, bool enabled = true}) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: type,
      inputFormatters: formatter,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.gold, size: 20),
        filled: true,
        fillColor: AppColors.inputBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
        labelStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
      ),
    );
  }
  Widget _infoRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 13)),
      Text(value, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
    ]);
  }
  Future<void> _save() async {
    final s = context.read<SettingsProvider>();
    await Future.wait([
      s.updateStoreName(_storeName.text.trim()),
      s.updateStorePhone(_storePhone.text.trim()),
      s.updateStoreAddress(_storeAddress.text.trim()),
      s.updateCurrency(_currency.text.trim()),
      s.updateTaxRate(double.tryParse(_taxRate.text) ?? 0),
      s.updateTaxEnabled(_taxEnabled),
      s.updateLowStockAlert(int.tryParse(_lowStock.text) ?? 5),
    ]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم حفظ الإعدادات', style: TextStyle(fontFamily: 'Cairo')),
      ));
    }
  }
}
