import 'package:flutter/material.dart';

import 'models/address_model.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';

class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  Map<String, dynamic>? _account;
  List<Address> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
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
      _isLoading = false;
    });
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
                TextField(
                  controller: houseController,
                  decoration: const InputDecoration(labelText: 'House Number'),
                ),
                TextField(
                  controller: streetController,
                  decoration: const InputDecoration(labelText: 'Street'),
                ),
                TextField(
                  controller: barangayController,
                  decoration: const InputDecoration(labelText: 'Barangay *'),
                ),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City/Municipality *'),
                ),
                TextField(
                  controller: provinceController,
                  decoration: const InputDecoration(labelText: 'Province *'),
                ),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
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
                  final saved = await DatabaseService.insertAddress(
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
                  savedAddressId = saved?.addressId;
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

                if (isDefault && savedAddressId != null) {
                  await DatabaseService.setDefaultAddress(accountId, savedAddressId);
                }

                if (!mounted || !context.mounted) return;
                Navigator.pop(context);
                _loadAddresses();
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

  @override
  Widget build(BuildContext context) {
    final role = _account?['account_type']?.toString() ?? 'Buyer';
    final title = role == 'Seller'
        ? 'Shop Location'
        : role == 'Rider'
            ? 'Delivery Location'
            : 'My Addresses';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF2d8f4e),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddressForm(),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Address'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAddresses,
              child: _addresses.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('No addresses saved')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _addresses.length,
                      itemBuilder: (context, index) {
                        final address = _addresses[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              address.isDefault ? Icons.home : Icons.location_on_outlined,
                            ),
                            title: Text(_formatAddress(address)),
                            subtitle: Text(address.isDefault ? 'Main location' : 'Saved address'),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _openAddressForm(address),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
