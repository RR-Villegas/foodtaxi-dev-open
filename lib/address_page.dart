import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';

import 'models/address_model.dart';
import 'services/database_service.dart';
import 'services/input_validator.dart';
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

  String _cleanAddressText(String text) {
    return InputValidator.cleanDisplayText(text);
  }

  Future<void> _openAddressForm([Address? address]) async {
    final streetController = TextEditingController(text: address?.street ?? '');
    final houseController = TextEditingController(text: address?.houseNumber ?? '');
    final zipController = TextEditingController(text: address?.zipCode ?? '');
    var provinces = await LocationService.fetchProvinces();
    var cities = <Map<String, dynamic>>[];
    var barangays = <Map<String, dynamic>>[];
    var selectedProvince =
        (address?.province.trim().isNotEmpty ?? false) ? address!.province : null;
    var selectedCity =
        (address?.city.trim().isNotEmpty ?? false) ? address!.city : null;
    var selectedBarangay =
        (address?.barangay.trim().isNotEmpty ?? false) ? address!.barangay : null;
    var loadingCities = false;
    var loadingBarangays = false;
    var isDefault = address?.isDefault ?? _addresses.isEmpty;

    Future<void> loadCities(StateSetter setDialogState, String provinceName) async {
      final province = provinces.firstWhere(
        (p) => p['name'] == provinceName,
        orElse: () => {},
      );
      final provinceCode = province['code']?.toString();
      if (provinceCode == null || provinceCode.isEmpty) return;
      setDialogState(() {
        loadingCities = true;
        cities = [];
        barangays = [];
        selectedCity = null;
        selectedBarangay = null;
        zipController.clear();
      });
      final loaded = await LocationService.fetchCitiesAndMunicipalities(
        provinceCode,
      );
      if (!mounted) return;
      setDialogState(() {
        cities = loaded;
        loadingCities = false;
      });
    }

    Future<void> loadBarangays(StateSetter setDialogState, String cityName) async {
      final city = cities.firstWhere(
        (c) => c['name'] == cityName,
        orElse: () => {},
      );
      final cityCode = city['code']?.toString();
      if (cityCode == null || cityCode.isEmpty) return;
      setDialogState(() {
        loadingBarangays = true;
        barangays = [];
        selectedBarangay = null;
        zipController.clear();
      });
      final loaded = await LocationService.fetchBarangays(cityCode);
      if (!mounted) return;
      setDialogState(() {
        barangays = loaded;
        loadingBarangays = false;
      });
    }

    if (selectedProvince != null && selectedProvince.isNotEmpty) {
      final province = provinces.firstWhere(
        (p) => p['name'] == selectedProvince,
        orElse: () => {},
      );
      final provinceCode = province['code']?.toString();
      if (provinceCode != null && provinceCode.isNotEmpty) {
        cities = await LocationService.fetchCitiesAndMunicipalities(
          provinceCode,
        );
      }
    }
    if (selectedCity != null && selectedCity!.isNotEmpty) {
      final city = cities.firstWhere(
        (c) => c['name'] == selectedCity,
        orElse: () => {},
      );
      final cityCode = city['code']?.toString();
      if (cityCode != null && cityCode.isNotEmpty) {
        barangays = await LocationService.fetchBarangays(cityCode);
      }
    }

    if (!mounted) return;
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
                DropdownSearch<String>(
                  items: provinces.map((p) => p['name'] as String).toList(),
                  selectedItem: selectedProvince,
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    fit: FlexFit.loose,
                  ),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Province *',
                      prefixIcon: Icon(Icons.map),
                    ),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    selectedProvince = value;
                    loadCities(setDialogState, value);
                  },
                ),
                const SizedBox(height: 12),
                if (selectedProvince == null)
                  _disabledLocationBox('Select a province first')
                else if (loadingCities)
                  _loadingLocationBox()
                else
                  DropdownSearch<String>(
                    items: cities.map((c) => c['name'] as String).toList(),
                    selectedItem: selectedCity,
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      fit: FlexFit.loose,
                    ),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'City/Municipality *',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      selectedCity = value;
                      loadBarangays(setDialogState, value);
                    },
                  ),
                const SizedBox(height: 12),
                if (selectedCity == null)
                  _disabledLocationBox('Select a city first')
                else if (loadingBarangays)
                  _loadingLocationBox()
                else
                  DropdownSearch<String>(
                    items: barangays.map((b) => b['name'] as String).toList(),
                    selectedItem: selectedBarangay,
                    popupProps: const PopupProps.menu(
                      showSearchBox: true,
                      fit: FlexFit.loose,
                    ),
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Barangay *',
                        prefixIcon: Icon(Icons.place),
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() => selectedBarangay = value);
                    },
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
                    selectedProvince == null ||
                    selectedCity == null ||
                    selectedBarangay == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fill in required address fields')),
                  );
                  return;
                }

                String? savedAddressId = address?.addressId;
                final houseNumber = _cleanAddressText(houseController.text);
                final street = _cleanAddressText(streetController.text);
                final point = await LocationService.geocodeAddress(
                  houseNumber: houseNumber,
                  street: street,
                  barangay: selectedBarangay,
                  city: selectedCity,
                  province: selectedProvince,
                  zipCode: zipController.text,
                );
                if (!context.mounted) return;
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
                    province: selectedProvince,
                    city: selectedCity,
                    barangay: selectedBarangay,
                    street: street,
                    houseNumber: houseNumber,
                    zipCode: resolvedZipCode,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    isDefault: isDefault,
                  );
                  savedAddressId = saved?.addressId;
                } else {
                  await DatabaseService.updateAddress(
                    addressId: address.addressId!,
                    province: selectedProvince,
                    city: selectedCity,
                    barangay: selectedBarangay,
                    street: street,
                    houseNumber: houseNumber,
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

    streetController.dispose();
    houseController.dispose();
    zipController.dispose();
  }

  Widget _loadingLocationBox() {
    return Container(
      height: 56,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _disabledLocationBox(String text) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
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
