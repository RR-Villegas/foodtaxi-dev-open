import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'cart_model.dart';
import 'widgets/adaptive_menu_item.dart';

class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  final _supabase = Supabase.instance.client;
  final _navSearchController = TextEditingController();
  final _navSearchFocusNode = FocusNode();

  List<Map<String, dynamic>> _products = [];
  Map<String, List<Map<String, dynamic>>> _groupedProducts = {};
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoggingOut = false;

  @override
  void dispose() {
    _navSearchController.dispose();
    _navSearchFocusNode.dispose();
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
    _navSearchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchProfile();
    _fetchProducts();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
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
      debugPrint('Profile fetch error: $e');
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
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
              if (_isLoggingOut) return;
              setState(() => _isLoggingOut = true);
              final navigator = Navigator.of(context);
              Navigator.pop(context); // close dialog
              await AuthService.clearLoginSession();
              if (!mounted || !navigator.mounted) return;
              navigator.pushNamedAndRemoveUntil('/login', (route) => false);
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
      final trending = await DatabaseService.getTrendingProducts();
      if (!mounted) return;
      _products = products;

      // Group by category with display names
      Map<String, List<Map<String, dynamic>>> grouped = {};
      if (trending.isNotEmpty) {
        grouped['Trending'] = trending;
      }
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
      debugPrint('Products fetch error: $e');
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

  Widget horizontalList(List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 306,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final productId = item['product_id'] as String?;
          final rating = _rating(item);
          final reviewCount = _reviewCount(item);

          return GestureDetector(
            onTap: productId != null
                ? () async {
                    await DatabaseService.trackProductClick(
                      productId: productId,
                      storeId: item['store_id']?.toString(),
                    );
                    if (!context.mounted) return;
                    Navigator.pushNamed(context, '/product/$productId');
                  }
                : null,
            child: Container(
              width: 170,
              margin: const EdgeInsets.only(right: 12, bottom: 12),
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
                          DatabaseService.getProductImageUrl(
                            item['main_image_url'],
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Image.asset(
                            'assets/images/burger.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                            DatabaseService.displayProductName(item['name']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                            const SizedBox(height: 2),
                            Text(
                            '₱${item['price']}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                            const SizedBox(height: 2),
                            Row(
                            children: [
                              _stars(rating),
                              const SizedBox(width: 4),
                              Text(
                                '($reviewCount)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                            const Spacer(),
                            SizedBox(
                            width: double.infinity,
                            height: 34,
                            child: FilledButton(
                              onPressed: productId != null
                                  ? () async {
                                      await DatabaseService.trackProductClick(
                                        productId: productId,
                                        storeId: item['store_id']?.toString(),
                                      );
                                      if (!context.mounted) return;
                                      Navigator.pushNamed(
                                        context,
                                        '/product/$productId',
                                      );
                                    }
                                  : null,
                              child: const Text('Buy'),
                            ),
                          ),
                          ],
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

  void _openSearch({bool filters = false}) {
    Navigator.pushNamed(
      context,
      '/search',
      arguments: _navSearchController.text.trim(),
    );
  }

  // ✅ HERO (UNCHANGED EXACTLY)
Widget heroSection() {
  final scheme = Theme.of(context).colorScheme;

  return Container(
    height: 250,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          scheme.primary,
          scheme.primary.withAlpha(217),
        ],
      ),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.10,
            child: Image.asset(
              'assets/images/tacos.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Your Philippine Marketplace",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "for Specialty Foods",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Shop local food, specialty goods, and pantry finds delivered from nearby sellers.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onPrimary,
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
            const Text('FoodTaxi Omega'),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _navSearchFocusNode.hasFocus ? 140 : 70,
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _navSearchController,
                  focusNode: _navSearchFocusNode,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText:
                        _navSearchFocusNode.hasFocus ? 'Search products' : 'Search',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
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
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => _openSearch(filters: true),
            icon: const Icon(Icons.filter_list),
          ),
          Center(
            child: ValueListenableBuilder<int>(
              valueListenable: CartModel.itemCountNotifier,
              builder: (context, count, child) {
                return Badge(
                  label: Text('$count'),
                  child: child,
                );
              },
              child: IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => Navigator.pushNamed(context, '/cart'),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.pushNamed(context, '/profile');
                  break;
                case 'orders':
                  Navigator.pushNamed(context, '/my-orders');
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
                  ? SizedBox(
                      width: 220,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage:
                                (_userProfile!['profile_image_url']?.toString() ?? '').isNotEmpty
                                    ? NetworkImage(
                                        DatabaseService.getProfileImageUrl(
                                          _userProfile!['profile_image_url'].toString(),
                                        ),
                                      )
                                    : null,
                            child: (_userProfile!['profile_image_url']?.toString() ?? '').isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_userProfile!['firstname'] ?? ''} ${_userProfile!['surname'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _userProfile!['email'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Text('Profile'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'profile',
                child: AdaptiveMenuItem(icon: Icons.person, title: 'Profile'),
              ),
              const PopupMenuItem<String>(
                value: 'orders',
                child: AdaptiveMenuItem(icon: Icons.receipt, title: 'My Orders'),
              ),
              const PopupMenuItem<String>(
                value: 'location',
                child: AdaptiveMenuItem(icon: Icons.location_on, title: 'My Location'),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: AdaptiveMenuItem(icon: Icons.settings, title: 'Settings'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: AdaptiveMenuItem(icon: Icons.logout, title: 'Logout'),
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
        onPressed: () => Navigator.pushNamed(context, '/cart'),
        child: const Icon(Icons.shopping_cart),
      ),
    );
  }
}
