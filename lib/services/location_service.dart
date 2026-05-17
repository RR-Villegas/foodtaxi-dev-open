import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class GeoPoint {
  final double latitude;
  final double longitude;
  final String? postalCode;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.postalCode,
  });
}

class LocationService {
  static const String _apiBaseUrl = 'https://psgc.gitlab.io/api';
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org/search';
  static const String _osrmUrl = 'https://router.project-osrm.org/route/v1/driving';
  static const int bulkDeliveryMinOrders = 10;
  static const int bulkDeliveryMaxOrders = 20;
  static const double bulkDeliveryLongDistanceKm = 12;

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

  static String buildAddressQuery({
    String? houseNumber,
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? zipCode,
  }) {
    final parts = [
      houseNumber,
      street,
      barangay,
      city,
      province,
      zipCode,
      'Philippines',
    ]
        .map((part) => part?.toString().trim() ?? '')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  static List<String> _addressQueryCandidates({
    String? houseNumber,
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? zipCode,
  }) {
    final normalizedCity = _normalizePlaceName(city);
    final normalizedProvince = _normalizePlaceName(province);
    final normalizedBarangay = _normalizePlaceName(barangay);

    final candidates = [
      buildAddressQuery(
        houseNumber: houseNumber,
        street: street,
        barangay: barangay,
        city: city,
        province: province,
        zipCode: zipCode,
      ),
      buildAddressQuery(
        houseNumber: houseNumber,
        street: street,
        barangay: normalizedBarangay,
        city: normalizedCity,
        province: normalizedProvince,
        zipCode: zipCode,
      ),
      buildAddressQuery(
        barangay: normalizedBarangay,
        city: normalizedCity,
        province: normalizedProvince,
        zipCode: zipCode,
      ),
      buildAddressQuery(
        city: normalizedCity,
        province: normalizedProvince,
        zipCode: zipCode,
      ),
      buildAddressQuery(
        city: normalizedCity,
        province: normalizedProvince,
      ),
    ];

    final seen = <String>{};
    return candidates
        .map((query) => query.trim())
        .where((query) => query.isNotEmpty && seen.add(query.toLowerCase()))
        .toList();
  }

  static String? _normalizePlaceName(String? value) {
    var normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return normalized;

    normalized = normalized
        .replaceAll(RegExp(r'\bCITY OF\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bMUNICIPALITY OF\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bPROVINCE OF\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bSTA\.?\b', caseSensitive: false), 'Santa')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized.isEmpty ? value?.trim() : normalized;
  }

  static Future<GeoPoint?> geocodeAddress({
    String? houseNumber,
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? zipCode,
  }) async {
    final queries = _addressQueryCandidates(
      houseNumber: houseNumber,
      street: street,
      barangay: barangay,
      city: city,
      province: province,
      zipCode: zipCode,
    );
    if (queries.isEmpty) return null;

    for (final query in queries) {
      final uri = Uri.parse(_nominatimUrl).replace(
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'addressdetails': '1',
          'limit': '1',
          'countrycodes': 'ph',
        },
      );

      try {
        final response = await http.get(
          uri,
          headers: const {
            'User-Agent': 'FoodTaxiMobile/1.0 support@foodtaxi.local',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) continue;
        final data = jsonDecode(response.body);
        if (data is! List || data.isEmpty || data.first is! Map) continue;
        final item = data.first as Map;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;
        return GeoPoint(
          latitude: lat,
          longitude: lon,
          postalCode: _extractPostalCode(item),
        );
      } catch (e) {
        print('Error geocoding address "$query": $e');
      }
    }

    return null;
  }

  static Future<String?> postalCodeForAddress({
    String? houseNumber,
    String? street,
    String? barangay,
    String? city,
    String? province,
  }) async {
    final point = await geocodeAddress(
      houseNumber: houseNumber,
      street: street,
      barangay: barangay,
      city: city,
      province: province,
    );
    final postalCode = point?.postalCode?.trim();
    return postalCode == null || postalCode.isEmpty ? null : postalCode;
  }

  static Future<double?> roadDistanceKm(GeoPoint from, GeoPoint to) async {
    try {
      final coords =
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final uri = Uri.parse('$_osrmUrl/$coords').replace(
        queryParameters: {'overview': 'false'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final routes = data is Map ? data['routes'] : null;
      if (routes is! List || routes.isEmpty || routes.first is! Map) return null;
      final distanceMeters = (routes.first as Map)['distance'];
      if (distanceMeters is num) return distanceMeters / 1000;
      return double.tryParse(distanceMeters?.toString() ?? '') == null
          ? null
          : double.parse(distanceMeters.toString()) / 1000;
    } catch (e) {
      print('Error fetching route distance: $e');
      return null;
    }
  }

  static double straightLineDistanceKm(GeoPoint from, GeoPoint to) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(to.latitude - from.latitude);
    final dLon = _radians(to.longitude - from.longitude);
    final lat1 = _radians(from.latitude);
    final lat2 = _radians(to.latitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double deliveryFeeForDistance(double distanceKm) {
    return max(10, distanceKm * 10).ceilToDouble();
  }

  static int bulkDeliveryShareCount(double distanceKm) {
    return distanceKm >= bulkDeliveryLongDistanceKm
        ? bulkDeliveryMaxOrders
        : bulkDeliveryMinOrders;
  }

  static double bulkDeliveryFeeForDistance(double distanceKm) {
    final sharedFee =
        deliveryFeeForDistance(distanceKm) / bulkDeliveryShareCount(distanceKm);
    return max(10, sharedFee).ceilToDouble();
  }

  static double _radians(double degrees) => degrees * pi / 180;

  static String? _extractPostalCode(Map item) {
    final address = item['address'];
    if (address is! Map) return null;

    for (final key in ['postcode', 'postal_code']) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }
}
