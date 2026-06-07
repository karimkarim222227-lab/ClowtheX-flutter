import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_event_bus.dart';
import '../../models/sale.dart';
import '../../providers/sale_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/pdf_service.dart';
import '../../services/backup_service.dart';
import '../../widgets/common/stat_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  List<Map<String, dynamic>> _dailyChart   = [];
  List<Map<String, dynamic>> _topProducts  = [];
  List<Sale>                 _sales        = [];
  Map<String, dynamic>       _profitSummary = {};
  List<Map<String, dynamic>> _profitChart  = [];
  List<Map<String, dynamic>> _storeHealthChart = [];
  bool _loading = true;

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to   = DateTime.now();

  StreamSubscription? _saleSub;
  StreamSubscription? _expenseSub;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _loadData();

    // ✅ FIX: تحديث فوري عند أي بيعة أو مصروف جديد
    final bus = AppEventBus();
    _saleSub    = bus.on(AppEvent.saleCompleted).listen((_) => _loadData());
    _expenseSub = bus.on(AppEvent.expenseUpdated).listen((_) => _loadData());
  }

  @override
  void dispose() {
    _tab.dispose();
    _saleSub?.cancel();
    _expenseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final sale    = context.read<SaleProvider>();
      final expense = context.read<ExpenseProvider>();

      final results = await Future.wait([
        sale.getDailySalesChart(days: 30),
        sale.getTopProducts(limit: 10),
        sale.getSalesByDateRange(_from, _to),
        sale.getProfitSummary(),
        sale.getProfitByDay(days: 30),
        sale.getProfitByMonth(months: 6),
        expense.getMonthlyReport(months: 6),
      ]);

      if (!mounted) return;
      _dailyChart       = results[0] as List<Map<String, dynamic>>;
      _topProducts      = results[1] as List<Map<String, dynamic>>;
      _sales            = results[2] as List<Sale>;
      _profitSummary    = results[3] as Map<String, dynamic>;
      _profitChart      = results[4] as List<Map<String, dynamic>>;

      final profitByMonth  = results[5] as List<Map<String, dynamic>>;
      final expenseByMonth = results[6] as List<Map<String, dynamic>>;
      _storeHealthChart = _buildStoreHealthData(profitByMonth, expenseByMonth);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ بناء بيانات مخطط صحة المحل الشامل
  List<Map<String, dynamic>> _buildStoreHealthData(
    List<Map<String, dynamic>> profitMonths,
    List<Map<String, dynamic>> expenseMonths,
  ) {
    final merged = <String, Map<String, dynamic>>{};

    for (final profit in profitMonths) {
      final month = profit['month'] as String? ?? '';
      if (month.isEmpty) continue;
      merged[month] = {
        'month': month,
        'revenue': (profit['revenue'] as num?)?.toDouble() ?? 0,
        'profit': (profit['profit'] as num?)?.toDouble() ?? 0,
        'expense': 0.0,
        'net': (profit['revenue'] as num?)?.toDouble() ?? 0,
      };
    }

    for (final expense in expenseMonths) {
      final month = expense['month'] as String? ?? '';
      if (month.isEmpty) continue;
      final entry = merged.putIfAbsent(month, () => {
        'month': month,
        'revenue': 0.0,
        'profit': 0.0,
        'expense': 0.0,
        'net': 0.0,
      });
      final expenseValue = (expense['total'] as num?)?.toDouble() ?? 0;
      entry['expense'] = expenseValue;
      entry['net'] = (entry['revenue'] as double) - expenseValue;
    }

    final sorted = merged.values.toList()
      ..sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          isScrollable: true,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'المبيعات'),
            Tab(text: 'الأرباح'),
            Tab(text: 'صحة المحل'),
            Tab(text: 'المنتجات'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            color: AppColors.surfaceVariant,
            onSelected: (v) async {
              final backup = BackupService();
              switch (v) {
                case 'print_sales':
                  await PdfService.printSalesReport(_sales, {}, currency: currency,
                    period: '${DateFormat('yyyy/MM/dd').format(_from)} - ${DateFormat('yyyy/MM/dd').format(_to)}');
                  break;
                case 'export_sales':
                  await backup.exportSalesToExcel(from: _from, to: _to);
                  break;
                case 'print_inventory':
                  final products = context.read<ProductProvider>().allProducts;
                  await PdfService.printInventoryReport(products, currency: currency);
                  break;
                case 'export_inventory':
                  await backup.exportProductsToExcel();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'print_sales', child: Row(children: [Icon(Icons.print, size: 18, color: AppColors.gold), SizedBox(width: 8), Text('طباعة تقرير المبيعات', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary))])),
              PopupMenuItem(value: 'export_sales', child: Row(children: [Icon(Icons.table_chart, size: 18, color: AppColors.success), SizedBox(width: 8), Text('تصدير المبيعات Excel', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary))])),
              PopupMenuDivider(),
              PopupMenuItem(value: 'print_inventory', child: Row(children: [Icon(Icons.print, size: 18, color: AppColors.gold), SizedBox(width: 8), Text('طباعة تقرير المخزون', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary))])),
              PopupMenuItem(value: 'export_inventory', child: Row(children: [Icon(Icons.table_chart, size: 18, color: AppColors.success), SizedBox(width: 8), Text('تصدير المخزون Excel', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textPrimary))])),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [Icon(Icons.download_outlined, color: AppColors.gold), Text(' تصدير', style: TextStyle(fontFamily: 'Cairo', color: AppColors.gold))]),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : TabBarView(
              controller: _tab,
              children: [
                _SalesTab(sales: _sales, dailyChart: _dailyChart, currency: currency,
                  from: _from, to: _to,
                  onDateChanged: (f, t) { setState(() { _from = f; _to = t; }); _loadData(); }),
                _ProfitTab(profitSummary: _profitSummary, profitChart: _profitChart,
                  currency: currency, onRefresh: _loadData),
                _StoreHealthTab(healthData: _storeHealthChart, currency: currency), // ✅ جديد
                _TopProductsTab(topProducts: _topProducts, currency: currency),
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 1: المبيعات
// ══════════════════════════════════════════════════════════════════════════════

class _SalesTab extends StatefulWidget {
  final List<Sale> sales;
  final List<Map<String, dynamic>> dailyChart;
  final String currency;
  final DateTime from, to;
  final void Function(DateTime, DateTime) onDateChanged;

  const _SalesTab({required this.sales, required this.dailyChart,
    required this.currency, required this.from, required this.to,
    required this.onDateChanged});

  @override
  State<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<_SalesTab> {
  String _activePeriod = '';

  void _selectPeriod(String period) {
    final now = DateTime.now();
    DateTime from;
    switch (period) {
      case 'اليوم':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'الأسبوع':
        from = now.subtract(const Duration(days: 7));
        break;
      case 'الشهر':
        from = DateTime(now.year, now.month, 1);
        break;
      case 'السنة':
        from = DateTime(now.year, 1, 1);
        break;
      default:
        return;
    }
    setState(() => _activePeriod = period);
    widget.onDateChanged(from, now);
  }

  @override
  Widget build(BuildContext context) {
    final total     = widget.sales.fold<double>(0, (s, e) => s + e.total);
    final completed = widget.sales.where((s) => s.status == SaleStatus.completed).length;
    const periods   = ['اليوم', 'الأسبوع', 'الشهر', 'السنة'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Period shortcut chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: periods.map((p) {
            final selected = _activePeriod == p;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => _selectPeriod(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.gold.withOpacity(0.15) : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppColors.gold : AppColors.cardBorder, width: selected ? 1.5 : 1),
                  ),
                  child: Text(p, style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600,
                    color: selected ? AppColors.gold : AppColors.textSecondary)),
                ),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 12),
        // Date range picker
        OutlinedButton.icon(
          onPressed: () async {
            final range = await showDateRangePicker(
              context: context, firstDate: DateTime(2020), lastDate: DateTime.now(),
              initialDateRange: DateTimeRange(start: widget.from, end: widget.to),
              builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!));
            if (range != null) {
              setState(() => _activePeriod = '');
              widget.onDateChanged(range.start, range.end);
            }
          },
          icon: const Icon(Icons.date_range, size: 16),
          label: Text('${DateFormat('yyyy/MM/dd').format(widget.from)} — ${DateFormat('yyyy/MM/dd').format(widget.to)}',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12))),
        const SizedBox(height: 16),

        // Stats
        GridView.count(crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
          children: [
            StatCard(title: 'إجمالي المبيعات',
              value: '${total.toStringAsFixed(2)} ${widget.currency}',
              icon: Icons.monetization_on_outlined, color: AppColors.gold),
            StatCard(title: 'عدد الفواتير', value: '$completed',
              icon: Icons.receipt_outlined, color: AppColors.info),
          ]),
        const SizedBox(height: 20),

        // Chart
        if (widget.dailyChart.isNotEmpty) ...[
          const Text('مبيعات آخر 30 يوم',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 12),
          _LineChartWidget(
            spots: widget.dailyChart.asMap().entries
              .map((e) => FlSpot(e.key.toDouble(), (e.value['revenue'] as num).toDouble()))
              .toList(),
            labels: widget.dailyChart.map((e) => e['sale_date']?.toString().substring(5) ?? '').toList(),
            color: AppColors.gold, height: 200),
          const SizedBox(height: 20),
        ],

        // Sales list
        const Text('الفواتير',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 8),
        if (widget.sales.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('لا توجد فواتير في هذه الفترة',
                style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
            ),
          ),
        ...widget.sales.map((s) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.card,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.invoiceNumber,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(DateFormat('yyyy/MM/dd HH:mm').format(s.createdAt),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
              if (s.customerName != null)
                Text(s.customerName!,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${s.total.toStringAsFixed(2)} ${widget.currency}',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: AppColors.gold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: s.status == SaleStatus.completed
                    ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(s.statusAr, style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
                  color: s.status == SaleStatus.completed ? AppColors.success : AppColors.error))),
            ]),
          ]),
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 2: الأرباح
// ══════════════════════════════════════════════════════════════════════════════

class _ProfitTab extends StatelessWidget {
  final Map<String, dynamic> profitSummary;
  final List<Map<String, dynamic>> profitChart;
  final String currency;
  final VoidCallback onRefresh;

  const _ProfitTab({required this.profitSummary, required this.profitChart,
    required this.currency, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final revenue = (profitSummary['total_revenue'] as num?)?.toDouble() ?? 0;
    final cost    = (profitSummary['total_cost'] as num?)?.toDouble() ?? 0;
    final profit  = (profitSummary['total_profit'] as num?)?.toDouble() ?? 0;
    final margin  = (profitSummary['profit_margin'] as num?)?.toDouble() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: StatCard(title: 'إجمالي الإيرادات',
            value: '${revenue.toStringAsFixed(2)} $currency',
            icon: Icons.trending_up, color: AppColors.success)),
          const SizedBox(width: 12),
          Expanded(child: StatCard(title: 'إجمالي التكاليف',
            value: '${cost.toStringAsFixed(2)} $currency',
            icon: Icons.money_off, color: AppColors.error)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatCard(title: 'صافي الربح',
            value: '${profit.toStringAsFixed(2)} $currency',
            icon: Icons.account_balance,
            color: profit >= 0 ? AppColors.gold : AppColors.error)),
          const SizedBox(width: 12),
          Expanded(child: StatCard(title: 'نسبة الربح',
            value: '${margin.toStringAsFixed(1)}%',
            icon: Icons.percent,
            color: margin > 20 ? AppColors.success : (margin > 10 ? AppColors.warning : AppColors.error))),
        ]),
        const SizedBox(height: 24),

        if (profitChart.isNotEmpty) ...[
          const Text('منحنى الأرباح (30 يوم)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: LineChart(LineChartData(
            backgroundColor: AppColors.card,
            gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1)),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 52,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= profitChart.length || i % 7 != 0) return const SizedBox();
                  final date = profitChart[i]['sale_date']?.toString() ?? '';
                  return Text(date.length > 5 ? date.substring(5) : '',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted));
                })),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: profitChart.asMap().entries.map((e) =>
                  FlSpot(e.key.toDouble(), (e.value['revenue'] as num?)?.toDouble() ?? 0)).toList(),
                isCurved: true, color: AppColors.success, barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: AppColors.success.withOpacity(0.1))),
              LineChartBarData(
                spots: profitChart.asMap().entries.map((e) =>
                  FlSpot(e.key.toDouble(), (e.value['profit'] as num?)?.toDouble() ?? 0)).toList(),
                isCurved: true, color: AppColors.gold, barWidth: 2,
                dotData: const FlDotData(show: false)),
            ]))),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _LegendDot(color: AppColors.success, label: 'الإيرادات'),
            const SizedBox(width: 16),
            _LegendDot(color: AppColors.gold, label: 'صافي الربح'),
          ]),
          const SizedBox(height: 24),
        ],

        // Store status card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: profit >= 0
                ? [AppColors.success.withOpacity(0.2), AppColors.info.withOpacity(0.1)]
                : [AppColors.error.withOpacity(0.2), AppColors.warning.withOpacity(0.1)],
              begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: profit >= 0
              ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3))),
          child: Column(children: [
            Icon(profit >= 0 ? Icons.trending_up : Icons.trending_down,
              size: 48, color: profit >= 0 ? AppColors.success : AppColors.error),
            const SizedBox(height: 12),
            Text(profit >= 0 ? 'الحالة ممتازة' : 'يحتاج تحسين',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800,
                color: profit >= 0 ? AppColors.success : AppColors.error)),
            const SizedBox(height: 8),
            Text(profit >= 0
              ? 'المحل يحقق أرباحاً جيدة. نسبة الربح ${margin.toStringAsFixed(1)}%'
              : 'المحل يعمل بخسارة. راجع التكاليف والأسعار',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 3: صحة المحل الشامل ✅ جديد
// ══════════════════════════════════════════════════════════════════════════════

class _StoreHealthTab extends StatelessWidget {
  final List<Map<String, dynamic>> healthData;
  final String currency;

  const _StoreHealthTab({required this.healthData, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (healthData.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bar_chart_outlined, size: 64, color: AppColors.textMuted),
        SizedBox(height: 16),
        Text('لا توجد بيانات كافية بعد', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
        SizedBox(height: 8),
        Text('ابدأ بتسجيل المبيعات والمصروفات\nوستظهر هنا إحصائيات شهرية شاملة',
          style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12),
          textAlign: TextAlign.center),
      ]));
    }

    // حساب الإجماليات
    final totalRevenue  = healthData.fold<double>(0, (s, e) => s + ((e['revenue'] as num?)?.toDouble() ?? 0));
    final totalExpenses = healthData.fold<double>(0, (s, e) => s + ((e['expense'] as num?)?.toDouble() ?? 0));
    final totalNet      = healthData.fold<double>(0, (s, e) => s + ((e['net'] as num?)?.toDouble() ?? 0));
    final avgMargin     = healthData.isEmpty ? 0.0
        : healthData.fold<double>(0, (s, e) {
            final rev = (e['revenue'] as num?)?.toDouble() ?? 0;
            final profit = (e['profit'] as num?)?.toDouble() ?? 0;
            return s + (rev > 0 ? profit / rev * 100 : 0);
          }) / healthData.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ملخص سريع
        const Text('ملخص الـ 6 أشهر الماضية',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        GridView.count(crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.4,
          children: [
            StatCard(title: 'إجمالي الإيرادات',
              value: '${totalRevenue.toStringAsFixed(0)} $currency',
              icon: Icons.trending_up, color: AppColors.success),
            StatCard(title: 'إجمالي المصروفات',
              value: '${totalExpenses.toStringAsFixed(0)} $currency',
              icon: Icons.payments_outlined, color: AppColors.error),
            StatCard(title: 'الربح الصافي',
              value: '${totalNet.toStringAsFixed(0)} $currency',
              icon: Icons.account_balance,
              color: totalNet >= 0 ? AppColors.gold : AppColors.error),
            StatCard(title: 'متوسط هامش الربح',
              value: '${avgMargin.toStringAsFixed(1)}%',
              icon: Icons.percent,
              color: avgMargin > 20 ? AppColors.success : (avgMargin > 10 ? AppColors.warning : AppColors.error)),
          ]),
        const SizedBox(height: 24),

        // المخطط الشامل
        const Text('المخطط البياني الشامل',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 4),
        const Text('الإيرادات — المصروفات — الربح الصافي',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'Cairo')),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder)),
          child: Column(children: [
            SizedBox(
              height: 260,
              child: LineChart(LineChartData(
                backgroundColor: AppColors.card,
                gridData: FlGridData(show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 56,
                    getTitlesWidget: (v, _) {
                      if (v == 0) return const Text('0', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted));
                      final formatted = v >= 1000 ? '${(v/1000).toStringAsFixed(0)}k' : v.toInt().toString();
                      return Text(formatted, style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted));
                    })),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= healthData.length) return const SizedBox();
                      final month = healthData[i]['month'] as String? ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(month.length >= 7 ? month.substring(5) : month,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted)));
                    })),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // إيرادات - أخضر
                  _chartLine(healthData, 'revenue', AppColors.success),
                  // مصروفات - أحمر
                  _chartLine(healthData, 'expense', AppColors.error),
                  // ربح صافي - ذهبي
                  _chartLine(healthData, 'net', AppColors.gold),
                ],
              )),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _LegendDot(color: AppColors.success, label: 'الإيرادات'),
              const SizedBox(width: 12),
              _LegendDot(color: AppColors.error, label: 'المصروفات'),
              const SizedBox(width: 12),
              _LegendDot(color: AppColors.gold, label: 'الربح الصافي'),
            ]),
          ])),
        const SizedBox(height: 24),

        // تفاصيل شهر بشهر
        const Text('التفصيل الشهري',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        ...healthData.reversed.map((d) {
          final month   = d['month'] as String? ?? '';
          final revenue = (d['revenue'] as num?)?.toDouble() ?? 0;
          final expense = (d['expense'] as num?)?.toDouble() ?? 0;
          final net     = (d['net'] as num?)?.toDouble() ?? 0;
          final isProfit = net >= 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isProfit
                ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3))),
            child: Column(children: [
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isProfit ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(isProfit ? Icons.trending_up : Icons.trending_down,
                    color: isProfit ? AppColors.success : AppColors.error, size: 20)),
                const SizedBox(width: 10),
                Expanded(child: Text(month,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary))),
                Text('${net >= 0 ? '+' : ''}${net.toStringAsFixed(2)} $currency',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 15,
                    color: isProfit ? AppColors.success : AppColors.error)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _MiniStat(label: 'إيرادات', value: '${revenue.toStringAsFixed(0)} $currency', color: AppColors.success),
                const SizedBox(width: 8),
                _MiniStat(label: 'مصروفات', value: '${expense.toStringAsFixed(0)} $currency', color: AppColors.error),
                const SizedBox(width: 8),
                _MiniStat(label: 'ربح', value: '${((d['profit'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} $currency', color: AppColors.gold),
              ]),
            ]),
          );
        }),
        const SizedBox(height: 20),
      ]),
    );
  }

  LineChartBarData _chartLine(List<Map<String, dynamic>> data, String key, Color color) {
    return LineChartBarData(
      spots: data.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), (e.value[key] as num?)?.toDouble() ?? 0)).toList(),
      isCurved: true, color: color, barWidth: 2.5,
      dotData: FlDotData(show: data.length <= 6),
      belowBarData: BarAreaData(show: key == 'revenue', color: color.withOpacity(0.08)));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 4: أكثر المنتجات مبيعاً
// ══════════════════════════════════════════════════════════════════════════════

class _TopProductsTab extends StatelessWidget {
  final List<Map<String, dynamic>> topProducts;
  final String currency;
  const _TopProductsTab({required this.topProducts, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (topProducts.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textMuted),
        SizedBox(height: 12),
        Text('لا توجد مبيعات بعد', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
      ]));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('أكثر المنتجات مبيعاً',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        ...topProducts.asMap().entries.map((e) {
          final p = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card,
              borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
            child: Row(children: [
              Container(width: 32, height: 32,
                decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('${e.key + 1}',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: AppColors.gold)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['product_name'] as String,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('${p['total_sold']} وحدة مباعة',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
              ])),
              Text('${(p['total_revenue'] as num).toStringAsFixed(2)} $currency',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.gold)),
            ]),
          );
        }),
      ],
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _LineChartWidget extends StatelessWidget {
  final List<FlSpot> spots;
  final List<String> labels;
  final Color color;
  final double height;
  const _LineChartWidget({required this.spots, required this.labels, required this.color, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, child: LineChart(LineChartData(
      backgroundColor: AppColors.card,
      gridData: FlGridData(show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1)),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48,
          getTitlesWidget: (v, _) => Text(v.toInt().toString(),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= labels.length || i % 5 != 0) return const SizedBox();
            return Text(labels[i], style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted));
          })),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))),
      borderData: FlBorderData(show: false),
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true, color: color, barWidth: 2.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)))])));
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
      ])));
  }
}

