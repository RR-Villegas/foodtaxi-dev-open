import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FoodTaxiTheme {
  final String id;
  final String name;
  final Color seed;
  final Brightness brightness;
  final Color? scaffold;
  final Color? appBar;
  final Color? navBar;
  final Color? selectedIcon;
  final Color? unselectedIcon;

  const FoodTaxiTheme({
    required this.id,
    required this.name,
    required this.seed,
    this.brightness = Brightness.light,
    this.scaffold,
    this.appBar,
    this.navBar,
    this.selectedIcon,
    this.unselectedIcon,
  });

  Color _contrastColor(Color background) {
    final luminance = background.computeLuminance();

    if (luminance > 0.5) {
      return const Color(0xFF111111);
    }

    return const Color(0xFFFFFFFF);
  }

  Color _mutedContrastColor(Color background) {
    final luminance = background.computeLuminance();

    if (luminance > 0.5) {
      return const Color(0xFF555555);
    }

    return const Color(0xFFC9D1D9);
  }

  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final background = scaffold ?? scheme.surface;
    final appBarColor = appBar ?? scheme.primary;
    final navigationColor = navBar ?? scheme.surface;

    final selectedNavIconColor = selectedIcon ?? _contrastColor(navigationColor);
    final unselectedNavIconColor =
        unselectedIcon ?? _mutedContrastColor(navigationColor);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,

      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        foregroundColor: _contrastColor(appBarColor),
        elevation: 0,
        centerTitle: false,
      ),

      iconTheme: IconThemeData(
        color: _contrastColor(background),
      ),

      cardTheme: CardThemeData(
        color: brightness == Brightness.dark
            ? const Color(0xFF252526)
            : scheme.surface,
        elevation: brightness == Brightness.dark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navigationColor,
        indicatorColor: selectedNavIconColor.withOpacity(0.14),
        elevation: 0,

        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final isSelected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: isSelected ? selectedNavIconColor : unselectedNavIconColor,
          );
        }),

        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final isSelected = states.contains(WidgetState.selected);

          return TextStyle(
            color: isSelected ? selectedNavIconColor : unselectedNavIconColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navigationColor,
        selectedItemColor: selectedNavIconColor,
        unselectedItemColor: unselectedNavIconColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: _contrastColor(scheme.primary),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: _contrastColor(scheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 2,
          ),
        ),
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
      seed: Color(0xFF2D8F4E),
      appBar: Color(0xFF2D8F4E),
      navBar: Color(0xFFFFFFFF),
      selectedIcon: Color(0xFF111111),
      unselectedIcon: Color(0xFF555555),
    ),

    FoodTaxiTheme(
      id: 'dark',
      name: 'Dark Mode',
      seed: Color(0xFF2D8F4E),
      brightness: Brightness.dark,
      scaffold: Color(0xFF1E1E1E),
      appBar: Color(0xFF252526),
      navBar: Color(0xFF252526),
      selectedIcon: Color(0xFFFFFFFF),
      unselectedIcon: Color(0xFFC9D1D9),
    ),

    FoodTaxiTheme(
      id: 'koishi',
      name: 'Koishi Komeiji',

      // dominant psychic purple
      seed: Color(0xFF7715EA),

      // pastel subconscious background
      scaffold: Color(0xFFF8F4FF),

      // darker purple navbar/appbar
      appBar: Color(0xFF4B0E91),
      navBar: Color(0xFF2A165A),

      // triadic highlight logic
      selectedIcon: Color(0xFFE8FF6A), // lime-yellow
      unselectedIcon: Color(0xFFC8BFE7),
    ),

    FoodTaxiTheme(
      id: 'satori',
      name: 'Satori Komeiji',

      // psychic rose-magenta
      seed: Color(0xFFB13E8B),

      scaffold: Color(0xFFFFF5FB),

      appBar: Color(0xFF6E214E),
      navBar: Color(0xFF40192D),

      // opposite-spectrum accent
      selectedIcon: Color(0xFF8FFFE0),
      unselectedIcon: Color(0xFFD8AFC4),
    ),

    FoodTaxiTheme(
      id: 'rin',
      name: 'Rin Kaenbyou',
      seed: Color(0xFFD6543D),
      scaffold: Color(0xFFFFF6F2),
      appBar: Color(0xFFD6543D),
      navBar: Color(0xFF3B1E16),
      selectedIcon: Color(0xFFFFFFFF),
      unselectedIcon: Color(0xFFC9D1D9),
    ),

    FoodTaxiTheme(
      id: 'utsuho',
      name: 'Utsuho Reiuji',
      seed: Color(0xFF2E7A8A),
      brightness: Brightness.dark,
      scaffold: Color(0xFF10191C),
      appBar: Color(0xFF193940),
      navBar: Color(0xFF101828),
      selectedIcon: Color(0xFFFFFFFF),
      unselectedIcon: Color(0xFFC9D1D9),
    ),
  ];

  static final selectedThemeId = ValueNotifier<String>('default');

  static FoodTaxiTheme get selectedTheme {
    return themes.firstWhere(
      (theme) => theme.id == selectedThemeId.value,
      orElse: () => themes.first,
    );
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);

    if (id == null) return;

    if (themes.any((theme) => theme.id == id)) {
      selectedThemeId.value = id;
    }
  }

  static Future<void> setTheme(String id) async {
    if (!themes.any((theme) => theme.id == id)) return;

    selectedThemeId.value = id;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
  }
}