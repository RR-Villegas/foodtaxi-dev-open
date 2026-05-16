class Address {
  final String? addressId;
  final String? accountId;
  final String province;
  final String city;
  final String barangay;
  final String? street;
  final String? houseNumber;
  final String? zipCode;
  final bool isDefault;
  final DateTime? createdAt;

  Address({
    this.addressId,
    this.accountId,
    required this.province,
    required this.city,
    required this.barangay,
    this.street,
    this.houseNumber,
    this.zipCode,
    this.isDefault = false,
    this.createdAt,
  });

  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'address_id': addressId,
      'account_id': accountId,
      'province': province,
      'city': city,
      'barangay': barangay,
      'street': street,
      'house_number': houseNumber,
      'zip_code': zipCode,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // Convert from Supabase JSON
  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      addressId: json['address_id'],
      accountId: json['account_id'],
      province: json['province'] ?? '',
      city: json['city'] ?? '',
      barangay: json['barangay'] ?? '',
      street: json['street'],
      houseNumber: json['house_number'],
      zipCode: json['zip_code'],
      isDefault: json['is_default'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  // Create a copy with modified fields
  Address copyWith({
    String? addressId,
    String? accountId,
    String? province,
    String? city,
    String? barangay,
    String? street,
    String? houseNumber,
    String? zipCode,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Address(
      addressId: addressId ?? this.addressId,
      accountId: accountId ?? this.accountId,
      province: province ?? this.province,
      city: city ?? this.city,
      barangay: barangay ?? this.barangay,
      street: street ?? this.street,
      houseNumber: houseNumber ?? this.houseNumber,
      zipCode: zipCode ?? this.zipCode,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
