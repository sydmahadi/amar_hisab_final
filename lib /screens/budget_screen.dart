
import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/money_db.dart';
import '../theme/app_theme.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final MoneyDb _db = MoneyDb.instance;
  final AppSettings _settings = AppSettings.instance;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  bool get _bn => _settings.isBangla;

  String _text(String bn, String en) => _bn ? bn : en;

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(double value) => value.toStringAsFixed(2);

  int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  @override
  void initState() {
    super.initState();
    _settings.addListener(_settingsChanged);
    _load();
  }

  @override
  void dispose() {
    _settings.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _db.getBudgets(month: _month),
        _db.getCategories(),
      ]);

      if (!mounted) return;

      setState(() {
        _budgets = List<Map<String, dynamic>>.from(
          results[0] as List,
        );
        _categories = List<Map<String, dynamic>>.from(
          results[1] as List,
        ).where((c) {
          return (c['type'] ?? '').toString().toLowerCase() == 'expense';
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text('বাজেট লোড করা যায়নি: $e', 'Could not load budgets: $e'),
          ),
        ),
      );
    }
  }

  String _monthName(DateTime date) {
    const bnMonths = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল',
      'মে', 'জুন', 'জুলাই', 'আগস্ট',
      'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
    ];
    const enMonths = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];

    final name = _bn ? bnMonths[date.month - 1] : enMonths[date.month - 1];
    return '$name ${date.year}';
  }

  Future<void> _changeMonth(int difference) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + difference);
    });
    await _load();
  }

  double get _totalBudget => _budgets.fold(
        0,
        (sum, item) => sum + _number(item['amount']),
      );

  double get _totalSpent => _budgets.fold(
        0,
        (sum, item) {
          if (item['category_id'] == null) {
            return sum + _number(item['spent']);
          }
          return sum;
        },
      );

  double get _remaining => _totalBudget - _totalSpent;

  Map<String, dynamic>? get _overallBudget {
    for (final item in _budgets) {
      if (item['category_id'] == null) return item;
    }
    return null;
  }

  Future<void> _showBudgetDialog({
    Map<String, dynamic>? existing,
  }) async {
    final amountController = TextEditingController(
      text: existing == null
          ? ''
          : _number(existing['amount']).toStringAsFixed(2),
    );

    final oldId = _int(existing?['id']);
    final oldCategoryId = _int(existing?['category_id']);
    int? selectedCategoryId = oldCategoryId;
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);

            return AlertDialog(
              title: Text(
                existing == null
                    ? _text('নতুন বাজেট', 'New budget')
                    : _text('বাজেট সম্পাদনা', 'Edit budget'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text('মাস: ${_monthName(_month)}',
                          'Month: ${_monthName(_month)}'),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      value: selectedCategoryId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _text('বাজেটের ধরন', 'Budget type'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            _text('সামগ্রিক বাজেট', 'Overall budget'),
                          ),
                        ),
                        ..._categories.map((category) {
                          final id = _int(category['id']);
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(
                              (category['name'] ?? '').toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategoryId = value;
                          errorText = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _text('বাজেটের পরিমাণ', 'Budget amount'),
                        hintText: '0.00',
                        prefixText: '৳ ',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(_text('বাতিল', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    if (amount == null || !amount.isFinite || amount <= 0) {
                      setDialogState(() {
                        errorText = _text(
                          'সঠিক বাজেটের পরিমাণ লিখুন',
                          'Enter a valid budget amount',
                        );
                      });
                      return;
                    }

                    try {
                      // Remove the old entry when editing.
                      if (oldId != null) {
                        await _db.deleteBudget(oldId);
                      }

                      // SQLite permits duplicate NULL category IDs in a
                      // UNIQUE constraint, so remove any previous overall
                      // budget for this month before saving another one.
                      if (selectedCategoryId == null) {
                        final currentBudgets =
                            await _db.getBudgets(month: _month);

                        for (final budget in currentBudgets) {
                          if (budget['category_id'] == null) {
                            final id = _int(budget['id']);
                            if (id != null && id != oldId) {
                              await _db.deleteBudget(id);
                            }
                          }
                        }
                      }

                      await _db.setBudget(
                        month: _month,
                        categoryId: selectedCategoryId,
                        amount: amount,
                      );

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      setDialogState(() {
                        errorText = _text(
                          'সংরক্ষণ করা যায়নি: $e',
                          'Could not save: $e',
                        );
                      });
                    }
                  },
                  child: Text(_text('সংরক্ষণ', 'Save')),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();

    if (saved == true) await _load();
  }

  Future<void> _deleteBudget(Map<String, dynamic> budget) async {
    final id = _int(budget['id']);
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text('বাজেট মুছবেন?', 'Delete budget?')),
        content: Text(
          _text(
            'এই বাজেটটি মুছে ফেলা হবে। লেনদেন মুছে যাবে না।',
            'This budget will be deleted. Transactions will remain.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text('না', 'No')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_text('মুছুন', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.deleteBudget(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _editBudget(Map<String, dynamic> budget) async {
    await _showBudgetDialog(existing: budget);
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _money(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overallCard() {
    final overall = _overallBudget;
    final theme = Theme.of(context);
    final spent = overall == null ? 0.0 : _number(overall['spent']);
    final limit = overall == null ? 0.0 : _number(overall['amount']);
    final progress = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final exceeded = spent > limit && limit > 0;
    final color = exceeded ? AppTheme.expenseColor : AppTheme.green;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.green, AppTheme.darkGreen],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.goldLight.withValues(alpha: .45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppTheme.goldLight,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _text('সামগ্রিক বাজেট', 'Overall budget'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: _text('বাজেট যোগ করুন', 'Set budget'),
                onPressed: () => _showBudgetDialog(existing: overall),
                icon: Icon(
                  overall == null ? Icons.add_circle_outline : Icons.edit,
                  color: AppTheme.goldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            overall == null
                ? _text('এখনো সামগ্রিক বাজেট নির্ধারণ করা হয়নি',
                    'No overall budget set yet')
                : '${_text('বাজেট', 'Budget')}: ${_money(limit)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontSize: 12,
            ),
          ),
          if (overall != null) ...[
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text('খরচ হয়েছে', 'Spent'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .8),
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  _money(spent),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: Colors.white.withValues(alpha: .2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  exceeded ? Colors.redAccent : AppTheme.goldLight,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    exceeded
                        ? _text('বাজেট ছাড়িয়েছে', 'Budget exceeded')
                        : _text('অবশিষ্ট', 'Remaining'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .8),
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  _money((limit - spent).abs()),
                  style: TextStyle(
                    color: exceeded ? Colors.redAccent : AppTheme.goldLight,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
          if (overall == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _text(
                  'যোগ (+) চিহ্নে চাপ দিয়ে এই মাসের বাজেট নির্ধারণ করুন।',
                  'Tap + to set this month’s budget.',
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _budgetTile(Map<String, dynamic> budget) {
    final theme = Theme.of(context);
    final name = (budget['category_name'] ?? '').toString();
    final limit = _number(budget['amount']);
    final spent = _number(budget['spent']);
    final remaining = limit - spent;
    final progress = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final exceeded = spent > limit;
    final color = exceeded ? AppTheme.expenseColor : AppTheme.green;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.category_rounded, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty
                          ? _text('খাতের বাজেট', 'Category budget')
                          : name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_text('সীমা', 'Limit')}: ${_money(limit)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _editBudget(budget);
                  if (value == 'delete') _deleteBudget(budget);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(_text('সম্পাদনা', 'Edit')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(_text('মুছুন', 'Delete')),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Text(
                  _text('খরচ: ${_money(spent)}',
                      'Spent: ${_money(spent)}'),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${limit == 0 ? 0 : (spent / limit * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(
                exceeded
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                color: color,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  exceeded
                      ? _text('বাজেট ছাড়িয়েছে', 'Budget exceeded')
                      : _text('অবশিষ্ট', 'Remaining'),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                _money(remaining.abs()),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final categoryBudgets = _budgets.where(
      (item) => item['category_id'] != null,
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_text('বাজেট ব্যবস্থাপনা', 'Budget Management')),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: _text('রিফ্রেশ', 'Refresh'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBudgetDialog(),
        icon: const Icon(Icons.add_rounded),
        label: Text(_text('বাজেট যোগ', 'Add budget')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: .25),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            _monthName(_month),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            title: _text('মোট বাজেট', 'Total budget'),
                            amount: _totalBudget,
                            icon: Icons.account_balance_wallet_rounded,
                            color: AppTheme.gold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _summaryCard(
                            title: _text('বাজেটের সংখ্যা', 'Budgets'),
                            amount: _budgets.length.toDouble(),
                            icon: Icons.pie_chart_outline_rounded,
                            color: AppTheme.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _overallCard(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.category_rounded,
                          color: AppTheme.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _text('খাতভিত্তিক বাজেট', 'Category budgets'),
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${categoryBudgets.length}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (categoryBudgets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.gold.withValues(alpha: .2),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.savings_outlined,
                              size: 38,
                              color: AppTheme.gold,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _text(
                                'এই মাসে কোনো খাতভিত্তিক বাজেট নেই',
                                'No category budgets for this month',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showBudgetDialog(),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(_text('বাজেট যোগ করুন', 'Add budget')),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...categoryBudgets.map(_budgetTile),
                ],
              ),
            ),
    );
  }
}
