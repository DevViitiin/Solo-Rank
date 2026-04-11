import 'package:flutter/foundation.dart';
import 'package:monarch/services/database_service.dart';
import 'package:monarch/models/user_model.dart';
import 'package:intl/intl.dart';

/// Serviço de gerenciamento de sequências diárias (streaks).
///
/// Responsabilidades:
/// - Calcular streak atual baseado em dias consecutivos com missões fixas completas
/// - Atualizar streak quando todas as missões fixas do dia são completadas
/// - Resetar streak quando um dia é perdido (não completou ontem)
/// - Tracking de milestones em tiers de 30 dias para motivação
///
/// O streak depende **apenas das missões fixas** (mínimo 5 completas).
/// Streaks não afetam atributos diretamente, servem como motivação.
/// Implementado como Singleton via [StreakService.instance].
class StreakService {
  static final StreakService _instance = StreakService._();
  static StreakService get instance => _instance;
  
  StreakService._();
  
  final DatabaseService _dbService = DatabaseService();
  
  // =========================================================================
  // CÁLCULO DE STREAK
  // =========================================================================
  
  /// Calcula o streak atual do usuário baseado no histórico de dias completos
  /// 
  /// ⏰ LÓGICA DE QUEBRA DO STREAK:
  /// - Durante o DIA (00:00 - 23:59): Streak NÃO quebra mesmo sem completar hoje
  /// - Após MEIA-NOITE: Se NÃO completou o dia anterior, aí sim quebra
  /// - Exemplo: Completou Seg, Ter, Qua. É quinta 15:00 e não completou ainda.
  ///   → Streak = 3 dias (ainda VIVO, tem até 23:59 quinta para continuar)
  /// - Exemplo: Completou Seg, Ter. É quinta 08:00 (não completou quarta).
  ///   → Streak = 0 (QUEBROU porque passou quarta sem completar)
  /// 
  /// Retorna:
  /// - currentStreak: dias consecutivos incluindo hoje SE completou
  /// - lastCompletedDate: última data que completou todas missões
  /// - streakBroken: true se o streak foi quebrado (dia anterior incompleto)
  Future<StreakCalculationResult> calculateCurrentStreak({
    required String serverId,
    required String userId,
  }) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔥 CALCULANDO STREAK');
      debugPrint('   UserId: $userId');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      
      // Buscar histórico de dias completos dos últimos 90 dias
      final completedDays = await _getCompletedDaysHistory(
        serverId: serverId,
        userId: userId,
        days: 90,
      );
      
      debugPrint('📊 Dias completos encontrados: ${completedDays.length}');
      if (completedDays.isNotEmpty) {
        debugPrint('   Últimos 10: ${completedDays.take(10).join(', ')}');
      }
      
      // Calcular streak
      int currentStreak = 0;
      DateTime? lastCompletedDate;
      bool streakBroken = false;
      
      // Verificar se completou hoje
      final completedToday = completedDays.contains(todayStr);
      
      if (completedToday) {
        currentStreak = 1;
        lastCompletedDate = today;
        
        // Contar dias consecutivos para trás
        DateTime checkDate = today.subtract(const Duration(days: 1));
        
        while (true) {
          final checkDateStr = DateFormat('yyyy-MM-dd').format(checkDate);
          
          if (completedDays.contains(checkDateStr)) {
            currentStreak++;
            lastCompletedDate = checkDate;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
      } else {
        // ✅ NÃO completou hoje ainda
        // Verificar se completou ontem
        final yesterday = today.subtract(const Duration(days: 1));
        final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
        
        if (completedDays.contains(yesterdayStr)) {
          // ✅ Completou ontem, streak AINDA ESTÁ VIVO
          // O usuário tem até o fim do dia de hoje para continuar
          currentStreak = 1;
          lastCompletedDate = yesterday;
          
          // Contar dias consecutivos para trás a partir de ontem
          DateTime checkDate = yesterday.subtract(const Duration(days: 1));
          
          while (true) {
            final checkDateStr = DateFormat('yyyy-MM-dd').format(checkDate);
            
            if (completedDays.contains(checkDateStr)) {
              currentStreak++;
              lastCompletedDate = checkDate;
              checkDate = checkDate.subtract(const Duration(days: 1));
            } else {
              break;
            }
          }
          
          debugPrint('   ⚠️ Ainda não completou hoje, mas streak VIVO (completou ontem)');
          debugPrint('   ⏰ Tem até 23:59 de hoje para manter o streak!');
          
        } else {
          // ❌ NÃO completou nem hoje nem ontem = STREAK QUEBRADO
          // Só chega aqui se passou da meia-noite e ontem não foi completado
          streakBroken = true;
          currentStreak = 0;
          
          debugPrint('   💔 Streak quebrado! Não completou ontem.');
          
          // Buscar última data completada para referência
          if (completedDays.isNotEmpty) {
            lastCompletedDate = DateTime.parse(completedDays.first);
          }
        }
      }

      
      debugPrint('📊 Resultado do cálculo:');
      debugPrint('   Streak atual: $currentStreak dias');
      debugPrint('   Última data completa: ${lastCompletedDate != null ? DateFormat('dd/MM/yyyy').format(lastCompletedDate) : 'nunca'}');
      debugPrint('   Streak quebrado: $streakBroken');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return StreakCalculationResult(
        currentStreak: currentStreak,
        lastCompletedDate: lastCompletedDate,
        streakBroken: streakBroken,
        completedToday: completedToday,
      );
      
    } catch (e, stack) {
      debugPrint('❌ Erro ao calcular streak: $e');
      debugPrint('Stack: $stack');
      
      return StreakCalculationResult(
        currentStreak: 0,
        lastCompletedDate: null,
        streakBroken: true,
        completedToday: false,
      );
    }
  }
  
  /// Busca histórico de dias em que todas as missões foram completadas
  Future<List<String>> _getCompletedDaysHistory({
    required String serverId,
    required String userId,
    required int days,
  }) async {
    final completedDays = <String>[];
    final today = DateTime.now();
    
    for (int i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final missions = await _dbService.getDailyMissions(serverId, userId, dateStr);
      
      if (missions != null) {
        final isComplete = _checkIfDayIsComplete(missions);
        
        if (isComplete) {
          completedDays.add(dateStr);
        }
      }
    }
    
    // Ordenar do mais recente para o mais antigo
    completedDays.sort((a, b) => b.compareTo(a));
    
    return completedDays;
  }
  
  /// Verifica se todas as missões fixas do dia foram completadas (streak depende apenas das fixas)
  bool _checkIfDayIsComplete(Map<String, dynamic> missions) {
    try {
      int fixedCompleted = 0;
      
      // Verificar missões fixas (mínimo 5)
      if (missions['fixed'] != null && missions['fixed'] is Map) {
        final fixed = Map<String, dynamic>.from(missions['fixed']);
        
        if (fixed.length < 5) return false; // Precisa ter pelo menos 5 fixas
        
        for (final mission in fixed.values) {
          if (mission is Map && mission['completed'] == true) {
            fixedCompleted++;
          }
        }
        
        // ✅ Streak depende apenas das 5 fixas
        return fixedCompleted >= 5;
      }
      
      return false;
      
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar dia completo: $e');
      return false;
    }
  }
  
  // =========================================================================
  // ATUALIZAÇÃO DE STREAK
  // =========================================================================
  
  /// Atualiza o streak do usuário quando todas as missões fixas do dia são completadas
  /// 
  /// ⏰ QUANDO CHAMAR:
  /// - APENAS quando a ÚLTIMA missão fixa do dia é completada
  /// - NÃO chamar ao fazer login
  /// - NÃO chamar múltiplas vezes no mesmo dia
  /// 
  /// ✅ LÓGICA DE INCREMENTO:
  /// - Completa 5 fixas → currentStreak++
  /// - Se currentStreak > bestStreak → bestStreak = currentStreak
  /// - Só incrementa UMA VEZ por dia (mesmo que complete fixas de novo)
  /// 
  /// ✅ NOVA LÓGICA:
  /// - Se completar 5 fixas: bestStreak = bestStreak + 1
  /// - Se NÃO completar 5 fixas: bestStreak = 0
  /// - Streak não afeta atributos (apenas motivação)
  Future<StreakUpdateResult> updateStreakOnDayComplete({
    required String serverId,
    required String userId,
    required UserModel currentUser,
  }) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔥 ATUALIZANDO STREAK - DIA COMPLETO');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // Calcular novo streak
      final calculation = await calculateCurrentStreak(
        serverId: serverId,
        userId: userId,
      );
      
      final oldStreak = currentUser.stats.currentStreak;
      final newStreak = calculation.currentStreak;
      
      // ✅ NOVA LÓGICA: bestStreak = bestStreak atual + 1 (sempre incrementa)
      final oldBestStreak = currentUser.stats.bestStreak;
      final newBestStreak = oldBestStreak + 1;
      
      debugPrint('📊 Comparação:');
      debugPrint('   Streak antigo: $oldStreak');
      debugPrint('   Streak novo: $newStreak');
      debugPrint('   Melhor streak antigo: $oldBestStreak');
      debugPrint('   Melhor streak novo: $newBestStreak (+1)');
      
      // Verificar se atingiu novo milestone
      final oldMilestone = _getStreakMilestone(oldStreak);
      final newMilestone = _getStreakMilestone(newStreak);
      final reachedNewMilestone = newMilestone > oldMilestone;
      
      if (reachedNewMilestone) {
        debugPrint('🎉 NOVO MILESTONE ATINGIDO: $newMilestone dias!');
      }
      
      // Atualizar stats no banco
      final newStats = currentUser.stats.copyWith(
        currentStreak: newStreak,
        bestStreak: newBestStreak,
      );
      
      await _dbService.updateUser(
        serverId,
        userId,
        {
          'stats': newStats.toMap(),
        },
      );
      
      // ✅ ATUALIZADO: Streak não afeta mais atributos
      // Apenas mantemos o tracking do streak para exibição e motivação
      Map<String, int> attributeChanges = {};
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ STREAK ATUALIZADO COM SUCESSO');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return StreakUpdateResult(
        success: true,
        oldStreak: oldStreak,
        newStreak: newStreak,
        bestStreak: newBestStreak,
        reachedNewMilestone: reachedNewMilestone,
        milestone: newMilestone,
        attributeChanges: attributeChanges,
      );
      
    } catch (e, stack) {
      debugPrint('❌ Erro ao atualizar streak: $e');
      debugPrint('Stack: $stack');
      
      return StreakUpdateResult(
        success: false,
        oldStreak: currentUser.stats.currentStreak,
        newStreak: currentUser.stats.currentStreak,
        bestStreak: currentUser.stats.bestStreak,
        reachedNewMilestone: false,
        milestone: 0,
        attributeChanges: {},
      );
    }
  }
  
  /// Verifica e reseta streak se necessário
  /// 
  /// ⏰ QUANDO CHAMAR:
  /// - Ao fazer login (para verificar se quebrou desde ontem)
  /// - Ao carregar dados do dia
  /// - NUNCA durante o dia atual (só verifica dia ANTERIOR)
  /// 
  /// ✅ LÓGICA DE RESET:
  /// - Só reseta se NÃO completou o DIA ANTERIOR (ontem)
  /// - NUNCA reseta por não ter completado hoje ainda
  /// - Exemplo: É quinta 10:00, não completei hoje. MAS completei quarta.
  ///   → Streak NÃO reseta (ainda tenho até 23:59 quinta)
  /// - Exemplo: É quinta 10:00, não completei quarta.
  ///   → Streak RESETA (passou meia-noite de quarta sem completar)
  Future<void> checkAndResetStreakIfNeeded({
    required String serverId,
    required String userId,
    required UserModel currentUser,
  }) async {
    try {
      final calculation = await calculateCurrentStreak(
        serverId: serverId,
        userId: userId,
      );
      
      // ✅ NOVO: Verificar se não completou ontem para zerar bestStreak
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
      
      final yesterdayMissions = await _dbService.getDailyMissions(serverId, userId, yesterdayStr);
      bool completedYesterday = false;
      
      if (yesterdayMissions != null) {
        completedYesterday = _checkIfDayIsComplete(yesterdayMissions);
      }
      
      // Se não completou ontem E bestStreak > 0, zerar
      if (!completedYesterday && currentUser.stats.bestStreak > 0) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('💔 NÃO COMPLETOU ONTEM! Zerando bestStreak...');
        debugPrint('   BestStreak perdido: ${currentUser.stats.bestStreak} dias');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        final newStats = currentUser.stats.copyWith(
          bestStreak: 0,
        );
        
        await _dbService.updateUser(
          serverId,
          userId,
          {
            'stats': newStats.toMap(),
          },
        );
        
        debugPrint('✅ BestStreak resetado para 0');
      }
      
      // Se o streak foi quebrado e o usuário ainda tem streak > 0, resetar
      if (calculation.streakBroken && currentUser.stats.currentStreak > 0) {
        debugPrint('💔 STREAK QUEBRADO! Resetando currentStreak...');
        debugPrint('   CurrentStreak perdido: ${currentUser.stats.currentStreak} dias');
        
        final newStats = currentUser.stats.copyWith(
          currentStreak: 0,
        );
        
        await _dbService.updateUser(
          serverId,
          userId,
          {
            'stats': newStats.toMap(),
          },
        );
        
        debugPrint('✅ CurrentStreak resetado');
      }
      
    } catch (e) {
      debugPrint('❌ Erro ao verificar/resetar streak: $e');
    }
  }
  
  // =========================================================================
  // MILESTONES (apenas para exibição e motivação)
  // =========================================================================
  
  /// Retorna os milestones do tier atual baseado no streak
  /// Tier 1 (0-30): 7, 15, 30
  /// Tier 2 (31-60): 37, 45, 60
  /// Tier 3 (61-90): 67, 75, 90
  /// E assim por diante...
  List<int> getCurrentTierMilestones(int currentStreak) {
    // Determinar qual tier está baseado no streak atual
    final tier = (currentStreak / 30).floor();
    final baseValue = tier * 30;
    
    return [
      baseValue + 7,
      baseValue + 15,
      baseValue + 30,
    ];
  }
  
  /// Retorna o próximo milestone a ser alcançado
  int getNextMilestone(int currentStreak) {
    final milestones = getCurrentTierMilestones(currentStreak);
    
    for (final milestone in milestones) {
      if (currentStreak < milestone) {
        return milestone;
      }
    }
    
    // Se completou todos do tier atual, retornar primeiro do próximo tier
    final nextTier = (currentStreak / 30).floor() + 1;
    return (nextTier * 30) + 7;
  }
  
  /// Retorna qual milestone foi atingido (se houver)
  int _getStreakMilestone(int streak) {
    final milestones = getCurrentTierMilestones(streak);
    
    for (int i = milestones.length - 1; i >= 0; i--) {
      if (streak >= milestones[i]) {
        return milestones[i];
      }
    }
    
    return 0;
  }
  
  /// Retorna o tier atual do streak (1 = 0-30 dias, 2 = 31-60, etc.).
  int getCurrentTier(int streak) {
    return (streak / 30).floor() + 1;
  }
  
  /// Verifica se alcançou todos os milestones do tier atual
  bool hasCompletedCurrentTier(int streak) {
    final milestones = getCurrentTierMilestones(streak);
    return streak >= milestones.last;
  }
  
  /// Retorna o bônus de XP baseado no streak atual.
  ///
  /// Escala: 0 (0-2 dias) → 25 (3-6) → 50 (7-14) → 100 (15-29)
  /// → 150 (30-59) → 200 (60-89) → 300 (90+).
  int getStreakXpBonus(int streak) {
    if (streak >= 90) return 300;  // 90+ dias (Tier 3+)
    if (streak >= 60) return 200;  // 60-89 dias (Tier 2)
    if (streak >= 30) return 150;  // 30-59 dias (Tier 1 completo)
    if (streak >= 15) return 100;  // 15-29 dias
    if (streak >= 7) return 50;    // 7-14 dias
    if (streak >= 3) return 25;    // 3-6 dias
    return 0;                      // 0-2 dias
  }
  
  /// Retorna mensagem motivacional baseada no streak
  String getStreakMessage(int streak) {
    if (streak >= 90) return '👑 MONARCA! 90+ dias de domínio absoluto!';
    if (streak >= 60) return '💎 DIAMANTE! 60+ dias de consistência épica!';
    if (streak >= 30) return '🔥 LENDÁRIO! 30+ dias de dedicação absoluta!';
    if (streak >= 15) return '⚡ INCANSÁVEL! 15+ dias de consistência!';
    if (streak >= 7) return '💪 GUERREIRO! 1 semana conquistada!';
    if (streak >= 3) return '🎯 FOCADO! Continue assim!';
    if (streak >= 1) return '✨ Ótimo começo!';
    return '💔 Streak perdido. Comece novamente hoje!';
  }
}

// =============================================================================
// CLASSES DE RESULTADO
// =============================================================================

/// Resultado do cálculo de streak atual.
///
/// Contém o streak em dias, última data completada, e flags indicando
/// se o streak foi quebrado e se o dia atual já foi completado.
class StreakCalculationResult {
  final int currentStreak;
  final DateTime? lastCompletedDate;
  final bool streakBroken;
  final bool completedToday;
  
  StreakCalculationResult({
    required this.currentStreak,
    required this.lastCompletedDate,
    required this.streakBroken,
    required this.completedToday,
  });
  
  /// Retorna `true` se o usuário tem um streak ativo (>0 dias).
  bool get hasActiveStreak => currentStreak > 0;
  
  /// Retorna a última data completada formatada (dd/MM/yyyy) ou 'Nunca'.
  String get lastCompletedDateFormatted {
    if (lastCompletedDate == null) return 'Nunca';
    return DateFormat('dd/MM/yyyy').format(lastCompletedDate!);
  }
}

/// Resultado da atualização de streak após completar todas as fixas.
///
/// Inclui streak anterior/novo, melhor streak, milestone atingido
/// e eventuais mudanças de atributos.
class StreakUpdateResult {
  final bool success;
  final int oldStreak;
  final int newStreak;
  final int bestStreak;
  final bool reachedNewMilestone;
  final int milestone;
  final Map<String, int> attributeChanges;
  
  StreakUpdateResult({
    required this.success,
    required this.oldStreak,
    required this.newStreak,
    required this.bestStreak,
    required this.reachedNewMilestone,
    required this.milestone,
    required this.attributeChanges,
  });
  
  /// Retorna `true` se o streak aumentou nesta atualização.
  bool get streakIncreased => newStreak > oldStreak;

  /// Diferença entre streak novo e anterior.
  int get streakGain => newStreak - oldStreak;
}
