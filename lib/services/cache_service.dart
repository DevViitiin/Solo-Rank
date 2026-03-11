import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Dados em cache com timestamp
class CachedData<T> {
  final T data;
  final DateTime timestamp;

  CachedData(this.data, this.timestamp);

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }
}

/// Serviço de cache em 2 camadas (memória + disco persistente)
///
/// CORREÇÃO PRINCIPAL:
/// - getCached agora aceita [toEncodable] e [fromJson] para tipos
///   complexos como UserModel, List<UserModel>, etc.
/// - jsonEncode nunca mais vai receber objetos não serializáveis
class CacheService {
  static CacheService? _instance;
  static CacheService get instance {
    _instance ??= CacheService._();
    return _instance!;
  }

  CacheService._();

  // ============================================================================
  // DURAÇÕES DE CACHE
  // ============================================================================

  static const Duration CACHE_VERY_SHORT = Duration(minutes: 1);
  static const Duration CACHE_SHORT      = Duration(minutes: 5);
  static const Duration CACHE_MEDIUM     = Duration(minutes: 30);
  static const Duration CACHE_LONG       = Duration(hours: 6);
  static const Duration CACHE_VERY_LONG  = Duration(days: 1);

  // ============================================================================
  // ESTADO INTERNO
  // ============================================================================

  final Map<String, CachedData> _memoryCache = {};
  late Box _persistentCache;
  bool _initialized = false;

  int _hits       = 0;
  int _misses     = 0;
  int _diskErrors = 0;

  static const int MAX_MEMORY_ITEMS = 100;
  static const int MAX_DISK_ITEMS   = 500;

  // ============================================================================
  // INICIALIZAÇÃO
  // ============================================================================

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      _persistentCache = await Hive.openBox('solo_rank_cache');
      _initialized = true;
      debugPrint('✅ CacheService inicializado');
      await _cleanOldCacheEntries();
    } catch (e) {
      debugPrint('❌ Erro ao inicializar CacheService: $e');
      rethrow;
    }
  }

  // ============================================================================
  // MÉTODO PRINCIPAL — getCached
  //
  // Parâmetros opcionais para tipos que NÃO são primitivos/Map/List simples:
  //
  //   toEncodable : converte T → dynamic serializável (ex: list.map((e) => e.toMap()).toList())
  //   fromJson    : converte dynamic (saído do jsonDecode) → T (ex: (j) => UserModel.fromMap(j))
  //
  // Para tipos simples (int, String, Map<String,dynamic>, etc.) não precisa passar nada.
  // ============================================================================

  Future<T?> getCached<T>({
    required String key,
    required Future<T> Function() fetchFunction,
    Duration cacheDuration = CACHE_MEDIUM,
    bool forceRefresh = false,
    /// Serializa T para algo que jsonEncode aceita
    dynamic Function(T? data)? toEncodable,
    /// Desserializa o resultado do jsonDecode de volta para T
    T Function(dynamic json)? fromJson,
  }) async {
    if (!_initialized) await init();

    if (forceRefresh) {
      debugPrint('🔄 Cache: Forçando refresh para $key');
      return await _fetchAndCache(
        key, fetchFunction,
        toEncodable: toEncodable,
        fromJson: fromJson,
      );
    }

    // 1. Cache em memória
    if (_memoryCache.containsKey(key)) {
      final cached = _memoryCache[key];
      if (cached != null && !cached.isExpired(cacheDuration)) {
        _hits++;
        debugPrint('🎯 Cache HIT (memória): $key [$_hitRate% hit rate]');
        return cached.data as T;
      }
      _memoryCache.remove(key);
      debugPrint('⏰ Cache expirado (memória): $key');
    }

    // 2. Cache em disco
    if (_persistentCache.containsKey(key)) {
      final cachedJson = _persistentCache.get(key);
      final cachedTime = _persistentCache.get('${key}_time');

      if (cachedJson != null && cachedTime != null) {
        final age = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(cachedTime as int),
        );

        if (age < cacheDuration) {
          try {
            final decoded = jsonDecode(cachedJson as String);
            // Se fromJson foi fornecido, converte; senão usa cast direto
            final T data = fromJson != null ? fromJson(decoded) : (decoded as T);

            _memoryCache[key] = CachedData(data, DateTime.now());
            _checkMemoryLimit();

            _hits++;
            debugPrint('🎯 Cache HIT (disco): $key [$_hitRate% hit rate]');
            return data;
          } catch (e) {
            debugPrint('⚠️ Erro ao decodificar cache de $key: $e');
            await _removeDiskCacheEntry(key);
          }
        } else {
          debugPrint('⏰ Cache expirado (disco): $key (${age.inMinutes}min)');
        }
      }
    }

    // 3. Cache MISS
    _misses++;
    debugPrint('❌ Cache MISS: $key [$_hitRate% hit rate]');
    return await _fetchAndCache(
      key, fetchFunction,
      toEncodable: toEncodable,
      fromJson: fromJson,
    );
  }

  // ============================================================================
  // INTERNO
  // ============================================================================

  Future<T> _fetchAndCache<T>(
    String key,
    Future<T> Function() fetchFunction, {
    dynamic Function(T? data)? toEncodable,
    T Function(dynamic json)? fromJson,
  }) async {
    final freshData = await fetchFunction();

    _memoryCache[key] = CachedData(freshData, DateTime.now());
    _checkMemoryLimit();

    await _saveToDisk(key, freshData, toEncodable: toEncodable);

    return freshData;
  }

  Future<void> _saveToDisk<T>(
    String key,
    T data, {
    dynamic Function(T? data)? toEncodable,
  }) async {
    try {
      // Usa o conversor customizado se fornecido, senão tenta direto
      final encodable = toEncodable != null ? toEncodable(data) : data;
      final jsonData  = jsonEncode(encodable);

      if (jsonData.length > 1024 * 1024) {
        debugPrint('⚠️ Dados muito grandes para disco: $key (${jsonData.length} bytes)');
        return;
      }

      await _persistentCache.put(key, jsonData);
      await _persistentCache.put('${key}_time', DateTime.now().millisecondsSinceEpoch);
      await _checkDiskLimit();

      debugPrint('✅ Cacheado em disco: $key');
    } catch (e) {
      _diskErrors++;
      debugPrint('⚠️ Falha ao cachear $key em disco: $e');
      // Não retenta — salvar em disco é best-effort. Memória já está ok.
    }
  }

  Future<void> _removeDiskCacheEntry(String key) async {
    try {
      await _persistentCache.delete(key);
      await _persistentCache.delete('${key}_time');
    } catch (e) {
      debugPrint('⚠️ Erro ao remover cache em disco: $key - $e');
    }
  }

  void _checkMemoryLimit() {
    if (_memoryCache.length <= MAX_MEMORY_ITEMS) return;
    final sorted = _memoryCache.keys.toList()
      ..sort((a, b) =>
          _memoryCache[a]!.timestamp.compareTo(_memoryCache[b]!.timestamp));
    final toRemove = _memoryCache.length - MAX_MEMORY_ITEMS;
    for (int i = 0; i < toRemove; i++) {
      _memoryCache.remove(sorted[i]);
    }
    debugPrint('🧹 Cache memória: removidas $toRemove entradas antigas');
  }

  Future<void> _checkDiskLimit() async {
    if (_persistentCache.length <= MAX_DISK_ITEMS) return;
    try {
      final entries = <MapEntry<String, int>>[];
      for (final key in _persistentCache.keys) {
        if (key is String && key.endsWith('_time')) {
          final ts = _persistentCache.get(key);
          if (ts is int) {
            entries.add(MapEntry(key.replaceAll('_time', ''), ts));
          }
        }
      }
      entries.sort((a, b) => a.value.compareTo(b.value));
      final toRemove = _persistentCache.length - MAX_DISK_ITEMS;
      for (int i = 0; i < toRemove && i < entries.length; i++) {
        await _removeDiskCacheEntry(entries[i].key);
      }
      debugPrint('🧹 Cache disco: removidas $toRemove entradas antigas');
    } catch (e) {
      debugPrint('❌ Erro ao limpar cache em disco: $e');
    }
  }

  Future<void> _cleanOldCacheEntries() async {
    try {
      final cutoff =
          DateTime.now().millisecondsSinceEpoch - (7 * 24 * 60 * 60 * 1000);
      final toRemove = <String>[];
      for (final key in _persistentCache.keys) {
        if (key is String && key.endsWith('_time')) {
          final ts = _persistentCache.get(key);
          if (ts is int && ts < cutoff) {
            toRemove.add(key.replaceAll('_time', ''));
          }
        }
      }
      for (final key in toRemove) {
        await _removeDiskCacheEntry(key);
      }
      if (toRemove.isNotEmpty) {
        debugPrint('🧹 Limpeza: ${toRemove.length} entradas antigas removidas');
      }
    } catch (e) {
      debugPrint('❌ Erro ao limpar cache antigo: $e');
    }
  }

  // ============================================================================
  // INVALIDAÇÃO
  // ============================================================================

  void invalidate(String key) {
    _memoryCache.remove(key);
    Future.microtask(() => _removeDiskCacheEntry(key));
    debugPrint('🗑️ Cache invalidado: $key');
  }

  void invalidateMultiple(List<String> keys) {
    for (final key in keys) invalidate(key);
  }

  void invalidatePattern(String pattern) {
    final regex = RegExp(pattern.replaceAll('*', '.*'));
    _memoryCache.removeWhere((key, _) => regex.hasMatch(key));
    Future.microtask(() async {
      final toRemove = _persistentCache.keys
          .where((k) => k is String && regex.hasMatch(k))
          .cast<String>()
          .toList();
      for (final k in toRemove) await _removeDiskCacheEntry(k);
    });
    debugPrint('🗑️ Cache invalidado (padrão): $pattern');
  }

  Future<void> invalidateAll() async {
    _memoryCache.clear();
    try {
      await _persistentCache.clear();
    } catch (e) {
      debugPrint('❌ Erro ao limpar cache em disco: $e');
    }
    _hits = _misses = _diskErrors = 0;
    debugPrint('🗑️ TODO cache limpo');
  }

  // ============================================================================
  // ESTATÍSTICAS
  // ============================================================================

  String get _hitRate {
    if (_hits + _misses == 0) return '0';
    return ((_hits / (_hits + _misses)) * 100).toStringAsFixed(1);
  }

  Map<String, dynamic> getStats() => {
        'hits': _hits,
        'misses': _misses,
        'disk_errors': _diskErrors,
        'hit_rate': _hitRate,
        'memory_items': _memoryCache.length,
        'disk_items': _persistentCache.length,
      };

  void printStats() {
    final s = getStats();
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📊 CACHE STATS:');
    debugPrint('   Hits: ${s['hits']}');
    debugPrint('   Misses: ${s['misses']}');
    debugPrint('   Disk Errors: ${s['disk_errors']}');
    debugPrint('   Hit Rate: ${s['hit_rate']}%');
    debugPrint('   Memória: ${s['memory_items']} itens');
    debugPrint('   Disco: ${s['disk_items']} itens');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  void resetStats() => _hits = _misses = _diskErrors = 0;
}