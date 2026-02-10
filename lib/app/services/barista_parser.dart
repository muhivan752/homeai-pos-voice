import 'dart:math';
import '../models/product.dart';

/// Intent types recognized by the barista parser.
enum BaristaIntent {
  addItem,
  removeItem,
  checkout,
  clearCart,
  greeting,
  thanks,
  askMenu,
  unknown,
}

/// Result of parsing a voice command.
class ParseResult {
  final BaristaIntent intent;
  final Product? product;
  final int quantity;
  final String rawText;
  final double confidence;
  final String? paymentMethod;

  const ParseResult({
    required this.intent,
    this.product,
    this.quantity = 1,
    this.rawText = '',
    this.confidence = 1.0,
    this.paymentMethod,
  });
}

/// Smart local NLP parser for Indonesian voice commands.
///
/// Understands casual Indonesian, slang, word-numbers,
/// and common speech-to-text mistakes. Designed to be
/// swapped with an LLM-based parser later.
class BaristaParser {
  // Last added product for context ("satu lagi", "tambah lagi")
  Product? _lastProduct;

  /// Word-to-number mapping for Indonesian + English
  static const Map<String, int> _wordNumbers = {
    'satu': 1, 'se': 1, 'siji': 1, 'one': 1, 'wan': 1,
    'dua': 2, 'duo': 2, 'loro': 2, 'two': 2, 'tu': 2,
    'tiga': 3, 'three': 3, 'telu': 3, 'tri': 3, 'tree': 3,
    'empat': 4, 'four': 4, 'papat': 4, 'for': 4,
    'lima': 5, 'five': 5, 'fife': 5,
    'enam': 6, 'six': 6, 'nem': 6,
    'tujuh': 7, 'seven': 7, 'pitu': 7,
    'delapan': 8, 'eight': 8, 'wolu': 8,
    'sembilan': 9, 'nine': 9, 'songo': 9,
    'sepuluh': 10, 'ten': 10,
  };

  /// Keywords that signal adding an item
  static const List<String> _addKeywords = [
    'jual', 'tambah', 'add', 'pesan', 'pesen',
    'mau', 'minta', 'kasih', 'beli', 'order',
    'bikin', 'buatin', 'bikinin', 'saya mau',
    'gue mau', 'gw mau', 'aku mau', 'tolong',
    'bisa', 'boleh', 'coba',
  ];

  /// Keywords that signal removing an item
  static const List<String> _removeKeywords = [
    'batal', 'cancel', 'hapus', 'gak jadi',
    'ga jadi', 'nggak jadi', 'ga usah', 'gak usah',
    'jangan', 'remove', 'delete', 'hilangkan',
    'coret', 'buang', 'batalin', 'cancelkan',
  ];

  /// Keywords that signal checkout
  static const List<String> _checkoutKeywords = [
    'bayar', 'checkout', 'cek out', 'check out',
    'selesai', 'udah', 'udah itu aja', 'itu aja',
    'cukup', 'sudah', 'total', 'hitung',
    'uda', 'udh', 'sdh', 'done', 'finish',
    'pas', 'segitu aja', 'udahan',
  ];

  /// Keywords that signal clearing the cart
  static const List<String> _clearKeywords = [
    'hapus semua', 'batal semua', 'cancel semua',
    'kosongkan', 'clear', 'reset', 'ulang',
    'mulai ulang', 'dari awal', 'ulangi',
  ];

  /// Keywords for greetings
  static const List<String> _greetingKeywords = [
    'halo', 'hai', 'hello', 'hi', 'hey',
    'selamat pagi', 'selamat siang', 'selamat sore',
    'selamat malam', 'pagi', 'siang', 'sore', 'malam',
    'assalamualaikum', 'permisi',
  ];

  /// Keywords for thanks
  static const List<String> _thanksKeywords = [
    'makasih', 'terima kasih', 'thanks', 'thank you',
    'tengkyu', 'tq', 'trims', 'nuhun', 'matur nuwun',
  ];

  /// Keywords for asking menu
  static const List<String> _menuKeywords = [
    'menu', 'ada apa', 'apa aja', 'daftar',
    'pilihan', 'rekomendasi', 'rekomen',
  ];

  /// Keywords that indicate "more" / repeat last
  static const List<String> _repeatKeywords = [
    'lagi', 'lgi', 'tambah lagi', 'satu lagi',
    'yang sama', 'sama lagi', 'repeat',
  ];

  /// Payment method detection
  static const Map<String, String> _paymentKeywords = {
    'qris': 'QRIS',
    'qr': 'QRIS',
    'scan': 'QRIS',
    'tunai': 'Cash',
    'cash': 'Cash',
    'kas': 'Cash',
    'transfer': 'Transfer',
    'tf': 'Transfer',
    'debit': 'Card',
    'kartu': 'Card',
    'card': 'Card',
    'kredit': 'Card',
    'ovo': 'E-Wallet',
    'gopay': 'E-Wallet',
    'dana': 'E-Wallet',
    'shopeepay': 'E-Wallet',
    'linkaja': 'E-Wallet',
  };

  /// Modifiers to strip from product search (not part of product name)
  static const List<String> _modifiers = [
    'dong', 'donk', 'ya', 'yaa', 'yaaa', 'yah',
    'nih', 'ini', 'itu', 'yang', 'nya', 'kak',
    'bang', 'mas', 'mbak', 'bro', 'sis',
    'tolong', 'bisa', 'boleh', 'coba',
    'saya', 'aku', 'gue', 'gw', 'gua',
    'mau', 'minta', 'kasih', 'please',
  ];

  /// Filler words from speech-to-text
  static const List<String> _fillerWords = [
    'eh', 'um', 'uh', 'hmm', 'emm', 'eee',
    'anu', 'apa', 'gimana', 'terus',
  ];

  /// Parse a voice command text into a structured result.
  ParseResult parse(String text, {List<Product>? products}) {
    final raw = text;
    final lower = text.toLowerCase().trim();

    if (lower.isEmpty) {
      return ParseResult(intent: BaristaIntent.unknown, rawText: raw);
    }

    // 1. Check greetings first (short commands)
    if (_matchesAny(lower, _greetingKeywords)) {
      return ParseResult(
        intent: BaristaIntent.greeting,
        rawText: raw,
        confidence: 0.95,
      );
    }

    // 2. Check thanks
    if (_matchesAny(lower, _thanksKeywords)) {
      return ParseResult(
        intent: BaristaIntent.thanks,
        rawText: raw,
        confidence: 0.95,
      );
    }

    // 3. Check menu inquiry
    if (_matchesAny(lower, _menuKeywords)) {
      return ParseResult(
        intent: BaristaIntent.askMenu,
        rawText: raw,
        confidence: 0.9,
      );
    }

    // 4. Check clear cart (before checkout, since "batal semua" > "batal")
    if (_matchesAny(lower, _clearKeywords)) {
      return ParseResult(
        intent: BaristaIntent.clearCart,
        rawText: raw,
        confidence: 0.95,
      );
    }

    // 5. Check checkout
    final checkoutResult = _parseCheckout(lower, raw);
    if (checkoutResult != null) return checkoutResult;

    // 6. Check remove item
    final removeResult = _parseRemove(lower, raw, products);
    if (removeResult != null) return removeResult;

    // 7. Check "lagi" / repeat last
    if (_lastProduct != null && _matchesAny(lower, _repeatKeywords)) {
      final qty = _extractQuantity(lower);
      return ParseResult(
        intent: BaristaIntent.addItem,
        product: _lastProduct,
        quantity: qty,
        rawText: raw,
        confidence: 0.85,
      );
    }

    // 8. Check add item (with keywords)
    final addResult = _parseAddItem(lower, raw, products);
    if (addResult != null) return addResult;

    // 9. Try direct product match (no keyword needed)
    final directResult = _parseDirectProduct(lower, raw, products);
    if (directResult != null) return directResult;

    // 10. Unknown
    return ParseResult(
      intent: BaristaIntent.unknown,
      rawText: raw,
      confidence: 0.0,
    );
  }

  /// Update context after a successful add.
  void setLastProduct(Product product) {
    _lastProduct = product;
  }

  void clearContext() {
    _lastProduct = null;
  }

  // --- Private parsing methods ---

  ParseResult? _parseCheckout(String lower, String raw) {
    if (!_matchesAny(lower, _checkoutKeywords)) return null;

    // Detect payment method
    String? payment;
    for (final entry in _paymentKeywords.entries) {
      if (lower.contains(entry.key)) {
        payment = entry.value;
        break;
      }
    }

    return ParseResult(
      intent: BaristaIntent.checkout,
      rawText: raw,
      confidence: 0.95,
      paymentMethod: payment,
    );
  }

  ParseResult? _parseRemove(String lower, String raw, List<Product>? products) {
    if (!_matchesAny(lower, _removeKeywords)) return null;

    final cleaned = _stripKeywords(lower, _removeKeywords);
    final product = _findProduct(cleaned, products);

    return ParseResult(
      intent: BaristaIntent.removeItem,
      product: product,
      rawText: raw,
      confidence: product != null ? 0.9 : 0.7,
    );
  }

  ParseResult? _parseAddItem(String lower, String raw, List<Product>? products) {
    if (!_matchesAny(lower, _addKeywords)) return null;

    final qty = _extractQuantity(lower);
    final cleaned = _stripForProductSearch(lower, _addKeywords);
    final product = _findProduct(cleaned, products);

    if (product != null) {
      _lastProduct = product;
      return ParseResult(
        intent: BaristaIntent.addItem,
        product: product,
        quantity: qty,
        rawText: raw,
        confidence: 0.9,
      );
    }

    return null;
  }

  ParseResult? _parseDirectProduct(String lower, String raw, List<Product>? products) {
    final qty = _extractQuantity(lower);
    final cleaned = _stripQuantityAndModifiers(lower);
    final product = _findProduct(cleaned, products);

    if (product != null) {
      _lastProduct = product;
      return ParseResult(
        intent: BaristaIntent.addItem,
        product: product,
        quantity: qty,
        rawText: raw,
        confidence: 0.8,
      );
    }

    return null;
  }

  // --- Utility methods ---

  /// Check if text matches any keyword in the list.
  bool _matchesAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  /// Extract quantity from text (numbers or word-numbers).
  int _extractQuantity(String text) {
    // Check digit numbers first
    final digitMatch = RegExp(r'(\d+)').firstMatch(text);
    if (digitMatch != null) {
      final n = int.tryParse(digitMatch.group(1)!);
      if (n != null && n > 0 && n <= 100) return n;
    }

    // Check word numbers
    final words = text.split(RegExp(r'\s+'));
    for (final word in words) {
      if (_wordNumbers.containsKey(word)) {
        return _wordNumbers[word]!;
      }
    }

    return 1;
  }

  /// Strip command keywords and extract product query.
  String _stripKeywords(String text, List<String> keywords) {
    var result = text;
    for (final kw in keywords) {
      result = result.replaceAll(kw, '');
    }
    return _cleanQuery(result);
  }

  /// Strip keywords, quantities, and modifiers for product search.
  String _stripForProductSearch(String text, List<String> keywords) {
    var result = text;

    // Strip command keywords
    for (final kw in keywords) {
      result = result.replaceAll(kw, '');
    }

    return _stripQuantityAndModifiers(result);
  }

  /// Strip quantity words/numbers and modifier words.
  String _stripQuantityAndModifiers(String text) {
    var result = text;

    // Strip digit numbers
    result = result.replaceAll(RegExp(r'\d+'), '');

    // Strip word numbers
    for (final wn in _wordNumbers.keys) {
      result = result.replaceAll(RegExp('\\b$wn\\b'), '');
    }

    // Strip modifiers and fillers
    for (final mod in [..._modifiers, ..._fillerWords]) {
      result = result.replaceAll(RegExp('\\b$mod\\b'), '');
    }

    return _cleanQuery(result);
  }

  /// Clean up extra whitespace.
  String _cleanQuery(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Find a product by name, alias, or fuzzy match.
  Product? _findProduct(String query, List<Product>? products) {
    if (query.isEmpty) return null;

    final catalog = products ?? Product.sampleProducts;
    final lowerQuery = query.toLowerCase().trim();

    // Pass 1: Exact name or alias match
    for (final p in catalog) {
      if (p.name.toLowerCase() == lowerQuery) return p;
      for (final alias in p.aliases) {
        if (alias.toLowerCase() == lowerQuery) return p;
      }
    }

    // Pass 2: Contains match
    for (final p in catalog) {
      if (p.name.toLowerCase().contains(lowerQuery) ||
          lowerQuery.contains(p.name.toLowerCase())) return p;
      for (final alias in p.aliases) {
        if (alias.toLowerCase().contains(lowerQuery) ||
            lowerQuery.contains(alias.toLowerCase())) return p;
      }
    }

    // Pass 3: Fuzzy match (Levenshtein-like)
    Product? bestMatch;
    double bestScore = 0;

    for (final p in catalog) {
      final nameScore = _similarity(lowerQuery, p.name.toLowerCase());
      if (nameScore > bestScore) {
        bestScore = nameScore;
        bestMatch = p;
      }
      for (final alias in p.aliases) {
        final aliasScore = _similarity(lowerQuery, alias.toLowerCase());
        if (aliasScore > bestScore) {
          bestScore = aliasScore;
          bestMatch = p;
        }
      }
    }

    // Only return if similarity is reasonable (0.5 = more forgiving for STT errors)
    if (bestScore >= 0.5) return bestMatch;

    // Pass 4: Check if any word in query matches a product
    final words = lowerQuery.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length < 3) continue;
      for (final p in catalog) {
        if (p.name.toLowerCase().contains(word)) return p;
        for (final alias in p.aliases) {
          if (alias.toLowerCase().contains(word)) return p;
        }
      }
    }

    return null;
  }

  /// Simple similarity score (0.0 to 1.0) based on common characters.
  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final longer = a.length >= b.length ? a : b;
    final shorter = a.length < b.length ? a : b;

    final longerLength = longer.length;
    if (longerLength == 0) return 1.0;

    final distance = _editDistance(longer, shorter);
    return (longerLength - distance) / longerLength;
  }

  /// Levenshtein edit distance.
  int _editDistance(String a, String b) {
    final la = a.length;
    final lb = b.length;

    List<int> prev = List.generate(lb + 1, (i) => i);
    List<int> curr = List.filled(lb + 1, 0);

    for (int i = 1; i <= la; i++) {
      curr[0] = i;
      for (int j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,       // deletion
          curr[j - 1] + 1,   // insertion
          prev[j - 1] + cost, // substitution
        ].reduce(min);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[lb];
  }
}
