import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'models/application_data.dart';
import 'models/picked_document.dart';
import 'services/database_service.dart';
import 'services/local_storage_service.dart';
import 'services/location_service.dart';
import 'services/input_validator.dart';
import 'utils/password_validator.dart';
import 'package:dropdown_search/dropdown_search.dart';

class SellerRegistrationPage extends StatefulWidget {
  const SellerRegistrationPage({super.key});

  @override
  State<SellerRegistrationPage> createState() => _SellerRegistrationPageState();
}

class _SellerRegistrationPageState extends State<SellerRegistrationPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  int _currentStep = 1;
  String? _step1Error;
  String? _step2Error;
  String? _step3Error;

  // Step 1: Personal Account Info
  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  PasswordStrength _passwordStrength = PasswordStrength.weak;
  String? _passwordCharError;

  // Step 2: Store Information
  final _storeNameController = TextEditingController();
  final _storeDescriptionController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  // Step 3: Location
  final _streetController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _zipCodeController = TextEditingController();

  // Location data
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];

  String? _selectedProvinceName;
  String? _selectedCityName;
  String? _selectedBarangayName;

  bool _loadingProvinces = true;
  bool _loadingCities = false;
  bool _loadingBarangays = false;
  final List<PickedDocument> _permitDocuments = [];

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _passwordController.addListener(_updatePasswordStrength);
    _loadProvinces();
  }

  void _updatePasswordStrength() {
    setState(() {
      _passwordStrength =
          PasswordValidator.calculateStrength(_passwordController.text);
      _passwordCharError =
          PasswordValidator.getFeedback(_passwordController.text);
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordController.removeListener(_updatePasswordStrength);
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _contactPhoneController.dispose();
    _streetController.dispose();
    _houseNumberController.dispose();
    _zipCodeController.dispose();
    super.dispose();
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
      debugPrint('Error loading provinces: $e');
      if (mounted) {
        setState(() => _loadingProvinces = false);
      }
    }
  }

  Future<void> _onProvinceSelected(String? provinceName) async {
    if (provinceName == null) return;

    final province = _provinces.firstWhere(
      (p) => p['name'] == provinceName,
      orElse: () => {},
    );

    setState(() {
      _selectedProvinceName = provinceName;
      _selectedCityName = null;
      _selectedBarangayName = null;
      _zipCodeController.clear();
      _cities = [];
      _barangays = [];
      _loadingCities = true;
    });

    try {
      final cities = await LocationService.fetchCitiesAndMunicipalities(
        province['code'],
      );
      if (mounted) {
        setState(() {
          _cities = cities;
          _loadingCities = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cities: $e');
      if (mounted) {
        setState(() => _loadingCities = false);
      }
    }
  }

  Future<void> _onCitySelected(String? cityName) async {
    if (cityName == null) return;

    final city = _cities.firstWhere(
      (c) => c['name'] == cityName,
      orElse: () => {},
    );

    setState(() {
      _selectedCityName = cityName;
      _selectedBarangayName = null;
      _zipCodeController.clear();
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
      debugPrint('Error loading barangays: $e');
      if (mounted) {
        setState(() => _loadingBarangays = false);
      }
    }

    await _refreshZipCodeFromApi();
  }

  Future<void> _refreshZipCodeFromApi() async {
    final zipCode = await LocationService.postalCodeForAddress(
      barangay: _selectedBarangayName,
      city: _selectedCityName,
      province: _selectedProvinceName,
    );
    if (!mounted || zipCode == null) return;
    setState(() => _zipCodeController.text = zipCode);
  }

  bool _validateStep1() {
    setState(() => _step1Error = null);

    final firstName = _firstNameController.text.trim();
    final surname = _surnameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (firstName.isEmpty) {
      setState(() => _step1Error = 'First name is required');
      return false;
    }

    // Sanitize and validate first name
    if (InputValidator.containsSQLInjectionPatterns(firstName)) {
      setState(() => _step1Error = 'First name contains invalid characters');
      return false;
    }

    if (!InputValidator.isValidName(firstName)) {
      setState(() => _step1Error = 'First name contains invalid characters');
      return false;
    }

    if (surname.isEmpty) {
      setState(() => _step1Error = 'Surname is required');
      return false;
    }

    // Sanitize and validate surname
    if (InputValidator.containsSQLInjectionPatterns(surname)) {
      setState(() => _step1Error = 'Surname contains invalid characters');
      return false;
    }

    if (!InputValidator.isValidName(surname)) {
      setState(() => _step1Error = 'Surname contains invalid characters');
      return false;
    }

    if (email.isEmpty) {
      setState(() => _step1Error = 'Email is required');
      return false;
    }

    // Check email for injection attempts
    if (InputValidator.containsSQLInjectionPatterns(email)) {
      setState(() => _step1Error = 'Email contains invalid characters');
      return false;
    }

    if (!InputValidator.isValidEmail(email)) {
      setState(() => _step1Error = 'Invalid email format');
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

    // Validate password strength and check for injection
    if (InputValidator.containsSQLInjectionPatterns(password)) {
      setState(() => _step1Error = 'Password contains invalid characters');
      return false;
    }

    if (!InputValidator.isValidPassword(password)) {
      setState(
        () => _step1Error =
            'Password must contain uppercase, lowercase, number, and special character',
      );
      return false;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _step1Error = 'Please re-enter your password');
      return false;
    }

    if (password != confirmPassword) {
      setState(() => _step1Error = 'Passwords do not match');
      return false;
    }

    return true;
  }

  bool _validateStep2() {
    setState(() => _step2Error = null);

    final storeName = _storeNameController.text.trim();
    final phone = _contactPhoneController.text.trim();

    if (storeName.isEmpty) {
      setState(() => _step2Error = 'Store name is required');
      return false;
    }

    // Validate store name
    if (InputValidator.containsSQLInjectionPatterns(storeName)) {
      setState(() => _step2Error = 'Store name contains invalid characters');
      return false;
    }

    if (!InputValidator.isValidStoreName(storeName)) {
      setState(
        () => _step2Error = 'Store name must be between 3-100 characters',
      );
      return false;
    }

    if (phone.isEmpty) {
      setState(() => _step2Error = 'Contact phone is required');
      return false;
    }

    // Validate phone number
    if (InputValidator.containsSQLInjectionPatterns(phone)) {
      setState(() => _step2Error = 'Phone number contains invalid characters');
      return false;
    }

    if (!InputValidator.isValidPhoneNumber(phone)) {
      setState(() => _step2Error = 'Invalid Philippine phone number format');
      return false;
    }

    if (_permitDocuments.isEmpty) {
      setState(() => _step2Error = 'Upload at least one business permit document');
      return false;
    }

    return true;
  }

  Future<void> _pickPermitImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 65,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    _addPickedDocument(
      PickedDocument(
        label: 'Business permit',
        fileName: image.name,
        contentType:
            DatabaseService.applicationDocumentContentTypeFor(image.name) ?? '',
        bytes: bytes,
      ),
    );
  }

  Future<void> _pickPermitFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: DatabaseService.allowedApplicationDocumentExtensions,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    _addPickedDocument(
      PickedDocument(
        label: 'Business permit',
        fileName: file.name,
        contentType:
            DatabaseService.applicationDocumentContentTypeFor(file.name) ?? '',
        bytes: bytes,
      ),
    );
  }

  void _addPickedDocument(PickedDocument document) {
    if (!DatabaseService.isAllowedApplicationDocumentName(document.fileName)) {
      setState(() => _step2Error = 'Only PDF, PNG, JPG, or WEBP files are allowed');
      return;
    }
    if (document.size > 5 * 1024 * 1024) {
      setState(() => _step2Error = 'Document must be 5MB or smaller');
      return;
    }
    setState(() {
      _step2Error = null;
      _permitDocuments.add(document);
    });
  }

  Future<List<Map<String, dynamic>>> _uploadPermitDocuments(String accountId) async {
    final uploaded = <Map<String, dynamic>>[];
    for (final document in _permitDocuments) {
      final metadata = await DatabaseService.uploadApplicationDocument(
        bytes: document.bytes,
        fileName: document.fileName,
        label: document.label,
        applicationType: 'seller',
        documentType: 'permit',
        accountId: accountId,
        contentType: document.contentType,
      );
      if (metadata == null) {
        throw Exception('Could not upload ${document.fileName}');
      }
      uploaded.add(metadata);
    }
    return uploaded;
  }

  List<Map<String, dynamic>> _pendingPermitDocuments() {
    return _permitDocuments
        .map(
          (document) => {
            'label': document.label,
            'file_name': document.fileName,
            'content_type': document.contentType,
            'size': document.size,
            'bytes_base64': base64Encode(document.bytes),
          },
        )
        .toList();
  }

  bool _validateStep3() {
    setState(() => _step3Error = null);

    final street = _streetController.text.trim();

    if (_selectedProvinceName == null) {
      setState(() => _step3Error = 'Province is required');
      return false;
    }

    if (_selectedCityName == null) {
      setState(() => _step3Error = 'Municipality/City is required');
      return false;
    }

    if (_selectedBarangayName == null) {
      setState(() => _step3Error = 'Barangay is required');
      return false;
    }

    if (street.isEmpty) {
      setState(() => _step3Error = 'Street is required');
      return false;
    }

    // Validate street input for injection attempts
    if (InputValidator.containsSQLInjectionPatterns(street)) {
      setState(() => _step3Error = 'Street contains invalid characters');
      return false;
    }

    // Optional fields - validate if provided
    final houseNumber = _houseNumberController.text.trim();
    if (houseNumber.isNotEmpty &&
        InputValidator.containsSQLInjectionPatterns(houseNumber)) {
      setState(() => _step3Error = 'House number contains invalid characters');
      return false;
    }

    final zipCode = _zipCodeController.text.trim();
    if (zipCode.isNotEmpty &&
        InputValidator.containsSQLInjectionPatterns(zipCode)) {
      setState(() => _step3Error = 'Zip code contains invalid characters');
      return false;
    }

    return true;
  }

  void _nextStep() {
    if (_currentStep == 1 && _validateStep1()) {
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2 && _validateStep2()) {
      setState(() => _currentStep = 3);
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _submitApplication() async {
    if (!_validateStep3()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = _supabase.auth.currentUser;
      final submittedWhileLoggedIn = currentUser != null;
      final point = await LocationService.geocodeAddress(
        houseNumber: _houseNumberController.text,
        street: _streetController.text,
        barangay: _selectedBarangayName,
        city: _selectedCityName,
        province: _selectedProvinceName,
        zipCode: _zipCodeController.text,
      );
      if (point == null) {
        throw Exception('Store address could not be verified by the location API');
      }
      final resolvedZipCode = point.postalCode?.trim().isNotEmpty == true
          ? point.postalCode!.trim()
          : _zipCodeController.text.trim();

      final applicationData = SellerApplicationData(
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        surname: _surnameController.text.trim(),
        password: _passwordController.text,
        storeName: _storeNameController.text.trim(),
        storeDescription: _storeDescriptionController.text.trim(),
        province: _selectedProvinceName,
        city: _selectedCityName ?? '',
        barangay: _selectedBarangayName,
        street: _streetController.text.isNotEmpty
            ? _streetController.text.trim()
            : null,
        houseNumber: _houseNumberController.text.isNotEmpty
            ? _houseNumberController.text.trim()
            : null,
        zipCode: resolvedZipCode.isNotEmpty
            ? resolvedZipCode
            : null,
        contactPhone: _contactPhoneController.text.trim(),
        documents: submittedWhileLoggedIn ? const [] : _pendingPermitDocuments(),
      );

      if (!submittedWhileLoggedIn) {
        await LocalStorageService.saveSellerApplicationData(applicationData);
      }

      if (currentUser == null) {
        final authResponse = await _supabase.auth.signUp(
          email: applicationData.email,
          password: applicationData.password,
          emailRedirectTo: Uri.base.origin,
          data: {'role': 'seller'},
        );

        if (authResponse.user == null) {
          throw Exception('Failed to create authentication account');
        }
        if (_supabase.auth.currentSession != null) {
          await _supabase.auth.signOut(scope: SignOutScope.local);
        }
      } else {
        final accountId = await DatabaseService.insertUserProfile(
          authId: currentUser.id,
          firstName: applicationData.firstName,
          surname: applicationData.surname,
          email: currentUser.email ?? applicationData.email,
          phoneNumber: applicationData.contactPhone,
          accountType: 'Seller',
        );

        if (accountId == null) {
          throw Exception('Failed to create seller account profile');
        }

        final documents = await _uploadPermitDocuments(accountId);
        final submitted = await DatabaseService.saveSellerApplication(
          accountId: accountId,
          storeName: applicationData.storeName,
          storeDescription: applicationData.storeDescription,
          province: applicationData.province,
          city: applicationData.city,
          barangay: applicationData.barangay,
          street: applicationData.street,
          houseNumber: applicationData.houseNumber,
          zipCode: applicationData.zipCode,
          contactPhone: applicationData.contactPhone,
          documents: documents,
        );

        if (!submitted) {
          throw Exception('Seller application could not be submitted');
        }

        await DatabaseService.saveRegistrationAddress(
          accountId: accountId,
          province: applicationData.province,
          city: applicationData.city,
          barangay: applicationData.barangay,
          street: applicationData.street,
          houseNumber: applicationData.houseNumber,
          zipCode: applicationData.zipCode,
          latitude: point.latitude,
          longitude: point.longitude,
        );
        await LocalStorageService.clearSellerApplicationData();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submittedWhileLoggedIn
                  ? 'Seller application submitted for admin review.'
                  : 'Seller application saved. Please confirm your email and log in to send it for admin review.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        if (submittedWhileLoggedIn) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/application-status',
            (route) => false,
            arguments: 'seller',
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: Colors.white.withAlpha(235),
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              color: Colors.black87,
              onPressed: _closePage,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _closePage() async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      final role = (await DatabaseService.getCurrentAccountType())?.toLowerCase();
      if (!mounted) return;
      final route = switch (role) {
        'admin' => '/admin-dashboard',
        'seller' => '/seller-dashboard',
        'rider' => '/rider-dashboard',
        'buyer' => '/buyer-dashboard',
        _ => '/',
      };
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    }
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildStepIndicators(),
              const SizedBox(height: 32),
              _currentStep == 1
                  ? _buildStep1Form()
                  : _currentStep == 2
                  ? _buildStep2Form()
                  : _buildStep3Form(),
              const SizedBox(height: 24),
              _buildButtonRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildSidePanel()),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _currentStep == 1
                      ? _buildStep1Form()
                      : _currentStep == 2
                      ? _buildStep2Form()
                      : _buildStep3Form(),
                  const SizedBox(height: 32),
                  _buildButtonRow(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidePanel() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.primary, scheme.secondary],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 10),
        ],
      ),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Become a Seller',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Join our marketplace and grow your business.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 48),
          _buildStepIndicator('Personal Info', 1),
          const SizedBox(height: 24),
          _buildStepIndicator('Store Information', 2),
          const SizedBox(height: 24),
          _buildStepIndicator('Location Details', 3),
        ],
      ),
    );
  }

  Widget _buildStepIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStepIndicator('Personal', 1),
        Container(
          height: 2,
          width: 30,
          color: _currentStep > 1
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[300],
        ),
        _buildStepIndicator('Store', 2),
        Container(
          height: 2,
          width: 30,
          color: _currentStep > 2
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[300],
        ),
        _buildStepIndicator('Location', 3),
      ],
    );
  }

  Widget _buildStepIndicator(String label, int step) {
    final isCompleted = step < _currentStep;
    final isCurrent = step == _currentStep;

    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent || isCompleted
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isCurrent || isCompleted
                          ? Colors.white
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent || isCompleted
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: 'First Name *',
            hintText: 'Enter your first name',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _surnameController,
          decoration: InputDecoration(
            labelText: 'Surname *',
            hintText: 'Enter your surname',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email *',
            hintText: 'Enter your email address',
            prefixIcon: const Icon(Icons.email),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          decoration: InputDecoration(
            labelText: 'Password *',
            hintText: 'Enter a strong password',
            helperText: _passwordFocusNode.hasFocus
                ? 'Allowed special characters: ! @ # \$ % ^ & *'
                : null,
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() => _showPassword = !_showPassword);
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          obscureText: !_showPassword,
        ),
        _buildPasswordStrengthIndicator(),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Re-enter Password *',
            hintText: 'Confirm your password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _showConfirmPassword
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
              onPressed: () {
                setState(
                  () => _showConfirmPassword = !_showConfirmPassword,
                );
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          obscureText: !_showConfirmPassword,
        ),
        if (_step1Error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                _step1Error!,
                style: TextStyle(color: Colors.red[700], fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    if (_passwordController.text.isEmpty) return const SizedBox.shrink();

    final color = PasswordValidator.getStrengthColor(_passwordStrength);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (_passwordStrength.index + 1) / 4,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
          const SizedBox(height: 6),
          Text(
            'Strength: ${PasswordValidator.getStrengthLabel(_passwordStrength)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          if (_passwordCharError != null && _passwordCharError!.isNotEmpty)
            Text(
              _passwordCharError!,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildStep2Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Store Information',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _storeNameController,
          decoration: InputDecoration(
            labelText: 'Store Name *',
            hintText: 'Enter your store name',
            prefixIcon: const Icon(Icons.storefront),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _storeDescriptionController,
          decoration: InputDecoration(
            labelText: 'Store Description',
            hintText: 'Describe your store and what you sell',
            prefixIcon: const Icon(Icons.description),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _contactPhoneController,
          decoration: InputDecoration(
            labelText: 'Contact Phone *',
            hintText: '9123456789',
            prefixText: '+63 ',
            prefixIcon: const Icon(Icons.phone),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _documentUploadSection(
          title: 'Business Permit *',
          documents: _permitDocuments,
          onPickImage: _pickPermitImage,
          onPickFile: _pickPermitFile,
          onRemove: (index) {
            setState(() => _permitDocuments.removeAt(index));
          },
        ),
        if (_step2Error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                _step2Error!,
                style: TextStyle(color: Colors.red[700], fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStep3Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Location Details',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 24),

        // =========================
        // PROVINCE
        // =========================
        _loadingProvinces
            ? Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            : DropdownSearch<String>(
                items: _provinces.map((p) => p['name'] as String).toList(),

                selectedItem: _selectedProvinceName,

                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  fit: FlexFit.loose,
                ),

                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select Province *',
                    prefixIcon: const Icon(Icons.map),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                onChanged: _onProvinceSelected,
              ),

        const SizedBox(height: 16),

        // =========================
        // CITY / MUNICIPALITY
        // =========================
        _selectedProvinceName == null
            ? Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: const Center(
                  child: Text(
                    'Select a province first',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : _loadingCities
            ? Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            : DropdownSearch<String>(
                items: _cities.map((c) => c['name'] as String).toList(),

                selectedItem: _selectedCityName,

                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  fit: FlexFit.loose,
                ),

                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select City / Municipality *',
                    prefixIcon: const Icon(Icons.location_city),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                onChanged: _onCitySelected,
              ),

        const SizedBox(height: 16),

        // =========================
        // BARANGAY
        // =========================
        _selectedCityName == null
            ? Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: const Center(
                  child: Text(
                    'Select a city first',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : _loadingBarangays
            ? Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            : DropdownSearch<String>(
                items: _barangays.map((b) => b['name'] as String).toList(),

                selectedItem: _selectedBarangayName,

                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  fit: FlexFit.loose,
                ),

                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select Barangay *',
                    prefixIcon: const Icon(Icons.place),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                onChanged: (value) {
                  setState(() {
                    _selectedBarangayName = value;
                  });
                  _refreshZipCodeFromApi();
                },
              ),

        const SizedBox(height: 16),

        // =========================
        // STREET
        // =========================
        TextField(
          controller: _streetController,
          decoration: InputDecoration(
            labelText: 'Street *',
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        const SizedBox(height: 16),

        // =========================
        // HOUSE NUMBER
        // =========================
        TextField(
          controller: _houseNumberController,
          decoration: InputDecoration(
            labelText: 'House Number',
            prefixIcon: const Icon(Icons.home),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        const SizedBox(height: 16),

        // =========================
        // ZIP CODE
        // =========================
        TextField(
          controller: _zipCodeController,
          decoration: InputDecoration(
            labelText: 'Zip Code',
            hintText: 'Auto-filled by location API when available',
            prefixIcon: const Icon(Icons.mail),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          readOnly: true,
        ),

        // =========================
        // ERROR DISPLAY
        // =========================
        if (_step3Error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                _step3Error!,
                style: TextStyle(color: Colors.red[700], fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _documentUploadSection({
    required String title,
    required List<PickedDocument> documents,
    required VoidCallback onPickImage,
    required VoidCallback onPickFile,
    required ValueChanged<int> onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Image'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickFile,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF/File'),
                ),
              ),
            ],
          ),
          if (documents.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('PDF, PNG, JPG, or WEBP up to 5MB.'),
            )
          else
            ...documents.asMap().entries.map((entry) {
              final index = entry.key;
              final document = entry.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  document.contentType == 'application/pdf'
                      ? Icons.picture_as_pdf
                      : Icons.image,
                ),
                title: Text(
                  document.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${(document.size / 1024).ceil()} KB'),
                trailing: IconButton(
                  onPressed: () => onRemove(index),
                  icon: const Icon(Icons.close),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildButtonRow() {
    return Row(
      children: [
        if (_currentStep > 1)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              child: const Text('Previous'),
            ),
          ),
        if (_currentStep > 1) const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : (_currentStep < 3 ? _nextStep : _submitApplication),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Text(
              _isLoading
                  ? 'Submitting...'
                  : (_currentStep < 3 ? 'Next' : 'Submit Application'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
