import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'profile_page.dart';
import 'cart_page.dart';
import 'search_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zsctswdvoknmdsimqrvr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpzY3Rzd2R2b2tubWRzaW1xcnZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0MDkyMjgsImV4cCI6MjA5MTk4NTIyOH0.9AMczePav5ftvCbhhYWxBaquUFK1Nrmgx1FbUZKpci8',
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

  final List<Map<String, String>> trendingItems = [
    {"name": "Mango Sticky Rice", "image": "assets/images/food1.jpg"},
    {"name": "Korean Kimchi", "image": "assets/images/food2.jpg"},
  ];

  final List<Map<String, String>> randomItems = [
    {"name": "Takoyaki", "image": "assets/images/food3.jpg"},
    {"name": "Matcha Cake", "image": "assets/images/food4.jpg"},
  ];

  @override
  void initState() {
    super.initState();
    testSupabase();
  }

  Future<void> testSupabase() async {
    try {
      await supabase.from('product').select().limit(1);

      setState(() {
        status = "✅ Supabase Connected";
      });
    } catch (e) {
      setState(() {
        status = "❌ Connection Failed: $e";
      });
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
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [

            // 🔥 STATUS (SUPABASE TEST)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                status,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // 🔥 HERO BANNER
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
                        'assets/images/food1.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
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
                        SizedBox(height: 16),
                        Text(
                          "Delivering fresh, local, and international goods right to your door.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🔥 TRENDING
            sectionTitle("🔥 Trending Now"),
            horizontalList(trendingItems),

            const SizedBox(height: 20),

            // ✨ RANDOM
            sectionTitle("✨ You Might Also Like"),
            horizontalList(randomItems),

            const SizedBox(height: 30),

            // 📢 CTA SECTION
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "Become a Seller",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Grow your business with FoodTaxi Omega. Apply now!",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                    ),
                    child: const Text("Start Selling"),
                  )
                ],
              ),
            )
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget horizontalList(List<Map<String, String>> items) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 140,
            margin: const EdgeInsets.all(10),
            child: Card(
              elevation: 4,
              child: Column(
                children: [
                  Image.asset(
                    item["image"]!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item["name"]!,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}