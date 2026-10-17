import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../services/money_db.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ScreenshotController _screenshotController =
      ScreenshotController();

  static const Color _gold = Color(0xFFC9A45C);
  static const Color _incomeColor = Color(0xFF2E7D32);
  static const Color _expenseColor = Color(0xFFC62828);
  static const Color _loanGiveColor = Color(0xFF1565C0);
  static const Color _loanTakeColor = Color(0xFF8E24AA);
  static const Color _loanReceiveColor = Color(0xFF00897B);
  static const Color _loanPaidColor = Color(0xFFEF6C00);

  static const double _a4Width = 794;
  static const double _a4Height = 1123;

  String _period = 'monthly';

  DateTime _startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
    23,
    59,
    59,
    999,
  );

  // দৈনিক খরচের ক্যালেন্ডার
  DateTime _calendarMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime? _selectedCalendarDate;

  bool _loading = true;
  bool _saving = false;

  double _income = 0;
  double _expense = 0;

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _incomeCategories = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _loanPeriodTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final dynamic incomeResult =
          await MoneyDb.instance.getTotalIncome(
        startDate: _startDate,
        endDate: _endDate,
      );

      final dynamic expenseResult =
          await MoneyDb.instance.getTotalExpense(
        startDate: _startDate,
        endDate: _endDate,
      );

      final dynamic transactionResult =
          await MoneyDb.instance.getTransactions(
        startDate: _startDate,
        endDate: _endDate,
      );

      final dynamic incomeCategoryResult =
          await MoneyDb.instance.getIncomeByCategory(
        startDate: _startDate,
        endDate: _endDate,
      );

      final dynamic expenseCategoryResult =
          await MoneyDb.instance.getExpenseByCategory(
        startDate: _startDate,
        endDate: _endDate,
      );

      final dynamic loansResult =
          await MoneyDb.instance.getLoans();

      final double loadedIncome = _toDouble(incomeResult);
      final double loadedExpense = _toDouble(expenseResult);

      final List<Map<String, dynamic>> loadedTransactions =
          _toDynamicMapList(transactionResult);

      final List<Map<String, dynamic>> loadedIncomeCategories =
          _toDynamicMapList(incomeCategoryResult);

      final List<Map<String, dynamic>> loadedExpenseCategories =
          _toDynamicMapList(expenseCategoryResult);

      final List<Map<String, dynamic>> loadedLoans =
          _toDynamicMapList(loansResult);

      final List<Map<String, dynamic>> loadedLoanTransactions =
          loadedTransactions.where((tx) {
        final type = _transactionType(tx);

        return type == 'loan_given' ||
            type == 'loan_taken' ||
            type == 'loan_received' ||
            type == 'loan_paid';
      }).toList();

      if (!mounted) return;

      setState(() {
        _income = loadedIncome;
        _expense = loadedExpense;
        _transactions = loadedTransactions;
        _incomeCategories = loadedIncomeCategories;
        _expenseCategories = loadedExpenseCategories;
        _loans = loadedLoans;
        _loanPeriodTransactions = loadedLoanTransactions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('রিপোর্ট লোড করতে সমস্যা হয়েছে: $e'),
        ),
      );
    }
  }

  // ক্যালেন্ডারের মাস পরিবর্তন
  void _changeCalendarMonth(int offset) {
    setState(() {
      _calendarMonth = DateTime(
        _calendarMonth.year,
        _calendarMonth.month + offset,
        1,
      );
      _selectedCalendarDate = null;
    });
  }

  String _calendarMonthTitle(DateTime date) {
    const months = [
      'জানুয়ারি',
      'ফেব্রুয়ারি',
      'মার্চ',
      'এপ্রিল',
      'মে',
      'জুন',
      'জুলাই',
      'আগস্ট',
      'সেপ্টেম্বর',
      'অক্টোবর',
      'নভেম্বর',
      'ডিসেম্বর',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }
DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();

  if (value is DateTime) return value;

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  final text = value.toString().trim();
  return DateTime.tryParse(text) ?? DateTime.now();
}
  DateTime _transactionDate(Map<String, dynamic> tx) {
    return _parseDate(
      tx['date'] ??
          tx['created_at'] ??
          tx['transaction_date'],
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  double _dailyExpense(DateTime day) {
    double total = 0;

    for (final tx in _transactions) {
      if (_transactionType(tx) != 'expense') continue;

      if (_sameDay(_transactionDate(tx), day)) {
        total += _amount(tx);
      }
    }

    return total;
  }

  List<Map<String, dynamic>> _transactionsForDay(
    DateTime day,
  ) {
    return _transactions.where((tx) {
      return _sameDay(_transactionDate(tx), day);
    }).toList();
  }

  void _showDayTransactions(DateTime day) {
    final dayTransactions = _transactionsForDay(day);

    setState(() {
      _selectedCalendarDate = day;
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${_dateText(day)} — দৈনিক লেনদেন',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: dayTransactions.isEmpty
                      ? const Center(
                          child: Text('এই দিনে কোনো লেনদেন নেই'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: dayTransactions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tx = dayTransactions[index];
                            final type = _transactionType(tx);
                            final isExpense = type == 'expense';
                            final color = isExpense
                                ? _expenseColor
                                : type == 'income'
                                    ? _incomeColor
                                    : _gold;

                            final title = _stringValue(
                              tx,
                              const [
                                'category',
                                'category_name',
                                'note',
                                'details',
                                'description',
                                'type',
                              ],
                            );

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    color.withValues(alpha: 0.12),
                                child: Icon(
                                  isExpense
                                      ? Icons.arrow_upward_rounded
                                      : type == 'income'
                                          ? Icons.arrow_downward_rounded
                                          : Icons.receipt_long_rounded,
                                  color: color,
                                ),
                              ),
                              title: Text(
                                title.isEmpty ? 'লেনদেন' : title,
                              ),
                              subtitle: Text(
                                _transactionTypeText(type),
                              ),
                              trailing: Text(
                                _money(_amount(tx)),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'মোট ব্যয়: ${_money(_dailyExpense(day))}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
String _transactionTypeText(String type) {
  switch (type) {
    case 'expense':
      return 'ব্যয়';
    case 'income':
      return 'আয়';
    case 'transfer':
      return 'ট্রান্সফার';
    default:
      return 'লেনদেন';
  }
}
  Widget _buildExpenseCalendar() {
    final firstDay = DateTime(
      _calendarMonth.year,
      _calendarMonth.month,
      1,
    );

    final daysInMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + 1,
      0,
    ).day;

    // সোমবার থেকে শুরু: সোমবার=0, রবিবার=6
    final leadingDays = firstDay.weekday - DateTime.monday;

    final totalCells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: _gold,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'দৈনিক ব্যয়ের ক্যালেন্ডার',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'আগের মাস',
                  onPressed: () => _changeCalendarMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'পরের মাস',
                  onPressed: () => _changeCalendarMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Center(
              child: Text(
                _calendarMonthTitle(_calendarMonth),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _gold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                'সোম',
                'মঙ্গল',
                'বুধ',
                'বৃহঃ',
                'শুক্র',
                'শনি',
                'রবি',
              ].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalCells,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.76,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - leadingDays + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final day = DateTime(
                  _calendarMonth.year,
                  _calendarMonth.month,
                  dayNumber,
                );

                final expense = _dailyExpense(day);
                final selected = _selectedCalendarDate != null &&
                    _sameDay(_selectedCalendarDate!, day);

                final today = _sameDay(DateTime.now(), day);

                return Material(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : expense > 0
                          ? _expenseColor.withValues(alpha: 0.10)
                          : today
                              ? _gold.withValues(alpha: 0.14)
                              : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => _showDayTransactions(day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 1,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : today
                                  ? _gold
                                  : Colors.grey.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimary
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (expense > 0)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _compactMoney(expense),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: selected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                      : _expenseColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 9),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'যে তারিখে ব্যয় আছে, সেখানে টাকার পরিমাণ দেখা যাবে। তারিখে চাপ দিলে ওই দিনের সব লেনদেন দেখাবে।',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _compactMoney(double value) {
    if (value >= 10000000) {
      return '৳${(value / 10000000).toStringAsFixed(1)}কো';
    }
    if (value >= 100000) {
      return '৳${(value / 100000).toStringAsFixed(1)}ল';
    }
    if (value >= 1000) {
      return '৳${(value / 1000).toStringAsFixed(1)}হা';
    }
    return '৳${value.toStringAsFixed(0)}';
  }

  Future<void> _changePeriod(String value) async {
    final now = DateTime.now();

    if (value == 'monthly') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(
        now.year,
        now.month + 1,
        0,
        23,
        59,
        59,
        999,
      );
    } else if (value == 'weekly') {
      final today = DateTime(now.year, now.month, now.day);
      final daysFromMonday = today.weekday - DateTime.monday;

      _startDate = today.subtract(Duration(days: daysFromMonday));
      _endDate = _startDate.add(
        const Duration(
          days: 6,
          hours: 23,
          minutes: 59,
          seconds: 59,
          milliseconds: 999,
        ),
      );
    } else if (value == 'yearly') {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
    }

    setState(() {
      _period = value;
    });

    if (value != 'custom') {
      await _loadReport();
    }
  }

  Future<void> _pickCustomDate() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      helpText: 'রিপোর্টের সময় নির্বাচন করুন',
      saveText: 'নির্বাচন করুন',
      cancelText: 'বাতিল',
    );

    if (range == null) return;

    setState(() {
      _period = 'custom';
      _startDate = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      _endDate = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
        999,
      );
    });

    await _loadReport();
  }

  String get _periodTitle {
    switch (_period) {
      case 'weekly':
        return 'সাপ্তাহিক রিপোর্ট';
      case 'yearly':
        return 'বার্ষিক রিপোর্ট';
      case 'custom':
        return 'নির্বাচিত সময়ের রিপোর্ট';
      case 'monthly':
      default:
        return 'মাসিক রিপোর্ট';
    }
  }

  String get _dateRangeText =>
      '${_dateText(_startDate)} - ${_dateText(_endDate)}';

  double get _difference => _income - _expense;
  bool get _isSurplus => _difference >= 0;

  double get _loanGivenPeriod => _loanPeriodAmount('loan_given');
  double get _loanTakenPeriod => _loanPeriodAmount('loan_taken');
  double get _loanReceivedPeriod =>
      _loanPeriodAmount('loan_received');
  double get _loanPaidPeriod => _loanPeriodAmount('loan_paid');

  double _loanPeriodAmount(String type) {
    double total = 0;
    for (final tx in _loanPeriodTransactions) {
      if (_transactionType(tx) == type) total += _amount(tx);
    }
    return total;
  }

  double get _totalReceivable {
    double total = 0;
    for (final loan in _loans) {
      final type = _stringValue(loan, const ['type', 'loan_type']);
      if (type == 'receivable') total += _loanRemaining(loan);
    }
    return total;
  }

  double get _totalPayable {
    double total = 0;
    for (final loan in _loans) {
      final type = _stringValue(loan, const ['type', 'loan_type']);
      if (type == 'payable') total += _loanRemaining(loan);
    }
    return total;
  }

  Map<String, double> get _receivablePeople {
    final Map<String, double> result = {};
    for (final loan in _loans) {
      final type = _stringValue(loan, const ['type', 'loan_type']);
      if (type != 'receivable') continue;
      final person = _loanPerson(loan);
      if (person.isEmpty) continue;
      final remaining = _loanRemaining(loan);
      if (remaining <= 0) continue;
      result[person] = (result[person] ?? 0) + remaining;
    }
    return result;
  }

  Map<String, double> get _payablePeople {
    final Map<String, double> result = {};
    for (final loan in _loans) {
      final type = _stringValue(loan, const ['type', 'loan_type']);
      if (type != 'payable') continue;
      final person = _loanPerson(loan);
      if (person.isEmpty) continue;
      final remaining = _loanRemaining(loan);
      if (remaining <= 0) continue;
      result[person] = (result[person] ?? 0) + remaining;
    }
    return result;
  }

  double _loanRemaining(Map<String, dynamic> loan) {
    return _toDouble(
      loan['remaining'] ??
          loan['remaining_amount'] ??
          loan['balance'] ??
          loan['amount'],
    );
  }

  String _loanPerson(Map<String, dynamic> loan) {
    return _stringValue(
      loan,
      const ['person', 'person_name', 'name', 'party', 'customer'],
    );
  }
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('রিপোর্ট'),
        actions: [
          IconButton(
            tooltip: 'রিফ্রেশ',
            onPressed: _loading || _saving ? null : _loadReport,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                children: [
                  _buildExpenseCalendar(),
                  const SizedBox(height: 12),
                  _buildPeriodSelector(),
                  const SizedBox(height: 12),
                  Center(
                    child: Screenshot(
                      controller: _screenshotController,
                      child: _buildA4ReportPage(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildExportButtons(),
                  const SizedBox(height: 14),
                  _buildTransactionDetailsButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildA4ReportPage() {
    return SizedBox(
      width: _a4Width,
      height: _a4Height,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border.all(
              color: _gold.withValues(alpha: 0.65),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 698,
                      child: _buildVoucherContent(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildSignatureArea(),
              const SizedBox(height: 6),
              _buildVoucherFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'রিপোর্ট সংরক্ষণ ও শেয়ার',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _exportButton(
                  icon: Icons.image_rounded,
                  label: 'JPG সংরক্ষণ',
                  onPressed: _saving ? null : _saveJpg,
                ),
                _exportButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF তৈরি ও শেয়ার',
                  onPressed: _saving ? null : _savePdf,
                ),
                _exportButton(
                  icon: Icons.share_rounded,
                  label: 'শেয়ার করুন',
                  onPressed: _saving ? null : _shareImage,
                ),
              ],
            ),
            if (_saving) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('প্রস্তুত হচ্ছে...', style: TextStyle(fontSize: 13)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _exportButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'রিপোর্টের সময়',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _period,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.date_range_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'weekly',
                  child: Text('এই সপ্তাহ'),
                ),
                DropdownMenuItem(
                  value: 'monthly',
                  child: Text('এই মাস'),
                ),
                DropdownMenuItem(
                  value: 'yearly',
                  child: Text('এই বছর'),
                ),
                DropdownMenuItem(
                  value: 'custom',
                  child: Text('নিজে সময় নির্বাচন করুন'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == 'custom') {
                  _pickCustomDate();
                } else {
                  _changePeriod(value);
                }
              },
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _dateRangeText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_period == 'custom')
                    IconButton(
                      tooltip: 'তারিখ পরিবর্তন',
                      onPressed: _pickCustomDate,
                      icon: const Icon(Icons.edit_calendar_rounded),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader(),
        const SizedBox(height: 14),
        _buildSummarySection(),
        const SizedBox(height: 14),
        _buildCategorySection(
          title: 'আয়ের খাত',
          categories: _incomeCategories,
          color: _incomeColor,
          emptyText: 'এই সময়ে কোনো আয় নেই',
        ),
        const SizedBox(height: 12),
        _buildCategorySection(
          title: 'ব্যয়ের খাত',
          categories: _expenseCategories,
          color: _expenseColor,
          emptyText: 'এই সময়ে কোনো ব্যয় নেই',
        ),
        const SizedBox(height: 14),
        _buildLoanSection(),
      ],
    );
  }

  Widget _buildReportHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F5132),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text(
            'আমার হিসাব',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _periodTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _gold,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _dateRangeText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'সারসংক্ষেপ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'মোট আয়',
                amount: _income,
                icon: Icons.arrow_downward_rounded,
                color: _incomeColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                title: 'মোট ব্যয়',
                amount: _expense,
                icon: Icons.arrow_upward_rounded,
                color: _expenseColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        _differenceCard(),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              _money(amount),
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _differenceCard() {
    final color = _isSurplus ? _incomeColor : _expenseColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            _isSurplus
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSurplus ? 'উদ্বৃত্ত' : 'ঘাটতি',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _money(_difference.abs()),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection({
    required String title,
    required List<Map<String, dynamic>> categories,
    required Color color,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.category_rounded, color: color, size: 21),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          _emptyBox(emptyText)
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < categories.length; i++)
                  _categoryRow(
                    categories[i],
                    color,
                    i == categories.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _categoryRow(
    Map<String, dynamic> item,
    Color color,
    bool last,
  ) {
    final name = _categoryName(item);
    final amount = _categoryAmount(item);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: color.withValues(alpha: 0.12),
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.isEmpty ? 'অন্যান্য' : name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            _money(amount),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.withValues(alpha: 0.06),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.color
              ?.withValues(alpha: 0.65),
        ),
      ),
    );
  }

  Widget _buildLoanSection() {
    final receivablePeople = _receivablePeople;
    final payablePeople = _payablePeople;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: _gold,
              size: 22,
            ),
            SizedBox(width: 7),
            Text(
              'ব্যক্তিগত Loan',
              style: TextStyle(
                color: _gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        _buildLoanPeriodGrid(),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _loanCurrentCard(
                title: 'আমি পাব',
                subtitle: 'আমার কাছে পাওনা',
                amount: _totalReceivable,
                color: _loanReceiveColor,
                icon: Icons.call_received_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _loanCurrentCard(
                title: 'আমার কাছে পাবে',
                subtitle: 'আমার দেনা',
                amount: _totalPayable,
                color: _loanPaidColor,
                icon: Icons.call_made_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildPeopleOutstanding(
          title: 'আমি পাব',
          people: receivablePeople,
          color: _loanReceiveColor,
          emptyText: 'কারো কাছে আমার পাওনা নেই',
        ),
        const SizedBox(height: 9),
        _buildPeopleOutstanding(
          title: 'আমার কাছে পাবে',
          people: payablePeople,
          color: _loanPaidColor,
          emptyText: 'কারো কাছে আমার দেনা নেই',
        ),
      ],
    );
  }

  Widget _buildLoanPeriodGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.15,
      children: [
        _loanSmallCard('এই সময়ে দিয়েছি', _loanGivenPeriod, _loanGiveColor),
        _loanSmallCard('এই সময়ে নিয়েছি', _loanTakenPeriod, _loanTakeColor),
        _loanSmallCard(
          'এই সময়ে ফেরত পেয়েছি',
          _loanReceivedPeriod,
          _loanReceiveColor,
        ),
        _loanSmallCard('এই সময়ে পরিশোধ', _loanPaidPeriod, _loanPaidColor),
      ],
    );
  }

  Widget _loanSmallCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              _money(amount),
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loanCurrentCard({
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              _money(amount),
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleOutstanding({
    required String title,
    required Map<String, double> people,
    required Color color,
    required String emptyText,
  }) {
    final entries = people.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                emptyText,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.65),
                ),
              ),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _money(entry.value),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
    Widget _buildSignatureArea() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 190,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(height: 1, color: Colors.grey.shade600),
                const SizedBox(height: 4),
                const Text(
                  'স্বাক্ষর',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetailsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saving
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailsScreen(
                      transactions: _transactions,
                      startDate: _startDate,
                      endDate: _endDate,
                      periodTitle: _periodTitle,
                    ),
                  ),
                );
              },
        icon: const Icon(Icons.receipt_long_rounded),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 13),
          child: Text(
            'লেনদেনের বিস্তারিত',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoucherFooter() {
    return Column(
      children: [
        Divider(color: _gold.withValues(alpha: 0.35)),
        const SizedBox(height: 5),
        const Text(
          'আমার হিসাব অ্যাপ',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _gold,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Developed by Sayeed Mahadi',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10),
        ),
        const Text(
          'mahadisayeed@gmail.com',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  Future<File?> _captureReport() async {
    final controller = ScreenshotController();

    final Uint8List bytes = await controller.captureFromWidget(
      Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: MediaQuery(
          data: MediaQuery.of(context),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: _a4Width,
              height: _a4Height,
              child: _buildA4ReportPage(),
            ),
          ),
        ),
      ),
      delay: const Duration(milliseconds: 300),
      pixelRatio: 2.0,
    );

    if (bytes.isEmpty) return null;

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/amar_hisab_report_a4.png',
    );

    await file.writeAsBytes(bytes, flush: true);

    if (!await file.exists() || await file.length() <= 0) {
      return null;
    }

    return file;
  }

  Future<void> _saveJpg() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final pngFile = await _captureReport();

      if (pngFile == null) {
        throw Exception('রিপোর্টের ছবি তৈরি করা যায়নি');
      }

      final pngBytes = await pngFile.readAsBytes();
      final decoded = img.decodeImage(pngBytes);

      if (decoded == null) {
        throw Exception('ছবি decode করা যায়নি');
      }

      final jpgBytes = img.encodeJpg(decoded, quality: 95);

      if (jpgBytes.isEmpty) {
        throw Exception('JPG তৈরি করা যায়নি');
      }

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/amar_hisab_report_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await file.writeAsBytes(jpgBytes, flush: true);

      final saved = await GallerySaver.saveImage(
        file.path,
        albumName: 'আমার হিসাব',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved == true
                ? 'রিপোর্ট A4 JPG হিসেবে Gallery-তে সংরক্ষণ হয়েছে'
                : 'JPG তৈরি হয়েছে, কিন্তু Gallery-তে সংরক্ষণ করা যায়নি',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JPG তৈরি করতে সমস্যা হয়েছে: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareImage() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final pngFile = await _captureReport();

      if (pngFile == null) {
        throw Exception('রিপোর্ট ছবি তৈরি করা যায়নি');
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pngFile.path)],
          text: 'আমার হিসাব - $_periodTitle\n$_dateRangeText',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('শেয়ার করতে সমস্যা হয়েছে: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<pw.Font> _loadPdfFont() async {
    try {
      final data = await rootBundle.load(
        'assets/fonts/NotoSansBengali-Regular.ttf',
      );
      return pw.Font.ttf(data);
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  Future<void> _savePdf() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final font = await _loadPdfFont();
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: font,
          ),
          build: (context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.amber700,
                  width: 0.8,
                ),
              ),
              padding: const pw.EdgeInsets.all(22),
              child: pw.Column(
                children: [
                  pw.Expanded(
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.topCenter,
                      child: _buildPdfOverview(font),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  _buildPdfSignatureArea(font),
                  pw.SizedBox(height: 6),
                  _buildPdfFooter(font),
                ],
              ),
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/amar_hisab_report.pdf');

      await file.writeAsBytes(await pdf.save(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'আমার হিসাব - $_periodTitle\n$_dateRangeText',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF তৈরি করতে সমস্যা হয়েছে: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  pw.Widget _buildPdfOverview(pw.Font font) {
    return pw.SizedBox(
      width: 540,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#0F5132'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'আমার হিসাব',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 23,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _periodTitle,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#C9A45C'),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _dateRangeText,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'সারসংক্ষেপ',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                children: [
                  _pdfCell('মোট আয়', font, bold: true),
                  _pdfCell('মোট ব্যয়', font, bold: true),
                  _pdfCell(_isSurplus ? 'উদ্বৃত্ত' : 'ঘাটতি', font, bold: true),
                ],
              ),
              pw.TableRow(
                children: [
                  _pdfCell(_money(_income), font),
                  _pdfCell(_money(_expense), font),
                  _pdfCell(_money(_difference.abs()), font),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _pdfCategorySection('আয়ের খাত', _incomeCategories, font),
          pw.SizedBox(height: 8),
          _pdfCategorySection('ব্যয়ের খাত', _expenseCategories, font),
          pw.SizedBox(height: 10),
          _pdfLoanReport(font),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(
    String text,
    pw.Font font, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _pdfCategorySection(
    String title,
    List<Map<String, dynamic>> categories,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        if (categories.isEmpty)
          pw.Text(
            'কোনো তথ্য নেই',
            style: pw.TextStyle(font: font, fontSize: 8),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                children: [
                  _pdfCell('খাত', font, bold: true),
                  _pdfCell('পরিমাণ', font, bold: true),
                ],
              ),
              ...categories.map((item) {
                final name = _categoryName(item);
                return pw.TableRow(
                  children: [
                    _pdfCell(name.isEmpty ? 'অন্যান্য' : name, font),
                    _pdfCell(_money(_categoryAmount(item)), font),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  pw.Widget _pdfLoanReport(pw.Font font) {
    final receivable = _receivablePeople.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final payable = _payablePeople.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ব্যক্তিগত Loan',
          style: pw.TextStyle(
            font: font,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              children: [
                _pdfCell('এই সময়ে দিয়েছি', font, bold: true),
                _pdfCell('এই সময়ে নিয়েছি', font, bold: true),
              ],
            ),
            pw.TableRow(
              children: [
                _pdfCell(_money(_loanGivenPeriod), font),
                _pdfCell(_money(_loanTakenPeriod), font),
              ],
            ),
            pw.TableRow(
              children: [
                _pdfCell('ফেরত পেয়েছি', font, bold: true),
                _pdfCell('পরিশোধ করেছি', font, bold: true),
              ],
            ),
            pw.TableRow(
              children: [
                _pdfCell(_money(_loanReceivedPeriod), font),
                _pdfCell(_money(_loanPaidPeriod), font),
              ],
            ),
            pw.TableRow(
              children: [
                _pdfCell('বর্তমানে আমি পাব', font, bold: true),
                _pdfCell('বর্তমানে আমার কাছে পাবে', font, bold: true),
              ],
            ),
            pw.TableRow(
              children: [
                _pdfCell(_money(_totalReceivable), font),
                _pdfCell(_money(_totalPayable), font),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'আমি পাব',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  _pdfPeopleTable(receivable, font, 'কারো কাছে আমার পাওনা নেই'),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'আমার কাছে পাবে',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  _pdfPeopleTable(payable, font, 'কারো কাছে আমার দেনা নেই'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfPeopleTable(
    List<MapEntry<String, double>> people,
    pw.Font font,
    String emptyText,
  ) {
    if (people.isEmpty) {
      return pw.Text(
        emptyText,
        style: pw.TextStyle(font: font, fontSize: 7),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          children: [
            _pdfCell('ব্যক্তি', font, bold: true),
            _pdfCell('পরিমাণ', font, bold: true),
          ],
        ),
        ...people.map(
          (entry) => pw.TableRow(
            children: [
              _pdfCell(entry.key, font),
              _pdfCell(_money(entry.value), font),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfSignatureArea(pw.Font font) {
    return pw.Container(
      width: double.infinity,
      height: 40,
      alignment: pw.Alignment.bottomRight,
      child: pw.SizedBox(
        width: 150,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(height: 0.7, color: PdfColors.grey700),
            pw.SizedBox(height: 3),
            pw.Text(
              'স্বাক্ষর',
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfFooter(pw.Font font) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.amber700),
        pw.SizedBox(height: 3),
        pw.Text(
          'আমার হিসাব অ্যাপ',
          style: pw.TextStyle(
            font: font,
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          'Developed by Sayeed Mahadi',
          style: pw.TextStyle(font: font, fontSize: 7),
        ),
        pw.Text(
          'mahadisayeed@gmail.com',
          style: pw.TextStyle(font: font, fontSize: 7),
        ),
      ],
    );
  }

  String _categoryName(Map<String, dynamic> item) {
    return _stringValue(
      item,
      const ['category', 'category_name', 'name', 'title'],
    );
  }

  double _categoryAmount(Map<String, dynamic> item) {
    return _toDouble(
      item['amount'] ??
          item['total'] ??
          item['value'] ??
          item['sum'],
    );
  }

  List<Map<String, dynamic>> _toDynamicMapList(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _transactionType(Map<String, dynamic> map) {
    return _stringValue(
      map,
      const ['type', 'transaction_type'],
    ).toLowerCase();
  }

  double _amount(Map<String, dynamic> map) {
    return _toDouble(
      map['amount'] ??
          map['total'] ??
          map['value'] ??
          map['money'],
    );
  }

  String _stringValue(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();

    return double.tryParse(
          value.toString().replaceAll(',', '').trim(),
        ) ??
        0;
  }

  String _money(double value) => '৳${value.toStringAsFixed(2)}';

  String _dateText(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}
class TransactionDetailsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;
  final DateTime startDate;
  final DateTime endDate;
  final String periodTitle;

  const TransactionDetailsScreen({
    super.key,
    required this.transactions,
    required this.startDate,
    required this.endDate,
    required this.periodTitle,
  });

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState
    extends State<TransactionDetailsScreen> {
  static const double _a4Width = 794;
  static const double _a4Height = 1123;

  static const Color _incomeColor = Color(0xFF2E7D32);
  static const Color _expenseColor = Color(0xFFC62828);
  static const Color _transferColor = Color(0xFF1565C0);
  static const Color _loanColor = Color(0xFF8E24AA);

  final ScreenshotController _screenshotController =
      ScreenshotController();

  bool _saving = false;

  // বড় বিবরণযুক্ত লেনদেন কম, ছোট বিবরণযুক্ত লেনদেন বেশি
  // রাখার জন্য আনুমানিক উচ্চতা ধরে পৃষ্ঠা ভাগ করা হয়।
  List<List<Map<String, dynamic>>> get _transactionPages {
    if (widget.transactions.isEmpty) {
      return [<Map<String, dynamic>>[]];
    }

    const double usableHeight = 760;
    final pages = <List<Map<String, dynamic>>>[];
    var currentPage = <Map<String, dynamic>>[];
    double usedHeight = 0;

    for (final tx in widget.transactions) {
      final estimatedHeight = _estimatedTransactionHeight(tx);

      if (currentPage.isNotEmpty &&
          usedHeight + estimatedHeight > usableHeight) {
        pages.add(currentPage);
        currentPage = <Map<String, dynamic>>[];
        usedHeight = 0;
      }

      currentPage.add(tx);
      usedHeight += estimatedHeight;
    }

    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    return pages;
  }

  double _estimatedTransactionHeight(Map<String, dynamic> tx) {
    double height = 56;

    final category = _stringValue(
      tx,
      const ['category', 'category_name'],
    );
    final account = _stringValue(
      tx,
      const ['account', 'account_name'],
    );
    final person = _stringValue(
      tx,
      const ['person', 'person_name', 'party', 'customer'],
    );
    final note = _stringValue(
      tx,
      const ['note', 'details', 'description'],
    );

    if (category.isNotEmpty) height += 12;
    if (account.isNotEmpty) height += 12;
    if (person.isNotEmpty) height += 12;

    if (note.isNotEmpty) {
      height += 12 * ((note.length / 70).ceil().clamp(1, 5));
    }

    return height;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _transactionPages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('লেনদেনের বিস্তারিত'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          for (int i = 0; i < pages.length; i++) ...[
            Center(
              child: Screenshot(
                controller: i == 0
                    ? _screenshotController
                    : ScreenshotController(),
                child: _buildA4TransactionPage(
                  pages[i],
                  i + 1,
                  pages.length,
                ),
              ),
            ),
            if (i != pages.length - 1)
              const SizedBox(height: 14),
          ],
          const SizedBox(height: 14),
          _buildTransactionExportButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildA4TransactionPage(
    List<Map<String, dynamic>> transactions,
    int pageNumber,
    int totalPages,
  ) {
    return SizedBox(
      width: _a4Width,
      height: _a4Height,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border.all(
              color: const Color(0xFFC9A45C).withValues(alpha: 0.65),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRect(
                  child: transactions.isEmpty
                      ? _emptyTransactions()
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: 698,
                            child: Column(
                              children: transactions
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => _buildTransactionCard(
                                      entry.value,
                                      _globalTransactionIndex(
                                        pageNumber,
                                        entry.key,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              _buildFooter(pageNumber, totalPages),
            ],
          ),
        ),
      ),
    );
  }

  int _globalTransactionIndex(int pageNumber, int localIndex) {
    final pages = _transactionPages;
    int count = 0;

    for (int i = 0; i < pageNumber - 1 && i < pages.length; i++) {
      count += pages[i].length;
    }

    return count + localIndex + 1;
  }

  Widget _buildTransactionExportButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'লেনদেন সংরক্ষণ ও শেয়ার',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _transactionExportButton(
                  icon: Icons.image_rounded,
                  label: 'JPG সংরক্ষণ',
                  onPressed: _saving ? null : _saveJpg,
                ),
                _transactionExportButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF তৈরি ও শেয়ার',
                  onPressed: _saving ? null : _savePdf,
                ),
                _transactionExportButton(
                  icon: Icons.share_rounded,
                  label: 'শেয়ার করুন',
                  onPressed: _saving ? null : _shareImage,
                ),
              ],
            ),
            if (_saving) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('প্রস্তুত হচ্ছে...', style: TextStyle(fontSize: 13)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _transactionExportButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0F5132),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text(
            'আমার হিসাব',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'লেনদেনের বিস্তারিত',
            style: TextStyle(
              color: Color(0xFFC9A45C),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.periodTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          Text(
            '${_dateText(widget.startDate)} - ${_dateText(widget.endDate)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.25),
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 45),
          SizedBox(height: 10),
          Text(
            'এই সময়ে কোনো লেনদেন নেই',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    Map<String, dynamic> tx,
    int index,
  ) {
    final type = _transactionType(tx);
    final color = _transactionColor(type);
    final icon = _transactionIcon(type);
    final typeText = _transactionTypeText(type);
    final amount = _amount(tx);

    final date = _parseDate(
      tx['date'] ??
          tx['created_at'] ??
          tx['transaction_date'],
    );

    final category = _stringValue(
      tx,
      const ['category', 'category_name'],
    );
    final account = _stringValue(
      tx,
      const ['account', 'account_name'],
    );
    final note = _stringValue(
      tx,
      const ['note', 'details', 'description'],
    );
    final person = _stringValue(
      tx,
      const ['person', 'person_name', 'party', 'customer'],
    );
    final fromAccount = _stringValue(
      tx,
      const ['from_account', 'fromAccount', 'account'],
    );
    final toAccount = _stringValue(
      tx,
      const ['to_account', 'toAccount'],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        color: color.withValues(alpha: 0.045),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$index. $typeText',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      _money(amount),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'তারিখ: ${_dateTimeText(date)}',
                  style: const TextStyle(fontSize: 9),
                ),
                if (category.isNotEmpty) _detailLine('খাত', category),
                if (account.isNotEmpty) _detailLine('অ্যাকাউন্ট', account),
                if (person.isNotEmpty) _detailLine('ব্যক্তি', person),
                if (type == 'transfer' &&
                    (fromAccount.isNotEmpty || toAccount.isNotEmpty))
                  _detailLine(
                    'ট্রান্সফার',
                    '${fromAccount.isEmpty ? '-' : fromAccount} → '
                        '${toAccount.isEmpty ? '-' : toAccount}',
                  ),
                if (note.isNotEmpty) _detailLine('বিবরণ', note),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 9),
          children: [
            TextSpan(
              text: '$title: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(int pageNumber, int totalPages) {
    return Column(
      children: [
        const Divider(color: Color(0xFFC9A45C)),
        const SizedBox(height: 4),
        const Text(
          'আমার হিসাব অ্যাপ',
          style: TextStyle(
            color: Color(0xFFC9A45C),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const Text(
          'Developed by Sayeed Mahadi',
          style: TextStyle(fontSize: 9),
        ),
        const Text(
          'mahadisayeed@gmail.com',
          style: TextStyle(fontSize: 8),
        ),
        const SizedBox(height: 3),
        Text(
          'পৃষ্ঠা $pageNumber / $totalPages',
          style: const TextStyle(fontSize: 8),
        ),
      ],
    );
  }

  String _transactionType(Map<String, dynamic> map) {
    return _stringValue(
      map,
      const ['type', 'transaction_type'],
    ).toLowerCase();
  }

  String _transactionTypeText(String type) {
    switch (type) {
      case 'income':
        return 'আয়';
      case 'expense':
        return 'ব্যয়';
      case 'transfer':
        return 'ট্রান্সফার';
      case 'loan_given':
        return 'ধার দিয়েছি';
      case 'loan_taken':
        return 'ধার নিয়েছি';
      case 'loan_received':
        return 'ধার ফেরত পেয়েছি';
      case 'loan_paid':
        return 'ধার পরিশোধ';
      default:
        return type.isEmpty ? 'লেনদেন' : type;
    }
  }

  Color _transactionColor(String type) {
    switch (type) {
      case 'income':
        return _incomeColor;
      case 'expense':
        return _expenseColor;
      case 'transfer':
        return _transferColor;
      case 'loan_given':
      case 'loan_taken':
      case 'loan_received':
      case 'loan_paid':
        return _loanColor;
      default:
        return Colors.grey;
    }
  }

  IconData _transactionIcon(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_downward_rounded;
      case 'expense':
        return Icons.arrow_upward_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'loan_given':
        return Icons.call_made_rounded;
      case 'loan_taken':
        return Icons.call_received_rounded;
      case 'loan_received':
        return Icons.payments_rounded;
      case 'loan_paid':
        return Icons.payment_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value != null) {
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) return parsed;
    }

    return DateTime.now();
  }

  double _amount(Map<String, dynamic> map) {
    return _toDouble(
      map['amount'] ??
          map['total'] ??
          map['value'] ??
          map['money'],
    );
  }

  String _stringValue(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();

    return double.tryParse(
          value.toString().replaceAll(',', '').trim(),
        ) ??
        0;
  }

  String _money(double value) => '৳${value.toStringAsFixed(2)}';

  String _dateText(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _dateTimeText(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');

    return '$d/$m/${date.year} $h:$min';
  }
    Future<File?> _captureTransactionPage({
    required List<Map<String, dynamic>> transactions,
    required int pageNumber,
    required int totalPages,
  }) async {
    final controller = ScreenshotController();

    final Uint8List bytes = await controller.captureFromWidget(
      Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: MediaQuery(
          data: MediaQuery.of(context),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: _a4Width,
              height: _a4Height,
              child: _buildA4TransactionPage(
                transactions,
                pageNumber,
                totalPages,
              ),
            ),
          ),
        ),
      ),
      delay: const Duration(milliseconds: 300),
      pixelRatio: 2.0,
    );

    if (bytes.isEmpty) return null;

    final directory = await getTemporaryDirectory();

    final file = File(
      '${directory.path}/amar_hisab_transactions_page_$pageNumber.png',
    );

    await file.writeAsBytes(bytes, flush: true);

    if (!await file.exists() || await file.length() <= 0) {
      return null;
    }

    return file;
  }

  Future<void> _saveJpg() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final pages = _transactionPages;
      int savedCount = 0;

      for (int i = 0; i < pages.length; i++) {
        final pngFile = await _captureTransactionPage(
          transactions: pages[i],
          pageNumber: i + 1,
          totalPages: pages.length,
        );

        if (pngFile == null) {
          throw Exception('পৃষ্ঠা ${i + 1}-এর ছবি তৈরি করা যায়নি');
        }

        final pngBytes = await pngFile.readAsBytes();
        final decoded = img.decodeImage(pngBytes);

        if (decoded == null) {
          throw Exception('পৃষ্ঠা ${i + 1}-এর ছবি decode করা যায়নি');
        }

        final jpgBytes = img.encodeJpg(decoded, quality: 95);
        final directory = await getTemporaryDirectory();

        final file = File(
          '${directory.path}/amar_hisab_transactions_page_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        await file.writeAsBytes(jpgBytes, flush: true);

        final saved = await GallerySaver.saveImage(
          file.path,
          albumName: 'আমার হিসাব',
        );

        if (saved == true) savedCount++;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$savedCountটি A4 JPG Gallery-তে সংরক্ষণ হয়েছে',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JPG তৈরি করতে সমস্যা হয়েছে: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareImage() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final pages = _transactionPages;
      final List<XFile> files = [];

      for (int i = 0; i < pages.length; i++) {
        final file = await _captureTransactionPage(
          transactions: pages[i],
          pageNumber: i + 1,
          totalPages: pages.length,
        );

        if (file == null) {
          throw Exception('পৃষ্ঠা ${i + 1}-এর ছবি তৈরি করা যায়নি');
        }

        files.add(XFile(file.path));
      }

      await SharePlus.instance.share(
        ShareParams(
          files: files,
          text: 'আমার হিসাব - লেনদেনের বিস্তারিত\n'
              '${_dateText(widget.startDate)} - '
              '${_dateText(widget.endDate)}\n'
              'মোট পৃষ্ঠা: ${pages.length}',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('শেয়ার করতে সমস্যা হয়েছে: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<pw.Font> _loadPdfFont() async {
    try {
      final data = await rootBundle.load(
        'assets/fonts/NotoSansBengali-Regular.ttf',
      );
      return pw.Font.ttf(data);
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  Future<void> _savePdf() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final font = await _loadPdfFont();
      final pdf = pw.Document();
      final pages = _transactionPages;

      for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
        final pageTransactions = pages[pageIndex];

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            theme: pw.ThemeData.withFont(
              base: font,
              bold: font,
            ),
            build: (context) {
              return pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.amber700,
                    width: 0.8,
                  ),
                ),
                padding: const pw.EdgeInsets.all(22),
                child: pw.Column(
                  children: [
                    _buildPdfTransactionHeader(font),
                    pw.SizedBox(height: 10),
                    pw.Expanded(
                      child: pageTransactions.isEmpty
                          ? pw.Center(
                              child: pw.Text(
                                'এই সময়ে কোনো লেনদেন নেই',
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : pw.FittedBox(
                              fit: pw.BoxFit.scaleDown,
                              alignment: pw.Alignment.topCenter,
                              child: pw.SizedBox(
                                width: 540,
                                child: pw.Column(
                                  children: pageTransactions
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => _pdfTransaction(
                                          entry.value,
                                          _globalTransactionIndex(
                                            pageIndex + 1,
                                            entry.key,
                                          ),
                                          font,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                    ),
                    pw.SizedBox(height: 8),
                    _buildPdfTransactionFooter(
                      font,
                      pageIndex + 1,
                      pages.length,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/amar_hisab_transactions.pdf',
      );

      await file.writeAsBytes(await pdf.save(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'আমার হিসাব - লেনদেনের বিস্তারিত\n'
              'মোট পৃষ্ঠা: ${pages.length}',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF তৈরি করতে সমস্যা হয়েছে: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  pw.Widget _buildPdfTransactionHeader(pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0F5132'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'আমার হিসাব',
            style: pw.TextStyle(
              font: font,
              fontSize: 21,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'লেনদেনের বিস্তারিত',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#C9A45C'),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            widget.periodTitle,
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            '${_dateText(widget.startDate)} - '
            '${_dateText(widget.endDate)}',
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTransactionFooter(
    pw.Font font,
    int pageNumber,
    int totalPages,
  ) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.amber700),
        pw.SizedBox(height: 3),
        pw.Text(
          'আমার হিসাব অ্যাপ',
          style: pw.TextStyle(
            font: font,
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          'Developed by Sayeed Mahadi',
          style: pw.TextStyle(font: font, fontSize: 7),
        ),
        pw.Text(
          'mahadisayeed@gmail.com',
          style: pw.TextStyle(font: font, fontSize: 7),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'পৃষ্ঠা $pageNumber / $totalPages',
          style: pw.TextStyle(font: font, fontSize: 7),
        ),
      ],
    );
  }

  pw.Widget _pdfTransaction(
    Map<String, dynamic> tx,
    int index,
    pw.Font font,
  ) {
    final type = _transactionType(tx);

    final date = _parseDate(
      tx['date'] ??
          tx['created_at'] ??
          tx['transaction_date'],
    );

    final typeText = _transactionTypeText(type);
    final amount = _amount(tx);

    final category = _stringValue(
      tx,
      const ['category', 'category_name'],
    );

    final account = _stringValue(
      tx,
      const ['account', 'account_name'],
    );

    final person = _stringValue(
      tx,
      const ['person', 'person_name', 'party', 'customer'],
    );

    final note = _stringValue(
      tx,
      const ['note', 'details', 'description'],
    );

    final fromAccount = _stringValue(
      tx,
      const ['from_account', 'fromAccount', 'account'],
    );

    final toAccount = _stringValue(
      tx,
      const ['to_account', 'toAccount'],
    );

    final List<String> details = [
      'তারিখ: ${_dateTimeText(date)}',
    ];

    if (category.isNotEmpty) details.add('খাত: $category');
    if (account.isNotEmpty) details.add('অ্যাকাউন্ট: $account');
    if (person.isNotEmpty) details.add('ব্যক্তি: $person');

    if (type == 'transfer' &&
        (fromAccount.isNotEmpty || toAccount.isNotEmpty)) {
      details.add(
        'ট্রান্সফার: '
        '${fromAccount.isEmpty ? '-' : fromAccount} → '
        '${toAccount.isEmpty ? '-' : toAccount}',
      );
    }

    if (note.isNotEmpty) details.add('বিবরণ: $note');

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  '$index. $typeText',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                _money(amount),
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          ...details.map(
            (detail) => pw.Text(
              detail,
              style: pw.TextStyle(
                font: font,
                fontSize: 6.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
