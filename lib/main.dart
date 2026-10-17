import 'dart:async';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'services/money_db.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // নিশ্চিত করুন Flutter Binding আগে ইনিশিয়ালাইজ হয়েছে
  WidgetsFlutterBinding.ensureInitialized();

  // Async ইনিশিয়ালাইজেশন সুরক্ষিত করার জন্য try-catch ব্লক
  try {
    // 1. Initialize DB
    await MoneyDb.instance.init();
  } catch (e) {
    debugPrint('Database init failed: $e');
  }

  try {
    // 2. Initialize Settings
    await AppSettings.instance.init();
  } catch (e) {
    debugPrint('AppSettings init failed: $e');
  }

  try {
    // 3. Initialize Notifications safely
    await NotificationService.instance.init();
    await NotificationService.instance.requestPermission();
    await NotificationService.instance.syncFinancialReminders();
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }

  runApp(const AmarHisabApp());
}

class AmarHisabApp extends StatefulWidget {
  const AmarHisabApp({super.key});

  @override
  State<AmarHisabApp> createState() => _AmarHisabAppState();
}

class _AmarHisabAppState extends State<AmarHisabApp> {
  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_settingsChanged);
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: settings.t('appName'),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
