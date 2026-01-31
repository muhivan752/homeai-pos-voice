import 'dart:io';

/// Configuration untuk ERPNext connection.
/// Digunakan oleh ERPNextAdapter.
class ERPNextConfig {
  final String baseUrl;
  final String apiKey;
  final String apiSecret;
  final String posProfile;
  final String warehouse;
  final String defaultCustomer;

  ERPNextConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
    required this.posProfile,
    required this.warehouse,
    this.defaultCustomer = 'Walk-in Customer',
  });

  /// Load config dari environment variables.
  /// Throws jika required env tidak ada.
  factory ERPNextConfig.fromEnv() {
    final baseUrl = Platform.environment['ERP_BASE_URL'];
    final apiKey = Platform.environment['ERP_API_KEY'];
    final apiSecret = Platform.environment['ERP_API_SECRET'];
    final posProfile = Platform.environment['ERP_POS_PROFILE'];
    final warehouse = Platform.environment['ERP_WAREHOUSE'];
    final defaultCustomer = Platform.environment['ERP_DEFAULT_CUSTOMER'];

    // Validate required fields
    if (baseUrl == null || baseUrl.isEmpty) {
      throw ConfigError('ERP_BASE_URL is required');
    }
    if (apiKey == null || apiKey.isEmpty) {
      throw ConfigError('ERP_API_KEY is required');
    }
    if (apiSecret == null || apiSecret.isEmpty) {
      throw ConfigError('ERP_API_SECRET is required');
    }
    if (posProfile == null || posProfile.isEmpty) {
      throw ConfigError('ERP_POS_PROFILE is required');
    }
    if (warehouse == null || warehouse.isEmpty) {
      throw ConfigError('ERP_WAREHOUSE is required');
    }

    return ERPNextConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      apiSecret: apiSecret,
      posProfile: posProfile,
      warehouse: warehouse,
      defaultCustomer: defaultCustomer ?? 'Walk-in Customer',
    );
  }
}

class ConfigError implements Exception {
  final String message;
  ConfigError(this.message);

  @override
  String toString() => 'ConfigError: $message';
}
