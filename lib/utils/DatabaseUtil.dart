import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseUtil {
   static  Database? database;
  static bool isDatabaseReady = false;
  static String dbName = "";
  static String tableName= "cacheTable";

  static Future initDatabase(String db,{String? tabname}) {
    dbName = db;
    if(null!=tabname){
      tableName = tabname;
    }
    Future future = Future(() async {
      String databasePath = await createDatabase();
      Database database = await openHttpDatabase(databasePath);
      DatabaseUtil.database = database;
      isDatabaseReady = true;
      return "DatabaseReady";
    });
    return future;
  }

  
  ///生成数据库
  static Future<String> createDatabase() async {
    var databasesPath = await getDatabasesPath();
    return join(databasesPath, "$dbName.db");
  }
///删除数据库
  static deleteMDatabase() async {
    createDatabase().then((path) {
      deleteDatabase(path);
    });
  }

  ///打开数据库
  static Future<Database> openHttpDatabase(String path) async {
    Database database = await openDatabase(path,
        singleInstance: false,
        version: 1, onCreate: (Database db, int version) async {
      await db.execute(
          'CREATE TABLE If Not Exists $tableName (cacheKey TEXT PRIMARY KEY,  value TEXT)');
    }, onOpen: (Database db) async {
      await db.execute(
          'CREATE TABLE If Not Exists  $tableName (cacheKey TEXT PRIMARY KEY,  value TEXT)');
    });
    return database;
  }

  ///关闭数据库
  static closeDatabase(Database database) async {
    await database.close();
  }

  ///查询
  static Future<List<Map<String, dynamic>>> queryHttp(
      Database? database, String cacheKey) async {
    if(database==null){
      return Future.value([]);
    }
    return await database.rawQuery(
        'SELECT value FROM  $tableName WHERE cacheKey = \'' + cacheKey + "\'");
  }

  ///插入
  static Future insertHttp(
      Database? database, String cacheKey, String value) async {
    cacheKey = cacheKey.replaceAll("\"", "\"\"");
    if(database==null){
      return Future.value(-1);
    }
    return await database.transaction((txn) async {
      await txn.rawInsert(
          'INSERT INTO  $tableName(cacheKey, value) VALUES( \'$cacheKey\', \'$value\')');
    });
  }

  /// 更新
  static Future<int> updateHttp(
      Database? database, String cacheKey, String value) async {
    cacheKey = cacheKey.replaceAll("\"", "\\\"");
    if(database==null){
      return Future.value(-1);
    }
    return await database
        .rawUpdate('UPDATE  $tableName SET  value = \'$value\' WHERE cacheKey = \'$cacheKey\'');
  }

 ///删除
  static Future<int> deleteHttp(Database database, String cacheKey) async {
    return await database.rawDelete(
        'DELETE FROM  $tableName WHERE name = \'$cacheKey\'');
  }
}
