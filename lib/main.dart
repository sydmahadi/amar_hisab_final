
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'services/money_db.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the existing database without deleting user data.
  await MoneyDb.instance.init();

  // Initialize saved language and theme settings.
  await AppSettings.instance.init();

  // Initialize notifications and request permission.
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermission();
  await NotificationService.instance.syncFinancialReminders();

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
      themeMode:
          settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
