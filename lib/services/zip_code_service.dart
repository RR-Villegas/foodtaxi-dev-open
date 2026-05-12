class ZipCodeService {
  static const Map<String, String> _zipCodes = {
    'caloocan': '1400',
    'las pinas': '1740',
    'makati': '1200',
    'malabon': '1470',
    'mandaluyong': '1550',
    'manila': '1000',
    'marikina': '1800',
    'muntinlupa': '1770',
    'navotas': '1485',
    'paranaque': '1700',
    'pasay': '1300',
    'pasig': '1600',
    'pateros': '1620',
    'quezon city': '1100',
    'san juan': '1500',
    'taguig': '1630',
    'valenzuela': '1440',
    'angeles': '2009',
    'baguio': '2600',
    'batangas city': '4200',
    'cabanatuan': '3100',
    'calamba': '4027',
    'cebu city': '6000',
    'davao city': '8000',
    'iloilo city': '5000',
    'lapu-lapu': '6015',
    'lucena': '4301',
    'mandaue': '6014',
    'naga': '4400',
    'olongapo': '2200',
    'san fernando': '2000',
    'santa rosa': '4026',
    'tarlac city': '2300',
    'zamboanga city': '7000',
  };

  static String? fromCityName(String? cityName) {
    final normalized = _normalize(cityName);
    if (normalized.isEmpty) return null;

    return _zipCodes[normalized] ??
        _zipCodes[normalized.replaceFirst('city of ', '')] ??
        _zipCodes[normalized.replaceFirst('municipality of ', '')];
  }

  static String _normalize(String? value) {
    return (value ?? '')
        .toLowerCase()
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
