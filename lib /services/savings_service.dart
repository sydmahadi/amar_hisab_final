import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class SavingsService {
  SavingsService._();

  static final SavingsService instance = SavingsService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    return init();
  }

  /// আলাদা Savings ডেটাবেস তৈরি করে।
  /// মূল Amar Hisab ডেটাবেসে হাত দেয় না।
  Future<Database> init() async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    final directory = await getDatabasesPath();
    final path = p.join(directory, 'amar_hisab_savings.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE savings_settings (
            setting_key TEXT PRIMARY KEY,
            setting_value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE savings_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            entry_date TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_savings_entry_date
          ON savings_entries(entry_date)
        ''');
      },
    );

    return _database!;
  }

  String _hash(String salt, String value) {
    return sha256.convert(utf8.encode('$salt:$value')).toString();
  }

  String _newSalt() {
    final random = Random.secure();
    final values = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    );

    return base64Url.encode(values);
  }

  String _newRecoveryCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    final code = List<String>.generate(
      16,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    return '${code.substring(0, 4)}-'
        '${code.substring(4, 8)}-'
        '${code.substring(8, 12)}-'
        '${code.substring(12, 16)}';
  }

  Future<void> _saveSetting(
    DatabaseExecutor db,
    String key,
    String value,
  ) async {
    await db.insert(
      'savings_settings',
      {
        'setting_key': key,
        'setting_value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> _getSetting(String key) async {
    final db = await database;

    final rows = await db.query(
      'savings_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return rows.first['setting_value'] as String?;
  }

  /// প্রথমবার পাসওয়ার্ড সেট করা হয়েছে কি না।
  Future<bool> isPasswordSet() async {
    final hash = await _getSetting('password_hash');
    return hash != null && hash.isNotEmpty;
  }

  /// প্রথমবার পাসওয়ার্ড ও Recovery Code তৈরি করে।
  ///
  /// সফল হলে Recovery Code একবার ফেরত দেয়।
  /// কোডটি নিরাপদ জায়গায় লিখে রাখতে হবে।
  Future<String> setupSecurity({
    required String password,
  }) async {
    if (password.trim().length < 6) {
      throw ArgumentError(
        'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে।',
      );
    }

    final db = await database;

    if (await isPasswordSet()) {
      throw StateError(
        'পাসওয়ার্ড আগে থেকেই সেট করা আছে।',
      );
    }

    final passwordSalt = _newSalt();
    final recoveryCode = _newRecoveryCode();
    final recoverySalt = _newSalt();

    await db.transaction((txn) async {
      await _saveSetting(
        txn,
        'password_salt',
        passwordSalt,
      );

      await _saveSetting(
        txn,
        'password_hash',
        _hash(passwordSalt, password),
      );

      await _saveSetting(
        txn,
        'recovery_salt',
        recoverySalt,
      );

      await _saveSetting(
        txn,
        'recovery_hash',
        _hash(recoverySalt, recoveryCode),
      );
    });

    return recoveryCode;
  }

  /// Savings খোলার পাসওয়ার্ড যাচাই।
  Future<bool> verifyPassword(String password) async {
    final salt = await _getSetting('password_salt');
    final savedHash = await _getSetting('password_hash');

    if (salt == null || savedHash == null) {
      return false;
    }

    return _hash(salt, password) == savedHash;
  }

  /// পুরোনো পাসওয়ার্ড দিয়ে নতুন পাসওয়ার্ড পরিবর্তন।
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (newPassword.trim().length < 6) {
      throw ArgumentError(
        'নতুন পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে।',
      );
    }

    if (!await verifyPassword(oldPassword)) {
      throw StateError('পুরোনো পাসওয়ার্ড সঠিক নয়।');
    }

    final db = await database;
    final salt = _newSalt();

    await db.transaction((txn) async {
      await _saveSetting(
        txn,
        'password_salt',
        salt,
      );

      await _saveSetting(
        txn,
        'password_hash',
        _hash(salt, newPassword),
      );
    });
  }

  /// Recovery Code দিয়ে পাসওয়ার্ড রিসেট।
  Future<void> resetPassword({
    required String recoveryCode,
    required String newPassword,
  }) async {
    if (newPassword.trim().length < 6) {
      throw ArgumentError(
        'নতুন পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে।',
      );
    }

    final recoverySalt = await _getSetting('recovery_salt');
    final recoveryHash = await _getSetting('recovery_hash');

    if (recoverySalt == null || recoveryHash == null) {
      throw StateError('Recovery Code পাওয়া যায়নি।');
    }

    final normalizedCode = recoveryCode
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .toUpperCase();

    if (_hash(recoverySalt, normalizedCode) != recoveryHash) {
      throw StateError('Recovery Code সঠিক নয়।');
    }

    final db = await database;
    final newSalt = _newSalt();

    await db.transaction((txn) async {
      await _saveSetting(
        txn,
        'password_salt',
        newSalt,
      );

      await _saveSetting(
        txn,
        'password_hash',
        _hash(newSalt, newPassword),
      );
    });
  }

  /// Savings-এর বর্তমান ব্যালেন্স।
  Future<double> getBalance() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT COALESCE(
        SUM(
          CASE
            WHEN type = 'deposit' THEN amount
            WHEN type = 'withdraw' THEN -amount
            ELSE 0
          END
        ),
        0
      ) AS balance
      FROM savings_entries
    ''');

    return (result.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// নতুন Savings জমা অথবা উত্তোলনের এন্ট্রি।
  ///
  /// type হবে 'deposit' অথবা 'withdraw'।
  Future<int> addEntry({
    required double amount,
    required String type,
    String note = '',
    DateTime? date,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('টাকার পরিমাণ সঠিক হতে হবে।');
    }

    if (type != 'deposit' && type != 'withdraw') {
      throw ArgumentError(
        "type হবে 'deposit' অথবা 'withdraw'।",
      );
    }

    final db = await database;
    final entryDate = date ?? DateTime.now();

    return db.transaction((txn) async {
      if (type == 'withdraw') {
        final result = await txn.rawQuery('''
          SELECT COALESCE(
            SUM(
              CASE
                WHEN type = 'deposit' THEN amount
                WHEN type = 'withdraw' THEN -amount
                ELSE 0
              END
            ),
            0
          ) AS balance
          FROM savings_entries
        ''');

        final balance =
            (result.first['balance'] as num?)?.toDouble() ?? 0.0;

        if (amount > balance) {
          throw StateError(
            'Savings-এ পর্যাপ্ত টাকা নেই। '
            'বর্তমান ব্যালেন্স: $balance',
          );
        }
      }

      return txn.insert('savings_entries', {
        'amount': amount,
        'type': type,
        'note': note.trim(),
        'entry_date': entryDate.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  /// সব এন্ট্রি নতুন থেকে পুরোনো ক্রমে।
  Future<List<Map<String, dynamic>>> getEntries() async {
    final db = await database;

    return db.query(
      'savings_entries',
      orderBy: 'entry_date DESC, id DESC',
    );
  }

  /// নির্দিষ্ট সময়ের এন্ট্রি।
  Future<List<Map<String, dynamic>>> getEntriesBetween({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;

    return db.query(
      'savings_entries',
      where: 'entry_date >= ? AND entry_date <= ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'entry_date DESC, id DESC',
    );
  }

  /// একটি এন্ট্রি মুছে ফেলা।
  Future<int> deleteEntry(int id) async {
    final db = await database;

    return db.delete(
      'savings_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// মোট জমা।
  Future<double> getTotalDeposits() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM savings_entries
      WHERE type = 'deposit'
    ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// মোট উত্তোলন।
  Future<double> getTotalWithdrawals() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM savings_entries
      WHERE type = 'withdraw'
    ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// সব Savings এন্ট্রি মুছে ফেলা।
  /// ব্যবহার করার আগে UI-তে নিশ্চিতকরণ নিতে হবে।
  Future<void> clearEntries() async {
    final db = await database;
    await db.delete('savings_entries');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
