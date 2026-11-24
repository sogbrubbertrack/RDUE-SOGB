import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ProducteurRepository {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;

    final path = join(await getDatabasesPath(), 'rubberway.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE producteurs (
            code_phi TEXT PRIMARY KEY,
            nom TEXT,
            contact TEXT,
            village TEXT
          )
        ''');
      },
    );

    return _db!;
  }

  // 🔎 Recherche par code
  static Future<Map<String, dynamic>?> getByCode(String code) async {
    final db = await database;

    final result = await db.query(
      'producteurs',
      where: 'code_phi = ?',
      whereArgs: [code],
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    return null;
  }

  // 🔎 Recherche par nom ou code
  static Future<List<Map<String, dynamic>>> search(String query) async {
    final db = await database;

    return await db.query(
      'producteurs',
      where: 'code_phi LIKE ? OR nom LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 50,
    );
  }

  // 📥 Insertion (import Excel)
  static Future<void> insertAll(List<Map<String, dynamic>> data) async {
    final db = await database;

    final batch = db.batch();

    for (final row in data) {
      batch.insert(
        'producteurs',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }
}
