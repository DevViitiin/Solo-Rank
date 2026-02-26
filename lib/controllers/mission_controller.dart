import 'dart:async';
import 'package:flutter/foundation.dart';


class MissionToggleController {
  static final MissionToggleController _instance = MissionToggleController._();
  static MissionToggleController get instance => _instance;
  
  MissionToggleController._();
  
  
  /// Missões em processamento (para evitar múltiplos cliques simultâneos)
  final Set<String> _processingMissions = {};
  
  /// Timers de debounce por missão
  final Map<String, Timer> _debounceTimers = {};
  
  /// Estado atual conhecido das missões (para validação)
  final Map<String, bool> _missionStates = {};
  
  /// Operações pendentes (para cancelamento)
  final Map<String, Completer<bool>> _pendingOperations = {};
  
  // =========================================================================
  // CONFIGURAÇÕES
  // =========================================================================
  
  /// Tempo de debounce entre cliques (milissegundos)
  static const int DEBOUNCE_MS = 500;
  
  ToggleValidation canToggleMission({
    required String missionId,
    required bool currentState,
    required bool newState,
  }) {
    // 1. Verificar se já está processando
    if (_processingMissions.contains(missionId)) {
      return ToggleValidation(
        allowed: false,
        reason: ToggleBlockReason.processing,
        message: 'Processando missão...',
      );
    }
    
    // 2. Verificar se tem timer de debounce ativo
    if (_debounceTimers.containsKey(missionId)) {
      return ToggleValidation(
        allowed: false,
        reason: ToggleBlockReason.debouncing,
        message: 'Aguarde um momento...',
      );
    }
    
    // 3. Validar se o estado atual é o esperado
    if (_missionStates.containsKey(missionId)) {
      if (_missionStates[missionId] != currentState) {
        return ToggleValidation(
          allowed: false,
          reason: ToggleBlockReason.stateConflict,
          message: 'Estado da missão mudou. Atualizando...',
        );
      }
    }
    
    // ✅ Permitido!
    return ToggleValidation(
      allowed: true,
      reason: ToggleBlockReason.none,
    );
  }
  
  /// Inicia o processamento de uma missão
  /// 
  /// DEVE ser chamado ANTES de executar a operação no banco
  void startProcessing(String missionId, bool newState) {
    _processingMissions.add(missionId);
    
    // Cancelar debounce anterior se existir
    _debounceTimers[missionId]?.cancel();
    _debounceTimers.remove(missionId);
    
    debugPrint('🔒 MissionToggle: Processando $missionId → $newState');
  }
  
  /// Finaliza o processamento de uma missão
  /// 
  /// DEVE ser chamado DEPOIS da operação no banco (sucesso ou erro)
  void finishProcessing(
    String missionId, {
    required bool success,
    required bool finalState,
  }) {
    _processingMissions.remove(missionId);
    
    if (success) {
      // Atualizar estado conhecido
      _missionStates[missionId] = finalState;
      
      // Iniciar debounce
      _startDebounce(missionId);
      
      debugPrint('✅ MissionToggle: Finalizado $missionId → $finalState');
    } else {
      // Em caso de erro, não atualizar estado
      debugPrint('❌ MissionToggle: Erro em $missionId');
    }
  }
  
  /// Inicia timer de debounce
  void _startDebounce(String missionId) {
    _debounceTimers[missionId]?.cancel();
    
    _debounceTimers[missionId] = Timer(
      Duration(milliseconds: DEBOUNCE_MS),
      () {
        _debounceTimers.remove(missionId);
        debugPrint('⏱️ MissionToggle: Debounce finalizado para $missionId');
      },
    );
  }
  
  /// Cancela processamento pendente
  void cancelProcessing(String missionId) {
    _processingMissions.remove(missionId);
    _debounceTimers[missionId]?.cancel();
    _debounceTimers.remove(missionId);
    
    if (_pendingOperations.containsKey(missionId)) {
      _pendingOperations[missionId]?.complete(false);
      _pendingOperations.remove(missionId);
    }
    
    debugPrint('🚫 MissionToggle: Cancelado $missionId');
  }
  
  // =========================================================================
  // SYNC DE ESTADO
  // =========================================================================
  
  /// Sincroniza estado de missões (ex: após load inicial)
  void syncMissionStates(Map<String, bool> states) {
    _missionStates.clear();
    _missionStates.addAll(states);
    
    debugPrint('🔄 MissionToggle: ${states.length} estados sincronizados');
  }
  
  /// Atualiza estado de uma missão específica
  void updateMissionState(String missionId, bool completed) {
    _missionStates[missionId] = completed;
  }
  
  /// Limpa estado de uma missão (ex: ao deletar)
  void clearMissionState(String missionId) {
    _missionStates.remove(missionId);
    _processingMissions.remove(missionId);
    _debounceTimers[missionId]?.cancel();
    _debounceTimers.remove(missionId);
    
    debugPrint('🗑️ MissionToggle: Estado limpo para $missionId');
  }
  
  // =========================================================================
  // RESET E DEBUG
  // =========================================================================
  
  /// Reseta todos os estados (ex: ao trocar de dia)
  void resetAll() {
    _processingMissions.clear();
    _missionStates.clear();
    
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    
    for (final completer in _pendingOperations.values) {
      completer.complete(false);
    }
    _pendingOperations.clear();
    
    debugPrint('🔄 MissionToggle: Reset completo');
  }
  
  /// Debug: Imprime estado atual
  void printDebugInfo() {
    debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📋 MissionToggleController - Debug Info');
    debugPrint('┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Processing: ${_processingMissions.length} missões');
    debugPrint('States: ${_missionStates.length} missões');
    debugPrint('Debouncing: ${_debounceTimers.length} missões');
    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    if (_missionStates.isNotEmpty) {
      debugPrint('Estados conhecidos:');
      _missionStates.forEach((id, state) {
        debugPrint('  $id: ${state ? "✓" : "○"}');
      });
    }
  }
}

// =========================================================================
// CLASSES DE SUPORTE
// =========================================================================

/// Resultado da validação de toggle
class ToggleValidation {
  final bool allowed;
  final ToggleBlockReason reason;
  final String? message;
  final int? remainingSeconds;
  
  ToggleValidation({
    required this.allowed,
    required this.reason,
    this.message,
    this.remainingSeconds,
  });
  
  bool get isBlocked => !allowed;
}

/// Razões para bloqueio de toggle
enum ToggleBlockReason {
  none,              // Não bloqueado
  processing,        // Já está processando
  debouncing,        // Em período de debounce
  stateConflict,     // Estado local diferente do esperado
  lockedAfterComplete,
}
