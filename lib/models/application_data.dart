import 'dart:convert';

class SellerApplicationData {
  final String email;
  final String firstName;
  final String surname;
  final String password;
  final String storeName;
  final String? storeDescription;
  final String? province;
  final String city;
  final String? barangay;
  final String? street;
  final String? houseNumber;
  final String? zipCode;
  final String contactPhone;

  const SellerApplicationData({
    required this.email,
    required this.firstName,
    required this.surname,
    required this.password,
    required this.storeName,
    this.storeDescription,
    this.province,
    required this.city,
    this.barangay,
    this.street,
    this.houseNumber,
    this.zipCode,
    required this.contactPhone,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'firstName': firstName,
    'surname': surname,
    'password': password,
    'storeName': storeName,
    'storeDescription': storeDescription,
    'province': province,
    'city': city,
    'barangay': barangay,
    'street': street,
    'houseNumber': houseNumber,
    'zipCode': zipCode,
    'contactPhone': contactPhone,
  };

  factory SellerApplicationData.fromJson(Map<String, dynamic> json) {
    return SellerApplicationData(
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      surname: json['surname'] ?? '',
      password: json['password'] ?? '',
      storeName: json['storeName'] ?? '',
      storeDescription: json['storeDescription'],
      province: json['province'],
      city: json['city'] ?? '',
      barangay: json['barangay'],
      street: json['street'],
      houseNumber: json['houseNumber'],
      zipCode: json['zipCode'],
      contactPhone: json['contactPhone'] ?? '',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory SellerApplicationData.fromJsonString(String value) {
    return SellerApplicationData.fromJson(jsonDecode(value));
  }
}

class RiderApplicationData {
  final String email;
  final String firstName;
  final String surname;
  final String password;
  final String phoneNumber;
  final String licenseNumber;
  final String vehicleType;
  final String plateNumber;
  final String? documentNotes;

  const RiderApplicationData({
    required this.email,
    required this.firstName,
    required this.surname,
    required this.password,
    required this.phoneNumber,
    required this.licenseNumber,
    required this.vehicleType,
    required this.plateNumber,
    this.documentNotes,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'firstName': firstName,
    'surname': surname,
    'password': password,
    'phoneNumber': phoneNumber,
    'licenseNumber': licenseNumber,
    'vehicleType': vehicleType,
    'plateNumber': plateNumber,
    'documentNotes': documentNotes,
  };

  factory RiderApplicationData.fromJson(Map<String, dynamic> json) {
    return RiderApplicationData(
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      surname: json['surname'] ?? '',
      password: json['password'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      licenseNumber: json['licenseNumber'] ?? '',
      vehicleType: json['vehicleType'] ?? 'Motorcycle',
      plateNumber: json['plateNumber'] ?? '',
      documentNotes: json['documentNotes'],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory RiderApplicationData.fromJsonString(String value) {
    return RiderApplicationData.fromJson(jsonDecode(value));
  }
}
