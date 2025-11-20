import 'package:flutter/foundation.dart';

class ApiConfig {
  // GIÁ TRỊ MẶC ĐỊNH (sẽ override bằng --dart-define)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (apiBaseUrl.isNotEmpty) {
      return apiBaseUrl;
    }

    // Nếu web thì dùng localhost
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }

    // Nếu Android/iOS
    return 'http://10.0.2.2:5000/api';
  }
}
