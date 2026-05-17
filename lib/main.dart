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
import 'services/protected_route.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zsctswdvoknmdsimqrvr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpzY3Rzd2R2b2tubWRzaW1xcnZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0MDkyMjgsImV4cCI6MjA5MTk4NTIyOH0.9AMczePav5ftvCbhhYWxBaquUFK1Nrmgx1FbUZKpci8',
  );
  await ThemeService.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.selectedThemeId,
      builder: (context, _, __) {
        return MaterialApp(
          title: 'FoodTaxi Omega',
          theme: ThemeService.selectedTheme.toThemeData(),
          debugShowCheckedModeBanner: false,
          initialRoute: Uri.base.fragment.contains('type=recovery')
              ? '/reset-password'
              : '/',
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
        '/search': (context) => ProtectedRoute(
          protection: RouteProtection.authenticated,
          child: const SearchPage(),
        ),
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
        '/seller-registration': (context) => const SellerRegistrationPage(),
        '/rider-registration': (context) => const RiderRegistrationPage(),
        '/application-status': (context) {
          final role =
              ModalRoute.of(context)?.settings.arguments?.toString() ?? 'seller';
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
            builder: (context) => ProtectedRoute(
              protection: RouteProtection.authenticated,
              child: SellerPage(storeId: storeId),
            ),
          );
        }
            return null;
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final supabase = Supabase.instance.client;

  String status = "Checking Supabase connection...";
  Map<String, List<Map<String, dynamic>>> foodCategories = {};
  bool isLoadingProducts = true;

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
    testSupabase();
    _loadProductsFromDatabase();
  }

  Future<void> _redirectLoggedInUser() async {
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

  Future<void> testSupabase() async {
    try {
      await supabase.from('product').select().limit(1);
      if (!mounted) return;
      setState(() => status = "");
    } catch (e) {
      if (!mounted) return;
      setState(() => status = "❌ Connection Failed: $e");
    }
  }

  Future<void> _loadProductsFromDatabase() async {
    try {
      final products = await DatabaseService.fetchProducts();

      // Group products by category
      Map<String, List<Map<String, dynamic>>> grouped = {};

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

  double _rating(Map<String, dynamic> product) {
    final value = product['average_rating'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _reviewCount(Map<String, dynamic> product) {
    final value = product['review_count'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _price(Map<String, dynamic> product) {
    final value = product['price'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _stars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = rating >= index + 1;
        final half = !filled && rating > index && rating < index + 1;
        return Icon(
          filled
              ? Icons.star
              : half
                  ? Icons.star_half
                  : Icons.star_border,
          size: 14,
          color: Colors.amber,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/signup'),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Create Account'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Sign In'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // STATUS
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                status,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            // HERO
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withAlpha(204),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: Image.asset(
                        'assets/images/tacos.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Your Philippine Marketplace",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "for Specialty Foods",
                          style: TextStyle(color: Colors.white, fontSize: 24),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Shop local food, specialty goods, and pantry finds from nearby sellers.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ✅ FETCHED FOOD CATEGORIES FROM DATABASE
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

            // CTA
            Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 560;
                  final actions = [
                    _roleCta(
                      title: 'Become a Seller',
                      body: 'Grow your business with FoodTaxi Omega.',
                      buttonText: 'Start Selling',
                      icon: Icons.storefront,
                      color: Colors.amber,
                      onPressed: () =>
                          Navigator.pushNamed(context, '/seller-registration'),
                    ),
                    _roleCta(
                      title: 'Become a Rider',
                      body: 'Deliver orders and earn with FoodTaxi Omega.',
                      buttonText: 'Start Riding',
                      icon: Icons.delivery_dining,
                      color: const Color(0xFF2d8f4e),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/rider-registration'),
                    ),
                  ];

                  if (isNarrow) {
                    return Column(
                      children: [
                        actions[0],
                        const SizedBox(height: 12),
                        actions[1],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: actions[0]),
                      const SizedBox(width: 12),
                      Expanded(child: actions[1]),
                    ],
                  );
                },
              ),
            ),
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

  Widget _roleCta({
    required String title,
    required String body,
    required String buttonText,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget horizontalFoodList(List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 324,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final imageUrl = item['main_image_url'] as String?;
          final productId = item['product_id']?.toString();
          final rating = _rating(item);
          final reviewCount = _reviewCount(item);

          return GestureDetector(
            onTap: productId != null
                ? () async {
                    await DatabaseService.trackProductClick(
                      productId: productId,
                      storeId: item['store_id']?.toString(),
                    );
                    if (mounted) {
                      Navigator.pushNamed(context, '/product/$productId');
                    }
                  }
                : null,
            child: Container(
              width: 170,
              margin: const EdgeInsets.only(right: 12, bottom: 12),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: imageUrl != null
                          ? Image.network(
                              DatabaseService.getProductImageUrl(imageUrl),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                              DatabaseService.displayProductName(item['name']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      "PHP ${_price(item).toStringAsFixed(2)}",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _stars(rating),
                        const SizedBox(width: 4),
                        Text(
                          '($reviewCount)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                      child: SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: FilledButton(
                          onPressed: productId != null
                              ? () => Navigator.pushNamed(
                                    context,
                                    '/product/$productId',
                                  )
                              : null,
                          child: const Text('View'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
