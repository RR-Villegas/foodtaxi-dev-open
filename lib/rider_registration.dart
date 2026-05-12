import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/application_data.dart';
import 'services/database_service.dart';
import 'services/input_validator.dart';
import 'services/local_storage_service.dart';
import 'utils/password_validator.dart';

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
  final _documentNotesController = TextEditingController();
  String _vehicleType = 'Motorcycle';
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  PasswordStrength _passwordStrength = PasswordStrength.weak;
  String? _passwordCharError;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _passwordController.addListener(_updatePasswordStrength);
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
    _documentNotesController.dispose();
    super.dispose();
  }

  bool _validateStep1() {
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
    final notes = _documentNotesController.text.trim();
    if (notes.isNotEmpty &&
        InputValidator.containsSQLInjectionPatterns(notes)) {
      setState(() => _step3Error = 'Document notes contain invalid characters');
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

  Future<void> _submitApplication() async {
    if (!_validateStep3()) return;
    setState(() => _isLoading = true);

    try {
      final data = RiderApplicationData(
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        surname: _surnameController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _phoneController.text.trim(),
        licenseNumber: _licenseController.text.trim(),
        vehicleType: _vehicleType,
        plateNumber: _plateController.text.trim(),
        documentNotes: _documentNotesController.text.trim().isEmpty
            ? null
            : _documentNotesController.text.trim(),
      );

      await LocalStorageService.saveRiderApplicationData(data);

      final currentUser = _supabase.auth.currentUser;
      final submittedWhileLoggedIn = currentUser != null;
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
        if (accountId == null) {
          throw Exception('Failed to create rider account profile');
        }

        final submitted = await DatabaseService.saveRiderApplication(
          accountId: accountId,
          licenseNumber: data.licenseNumber,
          vehicleType: data.vehicleType,
          plateNumber: data.plateNumber,
          documentNotes: data.documentNotes,
        );
        if (!submitted) {
          throw Exception('Rider application could not be submitted');
        }
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
            color: Colors.white.withOpacity(0.92),
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

  void _closePage() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
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
                _buttons(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sidePanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2d8f4e), Color(0xFF1e5322)],
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
          _stepIndicator('Personal Info', 1),
          const SizedBox(height: 24),
          _stepIndicator('Vehicle Details', 2),
          const SizedBox(height: 24),
          _stepIndicator('Documents', 3),
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
        _stepIndicator('Docs', 3),
      ],
    );
  }

  Widget _line(bool active) {
    return Container(
      height: 2,
      width: 30,
      color: active ? const Color(0xFF2d8f4e) : Colors.grey[300],
    );
  }

  Widget _stepIndicator(String label, int step) {
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
                ? const Color(0xFF2d8f4e)
                : Colors.grey[300],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white)
                : Text('$step'),
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  Widget _currentForm() {
    if (_currentStep == 1) return _step1Form();
    if (_currentStep == 2) return _step2Form();
    return _step3Form();
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
          value: _vehicleType,
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
          'Documents',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _documentNotesController,
          maxLines: 4,
          decoration: _decoration('Document Notes', Icons.description).copyWith(
            hintText: 'List the documents you will submit for admin review',
          ),
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
                : (_currentStep < 3 ? _nextStep : _submitApplication),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2d8f4e),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _isLoading
                  ? 'Submitting...'
                  : (_currentStep < 3 ? 'Next' : 'Submit Application'),
            ),
          ),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: _decoration(label, icon),
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

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2d8f4e), width: 2),
      ),
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
