import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Servicio singleton para gestionar el almacenamiento offline de respuestas API
class OfflineStorageService {
  static final OfflineStorageService _instance =
      OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  Database? _database;

  /// Obtiene la instancia de la base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa la base de datos SQLite
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabla para almacenar respuestas de API
        await db.execute('''
          CREATE TABLE api_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            endpoint TEXT NOT NULL,
            params TEXT NOT NULL,
            response TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            UNIQUE(endpoint, params)
          )
        ''');

        // Tabla para almacenar información de imágenes descargadas
        await db.execute('''
          CREATE TABLE image_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_id TEXT NOT NULL UNIQUE,
            local_path TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');

        // Tabla para gestionar rutas descargadas
        await db.execute('''
          CREATE TABLE downloaded_routes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            route_id TEXT NOT NULL UNIQUE,
            route_name TEXT NOT NULL,
            language_id TEXT NOT NULL,
            download_timestamp INTEGER NOT NULL,
            is_complete INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Almacena una respuesta de API en caché
  Future<void> cacheApiResponse(
    String endpoint,
    Map<String, dynamic> params,
    dynamic response,
  ) async {
    final db = await database;
    final paramsJson = jsonEncode(params);
    final responseJson = jsonEncode(response);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'api_cache',
      {
        'endpoint': endpoint,
        'params': paramsJson,
        'response': responseJson,
        'timestamp': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Recupera una respuesta de API desde la caché
  Future<dynamic> getCachedApiResponse(
    String endpoint,
    Map<String, dynamic> params,
  ) async {
    final db = await database;
    final paramsJson = jsonEncode(params);

    final results = await db.query(
      'api_cache',
      where: 'endpoint = ? AND params = ?',
      whereArgs: [endpoint, paramsJson],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final responseJson = results.first['response'] as String;
    return jsonDecode(responseJson);
  }

  /// Verifica si existe una respuesta en caché
  Future<bool> hasCachedResponse(
    String endpoint,
    Map<String, dynamic> params,
  ) async {
    final db = await database;
    final paramsJson = jsonEncode(params);

    final results = await db.query(
      'api_cache',
      where: 'endpoint = ? AND params = ?',
      whereArgs: [endpoint, paramsJson],
      limit: 1,
    );

    return results.isNotEmpty;
  }

  /// Registra una imagen descargada
  Future<void> registerImage(String imageId, String localPath) async {
    final db = await database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'image_cache',
      {
        'image_id': imageId,
        'local_path': localPath,
        'timestamp': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene la ruta local de una imagen
  Future<String?> getImageLocalPath(String imageId) async {
    final db = await database;

    final results = await db.query(
      'image_cache',
      where: 'image_id = ?',
      whereArgs: [imageId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first['local_path'] as String;
  }

  /// Marca una ruta como descargada
  Future<void> markRouteAsDownloaded(
    String routeId,
    String routeName,
    String languageId, {
    bool isComplete = true,
  }) async {
    final db = await database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'downloaded_routes',
      {
        'route_id': routeId,
        'route_name': routeName,
        'language_id': languageId,
        'download_timestamp': timestamp,
        'is_complete': isComplete ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Verifica si una ruta está descargada
  Future<bool> isRouteDownloaded(String routeId, String languageId) async {
    final db = await database;

    final results = await db.query(
      'downloaded_routes',
      where: 'route_id = ? AND language_id = ? AND is_complete = 1',
      whereArgs: [routeId, languageId],
      limit: 1,
    );

    return results.isNotEmpty;
  }

  /// Obtiene todas las rutas descargadas
  Future<List<Map<String, dynamic>>> getDownloadedRoutes() async {
    final db = await database;

    return await db.query(
      'downloaded_routes',
      where: 'is_complete = 1',
      orderBy: 'download_timestamp DESC',
    );
  }

  /// Elimina la caché de una ruta específica
  Future<void> deleteRouteCached(String routeId, String languageId) async {
    final db = await database;

    // Eliminar de la tabla de rutas descargadas
    await db.delete(
      'downloaded_routes',
      where: 'route_id = ? AND language_id = ?',
      whereArgs: [routeId, languageId],
    );

    // Aquí se podrían eliminar también las entradas relacionadas en api_cache
    // si queremos un control más granular
  }

  /// Limpia toda la caché (útil para liberar espacio)
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('api_cache');
    await db.delete('image_cache');
    await db.delete('downloaded_routes');
  }

  /// Obtiene el tamaño aproximado de la caché en MB
  Future<double> getCacheSize() async {
    final db = await database;

    // Contar registros en cada tabla
    final apiCacheCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM api_cache'),
    );
    final imageCacheCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM image_cache'),
    );

    // Aproximación simple: cada registro ~= 10KB en promedio
    final sizeInKB = ((apiCacheCount ?? 0) + (imageCacheCount ?? 0)) * 10;
    return sizeInKB / 1024; // Convertir a MB
  }

  /// Limpia entradas antiguas de la caché (más de 30 días)
  Future<void> cleanOldCache() async {
    final db = await database;
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;

    await db.delete(
      'api_cache',
      where: 'timestamp < ?',
      whereArgs: [thirtyDaysAgo],
    );

    await db.delete(
      'image_cache',
      where: 'timestamp < ?',
      whereArgs: [thirtyDaysAgo],
    );
  }

  /// Limpia caché para un endpoint específico
  Future<void> clearCacheForEndpoint(String endpoint) async {
    final db = await database;
    
    await db.delete(
      'api_cache',
      where: 'endpoint = ?',
      whereArgs: [endpoint],
    );
    
    print('🗑️ Caché limpiado para endpoint: $endpoint');
  }

  /// Limpia caché que coincida con un patrón de endpoint
  Future<void> clearCacheForEndpointPattern(String endpointPattern) async {
    final db = await database;
    
    await db.delete(
      'api_cache',
      where: 'endpoint LIKE ?',
      whereArgs: ['%$endpointPattern%'],
    );
    
    print('🗑️ Caché limpiado para patrón: $endpointPattern');
  }
}
