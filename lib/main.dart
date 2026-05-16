import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'profile_page.dart';
import 'address_page.dart';
import 'notifications_page.dart';
import 'settings_page.dart';
import 'cart_page.dart';
import 'search_page.dart';
import 'buyer_dashboard.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zsctswdvoknmdsimqrvr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpzY3Rzd2R2b2tubWRzaW1xcnZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0MDkyMjgsImV4cCI6MjA5MTk4NTIyOH0.9AMczePav5ftvCbhhYWxBaquUFK1Nrmgx1FbUZKpci8',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodTaxi Omega',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2d8f4e)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute:
          Uri.base.fragment.contains('type=recovery') ? '/reset-password' : '/',
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
            builder: (context) => ProtectedRoute(
              protection: RouteProtection.authenticated,
              child: ProductPage(productId: productId),
            ),
          );
        }
        return null;
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
      setState(() => status = "");
    } catch (e) {
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

      setState(() {
        foodCategories = grouped;
        isLoadingProducts = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() => isLoadingProducts = false);
    }
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
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
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
                          "Delivering fresh, local, and international goods right to your door.",
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
              child: Column(
                children: [
                  const Text(
                    "Become a Seller",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Grow your business with FoodTaxi Omega. Apply now!",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/seller-registration'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                    ),
                    child: const Text("Start Selling"),
                  ),
                ],
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

  Widget horizontalFoodList(List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final imageUrl = item['main_image_url'] as String?;
          final productId = item['product_id'] as String?;

          return GestureDetector(
            onTap: productId != null
                ? () => Navigator.pushNamed(context, '/product/$productId')
                : null,
            child: Container(
              width: 150,
              margin: const EdgeInsets.all(10),
              child: Card(
                child: Column(
                  children: [
                    Expanded(
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
                        item['name'] ?? 'Product',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      "₱${item['price']?.toStringAsFixed(2) ?? 'N/A'}",
                      style: const TextStyle(color: Colors.green),
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
