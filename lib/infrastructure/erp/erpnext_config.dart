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
}
