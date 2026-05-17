import 'package:flutter/material.dart';

import 'services/theme_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _themeId = ThemeService.selectedThemeId.value;

  Future<void> _setTheme(String? value) async {
    if (value == null) return;
    await ThemeService.setTheme(value);
    if (mounted) setState(() => _themeId = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              subtitle: const Text('Filter by type and time range'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/notifications'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _themeId,
                decoration: const InputDecoration(
                  labelText: 'Theme',
                  prefixIcon: Icon(Icons.palette_outlined),
                  border: OutlineInputBorder(),
                ),
                items: ThemeService.themes
                    .map(
                      (theme) => DropdownMenuItem(
                        value: theme.id,
                        child: Text(theme.name),
                      ),
                    )
                    .toList(),
                onChanged: _setTheme,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
