// import 'package:path/path.dart' as path ;
// import 'package:sqflite/sqflite.dart';
//
// ///
// /// create_user: zhengzaihong
// /// email:1096877329@qq.com
// /// create_date: 2022/8/11
// /// create_time: 9:52
// /// describe: 利用原生平台的sqllite
// ///
// class DatabaseUtil {
//   static  Database? database;
//   static bool isDatabaseReady = false;
//   static String dbName = "";
//   static String tableName= "cacheTable";
//
//   static final List<Function> _checkDataBaseListener = [];
//   static Future initDatabase(String db,{String? tabName}) {
//     dbName = db;
//     if(null!=tabName){
//       tableName = tabName;
//     }
//     Future future = Future(() async {
//       String databasePath = await createDatabase();
//       Database database = await openHttpDatabase(databasePath);
//       DatabaseUtil.database = database;
//       isDatabaseReady = true;
//       for (var callBack in _checkDataBaseListener) {
//         callBack.call(isDatabaseReady);
//       }
//       _checkDataBaseListener.clear();
//       return isDatabaseReady;
//     });
//     return future;
//   }
//
//   ///数据库还没初始完成，可能已经纯在网络请求，先将其缓存
//   ///等待数据库完成后并返回数据后，将其全部回调全部清除。
//   static void setDataBaseReadListener(Function(bool isOk) function){
//     if(!isDatabaseReady){
//       _checkDataBaseListener.add(function);
//     }
//   }
//
//   ///生成数据库
//   static Future<String> createDatabase() async {
//     var databasesPath = await getDatabasesPath();
//     return path.join(databasesPath, "$dbName.db");
//   }
// ///删除数据库
//   static deleteMDatabase() async {
//     createDatabase().then((path) {
//       deleteDatabase(path);
//     });
//   }
//
//   ///打开数据库
//   static Future<Database> openHttpDatabase(String path) async {
//     Database database = await openDatabase(path,
//         singleInstance: false,
//         version: 1, onCreate: (Database db, int version) async {
//       await db.execute(
//           'CREATE TABLE If Not Exists $tableName (cacheKey TEXT PRIMARY KEY,  value TEXT)');
//     }, onOpen: (Database db) async {
//       await db.execute(
//           'CREATE TABLE If Not Exists  $tableName (cacheKey TEXT PRIMARY KEY,  value TEXT)');
//     });
//     return database;
//   }
//
//   ///关闭数据库
//   static closeDatabase(Database database) async {
//     await database.close();
//   }
//
//   ///查询
//   static Future<List<Map<String, dynamic>>> queryHttp(
//       Database? database, String cacheKey) async {
//     if(database==null){
//       return Future.value([]);
//     }
//     return await database.rawQuery('SELECT value FROM  $tableName WHERE cacheKey = \'' + cacheKey + "\'");
//   }
//
//   ///插入
//   static Future insertHttp(
//       Database? database, String cacheKey, String value) async {
//     cacheKey = cacheKey.replaceAll("\"", "\"\"");
//     if(database==null){
//       return Future.value(-1);
//     }
//     return await database.transaction((txn) async {
//       await txn.rawInsert(
//           'INSERT INTO  $tableName(cacheKey, value) VALUES( \'$cacheKey\', \'$value\')');
//     });
//   }
//
//   /// 更新
//   static Future<int> updateHttp(
//       Database? database, String cacheKey, String value) async {
//     cacheKey = cacheKey.replaceAll("\"", "\\\"");
//     if(database==null){
//       return Future.value(-1);
//     }
//     return await database
//         .rawUpdate('UPDATE  $tableName SET  value = \'$value\' WHERE cacheKey = \'$cacheKey\'');
//   }
//
//  ///删除
//   static Future<int> deleteHttp(Database database, String cacheKey) async {
//     return await database.rawDelete(
//         'DELETE FROM  $tableName WHERE name = \'$cacheKey\'');
//   }
// }
