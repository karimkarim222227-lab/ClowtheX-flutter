import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../backup/backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});



    }
  }


    }
  }




    }
  }

  }



    }
  }

    super.dispose();
  }



    }
  }

          ),
          const SizedBox(height: 20),

          
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت المزامنة بنجاح')));
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
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة البيانات بنجاح')));
                      }
                    },
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('استعادة', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                ),
              ]),
            ]),
          ),

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
