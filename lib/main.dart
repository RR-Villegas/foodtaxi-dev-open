import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'profile_page.dart';
import 'address_page.dart';
import 'notifications_page.dart';
import 'settings_page.dart';
import 'my_orders_page.dart';
import 'order_receipt_page.dart';
import 'cart_page.dart';
import 'search_page.dart';
import 'buyer_dashboard.dart';
import 'seller_page.dart';
import 'admin_dashboard.dart';
import 'seller_dashboard.dart';
import 'rider_dashboard.dart';
import 'checkout_page.dart';
import 'product_page.dart';
import 'seller_registration.dart';
import 'rider_registration.dart';
import 'application_status_page.dart';
import 'reset_password_page.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/local_storage_service.dart';
import 'services/protected_route.dart';
import 'services/theme_service.dart';
import 'terms_page.dart';
import 'pages/radio_pages.dart';
import 'widgets/product_card.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final launchedFromPasswordRecovery = AuthService.isPasswordRecoveryUri(
    Uri.base,
  );

  await Supabase.initialize(
    url: 'https://zsctswdvoknmdsimqrvr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpzY3Rzd2R2b2tubWRzaW1xcnZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0MDkyMjgsImV4cCI6MjA5MTk4NTIyOH0.9AMczePav5ftvCbhhYWxBaquUFK1Nrmgx1FbUZKpci8',
  );
  await LocalStorageService.removePersistedPasswords();
  await ThemeService.load();
  if (launchedFromPasswordRecovery) {
    AuthService.startPasswordRecoverySession();
  }

  runApp(MyApp(launchedFromPasswordRecovery: launchedFromPasswordRecovery));
}

class MyApp extends StatefulWidget {
  final bool launchedFromPasswordRecovery;

  const MyApp({super.key, this.launchedFromPasswordRecovery = false});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.launchedFromPasswordRecovery ||
        AuthService.isPasswordRecoveryUri(Uri.base)) {
      AuthService.startPasswordRecoverySession();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/reset-password',
          (route) => false,
        );
      });
    }
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event != AuthChangeEvent.passwordRecovery) return;
      AuthService.startPasswordRecoverySession();
      appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/reset-password',
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.selectedThemeId,
      builder: (context, themeId, child) {
        final isPasswordRecovery =
            AuthService.isPasswordRecoverySession ||
            AuthService.isPasswordRecoveryUri(Uri.base);
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'FoodTaxi Omega',
          theme: ThemeService.selectedTheme.toThemeData(),
          scrollBehavior: const AppScrollBehavior(),
          debugShowCheckedModeBanner: false,
          initialRoute: isPasswordRecovery ? '/reset-password' : '/',
          routes: {
            '/': (context) => const MyHomePage(title: 'FoodTaxi Omega'),
            '/login': (context) => const LoginPage(),
            '/signup': (context) => const SignupPage(),
            '/reset-password': (context) => const ResetPasswordPage(),
            '/profile': (context) => ProtectedRoute(
              protection: RouteProtection.authenticated,
              child: const ProfilePage(),
            ),
            '/addresses': (context) => ProtectedRoute(
              protection: RouteProtection.authenticated,
              child: const AddressPage(),
            ),
            '/notifications': (context) => ProtectedRoute(
              protection: RouteProtection.authenticated,
              child: const NotificationsPage(),
            ),
            '/settings': (context) => ProtectedRoute(
              protection: RouteProtection.authenticated,
              child: const SettingsPage(),
            ),
            '/terms': (context) => const TermsPage(),
            '/cart': (context) => ProtectedRoute(
              protection: RouteProtection.authenticated,
              child: const CartPage(),
            ),
            '/my-orders': (context) => ProtectedRoute(
              protection: RouteProtection.buyerOnly,
              child: const MyOrdersPage(),
            ),
            '/order-receipt': (context) {
              final order = ModalRoute.of(context)?.settings.arguments;
              return ProtectedRoute(
                protection: RouteProtection.buyerOnly,
                child: OrderReceiptPage(
                  order: order is Map<String, dynamic>
                      ? order
                      : <String, dynamic>{},
                ),
              );
            },
            '/search': (context) => const SearchPage(),
            '/buyer-dashboard': (context) => ProtectedRoute(
              protection: RouteProtection.buyerOnly,
              child: const BuyerDashboard(),
            ),
            '/seller-dashboard': (context) => ProtectedRoute(
              protection: RouteProtection.sellerOnly,
              child: const SellerDashboard(),
            ),
            '/rider-dashboard': (context) => ProtectedRoute(
              protection: RouteProtection.riderOnly,
              child: RiderDashboard(),
            ),
            '/admin-dashboard': (context) => ProtectedRoute(
              protection: RouteProtection.adminOnly,
              child: const AdminDashboard(),
            ),
            '/checkout': (context) => ProtectedRoute(
              protection: RouteProtection.buyerOnly,
              child: const CheckoutPage(),
            ),
            '/radio': (context) => ProtectedRoute(
              protection: RouteProtection.authenticated,
              child: const RadioPage(),
            ),
            '/seller-registration': (context) => const SellerRegistrationPage(),
            '/rider-registration': (context) => const RiderRegistrationPage(),
            '/application-status': (context) {
              final role =
                  ModalRoute.of(context)?.settings.arguments?.toString() ??
                  'seller';
              return ApplicationStatusPage(role: role);
            },
          },
          onGenerateRoute: (settings) {
            if (settings.name?.startsWith('/product/') ?? false) {
              final productId = settings.name!.split('/').last;
              return MaterialPageRoute(
                builder: (context) => ProductPage(productId: productId),
              );
            }
            if (settings.name?.startsWith('/seller/') ?? false) {
              final storeId = settings.name!.split('/').last;
              return MaterialPageRoute(
                builder: (context) => SellerPage(storeId: storeId),
              );
            }
            return null;
          },
        );
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _productsChannel;
  bool _isRefreshingRealtime = false;

  Map<String, List<Map<String, dynamic>>> foodCategories = {};
  bool isLoadingProducts = true;
  final _navSearchController = TextEditingController();
  final _navSearchFocusNode = FocusNode();

  // Product categories mapping
  static const Map<String, String> categoryNames = {
    'Baking Supplies & Ingredients': '🧁 Baking',
    'Coffee, Tea & Beverages': '☕ Beverages',
    'Snacks & Candy': '🍬 Snacks',
    'Specialty Foods & International Cuisine': '🌍 Specialty',
    'Organic and Health Foods': '🥗 Health Foods',
    'Meal Kits & Prepped Foods': '🍱 Meal Kits',
    'Fresh Produce': '🥬 Fresh Produce',
    'Meat, Seafood & Poultry': '🥩 Meat & Seafood',
    'Dairy, Eggs & Chilled Goods': '🥚 Dairy & Eggs',
    'Frozen Foods': '❄️ Frozen',
    'Condiments, Sauces & Spices': '🌶️ Sauces & Spices',
    'Rice, Grains & Pasta': '🍚 Grains',
    'Ready-to-Eat Meals': '🍽️ Ready Meals',
    'Local Delicacies': '🏡 Local Delicacies',
  };

  @override
  void initState() {
    super.initState();
    _redirectLoggedInUser();
    _loadProductsFromDatabase();
    _navSearchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _setupRealtime();
  }

  void _setupRealtime() {
    _productsChannel = _supabase
        .channel('anon-home-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product',
          callback: (_) => _handleRealtimeRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product_variant',
          callback: (_) => _handleRealtimeRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product_discount',
          callback: (_) => _handleRealtimeRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product_review',
          callback: (_) => _handleRealtimeRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'store',
          callback: (_) => _handleRealtimeRefresh(),
        )
        .subscribe();
  }

  Future<void> _handleRealtimeRefresh() async {
    if (_isRefreshingRealtime) return;

    _isRefreshingRealtime = true;

    try {
      await _loadProductsFromDatabase();
    } catch (e) {
      debugPrint('Anon realtime refresh error: $e');
    } finally {
      _isRefreshingRealtime = false;
    }
  }

  @override
  void dispose() {
    _productsChannel?.unsubscribe();
    _navSearchFocusNode.dispose();
    _navSearchController.dispose();
    super.dispose();
  }

  void _openSearch({bool filters = false}) {
    Navigator.pushNamed(
      context,
      '/search',
      arguments: {
        'query': _navSearchController.text.trim(),
        'showFilters': filters,
      },
    );
  }

  Future<void> _redirectLoggedInUser() async {
    if (AuthService.isPasswordRecoverySession) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/reset-password',
        (route) => false,
      );
      return;
    }
    if (!AuthService.isAuthenticated()) return;
    final accountType = await DatabaseService.getCurrentAccountType();
    if (!mounted || accountType == null) return;

    final route = switch (accountType.toLowerCase()) {
      'admin' => '/admin-dashboard',
      'seller' => '/seller-dashboard',
      'rider' => '/rider-dashboard',
      _ => '/buyer-dashboard',
    };

    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  Future<void> _loadProductsFromDatabase() async {
    try {
      final products = await DatabaseService.fetchProducts();
      final trending = await DatabaseService.getTrendingProducts();

      // Group products by category
      Map<String, List<Map<String, dynamic>>> grouped = {};
      if (trending.isNotEmpty) {
        grouped['Trending'] = trending;
      }

      for (var product in products) {
        final category = product['category'] ?? 'Other';
        final displayName = categoryNames[category] ?? category;

        if (!grouped.containsKey(displayName)) {
          grouped[displayName] = [];
        }
        grouped[displayName]!.add(product);
      }

      if (!mounted) return;
      setState(() {
        foodCategories = grouped;
        isLoadingProducts = false;
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (!mounted) return;
      setState(() => isLoadingProducts = false);
    }
  }

  Widget heroSection() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFlandre = ThemeService.selectedThemeId.value == 'flandre';

    final gradient = isFlandre
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF050505),
              Color(0xFF2B1A2E),
              Color(0xFF76283C),
              Color(0xFFB83B54),
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                Colors.black.withAlpha(isDark ? 70 : 35),
                scheme.primary,
              ),
              Color.alphaBlend(
                Colors.black.withAlpha(isDark ? 110 : 55),
                scheme.primaryContainer,
              ),
            ],
          );

    final titleColor = Colors.white;
    final subtitleColor = isFlandre
        ? const Color(0xFFFFD9E2)
        : Colors.white.withAlpha(230);
    final bodyColor = isFlandre
        ? const Color(0xFFFFEAF0)
        : Colors.white.withAlpha(215);

    final textShadow = const [
      Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 2)),
    ];

    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: isFlandre ? 0.18 : (isDark ? 0.12 : 0.07),
              child: Image.asset('assets/images/tacos.jpg', fit: BoxFit.cover),
            ),
          ),
          Container(
            color: Colors.black.withAlpha(isFlandre ? 85 : (isDark ? 55 : 35)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Your Philippine Marketplace",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: textShadow,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "for Anything Food-related",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 24,
                    fontWeight: isFlandre ? FontWeight.w400 : FontWeight.w300,
                    shadows: textShadow,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Shop ingredients and foods delivered from sellers in every angle, to your location.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 16,
                      shadows: textShadow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerSearchBar({
    required TextEditingController controller,
    String hintText = 'Search products',
    VoidCallback? onFilter,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 46,
      width: double.infinity,
      child: TextField(
        controller: controller,
        focusNode: _navSearchFocusNode,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          prefixIcon: Icon(Icons.search, color: scheme.primary),
          suffixIcon: IconButton(
            tooltip: 'Filters',
            onPressed: onFilter,
            icon: Icon(Icons.tune, color: scheme.primary),
          ),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _openSearch(),
      ),
    );
  }

  Future<void> _openSignupMenu(BuildContext context) async {
    final value = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(999, 80, 8, 0),
      items: const [
        PopupMenuItem(value: 'buyer', child: Text('Buy Products')),
        PopupMenuItem(value: 'seller', child: Text('Become Seller')),
        PopupMenuItem(value: 'rider', child: Text('Become Rider')),
      ],
    );

    if (value == null || !context.mounted) return;

    final route = switch (value) {
      'seller' => '/seller-registration',
      'rider' => '/rider-registration',
      _ => '/signup',
    };

    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            if (!_navSearchFocusNode.hasFocus) ...[
              const Flexible(
                child: Text(
                  'FoodTaxi Omega',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _centerSearchBar(
                controller: _navSearchController,
                onFilter: () => _openSearch(filters: true),
              ),
            ),
          ],
        ),
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              final showText = MediaQuery.sizeOf(context).width >= 700;

              final button = showText
                  ? TextButton.icon(
                      onPressed: () => _openSignupMenu(context),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Sign Up'),
                    )
                  : IconButton(
                      tooltip: 'Sign Up',
                      onPressed: () => _openSignupMenu(context),
                      icon: const Icon(Icons.person_add),
                    );

              return button;
            },
          ),

          _navSearchFocusNode.hasFocus
              ? IconButton(
                  tooltip: 'Sign In',
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  icon: const Icon(Icons.login),
                )
              : TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Sign In'),
                ),

          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            heroSection(),
            const SizedBox(height: 20),

            isLoadingProducts
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  )
                : foodCategories.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No products available'),
                  )
                : Column(
                    children: foodCategories.entries.map<Widget>((entry) {
                      final categoryKey = entry.key;
                      final categoryValue = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          sectionTitle(categoryKey),
                          horizontalFoodList(categoryValue),
                        ],
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget horizontalFoodList(List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 306,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final productId = item['product_id']?.toString();

          Future<void> openProduct() async {
            if (productId == null) return;
            await DatabaseService.trackProductClick(
              productId: productId,
              storeId: item['store_id']?.toString(),
            );
            if (!context.mounted) return;
            Navigator.pushNamed(context, '/product/$productId');
          }

          return Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 12),
            child: SizedBox(
              width: 174,
              height: 294,
              child: ProductCard(
                product: item,
                onTap: productId == null ? null : openProduct,
                onAction: productId == null ? null : openProduct,
                actionLabel: 'Buy',
              ),
            ),
          );
        },
      ),
    );
  }
}
