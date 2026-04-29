import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_model.dart';
import 'services/local_storage_service.dart';
import 'services/database_service.dart';
import 'utils/password_validator.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // Step 1: Authentication
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2: Personal Information
  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  // Step 3: Address Information
  final _provinceController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _barangayController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseNumberController = TextEditingController();

  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  int _currentStep = 1;
  late UserSignupData _signupData;
  String? _step1Error;
  String? _step2Error;
  String? _step3Error;

  // Password visibility toggles
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  late PasswordStrength _passwordStrength;
  String? _passwordCharError;

  @override
  void initState() {
    super.initState();
    _signupData = UserSignupData();
    _passwordStrength = PasswordStrength.weak;
    _loadExistingData();
    _passwordController.addListener(_updatePasswordStrength);
  }

  void _updatePasswordStrength() {
    setState(() {
      _passwordStrength = PasswordValidator.calculateStrength(_passwordController.text);
      _passwordCharError = PasswordValidator.getFeedback(_passwordController.text);
    });
  }

  Future<void> _loadExistingData() async {
    final existingData = await LocalStorageService.loadSignupData();
    if (existingData != null) {
      setState(() {
        _signupData = existingData;
        _emailController.text = existingData.email ?? '';
        _passwordController.text = existingData.password ?? '';
        _firstNameController.text = existingData.firstName ?? '';
        _surnameController.text = existingData.surname ?? '';
        _phoneNumberController.text = existingData.phoneNumber ?? '';
        _provinceController.text = existingData.province ?? '';
        _municipalityController.text = existingData.municipality ?? '';
        _barangayController.text = existingData.barangay ?? '';
        _streetController.text = existingData.street ?? '';
        _houseNumberController.text = existingData.houseNumber ?? '';
      });
    }
  }

  bool _validateStep1() {
    setState(() => _step1Error = null);

    if (_emailController.text.isEmpty) {
      setState(() => _step1Error = 'Email is required');
      return false;
    }

    if (!_emailController.text.contains('@')) {
      setState(() => _step1Error = 'Please enter a valid email');
      return false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _step1Error = 'Password is required');
      return false;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _step1Error = 'Password must be at least 6 characters');
      return false;
    }

    if (!PasswordValidator.isValidCharacters(_passwordController.text)) {
      setState(() =>
          _step1Error = 'Password contains invalid characters. Use: a-z, A-Z, 0-9, @#\$%^&*+=!~');
      return false;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _step1Error = 'Passwords do not match');
      return false;
    }

    return true;
  }

  bool _validateStep2() {
    setState(() => _step2Error = null);

    if (_firstNameController.text.isEmpty) {
      setState(() => _step2Error = 'First name is required');
      return false;
    }

    if (_surnameController.text.isEmpty) {
      setState(() => _step2Error = 'Surname is required');
      return false;
    }

    if (_phoneNumberController.text.isEmpty) {
      setState(() => _step2Error = 'Phone number is required');
      return false;
    }

    return true;
  }

  bool _validateStep3() {
    setState(() => _step3Error = null);

    if (_provinceController.text.isEmpty) {
      setState(() => _step3Error = 'Province is required');
      return false;
    }

    if (_municipalityController.text.isEmpty) {
      setState(() => _step3Error = 'Municipality/City is required');
      return false;
    }

    if (_barangayController.text.isEmpty) {
      setState(() => _step3Error = 'Barangay is required');
      return false;
    }

    if (_streetController.text.isEmpty) {
      setState(() => _step3Error = 'Street is required');
      return false;
    }

    if (_houseNumberController.text.isEmpty) {
      setState(() => _step3Error = 'House number is required');
      return false;
    }

    return true;
  }

  Future<void> _nextStep() async {
    if (_currentStep == 1) {
      if (_validateStep1()) {
        _signupData.email = _emailController.text.trim();
        _signupData.password = _passwordController.text.trim();
        await LocalStorageService.saveSignupData(_signupData);

        if (mounted) {
          setState(() => _currentStep = 2);
        }
      }
    } else if (_currentStep == 2) {
      if (_validateStep2()) {
        _signupData.firstName = _firstNameController.text.trim();
        _signupData.surname = _surnameController.text.trim();
        _signupData.phoneNumber = _phoneNumberController.text.trim();
        await LocalStorageService.saveSignupData(_signupData);

        if (mounted) {
          setState(() => _currentStep = 3);
        }
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _submitSignup() async {
    if (!_validateStep3()) {
      return;
    }

    _signupData.province = _provinceController.text.trim();
    _signupData.municipality = _municipalityController.text.trim();
    _signupData.barangay = _barangayController.text.trim();
    _signupData.street = _streetController.text.trim();
    _signupData.houseNumber = _houseNumberController.text.trim();

    setState(() => _isLoading = true);
    try {
      // Sign up with Supabase Auth
      final authResponse = await _supabase.auth.signUp(
        email: _signupData.email!,
        password: _signupData.password!,
      );

      // Get the user ID
      final userId = authResponse.user?.id;
      
      if (userId == null) {
        throw Exception('Failed to get user ID from signup response');
      }

      // Insert address into the database
      await DatabaseService.insertAddress(
        accountId: userId,
        province: _signupData.province!,
        city: _signupData.municipality!,
        barangay: _signupData.barangay!,
        street: _signupData.street,
        houseNumber: _signupData.houseNumber,
        isDefault: true, // Set first address as default
      );

      // Save signup data locally for future reference
      _signupData.email = authResponse.user?.email;
      await LocalStorageService.saveSignupData(_signupData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign up successful! Please check your email.')),
        );
        Navigator.pop(context);
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
    _passwordController.removeListener(_updatePasswordStrength);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _surnameController.dispose();
    _phoneNumberController.dispose();
    _provinceController.dispose();
    _municipalityController.dispose();
    _barangayController.dispose();
    _streetController.dispose();
    _houseNumberController.dispose();
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
                                  _buildSignUpForm(context),
                                  _buildSidePanel(context, isSmall: true),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: _buildSignUpForm(context)),
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

  Widget _buildSignUpForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _currentStep == 1
                ? 'Sign Up - Step 1'
                : _currentStep == 2
                    ? 'Sign Up - Step 2'
                    : 'Sign Up - Step 3',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentStep == 1
                ? 'Email & Password'
                : _currentStep == 2
                    ? 'Personal Information'
                    : 'Address Information',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          if (_currentStep == 1) _buildStep1Form(),
          if (_currentStep == 2) _buildStep2Form(),
          if (_currentStep == 3) _buildStep3Form(),
          if (_step1Error != null && _currentStep == 1)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _step1Error!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          if (_step2Error != null && _currentStep == 2)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _step2Error!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          if (_step3Error != null && _currentStep == 3)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _step3Error!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          const SizedBox(height: 24),
          _buildButtonRow(),
        ],
      ),
    );
  }

  Widget _buildStep1Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (_passwordCharError != null && _passwordCharError!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _passwordCharError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        if (_passwordController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Strength: ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      PasswordValidator.getStrengthLabel(_passwordStrength),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: PasswordValidator.getStrengthColor(_passwordStrength),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_passwordStrength.index + 1) / 4,
                    minHeight: 4,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      PasswordValidator.getStrengthColor(_passwordStrength),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Re-enter your password',
            filled: true,
            fillColor: const Color(0xFFF1F7F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() => _showConfirmPassword = !_showConfirmPassword);
              },
            ),
          ),
          obscureText: !_showConfirmPassword,
        ),
      ],
    );
  }

  Widget _buildStep2Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: 'First Name',
            hintText: 'Enter your first name',
            filled: true,
            fillColor: const Color(0xFFF1F7F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _surnameController,
          decoration: InputDecoration(
            labelText: 'Surname',
            hintText: 'Enter your surname',
            filled: true,
            fillColor: const Color(0xFFF1F7F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneNumberController,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: 'Enter your phone number',
            filled: true,
            fillColor: const Color(0xFFF1F7F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildStep3Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _provinceController,
          decoration: InputDecoration(
            labelText: 'Province',
            hintText: 'Enter your province',
            filled: true,
            fillColor: const Color(0xFFF1F7F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _municipalityController,
          decoration: InputDecoration(
            labelText: 'Municipality/City',
            hintText: 'Enter your municipality or city',
            filled: true,
            fillColor: const Color(0xFFF1F7F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _barangayController,
          decoration: InputDecoration(
            labelText: 'Barangay',
            hintText: 'Enter your barangay',
            filled: true,
            fillColor: const Color(0xFFF1F7F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _streetController,
          decoration: InputDecoration(
            labelText: 'Street',
            hintText: 'Enter your street',
            filled: true,
            fillColor: const Color(0xFFF1F7F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _houseNumberController,
          decoration: InputDecoration(
            labelText: 'House Number',
            hintText: 'Enter your house number',
            filled: true,
            fillColor: const Color(0xFFF1F7F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonRow() {
    return Row(
      children: [
        if (_currentStep > 1)
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0F4D35)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isLoading ? null : _previousStep,
                child: const Text(
                  'Previous',
                  style: TextStyle(fontSize: 16, color: Color(0xFF0F4D35)),
                ),
              ),
            ),
          ),
        if (_currentStep > 1) const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4D35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : (_currentStep == 3 ? _submitSignup : _nextStep),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _currentStep == 3 ? 'Submit' : 'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidePanel(BuildContext context, {bool isSmall = false}) {
    return Container(
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
            'Welcome!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _currentStep == 1
                ? 'Create your account with your email and password.'
                : _currentStep == 2
                    ? 'Tell us about yourself so we can personalize your experience.'
                    : 'Help us deliver to the right location.',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator('Account', 1),
                const SizedBox(height: 12),
                _buildStepIndicator('Personal Info', 2),
                const SizedBox(height: 12),
                _buildStepIndicator('Address', 3),
              ],
            ),
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
              Navigator.pop(context);
            },
            child: const Text('Already have an account? Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(String label, int step) {
    final isCompleted = step < _currentStep;
    final isCurrent = step == _currentStep;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : (isCurrent ? Colors.white : Colors.white30),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: TextStyle(
                color: isCompleted || isCurrent ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: isCurrent ? Colors.white : Colors.white70,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
