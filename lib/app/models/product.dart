class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final List<String> aliases;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.aliases = const [],
  });

  // Sample products for demo
  static List<Product> sampleProducts = [
    const Product(
      id: 'kopi-susu',
      name: 'Kopi Susu',
      price: 18000,
      category: 'Minuman',
      aliases: ['kopi susu', 'kosu', 'kop sus'],
    ),
    const Product(
      id: 'es-teh',
      name: 'Es Teh',
      price: 8000,
      category: 'Minuman',
      aliases: ['es teh', 'esteh', 'teh es'],
    ),
    const Product(
      id: 'americano',
      name: 'Americano',
      price: 22000,
      category: 'Minuman',
      aliases: ['americano', 'amerika', 'kopi amerika'],
    ),
    const Product(
      id: 'latte',
      name: 'Cafe Latte',
      price: 25000,
      category: 'Minuman',
      aliases: ['latte', 'late', 'kopi latte'],
    ),
    const Product(
      id: 'cappuccino',
      name: 'Cappuccino',
      price: 25000,
      category: 'Minuman',
      aliases: ['cappuccino', 'kapucino', 'capucino'],
    ),
    const Product(
      id: 'roti-bakar',
      name: 'Roti Bakar',
      price: 15000,
      category: 'Makanan',
      aliases: ['roti bakar', 'rotibakar', 'robar'],
    ),
    const Product(
      id: 'kentang-goreng',
      name: 'Kentang Goreng',
      price: 20000,
      category: 'Makanan',
      aliases: ['kentang goreng', 'kentang', 'french fries'],
    ),
    const Product(
      id: 'nasi-goreng',
      name: 'Nasi Goreng',
      price: 25000,
      category: 'Makanan',
      aliases: ['nasi goreng', 'nasgor', 'nasigoreng'],
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
