
import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/money_db.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  final MoneyDb _db = MoneyDb.instance;
  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _loans = [];
  bool _loading = true;

  String _typeFilter = 'all';
  String _statusFilter = 'all';

  DateTime? _selectedDate;
  DateTime? _selectedMonth;

  bool get _bn => AppSettings.instance.isBangla;

  String _t(String bn, String en) => _bn ? bn : en;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadLoans();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
    _loadLoans();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _money(double value) => value.toStringAsFixed(2);

  String _formatDate(dynamic value) {
    final date = _parseDate(value);
    if (date == null) {
      return _t('নির্ধারিত নয়', 'Not set');
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isOverdue(Map<String, dynamic> loan) {
    final remaining = _number(loan['remaining']);
    final dueDate = _parseDate(loan['due_date']);

    return remaining > 0 &&
        dueDate != null &&
        _dateOnly(dueDate).isBefore(_dateOnly(DateTime.now()));
  }

  double _paidAmount(Map<String, dynamic> loan) {
    final principal = _number(loan['principal']);
    final remaining = _number(loan['remaining']);
    return (principal - remaining).clamp(0, principal).toDouble();
  }

  String _monthName(int month) {
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
    return (_bn ? bnMonths : enMonths)[month - 1];
  }

  Future<void> _loadLoans() async {
    if (mounted) setState(() => _loading = true);

    try {
      final loans = await _db.getLoans(
        type: _typeFilter == 'all' ? null : _typeFilter,
        activeOnly: _statusFilter == 'active',
      );

      final search = _searchController.text.trim().toLowerCase();

      var filtered = loans.where((loan) {
        if (search.isEmpty) return true;

        final person =
            (loan['person_name'] ?? '').toString().toLowerCase();
        final note = (loan['note'] ?? '').toString().toLowerCase();

        return person.contains(search) || note.contains(search);
      }).toList();

      if (_statusFilter == 'completed') {
        filtered = filtered.where(
          (loan) => _number(loan['remaining']) <= 0,
        ).toList();
      } else if (_statusFilter == 'overdue') {
        filtered = filtered.where(_isOverdue).toList();
      }

      if (_selectedDate != null) {
        filtered = filtered.where((loan) {
          final date = _parseDate(loan['created_at']);
          return date != null &&
              date.year == _selectedDate!.year &&
              date.month == _selectedDate!.month &&
              date.day == _selectedDate!.day;
        }).toList();
      }

      if (_selectedMonth != null) {
        filtered = filtered.where((loan) {
          final date = _parseDate(loan['created_at']);
          return date != null &&
              date.year == _selectedMonth!.year &&
              date.month == _selectedMonth!.month;
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        _loans = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loans = [];
        _loading = false;
      });
      _message(_errorText(e), error: true);
    }
  }

  String _errorText(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red.shade700 : AppTheme.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _filterLabel() {
    if (_selectedDate != null) {
      return _t(
        'তারিখ: ${_formatDate(_selectedDate)}',
        'Date: ${_formatDate(_selectedDate)}',
      );
    }
    if (_selectedMonth != null) {
      return '${_monthName(_selectedMonth!.month)} '
          '${_selectedMonth!.year}';
    }
    if (_statusFilter == 'active') return _t('চলমান', 'Active');
    if (_statusFilter == 'completed') {
      return _t('সম্পন্ন', 'Completed');
    }
    if (_statusFilter == 'overdue') {
      return _t('মেয়াদোত্তীর্ণ', 'Overdue');
    }
    if (_typeFilter == 'receivable') return _t('পাওনা', 'Receivable');
    if (_typeFilter == 'payable') return _t('দেনা', 'Payable');
    return _t('সব লোন', 'All loans');
  }

  bool get _hasFilter =>
      _typeFilter != 'all' ||
      _statusFilter != 'all' ||
      _selectedDate != null ||
      _selectedMonth != null;

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: _t('তারিখ নির্বাচন করুন', 'Select date'),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _selectedDate = selected;
      _selectedMonth = null;
    });
    _loadLoans();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    int year = _selectedMonth?.year ?? now.year;
    int month = _selectedMonth?.month ?? now.month;

    final selected = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t('মাস নির্বাচন করুন', 'Select month')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: year,
                decoration: InputDecoration(
                  labelText: _t('বছর', 'Year'),
                ),
                items: List.generate(21, (i) {
                  final value = now.year - 10 + i;
                  return DropdownMenuItem(
                    value: value,
                    child: Text('$value'),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => year = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: month,
                decoration: InputDecoration(
                  labelText: _t('মাস', 'Month'),
                ),
                items: List.generate(12, (i) {
                  final value = i + 1;
                  return DropdownMenuItem(
                    value: value,
                    child: Text(_monthName(value)),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => month = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('বাতিল', 'Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, DateTime(year, month)),
              child: Text(_t('নির্বাচন', 'Select')),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() {
      _selectedMonth = selected;
      _selectedDate = null;
    });
    _loadLoans();
  }

  void _clearFilters() {
    setState(() {
      _typeFilter = 'all';
      _statusFilter = 'all';
      _selectedDate = null;
      _selectedMonth = null;
    });
    _loadLoans();
  }

  Widget _filterTile({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppTheme.gold : null,
      ),
      title: Text(title),
      onTap: onTap,
    );
  }

  Future<void> _showFilterMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('লোন ফিল্টার', 'Loan filters'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(_t('ধরন', 'Type')),
              _filterTile(
                title: _t('সব লোন', 'All loans'),
                selected: _typeFilter == 'all',
                onTap: () {
                  setState(() => _typeFilter = 'all');
                  Navigator.pop(sheetContext);
                  _loadLoans();
                },
              ),
              _filterTile(
                title: _t('আমার পাওনা', 'My receivables'),
                selected: _typeFilter == 'receivable',
                onTap: () {
                  setState(() => _typeFilter = 'receivable');
                  Navigator.pop(sheetContext);
                  _loadLoans();
                },
              ),
              _filterTile(
                title: _t('আমার দেনা', 'My payables'),
                selected: _typeFilter == 'payable',
                onTap: () {
                  setState(() => _typeFilter = 'payable');
                  Navigator.pop(sheetContext);
                  _loadLoans();
                },
              ),
              const Divider(),
              Text(_t('অবস্থা', 'Status')),
              for (final option in [
                ['all', _t('সব', 'All')],
                ['active', _t('চলমান', 'Active')],
                ['completed', _t('সম্পন্ন', 'Completed')],
                ['overdue', _t('মেয়াদোত্তীর্ণ', 'Overdue')],
              ])
                _filterTile(
                  title: option[1],
                  selected: _statusFilter == option[0],
                  onTap: () {
                    setState(() => _statusFilter = option[0]);
                    Navigator.pop(sheetContext);
                    _loadLoans();
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(_t('নির্দিষ্ট তারিখ', 'Specific date')),
                subtitle: _selectedDate == null
                    ? null
                    : Text(_formatDate(_selectedDate)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickDate();
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(_t('নির্দিষ্ট মাস', 'Specific month')),
                subtitle: _selectedMonth == null
                    ? null
                    : Text(
                        '${_monthName(_selectedMonth!.month)} '
                        '${_selectedMonth!.year}',
                      ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickMonth();
                },
              ),
              if (_hasFilter)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _clearFilters();
                    },
                    icon: const Icon(Icons.clear),
                    label: Text(_t('সব ফিল্টার মুছুন', 'Clear filters')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editDueDate(Map<String, dynamic> loan) async {
    final loanId = (loan['id'] as num?)?.toInt();
    if (loanId == null) return;

    final existingDate = _parseDate(loan['due_date']);
    DateTime? selectedDate = existingDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t('পরিশোধের শেষ তারিখ', 'Loan due date')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t(
                'শেষ তারিখ নির্বাচন করুন। তারিখ না রাখতে চাইলে মুছে দিন।',
                'Choose a due date, or clear it to remove the deadline.',
              )),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final initial = selectedDate ?? now;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    helpText: _t('শেষ তারিখ নির্বাচন', 'Select due date'),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      selectedDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                      );
                    });
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  selectedDate == null
                      ? _t('তারিখ নির্বাচন করুন', 'Select date')
                      : _formatDate(selectedDate),
                ),
              ),
              if (selectedDate != null)
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() => selectedDate = null);
                  },
                  icon: const Icon(Icons.clear),
                  label: Text(_t('তারিখ মুছুন', 'Clear date')),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('বাতিল', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t('সংরক্ষণ', 'Save')),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    try {
      await _db.updateLoanDueDate(loanId, selectedDate);
      await _loadLoans();
      if (!mounted) return;
      _message(_t('শেষ তারিখ আপডেট হয়েছে', 'Due date updated'));
    } catch (e) {
      _message(_errorText(e), error: true);
    }
  }

  Future<void> _openAddTransaction() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
      ),
    );
    if (mounted) await _loadLoans();
  }

  Future<void> _editLoan(Map<String, dynamic> loan) async {
    final loanId = (loan['id'] as num?)?.toInt();
    if (loanId == null) return;

    final transactions = await _db.getLoanTransactions(loanId);
    if (!mounted) return;

    Map<String, dynamic>? original;
    for (final transaction in transactions) {
      final type = transaction['type']?.toString();
      if (type == 'loan_given' || type == 'loan_taken') {
        original = transaction;
        break;
      }
    }

    final transactionId = (original?['id'] as num?)?.toInt();
    if (transactionId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          transactionId: transactionId,
        ),
      ),
    );
    if (mounted) await _loadLoans();
  }

  Future<void> _deleteLoan(Map<String, dynamic> loan) async {
    final loanId = (loan['id'] as num?)?.toInt();
    if (loanId == null) return;

    final transactions = await _db.getLoanTransactions(loanId);
    if (!mounted) return;

    final hasRepayment = transactions.any((transaction) {
      final type = transaction['type']?.toString();
      return type == 'loan_received' || type == 'loan_paid';
    });

    if (hasRepayment) {
      _message(
        _t(
          'এই লোনে পরিশোধের লেনদেন আছে। আগে সেগুলো মুছুন।',
          'This loan has repayments. Delete those transactions first.',
        ),
        error: true,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('লোন মুছবেন?', 'Delete loan?')),
        content: Text(
          _t(
            '${loan['person_name'] ?? 'এই ব্যক্তির'} লোন মুছে যাবে।',
            'The loan for ${loan['person_name'] ?? 'this person'} will be deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('বাতিল', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('মুছে ফেলুন', 'Delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      Map<String, dynamic>? original;
      for (final transaction in transactions) {
        final type = transaction['type']?.toString();
        if (type == 'loan_given' || type == 'loan_taken') {
          original = transaction;
          break;
        }
      }

      final transactionId = (original?['id'] as num?)?.toInt();
      if (transactionId == null) return;

      await _db.deleteTransaction(transactionId);
      if (!mounted) return;

      _message(_t('লোন মুছে ফেলা হয়েছে', 'Loan deleted'));
      await _loadLoans();
    } catch (e) {
      _message(_errorText(e), error: true);
    }
  }

  Future<void> _deleteLoanTransaction(int transactionId) async {
    try {
      await _db.deleteTransaction(transactionId);
      if (!mounted) return;
      _message(_t('লেনদেন মুছে ফেলা হয়েছে', 'Transaction deleted'));
      await _loadLoans();
    } catch (e) {
      _message(_errorText(e), error: true);
    }
  }

  Future<void> _addRepayment(Map<String, dynamic> loan) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RepaymentSheet(loan: loan, db: _db),
    );
    if (result == true && mounted) await _loadLoans();
  }

  Future<void> _showLoanDetails(Map<String, dynamic> loan) async {
    final loanId = (loan['id'] as num?)?.toInt();
    if (loanId == null) return;

    final transactions = await _db.getLoanTransactions(loanId);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: _LoanDetailsSheet(
          loan: loan,
          transactions: transactions,
          onEdit: (id) async {
            Navigator.pop(context);
            await _editLoanTransaction(loanId, id);
          },
          onDelete: (id) async {
            Navigator.pop(context);
            await _deleteLoanTransaction(id);
          },
          onRepayment: () async {
            Navigator.pop(context);
            await _addRepayment(loan);
          },
          onEditDueDate: () async {
            Navigator.pop(context);
            await _editDueDate(loan);
          },
        ),
      ),
    );
  }

  Future<void> _editLoanTransaction(int loanId, int transactionId) async {
    final transactions = await _db.getLoanTransactions(loanId);
    if (!mounted || transactions.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          transactionId: transactionId,
        ),
      ),
    );
    if (mounted) await _loadLoans();
  }

  Widget _summaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '৳ ${_money(amount)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountColumn(
    String title,
    double amount, {
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '৳ ${_money(amount)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _loanCard(Map<String, dynamic> loan) {
    final type = (loan['type'] ?? '').toString();
    final person = (loan['person_name'] ??
            _t('নাম নেই', 'No name'))
        .toString();
    final principal = _number(loan['principal']);
    final remaining = _number(loan['remaining']);
    final paid = _paidAmount(loan);
    final receivable = type == 'receivable';
    final color = receivable ? Colors.green : Colors.red;
    final overdue = _isOverdue(loan);
    final dueDate = _parseDate(loan['due_date']);

    final status = remaining <= 0
        ? _t('সম্পন্ন', 'Completed')
        : overdue
            ? _t('মেয়াদোত্তীর্ণ', 'Overdue')
            : _t('চলমান', 'Active');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(
          color: overdue
              ? Colors.red.withValues(alpha: 0.45)
              : color.withValues(alpha: 0.18),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => _showLoanDetails(loan),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      receivable
                          ? Icons.call_received_rounded
                          : Icons.call_made_rounded,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          receivable
                              ? _t('আমার পাওনা', 'My receivable')
                              : _t('আমার দেনা', 'My payable'),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _editLoan(loan);
                      if (value == 'due') _editDueDate(loan);
                      if (value == 'delete') _deleteLoan(loan);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(_t('এডিট লোন', 'Edit loan')),
                      ),
                      PopupMenuItem(
                        value: 'due',
                        child: Text(
                          _t('শেষ তারিখ পরিবর্তন', 'Change due date'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(_t('লোন মুছুন', 'Delete loan')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _amountColumn(
                      _t('মোট টাকা', 'Principal'),
                      principal,
                    ),
                  ),
                  Expanded(
                    child: _amountColumn(
                      _t('পরিশোধিত', 'Paid'),
                      paid,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _amountColumn(
                      _t('বাকি', 'Remaining'),
                      remaining,
                      color: remaining > 0 ? color : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: principal <= 0
                      ? 0
                      : (paid / principal).clamp(0.0, 1.0),
                  backgroundColor: color.withValues(alpha: 0.10),
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 16,
                    color: overdue ? Colors.red : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      dueDate == null
                          ? _t('শেষ তারিখ নির্ধারিত নয়', 'Due date not set')
                          : '${_t('শেষ তারিখ', 'Due')}: ${_formatDate(dueDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: overdue ? Colors.red : Colors.grey.shade600,
                        fontWeight:
                            overdue ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (overdue
                              ? Colors.red
                              : remaining <= 0
                                  ? Colors.green
                                  : Colors.orange)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: overdue
                            ? Colors.red
                            : remaining <= 0
                                ? Colors.green
                                : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _formatDate(loan['created_at']),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _t('বিস্তারিত দেখুন', 'View details'),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: color, size: 17),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.handshake_outlined,
              size: 65,
              color: AppTheme.gold,
            ),
            const SizedBox(height: 15),
            Text(
              _t('কোনো দেনা-পাওনা পাওয়া যায়নি', 'No loans found'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasFilter
                  ? _t(
                      'ফিল্টার পরিবর্তন করে দেখুন।',
                      'Try changing the filters.',
                    )
                  : _t(
                      'নতুন লেনদেন থেকে ধার দেওয়া বা নেওয়ার হিসাব যোগ করুন।',
                      'Add a loan from New Transaction.',
                    ),
              textAlign: TextAlign.center,
            ),
            if (_hasFilter)
              TextButton(
                onPressed: _clearFilters,
                child: Text(_t('ফিল্টার মুছুন', 'Clear filters')),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalReceivable = _loans
        .where((loan) => loan['type']?.toString() == 'receivable')
        .fold<double>(
          0,
          (sum, loan) => sum + _number(loan['remaining']),
        );

    final totalPayable = _loans
        .where((loan) => loan['type']?.toString() == 'payable')
        .fold<double>(
          0,
          (sum, loan) => sum + _number(loan['remaining']),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('দেনা-পাওনা', 'Debts & Dues'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _t('রিফ্রেশ', 'Refresh'),
            onPressed: _loadLoans,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTransaction,
        icon: const Icon(Icons.add),
        label: Text(_t('নতুন লেনদেন', 'New transaction')),
      ),
      body: RefreshIndicator(
        onRefresh: _loadLoans,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _summaryCard(
                      title: _t('আমার পাওনা', 'Receivable'),
                      amount: totalReceivable,
                      icon: Icons.arrow_downward_rounded,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 10),
                    _summaryCard(
                      title: _t('আমার দেনা', 'Payable'),
                      amount: totalPayable,
                      icon: Icons.arrow_upward_rounded,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _t('নাম বা নোট দিয়ে খুঁজুন', 'Search name or note'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.clear),
                          ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _filterLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _showFilterMenu,
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: Text(_t('ফিল্টার', 'Filter')),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loans.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _loanCard(_loans[index]),
                    childCount: _loans.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoanDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> loan;
  final List<Map<String, dynamic>> transactions;
  final Future<void> Function(int id) onEdit;
  final Future<void> Function(int id) onDelete;
  final Future<void> Function() onRepayment;
  final Future<void> Function() onEditDueDate;

  const _LoanDetailsSheet({
    required this.loan,
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
    required this.onRepayment,
    required this.onEditDueDate,
  });

  bool get _bn => AppSettings.instance.isBangla;

  String _t(String bn, String en) => _bn ? bn : en;

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(double value) => value.toStringAsFixed(2);

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _date(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return _t('নির্ধারিত নয়', 'Not set');
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  bool get _receivable => loan['type']?.toString() == 'receivable';

  bool get _overdue {
    final dueDate = _parseDate(loan['due_date']);
    final remaining = _number(loan['remaining']);
    if (dueDate == null || remaining <= 0) return false;
    final today = DateTime.now();
    return DateTime(dueDate.year, dueDate.month, dueDate.day)
        .isBefore(DateTime(today.year, today.month, today.day));
  }

  String _transactionTitle(String type) {
    switch (type) {
      case 'loan_given':
        return _t('ধার দিয়েছি', 'Loan given');
      case 'loan_taken':
        return _t('ধার নিয়েছি', 'Loan taken');
      case 'loan_received':
        return _t('ধার ফেরত পেয়েছি', 'Repayment received');
      case 'loan_paid':
        return _t('ধার শোধ করেছি', 'Loan repayment');
      default:
        return _t('লোন লেনদেন', 'Loan transaction');
    }
  }

  Color _transactionColor(String type) {
    switch (type) {
      case 'loan_given':
        return Colors.orange;
      case 'loan_taken':
        return Colors.red;
      case 'loan_received':
        return Colors.green;
      case 'loan_paid':
        return Colors.blue;
      default:
        return AppTheme.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final person =
        (loan['person_name'] ?? _t('নাম নেই', 'No name')).toString();
    final principal = _number(loan['principal']);
    final remaining = _number(loan['remaining']);
    final paid = (principal - remaining).clamp(0, principal).toDouble();
    final color = _receivable ? Colors.green : Colors.red;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: color.withValues(alpha: 0.10),
                      child: Icon(
                        _receivable
                            ? Icons.call_received_rounded
                            : Icons.call_made_rounded,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _receivable
                                ? _t('আমার পাওনা', 'My receivable')
                                : _t('আমার দেনা', 'My payable'),
                            style: TextStyle(color: color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _amount(
                        _t('মোট টাকা', 'Principal'),
                        principal,
                      ),
                    ),
                    Expanded(
                      child: _amount(
                        _t('পরিশোধিত', 'Paid'),
                        paid,
                        color: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _amount(
                        _t('বাকি', 'Remaining'),
                        remaining,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_overdue ? Colors.red : AppTheme.gold)
                        .withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_available_outlined,
                        color: _overdue ? Colors.red : AppTheme.gold,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_t('পরিশোধের শেষ তারিখ', 'Due date')),
                            Text(
                              _date(loan['due_date']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _overdue ? Colors.red : null,
                              ),
                            ),
                            if (_overdue)
                              Text(
                                _t(
                                  'শেষ তারিখ পার হয়েছে',
                                  'Payment is overdue',
                                ),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _t('তারিখ পরিবর্তন', 'Edit due date'),
                        onPressed: onEditDueDate,
                        icon: const Icon(Icons.edit_calendar_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (remaining > 0)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onRepayment,
                      icon: Icon(
                        _receivable
                            ? Icons.call_received
                            : Icons.payments_outlined,
                      ),
                      label: Text(
                        _receivable
                            ? _t('ফেরত পেয়েছি', 'Receive repayment')
                            : _t('ধার শোধ করেছি', 'Pay repayment'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Text(_t('কোনো লেনদেন নেই', 'No transactions')),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final type =
                          (transaction['type'] ?? '').toString();
                      final amount = _number(transaction['amount']);
                      final id = (transaction['id'] as num?)?.toInt();
                      final color = _transactionColor(type);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: color.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              color: color,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _transactionTitle(type),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _date(
                                      transaction['transaction_date'] ??
                                          transaction['date'] ??
                                          transaction['created_at'],
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if ((transaction['note'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      transaction['note'].toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '৳ ${_money(amount)}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (id != null)
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    iconSize: 20,
                                    onSelected: (value) {
                                      if (value == 'edit') onEdit(id);
                                      if (value == 'delete') {
                                        _confirmDelete(context, id);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(_t('এডিট', 'Edit')),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          _t('মুছে ফেলুন', 'Delete'),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _amount(String title, double value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          '৳ ${_money(value)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, int id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('লেনদেন মুছবেন?', 'Delete transaction?')),
        content: Text(
          _t(
            'এই লোন লেনদেনটি স্থায়ীভাবে মুছে যাবে।',
            'This loan transaction will be permanently deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('বাতিল', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('মুছে ফেলুন', 'Delete')),
          ),
        ],
      ),
    );
    if (result == true) await onDelete(id);
  }
}

class _RepaymentSheet extends StatefulWidget {
  final Map<String, dynamic> loan;
  final MoneyDb db;

  const _RepaymentSheet({
    required this.loan,
    required this.db,
  });

  @override
  State<_RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends State<_RepaymentSheet> {
  final TextEditingController _amountController =
      TextEditingController();
  final TextEditingController _noteController =
      TextEditingController();

  List<Map<String, dynamic>> _accounts = [];
  int? _selectedAccountId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _bn => AppSettings.instance.isBangla;
  String _t(String bn, String en) => _bn ? bn : en;

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double get _remaining => _number(widget.loan['remaining']);

  bool get _receivable =>
      widget.loan['type']?.toString() == 'receivable';

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.db.getAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        if (accounts.isNotEmpty) {
          _selectedAccountId =
              (accounts.first['id'] as num?)?.toInt();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: _t('তারিখ নির্বাচন করুন', 'Select date'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
    });
  }

  String _dateText() =>
      '${_date.day.toString().padLeft(2, '0')}/'
      '${_date.month.toString().padLeft(2, '0')}/'
      '${_date.year}';

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final amount =
        double.tryParse(_amountController.text.trim()) ?? 0;

    if (!amount.isFinite || amount <= 0) {
      _showMessage(_t('সঠিক পরিমাণ লিখুন', 'Enter a valid amount'));
      return;
    }
    if (amount > _remaining) {
      _showMessage(
        _t(
          'বাকি টাকার চেয়ে বেশি দেওয়া যাবে না',
          'Amount cannot exceed the remaining balance',
        ),
      );
      return;
    }
    if (_selectedAccountId == null) {
      _showMessage(_t('অ্যাকাউন্ট নির্বাচন করুন', 'Select an account'));
      return;
    }

    final loanId = (widget.loan['id'] as num?)?.toInt();
    if (loanId == null) return;

    setState(() => _saving = true);
    try {
      await widget.db.addLoanRepayment(
        loanId: loanId,
        amount: amount,
        accountId: _selectedAccountId!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        transactionDate: _date,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = (widget.loan['person_name'] ??
            _t('নাম নেই', 'No name'))
        .toString();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _receivable
                    ? _t('ধার ফেরত পেয়েছি', 'Receive repayment')
                    : _t('ধার শোধ করেছি', 'Pay repayment'),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(person),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  '${_t('বর্তমান বাকি', 'Remaining')}: '
                  '৳ ${_remaining.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t('পরিমাণ', 'Amount'),
                  prefixText: '৳ ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedAccountId,
                decoration: InputDecoration(
                  labelText: _t('অ্যাকাউন্ট', 'Account'),
                  border: const OutlineInputBorder(),
                ),
                items: _accounts.map((account) {
                  final id = (account['id'] as num?)?.toInt();
                  if (id == null) return null;
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(account['name']?.toString() ?? ''),
                  );
                }).whereType<DropdownMenuItem<int>>().toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                          _selectedAccountId = value;
                        }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _t('নোট', 'Note'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(_t('লেনদেনের তারিখ', 'Transaction date')),
                subtitle: Text(_dateText()),
                trailing: const Icon(Icons.chevron_right),
                onTap: _saving ? null : _pickDate,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _saving
                        ? _t('সংরক্ষণ হচ্ছে...', 'Saving...')
                        : _t('সংরক্ষণ করুন', 'Save repayment'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  
