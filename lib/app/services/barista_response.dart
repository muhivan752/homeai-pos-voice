import 'dart:math';
import 'barista_parser.dart';
import '../models/product.dart';
import '../models/customer.dart';

/// Generates fun, natural barista-style responses in Indonesian.
///
/// Designed to feel like chatting with a friendly barista,
/// not a robot. Responses are randomized for variety.
/// Now with customer awareness — personalized greetings and
/// "yang biasa" recognition.
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
    Customer? activeCustomer,
    FavoriteItem? yangBiasa,
  }) {
    switch (result.intent) {
      case BaristaIntent.addItem:
        return _addItemResponse(result, cartItemCount, cartTotal, activeCustomer);
      case BaristaIntent.removeItem:
        return _removeItemResponse(result, cartItemCount);
      case BaristaIntent.checkout:
        return _checkoutResponse(result, cartItemCount, cartTotal, activeCustomer);
      case BaristaIntent.clearCart:
        return _clearCartResponse(cartItemCount);
      case BaristaIntent.greeting:
        return _greetingResponse(activeCustomer, yangBiasa);
      case BaristaIntent.thanks:
        return _thanksResponse(activeCustomer);
      case BaristaIntent.askMenu:
        return _menuResponse();
      case BaristaIntent.identifyCustomer:
        return _identifyCustomerResponse(result, activeCustomer, yangBiasa);
      case BaristaIntent.orderBiasa:
        return _orderBiasaResponse(activeCustomer, yangBiasa);
      case BaristaIntent.checkStock:
        return _checkStockResponse(result);
      case BaristaIntent.unknown:
        return _unknownResponse(result.rawText);
    }
  }

  /// Response when item is added to cart
  String _addItemResponse(ParseResult result, int cartCount, double cartTotal, Customer? customer) {
    final product = result.product;
    if (product == null) return _productNotFoundResponse(result.rawText);

    final name = product.name;
    final qty = result.quantity;
    final qtyStr = qty > 1 ? ' $qty' : '';
    final nameSuffix = customer != null ? ', ${customer.name.split(' ').first}' : '';

    // First item in cart
    if (cartCount == 0) {
      return _pick([
        'Siap,$qtyStr $name masuk! Ada lagi$nameSuffix?',
        'Oke$qtyStr $name ya! Mau tambah apa lagi?',
        '$name$qtyStr, noted! Ada yang lain$nameSuffix?',
        'Sipp,$qtyStr $name! Mau sekalian yang lain?',
      ]);
    }

    // Subsequent items
    final total = _formatCurrency(cartTotal);
    return _pick([
      'Plus$qtyStr $name ya! Totalnya Rp $total. Lanjut$nameSuffix?',
      'Oke$qtyStr $name ditambah! Sejauh ini Rp $total. Ada lagi?',
      '$name$qtyStr masuk! Running total Rp $total. Yang lain$nameSuffix?',
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
  String _checkoutResponse(ParseResult result, int cartCount, double cartTotal, Customer? customer) {
    if (cartCount == 0) {
      return _pick([
        'Eh, keranjangnya masih kosong nih. Mau pesan apa dulu?',
        'Belum ada pesanan nih. Mau order apa?',
        'Kosong nih! Pesan dulu yuk.',
      ]);
    }

    final total = _formatCurrency(cartTotal);
    final payment = result.paymentMethod;
    final thankName = customer != null ? ' ${customer.name.split(' ').first}' : '';

    if (payment != null) {
      return _pick([
        'Oke totalnya Rp $total, bayar pake $payment ya! Makasih$thankName!',
        'Total Rp $total, $payment ya. Ditunggu$thankName!',
        'Rp $total pake $payment, noted! Terima kasih$thankName!',
      ]);
    }

    return _pick([
      'Totalnya Rp $total ya! Mau bayar pake apa$thankName?',
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

  /// Response for greetings — personalized if customer is known.
  String _greetingResponse(Customer? customer, FavoriteItem? biasa) {
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

    // Personalized greeting for known customer
    if (customer != null) {
      final firstName = customer.name.split(' ').first;

      if (biasa != null) {
        return _pick([
          'Hai $firstName! Selamat $greeting! Yang biasa, ${biasa.productName}?',
          'Eh $firstName! $greeting! ${biasa.productName} lagi nih?',
          'Wah $firstName dateng! $greeting! Mau ${biasa.productName} kayak biasa?',
        ]);
      }

      if (customer.visitCount > 0) {
        return _pick([
          'Hai $firstName! Selamat $greeting! Seneng liat lo lagi!',
          'Eh $firstName! $greeting! Mau pesan apa hari ini?',
          'Wah $firstName! Dateng lagi nih! Mau apa kali ini?',
        ]);
      }
    }

    // Generic greeting
    return _pick([
      'Hai! Selamat $greeting! Mau pesan apa hari ini?',
      'Halo! Selamat $greeting! Ada yang bisa dibantu?',
      'Selamat $greeting! Yuk, mau ngopi apa nih?',
      'Hai! Welcome! Mau pesan apa?',
    ]);
  }

  /// Response for thanks — personalized
  String _thanksResponse(Customer? customer) {
    if (customer != null) {
      final firstName = customer.name.split(' ').first;
      return _pick([
        'Sama-sama $firstName! Ditunggu lagi ya!',
        'Makasih juga $firstName! Sampai ketemu lagi!',
        'Siap $firstName! Semoga harinya menyenangkan!',
      ]);
    }

    return _pick([
      'Sama-sama! Dateng lagi ya!',
      'Makasih juga! Semoga harinya menyenangkan!',
      'Siap! Ditunggu next order-nya ya!',
    ]);
  }

  /// Response for menu inquiry — uses current product catalog.
  String _menuResponse() {
    final products = Product.sampleProducts;
    if (products.isEmpty) {
      return 'Belum ada menu nih. Minta owner tambahin dulu ya!';
    }

    // Show top 5 products with prices
    final top = products.take(5).map(
      (p) => '${p.name} ${(p.price / 1000).toStringAsFixed(0)}rb',
    ).join(', ');
    final count = products.length;

    return _pick([
      'Kita punya $count menu! Ada $top, dan lainnya. Mau apa?',
      'Ada $top. Total $count pilihan! Mau yang mana?',
      'Menu kita: $top, dll. Mau coba yang mana?',
    ]);
  }

  /// Response when customer identifies themselves.
  String _identifyCustomerResponse(ParseResult result, Customer? customer, FavoriteItem? biasa) {
    final name = result.customerName ?? '';

    // Returning customer recognized!
    if (customer != null) {
      final firstName = customer.name.split(' ').first;

      if (biasa != null) {
        return _pick([
          'Eh $firstName! Udah lama gak mampir! Yang biasa, ${biasa.productName}?',
          'Halo $firstName! Gw inget lo! ${biasa.productName} lagi?',
          'Wah $firstName balik lagi! Mau ${biasa.productName} kayak biasa?',
        ]);
      }

      return _pick([
        'Halo $firstName! Seneng ketemu lagi! Mau pesan apa hari ini?',
        'Eh $firstName! Welcome back! Mau apa nih?',
        'Wah $firstName! Apa kabar? Mau order apa?',
      ]);
    }

    // New customer — we'll remember them
    return _pick([
      'Hai $name! Salam kenal ya! Gw inget lo mulai sekarang. Mau pesan apa?',
      'Halo $name! Welcome! Gw catat ya, next time tinggal sebut nama aja. Mau apa?',
      'Salam kenal $name! Gw bakal inget pesanan lo. Mau order apa hari ini?',
    ]);
  }

  /// Response when customer says "yang biasa".
  String _orderBiasaResponse(Customer? customer, FavoriteItem? biasa) {
    if (customer == null) {
      return _pick([
        'Hmm, gw belum kenal nih. Coba sebut nama dulu ya!',
        'Yang biasa siapa nih? Sebut nama dulu dong!',
        'Gw belum tau pesanan biasa kamu. Kasih tau nama dulu ya!',
      ]);
    }

    final firstName = customer.name.split(' ').first;

    if (biasa == null) {
      return _pick([
        'Hmm $firstName, gw belum hafal pesanan biasa lo nih. Pesan apa dulu?',
        '$firstName, ini kayaknya baru pertama ya? Mau pesan apa?',
        'Belum ada catatan pesanan biasa buat $firstName. Mau order apa?',
      ]);
    }

    // This response is shown BEFORE the item is added to cart.
    // The actual adding happens in VoiceProvider.
    return _pick([
      'Siap ${biasa.productName} kayak biasa ya $firstName!',
      '${biasa.productName} buat $firstName, coming right up!',
      'Oke $firstName, ${biasa.productName}! Gw udah hafal!',
    ]);
  }

  /// Response for stock check
  String _checkStockResponse(ParseResult result) {
    final product = result.product;
    if (product == null) {
      return _pick([
        'Produk mana yang mau dicek stoknya?',
        'Hmm, gak nemu produknya. Coba sebut nama yang lebih jelas.',
      ]);
    }

    if (!product.isStockTracked) {
      return '${product.name}: stok tidak dilacak (unlimited).';
    }

    if (product.isOutOfStock) {
      return _pick([
        '${product.name} lagi habis nih!',
        'Waduh, ${product.name} stoknya kosong!',
      ]);
    }

    if (product.isLowStock) {
      return _pick([
        '${product.name} tinggal ${product.stock} lagi nih, mau restock?',
        'Stok ${product.name}: ${product.stock} — udah mau habis!',
      ]);
    }

    return 'Stok ${product.name}: ${product.stock} tersedia.';
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
