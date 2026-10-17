import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings get settings => AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(settings.isBangla ? 'ভাষা' : 'Language'),
            subtitle: Text(settings.isBangla ? 'বাংলা' : 'English'),
            trailing: Switch(
              value: settings.isBangla,
              activeTrackColor: AppTheme.gold,
              onChanged: (val) {
                setState(() {
                  settings.toggleLanguage();
                });
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(settings.isBangla ? 'ডার্ক মোড' : 'Dark Mode'),
            trailing: Switch(
              value: settings.isDarkMode,
              activeTrackColor: AppTheme.gold,
              onChanged: (val) {
                setState(() {
                  settings.toggleTheme();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
