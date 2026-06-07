import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../backup/backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _storeName;
  late final TextEditingController _storePhone;
  late final TextEditingController _storeAddress;
  late final TextEditingController _currency;
  late final TextEditingController _taxRate;
  late final TextEditingController _lowStock;
  bool _taxEnabled = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _storeName = TextEditingController();
    _storePhone = TextEditingController();
    _storeAddress = TextEditingController();
    _currency = TextEditingController();
    _taxRate = TextEditingController();
    _lowStock = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final s = context.read<SettingsProvider>();
      _storeName.text = s.storeName;
      _storePhone.text = s.storePhone;
      _storeAddress.text = s.storeAddress;
      _currency.text = s.currency;
      _taxRate.text = s.taxRate.toString();
      _taxEnabled = s.taxEnabled;
      _lowStock.text = s.lowStockAlert.toString();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    for (final c in [_storeName, _storePhone, _storeAddress, _currency, _taxRate, _lowStock]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('معلومات المحل'),
          _settingField('اسم المحل', _storeName, Icons.store_outlined),
          const SizedBox(height: 12),
          _settingField('رقم الهاتف', _storePhone, Icons.phone_outlined, type: TextInputType.phone),
          const SizedBox(height: 12),
          _settingField('العنوان', _storeAddress, Icons.location_on_outlined, maxLines: 2),
          const SizedBox(height: 20),

          _sectionTitle('إعدادات المبيعات'),
          _settingField('رمز العملة', _currency, Icons.monetization_on_outlined),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _taxEnabled,
            title: const Text('تفعيل الضريبة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary)),
            subtitle: const Text('تطبيق الضريبة عند إتمام الفواتير', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12)),
            onChanged: (value) => setState(() => _taxEnabled = value),
            activeColor: AppColors.gold,
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
          ),
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
