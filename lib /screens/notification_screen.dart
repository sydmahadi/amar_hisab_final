
import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/money_db.dart';
import '../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final AppSettings _settings = AppSettings.instance;
  final NotificationService _notifications = NotificationService.instance;

  List<Map<String, Object?>> _loans = [];
  List<Map<String, Object?>> _dps = [];

  bool _loading = true;
  bool _working = false;
  String? _error;

  bool get _bn => _settings.isBangla;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _loadReminders();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  DateTime? _dateOf(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  bool _isOverdue(Object? value) {
    final date = _dateOf(value);
    if (date == null) return false;

    final today = DateTime.now();
    final dueDay = DateTime(date.year, date.month, date.day);
    final todayDay = DateTime(today.year, today.month, today.day);

    return dueDay.isBefore(todayDay);
  }

  String _formatDate(Object? value) {
    final date = _dateOf(value);
    if (date == null) return _bn ? 'তারিখ নেই' : 'No date';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _money(Object? value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return '৳${amount.toStringAsFixed(2)}';
  }

  Future<void> _loadReminders() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final loans = await MoneyDb.instance.getLoansDueForReminder(
        daysAhead: 7,
      );
      final dps = await MoneyDb.instance.getDpsDueForReminder(
        daysAhead: 7,
      );

      if (!mounted) return;

      setState(() {
        _loans = loans;
        _dps = dps;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _bn
            ? 'রিমাইন্ডারের তথ্য লোড করা যায়নি। আবার চেষ্টা করুন।'
            : 'Could not load reminders. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAndSchedule() async {
    if (_working) return;

    setState(() => _working = true);

    try {
      await _loadReminders();
      final count = await _notifications.syncFinancialReminders();

      if (!mounted) return;
      _message(
        _bn
            ? '$countটি রিমাইন্ডার শিডিউল করা হয়েছে।'
            : '$count reminder(s) scheduled.',
      );
    } catch (e) {
      if (mounted) {
        _message(
          _bn
              ? 'রিমাইন্ডার শিডিউল করা যায়নি।'
              : 'Could not schedule reminders.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sendTest() async {
    if (_working) return;
    setState(() => _working = true);

    try {
      final permission = await _notifications.requestPermission();

      if (!mounted) return;

      if (permission == false) {
        _message(
          _bn
              ? 'ফোনের Settings থেকে নোটিফিকেশন অনুমতি চালু করুন।'
              : 'Enable notifications in your phone Settings.',
        );
        return;
      }

      await _notifications.showTestNotification();

      if (mounted) {
        _message(
          _bn
              ? 'টেস্ট নোটিফিকেশন পাঠানো হয়েছে।'
              : 'Test notification sent.',
        );
      }
    } catch (e) {
      if (mounted) {
        _message(
          _bn
              ? 'টেস্ট নোটিফিকেশন পাঠানো যায়নি।'
              : 'Could not send test notification.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _scheduleTest() async {
    if (_working) return;
    setState(() => _working = true);

    try {
      final permission = await _notifications.requestPermission();

      if (!mounted) return;

      if (permission == false) {
        _message(
          _bn
              ? 'প্রথমে নোটিফিকেশনের অনুমতি দিন।'
              : 'Please grant notification permission first.',
        );
        return;
      }

      await _notifications.scheduleNotification(
        id: 1002,
        title: _bn ? 'আমার হিসাব — টেস্ট' : 'Amar Hisab — Test',
        body: _bn
            ? 'এটি আপনার পরীক্ষামূলক রিমাইন্ডার।'
            : 'This is your test reminder.',
        scheduledDate: DateTime.now().add(const Duration(minutes: 2)),
      );

      if (mounted) {
        _message(
          _bn
              ? '২ মিনিট পরের রিমাইন্ডার সেট হয়েছে।'
              : 'Reminder scheduled for 2 minutes from now.',
        );
      }
    } catch (e) {
      if (mounted) {
        _message(
          _bn
              ? 'টেস্ট রিমাইন্ডার সেট করা যায়নি।'
              : 'Could not schedule the test reminder.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _sectionTitle(String title, IconData icon, Color primary) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _loanCard(Map<String, Object?> loan, Color primary) {
    final due = loan['due_date'];
    final overdue = _isOverdue(due);
    final type = loan['type']?.toString() ?? '';
    final receivable = type == 'receivable';
    final person = loan['person_name']?.toString() ?? '';
    final remaining = loan['remaining'];

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (overdue ? Colors.red : primary).withValues(
            alpha: 0.12,
          ),
          child: Icon(
            overdue ? Icons.warning_amber_rounded : Icons.account_balance_wallet,
            color: overdue ? Colors.red : primary,
          ),
        ),
        title: Text(
          person.isEmpty
              ? (_bn ? 'নাম উল্লেখ নেই' : 'Unnamed person')
              : person,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${receivable ? (_bn ? 'পাওনা' : 'Receivable') : (_bn ? 'দেনা' : 'Payable')}'
            ' • ${_bn ? 'শেষ তারিখ' : 'Due'}: ${_formatDate(due)}\n'
            '${overdue ? (_bn ? 'মেয়াদোত্তীর্ণ' : 'Overdue') : (_bn ? 'আগামী ৭ দিনের মধ্যে' : 'Within 7 days')}',
          ),
        ),
        trailing: Text(
          _money(remaining),
          style: TextStyle(
            color: overdue ? Colors.red : primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _dpsCard(Map<String, Object?> saving, Color primary) {
    final due = saving['next_due_date'];
    final overdue = _isOverdue(due);
    final name = saving['name']?.toString() ?? 'DPS';
    final installment = saving['installment_amount'];

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (overdue ? Colors.red : primary).withValues(
            alpha: 0.12,
          ),
          child: Icon(
            overdue ? Icons.warning_amber_rounded : Icons.savings_rounded,
            color: overdue ? Colors.red : primary,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_bn ? 'কিস্তির তারিখ' : 'Installment date'}: ${_formatDate(due)}\n'
          '${overdue ? (_bn ? 'মেয়াদোত্তীর্ণ' : 'Overdue') : (_bn ? 'আগামী ৭ দিনের মধ্যে' : 'Within 7 days')}',
        ),
        trailing: Text(
          _money(installment),
          style: TextStyle(
            color: overdue ? Colors.red : primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = _settings.isDarkMode;
    final primary = dark
        ? const Color(0xFF176B45)
        : const Color(0xFF0F5132);
    final gold = const Color(0xFFC9A45C);
    final textColor = Theme.of(context).colorScheme.onSurface;

    final receivables = _loans
        .where((loan) => loan['type']?.toString() == 'receivable')
        .toList();
    final payables = _loans
        .where((loan) => loan['type']?.toString() == 'payable')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_bn ? 'রিমাইন্ডার' : 'Reminders'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _bn ? 'রিফ্রেশ ও শিডিউল' : 'Refresh and schedule',
            onPressed: _loading || _working ? null : _refreshAndSchedule,
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReminders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFC9A45C),
                    size: 42,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _bn ? 'রিমাইন্ডার সেন্টার' : 'Reminder Center',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _bn
                              ? 'আগামী ৭ দিনের হিসাব ও মেয়াদোত্তীর্ণ বকেয়া'
                              : 'Next 7 days and overdue balances',
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  title: Text(_error!),
                  trailing: IconButton(
                    onPressed: _loadReminders,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else ...[
              _sectionTitle(
                _bn ? 'আপনার পাওনা' : 'People who owe you',
                Icons.call_received_rounded,
                primary,
              ),
              if (receivables.isEmpty)
                _empty(_bn ? 'এখন কোনো পাওনার রিমাইন্ডার নেই।' : 'No receivable reminders.')
              else
                ...receivables.map((loan) => _loanCard(loan, primary)),
              _sectionTitle(
                _bn ? 'আপনার দেনা' : 'People you owe',
                Icons.call_made_rounded,
                primary,
              ),
              if (payables.isEmpty)
                _empty(_bn ? 'এখন কোনো দেনার রিমাইন্ডার নেই।' : 'No payable reminders.')
              else
                ...payables.map((loan) => _loanCard(loan, primary)),
              _sectionTitle(
                _bn ? 'সঞ্চয় ও DPS কিস্তি' : 'Savings and DPS installments',
                Icons.savings_rounded,
                primary,
              ),
              if (_dps.isEmpty)
                _empty(_bn ? 'আগামী ৭ দিনে কোনো DPS কিস্তি নেই।' : 'No DPS installments due in the next 7 days.')
              else
                ..._dps.map((saving) => _dpsCard(saving, primary)),
            ],
            _sectionTitle(
              _bn ? 'ফোনের নোটিফিকেশন' : 'Phone notifications',
              Icons.phone_android_rounded,
              primary,
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.send_rounded, color: primary),
                title: Text(_bn ? 'এখনই টেস্ট নোটিফিকেশন' : 'Send test notification'),
                subtitle: Text(
                  _bn
                      ? 'ফোনের নোটিফিকেশন প্যানেলে পরীক্ষা করুন।'
                      : 'Check whether notifications appear on your phone.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _working ? null : _sendTest,
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.alarm_rounded, color: primary),
                title: Text(_bn ? '২ মিনিটের টেস্ট রিমাইন্ডার' : '2-minute test reminder'),
                subtitle: Text(
                  _bn
                      ? 'অ্যাপ থেকে বের হয়েও পরীক্ষা করতে পারবেন।'
                      : 'Test after leaving the app.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _working ? null : _scheduleTest,
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.sync_rounded, color: primary),
                title: Text(_bn ? 'রিমাইন্ডার শিডিউল আপডেট' : 'Update reminder schedule'),
                subtitle: Text(
                  _bn
                      ? 'বর্তমান দেনা-পাওনা ও DPS তথ্য থেকে রিমাইন্ডার তৈরি করুন।'
                      : 'Schedule reminders from current loans and DPS data.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _working ? null : _refreshAndSchedule,
              ),
            ),
            if (_working)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withValues(alpha: 0.55)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _bn
                          ? 'মেয়াদোত্তীর্ণ বকেয়া পরিশোধ না হওয়া পর্যন্ত তালিকায় থাকবে। ফোনে নোটিফিকেশন পেতে অনুমতি চালু রাখুন। সময়মতো নতুন রিমাইন্ডার শিডিউল করতে Refresh/Sync চাপুন।'
                          : 'Overdue balances remain listed until paid. Keep notification permission enabled and use Refresh/Sync to update scheduled reminders.',
                      style: TextStyle(color: textColor, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
