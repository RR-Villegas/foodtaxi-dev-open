import 'dart:convert';

class UserSignupData {
  // Step 1: Authentication
  String? email;
  String? password;

  // Step 2: Personal Information
  String? firstName;
  String? surname;
  String? phoneNumber;

  // Step 3: Address Information
  String? province;
  String? municipality;
  String? barangay;
  String? street;
  String? houseNumber;

  // Account type (buyer/seller)
  String accountType = 'buyer';

  UserSignupData({
    this.email,
    this.password,
    this.firstName,
    this.surname,
    this.phoneNumber,
    this.province,
    this.municipality,
    this.barangay,
    this.street,
    this.houseNumber,
    this.accountType = 'buyer',
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'firstName': firstName,
      'surname': surname,
      'phoneNumber': phoneNumber,
      'province': province,
      'municipality': municipality,
      'barangay': barangay,
      'street': street,
      'houseNumber': houseNumber,
      'accountType': accountType,
    };
  }

  // Convert from JSON
  factory UserSignupData.fromJson(Map<String, dynamic> json) {
    return UserSignupData(
      email: json['email'],
      password: json['password'],
      firstName: json['firstName'],
      surname: json['surname'],
      phoneNumber: json['phoneNumber'],
      province: json['province'],
      municipality: json['municipality'],
      barangay: json['barangay'],
      street: json['street'],
      houseNumber: json['houseNumber'],
      accountType: json['accountType'] ?? 'buyer',
    );
  }

  // Convert to JSON string for storage
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Parse from JSON string
  factory UserSignupData.fromJsonString(String jsonString) {
    return UserSignupData.fromJson(jsonDecode(jsonString));
  }

  // Check if step 1 is complete
  bool isStep1Complete() {
    return email != null && email!.isNotEmpty && 
           password != null && password!.isNotEmpty;
  }

  // Check if step 2 is complete
  bool isStep2Complete() {
    return isStep1Complete() &&
           firstName != null && firstName!.isNotEmpty &&
           surname != null && surname!.isNotEmpty &&
           phoneNumber != null && phoneNumber!.isNotEmpty;
  }

  // Check if step 3 is complete
  bool isStep3Complete() {
    return isStep2Complete() &&
           province != null && province!.isNotEmpty &&
           municipality != null && municipality!.isNotEmpty &&
           barangay != null && barangay!.isNotEmpty &&
           street != null && street!.isNotEmpty &&
           houseNumber != null && houseNumber!.isNotEmpty;
  }
}
