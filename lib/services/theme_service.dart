import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  final Color? primary;
  final Color? onPrimary;
  final Color? primaryContainer;
  final Color? onPrimaryContainer;
  final Color? secondary;
  final Color? onSecondary;
  final Color? secondaryContainer;
  final Color? onSecondaryContainer;
  final Color? tertiary;
  final Color? onTertiary;
  final Color? tertiaryContainer;
  final Color? onTertiaryContainer;
  final Color? surface;
  final Color? onSurface;
  final Color? surfaceVariant;
  final Color? onSurfaceVariant;
  final Color? outline;

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
    this.primary,
    this.onPrimary,
    this.primaryContainer,
    this.onPrimaryContainer,
    this.secondary,
    this.onSecondary,
    this.secondaryContainer,
    this.onSecondaryContainer,
    this.tertiary,
    this.onTertiary,
    this.tertiaryContainer,
    this.onTertiaryContainer,
    this.surface,
    this.onSurface,
    this.surfaceVariant,
    this.onSurfaceVariant,
    this.outline,
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
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final scheme = baseScheme.copyWith(
      primary: primary ?? baseScheme.primary,
      onPrimary: onPrimary ?? _contrastColor(primary ?? baseScheme.primary),
      primaryContainer: primaryContainer ?? baseScheme.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ??
          _contrastColor(primaryContainer ?? baseScheme.primaryContainer),
      secondary: secondary ?? baseScheme.secondary,
      onSecondary:
          onSecondary ?? _contrastColor(secondary ?? baseScheme.secondary),
      secondaryContainer: secondaryContainer ?? baseScheme.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ??
          _contrastColor(secondaryContainer ?? baseScheme.secondaryContainer),
      tertiary: tertiary ?? baseScheme.tertiary,
      onTertiary: onTertiary ?? _contrastColor(tertiary ?? baseScheme.tertiary),
      tertiaryContainer: tertiaryContainer ?? baseScheme.tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer ??
          _contrastColor(tertiaryContainer ?? baseScheme.tertiaryContainer),
      surface: surface ?? scaffold ?? baseScheme.surface,
      onSurface:
          onSurface ?? _contrastColor(surface ?? scaffold ?? baseScheme.surface),
      surfaceContainerHighest:
          surfaceVariant ?? baseScheme.surfaceContainerHighest,
      onSurfaceVariant: onSurfaceVariant ??
          _mutedContrastColor(surfaceVariant ?? baseScheme.surfaceContainerHighest),
      outline: outline ?? baseScheme.outline,
    );

    final background = scaffold ?? scheme.surface;
    final appBarColor = appBar ?? scheme.primary;
    final navigationColor = navBar ?? scheme.surface;

    final selectedNavIconColor = selectedIcon ?? _contrastColor(navigationColor);
    final unselectedNavIconColor =
        unselectedIcon ?? _mutedContrastColor(navigationColor);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,

      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        foregroundColor: _contrastColor(appBarColor),
        iconTheme: IconThemeData(
          color: _contrastColor(appBarColor),
        ),
        actionsIconTheme: IconThemeData(
          color: _contrastColor(appBarColor),
        ),
        elevation: 0,
        centerTitle: false,
      ),

      iconTheme: IconThemeData(
        color: scheme.onSurface,
      ),

      cardTheme: CardThemeData(
        color: brightness == Brightness.dark
            ? surface ?? const Color(0xFF252526)
            : scheme.surface,
        elevation: brightness == Brightness.dark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondaryContainer,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: scheme.onSecondaryContainer),
        secondaryLabelStyle: TextStyle(color: scheme.onPrimaryContainer),
        checkmarkColor: scheme.onPrimaryContainer,
        iconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        side: BorderSide(color: scheme.outline.withAlpha(80)),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        iconColor: scheme.onSurface,
        textStyle: TextStyle(color: scheme.onSurface),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navigationColor,
        indicatorColor: selectedNavIconColor.withAlpha(36),
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
        backgroundColor: scheme.tertiary,
        foregroundColor: scheme.onTertiary,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
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
            ? scheme.surfaceContainerHighest
            : Colors.white,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withAlpha(170)),
        prefixIconColor: scheme.primary,
        suffixIconColor: scheme.primary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withAlpha(70)),
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
  static const _legacyKey = 'foodtaxi_theme_id';
  static const _keyPrefix = 'foodtaxi_theme_id_';

  static const themes = <FoodTaxiTheme>[
    FoodTaxiTheme(
      id: 'default',
      name: 'Default',
      seed: Color(0xFF2D8F4E),
      primary: Color(0xFF2D8F4E),
      secondary: Color(0xFF66A87A),
      tertiary: Color(0xFFE6B43C),
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
      surface: Color(0xFF252526),
      surfaceVariant: Color(0xFF303134),
      appBar: Color(0xFF252526),
      navBar: Color(0xFF252526),
      primary: Color(0xFF7DDA9B),
      secondary: Color(0xFF8AB4F8),
      tertiary: Color(0xFFFDD663),
      selectedIcon: Color(0xFFFFFFFF),
      unselectedIcon: Color(0xFFC9D1D9),
    ),

    FoodTaxiTheme(
      id: 'koishi',
      name: 'Koishi Komeiji',
      seed: Color(0xFF7B2CFF),

      primary: Color(0xFF6D35D8),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE8DDFF),
      onPrimaryContainer: Color(0xFF26104D),

      secondary: Color(0xFF45A857),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFD9F8D8),
      onSecondaryContainer: Color(0xFF083813),

      tertiary: Color(0xFFFFC20A),
      onTertiary: Color(0xFF2A1B00),
      tertiaryContainer: Color(0xFFFFE7A3),
      onTertiaryContainer: Color(0xFF3B2500),

      scaffold: Color(0xFFF7F1FF),
      surface: Color(0xFFFFFBFF),
      surfaceVariant: Color(0xFFE8DFF5),
      onSurface: Color(0xFF1D102D),
      onSurfaceVariant: Color(0xFF5F5374),
      outline: Color(0xFF8B78AA),

      appBar: Color(0xFF4B168C),
      navBar: Color(0xFF2B155B),
      selectedIcon: Color(0xFFFFC20A),
      unselectedIcon: Color(0xFFB8FFBC),
    ),

    FoodTaxiTheme(
      id: 'satori',
      name: 'Satori Komeiji',
      seed: Color(0xFFD94C9A),

      primary: Color(0xFFD94C9A),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFD8EA),
      onPrimaryContainer: Color(0xFF4A0B2E),

      secondary: Color(0xFFD83246),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFFD9DE),
      onSecondaryContainer: Color(0xFF4A0711),

      tertiary: Color(0xFF3D7BFF),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFDCE6FF),
      onTertiaryContainer: Color(0xFF001A4D),

      scaffold: Color(0xFFFFF4FA),
      surface: Color(0xFFFFFBFF),
      surfaceVariant: Color(0xFFF5DCE8),
      onSurface: Color(0xFF2A101B),
      onSurfaceVariant: Color(0xFF725567),
      outline: Color(0xFFA87891),

      appBar: Color(0xFF8F1F5D),
      navBar: Color(0xFF45142D),
      selectedIcon: Color(0xFF7EB6FF),
      unselectedIcon: Color(0xFFFFA9C7),
    ),

    FoodTaxiTheme(
      id: 'rin',
      name: 'Rin Kaenbyou',

      // deep hellfire red
      seed: Color(0xFFD91E18),

      brightness: Brightness.dark,

      // red/orange hair + fire
      primary: Color(0xFFD91E18),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFF4A0A08),
      onPrimaryContainer: Color(0xFFFFB4A8),

      // teal dress accents
      secondary: Color(0xFF2FA7A0),
      onSecondary: Color(0xFF001F1D),
      secondaryContainer: Color(0xFF103A37),
      onSecondaryContainer: Color(0xFF8FF5ED),

      // blue ghost flames
      tertiary: Color(0xFF4B6CFF),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFF1B2A73),
      onTertiaryContainer: Color(0xFFC8D2FF),

      scaffold: Color(0xFF0F0A0A),
      surface: Color(0xFF171111),
      surfaceVariant: Color(0xFF241919),

      onSurface: Color(0xFFF5EAEA),
      onSurfaceVariant: Color(0xFFC9B2B2),

      outline: Color(0xFF7D5A5A),

      // darker crimson top bar
      appBar: Color(0xFF3B0908),

      // near-black/navy inspired by dress
      navBar: Color(0xFF101522),

      // glowing orange-yellow active
      selectedIcon: Color(0xFFFF9A1F),

      // ghost-blue inactive
      unselectedIcon: Color(0xFF7EA2FF),
    ),

    FoodTaxiTheme(
      id: 'utsuho',
      name: 'Utsuho Reiuji',
      seed: Color(0xFFC8FF00),
      brightness: Brightness.dark,

      // radioactive green
      primary: Color(0xFFC8FF00),
      onPrimary: Color(0xFF151900),
      primaryContainer: Color(0xFF354600),
      onPrimaryContainer: Color(0xFFE6FF73),

      // nuclear yellow
      secondary: Color(0xFFFFF200),
      onSecondary: Color(0xFF1D1B00),
      secondaryContainer: Color(0xFF4A4500),
      onSecondaryContainer: Color(0xFFFFF86A),

      // bring back her blue
      tertiary: Color(0xFF2E7A8A),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFF193940),
      onTertiaryContainer: Color(0xFF9BE7F5),

      scaffold: Color(0xFF07100A),
      surface: Color(0xFF101A12),
      surfaceVariant: Color(0xFF1D2C20),
      onSurface: Color(0xFFEAF7E9),
      onSurfaceVariant: Color(0xFFB9D2B8),
      outline: Color(0xFF6E8D68),

      appBar: Color(0xFF142400),
      navBar: Color(0xFF071400),

      selectedIcon: Color(0xFFC8FF00),
      unselectedIcon: Color(0xFF5FA8FF),
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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      selectedThemeId.value = 'default';
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('$_keyPrefix$userId');

    if (id == null) {
      selectedThemeId.value = 'default';
      return;
    }

    if (themes.any((theme) => theme.id == id)) {
      selectedThemeId.value = id;
    }
  }

  static Future<void> setTheme(String id) async {
    if (!themes.any((theme) => theme.id == id)) return;

    selectedThemeId.value = id;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyKey);
    await prefs.setString('$_keyPrefix$userId', id);
  }

  static Future<void> resetToDefault() async {
    selectedThemeId.value = 'default';
  }
}
