import 'package:flutter/foundation.dart';
import 'package:monarch/services/attribute_manager_service.dart';
import 'package:monarch/services/database_service.dart';
import 'package:monarch/controllers/mission_controller.dart';
import 'package:monarch/models/user_model.dart';
import 'package:monarch/models/mission_model.dart';
import 'package:monarch/services/streak_service.dart';
import 'package:monarch/services/cache_service.dart';
import 'package:intl/intl.dart';

/// 🚀 MISSION SERVICE V14 - AJUSTADO PARA MODELO EXISTENTE
/// 
/// ✅ NOVO SISTEMA DE RECOMPENSAS:
/// 
/// 📌 MISSÕES FIXAS (3-5):
/// - Obrigatórias para streak
/// - Completar TODAS: +2 Disciplina, +1 Hábito, Streak +1
/// - Falhar: Streak zerado
/// 
/// 📌 MISSÕES CUSTOMIZADAS (5-7):
/// - Não afetam streak
/// - Treino: +1 Shape
/// - Estudo: +1 Estudo
/// - Outras: XP
/// - Bônus: 3 completas (+1 Háb), Todas (+2 Háb)

class MissionService {
  static final MissionService _instance = MissionService._();
  static MissionService get instance => _instance;

  MissionService._();

  final DatabaseService _dbService = DatabaseService();
  final AttributesManagerService _attributesManager = AttributesManagerService();
  final MissionToggleController _toggleController = MissionToggleController.instance;
  // FIX: referência ao cache para invalidar o ranking após missão completada
  final _cache = CacheService.instance;

  bool _initialized = false;

  // =========================================================================
  // CONFIGURAÇÕES
  // =========================================================================

  static const int MIN_FIXED_MISSIONS = 3;
  static const int MAX_FIXED_MISSIONS = 5;
  static const int MIN_CUSTOM_MISSIONS = 5;
  static const int MAX_CUSTOM_MISSIONS = 7;

  Future<void> init(String serverId, String userId) async {
    if (_initialized) return;

    debugPrint('🔧 MissionService V14: Inicializando...');
    await _attributesManager.init(serverId, userId);

    _initialized = true;
    debugPrint('✅ MissionService pronto!');
  }

  // =========================================================================
  // TOGGLE DE MISSÃO
  // =========================================================================

  Future<MissionToggleResult> toggleMission({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required MissionModel mission,
    required bool newState,
  }) async {
    if (!_initialized) {
      await init(serverId, userId);
    }

    final date = DatabaseService.todayKey;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🎯 TOGGLE MISSÃO V14: ${mission.name}');
    debugPrint('   Tipo: ${mission.type}');
    debugPrint('   Categoria: ${mission.category}');
    debugPrint('   Estado: ${mission.completed} → $newState');
    debugPrint('   XP: ${mission.xp}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Validação
    if (!newState) {
      return MissionToggleResult(
        success: false,
        blocked: true,
        message: 'Missões não podem ser desmarcadas!',
      );
    }

    final validation = _toggleController.canToggleMission(
      missionId: mission.id,
      currentState: mission.completed,
      newState: newState,
    );

    if (!validation.allowed) {
      return MissionToggleResult(
        success: false,
        blocked: true,
        blockReason: validation.reason,
        message: validation.message ?? 'Operação bloqueada',
      );
    }

    _toggleController.startProcessing(mission.id, newState);

    try {
      // ======================================================================
      // PASSO 1: Calcular XP e Level/Rank
      // ======================================================================

      // FIX: Busca dados frescos do usuário antes de incrementar contadores,
      // evitando que um currentUser cacheado/stale cause perda de incrementos.
      final freshUserForCount = await _dbService.getUserFromServer(
        serverId,
        userId,
        forceRefresh: true,
      );
      final userForCalc = freshUserForCount ?? currentUser;

      final xpChange = mission.xp;
      final newTotalXp = (userForCalc.totalXp + xpChange).clamp(0, 999999999);

      final oldLevel = userForCalc.level;
      final oldRank = userForCalc.rank;

      final newLevel = _calculateLevel(newTotalXp);
      final newRank = _calculateRank(newTotalXp);

      final leveledUp = newLevel > oldLevel;
      final rankedUp = newRank != oldRank && _rankValue(newRank) > _rankValue(oldRank);

      final newMissionCount = userForCalc.stats.totalMissionsCompleted + 1;

      debugPrint('📊 Valores calculados:');
      debugPrint('   XP: ${userForCalc.totalXp} → $newTotalXp (+$xpChange)');
      debugPrint('   Level: $oldLevel → $newLevel');
      debugPrint('   Rank: $oldRank → $newRank');

      // ======================================================================
      // PASSO 2: Salvar missão
      // ======================================================================

      debugPrint('💾 Salvando missão...');

      final missionData = {
        'name': mission.name,
        'xp': mission.xp,
        'completed': true,
        'completedAt': DatabaseService.now.millisecondsSinceEpoch,
      };

      // Adicionar categoria se for custom
      if (mission.isCustom && mission.category != null) {
        missionData['category'] = mission.category.toString().split('.').last;
      }

      final userData = {
        'totalXp': newTotalXp,
        'level': newLevel,
        'rank': newRank,
        'lastSeen': DatabaseService.now.toIso8601String(),
        'stats': {
          'totalMissionsCompleted': newMissionCount,
        },
      };

      await _dbService.updateMissionAndUserBatch(
        serverId: serverId,
        userId: userId,
        date: date,
        missionId: mission.id,
        missionType: mission.isFixed ? 'fixed' : 'custom',
        missionData: missionData,
        userData: userData,
      );

      debugPrint('✅ Missão salva!');

      // FIX: invalida o cache do ranking imediatamente após salvar no DB,
      // garantindo que a próxima abertura da tela busque dados frescos
      _invalidateRankingCache(serverId, userId);

      // ======================================================================
      // PASSO 3: Verificar estado das missões
      // ======================================================================

      debugPrint('🔍 Verificando estado das missões...');

      final missionsState = await _getDailyMissionsState(serverId, userId, date);

      debugPrint('📊 Estado atual:');
      debugPrint('   Fixas: ${missionsState.fixedCompleted}/${missionsState.fixedTotal}');
      debugPrint('   Custom: ${missionsState.customCompleted}/${missionsState.customTotal}');
      debugPrint('   Todas fixas: ${missionsState.allFixedCompleted}');
      debugPrint('   3+ custom: ${missionsState.reached3CustomBonus}');

      // ======================================================================
      // PASSO 4: Calcular atributos - NOVA LÓGICA
      // ======================================================================

      debugPrint('⚡ Calculando atributos...');

      final attributeChanges = await _calculateAttributeChanges(
        serverId: serverId,
        userId: userId,
        currentUser: userForCalc,
        mission: mission,
        missionsState: missionsState,
        date: date,
      );

      debugPrint('📊 Mudanças de atributos: $attributeChanges');

      // ======================================================================
      // PASSO 5: Evolução (level/rank up)
      // ======================================================================

      Map<String, int> evolutionChanges = {};

      if (leveledUp || rankedUp) {
        debugPrint('🆙 Level/Rank up! Atualizando Evolução...');

        final rankEvolution = await _attributesManager.updateAttributesOnLevelOrRankUp(
          serverId: serverId,
          userId: userId,
          currentUser: userForCalc,
          leveledUp: leveledUp,
          rankedUp: rankedUp,
          newLevel: newLevel,
          newRank: newRank,
        );

        if (rankEvolution.isNotEmpty) {
          evolutionChanges.addAll(rankEvolution);
          debugPrint('✅ Evolução: ${rankEvolution['evolution']}');
        }
      }

      // ======================================================================
      // PASSO 6: Streak (se todas fixas completadas)
      // ======================================================================

      Map<String, int> streakAttributeChanges = {};

      if (missionsState.allFixedCompleted) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('🔥 TODAS FIXAS COMPLETADAS! Atualizando streak...');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        try {
          final streakService = StreakService.instance;

          final freshUser = await _dbService.getUserFromServer(
            serverId,
            userId,
            forceRefresh: true,
          );

          if (freshUser != null) {
            final streakUpdate = await streakService.updateStreakOnDayComplete(
              serverId: serverId,
              userId: userId,
              currentUser: freshUser,
            );

            if (streakUpdate.success) {
              debugPrint('✅ Streak: ${streakUpdate.newStreak} dias');

              if (streakUpdate.reachedNewMilestone) {
                debugPrint('🎉 MILESTONE: ${streakUpdate.milestone} dias!');
              }

              streakAttributeChanges.addAll(streakUpdate.attributeChanges);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao atualizar streak (não crítico): $e');
        }
      }

      // ======================================================================
      // PASSO 7: Combinar mudanças
      // ======================================================================

      final allAttributeChanges = <String, int>{...attributeChanges};

      evolutionChanges.forEach((key, value) {
        allAttributeChanges[key] = (allAttributeChanges[key] ?? 0) + value;
      });

      streakAttributeChanges.forEach((key, value) {
        allAttributeChanges[key] = (allAttributeChanges[key] ?? 0) + value;
      });

      // ======================================================================
      // PASSO 8: Estado final
      // ======================================================================

      await Future.delayed(const Duration(milliseconds: 100));

      final finalUser = await _dbService.getUserFromServer(
        serverId,
        userId,
        forceRefresh: true,
      );

      if (finalUser == null) {
        throw Exception('Falha ao buscar estado final');
      }

      _toggleController.finishProcessing(
        mission.id,
        success: true,
        finalState: true,
      );

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ TOGGLE COMPLETO!');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return MissionToggleResult(
        success: true,
        updatedUser: finalUser,
        leveledUp: leveledUp,
        rankedUp: rankedUp,
        xpGained: xpChange,
        attributeChanges: allAttributeChanges,
        message: _getSuccessMessage(mission, missionsState),
        missionsState: missionsState,
      );
    } catch (e, stack) {
      debugPrint('❌ ERRO: $e');
      debugPrint('Stack: $stack');

      _toggleController.finishProcessing(
        mission.id,
        success: false,
        finalState: mission.completed,
      );

      return MissionToggleResult(
        success: false,
        message: 'Erro: $e',
      );
    }
  }

  // =========================================================================
  // FIX: invalida as chaves exatas usadas pelo ranking_screen
  // =========================================================================

  void _invalidateRankingCache(String serverId, String userId) {
    debugPrint('🗑️ MissionService: Invalidando cache do ranking...');
    _cache.invalidate('ranking_${serverId}_top3');
    _cache.invalidate('ranking_${serverId}_page1');
    _cache.invalidate('ranking_position_${serverId}_$userId');
    debugPrint('✅ Cache do ranking invalidado');
  }

  // =========================================================================
  // NOVA LÓGICA DE ATRIBUTOS
  // =========================================================================

  Future<Map<String, int>> _calculateAttributeChanges({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required MissionModel mission,
    required DailyMissionsState missionsState,
    required String date,
  }) async {
    final changes = <String, int>{};

    // -----------------------------------------------------------------------
    // ESTUDO: +1 por missão de estudo (fixa ou custom)
    // -----------------------------------------------------------------------
    if (mission.isStudyMission) {
      final studyChange = await _attributesManager.updateStudyAttribute(
        serverId: serverId,
        userId: userId,
        currentUser: currentUser,
        missionId: mission.id,
        missionName: mission.name,
        date: date,
      );

      if (studyChange > 0) {
        changes['study'] = studyChange;
        debugPrint('   ✅ Estudo: +$studyChange');
      }
    }

    // -----------------------------------------------------------------------
    // SHAPE: +1 por missão de treino (fixa ou custom)
    // -----------------------------------------------------------------------
    if (mission.isFitnessMission) {
      final shapeChange = await _attributesManager.updateShapeAttribute(
        serverId: serverId,
        userId: userId,
        currentUser: currentUser,
        missionId: mission.id,
        missionName: mission.name,
        date: date,
      );

      if (shapeChange > 0) {
        changes['shape'] = shapeChange;
        debugPrint('   ✅ Shape: +$shapeChange');
      }
    }

    // -----------------------------------------------------------------------
    // TODAS FIXAS: +2 Disciplina + +1 Hábito
    // -----------------------------------------------------------------------
    if (missionsState.allFixedCompleted) {
      debugPrint('   🎯 Todas fixas completadas!');

      // +2 Disciplina
      final disciplineChange = await _attributesManager.updateDisciplineOnAllFixed(
        serverId: serverId,
        userId: userId,
        currentUser: currentUser,
        date: date,
      );

      if (disciplineChange > 0) {
        changes['discipline'] = (changes['discipline'] ?? 0) + disciplineChange;
        debugPrint('   ✅ Disciplina: +$disciplineChange (fixas)');
      }

      // +1 Hábito
      final habitChange = await _attributesManager.updateHabitOnAllFixed(
        serverId: serverId,
        userId: userId,
        currentUser: currentUser,
        date: date,
      );

      if (habitChange > 0) {
        changes['habit'] = (changes['habit'] ?? 0) + habitChange;
        debugPrint('   ✅ Hábito: +$habitChange (fixas)');
      }
    }

    // -----------------------------------------------------------------------
    // BÔNUS CUSTOMIZADAS
    // -----------------------------------------------------------------------

    // 3+ custom: +1 Hábito
    if (missionsState.reached3CustomBonus) {
      final habit3 = await _attributesManager.updateHabitOn3Custom(
        serverId: serverId,
        userId: userId,
        currentUser: currentUser,
        date: date,
      );

      if (habit3 > 0) {
        changes['habit'] = (changes['habit'] ?? 0) + habit3;
        debugPrint('   ✅ Hábito: +$habit3 (3 custom)');
      }
    }

    // Todas custom: +2 Hábito
    if (missionsState.allCustomCompleted) {
      final habitAll = await _attributesManager.updateHabitOnAllCustom(
        serverId: serverId,
        userId: userId,
        currentUser: currentUser,
        date: date,
      );

      if (habitAll > 0) {
        changes['habit'] = (changes['habit'] ?? 0) + habitAll;
        debugPrint('   ✅ Hábito: +$habitAll (todas custom)');
      }
    }

    return changes;
  }

  // =========================================================================
  // UTILITÁRIOS
  // =========================================================================

  Future<DailyMissionsState> _getDailyMissionsState(
    String serverId,
    String userId,
    String date,
  ) async {
    final allMissionsData = await _dbService.getDailyMissions(serverId, userId, date);

    final fixedMissions = <MissionModel>[];
    final customMissions = <MissionModel>[];

    if (allMissionsData != null) {
      // Parse fixed
      final fixedData = _safeMapConversion(allMissionsData['fixed']);
      fixedData.forEach((id, data) {
        if (data is Map) {
          final missionData = Map<String, dynamic>.from(data);
          fixedMissions.add(MissionModel.fromMap(id, missionData, MissionType.fixed));
        }
      });

      // Parse custom
      final customData = _safeMapConversion(allMissionsData['custom']);
      customData.forEach((id, data) {
        if (data is Map) {
          final missionData = Map<String, dynamic>.from(data);
          customMissions.add(MissionModel.fromMap(id, missionData, MissionType.custom));
        }
      });
    }

    return DailyMissionsState(
      fixedMissions: fixedMissions,
      customMissions: customMissions,
      date: DateTime.parse(date),
    );
  }

  String _getSuccessMessage(MissionModel mission, DailyMissionsState state) {
    if (state.allDailyCompleted) {
      return '🎉 Todas as missões completadas!';
    }

    if (mission.isFixed && state.allFixedCompleted) {
      return '🔥 Todas fixas completas! Streak mantido!';
    }

    if (mission.isCustom && state.reached3CustomBonus) {
      return '⭐ 3 customizadas! Bônus de hábito!';
    }

    return 'Missão concluída!';
  }

  Map<String, dynamic> _safeMapConversion(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;

    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        result[key.toString()] = value;
      });
      return result;
    }

    return {};
  }

  // =========================================================================
  // CÁLCULOS
  // =========================================================================

  int _calculateLevel(int totalXp) {
    for (int level = 1; level <= 100; level++) {
      final xpNeeded = _totalXpForLevel(level);
      if (totalXp < xpNeeded) {
        return level - 1;
      }
    }
    return 100;
  }

  String _calculateRank(int totalXp) {
    if (totalXp >= 40000) return 'SSS';
    if (totalXp >= 25000) return 'SS';
    if (totalXp >= 15000) return 'S';
    if (totalXp >= 10000) return 'A';
    if (totalXp >= 6000) return 'B';
    if (totalXp >= 3000) return 'C';
    if (totalXp >= 1000) return 'D';
    return 'E';
  }

  int _rankValue(String rank) {
    const values = {
      'E': 0, 'D': 1, 'C': 2, 'B': 3,
      'A': 4, 'S': 5, 'SS': 6, 'SSS': 7,
    };
    return values[rank] ?? 0;
  }

  int _totalXpForLevel(int level) {
    int total = 0;
    for (int i = 1; i <= level; i++) {
      total += _xpForLevel(i);
    }
    return total;
  }

  int _xpForLevel(int level) {
    if (level <= 1) return 0;
    return (level * 100) + ((level - 1) * 50);
  }
}

// =============================================================================
// RESULTADO
// =============================================================================

class MissionToggleResult {
  final bool success;
  final bool blocked;
  final ToggleBlockReason? blockReason;
  final String message;
  final UserModel? updatedUser;
  final bool leveledUp;
  final bool rankedUp;
  final int xpGained;
  final Map<String, int> attributeChanges;
  final DailyMissionsState? missionsState;

  MissionToggleResult({
    required this.success,
    this.blocked = false,
    this.blockReason,
    this.message = '',
    this.updatedUser,
    this.leveledUp = false,
    this.rankedUp = false,
    this.xpGained = 0,
    this.attributeChanges = const {},
    this.missionsState,
  });

  bool get hasAttributeChanges => attributeChanges.isNotEmpty;
}