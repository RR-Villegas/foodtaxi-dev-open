import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_taxi/models/application_data.dart';
import 'package:food_taxi/models/user_model.dart';
import 'package:food_taxi/services/local_storage_service.dart';
import 'package:food_taxi/widgets/house_number_input.dart';

void main() {
  test(
    'passwords are excluded from serialized signup and application data',
    () {
      final signup = UserSignupData(
        email: 'buyer@example.com',
        password: 'Secret123!',
      );
      final seller = SellerApplicationData(
        email: 'seller@example.com',
        firstName: 'Seller',
        surname: 'Test',
        password: 'Secret123!',
        storeName: 'Store',
        city: 'City',
        contactPhone: '9123456789',
      );
      final rider = RiderApplicationData(
        email: 'rider@example.com',
        firstName: 'Rider',
        surname: 'Test',
        password: 'Secret123!',
        phoneNumber: '9123456789',
        licenseNumber: '123',
        vehicleType: 'Motorcycle',
        plateNumber: 'ABC123',
      );

      expect(signup.toJson(), isNot(contains('password')));
      expect(seller.toJson(), isNot(contains('password')));
      expect(rider.toJson(), isNot(contains('password')));
    },
  );

  test('legacy pending data has stored passwords removed', () async {
    SharedPreferences.setMockInitialValues({
      'signup_data': jsonEncode({
        'email': 'buyer@example.com',
        'password': 'secret',
      }),
      'seller_application_data': jsonEncode({
        'email': 'seller@example.com',
        'password': 'secret',
      }),
      'rider_application_data': jsonEncode({
        'email': 'rider@example.com',
        'password': 'secret',
      }),
    });

    await LocalStorageService.removePersistedPasswords();
    final prefs = await SharedPreferences.getInstance();

    for (final key in [
      'signup_data',
      'seller_application_data',
      'rider_application_data',
    ]) {
      final data = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      expect(data, isNot(contains('password')));
      expect(data, contains('email'));
    }
  });

  testWidgets('house number input filters letters and appends a suffix', (
    tester,
  ) async {
    final number = TextEditingController();
    final suffix = TextEditingController();
    addTearDown(number.dispose);
    addTearDown(suffix.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HouseNumberInput(
            numberController: number,
            suffixController: suffix,
            numberDecoration: const InputDecoration(labelText: 'House Number'),
            suffixDecoration: const InputDecoration(labelText: 'Suffix'),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '12B');
    await tester.enterText(find.byType(TextField).last, 'A');

    expect(number.text, '12');
    expect(suffix.text, 'A');
    expect(HouseNumberInput.combine(number.text, suffix.text), '12-A');
  });
}
