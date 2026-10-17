import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'money_db.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _syncing = false;

  static const String _channelId = 'amar_hisab_reminders';

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    _channelId,
    'Amar Hisab Reminders',
    description: 'Loan and DPS reminders',
    importance: Importance.max,
  );

  Future<void> init() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _plugin.initialize(settings);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await android?.createNotificationChannel(_channel);
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<bool?> requestPermission() async {
    try {
      await init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      return await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      _channelId,
      'Amar Hisab Reminders',
      channelDescription: 'Loan and DPS reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    return const NotificationDetails(android: android);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await init();
      await _plugin.show(id, title, body, _details());
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      await init();

      if (!scheduledDate.isAfter(DateTime.now())) {
        return;
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: id.toString(),
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  DateTime _nextReminderTime(Object? dueValue) {
    final dueDate = _parseDate(dueValue);
    final now = DateTime.now();

    if (dueDate == null) {
      return DateTime(now.year, now.month, now.day + 1, 9);
    }

    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final todayNine = DateTime(now.year, now.month, now.day, 9);

    if (dueDay.isBefore(today)) {
      return DateTime(now.year, now.month, now.day + 1, 9);
    }

    if (dueDay.isAtSameMomentAs(today) && !todayNine.isAfter(now)) {
      return DateTime(now.year, now.month, now.day + 1, 9);
    }

    return DateTime(dueDate.year, dueDate.month, dueDate.day, 9);
  }

  String _dateText(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<int> syncFinancialReminders() async {
    try {
      await init();

      if (_syncing) return 0;
      _syncing = true;

      await _plugin.cancelAll();

      var count = 0;

      final loans = await MoneyDb.instance.getLoansDueForReminder(
        daysAhead: 7,
      );

      for (final loan in loans) {
        final idValue = loan['id'];
        if (idValue is! num) continue;

        final dueDate = _parseDate(loan['due_date']);
        if (dueDate == null) continue;

        final remainingValue = loan['remaining'];
        final remaining = remainingValue is num
            ? remainingValue.toDouble()
            : double.tryParse(remainingValue?.toString() ?? '') ?? 0;

        if (remaining <= 0) continue;

        final person = loan['person_name']?.toString() ?? '';
        final type = loan['type']?.toString() ?? '';
        final receivable = type == 'receivable';
        final dueDay = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
        );
        final today = DateTime.now();
        final todayDay = DateTime(today.year, today.month, today.day);
        final overdue = dueDay.isBefore(todayDay);

        final title = overdue
            ? 'আমার হিসাব — মেয়াদোত্তীর্ণ বকেয়া'
            : 'আমার হিসাব — দেনা-পাওনা রিমাইন্ডার';

        final body = overdue
            ? '$person: ${receivable ? 'পাওনা' : 'দেনা'} ${remaining.toStringAsFixed(2)} টাকা এখনো বাকি।'
            : '$person: ${receivable ? 'পাওনা আদায়' : 'দেনা পরিশোধ'}-এর তারিখ ${_dateText(dueDate)}।';

        await scheduleNotification(
          id: 100000 + idValue.toInt(),
          title: title,
          body: body,
          scheduledDate: _nextReminderTime(dueDate),
        );
        count++;
      }

      final savings = await MoneyDb.instance.getDpsDueForReminder(
        daysAhead: 7,
      );

      for (final saving in savings) {
        final idValue = saving['id'];
        if (idValue is! num) continue;

        final dueDate = _parseDate(saving['next_due_date']);
        if (dueDate == null) continue;

        final installmentValue = saving['installment_amount'];
        final installment = installmentValue is num
            ? installmentValue.toDouble()
            : double.tryParse(installmentValue?.toString() ?? '') ?? 0;

        if (installment <= 0) continue;

        final name = saving['name']?.toString() ?? 'DPS';
        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final overdue = dueDay.isBefore(today);

        await scheduleNotification(
          id: 200000 + idValue.toInt(),
          title: overdue
              ? 'আমার হিসাব — DPS কিস্তি বকেয়া'
              : 'আমার হিসাব — DPS কিস্তি',
          body: overdue
              ? '$name: ${installment.toStringAsFixed(2)} টাকার কিস্তি বাকি।'
              : '$name: ${installment.toStringAsFixed(2)} টাকার কিস্তি ${_dateText(dueDate)} তারিখে।',
          scheduledDate: _nextReminderTime(dueDate),
        );
        count++;
      }

      return count;
    } catch (e) {
      debugPrint('Error syncing financial reminders: $e');
      return 0;
    } finally {
      _syncing = false;
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await init();
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await init();
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }
}
