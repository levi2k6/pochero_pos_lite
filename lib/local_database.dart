import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'payment_items_table.dart';
import 'payments_table.dart';
import 'product_recipes_table.dart';
import 'products_table.dart';

/// Local sqflite database: the device's store for recorded payments.
///
/// Android/iOS use the sqflite plugin; desktop uses the FFI factory installed
/// in `main.dart`. The file lives in the platform's app-data directory — never
/// the project directory — so it survives rebuilds, `flutter clean`, and test
/// runs.
class LocalDatabase {
  LocalDatabase._();

  /// App-wide instance.
  static final LocalDatabase instance = LocalDatabase._();

  static const _fileName = 'pochero_pos_lite.db';
  static const _version = 4;

  Database? _database;

  /// Opens (and creates on first run) the database, reusing the same
  /// connection on later calls.
  Future<Database> open() async {
    final open = _database;
    if (open != null) return open;

    final path = await _resolvePath();
    final database = await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _database = database;
    return database;
  }

  /// Closes the connection. Mainly for tests and teardown.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Closes and deletes the database file. Used by tests for a clean slate.
  Future<void> delete() async {
    final path = await _resolvePath();
    await close();
    await databaseFactory.deleteDatabase(path);
  }

  /// The DB lives in the platform app-data directory so it is stable across
  /// runs. Tests point path_provider at a temp directory.
  Future<String> _resolvePath() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return p.join(directory.path, _fileName);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(PaymentsTable.createSql);
    await db.execute(PaymentItemsTable.createSql);
    await db.execute(PaymentItemsTable.createPaymentIndexSql);
    await _createProductTables(db);
  }

  /// Adds the product tables (v2), drops the recipe quantity column (v3), and
  /// adds the payment `dirty` column (v4).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createProductTables(db);
    }
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS ${ProductRecipesTable.name}');
      await db.execute(ProductRecipesTable.createSql);
      await db.execute(ProductRecipesTable.createProductIndexSql);
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE ${PaymentsTable.name} '
        'ADD COLUMN ${PaymentsTable.dirty} INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  Future<void> _createProductTables(Database db) async {
    await db.execute(ProductsTable.createSql);
    await db.execute(ProductRecipesTable.createSql);
    await db.execute(ProductRecipesTable.createProductIndexSql);
  }
}
