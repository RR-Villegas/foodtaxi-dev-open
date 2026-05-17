import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FoodTaxiTheme {
  final String id;
  final String name;
  final Color seed;
  final Brightness brightness;
  final Color? scaffold;
  final Color? appBar;

  const FoodTaxiTheme({
    required this.id,
    required this.name,
    required this.seed,
    this.brightness = Brightness.light,
    this.scaffold,
    this.appBar,
  });

  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final background = scaffold ?? scheme.surface;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: appBar ?? scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.dark
            ? const Color(0xFF252526)
            : scheme.surface,
        elevation: brightness == Brightness.dark ? 0 : 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }
}

class ThemeService {
  static const _key = 'foodtaxi_theme_id';

  static const themes = <FoodTaxiTheme>[
    FoodTaxiTheme(
      id: 'default',
      name: 'Default',
      seed: Color(0xFF2d8f4e),
      appBar: Color(0xFF2d8f4e),
    ),
    FoodTaxiTheme(
      id: 'dark',
      name: 'Dark Mode',
      seed: Color(0xFF2d8f4e),
      brightness: Brightness.dark,
      scaffold: Color(0xFF1E1E1E),
      appBar: Color(0xFF252526),
    ),
    FoodTaxiTheme(
      id: 'koishi',
      name: 'Koishi Komeiji',
      seed: Color(0xFF4BA66A),
      scaffold: Color(0xFFF3FBF6),
    ),
    FoodTaxiTheme(
      id: 'satori',
      name: 'Komeiji Satori',
      seed: Color(0xFFB65A84),
      scaffold: Color(0xFFFFF5F9),
    ),
    FoodTaxiTheme(
      id: 'rin',
      name: 'Rin Kaenbyou',
      seed: Color(0xFFD6543D),
      scaffold: Color(0xFFFFF6F2),
    ),
    FoodTaxiTheme(
      id: 'utsuho',
      name: 'Utsuho Reiuji',
      seed: Color(0xFF2E7A8A),
      brightness: Brightness.dark,
      scaffold: Color(0xFF10191C),
      appBar: Color(0xFF193940),
    ),
  ];

  static final selectedThemeId = ValueNotifier<String>('default');

  static FoodTaxiTheme get selectedTheme => themes.firstWhere(
        (theme) => theme.id == selectedThemeId.value,
        orElse: () => themes.first,
      );

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    if (themes.any((theme) => theme.id == id)) {
      selectedThemeId.value = id!;
    }
  }

  static Future<void> setTheme(String id) async {
    if (!themes.any((theme) => theme.id == id)) return;
    selectedThemeId.value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
  }
}
