import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';


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
  
  /// Inicializa o controller carregando transações do Firebase
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
  
  DatabaseReference _getTransactionsRef(String serverId, String userId) {
    return _database.ref('serverData/$serverId/transactions/$userId');
  }
  
  DatabaseReference _getTransactionRef(String serverId, String userId, String transactionId) {
    return _getTransactionsRef(serverId, userId).child(transactionId);
  }

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
  
  /// Invalida todas as transações de uma data específica
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
  
  /// Limpa transações antigas (manter apenas últimos 7 dias)
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
  
  /// Reseta TODAS as transações (usar com cuidado!)
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
  
  String generateCompleteMissionId({
    required String userId,
    required String missionId,
    required String date,
  }) {
    return 'complete_${userId}_${missionId}_$date';
  }
  
  String generateUncompleteMissionId({
    required String userId,
    required String missionId,
    required String date,
  }) {
    return 'uncomplete_${userId}_${missionId}_$date';
  }
  
  String generateStreakUpdateId({
    required String userId,
    required int newStreak,
    required String date,
  }) {
    return 'streak_${userId}_${newStreak}_$date';
  }
  
  String generateLevelUpId({
    required String userId,
    required int newLevel,
  }) {
    return 'levelup_${userId}_$newLevel';
  }
  
  String generateRankUpId({
    required String userId,
    required String newRank,
  }) {
    return 'rankup_${userId}_$newRank';
  }
  
  String generateDailyLoginId({
    required String userId,
    required String date,
  }) {
    return 'login_${userId}_$date';
  }
  
  // =========================================================================
  // HISTÓRICO E DEBUG
  // =========================================================================
  
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
  
  List<AttributeChange> getUserHistory(String userId) {
    return List.unmodifiable(_userHistory[userId] ?? []);
  }
  
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

/// Representa uma mudança de atributo registrada
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
