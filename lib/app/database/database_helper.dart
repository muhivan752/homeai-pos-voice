import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pos_voice.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table - for cashier/staff login
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT DEFAULT 'cashier',
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Products table - cached from ERPNext
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        item_code TEXT NOT NULL,
        barcode TEXT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT,
        aliases TEXT,
        image_url TEXT,
        is_active INTEGER DEFAULT 1,
        synced_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Transactions table - local sales
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        subtotal REAL,
        tax_pb1 REAL DEFAULT 0,
        tax_ppn REAL DEFAULT 0,
        total REAL NOT NULL,
        payment_method TEXT DEFAULT 'cash',
        payment_amount REAL,
        change_amount REAL DEFAULT 0,
        payment_reference TEXT,
        customer_name TEXT,
        customer_id TEXT,
        cashier_id TEXT,
        cashier_name TEXT,
        status TEXT DEFAULT 'completed',
        erp_invoice_id TEXT,
        sync_status TEXT DEFAULT 'pending',
        sync_error TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced_at TEXT,
        FOREIGN KEY (cashier_id) REFERENCES users(id),
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    // Transaction items table
    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id)
      )
    ''');

    // Sync queue table - for failed syncs
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        status TEXT DEFAULT 'pending',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        next_retry_at TEXT
      )
    ''');

    // Customers table — "POS yang kenal pelanggan"
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        visit_count INTEGER DEFAULT 0,
        last_visit_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Settings table — key-value store for app config (tax, etc.)
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_transactions_sync ON transactions(sync_status)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
    await db.execute('CREATE INDEX idx_products_active ON products(is_active)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_products_category ON products(category)');
    await db.execute('CREATE INDEX idx_users_username ON users(username)');
    await db.execute('CREATE INDEX idx_customers_name ON customers(name)');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_transactions_customer ON transactions(customer_id)');

    // Insert default admin user (password: admin123)
    await db.insert('users', {
      'id': 'admin',
      'username': 'admin',
      'password_hash': '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', // admin123
      'name': 'Administrator',
      'role': 'admin',
      'is_active': 1,
    });

    // Insert default categories
    await db.insert('categories', {'id': 'all', 'name': 'Semua', 'icon': 'grid_view', 'sort_order': 0});
    await db.insert('categories', {'id': 'food', 'name': 'Makanan', 'icon': 'restaurant', 'sort_order': 1});
    await db.insert('categories', {'id': 'drink', 'name': 'Minuman', 'icon': 'local_cafe', 'sort_order': 2});
    await db.insert('categories', {'id': 'snack', 'name': 'Snack', 'icon': 'cookie', 'sort_order': 3});
    await db.insert('categories', {'id': 'other', 'name': 'Lainnya', 'icon': 'category', 'sort_order': 4});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add users table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          username TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          name TEXT NOT NULL,
          role TEXT DEFAULT 'cashier',
          is_active INTEGER DEFAULT 1,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Add categories table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon TEXT,
          color TEXT,
          sort_order INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1
        )
      ''');

      // Add new columns to products
      try {
        await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
      } catch (_) {}

      // Add new columns to transactions
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN payment_amount REAL');
        await db.execute('ALTER TABLE transactions ADD COLUMN change_amount REAL DEFAULT 0');
        await db.execute('ALTER TABLE transactions ADD COLUMN payment_reference TEXT');
        await db.execute('ALTER TABLE transactions ADD COLUMN cashier_id TEXT');
        await db.execute('ALTER TABLE transactions ADD COLUMN cashier_name TEXT');
      } catch (_) {}

      // Create new indexes
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)');
      } catch (_) {}

      // Insert default admin user
      try {
        await db.insert('users', {
          'id': 'admin',
          'username': 'admin',
          'password_hash': '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
          'name': 'Administrator',
          'role': 'admin',
          'is_active': 1,
        });
      } catch (_) {}

      // Insert default categories
      try {
        await db.insert('categories', {'id': 'all', 'name': 'Semua', 'icon': 'grid_view', 'sort_order': 0});
        await db.insert('categories', {'id': 'food', 'name': 'Makanan', 'icon': 'restaurant', 'sort_order': 1});
        await db.insert('categories', {'id': 'drink', 'name': 'Minuman', 'icon': 'local_cafe', 'sort_order': 2});
        await db.insert('categories', {'id': 'snack', 'name': 'Snack', 'icon': 'cookie', 'sort_order': 3});
        await db.insert('categories', {'id': 'other', 'name': 'Lainnya', 'icon': 'category', 'sort_order': 4});
      } catch (_) {}
    }

    // Version 3: Fix admin password hash (had wrong hash, fixed again in v4)
    if (oldVersion < 3) {
      await db.update(
        'users',
        {'password_hash': '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9'},
        where: 'username = ?',
        whereArgs: ['admin'],
      );
    }

    // Version 4: Fix admin password hash for users who got wrong hash from v3
    if (oldVersion < 4) {
      await db.update(
        'users',
        {'password_hash': '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9'},
        where: 'username = ?',
        whereArgs: ['admin'],
      );
    }

    // Version 5: Customer memory system — "POS yang kenal pelanggan"
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          visit_count INTEGER DEFAULT 0,
          last_visit_at TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN customer_id TEXT');
      } catch (_) {}

      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_customer ON transactions(customer_id)');
      } catch (_) {}
    }

    // Version 6: Tax system — PB1 + PPN compliance
    if (oldVersion < 6) {
      // Settings table for tax config
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      // Tax columns on transactions
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN subtotal REAL');
        await db.execute('ALTER TABLE transactions ADD COLUMN tax_pb1 REAL DEFAULT 0');
        await db.execute('ALTER TABLE transactions ADD COLUMN tax_ppn REAL DEFAULT 0');
      } catch (_) {}
    }
  }

  // ============ PRODUCTS ============

  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.insert(
      'products',
      product,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertProducts(List<Map<String, dynamic>> products) async {
    final db = await database;
    final batch = db.batch();

    for (final product in products) {
      batch.insert('products', product, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final results = await batch.commit();
    return results.length;
  }

  Future<List<Map<String, dynamic>>> getProducts({bool activeOnly = true}) async {
    final db = await database;

    if (activeOnly) {
      return await db.query('products', where: 'is_active = ?', whereArgs: [1]);
    }
    return await db.query('products');
  }

  Future<Map<String, dynamic>?> getProductById(String id) async {
    final db = await database;
    final results = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> findProductByName(String query) async {
    final db = await database;
    final lowerQuery = query.toLowerCase();

    // Search by name or aliases
    final results = await db.rawQuery('''
      SELECT * FROM products
      WHERE is_active = 1
        AND (LOWER(name) LIKE ? OR LOWER(aliases) LIKE ?)
      LIMIT 1
    ''', ['%$lowerQuery%', '%$lowerQuery%']);

    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateProduct(String id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update('products', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProduct(String id) async {
    final db = await database;
    return await db.update('products', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearProducts() async {
    final db = await database;
    return await db.delete('products');
  }

  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'barcode = ? AND is_active = 1',
      whereArgs: [barcode],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await database;
    final lowerQuery = query.toLowerCase();
    return await db.rawQuery('''
      SELECT * FROM products
      WHERE is_active = 1
        AND (LOWER(name) LIKE ? OR LOWER(aliases) LIKE ? OR barcode LIKE ?)
      ORDER BY name
      LIMIT 20
    ''', ['%$lowerQuery%', '%$lowerQuery%', '%$query%']);
  }

  Future<List<Map<String, dynamic>>> getProductsByCategory(String? category) async {
    final db = await database;
    if (category == null || category == 'all') {
      return await db.query('products', where: 'is_active = 1', orderBy: 'name');
    }
    return await db.query(
      'products',
      where: 'is_active = 1 AND category = ?',
      whereArgs: [category],
      orderBy: 'name',
    );
  }

  // ============ CATEGORIES ============

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories', where: 'is_active = 1', orderBy: 'sort_order');
  }

  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.insert('categories', category, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ============ USERS ============

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    final db = await database;
    final results = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return await db.query('users', where: 'is_active = 1', orderBy: 'name');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<int> updateUser(String id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update('users', updates, where: 'id = ?', whereArgs: [id]);
  }

  // ============ TRANSACTIONS ============

  Future<String> insertTransaction(Map<String, dynamic> transaction, List<Map<String, dynamic>> items) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert('transactions', transaction);

      for (final item in items) {
        await txn.insert('transaction_items', item);
      }
    });

    return transaction['id'];
  }

  Future<List<Map<String, dynamic>>> getTransactions({
    String? syncStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;

    String? where;
    List<dynamic>? whereArgs;

    if (syncStatus != null) {
      where = 'sync_status = ?';
      whereArgs = [syncStatus];
    }

    return await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionItems(String transactionId) async {
    final db = await database;
    return await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<Map<String, dynamic>?> getTransactionById(String id) async {
    final db = await database;
    final results = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateTransactionSyncStatus(
    String id, {
    required String syncStatus,
    String? erpInvoiceId,
    String? syncError,
  }) async {
    final db = await database;

    final updates = <String, dynamic>{
      'sync_status': syncStatus,
    };

    if (erpInvoiceId != null) {
      updates['erp_invoice_id'] = erpInvoiceId;
      updates['synced_at'] = DateTime.now().toIso8601String();
    }

    if (syncError != null) {
      updates['sync_error'] = syncError;
    }

    return await db.update(
      'transactions',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM transactions WHERE sync_status = 'pending'",
    );
    return result.first['count'] as int;
  }

  // ============ SYNC QUEUE ============

  Future<int> addToSyncQueue(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('sync_queue', item);
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems({int limit = 10}) async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: "status = 'pending' AND (next_retry_at IS NULL OR next_retry_at <= ?)",
      whereArgs: [DateTime.now().toIso8601String()],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  Future<int> updateSyncQueueItem(int id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update('sync_queue', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSyncQueueItem(int id) async {
    final db = await database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // ============ STATS ============

  Future<Map<String, dynamic>> getTodayStats() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as transaction_count,
        COALESCE(SUM(total), 0) as total_sales
      FROM transactions
      WHERE DATE(created_at) = ?
    ''', [today]);

    return result.first;
  }

  // ============ CUSTOMERS ============

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    return await db.insert(
      'customers',
      customer,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCustomerById(String id) async {
    final db = await database;
    final results = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Find customer by name (case-insensitive, fuzzy).
  Future<List<Map<String, dynamic>>> findCustomersByName(String name) async {
    final db = await database;
    final lower = name.toLowerCase();
    return await db.rawQuery('''
      SELECT * FROM customers
      WHERE LOWER(name) LIKE ?
      ORDER BY visit_count DESC
      LIMIT 5
    ''', ['%$lower%']);
  }

  /// Find customer by phone number.
  Future<Map<String, dynamic>?> findCustomerByPhone(String phone) async {
    final db = await database;
    final results = await db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [phone],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update customer visit after checkout.
  Future<void> recordCustomerVisit(String customerId) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE customers
      SET visit_count = visit_count + 1,
          last_visit_at = ?
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), customerId]);
  }

  /// Get a customer's most ordered products ("yang biasa").
  Future<List<Map<String, dynamic>>> getCustomerFavorites(
    String customerId, {
    int limit = 3,
  }) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        ti.product_id,
        ti.product_name,
        COUNT(DISTINCT t.id) as order_count,
        SUM(ti.quantity) as total_quantity
      FROM transaction_items ti
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE t.customer_id = ?
      GROUP BY ti.product_id
      ORDER BY order_count DESC, total_quantity DESC
      LIMIT ?
    ''', [customerId, limit]);
  }

  /// Get all customers, ordered by most recent visit.
  Future<List<Map<String, dynamic>>> getCustomers({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'customers',
      orderBy: 'last_visit_at DESC',
      limit: limit,
    );
  }

  // ============ SETTINGS ============

  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return results.isNotEmpty ? results.first['value'] as String : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final results = await db.query('settings');
    return {for (final r in results) r['key'] as String: r['value'] as String};
  }

  // ============ CLEANUP ============

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
