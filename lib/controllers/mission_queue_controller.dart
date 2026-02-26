import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';


class MissionBatchController {
  static final MissionBatchController _instance = MissionBatchController._();
  static MissionBatchController get instance => _instance;
  
  MissionBatchController._();
  
  // =========================================================================
  // ESTADO
  // =========================================================================
  
  /// Fila de operações pendentes
  final Queue<_MissionOperation> _queue = Queue();
  
  /// Controlador de stream para estado
  final _stateController = StreamController<MissionBatchState>.broadcast();
  
  /// Estado atual
  final Set<String> _processing = {};
  final Set<String> _pending = {};
  
  /// Estatísticas
  int _totalEnqueued = 0;
  int _totalProcessed = 0;
  int _totalSuccess = 0;
  int _totalFailed = 0;
  int _totalRetries = 0;
  
  /// Flag de processamento
  bool _isProcessing = false;
  
  /// Configuração de retry
  static const int MAX_RETRIES = 3;
  static const Duration RETRY_DELAY = Duration(milliseconds: 500);
  
  // =========================================================================
  // GETTERS
  // =========================================================================
  
  Stream<MissionBatchState> get stateStream => _stateController.stream;
  
  MissionBatchState get currentState => MissionBatchState(
    processing: Set.from(_processing),
    pending: Set.from(_pending),
  );
  
  bool get hasQueuedOperations => _queue.isNotEmpty;

  Future<void> enqueueMissionToggle({
    required String missionId,
    required bool optimisticState,
    required Future<dynamic> Function() operation,
    required void Function(dynamic result) onSuccess,
    required void Function(dynamic error) onError,
  }) async {
    debugPrint('📥 BatchController V3: Enfileirando $missionId');
    debugPrint('   Estado otimista: $optimisticState');
    debugPrint('   Fila atual: ${_queue.length}');
    
    // Criar operação
    final op = _MissionOperation(
      missionId: missionId,
      optimisticState: optimisticState,
      operation: operation,
      onSuccess: onSuccess,
      onError: onError,
      retryCount: 0,
    );
    
    // Adicionar à fila
    _queue.add(op);
    _pending.add(missionId);
    _totalEnqueued++;
    
    // Notificar estado
    _emitState();
    
    debugPrint('✅ Operação enfileirada. Fila: ${_queue.length}');
    
    // Processar (sem await para não travar UI)
    _scheduleBatchProcessing();
  }
  
  // =========================================================================
  // PROCESSAMENTO
  // =========================================================================
  
  /// Agenda processamento do batch
  void _scheduleBatchProcessing() {
    if (_isProcessing) {
      debugPrint('⏳ Batch já processando, aguardando...');
      return;
    }
    
    Future.microtask(() {
      if (!_isProcessing && _queue.isNotEmpty) {
        _processBatch();
      }
    });
  }
  
  /// Processa batch de operações SEQUENCIALMENTE
  Future<void> _processBatch() async {
    if (_isProcessing || _queue.isEmpty) return;
    
    _isProcessing = true;
    
    while (_queue.isNotEmpty) {
      final op = _queue.removeFirst();
      
      // Mover de pending para processing
      _pending.remove(op.missionId);
      _processing.add(op.missionId);
      _emitState();
      
      // Executar operação com retry
      await _executeOperationWithRetry(op);
      
      // Remover de processing
      _processing.remove(op.missionId);
      _emitState();
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    _isProcessing = false;
    

  }
  
  /// Executa operação com retry automático
  Future<void> _executeOperationWithRetry(_MissionOperation op) async {
    int attempt = 0;
    
    while (attempt < MAX_RETRIES) {
      attempt++;
      
      if (attempt > 1) {
        debugPrint('   🔄 Retry ${attempt - 1}/$MAX_RETRIES');
        _totalRetries++;
        await Future.delayed(RETRY_DELAY);
      }
      
      try {
        await _executeOperation(op);
        return; // Sucesso, sair do loop
        
      } catch (e) {
        debugPrint('   ❌ Tentativa $attempt falhou: $e');
        
        if (attempt >= MAX_RETRIES) {
          debugPrint('   ❌ Máximo de retries atingido!');
          _totalFailed++;
          
          // Chamar callback de erro
          try {
            op.onError(e);
          } catch (callbackError) {
            debugPrint('   ⚠️ Erro no callback onError: $callbackError');
          }
          
          return;
        }
      }
    }
  }
  
  /// Executa operação individual
  Future<void> _executeOperation(_MissionOperation op) async {
    _totalProcessed++;
    
    debugPrint('   ⚡ Executando operação...');
    
    // Executar operação
    final result = await op.operation();
    
    // Chamar callback de sucesso
    try {
      op.onSuccess(result);
      _totalSuccess++;
      debugPrint('   ✅ Sucesso!');
    } catch (e) {
      debugPrint('   ⚠️ Erro no callback onSuccess: $e');
      // Mesmo com erro no callback, consideramos sucesso da operação
    }
  }
  
  // =========================================================================
  // ESTADO
  // =========================================================================
  
  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(currentState);
    }
  }
  
  // =========================================================================
  // ESTATÍSTICAS
  // =========================================================================
  
  void printStats() {
    debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    debugPrint('┃ 📊 MISSION BATCH CONTROLLER V3 - Estatísticas          ┃');
    debugPrint('┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫');
    debugPrint('┃   Fila:              ${_queue.length.toString().padRight(3)}                            ┃');
    debugPrint('┃   Processando:       ${_processing.length.toString().padRight(3)}                            ┃');
    debugPrint('┃   Pendentes:         ${_pending.length.toString().padRight(3)}                            ┃');
    debugPrint('┃   Total enfileirado: ${_totalEnqueued.toString().padRight(3)}                            ┃');
    debugPrint('┃   Total processado:  ${_totalProcessed.toString().padRight(3)}                            ┃');
    debugPrint('┃   Sucesso:           ${_totalSuccess.toString().padRight(3)}                            ┃');
    debugPrint('┃   Falha:             ${_totalFailed.toString().padRight(3)}                            ┃');
    debugPrint('┃   Retries:           ${_totalRetries.toString().padRight(3)}                            ┃');
    
    final successRate = _totalProcessed > 0 
        ? (_totalSuccess / _totalProcessed * 100).toStringAsFixed(1)
        : '0.0';
    debugPrint('┃   Taxa de sucesso:   ${successRate.padRight(5)}%                        ┃');
    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
  }
  
  void resetStats() {
    _totalEnqueued = 0;
    _totalProcessed = 0;
    _totalSuccess = 0;
    _totalFailed = 0;
    _totalRetries = 0;
    debugPrint('📊 Estatísticas resetadas');
  }
  
  // =========================================================================
  // CLEANUP
  // =========================================================================
  
  /// Limpa fila de operações pendentes
  void clearQueue() {
    final count = _queue.length;
    _queue.clear();
    _pending.clear();
    
    debugPrint('🗑️ Fila limpa: $count operações removidas');
    _emitState();
  }
  
  /// Aguarda conclusão de todas operações
  Future<void> waitForCompletion({Duration timeout = const Duration(seconds: 30)}) async {
    debugPrint('⏳ Aguardando conclusão de operações...');
    
    final startTime = DateTime.now();
    
    while (_queue.isNotEmpty || _processing.isNotEmpty) {
      if (DateTime.now().difference(startTime) > timeout) {
        debugPrint('⚠️ Timeout aguardando conclusão!');
        break;
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    debugPrint('✅ Todas operações concluídas');
  }
  
  void dispose() {
    _stateController.close();
  }
}

// =============================================================================
// CLASSES DE SUPORTE
// =============================================================================

/// Operação de missão na fila
class _MissionOperation {
  final String missionId;
  final bool optimisticState;
  final Future<dynamic> Function() operation;
  final void Function(dynamic result) onSuccess;
  final void Function(dynamic error) onError;
  final int retryCount;
  
  _MissionOperation({
    required this.missionId,
    required this.optimisticState,
    required this.operation,
    required this.onSuccess,
    required this.onError,
    this.retryCount = 0,
  });
}

/// Estado do batch controller
class MissionBatchState {
  final Set<String> processing;
  final Set<String> pending;
  
  MissionBatchState({
    required this.processing,
    required this.pending,
  });
  
  bool isProcessing(String missionId) => processing.contains(missionId);
  bool isPending(String missionId) => pending.contains(missionId);
  bool isActive(String missionId) => isProcessing(missionId) || isPending(missionId);
}