import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_service.dart';
import 'cart_model.dart';

class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _products = [];
  Map<String, List<Map<String, dynamic>>> _groupedProducts = {};
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingProfile = true;

  int get _cartLength => CartModel.length;

  // FOOD CATEGORIES (6 items each)
  Map<String, List<Map<String, dynamic>>> get demoProducts => {
        "🔥 Trending": [
          {'name': 'Sushi', 'price': 320.00, 'main_image_url': 'assets/images/sushi.jpg'},
          {'name': 'Tacos', 'price': 180.00, 'main_image_url': 'assets/images/tacos.jpg'},
          {'name': 'Pad', 'price': 220.00, 'main_image_url': 'assets/images/padthai.jpg'},
          {'name': 'Pizza', 'price': 350.00, 'main_image_url': 'assets/images/pizza.jpg'},
          {'name': 'Kebab', 'price': 250.00, 'main_image_url': 'assets/images/kebab.jpg'},
          {'name': 'Burger', 'price': 200.00, 'main_image_url': 'assets/images/burger.jpg'},
        ],

        "🏆 Best Seller": [
          {'name': 'Ramen', 'price': 260.00, 'main_image_url': 'assets/images/ramen.jpg'},
          {'name': 'Dim', 'price': 230.00, 'main_image_url': 'assets/images/dimsum.jpg'},
          {'name': 'Lasagna', 'price': 340.00, 'main_image_url': 'assets/images/lasagna.jpg'},
          {'name': 'BBQ Ribs', 'price': 420.00, 'main_image_url': 'assets/images/bbqribs.jpg'},
          {'name': 'Paella', 'price': 360.00, 'main_image_url': 'assets/images/paella.jpg'},
          {'name': 'Falafel', 'price': 180.00, 'main_image_url': 'assets/images/falafel.jpg'},
        ],

        "🍝 Pasta": [
          {'name': 'Carbonara', 'price': 280.00, 'main_image_url': 'assets/images/carbonara.jpg'},
          {'name': 'Spaghetti Bolognese', 'price': 260.00, 'main_image_url': 'assets/images/spaghetti.jpg'},
          {'name': 'Pesto Pasta', 'price': 240.00, 'main_image_url': 'assets/images/pesto.jpg'},
          {'name': 'Seafood Pasta', 'price': 320.00, 'main_image_url': 'assets/images/seafood_pasta.jpg'},
          {'name': 'Mac & Cheese USA', 'price': 180.00, 'main_image_url': 'assets/images/maccheese.jpg'},
          {'name': 'Chicken Alfredo', 'price': 300.00, 'main_image_url': 'assets/images/alfredo.jpg'},
        ],

        "🍔 Burger": [
          {'name': 'Cheeseburge', 'price': 180.00, 'main_image_url': 'assets/images/cheeseburger.jpg'},
          {'name': 'Chicken Burger', 'price': 160.00, 'main_image_url': 'assets/images/chicken_burger.jpg'},
          {'name': 'Double Burger', 'price': 220.00, 'main_image_url': 'assets/images/double_burger.jpg'},
          {'name': 'Bacon Burger', 'price': 260.00, 'main_image_url': 'assets/images/bacon_burger.jpg'},
          {'name': 'Veggie Burger', 'price': 150.00, 'main_image_url': 'assets/images/veggie_burger.jpg'},
          {'name': 'Spicy Burger', 'price': 210.00, 'main_image_url': 'assets/images/spicy_burger.jpg'},
        ],
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
        setState(() => _isLoadingProfile = false);
        return;
      }
      final accountId = await DatabaseService.getCurrentAccountId();
      if (accountId != null) {
        final response = await _supabase
            .from('account')
            .select('firstname, surname, email')
            .eq('account_id', accountId)
            .maybeSingle();
        if (response != null) {
          setState(() {
            _userProfile = response;
          });
        }
      }
    } catch (e) {
      print('Profile fetch error: $e');
    } finally {
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
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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
      _products = await DatabaseService.fetchProducts();
      
      // Group by category
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var product in _products) {
        String cat = product['category'] ?? 'Other';
        grouped.putIfAbsent(cat, () => []).add(product);
      }
      
      _groupedProducts = grouped;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Products fetch error: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    CartModel.addItem(product);
    setState(() {}); // rebuild for badge

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product['name']} added to cart!')),
    );
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
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.network(
                      DatabaseService.getProductImageUrl(item['main_image_url']),
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/burger.jpg', // fallback
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
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
                        SizedBox(
                          width: double.infinity,
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () => _addToCart(item),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('Add'),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
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
        title: const Text("FoodTaxi Omega"),
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
            icon: _isLoadingProfile 
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    _userProfile?['firstname']?[0] ?? 'U',
                    style: const TextStyle(color: Color.fromARGB(255, 30, 83, 32)),
                  ),
                ),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                child: _userProfile != null 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_userProfile!['firstname'] ?? ''} ${_userProfile!['surname'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_userProfile!['email'] ?? ''),
                      ],
                    )
                  : const Text('Profile'),
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                  onTap: null,
                ),
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
              const PopupMenuItem(child: Text('Settings')),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: const Text('Logout')),
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