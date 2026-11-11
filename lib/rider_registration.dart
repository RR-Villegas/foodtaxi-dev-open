import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'models/application_data.dart';
import 'models/picked_document.dart';
import 'services/database_service.dart';
import 'services/input_validator.dart';
import 'services/location_service.dart';
import 'services/local_storage_service.dart';
import 'utils/password_validator.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'widgets/house_number_input.dart';

class RiderRegistrationPage extends StatefulWidget {
  const RiderRegistrationPage({super.key});

  @override
  State<RiderRegistrationPage> createState() => _RiderRegistrationPageState();
}

class _RiderRegistrationPageState extends State<RiderRegistrationPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  int _currentStep = 1;
  String? _step1Error;
  String? _step2Error;
  String? _step3Error;

  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _plateController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _houseNumberSuffixController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final List<PickedDocument> _riderDocuments = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];
  String? _selectedProvinceName;
  String? _selectedCityName;
  String? _selectedBarangayName;
  String _vehicleType = 'Motorcycle';
  bool _loadingProvinces = true;
  bool _loadingCities = false;
  bool _loadingBarangays = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _acceptedTerms = false;
  PasswordStrength _passwordStrength = PasswordStrength.weak;
  String? _passwordCharError;

  String get _houseNumber => HouseNumberInput.combine(
    _houseNumberController.text,
    _houseNumberSuffixController.text,
  );

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
    _passwordController.removeListener(_updatePasswordStrength);
    _firstNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _plateController.dispose();
    _streetController.dispose();
    _houseNumberController.dispose();
    _houseNumberSuffixController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      final provinces = await LocationService.fetchProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _loadingProvinces = false;
      });
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
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _loadingCities = false;
      });
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
    setState(() {
      _selectedCityName = cityName;
      _selectedBarangayName = null;
      _zipCodeController.clear();
      _barangays = [];
      _loadingBarangays = true;
    });

    try {
      final barangays = await LocationService.fetchBarangays(city['code']);
      if (!mounted) return;
      setState(() {
        _barangays = barangays;
        _loadingBarangays = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingBarangays = false);
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

  Future<bool> _validateStep1() async {
    setState(() => _step1Error = null);
    final firstName = _firstNameController.text.trim();
    final surname = _surnameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final phone = _phoneController.text.trim();

    if (firstName.isEmpty || surname.isEmpty) {
      setState(() => _step1Error = 'First name and surname are required');
      return false;
    }
    if (!InputValidator.isValidName(firstName) ||
        !InputValidator.isValidName(surname)) {
      setState(() => _step1Error = 'Name contains invalid characters');
      return false;
    }
    if (!InputValidator.isValidEmail(email)) {
      setState(() => _step1Error = 'Please enter a valid email');
      return false;
    }
    if (!InputValidator.isValidPhoneNumber(phone)) {
      setState(() => _step1Error = 'Invalid Philippine phone number format');
      return false;
    }

    final emailExists = await DatabaseService.isEmailAlreadyUsed(email);

    if (emailExists) {
      setState(() => _step1Error = 'Email is already registered');
      return false;
    }

    final phoneExists =
        await DatabaseService.isPhoneAlreadyUsed(phone);

    if (phoneExists) {
      setState(() => _step1Error = 'Phone number is already registered');
      return false;
    }

    if (password.length < 8 || !InputValidator.isValidPassword(password)) {
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
    final license = _licenseController.text.trim();
    final plate = _plateController.text.trim();

    if (license.isEmpty) {
      setState(() => _step2Error = 'License number is required');
      return false;
    }
    if (plate.isEmpty) {
      setState(() => _step2Error = 'Plate number is required');
      return false;
    }
    if (InputValidator.containsSQLInjectionPatterns(license) ||
        InputValidator.containsSQLInjectionPatterns(plate)) {
      setState(
        () => _step2Error = 'Vehicle details contain invalid characters',
      );
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    setState(() => _step3Error = null);
    if (HouseNumberInput.hasSuffixWithoutNumber(
      _houseNumberController.text,
      _houseNumberSuffixController.text,
    )) {
      setState(() => _step3Error = 'Enter a house number before its suffix');
      return false;
    }
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
    if (InputValidator.containsSQLInjectionPatterns(street)) {
      setState(() => _step3Error = 'Street contains invalid characters');
      return false;
    }
    final houseNumber = _houseNumber;
    if (houseNumber.isNotEmpty &&
        InputValidator.containsSQLInjectionPatterns(houseNumber)) {
      setState(() => _step3Error = 'House number contains invalid characters');
      return false;
    }
    return true;
  }

  bool _validateStep4() {
    setState(() => _step3Error = null);
    if (_riderDocuments.isEmpty) {
      setState(() => _step3Error = 'Upload your license or vehicle document');
      return false;
    }
    return true;
  }

  Future<void> _pickRiderImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 65,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return;
    _addPickedDocument(
      PickedDocument(
        label: 'Rider verification',
        fileName: image.name,
        contentType:
            DatabaseService.applicationDocumentContentTypeFor(image.name) ?? '',
        bytes: await image.readAsBytes(),
      ),
    );
  }

  Future<void> _pickRiderFile() async {
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
        label: 'Rider verification',
        fileName: file.name,
        contentType:
            DatabaseService.applicationDocumentContentTypeFor(file.name) ?? '',
        bytes: bytes,
      ),
    );
  }

  void _addPickedDocument(PickedDocument document) {
    if (!DatabaseService.isAllowedApplicationDocumentName(document.fileName)) {
      setState(() => _step3Error = 'Only PDF, PNG, JPG, or WEBP files are allowed');
      return;
    }
    if (document.size > 5 * 1024 * 1024) {
      setState(() => _step3Error = 'Document must be 5MB or smaller');
      return;
    }
    setState(() {
      _step3Error = null;
      _riderDocuments.add(document);
    });
  }

  Future<List<Map<String, dynamic>>> _uploadRiderDocuments(String accountId) async {
    final uploaded = <Map<String, dynamic>>[];
    for (final document in _riderDocuments) {
      final metadata = await DatabaseService.uploadApplicationDocument(
        bytes: document.bytes,
        fileName: document.fileName,
        label: document.label,
        applicationType: 'rider',
        documentType: 'license',
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

  List<Map<String, dynamic>> _pendingRiderDocuments() {
    return _riderDocuments
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

  Future<void> _nextStep() async {
    if (_currentStep == 1 && await _validateStep1()) {
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2 && _validateStep2()) {
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3 && _validateStep3()) {
      setState(() => _currentStep = 4);
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

  Future<void> _submitApplication() async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms and Conditions first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_validateStep4()) return;
    setState(() => _isLoading = true);

    try {
      final currentUser = _supabase.auth.currentUser;
      final submittedWhileLoggedIn = currentUser != null;
      final point = await LocationService.geocodeAddress(
        houseNumber: _houseNumber,
        street: _streetController.text,
        barangay: _selectedBarangayName,
        city: _selectedCityName,
        province: _selectedProvinceName,
        zipCode: _zipCodeController.text,
      );
      if (point == null) {
        throw Exception('Rider address could not be verified by the location API');
      }
      final resolvedZipCode = point.postalCode?.trim().isNotEmpty == true
          ? point.postalCode!.trim()
          : _zipCodeController.text.trim();

      final data = RiderApplicationData(
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        surname: _surnameController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _phoneController.text.trim(),
        licenseNumber: _licenseController.text.trim(),
        vehicleType: _vehicleType,
        plateNumber: _plateController.text.trim(),
        province: _selectedProvinceName,
        city: _selectedCityName,
        barangay: _selectedBarangayName,
        street: _streetController.text.trim(),
        houseNumber: _houseNumber,
        zipCode: resolvedZipCode.isNotEmpty ? resolvedZipCode : null,
        documents: submittedWhileLoggedIn ? const [] : _pendingRiderDocuments(),
      );

      if (!submittedWhileLoggedIn) {
        await LocalStorageService.saveRiderApplicationData(data);
      }

      if (currentUser == null) {
        final authResponse = await _supabase.auth.signUp(
          email: data.email,
          password: data.password,
          emailRedirectTo: Uri.base.origin,
          data: {'role': 'rider'},
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
          firstName: data.firstName,
          surname: data.surname,
          email: currentUser.email ?? data.email,
          phoneNumber: data.phoneNumber,
          accountType: 'Rider',
        );
        final updatedAccount = await DatabaseService.getCurrentAccount();
        if (updatedAccount?['account_type']?.toString().toLowerCase() != 'rider') {
          throw Exception('Account was created but role did not update to Rider');
        }
        if (accountId == null) {
          throw Exception('Failed to create rider account profile');
        }

        final documents = await _uploadRiderDocuments(accountId);
        final submitted = await DatabaseService.saveRiderApplication(
          accountId: accountId,
          licenseNumber: data.licenseNumber,
          vehicleType: data.vehicleType,
          plateNumber: data.plateNumber,
          province: data.province,
          city: data.city,
          barangay: data.barangay,
          street: data.street,
          houseNumber: data.houseNumber,
          zipCode: data.zipCode,
          latitude: point.latitude,
          longitude: point.longitude,
          documentNotes: data.documentNotes,
          documents: documents,
        );
        if (!submitted) {
          throw Exception('Rider application could not be submitted');
        }
        await DatabaseService.saveRegistrationAddress(
          accountId: accountId,
          province: data.province,
          city: data.city,
          barangay: data.barangay,
          street: data.street,
          houseNumber: data.houseNumber,
          zipCode: data.zipCode,
          latitude: point.latitude,
          longitude: point.longitude,
        );
        await LocalStorageService.clearRiderApplicationData();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submittedWhileLoggedIn
                  ? 'Rider application submitted for admin review.'
                  : 'Rider application saved. Please confirm your email and log in to send it for admin review.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        if (submittedWhileLoggedIn) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/application-status',
            (route) => false,
            arguments: 'rider',
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          isMobile ? _mobileLayout() : _desktopLayout(),
          _closeButton(),
        ],
      ),
    );
  }

  Widget _closeButton() {
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

  Widget _mobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _stepIndicators(),
            const SizedBox(height: 32),
            _currentForm(),
            const SizedBox(height: 24),
            if (_currentStep == 4) ...[
              _termsCheckbox(),
              const SizedBox(height: 12),
            ],
            _buttons(),
          ],
        ),
      ),
    );
  }

  Widget _desktopLayout() {
    return Row(
      children: [
        Expanded(child: _sidePanel()),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _currentForm(),
                const SizedBox(height: 32),
                if (_currentStep == 4) ...[
                  _termsCheckbox(),
                  const SizedBox(height: 12),
                ],
                _buttons(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sidePanel() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.primary, scheme.secondary],
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Become a Rider',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Deliver orders and earn with FoodTaxi.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 48),
          _stepIndicator('Personal Info', 1, onDark: true),
          const SizedBox(height: 24),
          _stepIndicator('Vehicle Details', 2, onDark: true),
          const SizedBox(height: 24),
          _stepIndicator('Location', 3, onDark: true),
          const SizedBox(height: 24),
          _stepIndicator('Documents', 4, onDark: true),
        ],
      ),
    );
  }

  Widget _stepIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _stepIndicator('Personal', 1),
        _line(_currentStep > 1),
        _stepIndicator('Vehicle', 2),
        _line(_currentStep > 2),
        _stepIndicator('Location', 3),
        _line(_currentStep > 3),
        _stepIndicator('Docs', 4),
      ],
    );
  }

  Widget _line(bool active) {
    return Container(
      height: 2,
      width: 30,
      color: active ? Theme.of(context).colorScheme.primary : Colors.grey[300],
    );
  }

  Widget _stepIndicator(String label, int step, {bool onDark = false}) {
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
                : Text('$step'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: onDark ? Colors.white : null,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _currentForm() {
    if (_currentStep == 1) return _step1Form();
    if (_currentStep == 2) return _step2Form();
    if (_currentStep == 3) return _step3Form();
    return _step4Form();
  }

  Widget _step1Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _field(_firstNameController, 'First Name *', Icons.person),
        _field(_surnameController, 'Surname *', Icons.person),
        _field(
          _emailController,
          'Email *',
          Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        _field(
          _phoneController,
          'Phone Number *',
          Icons.phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          prefixText: '+63 ',
          hintText: '9123456789',
        ),
        _passwordField(
          controller: _passwordController,
          label: 'Password *',
          icon: Icons.lock,
          focusNode: _passwordFocusNode,
          isVisible: _showPassword,
          onToggle: () => setState(() => _showPassword = !_showPassword),
          helperText: _passwordFocusNode.hasFocus
              ? 'Allowed special characters: ! @ # \$ % ^ & *'
              : null,
        ),
        _buildPasswordStrengthIndicator(),
        _passwordField(
          controller: _confirmPasswordController,
          label: 'Re-enter Password *',
          icon: Icons.lock_outline,
          isVisible: _showConfirmPassword,
          onToggle: () => setState(
            () => _showConfirmPassword = !_showConfirmPassword,
          ),
        ),
        _error(_step1Error),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    if (_passwordController.text.isEmpty) return const SizedBox.shrink();

    final color = PasswordValidator.getStrengthColor(_passwordStrength);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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

  Widget _step2Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vehicle Details',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          initialValue: _vehicleType,
          items: const ['Motorcycle', 'Bicycle', 'Van']
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          decoration: _decoration('Vehicle Type *', Icons.two_wheeler),
          onChanged: (value) => setState(() => _vehicleType = value!),
        ),
        const SizedBox(height: 16),
        _field(_licenseController, 'License Number *', Icons.badge),
        _field(_plateController, 'Plate Number *', Icons.confirmation_number),
        _error(_step2Error),
      ],
    );
  }

  Widget _step3Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Rider Location',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _locationFields(),
        _error(_step3Error),
      ],
    );
  }

  Widget _step4Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Documents',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _documentUploadSection(
          title: 'License and Vehicle Documents *',
          documents: _riderDocuments,
          onPickImage: _pickRiderImage,
          onPickFile: _pickRiderFile,
          onRemove: (index) {
            setState(() => _riderDocuments.removeAt(index));
          },
        ),
        _error(_step3Error),
      ],
    );
  }

  Widget _buttons() {
    return Row(
      children: [
        if (_currentStep > 1)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep -= 1),
              child: const Text('Previous'),
            ),
          ),
        if (_currentStep > 1) const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : (_currentStep < 4 ? _nextStep : _submitApplication),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _isLoading
                  ? 'Submitting...'
                  : (_currentStep < 4 ? 'Next' : 'Submit Application'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _locationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _loadingProvinces
            ? _loadingLocationBox()
            : DropdownSearch<String>(
                items: _provinces.map((p) => p['name'] as String).toList(),
                selectedItem: _selectedProvinceName,
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  fit: FlexFit.loose,
                ),
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: _decoration(
                    'Select Province *',
                    Icons.map,
                  ),
                ),
                onChanged: _onProvinceSelected,
              ),
        const SizedBox(height: 16),
        _selectedProvinceName == null
            ? _disabledLocationBox('Select a province first')
            : _loadingCities
                ? _loadingLocationBox()
                : DropdownSearch<String>(
                    items: _cities.map((c) => c['name'] as String).toList(),
                    selectedItem: _selectedCityName,
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      fit: FlexFit.loose,
                    ),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _decoration(
                        'Select City / Municipality *',
                        Icons.location_city,
                      ),
                    ),
                    onChanged: _onCitySelected,
                  ),
        const SizedBox(height: 16),
        _selectedCityName == null
            ? _disabledLocationBox('Select a city first')
            : _loadingBarangays
                ? _loadingLocationBox()
                : DropdownSearch<String>(
                    items: _barangays.map((b) => b['name'] as String).toList(),
                    selectedItem: _selectedBarangayName,
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      fit: FlexFit.loose,
                    ),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _decoration(
                        'Select Barangay *',
                        Icons.place,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _selectedBarangayName = value);
                      _refreshZipCodeFromApi();
                    },
                  ),
        const SizedBox(height: 16),
        _field(_streetController, 'Street *', Icons.location_on_outlined),
        HouseNumberInput(
          numberController: _houseNumberController,
          suffixController: _houseNumberSuffixController,
          numberDecoration: const InputDecoration(
            labelText: 'House Number',
            hintText: 'Number',
            prefixIcon: Icon(Icons.home),
          ),
          suffixDecoration: const InputDecoration(
            labelText: 'Suffix',
            hintText: 'Optional',
          ),
        ),
        _field(
          _zipCodeController,
          'Zip Code',
          Icons.mail,
          readOnly: true,
          hintText: 'Auto-filled by location API',
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
    String? prefixText,
    String? hintText,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        readOnly: readOnly,
        decoration: _decoration(label, icon).copyWith(
          prefixText: prefixText,
          hintText: hintText,
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggle,
    FocusNode? focusNode,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: !isVisible,
        decoration: _decoration(label, icon).copyWith(
          helperText: helperText,
          suffixIcon: IconButton(
            icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: onToggle,
          ),
        ),
      ),
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
              child: Text(
                'Upload license, OR/CR, plate, or permit files as PDF, PNG, JPG, or WEBP up to 5MB.',
              ),
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

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
    );
  }

  Widget _loadingLocationBox() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _disabledLocationBox(String text) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: Center(child: Text(text, style: const TextStyle(color: Colors.grey))),
    );
  }

  Widget _error(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Text(message, style: TextStyle(color: Colors.red[700])),
    );
  }
}
