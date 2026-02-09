import 'dart:math';
import 'barista_parser.dart';
import '../models/product.dart';

/// Generates fun, natural barista-style responses in Indonesian.
///
/// Designed to feel like chatting with a friendly barista,
/// not a robot. Responses are randomized for variety.
class BaristaResponse {
  final _random = Random();

  /// Format currency without decimal
  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  /// Pick a random item from a list.
  String _pick(List<String> options) {
    return options[_random.nextInt(options.length)];
  }

  /// Generate a response based on the parse result and cart state.
  String respond({
    required ParseResult result,
    required int cartItemCount,
    required double cartTotal,
    bool isFirstItem = false,
  }) {
    switch (result.intent) {
      case BaristaIntent.addItem:
        return _addItemResponse(result, cartItemCount, cartTotal);
      case BaristaIntent.removeItem:
        return _removeItemResponse(result, cartItemCount);
      case BaristaIntent.checkout:
        return _checkoutResponse(result, cartItemCount, cartTotal);
      case BaristaIntent.clearCart:
        return _clearCartResponse(cartItemCount);
      case BaristaIntent.greeting:
        return _greetingResponse();
      case BaristaIntent.thanks:
        return _thanksResponse();
      case BaristaIntent.askMenu:
        return _menuResponse();
      case BaristaIntent.unknown:
        return _unknownResponse(result.rawText);
    }
  }

  /// Response when item is added to cart
  String _addItemResponse(ParseResult result, int cartCount, double cartTotal) {
    final product = result.product;
    if (product == null) return _productNotFoundResponse(result.rawText);

    final name = product.name;
    final qty = result.quantity;
    final qtyStr = qty > 1 ? ' $qty' : '';

    // First item in cart
    if (cartCount == 0) {
      return _pick([
        'Siap,$qtyStr $name masuk! Ada lagi?',
        'Oke$qtyStr $name ya! Mau tambah apa lagi?',
        '$name$qtyStr, noted! Ada yang lain?',
        'Sipp,$qtyStr $name! Mau sekalian yang lain?',
      ]);
    }

    // Subsequent items
    final total = _formatCurrency(cartTotal);
    return _pick([
      'Plus$qtyStr $name ya! Totalnya Rp $total. Lanjut?',
      'Oke$qtyStr $name ditambah! Sejauh ini Rp $total. Ada lagi?',
      '$name$qtyStr masuk! Running total Rp $total. Yang lain?',
      'Siap,$qtyStr $name! Total sementara Rp $total. Apa lagi?',
    ]);
  }

  /// Response when item is removed
  String _removeItemResponse(ParseResult result, int cartCount) {
    final product = result.product;

    if (product == null) {
      if (cartCount == 0) {
        return _pick([
          'Keranjangnya udah kosong kok!',
          'Gak ada yang perlu dihapus, kosong nih.',
        ]);
      }
      return _pick([
        'Yang mana nih yang dibatalin?',
        'Hmm, yang mau dihapus yang mana ya?',
      ]);
    }

    return _pick([
      'Oke ${product.name} dibatalin ya!',
      '${product.name} dihapus! Ada yang mau diganti?',
      'Siap, ${product.name} dicoret!',
    ]);
  }

  /// Response for checkout
  String _checkoutResponse(ParseResult result, int cartCount, double cartTotal) {
    if (cartCount == 0) {
      return _pick([
        'Eh, keranjangnya masih kosong nih. Mau pesan apa dulu?',
        'Belum ada pesanan nih. Mau order apa?',
        'Kosong nih! Pesan dulu yuk.',
      ]);
    }

    final total = _formatCurrency(cartTotal);
    final payment = result.paymentMethod;

    if (payment != null) {
      return _pick([
        'Oke totalnya Rp $total, bayar pake $payment ya! Siap!',
        'Total Rp $total, $payment ya. Ditunggu!',
        'Rp $total pake $payment, noted! Makasih ya!',
      ]);
    }

    return _pick([
      'Totalnya Rp $total ya! Mau bayar pake apa?',
      'Oke, total Rp $total. Cash, QRIS, atau transfer?',
      'Siap! Totalnya Rp $total. Bayarnya gimana nih?',
    ]);
  }

  /// Response for clearing cart
  String _clearCartResponse(int cartCount) {
    if (cartCount == 0) {
      return _pick([
        'Udah kosong kok! Mau pesan apa?',
        'Keranjangnya emang kosong. Mulai pesan yuk!',
      ]);
    }

    return _pick([
      'Oke semua dihapus! Mulai dari awal ya.',
      'Bersih! Mau pesan apa dari awal?',
      'Cart dikosongkan. Yuk pesan lagi!',
    ]);
  }

  /// Response for greetings
  String _greetingResponse() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 11) {
      greeting = 'Pagi';
    } else if (hour < 15) {
      greeting = 'Siang';
    } else if (hour < 18) {
      greeting = 'Sore';
    } else {
      greeting = 'Malam';
    }

    return _pick([
      'Hai! Selamat $greeting! Mau pesan apa hari ini?',
      'Halo! Selamat $greeting! Ada yang bisa dibantu?',
      'Selamat $greeting! Yuk, mau ngopi apa nih?',
      'Hai! Welcome! Mau pesan apa?',
    ]);
  }

  /// Response for thanks
  String _thanksResponse() {
    return _pick([
      'Sama-sama! Dateng lagi ya!',
      'Makasih juga! Semoga harinya menyenangkan!',
      'Siap! Ditunggu next order-nya ya!',
      'Thank you! See you next time!',
    ]);
  }

  /// Response for menu inquiry
  String _menuResponse() {
    return _pick([
      'Kita punya kopi, teh, makanan, dan snack! Mau coba yang mana?',
      'Ada Kopi Susu, Americano, Latte, Cappuccino, Es Teh, Roti Bakar, dan lainnya! Mau apa?',
      'Menu favorit: Kopi Susu 18rb, Latte 25rb, Americano 22rb. Mau yang mana?',
    ]);
  }

  /// Response when product is not found
  String _productNotFoundResponse(String rawText) {
    return _pick([
      'Hmm, gak nemu yang itu nih. Coba sebut lagi?',
      'Wah, yang mana ya? Coba ulangi dong.',
      'Maaf, gak ketemu. Bisa sebut nama produknya lagi?',
    ]);
  }

  /// Response for unrecognized commands
  String _unknownResponse(String rawText) {
    return _pick([
      'Hmm, gak nangkep nih. Coba bilang lagi ya?',
      'Maaf, bisa diulang? Misal "kopi susu 2" atau "bayar".',
      'Gak kedengeran jelas nih. Coba lagi ya!',
      'Apa tadi? Coba sebut nama minuman atau "bayar" ya.',
    ]);
  }
}
