import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/application_data.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/local_storage_service.dart';
import 'services/input_validator.dart';

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
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Validate email format and check for injection attempts
      if (email.isEmpty) {
        _showErrorSnackBar('Email is required');
        return;
      }

      if (InputValidator.containsSQLInjectionPatterns(email)) {
        _showErrorSnackBar('Invalid email format');
        return;
      }

      if (!InputValidator.isValidEmail(email)) {
        _showErrorSnackBar('Please enter a valid email');
        return;
      }

      // Validate password
      if (password.isEmpty) {
        _showErrorSnackBar('Password is required');
        return;
      }

      if (InputValidator.containsSQLInjectionPatterns(password)) {
        _showErrorSnackBar('Password contains invalid characters');
        return;
      }

      // Test accounts
      if (email == 'admin@gmail.com' && password == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin-dashboard');
        return;
      }

      if (email == 'seller@gmail.com' && password == 'seller12345') {
        Navigator.pushReplacementNamed(context, '/seller-dashboard');
        return;
      }

      await _supabase.auth.signInWithPassword(email: email, password: password);

      final user = _supabase.auth.currentUser!;
      final authId = user.id;

      // Check/create account row
      var account = await DatabaseService.getCurrentAccount();
      if (account == null) {
        final pendingSignup = await LocalStorageService.loadSignupData();
        final pendingSeller =
            await LocalStorageService.loadSellerApplicationData();
        final pendingRider =
            await LocalStorageService.loadRiderApplicationData();
        final canUsePendingSignup = _matchesCurrentUser(
          pendingSignup,
          user.email,
        );
        final canUsePendingSeller = _matchesSellerApplication(
          pendingSeller,
          user.email,
        );
        final canUsePendingRider = _matchesRiderApplication(
          pendingRider,
          user.email,
        );
        final firstName = canUsePendingSeller
            ? pendingSeller!.firstName
            : canUsePendingRider
            ? pendingRider!.firstName
            : canUsePendingSignup
            ? pendingSignup!.firstName ?? _displayNameFromEmail(user.email)
            : _displayNameFromEmail(user.email);
        final surname = canUsePendingSeller
            ? pendingSeller!.surname
            : canUsePendingRider
            ? pendingRider!.surname
            : canUsePendingSignup
            ? pendingSignup!.surname ?? ''
            : '';
        final phoneNumber = canUsePendingSeller
            ? pendingSeller!.contactPhone
            : canUsePendingRider
            ? pendingRider!.phoneNumber
            : canUsePendingSignup
            ? pendingSignup!.phoneNumber
            : null;
        final accountType = canUsePendingSeller
            ? 'Seller'
            : canUsePendingRider
            ? 'Rider'
            : canUsePendingSignup
            ? _toDatabaseAccountType(pendingSignup!.accountType)
            : 'Buyer';

        final accountId = await DatabaseService.insertUserProfile(
          authId: authId,
          firstName: firstName,
          surname: surname,
          email: user.email ?? '',
          phoneNumber: phoneNumber,
          accountType: accountType,
        );
        if (accountId == null) {
          throw Exception('Account profile could not be created');
        }

        if (canUsePendingSignup && pendingSignup!.isStep3Complete()) {
          final address = await DatabaseService.insertAddress(
            accountId: accountId,
            province: pendingSignup.province,
            city: pendingSignup.municipality,
            barangay: pendingSignup.barangay,
            street: pendingSignup.street,
            houseNumber: pendingSignup.houseNumber,
            zipCode: pendingSignup.zipCode,
            isDefault: true,
          );

          if (address == null) {
            throw Exception('Delivery address could not be created');
          }

          await LocalStorageService.clearSignupData();
        }

        account = await DatabaseService.getCurrentAccount();
      }

      // Save login session for persistent login
      await AuthService.saveLoginSession(user);

      final role = (account?['account_type'] as String? ?? 'Buyer')
          .toLowerCase();
      if (mounted) {
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        } else if (role == 'seller') {
          await _handleSellerLogin(account);
        } else if (role == 'rider') {
          await _handleRiderLogin(account);
        } else {
          Navigator.pushReplacementNamed(context, '/buyer-dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  bool _matchesCurrentUser(UserSignupData? signupData, String? email) {
    return signupData?.email?.trim().toLowerCase() ==
        email?.trim().toLowerCase();
  }

  String _displayNameFromEmail(String? email) {
    final name = email?.split('@').first.trim();
    if (name == null || name.isEmpty) return 'User';

    return name
        .replaceAll('.', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _toDatabaseAccountType(String accountType) {
    switch (accountType.toLowerCase()) {
      case 'seller':
        return 'Seller';
      case 'rider':
        return 'Rider';
      case 'buyer':
      default:
        return 'Buyer';
    }
  }

  Future<void> _handleSellerLogin(Map<String, dynamic>? account) async {
    final accountId = account?['account_id'] as String?;
    if (accountId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    await _syncPendingSellerApplication(accountId);
    final application = await DatabaseService.getSellerApplicationByAccountId(
      accountId,
    );
    final status = application?['status']?.toString();

    if (status == 'Approved') {
      Navigator.pushReplacementNamed(context, '/seller-dashboard');
    } else {
      if (status == 'Rejected') {
        _showApplicationSnackBar(
          'Your seller application was denied. Please resend your application.',
        );
      }
      Navigator.pushReplacementNamed(
        context,
        '/application-status',
        arguments: 'seller',
      );
    }
  }

  Future<void> _handleRiderLogin(Map<String, dynamic>? account) async {
    final accountId = account?['account_id'] as String?;
    if (accountId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    await _syncPendingRiderApplication(accountId);
    final application = await DatabaseService.getRiderApplicationByAccountId(
      accountId,
    );
    final status = application?['status']?.toString();

    if (status == 'Approved') {
      Navigator.pushReplacementNamed(context, '/rider-dashboard');
    } else {
      if (status == 'Rejected') {
        _showApplicationSnackBar(
          'Your rider application was denied. Please resend your application.',
        );
      }
      Navigator.pushReplacementNamed(
        context,
        '/application-status',
        arguments: 'rider',
      );
    }
  }

  Future<void> _syncPendingSellerApplication(String accountId) async {
    final data = await LocalStorageService.loadSellerApplicationData();
    if (!_matchesSellerApplication(data, _supabase.auth.currentUser?.email)) {
      return;
    }

    final saved = await DatabaseService.saveSellerApplication(
      accountId: accountId,
      storeName: data!.storeName,
      storeDescription: data.storeDescription,
      province: data.province,
      city: data.city,
      barangay: data.barangay,
      street: data.street,
      houseNumber: data.houseNumber,
      zipCode: data.zipCode,
      contactPhone: data.contactPhone,
    );
    if (saved) await LocalStorageService.clearSellerApplicationData();
  }

  Future<void> _syncPendingRiderApplication(String accountId) async {
    final data = await LocalStorageService.loadRiderApplicationData();
    if (!_matchesRiderApplication(data, _supabase.auth.currentUser?.email)) {
      return;
    }

    final saved = await DatabaseService.saveRiderApplication(
      accountId: accountId,
      licenseNumber: data!.licenseNumber,
      vehicleType: data.vehicleType,
      plateNumber: data.plateNumber,
      documentNotes: data.documentNotes,
    );
    if (saved) await LocalStorageService.clearRiderApplicationData();
  }

  bool _matchesSellerApplication(SellerApplicationData? data, String? email) {
    return data?.email.trim().toLowerCase() == email?.trim().toLowerCase();
  }

  bool _matchesRiderApplication(RiderApplicationData? data, String? email) {
    return data?.email.trim().toLowerCase() == email?.trim().toLowerCase();
  }

  void _showApplicationSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
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
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
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
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
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
                  : const Text(
                      'Sign In',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
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
