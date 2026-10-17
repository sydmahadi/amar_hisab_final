import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/money_db.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  static const String _passwordKey = 'savings_password_hash';
  static const String _recoveryKey = 'savings_recovery_hash';

  bool _authorized = false;
  bool _loading = true;

  List<Map<String, dynamic>> _savings = [];
  List<Map<String, dynamic>> _accounts = [];

  bool get _bn =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'bn';

  String _t(String bn, String en) => _bn ? bn : en;

  String _money(num value) {
    final amount = value.toDouble();
    return amount.toStringAsFixed(2);
  }

  double _num(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  int? _int(dynamic value) =>
      value == null ? null : (value as num).toInt();

  String _date(DateTime? date) {
    if (date == null) return _t('নির্ধারণ করা নেই', 'Not set');
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  String _hash(String value) =>
      sha256.convert(value.trim().codeUnits).toString();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHash = prefs.getString(_passwordKey);

      if (!mounted) return;

      if (savedHash == null || savedHash.isEmpty) {
        await _setupPassword();
      } else {
        await _login();
      }
    } catch (e) {
      if (mounted) _message('$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _generateRecoveryCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    String part() =>
        List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();

    return '${part()}-${part()}-${part()}';
  }

  bool _validPassword(String password) {
    return password.length >= 6 &&
        RegExp(r'[A-Za-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  Future<void> _setupPassword() async {
    final password = TextEditingController();
    final confirm = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Savings পাসওয়ার্ড সেট করুন', 'Set Savings Password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _t(
                'কমপক্ষে ৬ অক্ষর ব্যবহার করুন; একটি ইংরেজি অক্ষর ও একটি সংখ্যা থাকতে হবে।',
                'Use at least 6 characters, including an English letter and a number.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _t('নতুন পাসওয়ার্ড', 'New password'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _t('আবার লিখুন', 'Confirm password'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              if (!_validPassword(password.text)) {
                _message(
                  _t(
                    'পাসওয়ার্ডে কমপক্ষে ৬ অক্ষর, ইংরেজি অক্ষর ও সংখ্যা দিন।',
                    'Password must contain at least 6 characters, a letter and a number.',
                  ),
                  error: true,
                );
                return;
              }
              if (password.text != confirm.text) {
                _message(
                  _t('দুটি পাসওয়ার্ড মিলছে না।', 'Passwords do not match.'),
                  error: true,
                );
                return;
              }
              Navigator.pop(dialogContext, password.text);
            },
            child: Text(_t('সেট করুন', 'Set password')),
          ),
        ],
      ),
    );

    password.dispose();
    confirm.dispose();

    if (result == null) return;

    final recoveryCode = _generateRecoveryCode();
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_passwordKey, _hash(result));
    await prefs.setString(_recoveryKey, _hash(recoveryCode));

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Recovery Code সংরক্ষণ করুন', 'Save Recovery Code')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(
                'পাসওয়ার্ড ভুলে গেলে এই কোড দিয়ে নতুন পাসওয়ার্ড সেট করতে পারবেন। কোডটি নিরাপদ স্থানে লিখে রাখুন।',
                'Use this code to reset your password if you forget it. Keep it somewhere safe.',
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              recoveryCode,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: recoveryCode));
              _message(_t('কোড কপি হয়েছে।', 'Code copied.'));
            },
            icon: const Icon(Icons.copy),
            label: Text(_t('কপি', 'Copy')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t('সংরক্ষণ করেছি', 'I saved it')),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _authorized = true);
    await _loadSavings();
  }

  Future<void> _login() async {
    final password = TextEditingController();
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    final savedHash = prefs.getString(_passwordKey);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Savings সুরক্ষিত', 'Savings Protected')),
        content: TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _t('পাসওয়ার্ড', 'Password'),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            Navigator.pop(
              dialogContext,
              _hash(password.text) == savedHash,
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext, false);
              await _resetPassword();
            },
            child: Text(_t('Recovery Code', 'Recovery Code')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _hash(password.text) == savedHash,
            ),
            child: Text(_t('প্রবেশ করুন', 'Unlock')),
          ),
        ],
      ),
    );

    password.dispose();

    if (!mounted) return;

    if (result == true) {
      setState(() => _authorized = true);
      await _loadSavings();
    } else {
      setState(() => _authorized = false);
    }
  }

  Future<void> _resetPassword() async {
    final recovery = TextEditingController();
    final password = TextEditingController();
    final confirm = TextEditingController();

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('পাসওয়ার্ড রিসেট', 'Reset Password')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: recovery,
                decoration: InputDecoration(
                  labelText: _t('Recovery Code', 'Recovery Code'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _t('নতুন পাসওয়ার্ড', 'New password'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _t('আবার লিখুন', 'Confirm password'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('বাতিল', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final savedRecovery = prefs.getString(_recoveryKey);
              if (savedRecovery == null ||
                  _hash(recovery.text.toUpperCase()) != savedRecovery) {
                _message(
                  _t('Recovery Code সঠিক নয়।', 'Incorrect Recovery Code.'),
                  error: true,
                );
                return;
              }
              if (!_validPassword(password.text) ||
                  password.text != confirm.text) {
                _message(
                  _t(
                    'সঠিক পাসওয়ার্ড দিন এবং দুটি পাসওয়ার্ড মিলিয়ে নিন।',
                    'Enter a valid password and make sure both passwords match.',
                  ),
                  error: true,
                );
                return;
              }
              await prefs.setString(_passwordKey, _hash(password.text));
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(_t('রিসেট করুন', 'Reset')),
          ),
        ],
      ),
    );

    recovery.dispose();
    password.dispose();
    confirm.dispose();

    if (!mounted) return;

    if (result == true) {
      setState(() => _authorized = true);
      await _loadSavings();
      _message(_t('পাসওয়ার্ড পরিবর্তন হয়েছে।', 'Password has been reset.'));
    }
  }

  Future<void> _changePassword() async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('পাসওয়ার্ড পরিবর্তন', 'Change Password')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPassword,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _t('পুরোনো পাসওয়ার্ড', 'Current password'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _t('নতুন পাসওয়ার্ড', 'New password'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmPassword,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _t('আবার লিখুন', 'Confirm password'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('বাতিল', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (_hash(oldPassword.text) !=
                  prefs.getString(_passwordKey)) {
                _message(
                  _t('পুরোনো পাসওয়ার্ড সঠিক নয়।', 'Current password is incorrect.'),
                  error: true,
                );
                return;
              }
              if (!_validPassword(newPassword.text) ||
                  newPassword.text != confirmPassword.text) {
                _message(
                  _t('নতুন পাসওয়ার্ড যাচাই করুন।', 'Check the new password.'),
                  error: true,
                );
                return;
              }
              await prefs.setString(_passwordKey, _hash(newPassword.text));
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(_t('পরিবর্তন করুন', 'Change')),
          ),
        ],
      ),
    );

    oldPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();

    if (!mounted) return;
    if (result == true) {
      _message(_t('পাসওয়ার্ড পরিবর্তন হয়েছে।', 'Password changed.'));
    }
  }
    Future<void> _loadSavings() async {
    try {
      final results = await Future.wait([
        MoneyDb.instance.getSavings(),
        MoneyDb.instance.getAccounts(),
      ]);

      if (!mounted) return;

      setState(() {
        _savings = results[0];
        _accounts = results[1];
      });
    } catch (e) {
      if (mounted) _message('$e', error: true);
    }
  }

  double get _totalSavings => _savings.fold<double>(
        0,
        (sum, saving) => sum + _num(saving['current_amount']),
      );

  Future<DateTime?> _pickDate({
    DateTime? initialDate,
    DateTime? firstDate,
  }) async {
    final now = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: DateTime(2100),
      helpText: _t('তারিখ নির্বাচন করুন', 'Select date'),
    );
  }

  Future<void> _addSaving({bool isDps = false}) async {
    final name = TextEditingController();
    final target = TextEditingController();
    final initialDeposit = TextEditingController();
    final installment = TextEditingController();
    final note = TextEditingController();

    String frequency = 'monthly';
    DateTime? nextDueDate;
    DateTime? maturityDate;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isDps
                ? _t('নতুন DPS তৈরি', 'Create DPS')
                : _t('নতুন সঞ্চয় তৈরি', 'Create Savings'),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: _t('নাম', 'Name'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? _t('নাম লিখুন', 'Enter a name')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: target,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: _t(
                          'লক্ষ্যমাত্রা (৳)',
                          'Target amount (৳)',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final value = double.tryParse(v ?? '') ?? 0;
                        return value < 0
                            ? _t('সঠিক পরিমাণ দিন', 'Enter a valid amount')
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: initialDeposit,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: _t(
                          'প্রাথমিক জমা (ঐচ্ছিক)',
                          'Initial deposit (optional)',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (isDps) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: installment,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: _t(
                            'কিস্তির পরিমাণ (৳)',
                            'Installment amount (৳)',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = double.tryParse(v ?? '') ?? 0;
                          return value <= 0
                              ? _t(
                                  'কিস্তির পরিমাণ দিন',
                                  'Enter installment amount',
                                )
                              : null;
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: frequency,
                        decoration: InputDecoration(
                          labelText: _t('কিস্তির ধরন', 'Installment frequency'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text(_t('সাপ্তাহিক', 'Weekly')),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text(_t('মাসিক', 'Monthly')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => frequency = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: Text(_t('পরবর্তী কিস্তি', 'Next installment')),
                        subtitle: Text(_date(nextDueDate)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                            final date = await _pickDate(
                              initialDate: nextDueDate,
                            );
                            if (date != null) {
                              setDialogState(() => nextDueDate = date);
                            }
                          },
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.flag),
                        title: Text(_t('মেয়াদপূর্তির তারিখ', 'Maturity date')),
                        subtitle: Text(_date(maturityDate)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                            final date = await _pickDate(
                              initialDate: maturityDate,
                            );
                            if (date != null) {
                              setDialogState(() => maturityDate = date);
                            }
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: note,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _t('নোট (ঐচ্ছিক)', 'Note (optional)'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('বাতিল', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(_t('সংরক্ষণ', 'Save')),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) {
      name.dispose();
      target.dispose();
      initialDeposit.dispose();
      installment.dispose();
      note.dispose();
      return;
    }

    try {
      final targetAmount = double.tryParse(target.text) ?? 0;
      final initialAmount = double.tryParse(initialDeposit.text) ?? 0;
      final installmentAmount = double.tryParse(installment.text) ?? 0;

      if (initialAmount < 0) {
        throw Exception(_t('প্রাথমিক জমা ঋণাত্মক হতে পারে না।', 'Initial deposit cannot be negative.'));
      }

      final savingId = await MoneyDb.instance.addSavings(
        name: name.text.trim(),
        targetAmount: targetAmount,
        note: note.text.trim(),
        isDps: isDps,
        installmentAmount: isDps ? installmentAmount : 0,
        installmentFrequency: isDps ? frequency : null,
        nextDueDate: isDps ? nextDueDate : null,
        maturityDate: isDps ? maturityDate : null,
      );

      if (initialAmount > 0 && mounted) {
        await _addTransaction(
          savingId,
          deposit: true,
          initialAmount: initialAmount,
        );
      }

      await _loadSavings();

      if (mounted) {
        _message(_t('সঞ্চয় সংরক্ষণ হয়েছে।', 'Savings saved.'));
      }
    } catch (e) {
      if (mounted) _message('$e', error: true);
    } finally {
      name.dispose();
      target.dispose();
      initialDeposit.dispose();
      installment.dispose();
      note.dispose();
    }
  }

  Future<void> _editSaving(Map<String, dynamic> saving) async {
    final id = _int(saving['id']);
    if (id == null) return;

    final name = TextEditingController(
      text: saving['name']?.toString() ?? '',
    );
    final target = TextEditingController(
      text: _num(saving['target_amount']).toString(),
    );
    final installment = TextEditingController(
      text: _num(saving['installment_amount']).toString(),
    );
    final note = TextEditingController(
      text: saving['note']?.toString() ?? '',
    );

    bool isDps = (saving['is_dps'] as num? ?? 0).toInt() == 1;
    String frequency =
        saving['installment_frequency']?.toString() ?? 'monthly';

    if (!['weekly', 'monthly'].contains(frequency)) {
      frequency = 'monthly';
    }

    DateTime? nextDueDate = _parseDate(saving['next_due_date']);
    DateTime? maturityDate = _parseDate(saving['maturity_date']);

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t('সঞ্চয় সম্পাদনা', 'Edit Savings')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: _t('নাম', 'Name'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? _t('নাম লিখুন', 'Enter a name')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: target,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _t('লক্ষ্যমাত্রা (৳)', 'Target (৳)'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final value = double.tryParse(v ?? '');
                        return value == null || value < 0
                            ? _t('সঠিক পরিমাণ দিন', 'Enter a valid amount')
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_t('DPS', 'DPS')),
                      value: isDps,
                      onChanged: (value) =>
                          setDialogState(() => isDps = value),
                    ),
                    if (isDps) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: installment,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _t('কিস্তির পরিমাণ (৳)', 'Installment (৳)'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (!isDps) return null;
                          final value = double.tryParse(v ?? '') ?? 0;
                          return value <= 0
                              ? _t('কিস্তির পরিমাণ দিন', 'Enter installment')
                              : null;
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: frequency,
                        decoration: InputDecoration(
                          labelText: _t('কিস্তির ধরন', 'Frequency'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text(_t('সাপ্তাহিক', 'Weekly')),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text(_t('মাসিক', 'Monthly')),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => frequency = v);
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_t('পরবর্তী কিস্তি', 'Next installment')),
                        subtitle: Text(_date(nextDueDate)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                            final d = await _pickDate(
                              initialDate: nextDueDate,
                            );
                            if (d != null) {
                              setDialogState(() => nextDueDate = d);
                            }
                          },
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_t('মেয়াদপূর্তি', 'Maturity date')),
                        subtitle: Text(_date(maturityDate)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                            final d = await _pickDate(
                              initialDate: maturityDate,
                            );
                            if (d != null) {
                              setDialogState(() => maturityDate = d);
                            }
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: note,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _t('নোট', 'Note'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('বাতিল', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(_t('আপডেট', 'Update')),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      try {
        final targetAmount = double.parse(target.text);
        final installmentAmount = isDps
            ? (double.tryParse(installment.text) ?? 0)
            : 0.0;

        await MoneyDb.instance.updateSaving(
          id: id,
          name: name.text.trim(),
          targetAmount: targetAmount,
          note: note.text.trim(),
          isDps: isDps,
          installmentAmount: installmentAmount,
          installmentFrequency: isDps ? frequency : null,
          nextDueDate: nextDueDate,
          maturityDate: maturityDate,
        );

        await _loadSavings();
        if (mounted) {
          _message(_t('সঞ্চয়ের তথ্য আপডেট হয়েছে।', 'Savings updated.'));
        }
      } catch (e) {
        if (mounted) _message('$e', error: true);
      }
    }

    name.dispose();
    target.dispose();
    installment.dispose();
    note.dispose();
  }
    Future<void> _addTransaction(
    int savingId, {
    required bool deposit,
    double? initialAmount,
  }) async {
    final amount = TextEditingController(
      text: initialAmount == null ? '' : _money(initialAmount),
    );
    final note = TextEditingController();

    DateTime transactionDate = DateTime.now();
    int? selectedAccountId = _accounts.isEmpty
        ? null
        : _int(_accounts.first['id']);

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            deposit
                ? _t('টাকা জমা দিন', 'Deposit Money')
                : _t('টাকা উত্তোলন করুন', 'Withdraw Money'),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amount,
                      autofocus: initialAmount == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: _t('পরিমাণ (৳)', 'Amount (৳)'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final number = double.tryParse(value ?? '') ?? 0;
                        return number <= 0
                            ? _t('সঠিক পরিমাণ দিন', 'Enter a valid amount')
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedAccountId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _t('Account নির্বাচন করুন', 'Select account'),
                        border: const OutlineInputBorder(),
                      ),
                      items: _accounts.map((account) {
                        final id = _int(account['id'])!;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(account['name'].toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedAccountId = value);
                      },
                      validator: (value) => value == null
                          ? _t('Account নির্বাচন করুন', 'Select an account')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month),
                      title: Text(_t('লেনদেনের তারিখ', 'Transaction date')),
                      subtitle: Text(_date(transactionDate)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_calendar),
                        onPressed: () async {
                          final date = await _pickDate(
                            initialDate: transactionDate,
                          );
                          if (date != null) {
                            setDialogState(() => transactionDate = date);
                          }
                        },
                      ),
                    ),
                    TextFormField(
                      controller: note,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _t('নোট (ঐচ্ছিক)', 'Note (optional)'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_accounts.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _t(
                          'কোনো Account পাওয়া যায়নি। আগে Account তৈরি করুন।',
                          'No accounts found. Create an account first.',
                        ),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('বাতিল', 'Cancel')),
            ),
            FilledButton(
              onPressed: _accounts.isEmpty
                  ? null
                  : () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
              child: Text(_t('সংরক্ষণ', 'Save')),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      try {
        await MoneyDb.instance.addSavingsTransaction(
          savingsId: savingId,
          type: deposit ? 'deposit' : 'withdrawal',
          amount: double.parse(amount.text),
          note: note.text.trim(),
          transactionDate: transactionDate,
          accountId: selectedAccountId,
        );

        await _loadSavings();

        if (mounted) {
          _message(
            deposit
                ? _t('জমা সম্পন্ন হয়েছে।', 'Deposit completed.')
                : _t('উত্তোলন সম্পন্ন হয়েছে।', 'Withdrawal completed.'),
          );
        }
      } catch (e) {
        if (mounted) _message('$e', error: true);
      }
    }

    amount.dispose();
    note.dispose();
  }

  Future<void> _showTransactions(Map<String, dynamic> saving) async {
    final savingId = _int(saving['id']);
    if (savingId == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            '${_t('লেনদেনের ইতিহাস', 'Transaction History')}\n'
            '${saving['name']}',
          ),
          content: SizedBox(
            width: 500,
            height: 420,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: MoneyDb.instance.getSavingsTransactions(savingId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}'));
                }

                final transactions =
                    snapshot.data ?? <Map<String, dynamic>>[];

                if (transactions.isEmpty) {
                  return Center(
                    child: Text(
                      _t('এখনও কোনো লেনদেন নেই।', 'No transactions yet.'),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final isDeposit = transaction['type'] == 'deposit';
                    final transactionId = _int(transaction['id']);
                    final accountId = _int(transaction['account_id']);

                    String accountName = _t('পুরোনো রেকর্ড', 'Legacy record');

                    for (final account in _accounts) {
                      if (_int(account['id']) == accountId) {
                        accountName = account['name'].toString();
                        break;
                      }
                    }

                    final date = _parseDate(
                      transaction['transaction_date'],
                    );

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(
                          isDeposit ? Icons.south_west : Icons.north_east,
                        ),
                      ),
                      title: Text(
                        '${isDeposit ? '+' : '-'}৳'
                        '${_money(_num(transaction['amount']))}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDeposit ? Colors.green : Colors.orange,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_date(date)} • $accountName',
                          ),
                          if ((transaction['note'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            Text(transaction['note'].toString()),
                        ],
                      ),
                      trailing: IconButton(
                        tooltip: _t('মুছুন', 'Delete'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: transactionId == null
                            ? null
                            : () async {
                                final confirm = await _confirm(
                                  _t(
                                    'এই লেনদেন মুছবেন?',
                                    'Delete this transaction?',
                                  ),
                                );

                                if (!confirm) return;

                                try {
                                  await MoneyDb.instance
                                      .deleteSavingsTransaction(
                                    transactionId,
                                  );

                                  await _loadSavings();

                                  if (dialogContext.mounted) {
                                    setDialogState(() {});
                                  }

                                  if (mounted) {
                                    _message(
                                      _t('লেনদেন মুছে ফেলা হয়েছে।', 'Transaction deleted.'),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    _message('$e', error: true);
                                  }
                                }
                              },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('বন্ধ করুন', 'Close')),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('না', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('হ্যাঁ', 'Confirm')),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _deleteSaving(Map<String, dynamic> saving) async {
    final id = _int(saving['id']);
    if (id == null) return;

    final confirmed = await _confirm(
      _t(
        '"${saving['name']}" এবং এর সব লেনদেন মুছে ফেলবেন?',
        'Delete "${saving['name']}" and all its transactions?',
      ),
    );

    if (!confirmed || !mounted) return;

    try {
      await MoneyDb.instance.deleteSaving(id);
      await _loadSavings();

      if (mounted) {
        _message(_t('সঞ্চয় মুছে ফেলা হয়েছে।', 'Savings deleted.'));
      }
    } catch (e) {
      if (mounted) _message('$e', error: true);
    }
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );
  }
    Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savingCard(Map<String, dynamic> saving) {
    final id = _int(saving['id']);
    final isDps = (saving['is_dps'] as num? ?? 0).toInt() == 1;
    final current = _num(saving['current_amount']);
    final target = _num(saving['target_amount']);
    final installment = _num(saving['installment_amount']);

    final progress = target > 0
        ? (current / target).clamp(0.0, 1.0).toDouble()
        : 0.0;

    final nextDue = _parseDate(saving['next_due_date']);
    final maturity = _parseDate(saving['maturity_date']);
    final frequency = saving['installment_frequency']?.toString();

    final overdue = isDps &&
        nextDue != null &&
        DateTime(nextDue.year, nextDue.month, nextDue.day)
            .isBefore(DateTime.now().copyWith(
              hour: 0,
              minute: 0,
              second: 0,
              millisecond: 0,
              microsecond: 0,
            ));

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: isDps
                      ? Colors.amber.withValues(alpha: 0.18)
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                  child: Icon(
                    isDps ? Icons.account_balance : Icons.savings_outlined,
                    color: isDps
                        ? Colors.amber.shade800
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        saving['name']?.toString() ?? '',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              isDps
                                  ? _t('DPS', 'DPS')
                                  : _t('সাধারণ সঞ্চয়', 'Regular Savings'),
                            ),
                          ),
                          if (overdue)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.red.withValues(alpha: 0.12),
                              label: Text(
                                _t('কিস্তি বকেয়া', 'Installment overdue'),
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: _t('আরও', 'More'),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editSaving(saving);
                    } else if (value == 'history') {
                      _showTransactions(saving);
                    } else if (value == 'delete') {
                      _deleteSaving(saving);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(_t('সম্পাদনা', 'Edit')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'history',
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(_t('লেনদেনের ইতিহাস', 'Transaction history')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: Text(_t('মুছে ফেলুন', 'Delete')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _t('বর্তমান সঞ্চয়', 'Current savings'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 3),
            Text(
              '৳${_money(current)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            if (target > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${(progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 6),
              _infoRow(
                Icons.flag_outlined,
                _t('লক্ষ্যমাত্রা', 'Target'),
                '৳${_money(target)}',
              ),
              _infoRow(
                Icons.savings_outlined,
                _t('বাকি লক্ষ্য', 'Target remaining'),
                '৳${_money((target - current).clamp(0.0, double.infinity))}',
              ),
            ],
            if (isDps) ...[
              const Divider(height: 24),
              _infoRow(
                Icons.payments_outlined,
                _t('কিস্তির পরিমাণ', 'Installment'),
                '৳${_money(installment)}',
              ),
              _infoRow(
                Icons.repeat,
                _t('কিস্তির ধরন', 'Frequency'),
                frequency == 'weekly'
                    ? _t('সাপ্তাহিক', 'Weekly')
                    : _t('মাসিক', 'Monthly'),
              ),
              _infoRow(
                Icons.event_outlined,
                _t('পরবর্তী কিস্তি', 'Next installment'),
                _date(nextDue),
              ),
              _infoRow(
                Icons.flag_outlined,
                _t('মেয়াদপূর্তি', 'Maturity date'),
                _date(maturity),
              ),
            ],
            if ((saving['note'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${_t('নোট', 'Note')}: ${saving['note']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: id == null
                      ? null
                      : () => _addTransaction(id, deposit: true),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_t('জমা', 'Deposit')),
                ),
                OutlinedButton.icon(
                  onPressed: id == null || current <= 0
                      ? null
                      : () => _addTransaction(id, deposit: false),
                  icon: const Icon(Icons.south_west, size: 18),
                  label: Text(_t('উত্তোলন', 'Withdraw')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showTransactions(saving),
                  icon: const Icon(Icons.history, size: 18),
                  label: Text(_t('ইতিহাস', 'History')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_t('সঞ্চয় ও DPS', 'Savings & DPS')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 16),
                Text(
                  _t(
                    'সঞ্চয়ের তথ্য দেখতে পাসওয়ার্ড প্রয়োজন।',
                    'A password is required to view savings.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.lock_open),
                  label: Text(_t('আবার চেষ্টা করুন', 'Try again')),
                ),
                TextButton(
                  onPressed: _resetPassword,
                  child: Text(_t('Recovery Code দিয়ে রিসেট', 'Reset with Recovery Code')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('সঞ্চয় ও DPS', 'Savings & DPS')),
        actions: [
          IconButton(
            tooltip: _t('পাসওয়ার্ড পরিবর্তন', 'Change password'),
            onPressed: _changePassword,
            icon: const Icon(Icons.password),
          ),
          IconButton(
            tooltip: _t('রিফ্রেশ', 'Refresh'),
            onPressed: _loadSavings,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSavings,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      Icons.savings,
                      size: 40,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('মোট সঞ্চয়', 'Total Savings'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '৳${_money(_totalSavings)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _addSaving(),
                    icon: const Icon(Icons.add),
                    label: Text(_t('সঞ্চয় তৈরি', 'Add Savings')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addSaving(isDps: true),
                    icon: const Icon(Icons.account_balance),
                    label: Text(_t('DPS তৈরি', 'Add DPS')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _t('তোমার সঞ্চয়ের তালিকা', 'Your Savings'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text('${_savings.length}'),
              ],
            ),
            const SizedBox(height: 12),
            if (_savings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t(
                        'এখনও কোনো সঞ্চয় তৈরি করা হয়নি।',
                        'No savings have been created yet.',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t(
                        'শুরু করতে সঞ্চয় তৈরি বা DPS তৈরি চাপুন।',
                        'Tap Add Savings or Add DPS to get started.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._savings.map(_savingCard),
            const SizedBox(height: 20),
            Text(
              _t(
                'নোট: সঞ্চয়ের জমা/উত্তোলনের সঙ্গে নির্বাচিত Account-এর ব্যালেন্সও আপডেট হবে।',
                'Note: Deposits and withdrawals also update the selected account balance.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
