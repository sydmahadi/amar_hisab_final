import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class MoneyDb {
  MoneyDb._();

  static final MoneyDb instance = MoneyDb._();
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    final databasesPath = await getDatabasesPath();
    final databasePath = join(databasesPath, 'amar_hisab.db');

    _db = await openDatabase(
      databasePath,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Database get db {
    if (_db == null) {
      throw Exception('Database is not initialized.');
    }
    return _db!;
  }

  Future<void> _onCreate(Database database, int version) async {
    await database.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        icon INTEGER,
        color INTEGER,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon INTEGER,
        color INTEGER,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_name TEXT NOT NULL,
        type TEXT NOT NULL,
        principal REAL NOT NULL,
        remaining REAL NOT NULL,
        note TEXT,
        due_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER,
        account_id INTEGER,
        from_account_id INTEGER,
        to_account_id INTEGER,
        loan_id INTEGER,
        savings_id INTEGER,
        note TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _createSavingsTables(database);
    await _createBudgetTable(database);
    await _createIndexes(database);
    await _insertDefaultAccounts(database);
    await _insertDefaultCategories(database);
  }

  Future<void> _onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS loans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          person_name TEXT NOT NULL,
          type TEXT NOT NULL,
          principal REAL NOT NULL,
          remaining REAL NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      final columns =
          await database.rawQuery('PRAGMA table_info(transactions)');

      if (!columns.any((c) => c['name'] == 'loan_id')) {
        await database.execute(
          'ALTER TABLE transactions ADD COLUMN loan_id INTEGER',
        );
      }
    }

    if (oldVersion < 3) {
      await _createSavingsTables(database);
    }

    if (oldVersion < 4) {
      final loanColumns =
          await database.rawQuery('PRAGMA table_info(loans)');

      if (!loanColumns.any((c) => c['name'] == 'due_date')) {
        await database.execute(
          'ALTER TABLE loans ADD COLUMN due_date TEXT',
        );
      }

      final savingsColumns =
          await database.rawQuery('PRAGMA table_info(savings)');

      Future<void> addSavingsColumn(
        String name,
        String definition,
      ) async {
        if (!savingsColumns.any((c) => c['name'] == name)) {
          await database.execute(
            'ALTER TABLE savings ADD COLUMN $name $definition',
          );
        }
      }

      await addSavingsColumn('is_dps', 'INTEGER NOT NULL DEFAULT 0');
      await addSavingsColumn(
        'installment_amount',
        'REAL NOT NULL DEFAULT 0',
      );
      await addSavingsColumn('installment_frequency', 'TEXT');
      await addSavingsColumn('next_due_date', 'TEXT');
      await addSavingsColumn('maturity_date', 'TEXT');

      final stColumns = await database.rawQuery(
        'PRAGMA table_info(savings_transactions)',
      );

      if (!stColumns.any((c) => c['name'] == 'account_id')) {
        await database.execute(
          'ALTER TABLE savings_transactions ADD COLUMN account_id INTEGER',
        );
      }

      if (!stColumns.any(
        (c) => c['name'] == 'balance_effect_applied',
      )) {
        await database.execute('''
          ALTER TABLE savings_transactions
          ADD COLUMN balance_effect_applied
          INTEGER NOT NULL DEFAULT 0
        ''');
      }

      await _createBudgetTable(database);
    }

    // Existing version-5 databases may also need these columns.
    final transactionColumns =
        await database.rawQuery('PRAGMA table_info(transactions)');

    if (!transactionColumns.any((c) => c['name'] == 'savings_id')) {
      await database.execute(
        'ALTER TABLE transactions ADD COLUMN savings_id INTEGER',
      );
    }

    final savingsTransactionColumns = await database.rawQuery(
      'PRAGMA table_info(savings_transactions)',
    );

    if (savingsTransactionColumns.isNotEmpty &&
        !savingsTransactionColumns.any(
          (c) => c['name'] == 'linked_transaction_id',
        )) {
      await database.execute('''
        ALTER TABLE savings_transactions
        ADD COLUMN linked_transaction_id INTEGER
      ''');
    }

    await _createSavingsTables(database);
    await _createBudgetTable(database);
    await _createIndexes(database);
  }

  Future<void> _createSavingsTables(DatabaseExecutor executor) async {
    await executor.execute('''
      CREATE TABLE IF NOT EXISTS savings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL DEFAULT 0,
        note TEXT,
        is_dps INTEGER NOT NULL DEFAULT 0,
        installment_amount REAL NOT NULL DEFAULT 0,
        installment_frequency TEXT,
        next_due_date TEXT,
        maturity_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await executor.execute('''
      CREATE TABLE IF NOT EXISTS savings_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        savings_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        account_id INTEGER,
        balance_effect_applied INTEGER NOT NULL DEFAULT 0,
        linked_transaction_id INTEGER,
        FOREIGN KEY (savings_id)
          REFERENCES savings(id) ON DELETE CASCADE
      )
    ''');

    // Safe additions for databases created by older app versions.
    final columns = await executor.rawQuery(
      'PRAGMA table_info(savings_transactions)',
    );

    if (!columns.any((c) => c['name'] == 'account_id')) {
      await executor.execute(
        'ALTER TABLE savings_transactions ADD COLUMN account_id INTEGER',
      );
    }

    if (!columns.any(
      (c) => c['name'] == 'balance_effect_applied',
    )) {
      await executor.execute('''
        ALTER TABLE savings_transactions
        ADD COLUMN balance_effect_applied
        INTEGER NOT NULL DEFAULT 0
      ''');
    }

    if (!columns.any(
      (c) => c['name'] == 'linked_transaction_id',
    )) {
      await executor.execute('''
        ALTER TABLE savings_transactions
        ADD COLUMN linked_transaction_id INTEGER
      ''');
    }
  }

  Future<void> _createBudgetTable(DatabaseExecutor executor) async {
    await executor.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL,
        category_id INTEGER,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(month_key, category_id)
      )
    ''');
  }

  Future<void> _createIndexes(DatabaseExecutor executor) async {
    for (final sql in [
      'CREATE INDEX IF NOT EXISTS idx_transactions_date '
          'ON transactions(transaction_date)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_type '
          'ON transactions(type)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_category '
          'ON transactions(category_id)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_account '
          'ON transactions(account_id)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_loan '
          'ON transactions(loan_id)',
      'CREATE INDEX IF NOT EXISTS idx_loans_type ON loans(type)',
      'CREATE INDEX IF NOT EXISTS idx_savings_transactions_date '
          'ON savings_transactions(transaction_date)',
      'CREATE INDEX IF NOT EXISTS idx_savings_transactions_savings '
          'ON savings_transactions(savings_id)',
      'CREATE INDEX IF NOT EXISTS idx_budgets_month ON budgets(month_key)',
    ]) {
      await executor.execute(sql);
    }
  }

  Future<void> _insertDefaultAccounts(Database database) async {
    final now = DateTime.now().toIso8601String();

    final accounts = [
      {
        'name': 'Cash',
        'type': 'cash',
        'icon': 0xe88a,
        'color': 0xFF176B45,
      },
      {
        'name': 'Bkash',
        'type': 'bkash',
        'icon': 0xe0b0,
        'color': 0xFFE91E63,
      },
      {
        'name': 'Nagad',
        'type': 'nagad',
        'icon': 0xe8a6,
        'color': 0xFFFF9800,
      },
      {
        'name': 'Bank Account',
        'type': 'bank',
        'icon': 0xe84f,
        'color': 0xFF2196F3,
      },
      {
        'name': 'Card',
        'type': 'card',
        'icon': 0xe870,
        'color': 0xFF9C27B0,
      },
    ];

    for (final account in accounts) {
      await database.insert('accounts', {
        ...account,
        'balance': 0.0,
        'is_default': 1,
        'created_at': now,
      });
    }
  }

  Future<void> _insertDefaultCategories(Database database) async {
    final now = DateTime.now().toIso8601String();

    final income = [
      {'name': 'Salary', 'icon': 0xe850, 'color': 0xFF176B45},
      {'name': 'Business', 'icon': 0xe8f6, 'color': 0xFF2196F3},
      {'name': 'Bonus', 'icon': 0xe8b6, 'color': 0xFFFF9800},
      {'name': 'Other Income', 'icon': 0xe145, 'color': 0xFF9C27B0},
    ];

    final expense = [
      {'name': 'Food', 'icon': 0xe56c, 'color': 0xFFFF7043},
      {'name': 'Shopping', 'icon': 0xe8cc, 'color': 0xFFE91E63},
      {'name': 'Transport', 'icon': 0xe531, 'color': 0xFF2196F3},
      {'name': 'Rent', 'icon': 0xe88a, 'color': 0xFF9C27B0},
      {'name': 'Bills', 'icon': 0xe8a1, 'color': 0xFFFF9800},
      {'name': 'Medical', 'icon': 0xe3f3, 'color': 0xFFF44336},
      {'name': 'Education', 'icon': 0xe80c, 'color': 0xFF3F51B5},
      {'name': 'Family', 'icon': 0xe7ef, 'color': 0xFF009688},
      {'name': 'Other Expense', 'icon': 0xe145, 'color': 0xFF607D8B},
    ];

    for (final category in income) {
      await database.insert('categories', {
        ...category,
        'type': 'income',
        'is_default': 1,
        'created_at': now,
      });
    }

    for (final category in expense) {
      await database.insert('categories', {
        ...category,
        'type': 'expense',
        'is_default': 1,
        'created_at': now,
      });
    }
  }

  // ACCOUNTS

  Future<List<Map<String, dynamic>>> getAccounts() => db.query(
        'accounts',
        orderBy: 'is_default DESC, id ASC',
      );

  Future<Map<String, dynamic>?> getAccount(int id) async {
    final rows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<int> addAccount({
    required String name,
    required String type,
    double balance = 0,
    int? icon,
    int? color,
  }) {
    return db.insert('accounts', {
      'name': name.trim(),
      'type': type,
      'balance': balance,
      'icon': icon,
      'color': color,
      'is_default': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateAccount(
    int id, {
    required String name,
    required String type,
    double? balance,
    int? icon,
    int? color,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'type': type,
      'icon': icon,
      'color': color,
    };

    if (balance != null) data['balance'] = balance;

    return db.update(
      'accounts',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final account = await getAccount(id);
    if (account == null) return 0;

    if ((account['is_default'] as int? ?? 0) == 1) {
      throw Exception('Default accounts cannot be deleted.');
    }

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS total FROM transactions
      WHERE account_id = ?
         OR from_account_id = ?
         OR to_account_id = ?
    ''', [id, id, id]);

    if ((result.first['total'] as num).toInt() > 0) {
      throw Exception(
        'This account has transactions and cannot be deleted.',
      );
    }

    final savingsResult = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM savings_transactions
      WHERE account_id = ?
    ''', [id]);

    if ((savingsResult.first['total'] as num).toInt() > 0) {
      throw Exception(
        'This account has savings records and cannot be deleted.',
      );
    }

    return db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CATEGORIES

  Future<List<Map<String, dynamic>>> getCategories({
    String? type,
  }) {
    if (type == null) {
      return db.query(
        'categories',
        orderBy: 'is_default DESC, id ASC',
      );
    }

    return db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'is_default DESC, id ASC',
    );
  }

  Future<Map<String, dynamic>?> getCategory(int id) async {
    final rows = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<int> addCategory({
    required String name,
    required String type,
    int? icon,
    int? color,
  }) {
    return db.insert('categories', {
      'name': name.trim(),
      'type': type,
      'icon': icon,
      'color': color,
      'is_default': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateCategory(
    int id, {
    required String name,
    int? icon,
    int? color,
  }) {
    return db.update(
      'categories',
      {
        'name': name.trim(),
        'icon': icon,
        'color': color,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final category = await getCategory(id);
    if (category == null) return 0;

    if ((category['is_default'] as int? ?? 0) == 1) {
      throw Exception('Default categories cannot be deleted.');
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM transactions WHERE category_id = ?',
      [id],
    );

    if ((result.first['total'] as num).toInt() > 0) {
      throw Exception(
        'This category has transactions and cannot be deleted.',
      );
    }

    return db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Ensures an Expense category exists for Savings/DPS contributions.
  Future<int> ensureSavingsCategoryId() async {
    final rows = await db.query(
      'categories',
      where: "type = 'expense' AND name IN (?, ?)",
      whereArgs: ['Savings', 'সঞ্চয়'],
      orderBy: "CASE WHEN name = 'Savings' THEN 0 ELSE 1 END",
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return (rows.first['id'] as num).toInt();
    }

    return db.insert('categories', {
      'name': 'Savings',
      'type': 'expense',
      'icon': 0xe8e5,
      'color': 0xFFC9A45C,
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

    // TRANSACTIONS

  Future<int> addTransaction({
    required String type,
    required double amount,
    int? categoryId,
    int? accountId,
    int? fromAccountId,
    int? toAccountId,
    int? loanId,
    String? note,
    required DateTime transactionDate,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be greater than zero.');
    }

    if ([
      'loan_given',
      'loan_taken',
      'loan_received',
      'loan_paid',
    ].contains(type)) {
      throw Exception('Please use the dedicated loan functions.');
    }

    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      final id = await txn.insert('transactions', {
        'type': type,
        'amount': amount,
        'category_id': categoryId,
        'account_id': accountId,
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'loan_id': loanId,
        'savings_id': null,
        'note': note?.trim() ?? '',
        'transaction_date': transactionDate.toIso8601String(),
        'created_at': now,
        'updated_at': now,
      });

      await _recalculateAllAccountBalances(txn);
      await _recalculateAllLoanBalances(txn);
      return id;
    });
  }

  /// Adds one Expense and one linked Savings deposit atomically.
  /// The account balance is reduced only by the Expense transaction.
  Future<int> addSavingsContribution({
    required int savingsId,
    required double amount,
    required int accountId,
    required int categoryId,
    String? note,
    required DateTime transactionDate,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be greater than zero.');
    }

    return db.transaction((txn) async {
      final savings = await txn.query(
        'savings',
        where: 'id = ?',
        whereArgs: [savingsId],
        limit: 1,
      );

      if (savings.isEmpty) {
        throw Exception('Savings record not found.');
      }

      final accounts = await txn.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );

      if (accounts.isEmpty) {
        throw Exception('Account not found.');
      }

      final categories = await txn.query(
        'categories',
        where: 'id = ? AND type = ?',
        whereArgs: [categoryId, 'expense'],
        limit: 1,
      );

      if (categories.isEmpty) {
        throw Exception('Expense category not found.');
      }

      final now = DateTime.now().toIso8601String();
      final cleanNote = note?.trim() ?? '';

      final transactionId = await txn.insert('transactions', {
        'type': 'expense',
        'amount': amount,
        'category_id': categoryId,
        'account_id': accountId,
        'from_account_id': null,
        'to_account_id': null,
        'loan_id': null,
        'savings_id': savingsId,
        'note': cleanNote,
        'transaction_date': transactionDate.toIso8601String(),
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('savings_transactions', {
        'savings_id': savingsId,
        'type': 'deposit',
        'amount': amount,
        'note': cleanNote,
        'transaction_date': transactionDate.toIso8601String(),
        'created_at': now,
        'account_id': accountId,
        'balance_effect_applied': 0,
        'linked_transaction_id': transactionId,
      });

      await txn.update(
        'savings',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [savingsId],
      );

      await _recalculateAllAccountBalances(txn);
      await _recalculateAllLoanBalances(txn);
      return transactionId;
    });
  }

  Future<int> updateTransaction(
    int id, {
    required String type,
    required double amount,
    int? categoryId,
    int? accountId,
    int? fromAccountId,
    int? toAccountId,
    int? loanId,
    String? note,
    required DateTime transactionDate,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be greater than zero.');
    }

    return db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw Exception('Transaction not found.');
      }

      final old = rows.first;
      final oldType = old['type'].toString();
      final oldLoanId = (old['loan_id'] as num?)?.toInt();
      final oldSavingsId = (old['savings_id'] as num?)?.toInt();

      final loanTypes = [
        'loan_given',
        'loan_taken',
        'loan_received',
        'loan_paid',
      ];

      if (oldSavingsId != null) {
        throw Exception(
          'Savings contribution must be edited from the Savings screen '
          'or deleted and entered again.',
        );
      }

      if (loanTypes.contains(oldType)) {
        if (oldLoanId == null) {
          throw Exception('Loan information is missing.');
        }

        if (type != oldType) {
          throw Exception('Loan transaction type cannot be changed.');
        }

        final loans = await txn.query(
          'loans',
          where: 'id = ?',
          whereArgs: [oldLoanId],
          limit: 1,
        );

        if (loans.isEmpty) {
          throw Exception('Related loan not found.');
        }

        final loan = loans.first;
        final repaymentType = loan['type'] == 'receivable'
            ? 'loan_received'
            : 'loan_paid';

        final sums = await txn.rawQuery('''
          SELECT COALESCE(SUM(amount), 0) AS total
          FROM transactions
          WHERE loan_id = ? AND type = ? AND id != ?
        ''', [oldLoanId, repaymentType, id]);

        final otherRepayments =
            (sums.first['total'] as num).toDouble();

        if (oldType == 'loan_given' || oldType == 'loan_taken') {
          if (amount < otherRepayments) {
            throw Exception(
              'Loan amount cannot be less than amount already repaid.',
            );
          }

          await txn.update(
            'loans',
            {
              'principal': amount,
              'note': note?.trim() ?? '',
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [oldLoanId],
          );
        } else {
          final principal = (loan['principal'] as num).toDouble();

          if (otherRepayments + amount > principal) {
            throw Exception(
              'Total repayment cannot exceed the loan amount.',
            );
          }
        }

        await txn.update(
          'transactions',
          {
            'amount': amount,
            'category_id': null,
            'account_id': accountId,
            'from_account_id': null,
            'to_account_id': null,
            'loan_id': oldLoanId,
            'note': note?.trim() ?? '',
            'transaction_date': transactionDate.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        if (loanTypes.contains(type)) {
          throw Exception('Please use the dedicated loan option.');
        }

        await txn.update(
          'transactions',
          {
            'type': type,
            'amount': amount,
            'category_id': categoryId,
            'account_id': accountId,
            'from_account_id': fromAccountId,
            'to_account_id': toAccountId,
            'loan_id': loanId,
            'note': note?.trim() ?? '',
            'transaction_date': transactionDate.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      await _recalculateAllAccountBalances(txn);
      await _recalculateAllLoanBalances(txn);
      return 1;
    });
  }

  Future<int> deleteTransaction(int id) async {
    return db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (rows.isEmpty) return 0;

      final row = rows.first;
      final type = row['type'].toString();
      final loanId = (row['loan_id'] as num?)?.toInt();

      if (loanId != null &&
          (type == 'loan_given' || type == 'loan_taken')) {
        final result = await txn.rawQuery('''
          SELECT COUNT(*) AS total
          FROM transactions
          WHERE loan_id = ?
            AND type IN ('loan_received', 'loan_paid')
        ''', [loanId]);

        if ((result.first['total'] as num).toInt() > 0) {
          throw Exception(
            'Delete repayment records before deleting this loan.',
          );
        }

        await txn.delete(
          'loans',
          where: 'id = ?',
          whereArgs: [loanId],
        );
      }

      // Remove the matching Savings history if this was a contribution.
      final linkedSavingsRecords = await txn.query(
        'savings_transactions',
        where: 'linked_transaction_id = ?',
        whereArgs: [id],
      );

      for (final savingsRecord in linkedSavingsRecords) {
        await txn.delete(
          'savings_transactions',
          where: 'id = ?',
          whereArgs: [savingsRecord['id']],
        );
      }

      final deleted = await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );

      await _recalculateAllAccountBalances(txn);
      await _recalculateAllLoanBalances(txn);
      return deleted;
    });
  }

  Future<Map<String, dynamic>?> getTransaction(int id) async {
    final rows = await db.rawQuery('''
      SELECT t.*, c.name AS category_name, c.type AS category_type,
        a.name AS account_name, fa.name AS from_account_name,
        ta.name AS to_account_name, l.person_name AS loan_person_name,
        l.type AS loan_type, l.principal AS loan_principal,
        l.remaining AS loan_remaining
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN accounts fa ON fa.id = t.from_account_id
      LEFT JOIN accounts ta ON ta.id = t.to_account_id
      LEFT JOIN loans l ON l.id = t.loan_id
      WHERE t.id = ?
      LIMIT 1
    ''', [id]);

    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getTransactions({
    String? type,
    int? categoryId,
    int? accountId,
    int? loanId,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
  }) async {
    final where = <String>[];
    final args = <dynamic>[];

    if (type != null && type.isNotEmpty && type != 'all') {
      where.add('t.type = ?');
      args.add(type);
    }

    if (categoryId != null) {
      where.add('t.category_id = ?');
      args.add(categoryId);
    }

    if (accountId != null) {
      where.add(
        '(t.account_id = ? OR t.from_account_id = ? OR t.to_account_id = ?)',
      );
      args.addAll([accountId, accountId, accountId]);
    }

    if (loanId != null) {
      where.add('t.loan_id = ?');
      args.add(loanId);
    }

    if (startDate != null) {
      where.add('t.transaction_date >= ?');
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where.add('t.transaction_date <= ?');
      args.add(endDate.toIso8601String());
    }

    if (search != null && search.trim().isNotEmpty) {
      where.add('''
        (t.note LIKE ? OR c.name LIKE ? OR a.name LIKE ?
         OR fa.name LIKE ? OR ta.name LIKE ? OR l.person_name LIKE ?)
      ''');
      args.addAll(List.filled(6, '%${search.trim()}%'));
    }

    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    return db.rawQuery('''
      SELECT t.*, c.name AS category_name, c.type AS category_type,
        a.name AS account_name, fa.name AS from_account_name,
        ta.name AS to_account_name, l.person_name AS loan_person_name,
        l.type AS loan_type, l.remaining AS loan_remaining
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN accounts fa ON fa.id = t.from_account_id
      LEFT JOIN accounts ta ON ta.id = t.to_account_id
      LEFT JOIN loans l ON l.id = t.loan_id
      $clause
      ORDER BY t.transaction_date DESC, t.id DESC
    ''', args);
  }

  // LOANS

  Future<int> createLoan({
    required String personName,
    required String type,
    required double amount,
    required int accountId,
    String? note,
    required DateTime transactionDate,
    DateTime? dueDate,
  }) async {
    if (personName.trim().isEmpty) {
      throw Exception('Person name is required.');
    }

    if (amount <= 0) {
      throw Exception('Loan amount must be greater than zero.');
    }

    if (!['receivable', 'payable'].contains(type)) {
      throw Exception('Loan type must be receivable or payable.');
    }

    if (await getAccount(accountId) == null) {
      throw Exception('Account not found.');
    }

    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      final loanId = await txn.insert('loans', {
        'person_name': personName.trim(),
        'type': type,
        'principal': amount,
        'remaining': amount,
        'note': note?.trim() ?? '',
        'due_date': dueDate?.toIso8601String(),
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('transactions', {
        'type': type == 'receivable' ? 'loan_given' : 'loan_taken',
        'amount': amount,
        'category_id': null,
        'account_id': accountId,
        'from_account_id': null,
        'to_account_id': null,
        'loan_id': loanId,
        'savings_id': null,
        'note': note?.trim() ?? '',
        'transaction_date': transactionDate.toIso8601String(),
        'created_at': now,
        'updated_at': now,
      });

      await _recalculateAllAccountBalances(txn);
      await _recalculateAllLoanBalances(txn);
      return loanId;
    });
  }

  Future<int> updateLoanDueDate(
    int loanId,
    DateTime? dueDate,
  ) {
    return db.update(
      'loans',
      {
        'due_date': dueDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [loanId],
    );
  }

  Future<int> addLoanRepayment({
    required int loanId,
    required double amount,
    required int accountId,
    String? note,
    required DateTime transactionDate,
  }) async {
    if (amount <= 0) {
      throw Exception('Repayment amount must be greater than zero.');
    }

    if (await getAccount(accountId) == null) {
      throw Exception('Account not found.');
    }

    return db.transaction((txn) async {
      final rows = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [loanId],
        limit: 1,
      );

      if (rows.isEmpty) throw Exception('Loan not found.');

      final loan = rows.first;
      final remaining = (loan['remaining'] as num).toDouble();

      if (remaining <= 0) {
        throw Exception('This loan is already completed.');
      }

      if (amount > remaining) {
        throw Exception('Repayment cannot exceed the remaining amount.');
      }

      final type = loan['type'] == 'receivable'
          ? 'loan_received'
          : 'loan_paid';

      final now = DateTime.now().toIso8601String();

      final id = await txn.insert('transactions', {
        'type': type,
        'amount': amount,
        'category_id': null,
        'account_id': accountId,
        'from_account_id': null,
        'to_account_id': null,
        'loan_id': loanId,
        'savings_id': null,
        'note': note?.trim() ?? '',
        'transaction_date': transactionDate.toIso8601String(),
        'created_at': now,
        'updated_at': now,
      });

      await _recalculateAllAccountBalances(txn);
      await _recalculateAllLoanBalances(txn);
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> getLoans({
    String? type,
    bool activeOnly = false,
  }) async {
    final where = <String>[];
    final args = <dynamic>[];

    if (type != null && type.isNotEmpty && type != 'all') {
      where.add('type = ?');
      args.add(type);
    }

    if (activeOnly) where.add('remaining > 0');

    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    return db.rawQuery(
      'SELECT * FROM loans $clause ORDER BY remaining DESC, id DESC',
      args,
    );
  }

  Future<Map<String, dynamic>?> getLoan(int id) async {
    final rows = await db.query(
      'loans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<double> getTotalReceivable() async {
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining), 0) AS total
      FROM loans
      WHERE type = 'receivable' AND remaining > 0
    ''');

    return (rows.first['total'] as num).toDouble();
  }

  Future<double> getTotalPayable() async {
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining), 0) AS total
      FROM loans
      WHERE type = 'payable' AND remaining > 0
    ''');

    return (rows.first['total'] as num).toDouble();
  }

  Future<Map<String, double>> getLoanTotals() async {
    final receivable = await getTotalReceivable();
    final payable = await getTotalPayable();

    return {
      'receivable': receivable,
      'payable': payable,
      'net': receivable - payable,
    };
  }

  Future<List<Map<String, dynamic>>> getLoanTransactions(int loanId) {
    return getTransactions(loanId: loanId);
  }

  // SAVINGS CRUD

  Future<int> addSavings({
    required String name,
    double targetAmount = 0,
    String? note,
    bool isDps = false,
    double installmentAmount = 0,
    String? installmentFrequency,
    DateTime? nextDueDate,
    DateTime? maturityDate,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('Savings name is required.');
    }

    if (targetAmount < 0 || installmentAmount < 0) {
      throw Exception('Amounts cannot be negative.');
    }

    final now = DateTime.now().toIso8601String();

    return db.insert('savings', {
      'name': name.trim(),
      'target_amount': targetAmount,
      'note': note?.trim() ?? '',
      'is_dps': isDps ? 1 : 0,
      'installment_amount': installmentAmount,
      'installment_frequency': installmentFrequency,
      'next_due_date': nextDueDate?.toIso8601String(),
      'maturity_date': maturityDate?.toIso8601String(),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getSavings() {
    return db.rawQuery('''
      SELECT s.*,
        COALESCE(SUM(
          CASE
            WHEN st.type = 'deposit' THEN st.amount
            WHEN st.type = 'withdrawal' THEN -st.amount
            ELSE 0
          END
        ), 0) AS current_amount
      FROM savings s
      LEFT JOIN savings_transactions st ON st.savings_id = s.id
      GROUP BY s.id
      ORDER BY s.id DESC
    ''');
  }

  Future<Map<String, dynamic>?> getSaving(int id) async {
    final rows = await db.rawQuery('''
      SELECT s.*,
        COALESCE(SUM(
          CASE
            WHEN st.type = 'deposit' THEN st.amount
            WHEN st.type = 'withdrawal' THEN -st.amount
            ELSE 0
          END
        ), 0) AS current_amount
      FROM savings s
      LEFT JOIN savings_transactions st ON st.savings_id = s.id
      WHERE s.id = ?
      GROUP BY s.id
      LIMIT 1
    ''', [id]);

    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updateSaving({
    required int id,
    required String name,
    required double targetAmount,
    String? note,
    bool? isDps,
    double? installmentAmount,
    String? installmentFrequency,
    DateTime? nextDueDate,
    DateTime? maturityDate,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('Savings name is required.');
    }

    if (targetAmount < 0 || (installmentAmount ?? 0) < 0) {
      throw Exception('Amounts cannot be negative.');
    }

    final data = <String, dynamic>{
      'name': name.trim(),
      'target_amount': targetAmount,
      'note': note?.trim() ?? '',
      'updated_at': DateTime.now().toIso8601String(),
      'next_due_date': nextDueDate?.toIso8601String(),
      'maturity_date': maturityDate?.toIso8601String(),
    };

    if (isDps != null) data['is_dps'] = isDps ? 1 : 0;

    if (installmentAmount != null) {
      data['installment_amount'] = installmentAmount;
    }

    if (installmentFrequency != null) {
      data['installment_frequency'] = installmentFrequency;
    }

    return db.update(
      'savings',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSaving(int id) async {
    return db.transaction((txn) async {
      final records = await txn.query(
        'savings_transactions',
        where: 'savings_id = ?',
        whereArgs: [id],
      );

      for (final record in records) {
        final linkedId =
            (record['linked_transaction_id'] as num?)?.toInt();

        if (linkedId != null) {
          await txn.delete(
            'transactions',
            where: 'id = ?',
            whereArgs: [linkedId],
          );
          continue;
        }

        // Reverse only account effects that were applied by older records.
        if ((record['balance_effect_applied'] as num? ?? 0).toInt() != 1) {
          continue;
        }

        final accountId = (record['account_id'] as num?)?.toInt();
        if (accountId == null) continue;

        final accounts = await txn.query(
          'accounts',
          columns: ['balance'],
          where: 'id = ?',
          whereArgs: [accountId],
          limit: 1,
        );

        if (accounts.isEmpty) continue;

        final balance = (accounts.first['balance'] as num).toDouble();
        final amount = (record['amount'] as num).toDouble();

        final updated = record['type'] == 'deposit'
            ? balance + amount
            : balance - amount;

        await txn.update(
          'accounts',
          {'balance': updated},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      }

      await txn.delete(
        'savings_transactions',
        where: 'savings_id = ?',
        whereArgs: [id],
      );

      final deleted = await txn.delete(
        'savings',
        where: 'id = ?',
        whereArgs: [id],
      );

      await _recalculateAllAccountBalances(txn);
      await _recalculateAllLoanBalances(txn);
      return deleted;
    });
  }
    // SAVINGS DEPOSIT / WITHDRAWAL

  Future<int> addSavingsTransaction({
    required int savingsId,
    required String type,
    required double amount,
    String? note,
    DateTime? transactionDate,
    int? accountId,
  }) async {
    if (!['deposit', 'withdrawal'].contains(type)) {
      throw Exception('Type must be deposit or withdrawal.');
    }

    if (amount <= 0) {
      throw Exception('Amount must be greater than zero.');
    }

    return db.transaction((txn) async {
      final savings = await txn.query(
        'savings',
        where: 'id = ?',
        whereArgs: [savingsId],
        limit: 1,
      );

      if (savings.isEmpty) {
        throw Exception('Savings record not found.');
      }

      if (accountId != null) {
        final accounts = await txn.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [accountId],
          limit: 1,
        );

        if (accounts.isEmpty) {
          throw Exception('Account not found.');
        }
      }

      final balanceRows = await txn.rawQuery('''
        SELECT COALESCE(SUM(
          CASE
            WHEN type = 'deposit' THEN amount
            WHEN type = 'withdrawal' THEN -amount
            ELSE 0
          END
        ), 0) AS total
        FROM savings_transactions
        WHERE savings_id = ?
      ''', [savingsId]);

      final currentSavings =
          (balanceRows.first['total'] as num).toDouble();

      if (type == 'withdrawal' && amount > currentSavings) {
        throw Exception('Withdrawal cannot exceed current savings.');
      }

      final now = DateTime.now().toIso8601String();

      await txn.insert('savings_transactions', {
        'savings_id': savingsId,
        'type': type,
        'amount': amount,
        'note': note?.trim() ?? '',
        'transaction_date':
            (transactionDate ?? DateTime.now()).toIso8601String(),
        'created_at': now,
        'account_id': accountId,
        'balance_effect_applied': accountId == null ? 0 : 1,
        'linked_transaction_id': null,
      });

      // Legacy/direct Savings transactions keep their existing behavior.
      if (accountId != null) {
        final accountRows = await txn.query(
          'accounts',
          columns: ['balance'],
          where: 'id = ?',
          whereArgs: [accountId],
          limit: 1,
        );

        final balance =
            (accountRows.first['balance'] as num).toDouble();

        final updated = type == 'deposit'
            ? balance - amount
            : balance + amount;

        await txn.update(
          'accounts',
          {'balance': updated},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      }

      await txn.update(
        'savings',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [savingsId],
      );

      return 1;
    });
  }

  Future<List<Map<String, dynamic>>> getSavingsTransactions(
    int savingsId,
  ) {
    return db.query(
      'savings_transactions',
      where: 'savings_id = ?',
      whereArgs: [savingsId],
      orderBy: 'transaction_date DESC, id DESC',
    );
  }

  Future<int> deleteSavingsTransaction(int id) async {
    return db.transaction((txn) async {
      final rows = await txn.query(
        'savings_transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (rows.isEmpty) return 0;

      final row = rows.first;
      final linkedId =
          (row['linked_transaction_id'] as num?)?.toInt();

      if (linkedId != null) {
        await txn.delete(
          'transactions',
          where: 'id = ?',
          whereArgs: [linkedId],
        );

        final deleted = await txn.delete(
          'savings_transactions',
          where: 'id = ?',
          whereArgs: [id],
        );

        await _recalculateAllAccountBalances(txn);
        await _recalculateAllLoanBalances(txn);
        return deleted;
      }

      if ((row['balance_effect_applied'] as num? ?? 0).toInt() == 1) {
        final accountId = (row['account_id'] as num?)?.toInt();

        if (accountId != null) {
          final accounts = await txn.query(
            'accounts',
            columns: ['balance'],
            where: 'id = ?',
            whereArgs: [accountId],
            limit: 1,
          );

          if (accounts.isNotEmpty) {
            final balance =
                (accounts.first['balance'] as num).toDouble();
            final amount = (row['amount'] as num).toDouble();

            final updated = row['type'] == 'deposit'
                ? balance + amount
                : balance - amount;

            await txn.update(
              'accounts',
              {'balance': updated},
              where: 'id = ?',
              whereArgs: [accountId],
            );
          }
        }
      }

      return txn.delete(
        'savings_transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<double> getTotalSavings() async {
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN type = 'deposit' THEN amount
          WHEN type = 'withdrawal' THEN -amount
          ELSE 0
        END
      ), 0) AS total
      FROM savings_transactions
    ''');

    return (rows.first['total'] as num).toDouble();
  }

  // BUDGETS

  // monthKey format: YYYY-MM.
  // categoryId = null means the total monthly budget.

  String _monthKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}';
  }

  Future<int> setBudget({
    required DateTime month,
    int? categoryId,
    required double amount,
  }) async {
    if (amount < 0) {
      throw Exception('Budget cannot be negative.');
    }

    if (categoryId != null) {
      final category = await getCategory(categoryId);

      if (category == null || category['type'] != 'expense') {
        throw Exception('Select a valid expense category.');
      }
    }

    final key = _monthKey(month);
    final now = DateTime.now().toIso8601String();

    return db.insert(
      'budgets',
      {
        'month_key': key,
        'category_id': categoryId,
        'amount': amount,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getBudgets({
    DateTime? month,
  }) async {
    final key = _monthKey(month ?? DateTime.now());

    return db.rawQuery('''
      SELECT b.*, c.name AS category_name,
        COALESCE((
          SELECT SUM(t.amount)
          FROM transactions t
          WHERE t.type = 'expense'
            AND strftime('%Y-%m', t.transaction_date) = b.month_key
            AND (
              (b.category_id IS NULL AND t.category_id IS NOT NULL)
              OR t.category_id = b.category_id
            )
        ), 0) AS spent
      FROM budgets b
      LEFT JOIN categories c ON c.id = b.category_id
      WHERE b.month_key = ?
      ORDER BY b.category_id IS NOT NULL, c.name
    ''', [key]);
  }

  Future<int> deleteBudget(int id) {
    return db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>> getBudgetStatus(
    DateTime month,
  ) async {
    final key = _monthKey(month);
    final budgets = await getBudgets(month: month);

    final overall =
        budgets.where((b) => b['category_id'] == null).toList();
    final categories =
        budgets.where((b) => b['category_id'] != null).toList();

    final totalBudget = overall.isEmpty
        ? 0.0
        : (overall.first['amount'] as num).toDouble();

    final totalSpent = await getTotalExpense(
      startDate: DateTime(month.year, month.month, 1),
      endDate: DateTime(
        month.year,
        month.month + 1,
        1,
      ).subtract(const Duration(microseconds: 1)),
    );

    final categoryStatuses = <Map<String, dynamic>>[];

    for (final budgetRow in categories) {
      final budget = (budgetRow['amount'] as num).toDouble();
      final spent = (budgetRow['spent'] as num).toDouble();

      categoryStatuses.add({
        ...budgetRow,
        'remaining': budget - spent,
        'percentage':
            budget == 0 ? (spent > 0 ? 1.0 : 0.0) : spent / budget,
        'status': budget > 0 && spent >= budget
            ? 'exceeded'
            : budget > 0 && spent >= budget * .8
                ? 'warning'
                : 'normal',
      });
    }

    return {
      'month_key': key,
      'budget': totalBudget,
      'spent': totalSpent,
      'remaining': totalBudget - totalSpent,
      'percentage': totalBudget == 0
          ? (totalSpent > 0 ? 1.0 : 0.0)
          : totalSpent / totalBudget,
      'status': totalBudget > 0 && totalSpent >= totalBudget
          ? 'exceeded'
          : totalBudget > 0 && totalSpent >= totalBudget * .8
              ? 'warning'
              : 'normal',
      'categories': categoryStatuses,
    };
  }

  // LOAN / DPS REMINDER DATA

  Future<List<Map<String, dynamic>>> getLoansDueForReminder({
    int daysAhead = 7,
  }) async {
    final today = DateTime.now();
    final end = today.add(Duration(days: daysAhead));

    return db.rawQuery('''
      SELECT * FROM loans
      WHERE remaining > 0
        AND due_date IS NOT NULL
        AND date(due_date) <= date(?)
      ORDER BY date(due_date)
    ''', [end.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getDpsDueForReminder({
    int daysAhead = 7,
  }) async {
    final end = DateTime.now().add(Duration(days: daysAhead));

    return db.rawQuery('''
      SELECT s.* FROM savings s
      WHERE s.is_dps = 1
        AND s.installment_amount > 0
        AND s.next_due_date IS NOT NULL
        AND date(s.next_due_date) <= date(?)
      ORDER BY date(s.next_due_date)
    ''', [end.toIso8601String()]);
  }
    // RECALCULATE LOAN BALANCES

  Future<void> _recalculateAllLoanBalances(
    DatabaseExecutor executor,
  ) async {
    final loans = await executor.query('loans');

    for (final loan in loans) {
      final id = (loan['id'] as num).toInt();
      final principal = (loan['principal'] as num).toDouble();

      final repaymentType = loan['type'] == 'receivable'
          ? 'loan_received'
          : 'loan_paid';

      final result = await executor.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM transactions
        WHERE loan_id = ? AND type = ?
      ''', [id, repaymentType]);

      final repaid = (result.first['total'] as num).toDouble();

      await executor.update(
        'loans',
        {
          'remaining':
              (principal - repaid).clamp(0.0, double.infinity),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // RECALCULATE ACCOUNT BALANCES
  //
  // New Savings/DPS contributions are represented by an Expense
  // transaction. Their linked Savings history has
  // balance_effect_applied=0, so it is never deducted twice.

  Future<void> _recalculateAllAccountBalances(
    DatabaseExecutor executor,
  ) async {
    final accounts = await executor.query('accounts');

    for (final account in accounts) {
      final id = (account['id'] as num).toInt();

      Future<double> sum(
        String sql,
        List<dynamic> args,
      ) async {
        final rows = await executor.rawQuery(sql, args);
        return (rows.first['total'] as num?)?.toDouble() ?? 0;
      }

      final income = await sum(
        "SELECT COALESCE(SUM(amount), 0) total "
        "FROM transactions WHERE type = 'income' AND account_id = ?",
        [id],
      );

      final expense = await sum(
        "SELECT COALESCE(SUM(amount), 0) total "
        "FROM transactions WHERE type = 'expense' AND account_id = ?",
        [id],
      );

      final transferIn = await sum(
        "SELECT COALESCE(SUM(amount), 0) total "
        "FROM transactions WHERE type = 'transfer' AND to_account_id = ?",
        [id],
      );

      final transferOut = await sum(
        "SELECT COALESCE(SUM(amount), 0) total "
        "FROM transactions WHERE type = 'transfer' AND from_account_id = ?",
        [id],
      );

      final loanGiven = await sum(
        "SELECT COALESCE(SUM(amount), 0) total "
        "FROM transactions WHERE type = 'loan_given' AND account_id = ?",
        [id],
      );

      final loanTaken = await sum(
        "SELECT COALESCE(SUM(amount), 0) total "
        "FROM transactions WHERE type = 'loan_taken' AND account_id = ?",
        [id],
      );

      final loanReceived = await sum(
        "SELECT COALESCE(SUM(amount), 0) total "
        "FROM transactions WHERE type = 'loan_received' AND account_id = ?",
        [id],
      );

      final loanPaid = await sum(
        "SELECT COALESCE(SUM(amount), 0) total "
        "FROM transactions WHERE type = 'loan_paid' AND account_id = ?",
        [id],
      );

      final savingsDeposits = await sum(
        "SELECT COALESCE(SUM(amount), 0) total "
        "FROM savings_transactions "
        "WHERE account_id = ? AND type = 'deposit' "
        "AND balance_effect_applied = 1",
        [id],
      );

      final savingsWithdrawals = await sum(
        "SELECT COALESCE(SUM(amount), 0) total "
        "FROM savings_transactions "
        "WHERE account_id = ? AND type = 'withdrawal' "
        "AND balance_effect_applied = 1",
        [id],
      );

      final balance = income -
          expense +
          transferIn -
          transferOut -
          loanGiven +
          loanTaken +
          loanReceived -
          loanPaid -
          savingsDeposits +
          savingsWithdrawals;

      await executor.update(
        'accounts',
        {'balance': balance},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> recalculateBalances() async {
    await db.transaction((txn) async {
      await _recalculateAllAccountBalances(txn);
      await _recalculateAllLoanBalances(txn);
    });
  }

  // TOTALS

  Future<double> getTotalBalance() async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(balance), 0) AS total FROM accounts',
    );

    return (rows.first['total'] as num).toDouble();
  }

  Future<double> getTotalIncome({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final where = <String>["type = 'income'"];
    final args = <dynamic>[];

    if (startDate != null) {
      where.add('transaction_date >= ?');
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where.add('transaction_date <= ?');
      args.add(endDate.toIso8601String());
    }

    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM transactions WHERE ${where.join(' AND ')}',
      args,
    );

    return (rows.first['total'] as num).toDouble();
  }

  Future<double> getTotalExpense({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final where = <String>["type = 'expense'"];
    final args = <dynamic>[];

    if (startDate != null) {
      where.add('transaction_date >= ?');
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where.add('transaction_date <= ?');
      args.add(endDate.toIso8601String());
    }

    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM transactions WHERE ${where.join(' AND ')}',
      args,
    );

    return (rows.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getIncomeByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _getCategoryTotals(
      type: 'income',
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<Map<String, dynamic>>> getExpenseByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _getCategoryTotals(
      type: 'expense',
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<Map<String, dynamic>>> _getCategoryTotals({
    required String type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final dateConditions = <String>[];
    final args = <dynamic>[type];

    if (startDate != null) {
      dateConditions.add('t.transaction_date >= ?');
      args.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      dateConditions.add('t.transaction_date <= ?');
      args.add(endDate.toIso8601String());
    }

    final dateSql = dateConditions.isEmpty
        ? ''
        : ' AND ${dateConditions.join(' AND ')}';

    args.add(type);

    return db.rawQuery('''
      SELECT c.id, c.name, c.type, c.icon, c.color,
        COALESCE(SUM(t.amount), 0) AS total
      FROM categories c
      LEFT JOIN transactions t
        ON t.category_id = c.id
        AND t.type = ? $dateSql
      WHERE c.type = ?
      GROUP BY c.id, c.name, c.type, c.icon, c.color
      HAVING total > 0
      ORDER BY total DESC
    ''', args);
  }

  Future<Map<String, double>> getPeriodTotals({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final income = await getTotalIncome(
      startDate: startDate,
      endDate: endDate,
    );

    final expense = await getTotalExpense(
      startDate: startDate,
      endDate: endDate,
    );

    return {
      'income': income,
      'expense': expense,
      'difference': income - expense,
    };
  }

  Future<List<Map<String, dynamic>>> searchTransactions(
    String query,
  ) {
    return getTransactions(search: query);
  }

  Future<void> clearTransactions() async {
    await db.transaction((txn) async {
      // Remove linked Savings history before clearing transactions.
      await txn.delete(
        'savings_transactions',
        where: 'linked_transaction_id IS NOT NULL',
      );

      await txn.delete('transactions');

      await _recalculateAllAccountBalances(txn);
      await _recalculateAllLoanBalances(txn);
    });
  }

  // BACKUP

  Future<String> exportBackup({
    Map<String, dynamic> settings = const {},
  }) async {
    final tableNames = [
      'accounts',
      'categories',
      'loans',
      'transactions',
      'savings',
      'savings_transactions',
      'budgets',
    ];

    final data = <String, dynamic>{
      'app': 'AmarHisab',
      'format_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': settings,
      'tables': <String, dynamic>{},
    };

    final tables = data['tables'] as Map<String, dynamic>;

    for (final table in tableNames) {
      tables[table] = await db.query(table);
    }

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Returns backed-up settings after successful restoration.
  Future<Map<String, dynamic>> restoreBackup(
    String jsonString,
  ) async {
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != 'AmarHisab' ||
        decoded['format_version'] != 1 ||
        decoded['tables'] is! Map) {
      throw Exception('Invalid Amar Hisab backup file.');
    }

    final tables = Map<String, dynamic>.from(
      decoded['tables'] as Map,
    );

    const requiredTables = [
      'accounts',
      'categories',
      'loans',
      'transactions',
      'savings',
      'savings_transactions',
      'budgets',
    ];

    for (final table in requiredTables) {
      if (tables[table] is! List) {
        throw Exception('Backup is missing table: $table');
      }

      for (final row in tables[table] as List) {
        if (row is! Map) {
          throw Exception('Invalid row in $table.');
        }
      }
    }

    final backupSettings = decoded['settings'];

    if (backupSettings != null && backupSettings is! Map) {
      throw Exception('Invalid settings in backup.');
    }

    await db.transaction((txn) async {
      for (final table in [
        'savings_transactions',
        'transactions',
        'budgets',
        'savings',
        'loans',
        'categories',
        'accounts',
      ]) {
        await txn.delete(table);
      }

      for (final table in [
        'accounts',
        'categories',
        'loans',
        'transactions',
        'savings',
        'savings_transactions',
        'budgets',
      ]) {
        final rows = (tables[table] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        final columns = await txn.rawQuery(
          'PRAGMA table_info($table)',
        );

        final validColumns = columns
            .map((column) => column['name'] as String)
            .toSet();

        for (final row in rows) {
          final cleanRow = <String, dynamic>{};

          row.forEach((key, value) {
            if (validColumns.contains(key)) {
              cleanRow[key] = value;
            }
          });

          await txn.insert(table, cleanRow);
        }
      }

      await _recalculateAllAccountBalances(txn);
      await _recalculateAllLoanBalances(txn);
    });

    return backupSettings == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(backupSettings as Map);
  }

  // CLOSE DATABASE

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
