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
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Products table - cached from ERPNext
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        item_code TEXT NOT NULL,
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

    // Transactions table - local sales
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        total REAL NOT NULL,
        payment_method TEXT DEFAULT 'Cash',
        customer_name TEXT,
        status TEXT DEFAULT 'completed',
        erp_invoice_id TEXT,
        sync_status TEXT DEFAULT 'pending',
        sync_error TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced_at TEXT
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

    // Create indexes
    await db.execute('CREATE INDEX idx_transactions_sync ON transactions(sync_status)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
    await db.execute('CREATE INDEX idx_products_active ON products(is_active)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
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

  Future<int> clearProducts() async {
    final db = await database;
    return await db.delete('products');
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

  // ============ CLEANUP ============

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
