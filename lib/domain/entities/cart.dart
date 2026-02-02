/// Domain entities untuk Cart.
/// Value objects yang merepresentasikan data di cart.

/// Product dalam katalog.
class Product {
  final String name;
  final String code;
  final double price;
  final int stock;
  final String? category;
  final String? imageUrl;

  Product({
    required this.name,
    required this.code,
    required this.price,
    required this.stock,
    this.category,
    this.imageUrl,
  });

  bool get isAvailable => stock > 0;

  @override
  bool operator ==(Object other) =>
      other is Product && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'Product($name, Rp$price, stock: $stock)';
}

/// Item dalam cart dengan detail harga dan qty.
class CartItem {
  final String item;
  final String itemCode;
  final int qty;
  final double rate;
  final double amount;

  CartItem({
    required this.item,
    required this.itemCode,
    required this.qty,
    required this.rate,
    required this.amount,
  });

  @override
  bool operator ==(Object other) =>
      other is CartItem &&
      other.itemCode == itemCode &&
      other.qty == qty &&
      other.rate == rate;

  @override
  int get hashCode => Object.hash(itemCode, qty, rate);

  @override
  String toString() => 'CartItem($item x$qty @ $rate)';
}

/// Summary total dari cart.
class CartTotal {
  final double total;
  final double discount;
  final double grandTotal;
  final int itemCount;

  CartTotal({
    required this.total,
    required this.discount,
    required this.grandTotal,
    required this.itemCount,
  });

  bool get isEmpty => itemCount == 0;

  @override
  String toString() => 'CartTotal($itemCount items, grand: $grandTotal)';
}
