import 'package:flutter/foundation.dart';
import '../models/product.dart';

/// Post-processor for Speech-to-Text output.
///
/// Google STT often mis-recognizes Indonesian as English or
/// concatenates words together. This corrector fixes common
/// errors BEFORE the text reaches the parser.
///
/// Examples:
///   "coffee susudua"  → "kopi susu dua"
///   "americanos Auto" → "americano"
///   "latteTiga"       → "latte tiga"
///   "ice tea"         → "es teh"
class SttCorrector {
  /// English → Indonesian word map for common menu/food terms.
  /// These are words Google STT wrongly "translates" from Indonesian.
  static const Map<String, String> _englishToIndo = {
    // Beverages
    'coffee': 'kopi',
    'coffe': 'kopi',
    'koffie': 'kopi',
    'coffees': 'kopi',
    'tea': 'teh',
    'teas': 'teh',
    'milk': 'susu',
    'milks': 'susu',
    'ice': 'es',
    'iced': 'es',
    'chocolate': 'coklat',
    'chocolates': 'coklat',
    'choco': 'coklat',
    'water': 'air',
    'juice': 'jus',

    // Food
    'rice': 'nasi',
    'bread': 'roti',
    'toast': 'roti bakar',
    'fried': 'goreng',
    'potato': 'kentang',
    'potatoes': 'kentang',
    'fries': 'kentang goreng',
    'chips': 'keripik',
    'chip': 'keripik',
    'noodle': 'mie',
    'noodles': 'mie',
    'egg': 'telur',
    'eggs': 'telur',
    'chicken': 'ayam',
    'sugar': 'gula',

    // Common STT garble
    'auto': '',
    'otto': '',
    'autor': '',
    'also': '',
    'order': 'pesan',
    'pay': 'bayar',
    'paid': 'bayar',
    'cancel': 'batal',
    'check': 'cek',
    'stock': 'stok',
    'menu': 'menu',
    'hello': 'halo',
    'thanks': 'makasih',
    'thank': 'makasih',
    'please': 'tolong',
    'want': 'mau',
    'add': 'tambah',
    'more': 'lagi',
    'again': 'lagi',
    'done': 'selesai',
    'finish': 'selesai',
    'enough': 'cukup',
    'total': 'total',
  };

  /// Base command/number vocabulary (always present).
  static const List<String> _baseKnownWords = [
    // Numbers
    'satu', 'dua', 'tiga', 'empat', 'lima',
    'enam', 'tujuh', 'delapan', 'sembilan', 'sepuluh',
    // Commands
    'jual', 'tambah', 'pesan', 'pesen', 'mau', 'minta',
    'bayar', 'batal', 'hapus', 'cek', 'stok',
    'checkout', 'cancel', 'total', 'selesai',
    'lagi', 'sama', 'yang', 'es',
  ];

  /// Build dynamic known words from base vocabulary + product catalog.
  List<String> get _knownWords {
    final words = <String>{..._baseKnownWords};
    for (final p in Product.sampleProducts) {
      // Add each word from product name
      for (final w in p.name.toLowerCase().split(' ')) {
        if (w.length >= 2) words.add(w);
      }
      // Add aliases
      for (final alias in p.aliases) {
        for (final w in alias.toLowerCase().split(' ')) {
          if (w.length >= 2) words.add(w);
        }
      }
    }
    return words.toList();
  }

  /// Phonetic corrections for common misheard words.
  static const Map<String, String> _phoneticFixes = {
    // Common STT butchering of Indonesian words
    'kopi susu': 'kopi susu',
    'copy susu': 'kopi susu',
    'coffee susu': 'kopi susu',
    'copy': 'kopi',
    'coppy': 'kopi',
    'kopy': 'kopi',
    'kopie': 'kopi',
    'susuh': 'susu',
    'americanos': 'americano',
    'americanas': 'americano',
    'americaner': 'americano',
    'amerika': 'americano',
    'amerikan': 'americano',
    'cappuccinos': 'cappuccino',
    'capuchino': 'cappuccino',
    'kapucino': 'cappuccino',
    'kapuchino': 'cappuccino',
    'cafelete': 'cafe latte',
    'kafelatte': 'cafe latte',
    'café': 'cafe',
    'lattes': 'latte',
    'latter': 'latte',
    'letteh': 'latte',
    'esteh': 'es teh',
    'essteh': 'es teh',
    'nasgor': 'nasi goreng',
    'nasigoreng': 'nasi goreng',
    'rotibakar': 'roti bakar',
    'kosu': 'kopi susu',

    // Common garble patterns from screenshot
    'casteñas': '',
    'castenas': '',
  };

  /// Correct STT output text. This runs BEFORE the parser.
  String correct(String raw) {
    if (raw.trim().isEmpty) return '';

    var text = raw.trim();
    debugPrint('[STT Corrector] Input: "$text"');

    // Step 1: Normalize — lowercase, strip extra spaces, remove special chars
    text = _normalize(text);
    debugPrint('[STT Corrector] After normalize: "$text"');

    // Step 2: Apply phonetic corrections (multi-word phrases first)
    text = _applyPhoneticFixes(text);
    debugPrint('[STT Corrector] After phonetic: "$text"');

    // Step 3: Try splitting concatenated words
    text = _splitConcatenated(text);
    debugPrint('[STT Corrector] After split: "$text"');

    // Step 4: Translate English words to Indonesian
    text = _translateEnglish(text);
    debugPrint('[STT Corrector] After translate: "$text"');

    // Step 5: Strip English plural 's' on known words
    text = _stripPlurals(text);
    debugPrint('[STT Corrector] After plurals: "$text"');

    // Step 6: Remove empty/noise tokens, clean up
    text = _cleanUp(text);
    debugPrint('[STT Corrector] Final: "$text"');

    return text;
  }

  /// Normalize text: lowercase, strip accents, clean punctuation.
  String _normalize(String text) {
    text = text.toLowerCase().trim();

    // Remove common accented characters (STT artifacts)
    text = text
        .replaceAll('ñ', 'n')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ä', 'a');

    // Remove punctuation except apostrophes
    text = text.replaceAll(RegExp(r"[^\w\s']"), ' ');

    // Collapse multiple spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Apply known phonetic corrections (longest match first).
  String _applyPhoneticFixes(String text) {
    // Sort by key length descending to match longer phrases first
    final sortedKeys = _phoneticFixes.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final key in sortedKeys) {
      if (text.contains(key)) {
        text = text.replaceAll(key, _phoneticFixes[key]!);
      }
    }

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Try to split concatenated words into separate known words.
  /// E.g., "susudua" → "susu dua", "lattetiga" → "latte tiga"
  String _splitConcatenated(String text) {
    final words = text.split(RegExp(r'\s+'));
    final result = <String>[];

    for (final word in words) {
      // Skip if already a known word or short
      if (word.length <= 3 || _isKnown(word)) {
        result.add(word);
        continue;
      }

      // Skip if it's a digit
      if (RegExp(r'^\d+$').hasMatch(word)) {
        result.add(word);
        continue;
      }

      // Try to split into two known words
      final split = _trySplit(word);
      if (split != null) {
        result.addAll(split);
      } else {
        result.add(word);
      }
    }

    return result.join(' ');
  }

  /// Try splitting a word into two or more known words.
  List<String>? _trySplit(String word) {
    // Try every split point
    for (int i = 2; i < word.length - 1; i++) {
      final left = word.substring(0, i);
      final right = word.substring(i);

      if (_isKnown(left) && _isKnown(right)) {
        return [left, right];
      }

      // Try 3-way split for longer words
      if (right.length > 3) {
        for (int j = 2; j < right.length - 1; j++) {
          final mid = right.substring(0, j);
          final last = right.substring(j);

          if (_isKnown(left) && _isKnown(mid) && _isKnown(last)) {
            return [left, mid, last];
          }
        }
      }

      // If left is known, try fuzzy match on right
      if (_isKnown(left) && _fuzzyKnown(right)) {
        final corrected = _closestKnown(right);
        if (corrected != null) {
          return [left, corrected];
        }
      }
    }

    // Also try if the whole word is a fuzzy match for a known word
    return null;
  }

  /// Check if a word is in our known vocabulary.
  bool _isKnown(String word) {
    return _knownWords.contains(word) ||
        _englishToIndo.containsKey(word) ||
        _wordNumbers.containsKey(word) ||
        RegExp(r'^\d+$').hasMatch(word);
  }

  /// Check if a word fuzzy-matches a known word.
  bool _fuzzyKnown(String word) {
    if (word.length < 3) return false;
    for (final known in _knownWords) {
      if (_similarity(word, known) >= 0.7) return true;
    }
    return false;
  }

  /// Find the closest known word.
  String? _closestKnown(String word) {
    String? best;
    double bestScore = 0;

    for (final known in _knownWords) {
      final score = _similarity(word, known);
      if (score > bestScore && score >= 0.7) {
        bestScore = score;
        best = known;
      }
    }

    return best;
  }

  /// Translate English words to Indonesian equivalents.
  String _translateEnglish(String text) {
    final words = text.split(RegExp(r'\s+'));
    final result = <String>[];

    for (final word in words) {
      if (_englishToIndo.containsKey(word)) {
        final replacement = _englishToIndo[word]!;
        if (replacement.isNotEmpty) {
          result.add(replacement);
        }
        // If replacement is empty, the word is noise — skip it
      } else {
        result.add(word);
      }
    }

    return result.join(' ');
  }

  /// Strip English plural 's' if the stem is a known word.
  String _stripPlurals(String text) {
    final words = text.split(RegExp(r'\s+'));
    final result = <String>[];

    for (final word in words) {
      if (word.endsWith('s') && word.length > 3) {
        final stem = word.substring(0, word.length - 1);
        if (_isKnown(stem)) {
          result.add(stem);
          continue;
        }
      }
      result.add(word);
    }

    return result.join(' ');
  }

  /// Final cleanup: remove empty tokens, collapse spaces.
  String _cleanUp(String text) {
    final words = text.split(RegExp(r'\s+'));
    final filtered = words.where((w) => w.isNotEmpty).toList();
    return filtered.join(' ').trim();
  }

  /// Simple similarity score (0.0 to 1.0).
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
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[lb];
  }

  /// Number words (for known-word detection)
  static const Map<String, int> _wordNumbers = {
    'satu': 1, 'dua': 2, 'tiga': 3, 'empat': 4, 'lima': 5,
    'enam': 6, 'tujuh': 7, 'delapan': 8, 'sembilan': 9, 'sepuluh': 10,
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
  };
}
