import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';

import 'models/user_model.dart';
import 'services/local_storage_service.dart';
import 'services/database_service.dart';
import 'services/input_validator.dart';
import 'services/location_service.dart';
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
  final _zipCodeController = TextEditingController();

  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _loadingProvinces = true;
  bool _loadingCities = false;
  bool _loadingBarangays = false;
  bool _acceptedTerms = false;
  int _currentStep = 1;
  late UserSignupData _signupData;
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];
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
    _loadProvinces();
    _passwordController.addListener(_updatePasswordStrength);
  }

  Future<void> _loadProvinces() async {
    try {
      final provinces = await LocationService.fetchProvinces();
      if (mounted) {
        setState(() {
          _provinces = provinces;
          _loadingProvinces = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _onProvinceSelected(String? provinceName) async {
    if (provinceName == null) return;

    final province = _provinces.firstWhere(
      (p) => p['name'] == provinceName,
      orElse: () => {},
    );

    _provinceController.text = provinceName;
    _municipalityController.clear();
    _barangayController.clear();
    _zipCodeController.clear();

    setState(() {
      _cities = [];
      _barangays = [];
      _loadingCities = true;
    });

    try {
      final cities =
          await LocationService.fetchCitiesAndMunicipalities(province['code']);
      if (mounted) {
        setState(() {
          _cities = cities;
          _loadingCities = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _onCitySelected(String? cityName) async {
    if (cityName == null) return;

    final city = _cities.firstWhere(
      (c) => c['name'] == cityName,
      orElse: () => {},
    );

    _municipalityController.text = cityName;
    _barangayController.clear();
    _zipCodeController.clear();

    setState(() {
      _barangays = [];
      _loadingBarangays = true;
    });

    try {
      final barangays = await LocationService.fetchBarangays(city['code']);
      if (mounted) {
        setState(() {
          _barangays = barangays;
          _loadingBarangays = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingBarangays = false);
    }

    await _refreshZipCodeFromApi();
  }

  Future<void> _refreshZipCodeFromApi() async {
    final zipCode = await LocationService.postalCodeForAddress(
      barangay: _barangayController.text,
      city: _municipalityController.text,
      province: _provinceController.text,
    );
    if (!mounted || zipCode == null) return;
    setState(() => _zipCodeController.text = zipCode);
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
        _zipCodeController.text = existingData.zipCode ?? '';
      });
    }
  }

  Future<bool> _validateStep1() async {
    setState(() => _step1Error = null);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty) {
      setState(() => _step1Error = 'Email is required');
      return false;
    }

    // Check for SQL injection patterns
    if (InputValidator.containsSQLInjectionPatterns(email)) {
      setState(() => _step1Error = 'Email contains invalid characters');
      return false;
    }

    if (!InputValidator.isValidEmail(email)) {
      setState(() => _step1Error = 'Please enter a valid email');
      return false;
    }

    final emailExists = await DatabaseService.isEmailAlreadyUsed(email);
    if (emailExists) {
      setState(() => _step1Error = 'Email is already registered');
      return false;
    }

    if (password.isEmpty) {
      setState(() => _step1Error = 'Password is required');
      return false;
    }

    if (password.length < 8) {
      setState(() => _step1Error = 'Password must be at least 8 characters');
      return false;
    }

    if (!InputValidator.isValidPassword(password)) {
      setState(() => _step1Error = 'Password must contain uppercase, lowercase, number, and special character');
      return false;
    }

    if (!PasswordValidator.isValidCharacters(password)) {
      setState(() =>
          _step1Error = 'Password contains invalid characters. Use: a-z, A-Z, 0-9, @#\$%^&*+=!~');
      return false;
    }

    if (password != confirmPassword) {
      setState(() => _step1Error = 'Passwords do not match');
      return false;
    }

    return true;
  }

  Future<bool> _validateStep2() async {
    setState(() => _step2Error = null);

    final firstName = _firstNameController.text.trim();
    final surname = _surnameController.text.trim();
    final phone = _phoneNumberController.text.trim();

    if (firstName.isEmpty) {
      setState(() => _step2Error = 'First name is required');
      return false;
    }

    // Sanitize and validate first name
    if (!InputValidator.isValidName(firstName)) {
      setState(() => _step2Error = 'First name contains invalid characters');
      return false;
    }

    if (surname.isEmpty) {
      setState(() => _step2Error = 'Surname is required');
      return false;
    }

    // Sanitize and validate surname
    if (!InputValidator.isValidName(surname)) {
      setState(() => _step2Error = 'Surname contains invalid characters');
      return false;
    }

    if (phone.isEmpty) {
      setState(() => _step2Error = 'Phone number is required');
      return false;
    }

    if (!InputValidator.isValidPhoneNumber(phone)) {
      setState(() => _step2Error = 'Please enter a valid Philippine phone number');
      return false;
    }
    final phoneExists = await DatabaseService.isPhoneAlreadyUsed(phone);

    if (phoneExists) {
      setState(() => _step2Error = 'Phone number is already registered');
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

    return true;
  }

  Future<void> _nextStep() async {
    if (_currentStep == 1) {
      if (await _validateStep1()) {
        _signupData.email = _emailController.text.trim();
        _signupData.password = _passwordController.text.trim();
        await LocalStorageService.saveSignupData(_signupData);

        if (mounted) {
          setState(() => _currentStep = 2);
        }
      }
    } else if (_currentStep == 2) {
      if (await _validateStep2()) {
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

  Widget _termsCheckbox() {
    return CheckboxListTile(
      value: _acceptedTerms,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('I agree to the '),
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/terms'),
            child: Text(
              'Terms and Conditions',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
      onChanged: (value) {
        setState(() => _acceptedTerms = value ?? false);
      },
    );
  }

  Future<void> _submitSignup() async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms and Conditions first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_validateStep3()) {
      return;
    }

    _signupData.province = _provinceController.text.trim();
    _signupData.municipality = _municipalityController.text.trim();
    _signupData.barangay = _barangayController.text.trim();
    _signupData.street = _streetController.text.trim();
    _signupData.houseNumber = _houseNumberController.text.trim();
    _signupData.zipCode = _zipCodeController.text.trim();

    setState(() => _isLoading = true);
    try {
      if (_supabase.auth.currentSession != null) {
        await _supabase.auth.signOut(scope: SignOutScope.local);
      }

      // Sign up with Supabase Auth - include role as metadata
      final authResponse = await _supabase.auth.signUp(
        email: _signupData.email!,
        password: _signupData.password!,
        emailRedirectTo: Uri.base.origin,
        data: {'role': _signupData.role},
      );

      // Get the user ID
      final userId = authResponse.user?.id;
      
      if (userId == null) {
        throw Exception('Signup failed: No user returned');
      }

      final hasNewUserSession = await _waitForAuthSession(userId);
      if (!hasNewUserSession) {
        await LocalStorageService.saveSignupData(_signupData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created. Please confirm your email, then sign in to finish setup.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushNamed(context, '/login');
        }
        return;
      }

      // Insert user profile
      final accountId = await DatabaseService.insertUserProfile(
        authId: userId,
        firstName: _signupData.firstName ?? '',
        surname: _signupData.surname ?? '',
        email: _signupData.email ?? '',
        phoneNumber: _signupData.phoneNumber,
        accountType: _toDatabaseAccountType(_signupData.accountType),
      );

      if (accountId == null) {
        throw Exception('Failed to create user profile');
      }

      final point = await LocationService.geocodeAddress(
        houseNumber: _signupData.houseNumber,
        street: _signupData.street,
        barangay: _signupData.barangay,
        city: _signupData.municipality,
        province: _signupData.province,
      );
      if (point == null) {
        throw Exception('Delivery address could not be verified by the location API');
      }
      final resolvedZipCode =
          point.postalCode?.trim().isNotEmpty == true
              ? point.postalCode!.trim()
              : _signupData.zipCode;
      _signupData.zipCode = resolvedZipCode;

      // Insert address into the database
      final address = await DatabaseService.insertAddress(
        accountId: accountId,
        province: _signupData.province,
        city: _signupData.municipality,
        barangay: _signupData.barangay,
        street: _signupData.street,
        houseNumber: _signupData.houseNumber,
        zipCode: resolvedZipCode,
        latitude: point.latitude,
        longitude: point.longitude,
        isDefault: true, // Set first address as default
      );

      if (address == null) {
        throw Exception('Failed to create delivery address');
      }

      // Clear local signup data on success
      await LocalStorageService.clearSignupData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signup successful! Please check your email for confirmation.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signup failed: ${_friendlySignupError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _waitForAuthSession(String expectedUserId) async {
    if (_isSignedInAs(expectedUserId)) return true;

    for (var attempt = 0; attempt < 10; attempt++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (_isSignedInAs(expectedUserId)) return true;
    }

    return false;
  }

  bool _isSignedInAs(String expectedUserId) {
    return _supabase.auth.currentSession != null &&
        _supabase.auth.currentUser?.id == expectedUserId;
  }

  String _friendlySignupError(Object error) {
    if (error is AuthException) {
      if (error.statusCode == '429' ||
          error.code == 'over_email_send_rate_limit') {
        return 'Supabase is temporarily limiting confirmation emails. Please wait a minute, then try again or sign in if the account was already created.';
      }

      return error.message;
    }

    return error.toString();
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
    _zipCodeController.dispose();
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
                          color: Colors.black.withAlpha(26),
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
          
          if (_currentStep == 3) ...[
            const SizedBox(height: 12),
            _termsCheckbox(),
          ],
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
            labelText: 'First Name *',
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
            labelText: 'Surname *',
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
            labelText: 'Phone Number *',
            hintText: '9123456789',
            prefixText: '+63 ',
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
        _loadingProvinces
            ? _loadingLocationBox()
            : DropdownSearch<String>(
                items: _provinces.map((p) => p['name'] as String).toList(),
                selectedItem: _provinceController.text.isEmpty
                    ? null
                    : _provinceController.text,
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  fit: FlexFit.loose,
                ),
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: _locationDecoration(
                    'Province',
                    Icons.map,
                  ),
                ),
                onChanged: _onProvinceSelected,
              ),
        const SizedBox(height: 16),
        _provinceController.text.isEmpty
            ? _disabledLocationBox('Select a province first')
            : _loadingCities
                ? _loadingLocationBox()
                : DropdownSearch<String>(
                    items: _cities.map((c) => c['name'] as String).toList(),
                    selectedItem: _municipalityController.text.isEmpty
                        ? null
                        : _municipalityController.text,
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      fit: FlexFit.loose,
                    ),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _locationDecoration(
                        'Municipality/City',
                        Icons.location_city,
                      ),
                    ),
                    onChanged: _onCitySelected,
                  ),
        const SizedBox(height: 16),
        _municipalityController.text.isEmpty
            ? _disabledLocationBox('Select a city first')
            : _loadingBarangays
                ? _loadingLocationBox()
                : DropdownSearch<String>(
                    items: _barangays.map((b) => b['name'] as String).toList(),
                    selectedItem: _barangayController.text.isEmpty
                        ? null
                        : _barangayController.text,
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      fit: FlexFit.loose,
                    ),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _locationDecoration(
                        'Barangay',
                        Icons.place,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _barangayController.text = value ?? '';
                      });
                      _refreshZipCodeFromApi();
                    },
                  ),
        const SizedBox(height: 16),
        TextField(
          controller: _zipCodeController,
          decoration: InputDecoration(
            labelText: 'Zip Code',
            hintText: 'Auto-filled by location API when available',
            filled: true,
            fillColor: const Color(0xFFF1F7F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          readOnly: true,
          keyboardType: TextInputType.number,
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

  InputDecoration _locationDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF1F7F1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _loadingLocationBox() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _disabledLocationBox(String text) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.black54)),
      ),
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
            color: Colors.black.withAlpha(46),
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
              Navigator.pushNamed(context, '/login');
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
