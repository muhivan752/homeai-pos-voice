class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final List<String> aliases;
  final String? barcode;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.aliases = const [],
    this.barcode,
  });

  // Sample products for demo
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
