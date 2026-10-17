
import 'package:flutter/material.dart';

import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backup = BackupService.instance;

  bool _loading = false;
  bool _autoBackup = true;
  bool _hasFolder = false;
  DateTime? _lastBackup;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final enabled = await _backup.isAutoBackupEnabled();
    final folder = await _backup.hasBackupFolder();
    final last = await _backup.getLastBackupDate();

    if (!mounted) return;

    setState(() {
      _autoBackup = enabled;
      _hasFolder = folder;
      _lastBackup = last;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _runTask(
    Future<void> Function() task,
  ) async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await task();
      await _loadStatus();
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _chooseFolder() async {
    await _runTask(() async {
      final selected = await _backup.chooseBackupFolder();

      if (selected) {
        _showMessage('ব্যাকআপ ফোল্ডার নির্বাচন করা হয়েছে।');
      } else {
        _showMessage('ফোল্ডার নির্বাচন বাতিল করা হয়েছে।');
      }
    });
  }

  Future<void> _createBackup() async {
    await _runTask(() async {
      final path = await _backup.exportBackupFile();

      if (path == null) {
        _showMessage('ব্যাকআপ সংরক্ষণ বাতিল করা হয়েছে।');
        return;
      }

      _showMessage('ব্যাকআপ ফাইল সংরক্ষণের অনুরোধ সম্পন্ন হয়েছে।');
    });
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ব্যাকআপ Restore করবেন?'),
        content: const Text(
          'Restore করলে বর্তমান হিসাবের তথ্য নির্বাচিত '
          'ব্যাকআপের তথ্য দিয়ে প্রতিস্থাপিত হবে। '
          'আগে বর্তমান হিসাবের একটি নিরাপদ কপি সংরক্ষণ করতে হবে। '
          'আপনি কি এগিয়ে যেতে চান?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('এগিয়ে যান'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _runTask(() async {
      // Save the existing data first. If the user cancels the
      // save dialog, do not proceed with the destructive restore.
      final safetyPath = await _backup.exportBackupFile();

      if (safetyPath == null) {
        _showMessage(
          'নিরাপদ ব্যাকআপ সংরক্ষণ করা হয়নি। Restore বাতিল।',
        );
        return;
      }

      await _backup.restoreFromFile();

      _showMessage(
        'Restore সম্পন্ন হয়েছে। পরিবর্তন দেখতে অ্যাপ পুনরায় খুলুন।',
      );
    });
  }

  Future<void> _toggleAutoBackup(bool value) async {
    setState(() => _autoBackup = value);

    try {
      await _backup.setAutoBackupEnabled(value);

      if (value) {
        _showMessage(
          'সাপ্তাহিক ব্যাকআপ চালু হয়েছে। '
          'স্বয়ংক্রিয় কাজের সময়সূচি এখনো যুক্ত করতে হবে।',
        );
      } else {
        _showMessage('সাপ্তাহিক ব্যাকআপ বন্ধ হয়েছে।');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _autoBackup = !value);
      _showMessage(e.toString());
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'এখনো কোনো ব্যাকআপ নেই';

    final d = date.toLocal();

    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.backup_rounded,
                        size: 42,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'আমার হিসাবের নিরাপদ ব্যাকআপ',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'তোমার হিসাবের তথ্য JSON ফাইলে সংরক্ষণ '
                        'করো। ফোন পরিবর্তন বা অ্যাপ পুনরায় '
                        'ইনস্টল করার পর এই ফাইল থেকে তথ্য '
                        'ফিরিয়ে আনা যাবে।',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_open_rounded),
                      title: const Text('ব্যাকআপ ফোল্ডার নির্বাচন'),
                      subtitle: Text(
                        _hasFolder
                            ? 'ফোল্ডার নির্বাচন করা হয়েছে'
                            : 'ফোনে ব্যাকআপ রাখার ফোল্ডার নির্বাচন করো',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _loading ? null : _chooseFolder,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.save_alt_rounded),
                      title: const Text('নতুন ব্যাকআপ তৈরি'),
                      subtitle: const Text(
                        'JSON ফাইল হিসেবে সংরক্ষণ করো',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _loading ? null : _createBackup,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.restore_rounded),
                      title: const Text('ব্যাকআপ থেকে Restore'),
                      subtitle: const Text(
                        'আগের JSON ব্যাকআপ ফাইল নির্বাচন করো',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _loading ? null : _restoreBackup,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.event_repeat_rounded),
                      title: const Text('সাপ্তাহিক ব্যাকআপ'),
                      subtitle: const Text(
                        'প্রতি ৭ দিনে ব্যাকআপের জন্য পছন্দ সংরক্ষণ',
                      ),
                      value: _autoBackup,
                      onChanged: _loading ? null : _toggleAutoBackup,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: const Text('সর্বশেষ ব্যাকআপ'),
                      subtitle: Text(_formatDate(_lastBackup)),
                      trailing: IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _loading ? null : _loadStatus,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'সতর্কতা: Restore করলে বর্তমান তথ্য '
                          'প্রতিস্থাপিত হবে। নিরাপদ কপি রাখবে। '
                          'সাপ্তাহিক ব্যাকগ্রাউন্ড ব্যাকআপের '
                          'জন্য অতিরিক্ত Android scheduling '
                          'কোড প্রয়োজন।',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black12,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'অপেক্ষা করো...',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
