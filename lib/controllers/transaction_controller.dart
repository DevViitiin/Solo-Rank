import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';


/// Controlador de transações idempotentes para atributos.
///
/// Garante que cada operação de atributo seja executada **exatamente uma vez**
/// usando IDs de transação únicos persistidos no Firebase.
///
/// Fluxo de uma transação:
/// 1. Verifica cache local de transações executadas
/// 2. Verifica Firebase (fonte da verdade)
/// 3. Executa a operação se ainda não foi executada
/// 4. Persiste o registro da transação no Firebase
/// 5. Atualiza cache local e histórico de auditoria
///
/// Também fornece geradores de IDs determinísticos para cada tipo
/// de ação (complete, uncomplete, streak, levelup, rankup, login).
///
/// Implementado como Singleton via [AttributeTransactionController.instance].
class AttributeTransactionController {
  static final AttributeTransactionController _instance = 
      AttributeTransactionController._();
  static AttributeTransactionController get instance => _instance;
  
  AttributeTransactionController._();
  
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // =========================================================================
  // CACHE LOCAL (para performance)
  // =========================================================================
  
  /// Cache em memória de transações executadas
  final Set<String> _executedTransactionsCache = {};
  
  /// Histórico de mudanças por usuário (para debug/auditoria)
  final Map<String, List<AttributeChange>> _userHistory = {};
  
  /// Flag de inicialização
  bool _initialized = false;
  
  // =========================================================================
  // INICIALIZAÇÃO
  // =========================================================================
  
  /// Inicializa o controller carregando transações já executadas do Firebase.
  ///
  /// Popula o cache local para evitar consultas desnecessárias.
  /// Seguro para chamar múltiplas vezes (idempotente).
  Future<void> init(String serverId, String userId) async {
    if (_initialized) return;
    
    debugPrint('🔐 Inicializando TransactionController...');
    
    try {
      // Carregar transações do Firebase para cache
      final snapshot = await _getTransactionsRef(serverId, userId).get();
      
      if (snapshot.exists && snapshot.value != null) {
        final transactions = Map<String, dynamic>.from(snapshot.value as Map);
        
        for (final entry in transactions.entries) {
          final txData = Map<String, dynamic>.from(entry.value);
          if (txData['executed'] == true) {
            _executedTransactionsCache.add(entry.key);
          }
        }
        
        debugPrint('✅ ${_executedTransactionsCache.length} transações carregadas do Firebase');
      }
      
      _initialized = true;
    } catch (e) {
      debugPrint('❌ Erro ao inicializar TransactionController: $e');
    }
  }
  
  // =========================================================================
  // REFERÊNCIAS FIREBASE
  // =========================================================================
  
  /// Referência Firebase para todas as transações de um usuário.
  DatabaseReference _getTransactionsRef(String serverId, String userId) {
    return _database.ref('serverData/$serverId/transactions/$userId');
  }
  
  /// Referência Firebase para uma transação específica.
  DatabaseReference _getTransactionRef(String serverId, String userId, String transactionId) {
    return _getTransactionsRef(serverId, userId).child(transactionId);
  }

  /// Executa uma operação de atributo com garantia de idempotência.
  ///
  /// Verifica cache local e Firebase antes de executar. Se já foi
  /// executada, retorna mapa vazio sem re-executar.
  /// Em caso de sucesso, persiste o registro no Firebase.
  Future<Map<String, int>> executeTransaction({
    required String serverId,
    required String userId,
    required String transactionId,
    required String actionType,
    required Map<String, dynamic> actionData,
    required Future<Map<String, int>> Function() operation,
  }) async {
    // ========================================================================
    // PASSO 1: VERIFICAR CACHE LOCAL
    // ========================================================================
    
    if (_executedTransactionsCache.contains(transactionId)) {
      debugPrint('⚠️ Transação já executada (cache): $transactionId');
      return {};
    }
    
    // ========================================================================
    // PASSO 2: VERIFICAR NO FIREBASE (fonte da verdade)
    // ========================================================================
    
    final txRef = _getTransactionRef(serverId, userId, transactionId);
    final snapshot = await txRef.get();
    
    if (snapshot.exists && snapshot.value != null) {
      final txData = Map<String, dynamic>.from(snapshot.value as Map);
      
      if (txData['executed'] == true) {
        debugPrint('⚠️ Transação já executada (Firebase): $transactionId');
        
        // Atualizar cache local
        _executedTransactionsCache.add(transactionId);
        
        return {};
      }
    }
    
    // ========================================================================
    // PASSO 3: EXECUTAR OPERAÇÃO
    // ========================================================================
    
    debugPrint('🔐 Executando transação: $transactionId');
    
    try {
      // Executar operação
      final result = await operation();
      
      if (result.isNotEmpty) {
        // =====================================================================
        // PASSO 4: PERSISTIR NO FIREBASE
        // =====================================================================
        
        await txRef.set({
          'executed': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'actionType': actionType,
          'actionData': actionData,
          'result': result,
        });
        
        // Atualizar cache local
        _executedTransactionsCache.add(transactionId);
        
        // Registrar no histórico
        _recordChange(
          userId: userId,
          transactionId: transactionId,
          actionType: actionType,
          actionData: actionData,
          attributeChanges: result,
        );
        
        debugPrint('✅ Transação concluída e persistida: $transactionId');
        debugPrint('   Resultado: $result');
      } else {
        debugPrint('ℹ️ Transação sem mudanças: $transactionId');
      }
      
      return result;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Erro na transação $transactionId: $e');
      debugPrint('   Stack: $stackTrace');
      return {};
    }
  }
  
  // =========================================================================
  // MÉTODOS DE VERIFICAÇÃO
  // =========================================================================
  

  /// Verifica se uma transação já foi executada (cache + Firebase).
  Future<bool> wasTransactionExecuted(
    String serverId,
    String userId,
    String transactionId,
  ) async {
    // 1. Verificar cache local
    if (_executedTransactionsCache.contains(transactionId)) {
      debugPrint('🔍 Transação $transactionId JÁ EXECUTADA (cache)');
      return true;
    }
    
    // 2. Verificar no Firebase
    final txRef = _getTransactionRef(serverId, userId, transactionId);
    final snapshot = await txRef.get();
    
    if (snapshot.exists && snapshot.value != null) {
      final txData = Map<String, dynamic>.from(snapshot.value as Map);
      final executed = txData['executed'] == true;
      
      if (executed) {
        // Atualizar cache local
        _executedTransactionsCache.add(transactionId);
        debugPrint('🔍 Transação $transactionId JÁ EXECUTADA (Firebase)');
      } else {
        debugPrint('🔍 Transação $transactionId ainda NÃO EXECUTADA');
      }
      
      return executed;
    }
    
    debugPrint('🔍 Transação $transactionId ainda NÃO EXECUTADA');
    return false;
  }
  
  // =========================================================================
  // MÉTODOS DE INVALIDAÇÃO
  // =========================================================================
  

  /// Remove uma transação do Firebase e cache, permitindo re-execução.
  Future<void> invalidateTransaction(
    String serverId,
    String userId,
    String transactionId,
  ) async {
    debugPrint('🗑️ Invalidando transação: $transactionId');
    
    try {
      // 1. Remover do Firebase
      final txRef = _getTransactionRef(serverId, userId, transactionId);
      await txRef.remove();
      
      // 2. Remover do cache local
      _executedTransactionsCache.remove(transactionId);
      
      debugPrint('✅ Transação invalidada com sucesso');
      debugPrint('   → Pode ser executada novamente');
    } catch (e) {
      debugPrint('❌ Erro ao invalidar transação: $e');
    }
  }
  
  /// Invalida todas as transações que contêm a [date] no ID.
  Future<void> invalidateDate(
    String serverId,
    String userId,
    String date,
  ) async {
    debugPrint('🗑️ Invalidando transações da data: $date');
    
    try {
      // 1. Buscar transações da data no Firebase
      final snapshot = await _getTransactionsRef(serverId, userId).get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return;
      }
      
      final transactions = Map<String, dynamic>.from(snapshot.value as Map);
      int invalidatedCount = 0;
      
      // 2. Remover transações que contêm a data
      for (final entry in transactions.entries) {
        if (entry.key.contains(date)) {
          await _getTransactionRef(serverId, userId, entry.key).remove();
          _executedTransactionsCache.remove(entry.key);
          invalidatedCount++;
        }
      }
      
      debugPrint('✅ $invalidatedCount transações invalidadas para data $date');
    } catch (e) {
      debugPrint('❌ Erro ao invalidar transações da data: $e');
    }
  }
  
  /// Remove transações com mais de 7 dias do Firebase e cache.
  Future<void> cleanOldTransactions(
    String serverId,
    String userId,
  ) async {
    debugPrint('🧹 Limpando transações antigas...');
    
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _getTransactionsRef(serverId, userId).get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return;
      }
      
      final transactions = Map<String, dynamic>.from(snapshot.value as Map);
      int cleanedCount = 0;
      
      for (final entry in transactions.entries) {
        final txData = Map<String, dynamic>.from(entry.value);
        final timestamp = txData['timestamp'] as int?;
        
        if (timestamp != null) {
          final txDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          
          if (txDate.isBefore(cutoffDate)) {
            await _getTransactionRef(serverId, userId, entry.key).remove();
            _executedTransactionsCache.remove(entry.key);
            cleanedCount++;
          }
        }
      }
      
      debugPrint('✅ $cleanedCount transações antigas removidas');
    } catch (e) {
      debugPrint('❌ Erro ao limpar transações antigas: $e');
    }
  }
  
  /// Remove todas as transações do Firebase e limpa cache/histórico.
  ///
  /// **Atenção**: permite que todas as operações sejam re-executadas.
  Future<void> resetAll(String serverId, String userId) async {
    debugPrint('🔄 Resetando TODAS as transações...');
    
    try {
      await _getTransactionsRef(serverId, userId).remove();
      _executedTransactionsCache.clear();
      _userHistory.clear();
      
      debugPrint('✅ Reset completo concluído');
    } catch (e) {
      debugPrint('❌ Erro ao resetar transações: $e');
    }
  }
  
  // =========================================================================
  // GERAÇÃO DE IDs DE TRANSAÇÃO
  // =========================================================================
  
  /// Gera ID determinístico para transação de completar missão.
  String generateCompleteMissionId({
    required String userId,
    required String missionId,
    required String date,
  }) {
    return 'complete_${userId}_${missionId}_$date';
  }
  
  /// Gera ID determinístico para transação de descompletar missão.
  String generateUncompleteMissionId({
    required String userId,
    required String missionId,
    required String date,
  }) {
    return 'uncomplete_${userId}_${missionId}_$date';
  }
  
  /// Gera ID determinístico para transação de atualização de streak.
  String generateStreakUpdateId({
    required String userId,
    required int newStreak,
    required String date,
  }) {
    return 'streak_${userId}_${newStreak}_$date';
  }
  
  /// Gera ID determinístico para transação de level up.
  String generateLevelUpId({
    required String userId,
    required int newLevel,
  }) {
    return 'levelup_${userId}_$newLevel';
  }
  
  /// Gera ID determinístico para transação de rank up.
  String generateRankUpId({
    required String userId,
    required String newRank,
  }) {
    return 'rankup_${userId}_$newRank';
  }
  
  /// Gera ID determinístico para transação de login diário.
  String generateDailyLoginId({
    required String userId,
    required String date,
  }) {
    return 'login_${userId}_$date';
  }
  
  // =========================================================================
  // HISTÓRICO E DEBUG
  // =========================================================================
  
  /// Registra uma mudança no histórico em memória para auditoria/debug.
  void _recordChange({
    required String userId,
    required String transactionId,
    required String actionType,
    required Map<String, dynamic> actionData,
    required Map<String, int> attributeChanges,
  }) {
    if (!_userHistory.containsKey(userId)) {
      _userHistory[userId] = [];
    }
    
    _userHistory[userId]!.add(
      AttributeChange(
        transactionId: transactionId,
        timestamp: DateTime.now(),
        actionType: actionType,
        actionData: actionData,
        attributeChanges: attributeChanges,
      ),
    );
  }
  
  /// Retorna histórico imutável de mudanças de atributos de um usuário.
  List<AttributeChange> getUserHistory(String userId) {
    return List.unmodifiable(_userHistory[userId] ?? []);
  }
  
  /// Imprime informações detalhadas de debug (cache local + Firebase).
  Future<void> printDebugInfo(String serverId, String userId) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔐 AttributeTransactionController - Debug Info');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Cache local: ${_executedTransactionsCache.length} transações');
    debugPrint('Usuários com histórico: ${_userHistory.length}');
    
    // Buscar do Firebase
    try {
      final snapshot = await _getTransactionsRef(serverId, userId).get();
      
      if (snapshot.exists && snapshot.value != null) {
        final transactions = Map<String, dynamic>.from(snapshot.value as Map);
        
        debugPrint('\n📋 Transações no Firebase: ${transactions.length}');
        
        final recent = transactions.entries.take(10);
        for (final entry in recent) {
          final txData = Map<String, dynamic>.from(entry.value);
          final timestamp = txData['timestamp'] as int?;
          
          debugPrint('  • ${entry.key}');
          if (timestamp != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            debugPrint('    ⏰ ${DateFormat('yyyy-MM-dd HH:mm:ss').format(date)}');
          }
        }
      } else {
        debugPrint('\n📋 Nenhuma transação no Firebase');
      }
    } catch (e) {
      debugPrint('❌ Erro ao buscar transações: $e');
    }
    
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}

// =============================================================================
// CLASSES DE SUPORTE
// =============================================================================

/// Registro de auditoria de uma mudança de atributo.
///
/// Armazena o ID da transação, timestamp, tipo de ação,
/// dados da ação e as mudanças numéricas nos atributos.
class AttributeChange {
  final String transactionId;
  final DateTime timestamp;
  final String actionType;
  final Map<String, dynamic> actionData;
  final Map<String, int> attributeChanges;
  
  AttributeChange({
    required this.transactionId,
    required this.timestamp,
    required this.actionType,
    required this.actionData,
    required this.attributeChanges,
  });
  
  @override
  String toString() {
    return 'AttributeChange('
        'tx: $transactionId, '
        'time: ${DateFormat('HH:mm:ss').format(timestamp)}, '
        'action: $actionType, '
        'changes: $attributeChanges'
        ')';
  }
}
