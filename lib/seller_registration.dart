import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
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

  final _storeNameController = TextEditingController();
  final _storeDescriptionController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _zipCodeController = TextEditingController();

  // Location data
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];

  String? _selectedProvinceName;
  String? _selectedProvinceCode;
  String? _selectedCityName;
  String? _selectedCityCode;
  String? _selectedBarangayName;

  bool _loadingProvinces = true;
  bool _loadingCities = false;
  bool _loadingBarangays = false;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
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
      print('Error loading provinces: $e');
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
      _selectedProvinceCode = province['code'];
      _selectedCityName = null;
      _selectedCityCode = null;
      _selectedBarangayName = null;
      _cities = [];
      _barangays = [];
      _loadingCities = true;
    });

    try {
      final cities = await LocationService.fetchMunicipalities(province['code']);
      if (mounted) {
        setState(() {
          _cities = cities;
          _loadingCities = false;
        });
      }
    } catch (e) {
      print('Error loading cities: $e');
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
      _selectedCityCode = city['code'];
      _selectedBarangayName = null;
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
      print('Error loading barangays: $e');
      if (mounted) {
        setState(() => _loadingBarangays = false);
      }
    }
  }

  bool _validateStep1() {
    setState(() => _step1Error = null);

    if (_storeNameController.text.isEmpty) {
      setState(() => _step1Error = 'Store name is required');
      return false;
    }

    if (_contactPhoneController.text.isEmpty) {
      setState(() => _step1Error = 'Phone number is required');
      return false;
    }

    return true;
  }

  bool _validateStep2() {
    setState(() => _step2Error = null);

    if (_selectedProvinceName == null) {
      setState(() => _step2Error = 'Province is required');
      return false;
    }

    if (_selectedCityName == null) {
      setState(() => _step2Error = 'Municipality/City is required');
      return false;
    }

    if (_selectedBarangayName == null) {
      setState(() => _step2Error = 'Barangay is required');
      return false;
    }

    if (_streetController.text.isEmpty) {
      setState(() => _step2Error = 'Street is required');
      return false;
    }

    return true;
  }

  void _nextStep() {
    if (_currentStep == 1 && _validateStep1()) {
      setState(() => _currentStep = 2);
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _submitApplication() async {
    if (!_validateStep2()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final accountId = await DatabaseService.getCurrentAccountId();
      if (accountId == null) {
        throw Exception('Account profile not found');
      }

      // Submit seller application
      final submitted = await DatabaseService.insertSellerApplication(
        accountId: accountId,
        storeName: _storeNameController.text.trim(),
        storeDescription: _storeDescriptionController.text.trim(),
        province: _selectedProvinceName ?? '',
        city: _selectedCityName ?? '',
        barangay: _selectedBarangayName ?? '',
        street: _streetController.text.trim(),
        houseNumber: _houseNumberController.text.trim(),
        zipCode: _zipCodeController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
      );

      if (!submitted) {
        throw Exception('Seller application could not be submitted');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Application submitted successfully! Waiting for admin approval.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
    );
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
              _currentStep == 1 ? _buildStep1Form() : _buildStep2Form(),
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
        Expanded(
          flex: 1,
          child: _buildSidePanel(),
        ),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _currentStep == 1 ? _buildStep1Form() : _buildStep2Form(),
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
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2d8f4e), Color(0xFF1e5322)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
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
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 48),
          _buildStepIndicator('Store Information', 1),
          const SizedBox(height: 24),
          _buildStepIndicator('Location Details', 2),
        ],
      ),
    );
  }

  Widget _buildStepIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStepIndicator('Store Information', 1),
        Container(
          height: 2,
          width: 40,
          color: _currentStep > 1 ? const Color(0xFF2d8f4e) : Colors.grey[300],
        ),
        _buildStepIndicator('Location Details', 2),
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
                ? const Color(0xFF2d8f4e)
                : Colors.grey[300],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isCurrent || isCompleted ? Colors.white : Colors.grey,
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
            color: isCurrent || isCompleted ? const Color(0xFF2d8f4e) : Colors.grey,
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
              borderSide: const BorderSide(color: Color(0xFF2d8f4e), width: 2),
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
              borderSide: const BorderSide(color: Color(0xFF2d8f4e), width: 2),
            ),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _contactPhoneController,
          decoration: InputDecoration(
            labelText: 'Contact Phone *',
            hintText: 'Enter your phone number',
            prefixIcon: const Icon(Icons.phone),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2d8f4e), width: 2),
            ),
          ),
          keyboardType: TextInputType.phone,
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

  Widget _buildStep2Form() {
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
              items: _provinces
                  .map((p) => p['name'] as String)
                  .toList(),

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
                  items: _cities
                      .map((c) => c['name'] as String)
                      .toList(),

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
                  items: _barangays
                      .map((b) => b['name'] as String)
                      .toList(),

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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
          prefixIcon: const Icon(Icons.mail),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // =========================
      // ERROR DISPLAY
      // =========================
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
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
              ),
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
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF2d8f4e)),
              ),
              child: const Text(
                'Previous',
                style: TextStyle(color: Color(0xFF2d8f4e)),
              ),
            ),
          ),
        if (_currentStep > 1) const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : (_currentStep == 1 ? _nextStep : _submitApplication),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2d8f4e),
              padding: const EdgeInsets.symmetric(vertical: 14),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Text(
              _isLoading
                  ? 'Submitting...'
                  : (_currentStep == 1 ? 'Next' : 'Submit Application'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
