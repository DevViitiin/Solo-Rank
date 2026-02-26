import 'package:shared_preferences/shared_preferences.dart';
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
/// ✅ CORREÇÕES V2:
/// - Melhor tratamento de erros de serialização
/// - Logs mais detalhados para debugging
/// - Limite de tamanho de cache em disco
/// - Limpeza automática de cache antigo
/// - Retry logic para operações Hive
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
  
  /// Cache muito curto - dados em tempo real
  static const Duration CACHE_VERY_SHORT = Duration(minutes: 1);
  
  /// Cache curto - dados que mudam com frequência moderada
  static const Duration CACHE_SHORT = Duration(minutes: 5);
  
  /// Cache médio - dados pessoais que mudam ocasionalmente
  static const Duration CACHE_MEDIUM = Duration(minutes: 30);
  
  /// Cache longo - dados que mudam raramente
  static const Duration CACHE_LONG = Duration(hours: 6);
  
  /// Cache muito longo - dados quase estáticos
  static const Duration CACHE_VERY_LONG = Duration(days: 1);
  
  // ============================================================================
  // CACHE STORAGE
  // ============================================================================
  
  /// Cache em memória (rápido mas volátil)
  final Map<String, CachedData> _memoryCache = {};
  
  /// Cache persistente (sobrevive ao fechar app)
  late Box _persistentCache;
  bool _initialized = false;
  
  /// Estatísticas
  int _hits = 0;
  int _misses = 0;
  int _diskErrors = 0; // ✅ NOVO: Contador de erros em disco
  
  // ✅ NOVO: Controle de tamanho
  static const int MAX_MEMORY_ITEMS = 100;
  static const int MAX_DISK_ITEMS = 500;
  
  // ============================================================================
  // INICIALIZAÇÃO
  // ============================================================================
  
  /// Inicializar o serviço de cache
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      await Hive.initFlutter();
      _persistentCache = await Hive.openBox('solo_rank_cache');
      _initialized = true;
      
      debugPrint('✅ CacheService inicializado');
      debugPrint('   Itens em memória: ${_memoryCache.length}');
      debugPrint('   Itens em disco: ${_persistentCache.length}');
      
      // ✅ NOVO: Limpar cache antigo na inicialização
      await _cleanOldCacheEntries();
      
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao inicializar CacheService: $e');
      debugPrint('   Stack: $stackTrace');
      rethrow;
    }
  }
  
  // ============================================================================
  // MÉTODOS PRINCIPAIS
  // ============================================================================
  
  /// Buscar dados com cache automático
  /// 
  /// ✅ CORREÇÕES:
  /// - Melhor tratamento de erros de serialização
  /// - Retry logic para operações em disco
  /// - Logs mais detalhados
  Future<T?> getCached<T>({
    required String key,
    required Future<T> Function() fetchFunction,
    Duration cacheDuration = CACHE_MEDIUM,
    bool forceRefresh = false,
  }) async {
    if (!_initialized) await init();
    
    // Forçar refresh (pull-to-refresh)
    if (forceRefresh) {
      debugPrint('🔄 Cache: Forçando refresh para $key');
      return await _fetchAndCache(key, fetchFunction);
    }
    
    // 1. Verificar cache em memória
    if (_memoryCache.containsKey(key)) {
      final cached = _memoryCache[key];
      if (cached != null && !cached.isExpired(cacheDuration)) {
        _hits++;
        debugPrint('🎯 Cache HIT (memória): $key [${_hitRate}% hit rate]');
        return cached.data as T;
      }
      _memoryCache.remove(key);
      debugPrint('⏰ Cache expirado (memória): $key');
    }
    
    // 2. Verificar cache persistente (disco)
    if (_persistentCache.containsKey(key)) {
      final cachedJson = _persistentCache.get(key);
      final cachedTime = _persistentCache.get('${key}_time');
      
      if (cachedJson != null && cachedTime != null) {
        final age = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(cachedTime as int)
        );
        
        if (age < cacheDuration) {
          try {
            final data = jsonDecode(cachedJson) as T;
            
            // Promover para memória
            _memoryCache[key] = CachedData(data, DateTime.now());
            
            // ✅ NOVO: Verificar limite de memória
            _checkMemoryLimit();
            
            _hits++;
            debugPrint('🎯 Cache HIT (disco): $key [${_hitRate}% hit rate]');
            return data;
          } catch (e) {
            debugPrint('⚠️ Erro ao decodificar cache de $key: $e');
            // Remover entrada corrompida
            await _removeDiskCacheEntry(key);
            // Continua para buscar do Firebase
          }
        } else {
          debugPrint('⏰ Cache expirado (disco): $key (${age.inMinutes}min)');
        }
      }
    }
    
    // 3. Cache MISS - buscar do Firebase
    _misses++;
    debugPrint('❌ Cache MISS: $key - buscando Firebase... [${_hitRate}% hit rate]');
    return await _fetchAndCache(key, fetchFunction);
  }
  
  /// Buscar dados do Firebase e salvar no cache
  /// 
  /// ✅ CORREÇÕES:
  /// - Retry logic para operações em disco
  /// - Melhor tratamento de erros
  Future<T> _fetchAndCache<T>(String key, Future<T> Function() fetchFunction) async {
    final freshData = await fetchFunction();
    
    // Salvar em memória
    _memoryCache[key] = CachedData(freshData, DateTime.now());
    
    // ✅ NOVO: Verificar limite de memória
    _checkMemoryLimit();
    
    // Salvar no disco (com retry)
    await _saveToDiskWithRetry(key, freshData);
    
    return freshData;
  }
  
  /// ✅ NOVO: Salvar no disco com retry logic
  Future<void> _saveToDiskWithRetry<T>(String key, T data, {int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final jsonData = jsonEncode(data);
        
        // ✅ NOVO: Verificar tamanho antes de salvar
        if (jsonData.length > 1024 * 1024) { // 1MB limite
          debugPrint('⚠️ Dados muito grandes para cachear em disco: $key (${jsonData.length} bytes)');
          return;
        }
        
        await _persistentCache.put(key, jsonData);
        await _persistentCache.put('${key}_time', DateTime.now().millisecondsSinceEpoch);
        
        // ✅ NOVO: Verificar limite de disco
        await _checkDiskLimit();
        
        debugPrint('✅ Cacheado em disco: $key');
        return; // Sucesso
        
      } catch (e) {
        _diskErrors++;
        debugPrint('⚠️ Tentativa ${attempt + 1}/$maxRetries falhou ao cachear $key em disco: $e');
        
        if (attempt == maxRetries - 1) {
          debugPrint('❌ Falha definitiva ao cachear $key após $maxRetries tentativas');
        } else {
          // Aguardar antes de tentar novamente
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
        }
      }
    }
  }
  
  /// ✅ NOVO: Remover entrada de cache em disco com tratamento de erro
  Future<void> _removeDiskCacheEntry(String key) async {
    try {
      await _persistentCache.delete(key);
      await _persistentCache.delete('${key}_time');
    } catch (e) {
      debugPrint('⚠️ Erro ao remover cache em disco: $key - $e');
    }
  }
  
  /// ✅ NOVO: Verificar e limpar cache em memória se exceder limite
  void _checkMemoryLimit() {
    if (_memoryCache.length > MAX_MEMORY_ITEMS) {
      // Remover as entradas mais antigas
      final sortedKeys = _memoryCache.keys.toList()
        ..sort((a, b) {
          final aTime = _memoryCache[a]!.timestamp;
          final bTime = _memoryCache[b]!.timestamp;
          return aTime.compareTo(bTime);
        });
      
      final toRemove = _memoryCache.length - MAX_MEMORY_ITEMS;
      for (int i = 0; i < toRemove; i++) {
        _memoryCache.remove(sortedKeys[i]);
      }
      
      debugPrint('🧹 Cache memória: removidas $toRemove entradas antigas');
    }
  }
  
  /// ✅ NOVO: Verificar e limpar cache em disco se exceder limite
  Future<void> _checkDiskLimit() async {
    if (_persistentCache.length > MAX_DISK_ITEMS) {
      try {
        // Coletar entradas com timestamp
        final entries = <MapEntry<String, int>>[];
        
        for (final key in _persistentCache.keys) {
          if (key is String && key.endsWith('_time')) {
            final timestamp = _persistentCache.get(key);
            if (timestamp is int) {
              final dataKey = key.replaceAll('_time', '');
              entries.add(MapEntry(dataKey, timestamp));
            }
          }
        }
        
        // Ordenar por timestamp (mais antigas primeiro)
        entries.sort((a, b) => a.value.compareTo(b.value));
        
        // Remover as mais antigas
        final toRemove = _persistentCache.length - MAX_DISK_ITEMS;
        for (int i = 0; i < toRemove && i < entries.length; i++) {
          await _removeDiskCacheEntry(entries[i].key);
        }
        
        debugPrint('🧹 Cache disco: removidas $toRemove entradas antigas');
      } catch (e) {
        debugPrint('❌ Erro ao limpar cache em disco: $e');
      }
    }
  }
  
  /// ✅ NOVO: Limpar entradas de cache antigas (>7 dias)
  Future<void> _cleanOldCacheEntries() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cutoff = now - (7 * 24 * 60 * 60 * 1000); // 7 dias
      
      final keysToRemove = <String>[];
      
      for (final key in _persistentCache.keys) {
        if (key is String && key.endsWith('_time')) {
          final timestamp = _persistentCache.get(key);
          if (timestamp is int && timestamp < cutoff) {
            final dataKey = key.replaceAll('_time', '');
            keysToRemove.add(dataKey);
          }
        }
      }
      
      for (final key in keysToRemove) {
        await _removeDiskCacheEntry(key);
      }
      
      if (keysToRemove.isNotEmpty) {
        debugPrint('🧹 Limpeza: ${keysToRemove.length} entradas antigas removidas');
      }
    } catch (e) {
      debugPrint('❌ Erro ao limpar cache antigo: $e');
    }
  }
  
  // ============================================================================
  // INVALIDAÇÃO DE CACHE
  // ============================================================================
  
  /// Invalidar cache específico
  void invalidate(String key) {
    _memoryCache.remove(key);
    
    // Remover do disco de forma assíncrona (não bloquear)
    Future.microtask(() async {
      await _removeDiskCacheEntry(key);
    });
    
    debugPrint('🗑️ Cache invalidado: $key');
  }
  
  /// Invalidar múltiplas chaves
  void invalidateMultiple(List<String> keys) {
    for (final key in keys) {
      invalidate(key);
    }
  }
  
  /// Invalidar por padrão (ex: 'user_*')
  void invalidatePattern(String pattern) {
    final regex = RegExp(pattern.replaceAll('*', '.*'));
    
    // Memória
    _memoryCache.removeWhere((key, value) => regex.hasMatch(key));
    
    // Disco (assíncrono)
    Future.microtask(() async {
      final keysToRemove = _persistentCache.keys
          .where((key) => key is String && regex.hasMatch(key))
          .cast<String>()
          .toList();
      
      for (final key in keysToRemove) {
        await _removeDiskCacheEntry(key);
      }
    });
    
    debugPrint('🗑️ Cache invalidado (padrão): $pattern');
  }
  
  /// Limpar todo o cache
  Future<void> invalidateAll() async {
    _memoryCache.clear();
    
    try {
      await _persistentCache.clear();
    } catch (e) {
      debugPrint('❌ Erro ao limpar cache em disco: $e');
    }
    
    _hits = 0;
    _misses = 0;
    _diskErrors = 0;
    
    debugPrint('🗑️ TODO cache limpo');
  }
  
  // ============================================================================
  // ESTATÍSTICAS
  // ============================================================================
  
  /// Taxa de acerto do cache (percentage)
  String get _hitRate {
    if (_hits + _misses == 0) return '0';
    return ((_hits / (_hits + _misses)) * 100).toStringAsFixed(1);
  }
  
  /// Obter estatísticas completas
  Map<String, dynamic> getStats() {
    return {
      'hits': _hits,
      'misses': _misses,
      'disk_errors': _diskErrors,
      'hit_rate': _hitRate,
      'memory_items': _memoryCache.length,
      'disk_items': _persistentCache.length,
      'memory_keys': _memoryCache.keys.toList(),
    };
  }
  
  /// Imprimir estatísticas (debug)
  void printStats() {
    final stats = getStats();
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📊 CACHE STATS:');
    debugPrint('   Hits: ${stats['hits']}');
    debugPrint('   Misses: ${stats['misses']}');
    debugPrint('   Disk Errors: ${stats['disk_errors']}');
    debugPrint('   Hit Rate: ${stats['hit_rate']}%');
    debugPrint('   Memória: ${stats['memory_items']} itens');
    debugPrint('   Disco: ${stats['disk_items']} itens');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
  
  /// Resetar estatísticas
  void resetStats() {
    _hits = 0;
    _misses = 0;
    _diskErrors = 0;
  }
}