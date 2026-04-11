import 'package:flutter/foundation.dart';
import 'package:monarch/core/constants/app_constants.dart';
import 'package:monarch/controllers/transaction_controller.dart';
import 'package:monarch/models/user_model.dart';
import 'package:monarch/services/database_service.dart';

/// Serviço gerenciador de atributos do sistema Dracoryx.
///
/// Coordena a atualização dos 5 atributos (Estudo, Disciplina, Evolução,
/// Shape, Hábito) com garantia de idempotência via [AttributeTransactionController].
///
/// Cada método público:
/// 1. Gera um transaction ID único para evitar duplicidade
/// 2. Executa a lógica de cálculo dentro de uma transação
/// 3. Salva no Firebase via [_updateAttributesSafely]
///
/// Atributos são limitados a [AppConstants.maxAttributePoints] (100).
class AttributesManagerService {
  final DatabaseService _dbService = DatabaseService();
  final AttributeTransactionController _txController = 
      AttributeTransactionController.instance;
  
  static const int MAX_FIXED_MISSIONS = 5;  // 3-5
  static const int MAX_CUSTOM_MISSIONS = 7; 
  static const int TOTAL_MISSIONS = MAX_FIXED_MISSIONS + MAX_CUSTOM_MISSIONS;
  
  /// Inicializa o controller de transações de atributos.
  ///
  /// Deve ser chamado antes de qualquer operação de atributo.
  Future<void> init(String serverId, String userId) async {
    await _txController.init(serverId, userId);
  }
  
  // =========================================================================
  // ESTUDO - +1 por missão de estudo (fixa ou customizada)
  // =========================================================================
  
  /// Incrementa +1 em Estudo ao completar uma missão de estudo.
  ///
  /// Idempotente: a mesma missão no mesmo dia não incrementa duas vezes.
  Future<int> updateStudyAttribute({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required String missionId,
    required String missionName,
    required String date,
  }) async {
    final studyTxId = 'study_${userId}_${missionId}_$date';
    
    debugPrint('📚 Processando Estudo:');
    debugPrint('   Transaction ID: $studyTxId');
    
    final studyUpdate = await _txController.executeTransaction(
      serverId: serverId,
      userId: userId,
      transactionId: studyTxId,
      actionType: 'study_mission',
      actionData: {
        'missionId': missionId,
        'missionName': missionName,
        'date': date,
      },
      operation: () async {
        final currentStudy = currentUser.stats.attributes.study;
        final newStudy = (currentStudy + 1).clamp(0, AppConstants.maxAttributePoints);
        
        if (newStudy != currentStudy) {
          debugPrint('   ✅ Estudo: $currentStudy → $newStudy');
          return {'study': newStudy};
        }
        return <String, int>{};
      },
    );
    
    if (studyUpdate.isNotEmpty) {
      await _updateAttributesSafely(serverId, userId, currentUser, studyUpdate);
    }
    
    return studyUpdate['study'] ?? 0;
  }
  
  // =========================================================================
  // SHAPE - +1 por missão de treino (fixa ou customizada)
  // =========================================================================
  
  /// Incrementa +1 em Shape ao completar uma missão de fitness.
  ///
  /// Idempotente: a mesma missão no mesmo dia não incrementa duas vezes.
  Future<int> updateShapeAttribute({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required String missionId,
    required String missionName,
    required String date,
  }) async {
    final shapeTxId = 'shape_${userId}_${missionId}_$date';
    
    debugPrint('💪 Processando Shape:');
    debugPrint('   Transaction ID: $shapeTxId');
    
    final shapeUpdate = await _txController.executeTransaction(
      serverId: serverId,
      userId: userId,
      transactionId: shapeTxId,
      actionType: 'shape_mission',
      actionData: {
        'missionId': missionId,
        'missionName': missionName,
        'date': date,
      },
      operation: () async {
        final currentShape = currentUser.stats.attributes.shape;
        final newShape = (currentShape + 1).clamp(0, AppConstants.maxAttributePoints);
        
        if (newShape != currentShape) {
          debugPrint('   ✅ Shape: $currentShape → $newShape');
          return {'shape': newShape};
        }
        return <String, int>{};
      },
    );
    
    if (shapeUpdate.isNotEmpty) {
      await _updateAttributesSafely(serverId, userId, currentUser, shapeUpdate);
    }
    
    return shapeUpdate['shape'] ?? 0;
  }
  
  // =========================================================================
  // DISCIPLINA - +2 ao completar todas as fixas (1x por dia)
  // =========================================================================
  
  /// Incrementa +2 em Disciplina ao completar todas as missões fixas.
  ///
  /// Executado no máximo 1x por dia via transaction ID.
  Future<int> updateDisciplineOnAllFixed({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required String date,
  }) async {
    final disciplineTxId = 'discipline_all_fixed_${userId}_$date';
    
    debugPrint('🎯 Processando Disciplina (todas fixas):');
    debugPrint('   Transaction ID: $disciplineTxId');
    
    final disciplineUpdate = await _txController.executeTransaction(
      serverId: serverId,
      userId: userId,
      transactionId: disciplineTxId,
      actionType: 'discipline_all_fixed',
      actionData: {
        'date': date,
        'bonus': 2,
      },
      operation: () async {
        // Buscar valor atualizado
        final freshUser = await _dbService.getUserFromServer(
          serverId,
          userId,
          forceRefresh: true,
        );
        
        final currentDiscipline = freshUser?.stats.attributes.discipline ?? 
                                  currentUser.stats.attributes.discipline;
        
        final newDiscipline = (currentDiscipline + 2).clamp(0, AppConstants.maxAttributePoints);
        
        if (newDiscipline != currentDiscipline) {
          debugPrint('   ✅ Disciplina: $currentDiscipline → $newDiscipline (+2)');
          return {'discipline': newDiscipline};
        }
        return <String, int>{};
      },
    );
    
    if (disciplineUpdate.isNotEmpty) {
      await _updateAttributesSafely(serverId, userId, currentUser, disciplineUpdate);
    }
    
    return disciplineUpdate['discipline'] ?? 0;
  }
  
  // =========================================================================
  // HÁBITO - +1 ao completar todas as fixas (1x por dia)
  // =========================================================================
  
  /// Incrementa +1 em Hábito ao completar todas as missões fixas.
  ///
  /// Executado no máximo 1x por dia via transaction ID.
  Future<int> updateHabitOnAllFixed({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required String date,
  }) async {
    final habitTxId = 'habit_all_fixed_${userId}_$date';
    
    debugPrint('✅ Processando Hábito (todas fixas):');
    debugPrint('   Transaction ID: $habitTxId');
    
    final habitUpdate = await _txController.executeTransaction(
      serverId: serverId,
      userId: userId,
      transactionId: habitTxId,
      actionType: 'habit_all_fixed',
      actionData: {
        'date': date,
        'bonus': 1,
      },
      operation: () async {
        final freshUser = await _dbService.getUserFromServer(
          serverId,
          userId,
          forceRefresh: true,
        );
        
        final currentHabit = freshUser?.stats.attributes.habit ?? 
                            currentUser.stats.attributes.habit;
        
        final newHabit = (currentHabit + 1).clamp(0, AppConstants.maxAttributePoints);
        
        if (newHabit != currentHabit) {
          debugPrint('   ✅ Hábito: $currentHabit → $newHabit (+1)');
          return {'habit': newHabit};
        }
        return <String, int>{};
      },
    );
    
    if (habitUpdate.isNotEmpty) {
      await _updateAttributesSafely(serverId, userId, currentUser, habitUpdate);
    }
    
    return habitUpdate['habit'] ?? 0;
  }
  
  // =========================================================================
  // HÁBITO - +1 ao completar 3 customizadas (1x por dia)
  // =========================================================================
  
  /// Incrementa +1 em Hábito ao completar 3 missões customizadas.
  ///
  /// Executado no máximo 1x por dia via transaction ID.
  Future<int> updateHabitOn3Custom({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required String date,
  }) async {
    final habitTxId = 'habit_3_custom_${userId}_$date';
    
    debugPrint('⭐ Processando Hábito (3 customizadas):');
    debugPrint('   Transaction ID: $habitTxId');
    
    final habitUpdate = await _txController.executeTransaction(
      serverId: serverId,
      userId: userId,
      transactionId: habitTxId,
      actionType: 'habit_3_custom',
      actionData: {
        'date': date,
        'bonus': 1,
      },
      operation: () async {
        final freshUser = await _dbService.getUserFromServer(
          serverId,
          userId,
          forceRefresh: true,
        );
        
        final currentHabit = freshUser?.stats.attributes.habit ?? 
                            currentUser.stats.attributes.habit;
        
        final newHabit = (currentHabit + 1).clamp(0, AppConstants.maxAttributePoints);
        
        if (newHabit != currentHabit) {
          debugPrint('   ✅ Hábito: $currentHabit → $newHabit (+1)');
          return {'habit': newHabit};
        }
        return <String, int>{};
      },
    );
    
    if (habitUpdate.isNotEmpty) {
      await _updateAttributesSafely(serverId, userId, currentUser, habitUpdate);
    }
    
    return habitUpdate['habit'] ?? 0;
  }
  
  // =========================================================================
  // HÁBITO - +2 ao completar todas customizadas (1x por dia)
  // =========================================================================
  
  /// Incrementa +2 em Hábito ao completar todas as missões customizadas.
  ///
  /// Executado no máximo 1x por dia via transaction ID.
  Future<int> updateHabitOnAllCustom({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required String date,
  }) async {
    final habitTxId = 'habit_all_custom_${userId}_$date';
    
    debugPrint('🌟 Processando Hábito (todas customizadas):');
    debugPrint('   Transaction ID: $habitTxId');
    
    final habitUpdate = await _txController.executeTransaction(
      serverId: serverId,
      userId: userId,
      transactionId: habitTxId,
      actionType: 'habit_all_custom',
      actionData: {
        'date': date,
        'bonus': 2,
      },
      operation: () async {
        final freshUser = await _dbService.getUserFromServer(
          serverId,
          userId,
          forceRefresh: true,
        );
        
        final currentHabit = freshUser?.stats.attributes.habit ?? 
                            currentUser.stats.attributes.habit;
        
        final newHabit = (currentHabit + 2).clamp(0, AppConstants.maxAttributePoints);
        
        if (newHabit != currentHabit) {
          debugPrint('   ✅ Hábito: $currentHabit → $newHabit (+2)');
          return {'habit': newHabit};
        }
        return <String, int>{};
      },
    );
    
    if (habitUpdate.isNotEmpty) {
      await _updateAttributesSafely(serverId, userId, currentUser, habitUpdate);
    }
    
    return habitUpdate['habit'] ?? 0;
  }
  
  // =========================================================================
  // EVOLUÇÃO - Wrapper unificado para level/rank up
  // =========================================================================
  
  /// Wrapper unificado para bônus de evolução em level/rank up.
  ///
  /// Delega para [updateEvolutionOnLevelUp] (+1) e/ou
  /// [updateEvolutionOnRankUp] (+5) conforme aplicável.
  Future<Map<String, int>> updateAttributesOnLevelOrRankUp({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required bool leveledUp,
    required bool rankedUp,
    required int newLevel,
    required String newRank,
  }) async {
    final changes = <String, int>{};
    
    if (leveledUp) {
      final evolutionChange = await updateEvolutionOnLevelUp(
        serverId: serverId,
        userId: userId,
        currentUser: currentUser,
        oldLevel: newLevel - 1,
        newLevel: newLevel,
      );
      
      if (evolutionChange.isNotEmpty) {
        changes.addAll(evolutionChange);
      }
    }
    
    if (rankedUp) {
      final oldRank = _getPreviousRank(newRank);
      final evolutionChange = await updateEvolutionOnRankUp(
        serverId: serverId,
        userId: userId,
        currentUser: currentUser,
        oldRank: oldRank,
        newRank: newRank,
      );
      
      if (evolutionChange.isNotEmpty) {
        changes.addAll(evolutionChange);
      }
    }
    
    return changes;
  }
  
  // =========================================================================
  // EVOLUÇÃO - +1 ao subir de level
  // =========================================================================
  
  /// Incrementa +1 em Evolução ao subir de level.
  Future<Map<String, int>> updateEvolutionOnLevelUp({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required int oldLevel,
    required int newLevel,
  }) async {
    final txId = 'levelup_evolution_${userId}_$newLevel';
    
    debugPrint('⚡ Level Up - Bônus de Evolução:');
    debugPrint('   Level: $oldLevel → $newLevel');
    debugPrint('   Evolução atual: ${currentUser.stats.attributes.evolution}');
    
    final evolutionUpdate = await _txController.executeTransaction(
      serverId: serverId,
      userId: userId,
      transactionId: txId,
      actionType: 'evolution_levelup',
      actionData: {
        'oldLevel': oldLevel,
        'newLevel': newLevel,
      },
      operation: () async {
        final currentEvolution = currentUser.stats.attributes.evolution;
        final newEvolution = (currentEvolution + 1).clamp(0, AppConstants.maxAttributePoints);
        
        if (newEvolution != currentEvolution) {
          debugPrint('   ✅ Evolução: $currentEvolution → $newEvolution (+1)');
          return {'evolution': newEvolution};
        }
        return <String, int>{};
      },
    );
    
    if (evolutionUpdate.isNotEmpty) {
      await _updateAttributesSafely(serverId, userId, currentUser, evolutionUpdate);
      debugPrint('   ✅ Bônus de evolução (level) concedido!');
    }
    
    return evolutionUpdate;
  }
  
  // =========================================================================
  // EVOLUÇÃO - +5 ao subir de rank
  // =========================================================================
  
  /// Incrementa +5 em Evolução ao subir de rank.
  Future<Map<String, int>> updateEvolutionOnRankUp({
    required String serverId,
    required String userId,
    required UserModel currentUser,
    required String oldRank,
    required String newRank,
  }) async {
    final txId = 'rankup_evolution_${userId}_$newRank';
    
    debugPrint('⚡ Rank Up - Bônus de Evolução:');
    debugPrint('   Rank: $oldRank → $newRank');
    debugPrint('   Evolução atual: ${currentUser.stats.attributes.evolution}');
    
    final evolutionUpdate = await _txController.executeTransaction(
      serverId: serverId,
      userId: userId,
      transactionId: txId,
      actionType: 'evolution_rankup',
      actionData: {
        'oldRank': oldRank,
        'newRank': newRank,
      },
      operation: () async {
        final currentEvolution = currentUser.stats.attributes.evolution;
        final newEvolution = (currentEvolution + 5).clamp(0, AppConstants.maxAttributePoints);
        
        if (newEvolution != currentEvolution) {
          debugPrint('   ✅ Evolução: $currentEvolution → $newEvolution (+5)');
          return {'evolution': newEvolution};
        }
        return <String, int>{};
      },
    );
    
    if (evolutionUpdate.isNotEmpty) {
      await _updateAttributesSafely(serverId, userId, currentUser, evolutionUpdate);
      debugPrint('   ✅ Bônus de evolução (rank) concedido!');
    }
    
    return evolutionUpdate;
  }
  
  // =========================================================================
  // HELPERS - DETECÇÃO DE TIPO DE MISSÃO
  // =========================================================================
  
  /// Verifica se o nome da missão indica conteúdo de estudo.
  ///
  /// Usa busca por keywords em português cobrindo áreas acadêmicas,
  /// programação, idiomas e preparatórios.
  bool _isStudyRelatedMission(String missionName) {
    final lowerName = missionName.toLowerCase();
    
    final studyKeywords = [
      'estudo', 'estudar', 'inglês', 'ingles', 'espanhol', 'francês', 'frances',
      'idioma', 'língua', 'lingua', 'leitura', 'ler', 'livro', 'curso', 'aula',
      'aprender', 'aprendizado', 'prova', 'dever', 'tarefa', 'homework', 
      'revisar', 'revisão', 'revisao', 'pesquisa', 'pesquisar', 'resumo',
      'resumir', 'fichamento', 'artigo', 'tcc', 'monografia', 'dissertação',
      'dissertacao', 'tese', 'seminário', 'seminario', 'apresentação',
      'apresentacao', 'slide', 'trabalho', 'projeto', 'redação', 'redacao',
      'gramática', 'gramatica', 'matemática', 'matematica', 'física', 'fisica',
      'química', 'quimica', 'biologia', 'história', 'historia', 'geografia',
      'filosofia', 'sociologia', 'programação', 'programacao', 'código',
      'codigo', 'algoritmo', 'python', 'java', 'javascript', 'html', 'css',
      'react', 'desenvolvimento', 'dev', 'coding', 'faculdade', 'escola',
      'colégio', 'colegio', 'universidade', 'vestibular', 'enem', 'concurso',
      'teste', 'exame', 'avaliação', 'avaliacao',
    ];
    
    return studyKeywords.any((keyword) => lowerName.contains(keyword));
  }
  
  /// Verifica se o nome da missão indica atividade física.
  ///
  /// Usa busca por keywords em português cobrindo exercícios,
  /// esportes, musculação e atividades ao ar livre.
  bool _isFitnessRelatedMission(String missionName) {
    final lowerName = missionName.toLowerCase();
    
    final fitnessKeywords = [
      'treino', 'treinar', 'exercício', 'exercicio', 'força', 'gym', 'academia',
      'corrida', 'correr', 'caminhada', 'caminhar', 'musculação', 'musculacao',
      'flexão', 'flexao', 'abdominais', 'abdominal', 'agachamento', 'cardio',
      'aeróbico', 'aerobico', 'yoga', 'pilates', 'crossfit', 'funcional',
      'peso', 'halteres', 'barra', 'supino', 'leg press', 'esteira', 'bike',
      'bicicleta', 'natação', 'natacao', 'nadar', 'alongamento', 'alongar',
      'aquecimento', 'polichinelo', 'burpee', 'prancha', 'remada',
      'levantamento', 'pull', 'push', 'leg', 'arm', 'chest', 'back',
      'shoulder', 'biceps', 'triceps', 'glúteo', 'gluteo', 'perna', 'braço',
      'braco', 'peito', 'costas', 'ombro', 'abdômen', 'abdomen', 'sport',
      'esporte', 'atletismo', 'boxe', 'luta', 'artes marciais', 'futebol',
      'basquete', 'volei', 'tênis', 'tenis',
    ];
    
    return fitnessKeywords.any((keyword) => lowerName.contains(keyword));
  }
  
  /// Retorna o rank imediatamente anterior ao [currentRank].
  ///
  /// Retorna 'E' se já estiver no rank mínimo.
  String _getPreviousRank(String currentRank) {
    const ranks = ['E', 'D', 'C', 'B', 'A', 'S', 'SS', 'SSS'];
    final index = ranks.indexOf(currentRank);
    return index > 0 ? ranks[index - 1] : 'E';
  }
  
  // =========================================================================
  // HELPERS - SALVAMENTO SEGURO
  // =========================================================================
  
  /// Salva atributos no Firebase preservando valores não alterados.
  ///
  /// Constrói um [UserAttributes] combinando valores atuais com as
  /// [updates], e persiste via [DatabaseService.updateUser].
  Future<void> _updateAttributesSafely(
    String serverId,
    String userId,
    UserModel currentUser,
    Map<String, int> updates,
  ) async {
    try {
      // Criar novo objeto de atributos com valores atualizados
      final currentAttrs = currentUser.stats.attributes;
      
      final updatedAttrs = UserAttributes(
        study: updates['study'] ?? currentAttrs.study,
        discipline: updates['discipline'] ?? currentAttrs.discipline,
        evolution: updates['evolution'] ?? currentAttrs.evolution,
        shape: updates['shape'] ?? currentAttrs.shape,
        habit: updates['habit'] ?? currentAttrs.habit,
      );
      
      // Criar novo stats preservando outros campos
      final updatedStats = currentUser.stats.copyWith(
        attributes: updatedAttrs,
      );
      
      // Atualizar no Firebase
      await _dbService.updateUser(
        serverId,
        userId,
        {
          'stats': updatedStats.toMap(),
        },
      );
      
      debugPrint('✅ _updateAttributesSafely: Atributos salvos');
      
    } catch (e, stack) {
      debugPrint('❌ Erro ao salvar atributos: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }
}
