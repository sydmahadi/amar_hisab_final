import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/money_db.dart';
import '../theme/app_theme.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final AppSettings _settings = AppSettings.instance;

  String _period = 'monthly';
  String _selectedTab = 'income';

  bool _loading = true;

  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  double _myDebt = 0.0;
  double _myReceivable = 0.0;

  List<Map<String, dynamic>> _incomeCategories = [];
  List<Map<String, dynamic>> _expenseCategories = [];

  List<Map<String, dynamic>> _allTransactions = [];

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _setPeriod();
    _loadStatistics();
  }

  void _setPeriod() {
    final now = DateTime.now();

    switch (_period) {
      case 'daily':
        _startDate = DateTime(
          now.year,
          now.month,
          now.day,
        );

        _endDate = DateTime(
          now.year,
          now.month,
          now.day,
          23,
          59,
          59,
        );
        break;

      case 'weekly':
        final today = DateTime(
          now.year,
          now.month,
          now.day,
        );

        final monday = today.subtract(
          Duration(days: today.weekday - 1),
        );

        _startDate = monday;

        _endDate = DateTime(
          monday.year,
          monday.month,
          monday.day + 6,
          23,
          59,
          59,
        );
        break;

      case 'yearly':
        _startDate = DateTime(
          now.year,
          1,
          1,
        );

        _endDate = DateTime(
          now.year,
          12,
          31,
          23,
          59,
          59,
        );
        break;

      case 'monthly':
      default:
        _startDate = DateTime(
          now.year,
          now.month,
          1,
        );

        _endDate = DateTime(
          now.year,
          now.month + 1,
          0,
          23,
          59,
          59,
        );
        break;
    }
  }

  Future<void> _loadStatistics() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final transactions =
          await MoneyDb.instance.getTransactions();

      final periodTransactions = transactions.where((tx) {
        final date = _transactionDate(tx);

        if (date == null ||
            _startDate == null ||
            _endDate == null) {
          return false;
        }

        return !date.isBefore(_startDate!) &&
            !date.isAfter(_endDate!);
      }).toList();

      double income = 0.0;
      double expense = 0.0;

      final Map<int, Map<String, dynamic>> incomeMap = {};
      final Map<int, Map<String, dynamic>> expenseMap = {};

      double debt = 0.0;
      double receivable = 0.0;

      for (final tx in transactions) {
        final type = _stringValue(
          tx['type'],
        ).toLowerCase();

        final amount = _doubleValue(
          tx['amount'],
        );

        switch (type) {
          case 'loan_taken':
            debt += amount;
            break;

          case 'loan_paid':
            debt -= amount;
            break;

          case 'loan_given':
            receivable += amount;
            break;

          case 'loan_received':
            receivable -= amount;
            break;
        }
      }

      if (debt < 0) {
        debt = 0.0;
      }

      if (receivable < 0) {
        receivable = 0.0;
      }

      for (final tx in periodTransactions) {
        final type = _stringValue(
          tx['type'],
        ).toLowerCase();

        final amount = _doubleValue(
          tx['amount'],
        );

        if (type == 'income') {
          income += amount;

          final categoryId = _intValue(
            tx['category_id'],
          );

          final categoryName = _categoryName(tx);

          if (!incomeMap.containsKey(categoryId)) {
            incomeMap[categoryId] = {
              'category_id': categoryId,
              'category_name': categoryName,
              'amount': 0.0,
              'color': tx['category_color'],
            };
          }

          final oldAmount = _doubleValue(
            incomeMap[categoryId]!['amount'],
          );

          incomeMap[categoryId]!['amount'] =
              oldAmount + amount;
        } else if (type == 'expense') {
          expense += amount;

          final categoryId = _intValue(
            tx['category_id'],
          );

          final categoryName = _categoryName(tx);

          if (!expenseMap.containsKey(categoryId)) {
            expenseMap[categoryId] = {
              'category_id': categoryId,
              'category_name': categoryName,
              'amount': 0.0,
              'color': tx['category_color'],
            };
          }

          final oldAmount = _doubleValue(
            expenseMap[categoryId]!['amount'],
          );

          expenseMap[categoryId]!['amount'] =
              oldAmount + amount;
        }
      }

      final incomeCategories = incomeMap.values.toList();
      final expenseCategories = expenseMap.values.toList();

      incomeCategories.sort(
        (a, b) => _doubleValue(
          b['amount'],
        ).compareTo(
          _doubleValue(
            a['amount'],
          ),
        ),
      );

      expenseCategories.sort(
        (a, b) => _doubleValue(
          b['amount'],
        ).compareTo(
          _doubleValue(
            a['amount'],
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;

        _allTransactions = transactions;

        _totalIncome = income;
        _totalExpense = expense;

        _myDebt = debt;
        _myReceivable = receivable;

        _incomeCategories = incomeCategories;
        _expenseCategories = expenseCategories;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _settings.isBangla
                ? 'পরিসংখ্যান লোড করতে সমস্যা হয়েছে'
                : 'Failed to load statistics',
          ),
        ),
      );
    }
  }

  DateTime? _transactionDate(
    Map<String, dynamic> tx,
  ) {
    final value = tx['date'] ??
        tx['transaction_date'] ??
        tx['created_at'];

    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  String _stringValue(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  double _doubleValue(
    dynamic value,
  ) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  int _intValue(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  String _categoryName(
    Map<String, dynamic> tx,
  ) {
    final value = tx['category_name'] ??
        tx['category'] ??
        tx['name'];

    if (value == null ||
        value.toString().trim().isEmpty) {
      return _settings.isBangla
          ? 'অন্যান্য'
          : 'Other';
    }

    return value.toString();
  }

  String _money(
    double value,
  ) {
    return '৳${_formatNumber(value)}';
  }

  String _formatNumber(
    double value,
  ) {
    final rounded = value.round();
    final text = rounded.toString();

    final buffer = StringBuffer();
    final length = text.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 &&
          (length - i) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(text[i]);
    }

    return buffer.toString();
  }

  String _formatDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _periodLabel() {
    if (_period == 'custom') {
      if (_startDate == null ||
          _endDate == null) {
        return _settings.isBangla
            ? 'তারিখ নির্বাচন করুন'
            : 'Select dates';
      }

      return '${_formatDate(_startDate!)} - '
          '${_formatDate(_endDate!)}';
    }

    if (!_settings.isBangla) {
      switch (_period) {
        case 'daily':
          return 'Today';

        case 'weekly':
          return 'This Week';

        case 'yearly':
          return 'This Year';

        case 'monthly':
        default:
          return 'This Month';
      }
    }

    switch (_period) {
      case 'daily':
        return 'আজ';

      case 'weekly':
        return 'এই সপ্তাহ';

      case 'yearly':
        return 'এই বছর';

      case 'monthly':
      default:
        return 'এই মাস';
    }
  }

  void _changePeriod(
    String period,
  ) {
    setState(() {
      _period = period;
    });

    _setPeriod();
    _loadStatistics();
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();

    final initialStart = _startDate ??
        DateTime(
          now.year,
          now.month,
          1,
        );

    final initialEnd = _endDate ??
        DateTime(
          now.year,
          now.month,
          now.day,
          23,
          59,
          59,
        );

    final firstDate = DateTime(
      2000,
      1,
      1,
    );

    final lastDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final clampedStart = initialStart.isAfter(lastDate)
        ? lastDate
        : initialStart.isBefore(firstDate)
            ? firstDate
            : initialStart;

    final clampedEnd = initialEnd.isAfter(lastDate)
        ? lastDate
        : initialEnd.isBefore(firstDate)
            ? firstDate
            : initialEnd;

    final initialRange = DateTimeRange(
      start: clampedStart,
      end: clampedEnd,
    );

    final safeRange = initialRange.start.isAfter(
      initialRange.end,
    )
        ? DateTimeRange(
            start: initialRange.end,
            end: initialRange.end,
          )
        : initialRange;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: safeRange,
      helpText: _settings.isBangla
          ? 'তারিখ নির্বাচন করুন'
          : 'Select date range',
      cancelText: _settings.isBangla
          ? 'বাতিল'
          : 'Cancel',
      confirmText: _settings.isBangla
          ? 'নির্বাচন'
          : 'Select',
      saveText: _settings.isBangla
          ? 'সম্পন্ন'
          : 'Done',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context)
                .colorScheme
                .copyWith(
                  primary: AppTheme.green,
                  onPrimary: Colors.white,
                  secondary: AppTheme.gold,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _period = 'custom';

      _startDate = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );

      _endDate = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );
    });

    await _loadStatistics();
  }

  Color _categoryColor(
    Map<String, dynamic> category,
    int index,
  ) {
    final rawColor = category['color'];

    if (rawColor is int &&
        rawColor != 0) {
      return Color(rawColor);
    }

    const colors = [
      Color(0xFF176B45),
      Color(0xFFC9A45C),
      Color(0xFF3F7CAC),
      Color(0xFF9B59B6),
      Color(0xFFE67E22),
      Color(0xFF16A085),
      Color(0xFFE74C3C),
      Color(0xFF34495E),
      Color(0xFF2ECC71),
      Color(0xFF8E44AD),
    ];

    return colors[
      index % colors.length
    ];
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _settings.isBangla
              ? 'পরিসংখ্যান'
              : 'Statistics',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _settings.isBangla
                ? 'রিফ্রেশ'
                : 'Refresh',
            onPressed: _loadStatistics,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  32,
                ),
                children: [
                  _buildPeriodSelector(theme),
                  const SizedBox(height: 10),
                  _buildCustomDateButton(theme),
                  const SizedBox(height: 16),
                  _buildSummaryGrid(theme),
                  const SizedBox(height: 20),
                  _buildTabSelector(theme),
                  const SizedBox(height: 18),
                  if (_selectedTab == 'income')
                    _buildIncomeSection(theme)
                  else if (_selectedTab == 'expense')
                    _buildExpenseSection(theme)
                  else
                    _buildLoanSection(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(
    ThemeData theme,
  ) {
    final periods = [
      {
        'key': 'daily',
        'bn': 'দৈনিক',
        'en': 'Daily',
        'icon': Icons.today_rounded,
      },
      {
        'key': 'weekly',
        'bn': 'সাপ্তাহিক',
        'en': 'Weekly',
        'icon': Icons.view_week_rounded,
      },
      {
        'key': 'monthly',
        'bn': 'মাসিক',
        'en': 'Monthly',
        'icon': Icons.calendar_month_rounded,
      },
      {
        'key': 'yearly',
        'bn': 'বার্ষিক',
        'en': 'Yearly',
        'icon': Icons.date_range_rounded,
      },
    ];

    final Color unselectedColor =
        theme.colorScheme.onSurface.withValues(
      alpha: 0.78,
    );

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.green.withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Row(
        children: periods.map((item) {
          final selected =
              _period == item['key'];

          return Expanded(
            child: GestureDetector(
              onTap: () {
                _changePeriod(
                  item['key'].toString(),
                );
              },
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.green
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 18,
                      color: selected
                          ? AppTheme.goldLight
                          : unselectedColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _settings.isBangla
                          ? item['bn'].toString()
                          : item['en'].toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : unselectedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCustomDateButton(
    ThemeData theme,
  ) {
    final selected = _period == 'custom';

    return Material(
      color: theme.cardColor,
      borderRadius:
          BorderRadius.circular(16),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: _selectCustomDateRange,
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.gold.withValues(
                      alpha: 0.55,
                    )
                  : AppTheme.green.withValues(
                      alpha: 0.15,
                    ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.date_range_rounded,
                  color: AppTheme.gold,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _settings.isBangla
                          ? 'নিজের তারিখ নির্বাচন'
                          : 'Custom Date Range',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                        color: theme
                            .colorScheme
                            .onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selected
                          ? _periodLabel()
                          : (_settings.isBangla
                              ? 'শুরু ও শেষের তারিখ নির্বাচন করুন'
                              : 'Select start and end dates'),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(
    ThemeData theme,
  ) {
    final difference =
        _totalIncome - _totalExpense;

    final isSurplus =
        difference >= 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                theme: theme,
                title: _settings.isBangla
                    ? 'মোট আয়'
                    : 'Total Income',
                amount: _totalIncome,
                icon: Icons.arrow_downward_rounded,
                iconColor: Colors.green,
                subtitle: _periodLabel(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                theme: theme,
                title: _settings.isBangla
                    ? 'মোট ব্যয়'
                    : 'Total Expense',
                amount: _totalExpense,
                icon: Icons.arrow_upward_rounded,
                iconColor: Colors.redAccent,
                subtitle: _periodLabel(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                theme: theme,
                title: _settings.isBangla
                    ? (isSurplus
                        ? 'উদ্বৃত্ত'
                        : 'ঘাটতি')
                    : (isSurplus
                        ? 'Surplus'
                        : 'Deficit'),
                amount: difference.abs(),
                icon: isSurplus
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                iconColor: isSurplus
                    ? Colors.green
                    : Colors.redAccent,
                subtitle: _periodLabel(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                theme: theme,
                title: _settings.isBangla
                    ? 'মোট লোন'
                    : 'My Loan',
                amount: _myDebt,
                icon: Icons.handshake_rounded,
                iconColor: AppTheme.gold,
                subtitle: _settings.isBangla
                    ? 'অন্যকে শোধ করতে হবে'
                    : 'Outstanding debt',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required ThemeData theme,
    required String title,
    required double amount,
    required IconData icon,
    required Color iconColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: iconColor.withValues(
            alpha: 0.18,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(
                    alpha: 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.end,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                    color: theme.textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(
                          alpha: 0.72,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment:
                Alignment.centerLeft,
            child: Text(
              _money(amount),
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.w800,
                color: theme.textTheme
                    .bodyLarge
                    ?.color,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: theme.textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(
                    alpha: 0.55,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(
    ThemeData theme,
  ) {
    final tabs = [
      {
        'key': 'income',
        'bn': 'আয়',
        'en': 'Income',
        'icon': Icons.south_west_rounded,
      },
      {
        'key': 'expense',
        'bn': 'ব্যয়',
        'en': 'Expense',
        'icon': Icons.north_east_rounded,
      },
      {
        'key': 'loan',
        'bn': 'লোন',
        'en': 'Loan',
        'icon': Icons.handshake_rounded,
      },
    ];

    final Color unselectedColor =
        theme.colorScheme.onSurface.withValues(
      alpha: 0.78,
    );

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: Row(
        children: tabs.map((tab) {
          final selected =
              _selectedTab == tab['key'];

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab =
                      tab['key'].toString();
                });
              },
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.green
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 18,
                      color: selected
                          ? AppTheme.goldLight
                          : unselectedColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _settings.isBangla
                          ? tab['bn'].toString()
                          : tab['en'].toString(),
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : unselectedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIncomeSection(
    ThemeData theme,
  ) {
    if (_incomeCategories.isEmpty) {
      return _emptyState(
        theme,
        Icons.bar_chart_rounded,
        _settings.isBangla
            ? 'এই সময়ে কোনো আয় নেই'
            : 'No income for this period',
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          _settings.isBangla
              ? 'আয়ের বিশ্লেষণ'
              : 'Income Analysis',
          _settings.isBangla
              ? 'ক্যাটাগরি অনুযায়ী আয়'
              : 'Income by category',
        ),
        const SizedBox(height: 14),
        _buildPieCard(
          theme: theme,
          categories: _incomeCategories,
          total: _totalIncome,
          isIncome: true,
        ),
        const SizedBox(height: 16),
        _buildCategoryList(
          theme,
          _incomeCategories,
          isIncome: true,
        ),
      ],
    );
  }

  Widget _buildExpenseSection(
    ThemeData theme,
  ) {
    if (_expenseCategories.isEmpty) {
      return _emptyState(
        theme,
        Icons.pie_chart_outline_rounded,
        _settings.isBangla
            ? 'এই সময়ে কোনো ব্যয় নেই'
            : 'No expense for this period',
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          _settings.isBangla
              ? 'ব্যয়ের বিশ্লেষণ'
              : 'Expense Analysis',
          _settings.isBangla
              ? 'ক্যাটাগরি অনুযায়ী ব্যয়'
              : 'Expense by category',
        ),
        const SizedBox(height: 14),
        _buildPieCard(
          theme: theme,
          categories: _expenseCategories,
          total: _totalExpense,
          isIncome: false,
        ),
        const SizedBox(height: 16),
        _buildCategoryList(
          theme,
          _expenseCategories,
          isIncome: false,
        ),
      ],
    );
  }

  Widget _buildPieCard({
    required ThemeData theme,
    required List<Map<String, dynamic>> categories,
    required double total,
    required bool isIncome,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        12,
        20,
        12,
        18,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.green.withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 245,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 65,
                    startDegreeOffset: -90,
                    borderData:
                        FlBorderData(
                      show: false,
                    ),
                    sections: List.generate(
                      categories.length,
                      (index) {
                        final value =
                            _doubleValue(
                          categories[index]
                              ['amount'],
                        );

                        final double percentage =
                            total <= 0.0
                                ? 0.0
                                : (value /
                                        total) *
                                    100.0;

                        return PieChartSectionData(
                          value: value,
                          color:
                              _categoryColor(
                            categories[index],
                            index,
                          ),
                          radius: 72,
                          title: percentage >= 5.0
                              ? '${percentage.toStringAsFixed(0)}%'
                              : '',
                          titleStyle:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w800,
                          ),
                          titlePositionPercentageOffset:
                              0.55,
                        );
                      },
                    ),
                  ),
                ),
                Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      isIncome
                          ? Icons
                              .account_balance_wallet_rounded
                          : Icons
                              .payments_rounded,
                      color: isIncome
                          ? Colors.green
                          : Colors.redAccent,
                      size: 25,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _settings.isBangla
                          ? (isIncome
                              ? 'মোট আয়'
                              : 'মোট ব্যয়')
                          : (isIncome
                              ? 'Total Income'
                              : 'Total Expense'),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(
                              alpha: 0.65,
                            ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _money(total),
                      style:
                          const TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment:
                WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: List.generate(
              categories.length > 8
                  ? 8
                  : categories.length,
              (index) {
                final category =
                    categories[index];

                return Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration:
                          BoxDecoration(
                        color:
                            _categoryColor(
                          category,
                          index,
                        ),
                        shape:
                            BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      category[
                              'category_name']
                          .toString(),
                      style:
                          const TextStyle(
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(
    ThemeData theme,
    List<Map<String, dynamic>> categories, {
    required bool isIncome,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          _settings.isBangla
              ? 'ক্যাটাগরি বিস্তারিত'
              : 'Category Details',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(
          categories.length,
          (index) {
            final category =
                categories[index];

            final double amount =
                _doubleValue(
              category['amount'],
            );

            final double total =
                isIncome
                    ? _totalIncome
                    : _totalExpense;

            final double percentage =
                total > 0.0
                    ? (amount / total) *
                        100.0
                    : 0.0;

            return _categoryTile(
              theme,
              category,
              amount,
              percentage,
              index,
              isIncome,
            );
          },
        ),
      ],
    );
  }

  Widget _categoryTile(
    ThemeData theme,
    Map<String, dynamic> category,
    double amount,
    double percentage,
    int index,
    bool isIncome,
  ) {
    final color =
        _categoryColor(
      category,
      index,
    );

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 9,
      ),
      child: Material(
        color: theme.cardColor,
        borderRadius:
            BorderRadius.circular(16),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(16),
          onTap: () {
            _showCategoryTransactions(
              category,
              isIncome,
            );
          },
          child: Padding(
            padding:
                const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color: color.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: Icon(
                    isIncome
                        ? Icons
                            .arrow_downward_rounded
                        : Icons
                            .arrow_upward_rounded,
                    color: color,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        category[
                                'category_name']
                            .toString(),
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(20),
                        child:
                            LinearProgressIndicator(
                          value: percentage /
                              100.0,
                          minHeight: 5,
                          backgroundColor:
                              color.withValues(
                            alpha: 0.10,
                          ),
                          valueColor:
                              AlwaysStoppedAnimation<
                                  Color>(
                            color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .end,
                  children: [
                    Text(
                      _money(amount),
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(
                              alpha: 0.6,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoanSection(
    ThemeData theme,
  ) {
    final double totalLoan =
        _myDebt + _myReceivable;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          theme,
          _settings.isBangla
              ? 'লোনের বিশ্লেষণ'
              : 'Loan Analysis',
          _settings.isBangla
              ? 'বর্তমান পাওনা ও দেনার হিসাব'
              : 'Current receivable and payable',
        ),
        const SizedBox(height: 14),
        Container(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            20,
            12,
            18,
          ),
          decoration:
              BoxDecoration(
            color: theme.cardColor,
            borderRadius:
                BorderRadius.circular(22),
            border: Border.all(
              color:
                  AppTheme.gold.withValues(
                alpha: 0.18,
              ),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 230,
                child: totalLoan <= 0.0
                    ? Center(
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Icon(
                              Icons
                                  .handshake_outlined,
                              size: 60,
                              color: AppTheme
                                  .gold
                                  .withValues(
                                alpha: 0.65,
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text(
                              _settings
                                      .isBangla
                                  ? 'বর্তমানে কোনো বাকি লোন নেই'
                                  : 'No outstanding loans',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                                color: theme
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        alignment:
                            Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 4,
                              centerSpaceRadius:
                                  64,
                              startDegreeOffset:
                                  -90,
                              borderData:
                                  FlBorderData(
                                show: false,
                              ),
                              sections: [
                                PieChartSectionData(
                                  value: _myDebt,
                                  color: Colors
                                      .redAccent,
                                  radius: 72,
                                  title: _myDebt >
                                          0.0
                                      ? '${((_myDebt / totalLoan) * 100.0).toStringAsFixed(0)}%'
                                      : '',
                                  titleStyle:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        12,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                                ),
                                PieChartSectionData(
                                  value:
                                      _myReceivable,
                                  color:
                                      AppTheme
                                          .green,
                                  radius: 72,
                                  title:
                                      _myReceivable >
                                              0.0
                                          ? '${((_myReceivable / totalLoan) * 100.0).toStringAsFixed(0)}%'
                                          : '',
                                  titleStyle:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        12,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children: [
                              const Icon(
                                Icons
                                    .handshake_rounded,
                                color:
                                    AppTheme
                                        .gold,
                                size: 27,
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                _settings
                                        .isBangla
                                    ? 'লোন'
                                    : 'Loans',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 2,
                              ),
                              Text(
                                _money(
                                  totalLoan,
                                ),
                                style:
                                    const TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child:
                        _loanLegendCard(
                      theme: theme,
                      title: _settings
                              .isBangla
                          ? 'আমার দেনা'
                          : 'My Debt',
                      subtitle: _settings
                              .isBangla
                          ? 'অন্যকে শোধ করতে হবে'
                          : 'I have to repay',
                      amount: _myDebt,
                      color:
                          Colors.redAccent,
                      icon: Icons
                          .arrow_upward_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child:
                        _loanLegendCard(
                      theme: theme,
                      title: _settings
                              .isBangla
                          ? 'আমার পাওনা'
                          : 'My Receivable',
                      subtitle: _settings
                              .isBangla
                          ? 'অন্যের কাছ থেকে পাব'
                          : 'Others owe me',
                      amount:
                          _myReceivable,
                      color:
                          AppTheme.green,
                      icon: Icons
                          .arrow_downward_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _settings.isBangla
              ? 'লোনের লেনদেন'
              : 'Loan Transactions',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _buildLoanMovementGrid(theme),
      ],
    );
  }

  Widget _loanLegendCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(
            alpha: 0.16,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: color,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _money(amount),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: theme.textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(
                    alpha: 0.6,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanMovementGrid(
    ThemeData theme,
  ) {
    double given = 0.0;
    double received = 0.0;
    double taken = 0.0;
    double paid = 0.0;

    for (final tx in _allTransactions) {
      final date =
          _transactionDate(tx);

      if (date == null ||
          _startDate == null ||
          _endDate == null ||
          date.isBefore(_startDate!) ||
          date.isAfter(_endDate!)) {
        continue;
      }

      final type = _stringValue(
        tx['type'],
      ).toLowerCase();

      final amount = _doubleValue(
        tx['amount'],
      );

      switch (type) {
        case 'loan_given':
          given += amount;
          break;

        case 'loan_received':
          received += amount;
          break;

        case 'loan_taken':
          taken += amount;
          break;

        case 'loan_paid':
          paid += amount;
          break;
      }
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        _movementCard(
          theme,
          _settings.isBangla
              ? 'ধার দিয়েছি'
              : 'Given',
          given,
          Icons.call_made_rounded,
          AppTheme.green,
        ),
        _movementCard(
          theme,
          _settings.isBangla
              ? 'ফেরত পেয়েছি'
              : 'Received',
          received,
          Icons.call_received_rounded,
          Colors.blue,
        ),
        _movementCard(
          theme,
          _settings.isBangla
              ? 'ধার নিয়েছি'
              : 'Taken',
          taken,
          Icons.south_west_rounded,
          Colors.orange,
        ),
        _movementCard(
          theme,
          _settings.isBangla
              ? 'শোধ করেছি'
              : 'Paid',
          paid,
          Icons.north_east_rounded,
          Colors.redAccent,
        ),
      ],
    );
  }

  Widget _movementCard(
    ThemeData theme,
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(
            alpha: 0.14,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(
                          alpha: 0.65,
                        ),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    _money(amount),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    ThemeData theme,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.gold,
            borderRadius:
                BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: theme
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(
                        alpha: 0.60,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState(
    ThemeData theme,
    IconData icon,
    String text,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 55,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 58,
            color: AppTheme.gold
                .withValues(
              alpha: 0.65,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontWeight:
                  FontWeight.w600,
              color: theme.textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(
                    alpha: 0.65,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void>
      _showCategoryTransactions(
    Map<String, dynamic> category,
    bool isIncome,
  ) async {
    final categoryId =
        _intValue(
      category['category_id'],
    );

    final transactions =
        _allTransactions.where((tx) {
      final type = _stringValue(
        tx['type'],
      ).toLowerCase();

      if (type !=
          (isIncome
              ? 'income'
              : 'expense')) {
        return false;
      }

      final date =
          _transactionDate(tx);

      if (date == null ||
          _startDate == null ||
          _endDate == null ||
          date.isBefore(_startDate!) ||
          date.isAfter(_endDate!)) {
        return false;
      }

      if (categoryId != 0) {
        return _intValue(
              tx['category_id'],
            ) ==
            categoryId;
      }

      return _categoryName(tx) ==
          category['category_name']
              .toString();
    }).toList();

    transactions.sort(
      (a, b) {
        final da =
            _transactionDate(a);
        final db =
            _transactionDate(b);

        if (da == null &&
            db == null) {
          return 0;
        }

        if (da == null) {
          return 1;
        }

        if (db == null) {
          return -1;
        }

        return db.compareTo(da);
      },
    );

    if (!mounted) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        return Container(
          height:
              MediaQuery.of(
                sheetContext,
              ).size.height *
              0.72,
          decoration: BoxDecoration(
            color: theme
                .scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration:
                    BoxDecoration(
                  color:
                      theme.dividerColor,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            category[
                                    'category_name']
                                .toString(),
                            style:
                                const TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            _settings.isBangla
                                ? '${transactions.length}টি লেনদেন'
                                : '${transactions.length} transactions',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money(
                        _doubleValue(
                          category[
                              'amount'],
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                        color: isIncome
                            ? Colors.green
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
              ),
              Expanded(
                child: transactions
                        .isEmpty
                    ? Center(
                        child: Text(
                          _settings
                                  .isBangla
                              ? 'কোনো লেনদেন পাওয়া যায়নি'
                              : 'No transactions found',
                        ),
                      )
                    : ListView
                        .separated(
                        padding:
                            const EdgeInsets
                                .all(16),
                        itemCount:
                            transactions
                                .length,
                        separatorBuilder:
                            (_, __) =>
                                const SizedBox(
                          height: 8,
                        ),
                        itemBuilder:
                            (_, index) {
                          return _transactionItem(
                            theme,
                            transactions[
                                index],
                            isIncome,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _transactionItem(
    ThemeData theme,
    Map<String, dynamic> tx,
    bool isIncome,
  ) {
    final amount =
        _doubleValue(
      tx['amount'],
    );

    final date =
        _transactionDate(tx);

    final note = tx['note'] ??
        tx['description'] ??
        tx['details'] ??
        '';

    String dateText = '';

    if (date != null) {
      dateText =
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color: (isIncome
                      ? Colors.green
                      : Colors.redAccent)
                  .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              isIncome
                  ? Icons
                      .south_west_rounded
                  : Icons
                      .north_east_rounded,
              color: isIncome
                  ? Colors.green
                  : Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  note
                          .toString()
                          .trim()
                          .isEmpty
                      ? (isIncome
                          ? (_settings
                                  .isBangla
                              ? 'আয়'
                              : 'Income')
                          : (_settings
                                  .isBangla
                              ? 'ব্যয়'
                              : 'Expense'))
                      : note.toString(),
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                if (dateText
                    .isNotEmpty) ...[
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    dateText,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _money(amount),
            style: TextStyle(
              fontWeight:
                  FontWeight.w800,
              color: isIncome
                  ? Colors.green
                  : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}
