import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'cart_model.dart';

class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  final _supabase = Supabase.instance.client;
  final _navSearchController = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  Map<String, List<Map<String, dynamic>>> _groupedProducts = {};
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingProfile = true;

  int get _cartLength => CartModel.length;

  @override
  void dispose() {
    _navSearchController.dispose();
    super.dispose();
  }

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
    _fetchProfile();
    _fetchProducts();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoadingProfile = false);
        return;
      }
      final accountId = await DatabaseService.getCurrentAccountId();
      if (accountId != null) {
        final response = await _supabase
            .from('account')
            .select('firstname, surname, email, phone_number, profile_image_url')
            .eq('account_id', accountId)
            .maybeSingle();
        if (response != null) {
          if (!mounted) return;
          setState(() {
            _userProfile = response;
          });
        }
      }
    } catch (e) {
      print('Profile fetch error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              await AuthService.clearLoginSession();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchProducts() async {
    try {
      final products = await DatabaseService.fetchProducts();
      if (!mounted) return;
      _products = products;
      
      // Group by category with display names
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var product in _products) {
        final category = product['category'] ?? 'Other';
        final displayName = categoryNames[category] ?? category;
        
        if (!grouped.containsKey(displayName)) {
          grouped[displayName] = [];
        }
        grouped[displayName]!.add(product);
      }
      
      _groupedProducts = grouped;

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      print('Products fetch error: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget horizontalList(List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 292,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final productId = item['product_id'] as String?;

          return GestureDetector(
            onTap: productId != null
                ? () => Navigator.pushNamed(context, '/product/$productId')
                : null,
            child: Container(
              width: 170,
              margin: const EdgeInsets.only(right: 12),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.network(
                          DatabaseService.getProductImageUrl(item['main_image_url']),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/images/burger.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₱${item['price']}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Row(
                            children: [
                              Icon(Icons.star, size: 14, color: Colors.amber),
                              Icon(Icons.star, size: 14, color: Colors.amber),
                              Icon(Icons.star, size: 14, color: Colors.amber),
                              Icon(Icons.star, size: 14, color: Colors.amber),
                              Icon(Icons.star_border, size: 14, color: Colors.amber),
                              SizedBox(width: 4),
                              Text('(0)', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: productId != null
                                  ? () => Navigator.pushNamed(
                                        context,
                                        '/product/$productId',
                                      )
                                  : null,
                              child: const Text('Buy'),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSearch({bool filters = false}) {
    Navigator.pushNamed(
      context,
      '/search',
      arguments: _navSearchController.text.trim(),
    );
  }

  // ✅ HERO (UNCHANGED EXACTLY)
Widget heroSection() {
  return Container(
    height: 250,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2d8f4e),
          const Color(0xFF2d8f4e).withOpacity(0.85),
        ],
      ),
    ),
    child: Stack(
      children: [
        // faint background image (same style as main.dart)
        Positioned.fill(
          child: Opacity(
            opacity: 0.10,
            child: Image.asset(
              'assets/images/tacos.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),

        // centered content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
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
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
              ),
              SizedBox(height: 14),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Order fresh meals, snacks, and fast food favorites delivered fast to your doorstep.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text('FoodTaxi'),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _navSearchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search products',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _openSearch(),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Filters',
              onPressed: () => _openSearch(filters: true),
              icon: const Icon(Icons.filter_list),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 30, 83, 32),
        actions: [
          Center(child: Badge(
            label: Text('$_cartLength'),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () => Navigator.pushNamed(context, '/cart'),
            ),
          )),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.pushNamed(context, '/profile');
                  break;
                case 'orders':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('My Orders - Coming Soon')),
                  );
                  break;
                case 'location':
                  Navigator.pushNamed(context, '/addresses');
                  break;
                case 'settings':
                  Navigator.pushNamed(context, '/settings');
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: _userProfile != null 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_userProfile!['firstname'] ?? ''} ${_userProfile!['surname'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_userProfile!['email'] ?? '', style: const TextStyle(fontSize: 12)),
                      ],
                    )
                  : const Text('Profile'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'orders',
                child: Row(
                  children: [
                    Icon(Icons.receipt, size: 20),
                    SizedBox(width: 12),
                    Text('My Orders'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'location',
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 20),
                    SizedBox(width: 12),
                    Text('My Location'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: const Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? const Center(child: Text("Error loading products"))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      heroSection(),

                      ..._groupedProducts.entries.map((entry) {
                        return Column(
                          children: [
                            sectionTitle(entry.key),
                            horizontalList(entry.value),
                          ],
                        );
                      }),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => Navigator.pushNamed(context, '/cart'),
        child: const Icon(Icons.shopping_cart),
      ),
    );
  }
}
