import 'dart:io';

import 'package:flutter/foundation.dart';

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

  /// Compile-time constants dari --dart-define (untuk web)
  static const _erpBaseUrl = String.fromEnvironment('ERP_BASE_URL');
  static const _erpApiKey = String.fromEnvironment('ERP_API_KEY');
  static const _erpApiSecret = String.fromEnvironment('ERP_API_SECRET');
  static const _erpPosProfile = String.fromEnvironment('ERP_POS_PROFILE');
  static const _erpWarehouse = String.fromEnvironment('ERP_WAREHOUSE');
  static const _erpDefaultCustomer = String.fromEnvironment('ERP_DEFAULT_CUSTOMER');

  /// Check apakah config tersedia via compile-time constants
  static bool get hasWebConfig =>
      _erpBaseUrl.isNotEmpty &&
      _erpApiKey.isNotEmpty &&
      _erpApiSecret.isNotEmpty &&
      _erpPosProfile.isNotEmpty &&
      _erpWarehouse.isNotEmpty;

  /// Load config dari environment variables atau compile-time constants.
  /// Untuk web: gunakan --dart-define saat build.
  /// Untuk native: gunakan environment variables.
  factory ERPNextConfig.fromEnv() {
    String? baseUrl;
    String? apiKey;
    String? apiSecret;
    String? posProfile;
    String? warehouse;
    String? defaultCustomer;

    if (kIsWeb) {
      // Web: gunakan compile-time constants
      baseUrl = _erpBaseUrl.isNotEmpty ? _erpBaseUrl : null;
      apiKey = _erpApiKey.isNotEmpty ? _erpApiKey : null;
      apiSecret = _erpApiSecret.isNotEmpty ? _erpApiSecret : null;
      posProfile = _erpPosProfile.isNotEmpty ? _erpPosProfile : null;
      warehouse = _erpWarehouse.isNotEmpty ? _erpWarehouse : null;
      defaultCustomer = _erpDefaultCustomer.isNotEmpty ? _erpDefaultCustomer : null;
    } else {
      // Native: gunakan Platform.environment
      baseUrl = Platform.environment['ERP_BASE_URL'];
      apiKey = Platform.environment['ERP_API_KEY'];
      apiSecret = Platform.environment['ERP_API_SECRET'];
      posProfile = Platform.environment['ERP_POS_PROFILE'];
      warehouse = Platform.environment['ERP_WAREHOUSE'];
      defaultCustomer = Platform.environment['ERP_DEFAULT_CUSTOMER'];
    }

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
