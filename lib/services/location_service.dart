import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static const String _apiBaseUrl = 'https://psgc.gitlab.io/api';

  static List<Map<String, dynamic>>? _cachedProvinces;

  // =========================
  // FETCH PROVINCES
  // =========================
  static Future<List<Map<String, dynamic>>> fetchProvinces() async {
    try {
      if (_cachedProvinces != null) {
        return _cachedProvinces!;
      }

      final response = await http.get(
        Uri.parse('$_apiBaseUrl/provinces'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final provinces = data
            .map((item) => {
                  'code': item['code'] ?? '',
                  'name': item['name'] ?? '',
                })
            .toList();

        provinces.sort(
          (a, b) => a['name'].compareTo(b['name']),
        );

        _cachedProvinces = provinces;

        return provinces;
      }

      return [];
    } catch (e) {
      print('Error fetching provinces: $e');
      return [];
    }
  }

  // =========================
  // FETCH CITIES + MUNICIPALITIES
  // =========================
  static Future<List<Map<String, dynamic>>>
      fetchCitiesAndMunicipalities(
    String provinceCode,
  ) async {
    try {
      final cityResponse = await http.get(
        Uri.parse('$_apiBaseUrl/provinces/$provinceCode/cities'),
      );

      final municipalityResponse = await http.get(
        Uri.parse('$_apiBaseUrl/provinces/$provinceCode/municipalities'),
      );

      List<Map<String, dynamic>> results = [];

      if (cityResponse.statusCode == 200) {
        final List<dynamic> cities = jsonDecode(cityResponse.body);

        results.addAll(
          cities.map(
            (item) => {
              'code': item['code'] ?? '',
              'name': item['name'] ?? '',
            },
          ),
        );
      }

      if (municipalityResponse.statusCode == 200) {
        final List<dynamic> municipalities =
            jsonDecode(municipalityResponse.body);

        results.addAll(
          municipalities.map(
            (item) => {
              'code': item['code'] ?? '',
              'name': item['name'] ?? '',
            },
          ),
        );
      }

      results.sort(
        (a, b) => a['name'].compareTo(b['name']),
      );

      return results;
    } catch (e) {
      print('Error fetching cities/municipalities: $e');
      return [];
    }
  }

  // =========================
  // FETCH BARANGAYS
  // =========================
  static Future<List<Map<String, dynamic>>> fetchBarangays(
    String municipalityCode,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_apiBaseUrl/cities-municipalities/$municipalityCode/barangays',
        ),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final barangays = data
            .map((item) => {
                  'code': item['code'] ?? '',
                  'name': item['name'] ?? '',
                })
            .toList();

        barangays.sort(
          (a, b) => a['name'].compareTo(b['name']),
        );

        return barangays;
      }

      return [];
    } catch (e) {
      print('Error fetching barangays: $e');
      return [];
    }
  }
}