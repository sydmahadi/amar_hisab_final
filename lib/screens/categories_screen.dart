import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/money_db.dart';
import '../theme/app_theme.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _incomeCategories = [];
  List<Map<String, dynamic>> _expenseCategories = [];

  List<Map<String, dynamic>> _allTransactions = [];

  bool _loading = true;

  String _dateFilter = 'all';

  DateTime? _selectedDate;
  DateTime? _selectedMonth;

  AppSettings get settings => AppSettings.instance;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOAD
  // ------------------------------------------------------------

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final income = await MoneyDb.instance.getCategories(
        type: 'income',
      );

      final expense = await MoneyDb.instance.getCategories(
        type: 'expense',
      );

      final transactions =
          await MoneyDb.instance.getTransactions();

      if (!mounted) return;

      setState(() {
        _incomeCategories = income;
        _expenseCategories = expense;
        _allTransactions = transactions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
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

  // ------------------------------------------------------------
  // FILTERED TRANSACTIONS
  // ------------------------------------------------------------

  List<Map<String, dynamic>> _filteredTransactions(
    String type,
  ) {
    var transactions = _allTransactions.where((item) {
      return item['type']?.toString() == type;
    }).toList();

    if (_dateFilter == 'date' && _selectedDate != null) {
      final selected = _selectedDate!;

      transactions = transactions.where((item) {
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

      transactions = transactions.where((item) {
        final date = _parseDate(
          item['transaction_date']?.toString(),
        );

        if (date == null) return false;

        return date.year == selected.year &&
            date.month == selected.month;
      }).toList();
    }

    return transactions;
  }

  // ------------------------------------------------------------
  // AMOUNT
  // ------------------------------------------------------------

  double _transactionAmount(
    Map<String, dynamic> transaction,
  ) {
    final value = transaction['amount'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _formatAmount(double amount) {
    if (amount == amount.toInt()) {
      return amount.toInt().toString();
    }

    return amount.toStringAsFixed(2);
  }

  // ------------------------------------------------------------
  // CATEGORY AMOUNT
  // ------------------------------------------------------------

  double _categoryAmount(
    Map<String, dynamic> category,
  ) {
    final type =
        category['type']?.toString() ?? 'expense';

    final categoryId = category['id'];

    final categoryName =
        category['name']?.toString().trim() ?? '';

    final transactions =
        _filteredTransactions(type);

    double total = 0;

    for (final transaction in transactions) {
      final transactionCategoryId =
          transaction['category_id'];

      final transactionCategoryName =
          transaction['category_name']
                  ?.toString()
                  .trim() ??
              '';

      bool matches = false;

      // First try category ID.
      if (categoryId != null &&
          transactionCategoryId != null) {
        final categoryIdString =
            categoryId.toString();

        final transactionCategoryIdString =
            transactionCategoryId.toString();

        matches =
            categoryIdString ==
                transactionCategoryIdString;
      }

      // Fallback to category name.
      if (!matches &&
          categoryName.isNotEmpty &&
          transactionCategoryName.isNotEmpty) {
        matches =
            categoryName ==
                transactionCategoryName;
      }

      if (matches) {
        total += _transactionAmount(transaction);
      }
    }

    return total;
  }

  // ------------------------------------------------------------
  // FILTER LABEL
  // ------------------------------------------------------------

  String _filterLabel() {
    if (_dateFilter == 'date' &&
        _selectedDate != null) {
      final date = _selectedDate!;

      if (settings.isBangla) {
        return '${date.day}/${date.month}/${date.year}';
      }

      return '${date.month}/${date.day}/${date.year}';
    }

    if (_dateFilter == 'month' &&
        _selectedMonth != null) {
      return _monthName(
        _selectedMonth!.month,
        _selectedMonth!.year,
      );
    }

    return settings.isBangla
        ? 'সব'
        : 'All';
  }

  // ------------------------------------------------------------
  // MONTH NAME
  // ------------------------------------------------------------

  String _monthName(
    int month,
    int year,
  ) {
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
      _dateFilter = 'all';
      _selectedDate = null;
      _selectedMonth = null;
    });

    await _loadCategories();
  }

  // ------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ?? now,
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

    if (mounted) {
      setState(() {});
    }
  }

  // ------------------------------------------------------------
  // MONTH PICKER
  // ------------------------------------------------------------

  Future<void> _pickMonth() async {
    final now = DateTime.now();

    int selectedMonth =
        _selectedMonth?.month ??
            now.month;

    int selectedYear =
        _selectedMonth?.year ??
            now.year;

    final years = List<int>.generate(
      31,
      (index) =>
          now.year - 15 + index,
    );

    final result =
        await showModalBottomSheet<
            Map<String, int>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      settings.isBangla
                          ? 'মাস নির্বাচন করুন'
                          : 'Select month',
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              DropdownButtonFormField<
                                  int>(
                            initialValue:
                                selectedMonth,
                            decoration:
                                InputDecoration(
                              labelText:
                                  settings.isBangla
                                      ? 'মাস'
                                      : 'Month',
                              prefixIcon:
                                  const Icon(
                                Icons
                                    .calendar_month_rounded,
                              ),
                            ),
                            items:
                                List.generate(
                              12,
                              (index) {
                                final month =
                                    index + 1;

                                final months =
                                    settings.isBangla
                                        ? const [
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
                                          ]
                                        : const [
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

                                return DropdownMenuItem<
                                    int>(
                                  value: month,
                                  child: Text(
                                    months[
                                        month - 1],
                                  ),
                                );
                              },
                            ),
                            onChanged:
                                (value) {
                              if (value ==
                                  null) {
                                return;
                              }

                              setSheetState(
                                () {
                                  selectedMonth =
                                      value;
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child:
                              DropdownButtonFormField<
                                  int>(
                            initialValue:
                                selectedYear,
                            decoration:
                                InputDecoration(
                              labelText:
                                  settings.isBangla
                                      ? 'বছর'
                                      : 'Year',
                              prefixIcon:
                                  const Icon(
                                Icons
                                    .date_range_rounded,
                              ),
                            ),
                            items: years.map(
                              (year) {
                                return DropdownMenuItem<
                                    int>(
                                  value: year,
                                  child: Text(
                                    year.toString(),
                                  ),
                                );
                              },
                            ).toList(),
                            onChanged:
                                (value) {
                              if (value ==
                                  null) {
                                return;
                              }

                              setSheetState(
                                () {
                                  selectedYear =
                                      value;
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(
                            sheetContext,
                            {
                              'month':
                                  selectedMonth,
                              'year':
                                  selectedYear,
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
                        style:
                            FilledButton.styleFrom(
                          backgroundColor:
                              AppTheme.green,
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

    if (mounted) {
      setState(() {});
    }
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
            padding:
                const EdgeInsets.fromLTRB(
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
                  padding:
                      const EdgeInsets.fromLTRB(
                    4,
                    4,
                    4,
                    10,
                  ),
                  child: Text(
                    settings.isBangla
                        ? 'খাতের হিসাব ফিল্টার'
                        : 'Category filter',
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
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
                  trailing:
                      _dateFilter == 'all'
                          ? const Icon(
                              Icons
                                  .check_circle_rounded,
                              color:
                                  AppTheme.green,
                            )
                          : null,
                  onTap: () async {
                    Navigator.pop(
                      sheetContext,
                    );

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
                              _selectedDate !=
                                  null
                          ? Text(
                              _filterLabel(),
                            )
                          : null,
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () async {
                    Navigator.pop(
                      sheetContext,
                    );

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
                      _dateFilter ==
                                  'month' &&
                              _selectedMonth !=
                                  null
                          ? Text(
                              _filterLabel(),
                            )
                          : null,
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () async {
                    Navigator.pop(
                      sheetContext,
                    );

                    await _pickMonth();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // FILTER BAR
  // ------------------------------------------------------------

  Widget _buildCompactFilterBar() {
    final hasFilter =
        _dateFilter != 'all';

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hasFilter
                  ? _filterLabel()
                  : (settings.isBangla
                      ? 'সব লেনদেন'
                      : 'All transactions'),
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
                color: hasFilter
                    ? AppTheme.green
                    : Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color,
              ),
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          InkWell(
            onTap: _showFilterMenu,
            borderRadius:
                BorderRadius.circular(10),
            child: Container(
              height: 36,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
              ),
              decoration:
                  BoxDecoration(
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
                mainAxisSize:
                    MainAxisSize.min,
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
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    settings.isBangla
                        ? 'ফিল্টার'
                        : 'Filter',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
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
      ),
    );
  }

  // ------------------------------------------------------------
  // ADD CATEGORY
  // ------------------------------------------------------------

  Future<void> _showAddCategoryDialog() async {
    final nameController =
        TextEditingController();

    String type =
        _tabController.index == 0
            ? 'income'
            : 'expense';

    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            dialogBuilderContext,
            setDialogState,
          ) {
            return AlertDialog(
              title: Text(
                settings.t('addCategory'),
              ),
              content: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  TextField(
                    controller:
                        nameController,
                    autofocus: true,
                    decoration:
                        InputDecoration(
                      labelText: settings.t(
                        'categoryName',
                      ),
                      hintText:
                          settings.t(
                        'enterName',
                      ),
                      prefixIcon:
                          const Icon(
                        Icons
                            .category_outlined,
                        color:
                            AppTheme.gold,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  DropdownButtonFormField<
                      String>(
                    initialValue: type,
                    decoration:
                        InputDecoration(
                      labelText:
                          settings.isBangla
                              ? 'খাতের ধরন'
                              : 'Category Type',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'income',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .arrow_downward_rounded,
                              size: 19,
                              color: Colors
                                  .green
                                  .shade600,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Text(
                              settings.t(
                                'income',
                              ),
                            ),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'expense',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .arrow_upward_rounded,
                              size: 19,
                              color: Colors
                                  .red
                                  .shade600,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Text(
                              settings.t(
                                'expense',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged:
                        (value) {
                      if (value ==
                          null) {
                        return;
                      }

                      setDialogState(
                        () {
                          type = value;
                        },
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: Text(
                    settings.t('cancel'),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      () async {
                    final name =
                        nameController
                            .text
                            .trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger
                              .of(
                        dialogBuilderContext,
                      ).showSnackBar(
                        SnackBar(
                          content:
                              Text(
                            settings.t(
                              'enterName',
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      await MoneyDb
                          .instance
                          .addCategory(
                        name: name,
                        type: type,
                        icon: type ==
                                'income'
                            ? Icons
                                .payments_outlined
                                .codePoint
                            : Icons
                                .category_outlined
                                .codePoint,
                        color: type ==
                                'income'
                            ? 0xFF176B45
                            : 0xFFE57373,
                      );

                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        true,
                      );
                    } catch (e) {
                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      ScaffoldMessenger
                              .of(
                        dialogContext,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString()
                                .replaceFirst(
                              'Exception: ',
                              '',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    settings.t('save'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();

    if (result == true) {
      await _loadCategories();

      if (!mounted) return;

      _showMessage(
        settings.isBangla
            ? 'নতুন খাত যোগ হয়েছে'
            : 'Category added',
      );
    }
  }

  // ------------------------------------------------------------
  // EDIT CATEGORY
  // ------------------------------------------------------------

  Future<void> _showEditCategoryDialog(
    Map<String, dynamic> category,
  ) async {
    final id =
        category['id'] as int;

    final nameController =
        TextEditingController(
      text:
          category['name']
                  ?.toString() ??
              '',
    );

    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            settings.isBangla
                ? 'খাত এডিট করুন'
                : 'Edit Category',
          ),
          content: TextField(
            controller:
                nameController,
            autofocus: true,
            decoration:
                InputDecoration(
              labelText:
                  settings.t(
                'categoryName',
              ),
              prefixIcon:
                  const Icon(
                Icons
                    .category_outlined,
                color:
                    AppTheme.gold,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                settings.t('cancel'),
              ),
            ),
            ElevatedButton(
              onPressed:
                  () async {
                final name =
                    nameController
                        .text
                        .trim();

                if (name.isEmpty) {
                  ScaffoldMessenger
                          .of(
                    dialogContext,
                  ).showSnackBar(
                    SnackBar(
                      content:
                          Text(
                        settings.t(
                          'enterName',
                        ),
                      ),
                    ),
                  );
                  return;
                }

                try {
                  await MoneyDb
                      .instance
                      .updateCategory(
                    id,
                    name: name,
                  );

                  if (!dialogContext
                      .mounted) {
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                } catch (e) {
                  if (!dialogContext
                      .mounted) {
                    return;
                  }

                  ScaffoldMessenger
                          .of(
                    dialogContext,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString()
                            .replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      ),
                    ),
                  );
                }
              },
              child: Text(
                settings.t('update'),
              ),
            ),
          ],
        );
      },
    );

    nameController.dispose();

    if (result == true) {
      await _loadCategories();

      if (!mounted) return;

      _showMessage(
        settings.isBangla
            ? 'খাত আপডেট হয়েছে'
            : 'Category updated',
      );
    }
  }

  // ------------------------------------------------------------
  // DELETE CATEGORY
  // ------------------------------------------------------------

  Future<void> _deleteCategory(
    Map<String, dynamic> category,
  ) async {
    final id =
        category['id'] as int;

    final isDefault =
        (category['is_default'] ?? 0) ==
            1;

    if (isDefault) {
      _showMessage(
        settings.isBangla
            ? 'ডিফল্ট খাত মুছে ফেলা যাবে না'
            : 'Default categories cannot be deleted',
        isError: true,
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            settings.isBangla
                ? 'খাত মুছে ফেলুন'
                : 'Delete Category',
          ),
          content: Text(
            settings.isBangla
                ? 'আপনি কি এই খাতটি মুছে ফেলতে চান?'
                : 'Do you want to delete this category?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                settings.t('cancel'),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red.shade700,
              ),
              child: Text(
                settings.t('delete'),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await MoneyDb.instance
          .deleteCategory(id);

      await _loadCategories();

      if (!mounted) return;

      _showMessage(
        settings.isBangla
            ? 'খাত মুছে ফেলা হয়েছে'
            : 'Category deleted',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
        isError: true,
      );
    }
  }

  // ------------------------------------------------------------
  // CATEGORY ICON
  // ------------------------------------------------------------

  IconData _iconForCategory(
    dynamic icon,
    String type,
  ) {
    if (type == 'income') {
      return Icons.payments_outlined;
    }

    return Icons.category_outlined;
  }

  // ------------------------------------------------------------
  // CATEGORY COLOR
  // ------------------------------------------------------------

  Color _colorForCategory(
    Map<String, dynamic> category,
  ) {
    final value =
        category['color'];

    if (value is int) {
      return Color(value);
    }

    if (value is num) {
      return Color(
        value.toInt(),
      );
    }

    final type =
        category['type']?.toString();

    return type == 'income'
        ? AppTheme.green
        : Colors.red.shade400;
  }

  // ------------------------------------------------------------
  // CATEGORY CARD
  // ------------------------------------------------------------

  Widget _buildCategoryCard(
    Map<String, dynamic> category,
  ) {
    final type =
        category['type']?.toString() ??
            'expense';

    final name =
        category['name']?.toString() ??
            '';

    final color =
        _colorForCategory(category);

    final isDefault =
        (category['is_default'] ?? 0) ==
            1;

    final total =
        _categoryAmount(category);

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 3,
        ),

        leading: Container(
          width: 46,
          height: 46,
          decoration:
              BoxDecoration(
            color:
                color.withValues(
              alpha: 0.12,
            ),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: Icon(
            _iconForCategory(
              category['icon'],
              type,
            ),
            color: color,
          ),
        ),

        title: Text(
          name,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        subtitle: Text(
          isDefault
              ? settings.isBangla
                  ? 'ডিফল্ট খাত'
                  : 'Default category'
              : settings.isBangla
                  ? 'নিজস্ব খাত'
                  : 'Custom category',
          style: TextStyle(
            fontSize: 11,
            color: isDefault
                ? AppTheme.gold
                : Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color,
          ),
        ),

        trailing: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  _formatAmount(
                    total,
                  ),
                  style:
                      TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  settings.isBangla
                      ? '৳ মোট'
                      : 'Total',
                  style:
                      TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    )
                        .textTheme
                        .bodySmall
                        ?.color,
                  ),
                ),
              ],
            ),

            const SizedBox(
              width: 4,
            ),

            PopupMenuButton<
                String>(
              onSelected:
                  (value) {
                if (value ==
                    'edit') {
                  _showEditCategoryDialog(
                    category,
                  );
                }

                if (value ==
                    'delete') {
                  _deleteCategory(
                    category,
                  );
                }
              },
              itemBuilder:
                  (context) {
                return [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons
                              .edit_outlined,
                          size: 20,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Text(
                          settings.t(
                            'edit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isDefault)
                    PopupMenuItem(
                      value:
                          'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .delete_outline,
                            size: 20,
                            color: Colors
                                .red
                                .shade600,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            settings.t(
                              'delete',
                            ),
                            style:
                                TextStyle(
                              color: Colors
                                  .red
                                  .shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CATEGORY LIST
  // ------------------------------------------------------------

  Widget _buildCategoryList(
    List<Map<String, dynamic>>
        categories,
  ) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons
                  .category_outlined,
              size: 58,
              color: AppTheme.gold
                  .withValues(
                alpha: 0.7,
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            Text(
              settings.isBangla
                  ? 'কোনো খাত নেই'
                  : 'No categories',
              style:
                  const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              settings.isBangla
                  ? 'নিচের + বাটনে নতুন খাত যোগ করুন'
                  : 'Tap the + button to add a category',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                )
                    .textTheme
                    .bodySmall
                    ?.color,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          _loadCategories,
      child:
          ListView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          100,
        ),
        itemCount:
            categories.length,
        itemBuilder:
            (context, index) {
          return _buildCategoryCard(
            categories[index],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          settings.t(
            'categories',
          ),
        ),
        bottom: TabBar(
          controller:
              _tabController,
          indicatorColor:
              AppTheme.gold,
          indicatorWeight: 3,
          labelColor:
              AppTheme.gold,
          unselectedLabelColor:
              Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color,
          tabs: [
            Tab(
              icon: const Icon(
                Icons
                    .arrow_downward_rounded,
              ),
              text: settings.t(
                'incomeCategories',
              ),
            ),
            Tab(
              icon: const Icon(
                Icons
                    .arrow_upward_rounded,
              ),
              text: settings.t(
                'expenseCategories',
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          _buildCompactFilterBar(),

          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : TabBarView(
                    controller:
                        _tabController,
                    children: [
                      _buildCategoryList(
                        _incomeCategories,
                      ),
                      _buildCategoryList(
                        _expenseCategories,
                      ),
                    ],
                  ),
          ),
        ],
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _showAddCategoryDialog,
        backgroundColor:
            AppTheme.green,
        foregroundColor:
            Colors.white,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: Text(
          settings.isBangla
              ? 'খাত যোগ করুন'
              : 'Add Category',
        ),
      ),
    );
  }
}
