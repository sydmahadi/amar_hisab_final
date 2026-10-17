
import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/money_db.dart';
import '../theme/app_theme.dart';

import 'about_screen.dart';
import 'accounts_screen.dart';
import 'add_transaction_screen.dart';
import 'categories_screen.dart';
import 'loan_screen.dart';
import 'report_screen.dart';
import 'savings_screen.dart';
import 'statistics_screen.dart';
import 'transaction_screen.dart';
import 'budget_screen.dart';
import 'notification_screen.dart';
import 'backup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MoneyDb _db = MoneyDb.instance;
  final AppSettings _settings = AppSettings.instance;

  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  bool _loading = true;

  double _income = 0;
  double _expense = 0;
  double _difference = 0;
  double _accountBalance = 0;

  double _receivable = 0;
  double _payable = 0;

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _categories = [];

  // Upcoming reminder data
  List<Map<String, dynamic>> _reminderLoans = [];
  List<Map<String, dynamic>> _reminderDps = [];

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _loadDashboard();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadDashboard() async {
    try {
      final accounts = await _db.getAccounts();
      final transactions = await _db.getTransactions();
      final totalBalance = await _db.getTotalBalance();
      final loanTotals = await _db.getLoanTotals();
      final categories = await _db.getCategories();

      List<Map<String, dynamic>> reminderLoans = [];
      List<Map<String, dynamic>> reminderDps = [];

      try {
        reminderLoans = await _db.getLoansDueForReminder(
          daysAhead: 7,
        );
        reminderDps = await _db.getDpsDueForReminder(
          daysAhead: 7,
        );
      } catch (_) {
        // Dashboard will continue working if reminders fail to load.
      }

      double totalIncome = 0;
      double totalExpense = 0;

      for (final transaction in transactions) {
        final type =
            (transaction['type'] ?? '').toString().toLowerCase();
        final amount = _toDouble(transaction['amount']);

        if (type == 'income') {
          totalIncome += amount;
        } else if (type == 'expense') {
          totalExpense += amount;
        }
      }

      final difference = totalIncome - totalExpense;
      final receivable = _toDouble(loanTotals['receivable']);
      final payable = _toDouble(loanTotals['payable']);

      final sortedCategories =
          List<Map<String, dynamic>>.from(categories);

      sortedCategories.sort((a, b) {
        final aId = _toDouble(a['id']);
        final bId = _toDouble(b['id']);
        return bId.compareTo(aId);
      });

      final recentCategories = <Map<String, dynamic>>[];

      for (final category in sortedCategories.take(5)) {
        final categoryId = _toDouble(category['id']);
        double total = 0;

        for (final transaction in transactions) {
          final transactionCategoryId =
              _toDouble(transaction['category_id']);

          if (transactionCategoryId == categoryId) {
            final type = _type(transaction);

            if (type == 'income' || type == 'expense') {
              total += _toDouble(transaction['amount']);
            }
          }
        }

        recentCategories.add({
          ...category,
          'home_total': total,
        });
      }

      if (!mounted) return;

      setState(() {
        _income = totalIncome;
        _expense = totalExpense;
        _difference = difference;
        _accountBalance = _toDouble(totalBalance);
        _receivable = receivable;
        _payable = payable;
        _accounts = accounts;
        _transactions = transactions.take(5).toList();
        _categories = recentCategories;
        _reminderLoans = reminderLoans;
        _reminderDps = reminderDps;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _money(double value) => value.toStringAsFixed(2);

  String _type(Map<String, dynamic> item) {
    return (item['type'] ?? '').toString().toLowerCase();
  }

  String _transactionTitle(Map<String, dynamic> item) {
    final type = _type(item);

    if (type == 'transfer') {
      final from = (item['from_account_name'] ?? '').toString();
      final to = (item['to_account_name'] ?? '').toString();

      if (from.isNotEmpty && to.isNotEmpty) {
        return '$from → $to';
      }
      return _settings.t('transfer');
    }

    final category = (item['category_name'] ?? '').toString();
    if (category.isNotEmpty) return category;

    if (type == 'income') return _settings.t('income');
    if (type == 'expense') return _settings.t('expense');

    if (type == 'loan_given') {
      return _settings.isBangla ? 'ধার দিয়েছি' : 'Loan given';
    }
    if (type == 'loan_taken') {
      return _settings.isBangla ? 'ধার নিয়েছি' : 'Loan taken';
    }
    if (type == 'loan_received') {
      return _settings.isBangla
          ? 'ধার ফেরত পেয়েছি'
          : 'Loan received';
    }
    if (type == 'loan_paid') {
      return _settings.isBangla ? 'ধার শোধ করেছি' : 'Loan paid';
    }

    return _settings.t('transactions');
  }

  String _transactionSubtitle(Map<String, dynamic> item) {
    final type = _type(item);

    if (type == 'loan_given' ||
        type == 'loan_taken' ||
        type == 'loan_received' ||
        type == 'loan_paid') {
      final person = (item['loan_person_name'] ?? '').toString();
      final note = (item['note'] ?? '').toString();

      if (person.isNotEmpty && note.isNotEmpty) {
        return '$person • $note';
      }
      if (person.isNotEmpty) return person;
      if (note.isNotEmpty) return note;
    }

    final note = (item['note'] ?? '').toString();
    if (note.isNotEmpty) return note;

    final date = (item['transaction_date'] ?? '').toString();
    if (date.length >= 10) return date.substring(0, 10);

    return date;
  }

  IconData _transactionIcon(String type) {
    switch (type) {
      case 'income':
        return Icons.south_west_rounded;
      case 'expense':
        return Icons.north_east_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'loan_given':
        return Icons.call_made_rounded;
      case 'loan_taken':
        return Icons.call_received_rounded;
      case 'loan_received':
        return Icons.keyboard_return_rounded;
      case 'loan_paid':
        return Icons.payments_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  Color _transactionColor(String type) {
    switch (type) {
      case 'income':
        return AppTheme.incomeColor;
      case 'expense':
        return AppTheme.expenseColor;
      case 'transfer':
        return AppTheme.transferColor;
      case 'loan_given':
      case 'loan_taken':
      case 'loan_received':
      case 'loan_paid':
        return AppTheme.gold;
      default:
        return AppTheme.gold;
    }
  }

  String _transactionAmount(Map<String, dynamic> item) {
    final type = _type(item);
    final amount = _toDouble(item['amount']);

    if (type == 'income' ||
        type == 'loan_received' ||
        type == 'loan_taken') {
      return '+${_money(amount)}';
    }

    if (type == 'expense' ||
        type == 'loan_given' ||
        type == 'loan_paid') {
      return '-${_money(amount)}';
    }

    return _money(amount);
  }

  Future<void> _openAddTransaction() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
      ),
    );

    if (result == true) await _loadDashboard();
  }

  Future<void> _editTransaction(int id) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(transactionId: id),
      ),
    );

    if (result == true) await _loadDashboard();
  }

  Future<void> _deleteTransaction(int id) async {
    await _db.deleteTransaction(id);
    await _loadDashboard();
  }

  Future<void> _openScreen(Widget screen) async {
    if (!mounted) return;

    _scaffoldKey.currentState?.closeDrawer();

    await Future<void>.delayed(
      const Duration(milliseconds: 150),
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );

    if (!mounted) return;
    await _loadDashboard();
  }

  void _showDeleteDialog(Map<String, dynamic> transaction) {
    final rawId = transaction['id'];
    if (rawId == null) return;

    final id = rawId is int
        ? rawId
        : int.tryParse(rawId.toString());

    if (id == null) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_settings.t('delete')),
          content: Text(_settings.t('deleteConfirmation')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_settings.t('no')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteTransaction(id);
              },
              child: Text(_settings.t('delete')),
            ),
          ],
        );
      },
    );
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _changeTheme(bool value) async {
    await _settings.setDarkMode(value);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _changeLanguage(String language) async {
    await _settings.setLanguage(language);
    if (!mounted) return;
    setState(() {});
  }

  void _showSettings() {
    _scaffoldKey.currentState?.closeDrawer();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentDark = _settings.isDarkMode;
            final currentBangla = _settings.isBangla;

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: .30),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.green,
                                  AppTheme.darkGreen,
                                ],
                              ),
                              border: Border.all(color: AppTheme.gold),
                            ),
                            child: const Icon(
                              Icons.settings_rounded,
                              color: AppTheme.goldLight,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              _settings.t('settings'),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _settingTile(
                        icon: currentDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        title: _settings.t('theme'),
                        subtitle: currentDark
                            ? _settings.t('darkTheme')
                            : _settings.t('lightTheme'),
                        trailing: Switch(
                          value: currentDark,
                          onChanged: (value) async {
                            await _settings.setDarkMode(value);
                            if (!mounted) return;
                            setState(() {});
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _settingTile(
                        icon: Icons.language_rounded,
                        title: _settings.t('language'),
                        subtitle: currentBangla
                            ? _settings.t('bangla')
                            : _settings.t('english'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _languageButton(
                              label: 'বাংলা',
                              selected: currentBangla,
                              onTap: () async {
                                await _settings.setLanguage('bn');
                                if (!mounted) return;
                                setState(() {});
                                setSheetState(() {});
                              },
                            ),
                            const SizedBox(width: 6),
                            _languageButton(
                              label: 'EN',
                              selected: !currentBangla,
                              onTap: () async {
                                await _settings.setLanguage('en');
                                if (!mounted) return;
                                setState(() {});
                                setSheetState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: .45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: .18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                )),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                )),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _languageButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.green
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.gold : AppTheme.gold.withValues(alpha: .18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: _buildDrawer(),
      floatingActionButton: _buildFloatingAddButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: IslamicBackgroundPainter(dark: isDark),
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadDashboard,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        SliverToBoxAdapter(child: _buildBalanceCard()),
                        SliverToBoxAdapter(child: _buildLoanSection()),
                        SliverToBoxAdapter(
                          child: _buildUpcomingRemindersSection(),
                        ),
                        SliverToBoxAdapter(child: _buildQuickActions()),
                        SliverToBoxAdapter(child: _buildAccountSection()),
                        SliverToBoxAdapter(child: _buildRecentSection()),
                        SliverToBoxAdapter(
                          child: _buildRecentCategoriesSection(),
                        ),
                        SliverToBoxAdapter(child: _buildToolsSection()),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 90),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAddButton() {
    final label = _settings.isBangla ? 'লেনদেন যোগ' : 'Add transaction';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openAddTransaction,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.green, AppTheme.darkGreen],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.goldLight.withValues(alpha: .65),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkGreen.withValues(alpha: .35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.goldLight.withValues(alpha: .16),
                  border: Border.all(
                    color: AppTheme.goldLight.withValues(alpha: .55),
                  ),
                ),
                child: const Icon(Icons.add_rounded,
                    color: AppTheme.goldLight, size: 23),
              ),
              const SizedBox(width: 9),
              Text(label, style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final reminderCount = _reminderLoans.length + _reminderDps.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          _roundButton(icon: Icons.menu_rounded, onTap: _openDrawer),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _roundButton(
                icon: Icons.notifications_active_rounded,
                onTap: () => _openScreen(const NotificationScreen()),
              ),
              if (reminderCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 21,
                      minHeight: 21,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      reminderCount > 99 ? '99+' : '$reminderCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.gold.withValues(alpha: .28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? .18 : .05,
                ),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: AppTheme.gold),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final positive = _difference >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.green, AppTheme.darkGreen],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppTheme.goldLight.withValues(alpha: .45),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGreen.withValues(alpha: .28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -45,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.goldLight.withValues(alpha: .12),
                  width: 18,
                ),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -45,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.goldLight.withValues(alpha: .10),
                  width: 12,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: AppTheme.goldLight, size: 21),
                  const SizedBox(width: 8),
                  Text(_settings.t('balance'), style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
                ],
              ),
              const SizedBox(height: 9),
              Text(_money(_accountBalance), style: const TextStyle(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w900,
              )),
              const SizedBox(height: 4),
              Text(
                _settings.isBangla
                    ? 'সব অ্যাকাউন্টের বর্তমান ব্যালেন্স'
                    : 'Current balance of all accounts',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .70),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _balanceMini(
                      icon: Icons.arrow_downward_rounded,
                      title: _settings.t('incomeTotal'),
                      amount: _income,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _balanceMini(
                      icon: Icons.arrow_upward_rounded,
                      title: _settings.t('expenseTotal'),
                      amount: _expense,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .10),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      positive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: AppTheme.goldLight,
                      size: 21,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      positive
                          ? _settings.t('surplus')
                          : _settings.t('deficit'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(_money(_difference.abs()), style: const TextStyle(
                      color: AppTheme.goldLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceMini({
    required IconData icon,
    required String title,
    required double amount,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.goldLight, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  color: Colors.white.withValues(alpha: .65),
                  fontSize: 10,
                )),
                const SizedBox(height: 3),
                Text(_money(amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanSection() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: _settings.isBangla ? 'দেনা-পাওনা' : 'Loans',
            icon: Icons.handshake_rounded,
            onTap: () => _openScreen(const LoanScreen()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _loanSummaryCard(
                  icon: Icons.arrow_downward_rounded,
                  title: _settings.isBangla ? 'আমার পাওনা' : 'Receivable',
                  amount: _receivable,
                  color: AppTheme.incomeColor,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _loanSummaryCard(
                  icon: Icons.arrow_upward_rounded,
                  title: _settings.isBangla ? 'আমার দেনা' : 'Payable',
                  amount: _payable,
                  color: AppTheme.expenseColor,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loanSummaryCard({
    required IconData icon,
    required String title,
    required double amount,
    required Color color,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openScreen(const LoanScreen()),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? .10 : .025,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: .25)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingRemindersSection() {
    final theme = Theme.of(context);
    final isBn = _settings.isBangla;
    final reminderCount = _reminderLoans.length + _reminderDps.length;

    String dateText(dynamic value) {
      if (value == null || value.toString().isEmpty) {
        return isBn ? 'তারিখ নেই' : 'No date';
      }

      final date = DateTime.tryParse(value.toString());
      if (date == null) return value.toString();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    Widget reminderTile({
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required String date,
      required String amount,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: .35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .20)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${isBn ? 'তারিখ' : 'Date'}: $date',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              amount,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: isBn ? 'আসন্ন রিমাইন্ডার' : 'Upcoming Reminders',
            icon: Icons.notifications_active_rounded,
            onTap: () => _openScreen(const NotificationScreen()),
          ),
          const SizedBox(height: 10),
          if (reminderCount == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: .20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: AppTheme.gold,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isBn
                          ? 'আগামী ৭ দিনের কোনো রিমাইন্ডার পাওয়া যায়নি।'
                          : 'No reminders found for the next 7 days.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: .20),
                ),
              ),
              child: Column(
                children: [
                  ..._reminderLoans.take(4).map((loan) {
                    final name = (loan['person_name'] ??
                            loan['name'] ??
                            loan['person'] ??
                            (isBn ? 'দেনা-পাওনা' : 'Loan'))
                        .toString();

                    final dueDate = loan['due_date'] ??
                        loan['next_due_date'] ??
                        loan['reminder_date'];

                    final amount = _toDouble(
                      loan['remaining_amount'] ??
                          loan['due_amount'] ??
                          loan['amount'] ??
                          loan['remaining'],
                    );

                    return reminderTile(
                      icon: Icons.handshake_rounded,
                      color: AppTheme.incomeColor,
                      title: name,
                      subtitle: isBn
                          ? 'দেনা-পাওনার রিমাইন্ডার'
                          : 'Loan reminder',
                      date: dateText(dueDate),
                      amount: _money(amount),
                    );
                  }),
                  ..._reminderDps.take(4).map((dps) {
                    final name = (dps['name'] ??
                            dps['title'] ??
                            dps['scheme_name'] ??
                            (isBn ? 'DPS সঞ্চয়' : 'DPS savings'))
                        .toString();

                    final dueDate = dps['due_date'] ??
                        dps['next_due_date'] ??
                        dps['next_installment_date'] ??
                        dps['reminder_date'];

                    final amount = _toDouble(
                      dps['installment_amount'] ??
                          dps['due_amount'] ??
                          dps['amount'] ??
                          dps['monthly_amount'],
                    );

                    return reminderTile(
                      icon: Icons.savings_rounded,
                      color: AppTheme.gold,
                      title: name,
                      subtitle: isBn
                          ? 'সঞ্চয় / DPS কিস্তি'
                          : 'Savings / DPS installment',
                      date: dateText(dueDate),
                      amount: _money(amount),
                    );
                  }),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _openScreen(const NotificationScreen()),
                      icon: const Icon(Icons.notifications_active_rounded),
                      label: Text(
                        isBn ? 'সব রিমাইন্ডার দেখুন' : 'View all reminders',
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

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: _quickAction(
              icon: Icons.add_circle_outline_rounded,
              title: _settings.t('income'),
              subtitle: _settings.isBangla ? 'নতুন আয়' : 'New income',
              color: AppTheme.incomeColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _quickAction(
              icon: Icons.remove_circle_outline_rounded,
              title: _settings.t('expense'),
              subtitle: _settings.isBangla ? 'নতুন ব্যয়' : 'New expense',
              color: AppTheme.expenseColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _quickAction(
              icon: Icons.swap_horiz_rounded,
              title: _settings.t('transfer'),
              subtitle: _settings.isBangla ? 'অ্যাকাউন্ট' : 'Account',
              color: AppTheme.transferColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openAddTransaction,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: color.withValues(alpha: .25)),
          ),
          child: Column(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .13),
                  border: Border.all(color: color.withValues(alpha: .28)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: _settings.t('accounts'),
            icon: Icons.account_balance_wallet_rounded,
            onTap: () => _openScreen(const AccountsScreen()),
          ),
          const SizedBox(height: 10),
          if (_accounts.isEmpty)
            _emptyCard(
              icon: Icons.account_balance_wallet_outlined,
              text: _settings.isBangla
                  ? 'কোনো অ্যাকাউন্ট পাওয়া যায়নি'
                  : 'No accounts found',
            )
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _accounts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final account = _accounts[index];
                  final name = (account['name'] ?? 'Account').toString();
                  final balance = _toDouble(account['balance']);

                  return Container(
                    width: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: .22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 31,
                              height: 31,
                              decoration: BoxDecoration(
                                color: AppTheme.green.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_rounded,
                                color: AppTheme.gold,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          _money(balance),
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
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentSection() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: _settings.t('transactions'),
            icon: Icons.receipt_long_rounded,
            onTap: () => _openScreen(const TransactionsScreen()),
          ),
          const SizedBox(height: 10),
          if (_transactions.isEmpty)
            _emptyCard(
              icon: Icons.receipt_long_outlined,
              text: _settings.t('noTransactions'),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: .20),
                ),
              ),
              child: Column(
                children: List.generate(_transactions.length, (index) {
                  final item = _transactions[index];
                  final type = _type(item);
                  final color = _transactionColor(type);
                  final rawId = item['id'];
                  final id = rawId is int
                      ? rawId
                      : int.tryParse(rawId.toString());

                  return Column(
                    children: [
                      if (index != 0)
                        Divider(
                          height: 1,
                          indent: 68,
                          endIndent: 16,
                          color: AppTheme.gold.withValues(alpha: .10),
                        ),
                      ListTile(
                        onTap: () =>
                            _openScreen(const TransactionsScreen()),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: color.withValues(alpha: .25),
                            ),
                          ),
                          child: Icon(
                            _transactionIcon(type),
                            color: color,
                            size: 21,
                          ),
                        ),
                        title: Text(
                          _transactionTitle(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          _transactionSubtitle(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _transactionAmount(item),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                              onSelected: (value) {
                                if (id == null) return;
                                if (value == 'edit') {
                                  _editTransaction(id);
                                }
                                if (value == 'delete') {
                                  _showDeleteDialog(item);
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_rounded, size: 19),
                                      const SizedBox(width: 10),
                                      Text(_settings.t('edit')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 19,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(_settings.t('delete')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentCategoriesSection() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: _settings.isBangla ? 'সাম্প্রতিক খাত' : 'Recent Categories',
            icon: Icons.category_rounded,
            onTap: () => _openScreen(const CategoriesScreen()),
          ),
          const SizedBox(height: 10),
          if (_categories.isEmpty)
            _emptyCard(
              icon: Icons.category_outlined,
              text: _settings.isBangla
                  ? 'কোনো ক্যাটাগরি পাওয়া যায়নি'
                  : 'No categories found',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: .20),
                ),
              ),
              child: Column(
                children: List.generate(_categories.length, (index) {
                  final category = _categories[index];
                  final name = (category['name'] ?? '').toString();
                  final amount = _toDouble(category['home_total']);

                  return Column(
                    children: [
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppTheme.gold.withValues(alpha: .12),
                        ),
                      ListTile(
                        onTap: () =>
                            _openScreen(const CategoriesScreen()),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 3,
                        ),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: AppTheme.gold.withValues(alpha: .25),
                            ),
                          ),
                          child: const Icon(
                            Icons.category_rounded,
                            color: AppTheme.gold,
                            size: 21,
                          ),
                        ),
                        title: Text(
                          name.isEmpty
                              ? (_settings.isBangla
                                  ? 'নামহীন খাত'
                                  : 'Unnamed category')
                              : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          _settings.isBangla
                              ? 'মোট লেনদেন'
                              : 'Total transactions',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        trailing: Text(
                          _money(amount),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: _settings.isBangla ? 'আরও' : 'More',
            icon: Icons.grid_view_rounded,
            onTap: () {},
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: .92,
            children: [
              _toolCard(
                icon: Icons.pie_chart_rounded,
                title: _settings.isBangla ? 'বাজেট' : 'Budget',
                onTap: () => _openScreen(const BudgetScreen()),
              ),
              _toolCard(
                icon: Icons.notifications_active_rounded,
                title: _settings.isBangla ? 'রিমাইন্ডার' : 'Reminder',
                onTap: () => _openScreen(const NotificationScreen()),
              ),
              _toolCard(
                icon: Icons.receipt_long_rounded,
                title: _settings.t('transactions'),
                onTap: () => _openScreen(const TransactionsScreen()),
              ),
              _toolCard(
                icon: Icons.handshake_rounded,
                title: _settings.isBangla ? 'দেনা-পাওনা' : 'Loans',
                onTap: () => _openScreen(const LoanScreen()),
              ),
              _toolCard(
                icon: Icons.bar_chart_rounded,
                title: _settings.t('statistics'),
                onTap: () => _openScreen(const StatisticsScreen()),
              ),
              _toolCard(
                icon: Icons.assessment_rounded,
                title: _settings.t('report'),
                onTap: () => _openScreen(const ReportScreen()),
              ),
              _toolCard(
                icon: Icons.category_rounded,
                title: _settings.t('categories'),
                onTap: () => _openScreen(const CategoriesScreen()),
              ),
              _toolCard(
                icon: Icons.account_balance_rounded,
                title: _settings.t('accounts'),
                onTap: () => _openScreen(const AccountsScreen()),
              ),
              _toolCard(
                icon: Icons.info_outline_rounded,
                title: _settings.t('about'),
                onTap: () => _openScreen(const AboutScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 19, color: AppTheme.gold),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String text,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: .18),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: AppTheme.gold.withValues(alpha: .22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? .13 : .035,
                ),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.green, AppTheme.darkGreen],
                  ),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: .55),
                  ),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.goldLight,
                  size: 23,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    final theme = Theme.of(context);
    final currentDark = _settings.isDarkMode;
    final currentBangla = _settings.isBangla;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      width: MediaQuery.of(context).size.width * .84,
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                children: [
                  _drawerItem(
                    icon: Icons.home_rounded,
                    title: _settings.t('appName'),
                    selected: true,
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                    },
                  ),
                  _drawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: _settings.t('transactions'),
                    onTap: () => _openScreen(const TransactionsScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: _settings.t('accounts'),
                    onTap: () => _openScreen(const AccountsScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.category_rounded,
                    title: _settings.t('categories'),
                    onTap: () => _openScreen(const CategoriesScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.bar_chart_rounded,
                    title: _settings.t('statistics'),
                    onTap: () => _openScreen(const StatisticsScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.assessment_rounded,
                    title: _settings.t('report'),
                    onTap: () => _openScreen(const ReportScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.handshake_rounded,
                    title: _settings.isBangla ? 'দেনা-পাওনা' : 'Loans',
                    onTap: () => _openScreen(const LoanScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.savings_rounded,
                    title: _settings.isBangla ? 'সঞ্চয়' : 'Savings',
                    onTap: () => _openScreen(const SavingsScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.pie_chart_rounded,
                    title: _settings.isBangla ? 'বাজেট' : 'Budget',
                    onTap: () => _openScreen(const BudgetScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.notifications_active_rounded,
                    title: _settings.isBangla ? 'রিমাইন্ডার' : 'Reminder',
                    onTap: () => _openScreen(const NotificationScreen()),
                  ),
                  _drawerItem(
                    icon: Icons.backup_rounded,
                    title: _settings.isBangla ? 'ব্যাকআপ ও রিস্টোর' : 'Backup & Restore',
                    onTap: () => _openScreen(const BackupScreen()),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Divider(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: .08,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: .18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 39,
                          height: 39,
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            currentDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: AppTheme.gold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _settings.t('theme'),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentDark
                                    ? _settings.t('darkTheme')
                                    : _settings.t('lightTheme'),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: currentDark,
                          onChanged: _changeTheme,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: .18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 39,
                          height: 39,
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.language_rounded,
                            color: AppTheme.gold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            _settings.t('language'),
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _languageButton(
                          label: 'বাংলা',
                          selected: currentBangla,
                          onTap: () => _changeLanguage('bn'),
                        ),
                        const SizedBox(width: 6),
                        _languageButton(
                          label: 'EN',
                          selected: !currentBangla,
                          onTap: () => _changeLanguage('en'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  _drawerItem(
                    icon: Icons.settings_rounded,
                    title: _settings.t('settings'),
                    onTap: _showSettings,
                  ),
                  _drawerItem(
                    icon: Icons.info_outline_rounded,
                    title: _settings.t('about'),
                    onTap: () => _openScreen(const AboutScreen()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Text(
                _settings.isBangla
                    ? 'সহজে হিসাব রাখুন'
                    : 'Manage your money easily',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.green, AppTheme.darkGreen],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.goldLight.withValues(alpha: .42),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .09),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.goldLight),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppTheme.goldLight,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _settings.t('appName'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _settings.t('appTagline'),
                  style: const TextStyle(
                    color: AppTheme.goldLight,
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

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.green.withValues(alpha: .14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: selected
            ? Border.all(
                color: AppTheme.gold.withValues(alpha: .20),
              )
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: selected ? AppTheme.green : theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.gold.withValues(
                alpha: selected ? .42 : .15,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected
                ? AppTheme.goldLight
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: selected
            ? const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.gold,
                size: 18,
              )
            : Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
      ),
    );
  }
}

class IslamicBackgroundPainter extends CustomPainter {
  final bool dark;

  IslamicBackgroundPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppTheme.gold.withValues(
        alpha: dark ? .045 : .035,
      );

    const spacing = 54.0;

    for (
      double x = -size.height;
      x < size.width + size.height;
      x += spacing
    ) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );

      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }

    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = AppTheme.gold.withValues(
        alpha: dark ? .035 : .025,
      );

    final centers = [
      Offset(size.width * .88, size.height * .18),
      Offset(size.width * .10, size.height * .62),
      Offset(size.width * .72, size.height * .82),
    ];

    for (final center in centers) {
      canvas.drawCircle(center, 42, circlePaint);
      canvas.drawCircle(center, 58, circlePaint);
      canvas.drawCircle(center, 74, circlePaint);
    }

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppTheme.gold.withValues(
        alpha: dark ? .06 : .035,
      );

    for (double y = 30; y < size.height; y += 82) {
      for (double x = 25; x < size.width; x += 82) {
        canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant IslamicBackgroundPainter oldDelegate) {
    return oldDelegate.dark != dark;
  }
}
