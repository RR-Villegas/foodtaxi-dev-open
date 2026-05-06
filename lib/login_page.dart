import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
  }



  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      // Test accounts
      if (_emailController.text.trim() == 'admin@gmail.com' && _passwordController.text.trim() == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin-dashboard');
        return;
      }

      if (_emailController.text.trim() == 'seller@gmail.com' && _passwordController.text.trim() == 'seller12345') {
        Navigator.pushReplacementNamed(context, '/seller-dashboard');
        return;
      }

      final authResponse = await _supabase.auth.signInWithPassword(

        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = _supabase.auth.currentUser!;
      final authId = user.id;

      // Check/create account row
      var accountId = await DatabaseService.getCurrentAccountId();
      if (accountId == null) {
        accountId = await DatabaseService.insertUserProfile(
          authId: authId,
          firstName: (user.email?.split('@')[0].replaceAll('.', ' ').split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1).toLowerCase() : s).join(' ')) ?? 'User',
          surname: '',
          email: user.email ?? '',
          phoneNumber: '',
          accountType: 'Buyer',
        );
      }

      final role = 'buyer'; // from account_type, default Buyer
      if (mounted) {
        Navigator.pushReplacementNamed(context, role == 'admin' ? '/admin-dashboard' : '/buyer-dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE7F6E8), Color(0xFFF6FBF6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 28,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmall = constraints.maxWidth < 700;
                        return isSmall
                            ? Column(
                                children: [
                                  _buildSignInForm(context),
                                  _buildSidePanel(context, isSmall: true),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: _buildSignInForm(context)),
                                  Expanded(child: _buildSidePanel(context)),
                                ],
                              );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Close button
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 28, color: Colors.black54),
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign In',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              filled: true,
              fillColor: const Color(0xFFF1F7F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              filled: true,
              fillColor: const Color(0xFFF1F7F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() => _showPassword = !_showPassword);
                },
              ),
            ),
            obscureText: !_showPassword,
          ),


          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4D35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading ? null : _signIn,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Sign In', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'or sign in with',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _AuthIcon(icon: Icons.facebook),
              SizedBox(width: 12),
              _AuthIcon(icon: Icons.g_mobiledata),
              SizedBox(width: 12),
              _AuthIcon(icon: Icons.code),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context, {bool isSmall = false}) {
final panel = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E5C40), Color(0xFF2B8C5A), Color(0xFF4DBB7B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'We are so happy to have you here. It’s great to see you again. We hope you had a safe and enjoyable time away.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              foregroundColor: Colors.white,
              backgroundColor: Colors.white24,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/signup');
            },
            child: const Text('No account yet? Signup.'),
          ),
        ],
      ),
    );
    return panel;
  }
}

class _AuthIcon extends StatelessWidget {
  final IconData icon;
  const _AuthIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: const Color(0xFF0F4D35)),
    );
  }
}