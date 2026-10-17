
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'money_db.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const MethodChannel _channel =
      MethodChannel('amar_hisab/backup');

  static const String _lastBackupDateKey =
      'amar_hisab_last_backup_date';

  static const String _backupFolderKey =
      'amar_hisab_backup_folder';

  static const String _autoBackupEnabledKey =
      'amar_hisab_auto_backup_enabled';

  static const String _backupPrefix = 'amar_hisab_backup_';

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? true;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
  }

  Future<DateTime?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastBackupDateKey);

    if (value == null || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  Future<bool> chooseBackupFolder() async {
    final result = await _channel.invokeMethod<bool>(
      'chooseBackupFolder',
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_backupFolderKey, true);
      return true;
    }

    return false;
  }

  Future<bool> hasBackupFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backupFolderKey) ?? false;
  }

  Future<Map<String, dynamic>> _readSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{};

    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);

      if (value is String ||
          value is bool ||
          value is int ||
          value is double ||
          value is List<String>) {
        settings[key] = value;
      }
    }

    return settings;
  }

  Future<String> createBackupJson() async {
    final settings = await _readSettings();

    final backupJson = await MoneyDb.instance.exportBackup(
      settings: settings,
    );

    final decoded = jsonDecode(backupJson);

    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != 'AmarHisab' ||
        decoded['format_version'] != 1 ||
        decoded['tables'] is! Map) {
      throw Exception('ব্যাকআপ ডেটার ফরম্যাট সঠিক নয়।');
    }

    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  Future<bool> saveBackupToPhone() async {
    if (!await hasBackupFolder()) {
      throw Exception('আগে ব্যাকআপ ফোল্ডার নির্বাচন করুন।');
    }

    final backupJson = await createBackupJson();
    final now = DateTime.now();

    final timestamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    final filename = '$_backupPrefix$timestamp.json';

    final result = await _channel.invokeMethod<bool>(
      'saveBackupToFolder',
      <String, dynamic>{
        'filename': filename,
        'content': backupJson,
      },
    );

    if (result != true) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastBackupDateKey,
      now.toIso8601String(),
    );

    return true;
  }

  Future<String?> exportBackupFile() async {
    final backupJson = await createBackupJson();
    final now = DateTime.now();

    final timestamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    final filename = '$_backupPrefix$timestamp.json';

    final path = await FilePicker.saveFile(
      dialogTitle: 'আমার হিসাব ব্যাকআপ সংরক্ষণ করুন',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(backupJson),
    );

    if (path == null || path.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastBackupDateKey,
      now.toIso8601String(),
    );

    return path;
  }

  Future<Map<String, dynamic>?> restoreFromFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'আমার হিসাব ব্যাকআপ ফাইল নির্বাচন করুন',
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw Exception('ব্যাকআপ ফাইল থেকে ডেটা পড়া যায়নি।');
    }

    final backupJson = utf8.decode(bytes);
    final decoded = jsonDecode(backupJson);

    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != 'AmarHisab' ||
        decoded['format_version'] != 1 ||
        decoded['tables'] is! Map) {
      throw Exception('সঠিক আমার হিসাব ব্যাকআপ ফাইল নির্বাচন করুন।');
    }

    final restoredSettings =
        await MoneyDb.instance.restoreBackup(backupJson);

    final prefs = await SharedPreferences.getInstance();

    for (final entry in restoredSettings.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      }
    }

    await prefs.setString(
      _lastBackupDateKey,
      DateTime.now().toIso8601String(),
    );

    return restoredSettings;
  }

  Future<bool> runWeeklyBackupIfDue() async {
    if (!await isAutoBackupEnabled()) {
      return false;
    }

    if (!await hasBackupFolder()) {
      return false;
    }

    final lastBackup = await getLastBackupDate();
    final now = DateTime.now();

    if (lastBackup != null &&
        now.difference(lastBackup).inDays < 7) {
      return false;
    }

    return saveBackupToPhone();
  }
}
