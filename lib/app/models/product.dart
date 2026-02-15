class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final List<String> aliases;
  final String? barcode;
  final int stock; // -1 = unlimited (not tracked), >= 0 = tracked

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.aliases = const [],
    this.barcode,
    this.stock = -1,
  });

  /// Whether stock is being tracked for this product.
  bool get isStockTracked => stock >= 0;

  /// Whether this product is out of stock.
  bool get isOutOfStock => isStockTracked && stock <= 0;

  /// Whether this product has low stock (1-5 remaining).
  bool get isLowStock => isStockTracked && stock > 0 && stock <= 5;

  /// Create Product from SQLite map.
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? map['item_code'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      category: map['category'] ?? 'other',
      aliases: (map['aliases'] as String?)?.split(',').where((a) => a.trim().isNotEmpty).toList() ?? [],
      barcode: map['barcode'],
      stock: (map['stock'] as int?) ?? -1,
    );
  }

  /// Convert to SQLite map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_code': id,
      'name': name,
      'price': price,
      'category': category,
      'aliases': aliases.join(','),
      'barcode': barcode,
      'stock': stock,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Copy with modified fields.
  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? category,
    List<String>? aliases,
    String? barcode,
    int? stock,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      aliases: aliases ?? this.aliases,
      barcode: barcode ?? this.barcode,
      stock: stock ?? this.stock,
    );
  }

  // Default products — used as seed data for first launch.
  // After seeding, this list gets updated from SQLite.
  static List<Product> sampleProducts = [
    const Product(
      id: 'kopi-susu',
      name: 'Kopi Susu',
      price: 18000,
      category: 'drink',
      aliases: ['kopi susu', 'kosu', 'kop sus', 'coffee susu', 'coffee milk', 'kopi milk', 'cofi susu'],
      barcode: '8991234567001',
    ),
    const Product(
      id: 'es-teh',
      name: 'Es Teh',
      price: 8000,
      category: 'drink',
      aliases: ['es teh', 'esteh', 'teh es', 'ice tea', 'iced tea', 'ice teh', 'es tea'],
      barcode: '8991234567002',
    ),
    const Product(
      id: 'americano',
      name: 'Americano',
      price: 22000,
      category: 'drink',
      aliases: ['americano', 'amerika', 'kopi amerika', 'americanos', 'amerikano', 'american', 'amerikan'],
      barcode: '8991234567003',
    ),
    const Product(
      id: 'latte',
      name: 'Cafe Latte',
      price: 25000,
      category: 'drink',
      aliases: ['latte', 'late', 'kopi latte', 'cafe latte', 'cafelatte', 'kafe latte', 'lte', 'latter', 'lattes'],
      barcode: '8991234567004',
    ),
    const Product(
      id: 'cappuccino',
      name: 'Cappuccino',
      price: 25000,
      category: 'drink',
      aliases: ['cappuccino', 'kapucino', 'capucino', 'cappucino', 'capuchino', 'cappuccinos', 'kapuchino', 'kappucino'],
      barcode: '8991234567005',
    ),
    const Product(
      id: 'roti-bakar',
      name: 'Roti Bakar',
      price: 15000,
      category: 'food',
      aliases: ['roti bakar', 'rotibakar', 'robar', 'toast', 'roti', 'bread toast'],
      barcode: '8991234567006',
    ),
    const Product(
      id: 'kentang-goreng',
      name: 'Kentang Goreng',
      price: 20000,
      category: 'food',
      aliases: ['kentang goreng', 'kentang', 'french fries', 'fries', 'potato fries', 'fried potato'],
      barcode: '8991234567007',
    ),
    const Product(
      id: 'nasi-goreng',
      name: 'Nasi Goreng',
      price: 25000,
      category: 'food',
      aliases: ['nasi goreng', 'nasgor', 'nasigoreng', 'fried rice', 'nasi greng', 'nasigreng'],
      barcode: '8991234567008',
    ),
    const Product(
      id: 'keripik',
      name: 'Keripik Kentang',
      price: 12000,
      category: 'snack',
      aliases: ['keripik', 'chips', 'potato chips'],
      barcode: '8991234567009',
    ),
    const Product(
      id: 'coklat',
      name: 'Coklat Bar',
      price: 15000,
      category: 'snack',
      aliases: ['coklat', 'chocolate', 'cokelat', 'choco', 'chocolates', 'coklat bar'],
      barcode: '8991234567010',
    ),
  ];

  static Product? findByNameOrAlias(String query) {
    final lowerQuery = query.toLowerCase().trim();

    for (final product in sampleProducts) {
      if (product.name.toLowerCase() == lowerQuery) {
        return product;
      }
      for (final alias in product.aliases) {
        if (alias.toLowerCase() == lowerQuery) {
          return product;
        }
      }
    }

    // Fuzzy match
    for (final product in sampleProducts) {
      if (product.name.toLowerCase().contains(lowerQuery) ||
          lowerQuery.contains(product.name.toLowerCase())) {
        return product;
      }
      for (final alias in product.aliases) {
        if (alias.toLowerCase().contains(lowerQuery) ||
            lowerQuery.contains(alias.toLowerCase())) {
          return product;
        }
      }
    }

    return null;
  }
}
