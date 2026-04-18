import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'profile_page.dart';
import 'cart_page.dart';
import 'search_page.dart';
import 'buyer_dashboard.dart';

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
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: 'FoodTaxi Omega'),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/profile': (context) => const ProfilePage(),
        '/cart': (context) => const CartPage(),
        '/search': (context) => const SearchPage(),
        '/buyer-dashboard': (context) => const BuyerDashboard(),
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

  // ✅ FOOD CATEGORIES
  Map<String, List<Map<String, dynamic>>> get foodCategories => {
        "🔥 Trending": [
          {'name': 'Sushi', 'price': 320.00, 'main_image_url': 'assets/images/sushi.jpg'},
          {'name': 'Tacos', 'price': 180.00, 'main_image_url': 'assets/images/tacos.jpg'},
          {'name': 'Pad Thai', 'price': 220.00, 'main_image_url': 'assets/images/padthai.jpg'},
          {'name': 'Pizza', 'price': 350.00, 'main_image_url': 'assets/images/pizza.jpg'},
          {'name': 'Kebab', 'price': 250.00, 'main_image_url': 'assets/images/kebab.jpg'},
          {'name': 'Burger', 'price': 200.00, 'main_image_url': 'assets/images/burger.jpg'},
        ],
        "🏆 Best Seller": [
          {'name': 'Ramen', 'price': 260.00, 'main_image_url': 'assets/images/ramen.jpg'},
          {'name': 'Dimsum', 'price': 230.00, 'main_image_url': 'assets/images/dimsum.jpg'},
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
          {'name': 'Mac & Cheese', 'price': 180.00, 'main_image_url': 'assets/images/maccheese.jpg'},
          {'name': 'Chicken Alfredo', 'price': 300.00, 'main_image_url': 'assets/images/alfredo.jpg'},
        ],
        "🍔 Burger": [
          {'name': 'Cheeseburger', 'price': 180.00, 'main_image_url': 'assets/images/cheeseburger.jpg'},
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
    testSupabase();
  }

  Future<void> testSupabase() async {
    try {
      await supabase.from('product').select().limit(1);
      setState(() => status = "");
    } catch (e) {
      setState(() => status = "❌ Connection Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [

            // STATUS
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      child: Image.asset('assets/images/tacos.jpg', fit: BoxFit.cover),
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
                              fontWeight: FontWeight.bold),
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

            // ✅ FIXED FOOD CATEGORIES
            Column(
              children: foodCategories.entries.map((category) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    sectionTitle(category.key),
                    horizontalFoodList(category.value),
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
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: const Text("Start Selling"),
                  )
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

          return Container(
            width: 150,
            margin: const EdgeInsets.all(10),
            child: Card(
              child: Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      item["main_image_url"],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(item["name"],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Text("₱${item["price"]}",
                      style: const TextStyle(color: Colors.green)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}