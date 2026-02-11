import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// Tax calculation result.
class TaxBreakdown {
  final double subtotal;
  final double pb1Amount;
  final double ppnAmount;
  final double grandTotal;

  const TaxBreakdown({
    required this.subtotal,
    required this.pb1Amount,
    required this.ppnAmount,
    required this.grandTotal,
  });

  bool get hasTax => pb1Amount > 0 || ppnAmount > 0;
}

/// Manages tax settings (PB1 + PPN) with SQLite persistence.
class TaxProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  bool _pb1Enabled = false;
  double _pb1Rate = 10.0; // Default PB1 = 10%
  bool _ppnEnabled = false;
  double _ppnRate = 11.0; // Default PPN = 11%
  bool _isLoaded = false;

  bool get pb1Enabled => _pb1Enabled;
  double get pb1Rate => _pb1Rate;
  bool get ppnEnabled => _ppnEnabled;
  double get ppnRate => _ppnRate;
  bool get isLoaded => _isLoaded;
  bool get hasTaxEnabled => _pb1Enabled || _ppnEnabled;

  /// Load tax settings from DB.
  Future<void> load() async {
    try {
      final settings = await _db.getAllSettings();

      _pb1Enabled = settings['tax_pb1_enabled'] == 'true';
      _pb1Rate = double.tryParse(settings['tax_pb1_rate'] ?? '') ?? 10.0;
      _ppnEnabled = settings['tax_ppn_enabled'] == 'true';
      _ppnRate = double.tryParse(settings['tax_ppn_rate'] ?? '') ?? 11.0;
      _isLoaded = true;
    } catch (e) {
      debugPrint('[TaxProvider] Error loading: $e');
      _isLoaded = true;
    }
    notifyListeners();
  }

  /// Save all tax settings to DB.
  Future<void> _save() async {
    await _db.setSetting('tax_pb1_enabled', _pb1Enabled.toString());
    await _db.setSetting('tax_pb1_rate', _pb1Rate.toString());
    await _db.setSetting('tax_ppn_enabled', _ppnEnabled.toString());
    await _db.setSetting('tax_ppn_rate', _ppnRate.toString());
  }

  /// Toggle PB1 on/off.
  Future<void> setPb1Enabled(bool enabled) async {
    _pb1Enabled = enabled;
    notifyListeners();
    await _save();
  }

  /// Set PB1 rate (percentage).
  Future<void> setPb1Rate(double rate) async {
    _pb1Rate = rate;
    notifyListeners();
    await _save();
  }

  /// Toggle PPN on/off.
  Future<void> setPpnEnabled(bool enabled) async {
    _ppnEnabled = enabled;
    notifyListeners();
    await _save();
  }

  /// Set PPN rate (percentage).
  Future<void> setPpnRate(double rate) async {
    _ppnRate = rate;
    notifyListeners();
    await _save();
  }

  /// Calculate tax breakdown for a given subtotal.
  TaxBreakdown calculate(double subtotal) {
    final pb1 = _pb1Enabled ? (subtotal * _pb1Rate / 100) : 0.0;
    final ppn = _ppnEnabled ? (subtotal * _ppnRate / 100) : 0.0;
    final grand = subtotal + pb1 + ppn;

    return TaxBreakdown(
      subtotal: subtotal,
      pb1Amount: pb1,
      ppnAmount: ppn,
      grandTotal: grand,
    );
  }
}
