import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'cart_model.dart';
import 'widgets/adaptive_menu_item.dart';
import 'services/theme_service.dart';
import 'widgets/notification_bell.dart';
import 'widgets/product_card.dart';

class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  final _supabase = Supabase.instance.client;
  final _navSearchController = TextEditingController();
  final _navSearchFocusNode = FocusNode();

  RealtimeChannel? _productsChannel;
  bool _isRefreshingRealtime = false;

  List<Map<String, dynamic>> _products = [];
  Map<String, List<Map<String, dynamic>>> _groupedProducts = {};
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoggingOut = false;

  @override
  void dispose() {
    _productsChannel?.unsubscribe();
    _navSearchFocusNode.dispose();
    _navSearchController.dispose();

    super.dispose();
  }

  // Product categories mapping
  static const Map<String, String> categoryNames = {
    'Baking Supplies & Ingredients': '🧁 Baking',
    'Coffee, Tea & Beverages': '☕ Beverages',
    'Condiments, Sauces & Spices': '🌶️ Sauces & Spices',
    'Dairy, Eggs & Chilled Goods': '🥚 Dairy & Eggs',
    'Fresh Produce': '🥬 Fresh Produce',
    'Frozen Foods': '❄️ Frozen',
    'Local Delicacies': '🏡 Local Delicacies',
    'Meal Kits & Prepped Foods': '🍱 Meal Kits',
    'Meat, Seafood & Poultry': '🥩 Meat & Seafood',
    'Organic and Health Foods': '🥗 Health Foods',
    'Other': '📦 Other',
    'Ready-to-Eat Meals': '🍽️ Ready Meals',
    'Rice, Grains & Pasta': '🍚 Grains',
    'Snacks & Candy': '🍬 Snacks',
    'Specialty Foods & International Cuisine': '🌍 Specialty',
  };

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchProducts();
    _navSearchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _setupRealtime();
  }

  void _setupRealtime() {
    _productsChannel = _supabase
        .channel('buyer-dashboard-realtime')
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
      await _fetchProducts();
    } catch (e) {
      debugPrint('Realtime refresh error: $e');
    } finally {
      _isRefreshingRealtime = false;
    }
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
            .select(
              'firstname, surname, email, phone_number, profile_image_url',
            )
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
        grouped['🔥 Trending'] = trending;
      }
      for (var product in _products) {
        final category = product['category']?.toString().trim();
        final displayName =
            categoryNames[category == null || category.isEmpty
                ? 'Other'
                : category] ??
            '📦 Other';

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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
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

  Widget _centerSearchBar({
    required TextEditingController controller,
    String hintText = 'Search products',
    VoidCallback? onFilter,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 42,
      width: double.infinity,
      child: TextField(
        controller: controller,
        focusNode: _navSearchFocusNode,
        textInputAction: TextInputAction.search,
        style: const TextStyle(height: 1.0),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          filled: true,
          fillColor: scheme.surface,
          prefixIcon: Icon(Icons.search, color: scheme.primary),
          suffixIcon: IconButton(
            tooltip: 'Filters',
            onPressed: onFilter,
            icon: Icon(Icons.tune, color: scheme.primary),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _openSearch(),
      ),
    );
  }

  // ✅ HERO (UNCHANGED EXACTLY)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            if (!_navSearchFocusNode.hasFocus) ...[
              const Flexible(
                child: Text('FoodTaxi Omega', overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 16),
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
          const NotificationBell(),
          Center(
            child: ValueListenableBuilder<int>(
              valueListenable: CartModel.itemCountNotifier,
              builder: (context, count, child) {
                return Badge(label: Text('$count'), child: child);
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
                                  (_userProfile!['profile_image_url']
                                              ?.toString() ??
                                          '')
                                      .isNotEmpty
                                  ? NetworkImage(
                                      DatabaseService.getProfileImageUrl(
                                        _userProfile!['profile_image_url']
                                            .toString(),
                                      ),
                                    )
                                  : null,
                              child:
                                  (_userProfile!['profile_image_url']
                                              ?.toString() ??
                                          '')
                                      .isEmpty
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                child: AdaptiveMenuItem(
                  icon: Icons.receipt,
                  title: 'My Orders',
                ),
              ),
              const PopupMenuItem<String>(
                value: 'location',
                child: AdaptiveMenuItem(
                  icon: Icons.location_on,
                  title: 'My Location',
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: AdaptiveMenuItem(
                  icon: Icons.settings,
                  title: 'Settings',
                ),
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
