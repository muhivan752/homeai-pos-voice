import 'intent.dart';

class IntentParser {
  Intent parse(String text) {
    final normalized = text.toLowerCase().trim();

    // jual <item> <qty>
    final sellRegex = RegExp(r'jual\s+(.+?)\s+(\d+)$');
    final sellMatch = sellRegex.firstMatch(normalized);

    if (sellMatch != null) {
      return Intent(
        IntentType.sellItem,
        {
          'item': sellMatch.group(1),
          'qty': int.parse(sellMatch.group(2)!),
        },
      );
    }

    // checkout / bayar
    if (normalized.contains('checkout') || normalized.contains('bayar')) {
      return Intent(
        IntentType.checkout,
        {},
      );
    }

    return Intent(
      IntentType.unknown,
      {},
    );
  }
}