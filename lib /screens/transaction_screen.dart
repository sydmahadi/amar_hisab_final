import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/money_db.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Map<String, dynamic>> _transactions = [];

  bool _loading = true;

  String _typeFilter = 'all';

  String _dateFilter = 'all';

  DateTime? _selectedDate;
  DateTime? _selectedMonth;

  String _searchText = '';

  final TextEditingController _searchController =
      TextEditingController();

  AppSettings get settings => AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOAD
  // ------------------------------------------------------------

  Future<void> _loadTransactions() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      List<Map<String, dynamic>> data;

      if (_searchText.trim().isNotEmpty) {
        data = await MoneyDb.instance.searchTransactions(
          _searchText.trim(),
        );
      } else {
        data = await MoneyDb.instance.getTransactions(
          type: _typeFilter == 'all' ? null : _typeFilter,
        );
      }

      // --------------------------------------------------------
      // DATE / MONTH FILTER
      // --------------------------------------------------------

      if (_dateFilter == 'date' && _selectedDate != null) {
        final selected = _selectedDate!;

        data = data.where((item) {
          final date = _parseDate(
            item['transaction_date']?.toString(),
          );

          if (date == null) return false;

          return date.year == selected.year &&
              date.month == selected.month &&
              date.day == selected.day;
        }).toList();
      }

      if (_dateFilter == 'month' && _selectedMonth != null) {
        final selected = _selectedMonth!;

        data = data.where((item) {
          final date = _parseDate(
            item['transaction_date']?.toString(),
          );

          if (date == null) return false;

          return date.year == selected.year &&
              date.month == selected.month;
        }).toList();
      }

      if (!mounted) return;

      setState(() {
        _transactions = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ------------------------------------------------------------
  // NAVIGATION
  // ------------------------------------------------------------

  Future<void> _openAddTransaction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
      ),
    );

    if (result == true) {
      await _loadTransactions();
    }
  }

  Future<void> _editTransaction(int id) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          transactionId: id,
        ),
      ),
    );

    if (result == true) {
      await _loadTransactions();
    }
  }

  // ------------------------------------------------------------
  // DELETE
  // ------------------------------------------------------------

  Future<void> _deleteTransaction(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(settings.t('confirm')),
          content: Text(settings.t('deleteConfirmation')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(settings.t('cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: Text(settings.t('delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await MoneyDb.instance.deleteTransaction(id);

      await _loadTransactions();

      if (!mounted) return;

      _showMessage(
        settings.isBangla
            ? 'লেনদেন মুছে ফেলা হয়েছে'
            : 'Transaction deleted',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ------------------------------------------------------------
  // MESSAGE
  // ------------------------------------------------------------

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? Colors.red.shade700 : AppTheme.green,
        ),
      );
  }

  // ------------------------------------------------------------
  // DATE
  // ------------------------------------------------------------

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  String _dateKey(Map<String, dynamic> item) {
    final date = _parseDate(
      item['transaction_date']?.toString(),
    );

    if (date == null) {
      return 'unknown';
    }

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _dateHeader(String key) {
    if (key == 'unknown') {
      return settings.isBangla ? 'তারিখ নেই' : 'No Date';
    }

    final parts = key.split('-');

    if (parts.length != 3) {
      return key;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) {
      return key;
    }

    if (month < 1 || month > 12) {
      return key;
    }

    final date = DateTime(year, month, day);
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final yesterday = today.subtract(
      const Duration(days: 1),
    );

    final onlyDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    if (onlyDate == today) {
      return settings.isBangla ? 'আজ' : 'Today';
    }

    if (onlyDate == yesterday) {
      return settings.isBangla ? 'গতকাল' : 'Yesterday';
    }

    const bnMonths = [
      'জানুয়ারি',
      'ফেব্রুয়ারি',
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

    const enMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final monthName = settings.isBangla
        ? bnMonths[month - 1]
        : enMonths[month - 1];

    if (settings.isBangla) {
      return '$day $monthName, $year';
    }

    return '$monthName $day, $year';
  }

  Map<String, List<Map<String, dynamic>>>
      _groupTransactionsByDate() {
    final groups =
        <String, List<Map<String, dynamic>>>{};

    for (final item in _transactions) {
      final key = _dateKey(item);

      groups.putIfAbsent(key, () => []);
      groups[key]!.add(item);
    }

    final entries = groups.entries.toList();

    entries.sort((a, b) {
      if (a.key == 'unknown') return 1;
      if (b.key == 'unknown') return -1;

      return b.key.compareTo(a.key);
    });

    return Map.fromEntries(entries);
  }

  // ------------------------------------------------------------
  // AMOUNT
  // ------------------------------------------------------------

  double _amount(Map<String, dynamic> item) {
    return (item['amount'] as num?)?.toDouble() ?? 0;
  }

  String _formatAmount(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;

    if (amount == amount.toInt()) {
      return amount.toInt().toString();
    }

    return amount.toStringAsFixed(2);
  }

  double _dailyIncome(
    List<Map<String, dynamic>> items,
  ) {
    double total = 0;

    for (final item in items) {
      if (item['type']?.toString() == 'income') {
        total += _amount(item);
      }
    }

    return total;
  }

  double _dailyExpense(
    List<Map<String, dynamic>> items,
  ) {
    double total = 0;

    for (final item in items) {
      if (item['type']?.toString() == 'expense') {
        total += _amount(item);
      }
    }

    return total;
  }

  // ------------------------------------------------------------
  // LOAN
  // ------------------------------------------------------------

  bool _isLoanType(String type) {
    return type == 'loan_given' ||
        type == 'loan_taken' ||
        type == 'loan_received' ||
        type == 'loan_paid';
  }

  String _loanTypeTitle(String type) {
    switch (type) {
      case 'loan_given':
        return settings.isBangla
            ? 'ধার দিয়েছি'
            : 'Loan Given';

      case 'loan_taken':
        return settings.isBangla
            ? 'ধার নিয়েছি'
            : 'Loan Taken';

      case 'loan_received':
        return settings.isBangla
            ? 'ধার ফেরত পেয়েছি'
            : 'Loan Received';

      case 'loan_paid':
        return settings.isBangla
            ? 'ধার শোধ করেছি'
            : 'Loan Paid';

      default:
        return settings.isBangla ? 'ধার' : 'Loan';
    }
  }

  // ------------------------------------------------------------
  // TYPE HELPERS
  // ------------------------------------------------------------

  Color _amountColor(String type) {
    switch (type) {
      case 'income':
        return Colors.green.shade600;

      case 'expense':
        return Colors.red.shade600;

      case 'loan_given':
        return Colors.orange.shade700;

      case 'loan_taken':
        return Colors.blue.shade600;

      case 'loan_received':
        return Colors.green.shade700;

      case 'loan_paid':
        return Colors.red.shade700;

      case 'transfer':
        return AppTheme.gold;

      default:
        return AppTheme.gold;
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
        return Icons.assignment_return_rounded;

      case 'loan_paid':
        return Icons.payments_outlined;

      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _amountPrefix(String type) {
    switch (type) {
      case 'income':
      case 'loan_received':
        return '+ ';

      case 'expense':
      case 'loan_given':
      case 'loan_paid':
        return '- ';

      default:
        return '';
    }
  }

  // ------------------------------------------------------------
  // LOAN PERSON
  // ------------------------------------------------------------

  String _personName(Map<String, dynamic> item) {
    final possibleKeys = [
      'person_name',
      'loan_person_name',
      'person',
      'borrower_name',
      'lender_name',
    ];

    for (final key in possibleKeys) {
      final value = item[key]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String _loanSubtitle(
    Map<String, dynamic> item,
  ) {
    final person = _personName(item);

    final account =
        item['account_name']?.toString().trim() ?? '';

    final note =
        item['note']?.toString().trim() ?? '';

    final parts = <String>[];

    if (person.isNotEmpty) {
      parts.add(person);
    }

    if (account.isNotEmpty) {
      parts.add(account);
    }

    if (note.isNotEmpty) {
      parts.add(note);
    }

    return parts.join(' • ');
  }

  // ------------------------------------------------------------
  // TITLE
  // ------------------------------------------------------------

  String _transactionTitle(
    Map<String, dynamic> item,
  ) {
    final type = item['type']?.toString() ?? '';

    if (_isLoanType(type)) {
      final person = _personName(item);

      final loanTitle = _loanTypeTitle(type);

      if (person.isNotEmpty) {
        return '$loanTitle • $person';
      }

      return loanTitle;
    }

    if (type == 'transfer') {
      final from =
          item['from_account_name']?.toString() ?? '';

      final to =
          item['to_account_name']?.toString() ?? '';

      if (from.isNotEmpty && to.isNotEmpty) {
        return '$from → $to';
      }

      return settings.t('transfer');
    }

    final category =
        item['category_name']?.toString() ?? '';

    if (category.isNotEmpty) {
      return category;
    }

    if (type == 'income') {
      return settings.t('income');
    }

    if (type == 'expense') {
      return settings.t('expense');
    }

    return settings.isBangla
        ? 'লেনদেন'
        : 'Transaction';
  }

  // ------------------------------------------------------------
  // SUBTITLE
  // ------------------------------------------------------------

  String _transactionSubtitle(
    Map<String, dynamic> item,
  ) {
    final type = item['type']?.toString() ?? '';

    if (_isLoanType(type)) {
      return _loanSubtitle(item);
    }

    if (type == 'transfer') {
      final note =
          item['note']?.toString().trim() ?? '';

      return note;
    }

    final account =
        item['account_name']?.toString().trim() ?? '';

    final note =
        item['note']?.toString().trim() ?? '';

    if (note.isNotEmpty && account.isNotEmpty) {
      return '$account • $note';
    }

    if (account.isNotEmpty) {
      return account;
    }

    return note;
  }

  // ------------------------------------------------------------
  // FILTER LABEL
  // ------------------------------------------------------------

  String _filterLabel() {
    if (_dateFilter == 'date' && _selectedDate != null) {
      final date = _selectedDate!;

      if (settings.isBangla) {
        return '${date.day}/${date.month}/${date.year}';
      }

      return '${date.month}/${date.day}/${date.year}';
    }

    if (_dateFilter == 'month' && _selectedMonth != null) {
      return _monthName(
        _selectedMonth!.month,
        _selectedMonth!.year,
      );
    }

    if (_typeFilter != 'all') {
      switch (_typeFilter) {
        case 'income':
          return settings.t('income');

        case 'expense':
          return settings.t('expense');

        case 'transfer':
          return settings.t('transfer');

        case 'loan_given':
          return settings.isBangla
              ? 'ধার দিয়েছি'
              : 'Given';

        case 'loan_taken':
          return settings.isBangla
              ? 'ধার নিয়েছি'
              : 'Taken';

        case 'loan_received':
          return settings.isBangla
              ? 'ফেরত পেয়েছি'
              : 'Received';

        case 'loan_paid':
          return settings.isBangla
              ? 'ধার শোধ'
              : 'Paid';
      }
    }

    return settings.isBangla ? 'সব' : 'All';
  }

  // ------------------------------------------------------------
  // MONTH NAME
  // ------------------------------------------------------------

  String _monthName(int month, int year) {
    const bnMonths = [
      'জানুয়ারি',
      'ফেব্রুয়ারি',
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

    const enMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    if (month < 1 || month > 12) {
      return year.toString();
    }

    final name = settings.isBangla
        ? bnMonths[month - 1]
        : enMonths[month - 1];

    return '$name $year';
  }

  // ------------------------------------------------------------
  // CLEAR FILTER
  // ------------------------------------------------------------

  Future<void> _clearFilter() async {
    setState(() {
      _typeFilter = 'all';
      _dateFilter = 'all';
      _selectedDate = null;
      _selectedMonth = null;
    });

    await _loadTransactions();
  }

  // ------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(
        now.year + 2,
        12,
        31,
      ),
      helpText: settings.isBangla
          ? 'তারিখ নির্বাচন করুন'
          : 'Select date',
      cancelText: settings.t('cancel'),
      confirmText: settings.isBangla
          ? 'নির্বাচন'
          : 'Select',
    );

    if (picked == null) return;

    setState(() {
      _dateFilter = 'date';
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
      );

      _selectedMonth = null;
    });

    await _loadTransactions();
  }

  // ------------------------------------------------------------
  // MONTH PICKER
  // ------------------------------------------------------------

  Future<void> _pickMonth() async {
    final now = DateTime.now();

    int selectedMonth =
        _selectedMonth?.month ?? now.month;

    int selectedYear =
        _selectedMonth?.year ?? now.year;

    final years = List<int>.generate(
      31,
      (index) => now.year - 15 + index,
    );

    final result =
        await showModalBottomSheet<Map<String, int>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settings.isBangla
                          ? 'মাস নির্বাচন করুন'
                          : 'Select month',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedMonth,
                            decoration: InputDecoration(
                              labelText: settings.isBangla
                                  ? 'মাস'
                                  : 'Month',
                              prefixIcon: const Icon(
                                Icons.calendar_month_rounded,
                              ),
                            ),
                            items: List.generate(
                              12,
                              (index) {
                                final month = index + 1;

                                return DropdownMenuItem<int>(
                                  value: month,
                                  child: Text(
                                    _monthName(
                                      month,
                                      selectedYear,
                                    ).split(' ').first,
                                  ),
                                );
                              },
                            ),
                            onChanged: (value) {
                              if (value == null) return;

                              setSheetState(() {
                                selectedMonth = value;
                              });
                            },
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedYear,
                            decoration: InputDecoration(
                              labelText: settings.isBangla
                                  ? 'বছর'
                                  : 'Year',
                              prefixIcon: const Icon(
                                Icons.date_range_rounded,
                              ),
                            ),
                            items: years.map((year) {
                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text(year.toString()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              setSheetState(() {
                                selectedYear = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(
                            sheetContext,
                            {
                              'month': selectedMonth,
                              'year': selectedYear,
                            },
                          );
                        },
                        icon: const Icon(
                          Icons.check_rounded,
                        ),
                        label: Text(
                          settings.isBangla
                              ? 'নির্বাচন করুন'
                              : 'Select',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() {
      _dateFilter = 'month';

      _selectedMonth = DateTime(
        result['year']!,
        result['month']!,
        1,
      );

      _selectedDate = null;
    });

    await _loadTransactions();
  }

  // ------------------------------------------------------------
  // FILTER MENU
  // ------------------------------------------------------------

  Future<void> _showFilterMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              24,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    4,
                    4,
                    4,
                    10,
                  ),
                  child: Text(
                    settings.isBangla
                        ? 'লেনদেন ফিল্টার'
                        : 'Transaction filter',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // ALL
                ListTile(
                  leading: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.gold,
                  ),
                  title: Text(
                    settings.isBangla
                        ? 'সব লেনদেন'
                        : 'All transactions',
                  ),
                  trailing: _dateFilter == 'all' &&
                          _typeFilter == 'all'
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.green,
                        )
                      : null,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _clearFilter();
                  },
                ),

                const Divider(),

                // DATE
                ListTile(
                  leading: const Icon(
                    Icons.today_rounded,
                    color: AppTheme.green,
                  ),
                  title: Text(
                    settings.isBangla
                        ? 'নির্দিষ্ট তারিখ'
                        : 'Specific date',
                  ),
                  subtitle:
                      _dateFilter == 'date' &&
                              _selectedDate != null
                          ? Text(
                              _filterLabel(),
                            )
                          : null,
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickDate();
                  },
                ),

                // MONTH
                ListTile(
                  leading: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppTheme.green,
                  ),
                  title: Text(
                    settings.isBangla
                        ? 'নির্দিষ্ট মাস'
                        : 'Specific month',
                  ),
                  subtitle:
                      _dateFilter == 'month' &&
                              _selectedMonth != null
                          ? Text(
                              _filterLabel(),
                            )
                          : null,
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickMonth();
                  },
                ),

                const Divider(),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    4,
                    8,
                    4,
                    4,
                  ),
                  child: Text(
                    settings.isBangla
                        ? 'লেনদেনের ধরন'
                        : 'Transaction type',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color,
                    ),
                  ),
                ),

                _typeFilterTile(
                  sheetContext,
                  value: 'income',
                  icon: Icons.arrow_downward_rounded,
                  color: Colors.green.shade600,
                  title: settings.t('income'),
                ),

                _typeFilterTile(
                  sheetContext,
                  value: 'expense',
                  icon: Icons.arrow_upward_rounded,
                  color: Colors.red.shade600,
                  title: settings.t('expense'),
                ),

                _typeFilterTile(
                  sheetContext,
                  value: 'transfer',
                  icon: Icons.swap_horiz_rounded,
                  color: AppTheme.gold,
                  title: settings.t('transfer'),
                ),

                _typeFilterTile(
                  sheetContext,
                  value: 'loan_given',
                  icon: Icons.call_made_rounded,
                  color: Colors.orange.shade700,
                  title: settings.isBangla
                      ? 'ধার দিয়েছি'
                      : 'Loan given',
                ),

                _typeFilterTile(
                  sheetContext,
                  value: 'loan_taken',
                  icon: Icons.call_received_rounded,
                  color: Colors.blue.shade600,
                  title: settings.isBangla
                      ? 'ধার নিয়েছি'
                      : 'Loan taken',
                ),

                _typeFilterTile(
                  sheetContext,
                  value: 'loan_received',
                  icon: Icons.assignment_return_rounded,
                  color: Colors.green.shade700,
                  title: settings.isBangla
                      ? 'ধার ফেরত পেয়েছি'
                      : 'Loan received',
                ),

                _typeFilterTile(
                  sheetContext,
                  value: 'loan_paid',
                  icon: Icons.payments_outlined,
                  color: Colors.red.shade700,
                  title: settings.isBangla
                      ? 'ধার শোধ করেছি'
                      : 'Loan paid',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _typeFilterTile(
    BuildContext sheetContext, {
    required String value,
    required IconData icon,
    required Color color,
    required String title,
  }) {
    final selected = _typeFilter == value;

    return ListTile(
      leading: Icon(
        icon,
        color: color,
      ),
      title: Text(title),
      trailing: selected
          ? const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.green,
            )
          : null,
      onTap: () async {
        Navigator.pop(sheetContext);

        setState(() {
          _typeFilter = value;
          _dateFilter = 'all';
          _selectedDate = null;
          _selectedMonth = null;
        });

        await _loadTransactions();
      },
    );
  }

  // ------------------------------------------------------------
  // FILTER BAR
  // ------------------------------------------------------------

  Widget _buildCompactFilterBar() {
    final hasFilter =
        _dateFilter != 'all' ||
        _typeFilter != 'all';

    return Row(
      children: [
        Expanded(
          child: Text(
            hasFilter
                ? _filterLabel()
                : (settings.isBangla
                    ? 'সব লেনদেন'
                    : 'All transactions'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: hasFilter
                  ? AppTheme.green
                  : Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color,
            ),
          ),
        ),

        const SizedBox(width: 8),

        InkWell(
          onTap: _showFilterMenu,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasFilter
                    ? AppTheme.green
                    : Theme.of(context)
                        .dividerColor,
              ),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: 18,
                  color: hasFilter
                      ? AppTheme.green
                      : Theme.of(context)
                          .iconTheme
                          .color,
                ),
                const SizedBox(width: 5),
                Text(
                  settings.isBangla
                      ? 'ফিল্টার'
                      : 'Filter',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasFilter
                        ? AppTheme.green
                        : Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // DATE HEADER
  // ------------------------------------------------------------

  Widget _buildDateHeader(
    String dateKey,
    List<Map<String, dynamic>> items,
  ) {
    final income = _dailyIncome(items);
    final expense = _dailyExpense(items);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        2,
        18,
        2,
        10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateHeader(dateKey),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${items.length} ${settings.isBangla ? 'টি লেনদেন' : 'transactions'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (income > 0 || expense > 0)
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                if (income > 0)
                  Text(
                    '+ ${_formatAmount(income)}',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (expense > 0)
                  Text(
                    '- ${_formatAmount(expense)}',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TRANSACTION CARD
  // ------------------------------------------------------------

  Widget _buildTransactionCard(
    Map<String, dynamic> item,
  ) {
    final type =
        item['type']?.toString() ?? 'expense';

    final amount = _formatAmount(
      item['amount'],
    );

    final color = _amountColor(type);

    final icon = _transactionIcon(type);

    final title = _transactionTitle(item);

    final subtitle =
        _transactionSubtitle(item);

    final rawId = item['id'];

    final id = rawId is int
        ? rawId
        : int.tryParse(rawId.toString()) ?? 0;

    final isLoan = _isLoanType(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: InkWell(
        onTap: id > 0
            ? () => _editTransaction(id)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      color.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color,
                        ),
                      ),
                    ],

                    if (isLoan) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration:
                            BoxDecoration(
                          color: color.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            6,
                          ),
                        ),
                        child: Text(
                          _loanTypeTitle(type),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_amountPrefix(type)}$amount',
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 21,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editTransaction(id);
                      } else if (value ==
                          'delete') {
                        _deleteTransaction(id);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              settings.t('edit'),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color:
                                  Colors.red.shade600,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              settings.t('delete'),
                              style: TextStyle(
                                color:
                                    Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY
  // ------------------------------------------------------------

  Widget _buildEmptyState() {
    final isFiltered =
        _dateFilter != 'all' ||
        _typeFilter != 'all' ||
        _searchText.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 45,
                color: AppTheme.gold,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              isFiltered
                  ? (settings.isBangla
                      ? 'কোনো লেনদেন পাওয়া যায়নি'
                      : 'No transactions found')
                  : settings.t('noTransactions'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isFiltered
                  ? (settings.isBangla
                      ? 'অন্য ফিল্টার বা সার্চ ব্যবহার করুন'
                      : 'Try another filter or search')
                  : (settings.isBangla
                      ? 'নতুন আয়, ব্যয়, ট্রান্সফার অথবা ধার যোগ করুন'
                      : 'Add a new income, expense, transfer or loan'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color,
              ),
            ),

            const SizedBox(height: 20),

            if (!isFiltered)
              ElevatedButton.icon(
                onPressed:
                    _openAddTransaction,
                icon: const Icon(
                  Icons.add_rounded,
                ),
                label: Text(
                  settings.t(
                    'addTransaction',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) async {
        _searchText = value;

        await _loadTransactions();

        if (mounted) {
          setState(() {});
        }
      },
      decoration: InputDecoration(
        hintText: settings.t('search'),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppTheme.gold,
        ),
        suffixIcon:
            _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () async {
                      _searchController.clear();

                      setState(() {
                        _searchText = '';
                      });

                      await _loadTransactions();
                    },
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  )
                : null,
      ),
    );
  }

  // ------------------------------------------------------------
  // GROUPED LIST
  // ------------------------------------------------------------

  Widget _buildGroupedTransactions() {
    final groups =
        _groupTransactionsByDate();

    final children = <Widget>[];

    for (final entry in groups.entries) {
      children.add(
        _buildDateHeader(
          entry.key,
          entry.value,
        ),
      );

      for (final transaction
          in entry.value) {
        children.add(
          _buildTransactionCard(
            transaction,
          ),
        );
      }
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        100,
      ),
      children: children,
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          settings.t('transactions'),
        ),
        actions: [
          IconButton(
            tooltip:
                settings.t('addTransaction'),
            onPressed:
                _openAddTransaction,
            icon: const Icon(
              Icons.add_rounded,
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              5,
            ),
            child: _buildSearchField(),
          ),

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              2,
              16,
              6,
            ),
            child: _buildCompactFilterBar(),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTransactions,
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : _transactions.isEmpty
                      ? _buildEmptyState()
                      : _buildGroupedTransactions(),
            ),
          ),
        ],
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _openAddTransaction,
        backgroundColor:
            AppTheme.green,
        foregroundColor:
            Colors.white,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: Text(
          settings.t(
            'addTransaction',
          ),
        ),
      ),
    );
  }
}
