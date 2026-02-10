/// A remembered customer — the heart of "POS yang kenal pelanggan".
class Customer {
  final String id;
  final String name;
  final String? phone;
  int visitCount;
  DateTime? lastVisitAt;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.visitCount = 0,
    this.lastVisitAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from database row.
  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      visitCount: (map['visit_count'] as int?) ?? 0,
      lastVisitAt: map['last_visit_at'] != null
          ? DateTime.tryParse(map['last_visit_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Convert to database row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'visit_count': visitCount,
      'last_visit_at': lastVisitAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// A customer's favorite / "yang biasa" item.
class FavoriteItem {
  final String productId;
  final String productName;
  final int orderCount;
  final int totalQuantity;

  const FavoriteItem({
    required this.productId,
    required this.productName,
    required this.orderCount,
    required this.totalQuantity,
  });
}
