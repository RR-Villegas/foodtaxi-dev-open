import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/address_model.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/input_validator.dart';
import 'services/location_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _picker = ImagePicker();
  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();

  Map<String, dynamic>? _account;
  List<Address> _addresses = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final account = await DatabaseService.getCurrentAccount();
    final accountId = account?['account_id']?.toString();
    final addresses = accountId == null
        ? <Address>[]
        : await DatabaseService.getUserAddresses(accountId);

    if (!mounted) return;
    setState(() {
      _account = account;
      _addresses = addresses;
      _firstNameController.text = account?['firstname']?.toString() ?? '';
      _surnameController.text = account?['surname']?.toString() ?? '';
      _phoneController.text = account?['phone_number']?.toString() ?? '';
      _profileImagePath = account?['profile_image_url']?.toString();
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && !InputValidator.isValidPhoneNumber(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Philippine phone number')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok = await DatabaseService.updateCurrentAccountProfile(
      firstName: _firstNameController.text,
      surname: _surnameController.text,
      phoneNumber: phone,
      profileImageUrl: _profileImagePath,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Profile saved' : 'Profile could not be saved')),
    );
    if (ok) _loadProfile();
  }

  Future<void> _pickProfileImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1000,
    );
    if (image == null) return;

    setState(() => _isUploading = true);
    final path = await DatabaseService.uploadProfileImage(
      bytes: await image.readAsBytes(),
      fileName: image.name,
    );

    if (!mounted) return;
    setState(() {
      _isUploading = false;
      if (path != null) _profileImagePath = path;
    });
  }

  Future<void> _logout() async {
    await AuthService.clearLoginSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  String _formatAddress(Address address) {
    return [
      address.houseNumber,
      address.street,
      address.barangay,
      address.city,
      address.province,
      address.zipCode,
    ]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!)
        .join(', ');
  }

  Future<void> _openAddressForm([Address? address]) async {
    final provinceController = TextEditingController(text: address?.province ?? '');
    final cityController = TextEditingController(text: address?.city ?? '');
    final barangayController = TextEditingController(text: address?.barangay ?? '');
    final streetController = TextEditingController(text: address?.street ?? '');
    final houseController = TextEditingController(text: address?.houseNumber ?? '');
    final zipController = TextEditingController(text: address?.zipCode ?? '');
    var isDefault = address?.isDefault ?? _addresses.isEmpty;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(address == null ? 'Add Address' : 'Edit Address'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: houseController, decoration: const InputDecoration(labelText: 'House Number')),
                TextField(controller: streetController, decoration: const InputDecoration(labelText: 'Street')),
                TextField(controller: barangayController, decoration: const InputDecoration(labelText: 'Barangay *')),
                TextField(controller: cityController, decoration: const InputDecoration(labelText: 'City/Municipality *')),
                TextField(controller: provinceController, decoration: const InputDecoration(labelText: 'Province *')),
                TextField(
                  controller: zipController,
                  decoration: const InputDecoration(
                    labelText: 'Zip Code',
                    hintText: 'Auto-filled by location API',
                  ),
                  readOnly: true,
                ),
                SwitchListTile(
                  value: isDefault,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Main location'),
                  onChanged: (value) => setDialogState(() => isDefault = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final accountId = _account?['account_id']?.toString();
                if (accountId == null ||
                    provinceController.text.trim().isEmpty ||
                    cityController.text.trim().isEmpty ||
                    barangayController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fill in required address fields')),
                  );
                  return;
                }

                String? savedAddressId = address?.addressId;
                final point = await LocationService.geocodeAddress(
                  houseNumber: houseController.text,
                  street: streetController.text,
                  barangay: barangayController.text,
                  city: cityController.text,
                  province: provinceController.text,
                );
                if (point == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address could not be verified by the location API'),
                    ),
                  );
                  return;
                }
                final resolvedZipCode = point.postalCode?.trim().isNotEmpty == true
                    ? point.postalCode!.trim()
                    : zipController.text.trim();
                zipController.text = resolvedZipCode;
                if (address == null) {
                  final savedAddress = await DatabaseService.insertAddress(
                    accountId: accountId,
                    province: provinceController.text,
                    city: cityController.text,
                    barangay: barangayController.text,
                    street: streetController.text,
                    houseNumber: houseController.text,
                    zipCode: resolvedZipCode,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    isDefault: isDefault,
                  );
                  savedAddressId = savedAddress?.addressId;
                } else {
                  await DatabaseService.updateAddress(
                    addressId: address.addressId!,
                    province: provinceController.text,
                    city: cityController.text,
                    barangay: barangayController.text,
                    street: streetController.text,
                    houseNumber: houseController.text,
                    zipCode: resolvedZipCode,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    isDefault: isDefault,
                  );
                }

                if (isDefault) {
                  if (savedAddressId != null) {
                    await DatabaseService.setDefaultAddress(accountId, savedAddressId);
                  }
                }

                if (!mounted || !context.mounted) return;
                Navigator.pop(context);
                _loadProfile();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    provinceController.dispose();
    cityController.dispose();
    barangayController.dispose();
    streetController.dispose();
    houseController.dispose();
    zipController.dispose();
  }

  Widget _avatar() {
    final imagePath = _profileImagePath;
    if (imagePath == null || imagePath.trim().isEmpty) {
      return const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 44));
    }

    return CircleAvatar(
      radius: 44,
      backgroundImage: NetworkImage(DatabaseService.getProfileImageUrl(imagePath)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF2d8f4e),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _isUploading ? null : _pickProfileImage,
                    child: _avatar(),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _isUploading ? null : _pickProfileImage,
                    icon: const Icon(Icons.upload),
                    label: Text(_isUploading ? 'Uploading...' : 'Change Photo'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _surnameController,
                  decoration: const InputDecoration(labelText: 'Surname'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Philippine Phone Number',
                    hintText: '09xxxxxxxxx or +639xxxxxxxxx',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Text('Email: ${_account?['email'] ?? ''}'),
                Text('Role: ${_account?['account_type'] ?? ''}'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Addresses',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/addresses')
                          .then((_) => _loadProfile()),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Manage'),
                    ),
                  ],
                ),
                if (_addresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No addresses saved'),
                  )
                else
                  ..._addresses.map(
                    (address) => Card(
                      child: ListTile(
                        leading: Icon(
                          address.isDefault ? Icons.home : Icons.location_on_outlined,
                        ),
                        title: Text(_formatAddress(address)),
                        subtitle: Text(address.isDefault ? 'Main location' : 'Saved address'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(context, '/addresses')
                            .then((_) => _loadProfile()),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
