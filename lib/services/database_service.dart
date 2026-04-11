import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../models/server_model.dart';
import '../models/mission_model.dart';
import 'package:monarch/core/constants/app_constants.dart';
import 'cache_service.dart';
import 'dart:async';

/// Serviço central de acesso ao Firebase Realtime Database.
///
/// Responsável por todas as operações de leitura e escrita no banco:
/// - CRUD de usuários e missões
/// - Streams em tempo real para sincronização
/// - Batch atômico para atualizações consistentes
/// - Templates de missões recorrentes e propagação diária
/// - Ranking do servidor com cache
/// - Gerenciamento de servidores mensais
///
/// Fornece também a fonte única de data ([now], [todayKey]) para
/// permitir simulação de datas em desenvolvimento via [testDate].
class DatabaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final _cache = CacheService.instance;

  // =========================================================================
  // 📅 FONTE ÚNICA DE DATA — usada em TODO o app
  // =========================================================================

  /// Defina para simular uma data. null = data real.
  static DateTime? testDate;

  /// Use DatabaseService.now em qualquer lugar que precisar da data atual.
  static DateTime get now => testDate ?? DateTime.now();

  /// Data de hoje no formato yyyy-MM-dd (respeita testDate).
  static String get todayKey {
    final d = now;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // =========================================================================
  // STREAM CONTROLLERS
  // =========================================================================

  final Map<String, StreamController<UserModel?>> _userStreamControllers = {};
  final Map<String, StreamController<Map<String, dynamic>?>>
      _missionsStreamControllers = {};

  // =========================================================================
  // REFERÊNCIAS DO BANCO
  // =========================================================================

  DatabaseReference get _serversRef => _database.ref('servers');
  DatabaseReference get _userServersRef => _database.ref('userServers');

  DatabaseReference _serverDataRef(String serverId) =>
      _database.ref('serverData/$serverId');

  DatabaseReference _serverUsersRef(String serverId) =>
      _serverDataRef(serverId).child('users');

  DatabaseReference _serverUserRef(String serverId, String userId) =>
      _serverUsersRef(serverId).child(userId);

  DatabaseReference _dailyMissionsRef(
          String serverId, String userId, String date) =>
      _serverDataRef(serverId).child('dailyMissions').child(userId).child(date);

  DatabaseReference _fixedTemplatesRef(String serverId, String userId) =>
      _serverDataRef(serverId).child('fixedMissionTemplates').child(userId);

  // =========================================================================
  // 🔥 STREAMS EM TEMPO REAL
  // =========================================================================

  /// Retorna um stream em tempo real do [UserModel] para o usuário especificado.
  ///
  /// Escuta mudanças no nó do Firebase e emite atualizações automáticas.
  /// O stream é compartilhado (broadcast) e se auto-limpa ao cancelar.
  Stream<UserModel?> getUserStream(String serverId, String userId) {
    final key = '${serverId}_$userId';
    if (_userStreamControllers.containsKey(key)) {
      return _userStreamControllers[key]!.stream;
    }

    final controller = StreamController<UserModel?>.broadcast(
      onCancel: () => _userStreamControllers.remove(key),
    );
    _userStreamControllers[key] = controller;

    _serverUserRef(serverId, userId).onValue.listen(
      (event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          controller.add(null);
          return;
        }
        try {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          controller.add(UserModel.fromMap(userId, data));
        } catch (e) {
          controller.addError(e);
        }
      },
      onError: controller.addError,
    );
    return controller.stream;
  }

  /// Retorna um stream em tempo real das missões diárias do usuário.
  ///
  /// Emite o Map bruto das missões (fixed + custom) para uma data específica.
  Stream<Map<String, dynamic>?> getDailyMissionsStream(
    String serverId,
    String userId,
    String date,
  ) {
    final key = '${serverId}_${userId}_$date';
    if (_missionsStreamControllers.containsKey(key)) {
      return _missionsStreamControllers[key]!.stream;
    }

    final controller = StreamController<Map<String, dynamic>?>.broadcast(
      onCancel: () => _missionsStreamControllers.remove(key),
    );
    _missionsStreamControllers[key] = controller;

    _dailyMissionsRef(serverId, userId, date).onValue.listen(
      (event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          controller.add(null);
          return;
        }
        try {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          controller.add(data);
        } catch (e) {
          controller.addError(e);
        }
      },
      onError: controller.addError,
    );
    return controller.stream;
  }

  // =========================================================================
  // 🔥 BATCH ATÔMICO
  // =========================================================================

  /// Executa atualização atômica de missão + usuário em uma única operação.
  ///
  /// Garante consistência usando `_database.ref().update()` com todos os
  /// campos em um único Map. O campo `totalMissionsCompleted` é incrementado
  /// via [ServerValue.increment] para evitar race conditions.
  Future<void> updateMissionAndUserBatch({
    required String serverId,
    required String userId,
    required String date,
    required String missionId,
    required String missionType,
    required Map<String, dynamic> missionData,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final updates = <String, dynamic>{};

      final missionPath =
          'serverData/$serverId/dailyMissions/$userId/$date/$missionType/$missionId';
      missionData.forEach((key, value) {
        updates['$missionPath/$key'] = value;
      });

      final userPath = 'serverData/$serverId/users/$userId';
      userData.forEach((key, value) {
        if (key == 'stats') {
          final stats = value as Map<String, dynamic>;
          stats.forEach((statKey, statValue) {
            if (statKey == 'totalMissionsCompleted') {
              updates['$userPath/stats/$statKey'] = ServerValue.increment(1);
            } else {
              updates['$userPath/stats/$statKey'] = statValue;
            }
          });
        } else {
          updates['$userPath/$key'] = value;
        }
      });

      await _database.ref().update(updates);
      AppConstants.debugLog(
          '✅ Batch update: 1 write para ${updates.length} campos');
    } catch (e) {
      AppConstants.debugLog('❌ Erro no batch update: $e');
      throw Exception('Erro ao atualizar dados: $e');
    }
  }

  // =========================================================================
  // ✅ TEMPLATES DE MISSÕES FIXAS RECORRENTES
  // =========================================================================

  /// Salva um template de missão fixa recorrente no Firebase.
  ///
  /// Templates definem missões que se repetem automaticamente conforme
  /// a [recurrence] configurada. Retorna o ID gerado para o template.
  Future<String> saveFixedMissionTemplate({
    required String serverId,
    required String userId,
    required String missionName,
    required int xpBase,
    required MissionRecurrence recurrence,
  }) async {
    try {
      final missionId = 'fixed_${DatabaseService.now.millisecondsSinceEpoch}';
      final templateData = {
        'name': missionName,
        'xp_base': xpBase,
        'recurrence': recurrence.toMap(),
        'createdAt': DatabaseService.now.millisecondsSinceEpoch,
        'active': true,
      };

      await _fixedTemplatesRef(serverId, userId)
          .child(missionId)
          .set(templateData);
      AppConstants.debugLog('✅ Template salvo: $missionName ($missionId)');
      return missionId;
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao salvar template: $e');
      throw Exception('Erro ao salvar template: $e');
    }
  }

  /// Busca todos os templates de missões fixas ativos do usuário.
  Future<List<Map<String, dynamic>>> getFixedMissionTemplates({
    required String serverId,
    required String userId,
  }) async {
    try {
      final snapshot = await _fixedTemplatesRef(serverId, userId).get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final templatesMap = Map<String, dynamic>.from(snapshot.value as Map);
      final templates = <Map<String, dynamic>>[];

      templatesMap.forEach((id, value) {
        if (value is Map) {
          final data = Map<String, dynamic>.from(value);
          if (data['active'] == true) {
            templates.add({'id': id, ...data});
          }
        }
      });

      AppConstants.debugLog('📋 ${templates.length} templates encontrados');
      return templates;
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao buscar templates: $e');
      return [];
    }
  }

  /// Desativa um template de missão fixa (soft delete).
  Future<void> deactivateFixedMissionTemplate({
    required String serverId,
    required String userId,
    required String missionId,
  }) async {
    try {
      await _fixedTemplatesRef(serverId, userId)
          .child(missionId)
          .update({'active': false});
      AppConstants.debugLog('🗑️ Template desativado: $missionId');
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao desativar template: $e');
      throw Exception('Erro ao desativar template: $e');
    }
  }

  /// Propaga missões recorrentes para [date].
  ///
  /// Para cada template ativo:
  ///   1. Verifica se [date] está dentro do período (startDate ≤ date ≤ endDate)
  ///   2. Verifica se é um dos dias da semana configurados
  ///   3. Se ainda não existe neste dia → cria com completed: false (fresh)
  ///
  /// Isso garante que uma missão concluída ontem reaparece hoje do zero.
  Future<int> propagateRecurringMissionsToDay({
    required String serverId,
    required String userId,
    required String date,
    required int userLevel,
  }) async {
    try {
      AppConstants.debugLog(
          '🔄 Propagando missões recorrentes para $date (level $userLevel)...');

      final templates = await getFixedMissionTemplates(
        serverId: serverId,
        userId: userId,
      );

      if (templates.isEmpty) {
        AppConstants.debugLog('   Nenhum template encontrado.');
        return 0;
      }

      // IDs que já existem neste dia (não duplicar)
      final existingSnapshot = await _dailyMissionsRef(serverId, userId, date)
          .child('fixed')
          .get();

      final existingIds = <String>{};
      if (existingSnapshot.exists && existingSnapshot.value != null) {
        final existing =
            Map<String, dynamic>.from(existingSnapshot.value as Map);
        existingIds.addAll(existing.keys);
      }

      final targetDate = DateTime.parse(date);
      final updates = <String, dynamic>{};
      int propagated = 0;

      for (final template in templates) {
        final missionId = template['id'] as String;

        // Já existe neste dia? Pula (pode estar completa ou não — não interessa)
        if (existingIds.contains(missionId)) {
          AppConstants.debugLog('   ↩️ Já existe neste dia: $missionId');
          continue;
        }

        MissionRecurrence recurrence;
        try {
          recurrence = MissionRecurrence.fromMap(
            Map<String, dynamic>.from(template['recurrence'] as Map),
          );
        } catch (e) {
          AppConstants.debugLog(
              '   ⚠️ Recorrência inválida em $missionId: $e');
          continue;
        }

        // Verifica período (startDate ≤ targetDate ≤ endDate) + dia da semana
        if (!recurrence.isActiveOn(targetDate)) {
          AppConstants.debugLog(
              '   ⏭️ Inativo neste dia/período: ${template['name']}');
          continue;
        }

        final xp = _calculateFixedMissionXp(userLevel);

        final missionPath =
            'serverData/$serverId/dailyMissions/$userId/$date/fixed/$missionId';
        updates[missionPath] = {
          'name': template['name'],
          'xp': xp,
          'completed': false,
          'recurrence': template['recurrence'],
        };

        propagated++;
        AppConstants.debugLog(
            '   ✅ Propagando: ${template['name']} (+$xp XP)');
      }

      if (updates.isNotEmpty) {
        await _database.ref().update(updates);
        AppConstants.debugLog(
            '✅ $propagated missão(ões) propagada(s) para $date');
      } else {
        AppConstants.debugLog('   Nenhuma missão nova para propagar em $date.');
      }

      return propagated;
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao propagar missões: $e');
      return 0;
    }
  }

  int _calculateFixedMissionXp(int userLevel) => 50 + (userLevel * 10);

  // =========================================================================
  // OPERAÇÕES PRINCIPAIS
  // =========================================================================

  /// Busca os dados do usuário diretamente do Firebase.
  ///
  /// Retorna `null` se o usuário não existir no servidor.
  Future<UserModel?> getUserFromServer(
    String serverId,
    String userId, {
    bool forceRefresh = false,
  }) async {
    try {
      final snapshot = await _serverUserRef(serverId, userId).get();
      if (!snapshot.exists || snapshot.value == null) return null;
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return UserModel.fromMap(userId, data);
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao buscar usuário: $e');
      return null;
    }
  }

  /// Busca o ID do servidor ao qual o usuário pertence.
  Future<String?> getUserServer(String userId,
      {bool forceRefresh = false}) async {
    try {
      final snapshot = await _userServersRef.child(userId).get();
      return snapshot.exists ? snapshot.value as String : null;
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao buscar servidor: $e');
      return null;
    }
  }

  /// Busca as missões diárias (fixed + custom) para uma data específica.
  Future<Map<String, dynamic>?> getDailyMissions(
    String serverId,
    String userId,
    String date,
  ) async {
    try {
      final snapshot =
          await _dailyMissionsRef(serverId, userId, date).get();
      if (!snapshot.exists || snapshot.value == null) return null;
      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao buscar missões: $e');
      return null;
    }
  }

  /// Atualiza campos do usuário no Firebase.
  ///
  /// Aplana campos aninhados (stats, attributes) para atualização parcial
  /// sem sobrescrever dados existentes. Atualiza [lastSeen] automaticamente.
  Future<void> updateUser(
    String serverId,
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final userPath = 'serverData/$serverId/users/$userId';
      final flatUpdates = <String, dynamic>{};

      updates.forEach((key, value) {
        if (key == 'stats' && value is Map) {
          (value as Map).forEach((statKey, statValue) {
            if (statKey == 'totalMissionsCompleted') {
              // ignorado — batch usa ServerValue.increment
            } else if (statKey == 'attributes' && statValue is Map) {
              (statValue as Map).forEach((attrKey, attrValue) {
                flatUpdates['$userPath/stats/attributes/$attrKey'] = attrValue;
              });
            } else {
              flatUpdates['$userPath/stats/$statKey'] = statValue;
            }
          });
        } else {
          flatUpdates['$userPath/$key'] = value;
        }
      });

      flatUpdates['$userPath/lastSeen'] = DatabaseService.now.toIso8601String();
      await _database.ref().update(flatUpdates);
    } catch (e) {
      throw Exception('Erro ao atualizar usuário: $e');
    }
  }

  /// Atualiza campos específicos de uma missão diária.
  Future<void> updateDailyMission({
    required String serverId,
    required String userId,
    required String date,
    required String missionType,
    required String missionId,
    required Map<String, dynamic> missionData,
  }) async {
    try {
      await _dailyMissionsRef(serverId, userId, date)
          .child(missionType)
          .child(missionId)
          .update(missionData);
    } catch (e) {
      throw Exception('Erro ao atualizar missão: $e');
    }
  }

  /// Adiciona uma nova missão (fixa ou customizada) ao dia especificado.
  ///
  /// Retorna o ID gerado para a missão.
  Future<String> addCustomMission({
    required String serverId,
    required String userId,
    required String date,
    required String missionName,
    required int xp,
    String missionType = 'custom',
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final prefix = missionType == 'fixed' ? 'fixed' : 'custom';
      final missionId =
          '${prefix}_${DatabaseService.now.millisecondsSinceEpoch}';

      final data = <String, dynamic>{
        'name': missionName,
        'xp': xp,
        'completed': false,
        ...?extraData,
      };

      await _dailyMissionsRef(serverId, userId, date)
          .child(missionType)
          .child(missionId)
          .set(data);

      AppConstants.debugLog(
          '✅ Missão $missionType adicionada: $missionName ($missionId)');
      return missionId;
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao adicionar missão: $e');
      throw Exception('Erro ao adicionar missão: $e');
    }
  }

  /// Remove uma missão do dia especificado.
  Future<void> removeCustomMission({
    required String serverId,
    required String userId,
    required String date,
    required String missionId,
    required String missionType,
  }) async {
    try {
      await _dailyMissionsRef(serverId, userId, date)
          .child(missionType)
          .child(missionId)
          .remove();
      AppConstants.debugLog('✅ Missão removida: $missionId');
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao remover missão: $e');
      throw Exception('Erro ao remover missão: $e');
    }
  }

  /// Alias para [removeCustomMission] (compat. retroativa).
  Future<void> deleteDailyMission({
    required String serverId,
    required String userId,
    required String date,
    required String missionType,
    required String missionId,
  }) async {
    return removeCustomMission(
      serverId: serverId,
      userId: userId,
      date: date,
      missionId: missionId,
      missionType: missionType,
    );
  }

  /// Edita o nome e XP de uma missão existente.
  Future<void> editMission({
    required String serverId,
    required String userId,
    required String date,
    required String missionId,
    required String missionType,
    required String newName,
    required int newXp,
  }) async {
    try {
      await _dailyMissionsRef(serverId, userId, date)
          .child(missionType)
          .child(missionId)
          .update({'name': newName, 'xp': newXp});
      AppConstants.debugLog('✅ Missão editada: $missionId');
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao editar missão: $e');
      throw Exception('Erro ao editar missão: $e');
    }
  }

  /// Fecha todos os stream controllers ativos e libera recursos.
  void dispose() {
    for (final controller in _userStreamControllers.values) {
      controller.close();
    }
    for (final controller in _missionsStreamControllers.values) {
      controller.close();
    }
    _userStreamControllers.clear();
    _missionsStreamControllers.clear();
  }

  // =========================================================================
  // SERVIDORES E RANKING
  // =========================================================================

  /// Cria um novo usuário dentro de um servidor.
  ///
  /// Registra os dados do usuário, vincula ao servidor via `userServers`
  /// e incrementa atomicamente o contador de jogadores do servidor.
  Future<void> createUserInServer({
    required String userId,
    required String userName,
    required String userEmail,
    required String serverId,
    bool termsAccepted = false,
  }) async {
    try {
      final newUser = UserModel.newUser(
        id: userId,
        name: userName,
        email: userEmail,
        terms: termsAccepted,
      );

      final updates = <String, dynamic>{};
      final userPath = 'serverData/$serverId/users/$userId';

      newUser.toMap().forEach((key, value) {
        if (key == 'stats' && value is Map) {
          (value as Map<String, dynamic>).forEach((statKey, statValue) {
            if (statKey == 'attributes' && statValue is Map) {
              (statValue as Map<String, dynamic>).forEach((attrKey, attrValue) {
                updates['$userPath/stats/attributes/$attrKey'] = attrValue;
              });
            } else {
              updates['$userPath/stats/$statKey'] = statValue;
            }
          });
        } else {
          updates['$userPath/$key'] = value;
        }
      });

      updates['userServers/$userId'] = serverId;

      await _database.ref().update(updates);

      final counterRef = _serversRef.child(serverId).child('playerCount');
      await counterRef.runTransaction((currentValue) {
        final current = currentValue as int? ?? 0;
        return Transaction.success(current + 1);
      });
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao criar usuário no servidor: $e');
      if (e is FirebaseException) {
        AppConstants.debugLog('   Firebase code: ${e.code}');
      }
      throw Exception('Erro ao criar usuário: $e');
    }
  }

  /// Retorna a lista de servidores ativos, com cache de longa duração.
  Future<List<ServerModel>> getActiveServers(
      {bool forceRefresh = false}) async {
    try {
      final result = await _cache.getCached<List<ServerModel>>(
        key: 'active_servers',
        cacheDuration: CacheService.CACHE_LONG,
        forceRefresh: forceRefresh,
        fetchFunction: () => _fetchActiveServers(),
      );
      return result ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Busca servidores ativos diretamente do Firebase (sem cache).
  Future<List<ServerModel>> _fetchActiveServers() async {
    final snapshot = await _serversRef.get();
    if (!snapshot.exists || snapshot.value == null) return [];

    final servers = <ServerModel>[];
    final serversMap = Map<String, dynamic>.from(snapshot.value as Map);

    for (var entry in serversMap.entries) {
      try {
        if (entry.value is Map) {
          final serverData = Map<String, dynamic>.from(entry.value);
          if (serverData['status'] == 'active') {
            servers.add(ServerModel.fromMap(entry.key, serverData));
          }
        }
      } catch (e) {
        AppConstants.debugLog('❌ Erro ao processar servidor: $e');
      }
    }

    servers.sort((a, b) => b.openDate.compareTo(a.openDate));
    return servers;
  }

  /// Garante que existe um servidor para o mês atual.
  ///
  /// Se não existir, cria automaticamente com capacidade para 1000 jogadores.
  Future<void> ensureCurrentMonthServer() async {
    try {
      final now = DatabaseService.now;
      final serverId =
          'server_${now.year}_${now.month.toString().padLeft(2, '0')}';

      final snapshot = await _serversRef.child(serverId).get();
      if (!snapshot.exists) {
        await _serversRef.child(serverId).set({
          'name': 'Servidor ${_getMonthName(now.month)} ${now.year}',
          'maxPlayers': 1000,
          'playerCount': 0,
          'status': 'active',
          'openDate': DateTime(now.year, now.month, 1).toIso8601String(),
        });
      }
    } catch (e) {
      throw Exception('Erro ao garantir servidor: $e');
    }
  }

  /// Retorna a posição do usuário no ranking do servidor.
  ///
  /// Conta quantos usuários têm mais XP e retorna posição (1-based).
  Future<int> getUserRankingPosition({
    required String serverId,
    required String userId,
  }) async {
    try {
      final userSnapshot =
          await _serverUserRef(serverId, userId).child('totalXp').get();
      if (!userSnapshot.exists) return 0;

      final userXp = userSnapshot.value as int;
      final query = _serverUsersRef(serverId)
          .orderByChild('totalXp')
          .startAt(userXp + 1);

      final snapshot = await query.get();
      if (!snapshot.exists || snapshot.value == null) return 1;

      final usersAhead = Map<String, dynamic>.from(snapshot.value as Map);
      return usersAhead.length + 1;
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao buscar posição: $e');
      return 0;
    }
  }

  /// Retorna página do ranking do servidor, ordenado por XP decrescente.
  ///
  /// Utiliza cache de curta duração para evitar queries excessivas.
  Future<List<UserModel>> getServerRanking(
    String serverId, {
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'ranking_${serverId}_p${page}_s$pageSize';
    return await _cache.getCached<List<UserModel>>(
          key: cacheKey,
          cacheDuration: CacheService.CACHE_SHORT,
          forceRefresh: forceRefresh,
          fetchFunction: () => _fetchRankingPage(serverId, page, pageSize),
        ) ??
        [];
  }

  /// Busca uma página do ranking diretamente do Firebase (sem cache).
  Future<List<UserModel>> _fetchRankingPage(
    String serverId,
    int page,
    int pageSize,
  ) async {
    try {
      final snapshot = await _serverUsersRef(serverId)
          .orderByChild('totalXp')
          .limitToLast(page * pageSize)
          .get();

      if (!snapshot.exists || snapshot.value == null) return [];

      final usersMap = Map<String, dynamic>.from(snapshot.value as Map);
      final users = <UserModel>[];

      usersMap.forEach((key, value) {
        try {
          if (value is Map) {
            users.add(
                UserModel.fromMap(key, Map<String, dynamic>.from(value)));
          }
        } catch (e) {
          AppConstants.debugLog('❌ Erro ao processar usuário no ranking: $e');
        }
      });

      users.sort((a, b) => b.totalXp.compareTo(a.totalXp));

      final startIndex = (page - 1) * pageSize;
      final endIndex = page * pageSize;
      return users.sublist(
        startIndex,
        endIndex > users.length ? users.length : endIndex,
      );
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao buscar ranking: $e');
      return [];
    }
  }

  /// Converte número do mês (1-12) para nome em português.
  String _getMonthName(int month) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return months[month - 1];
  }

  /// Cria a estrutura inicial de missões diárias para um usuário.
  ///
  /// Popula as missões fixas padrão a partir de [AppConstants.fixedMissionCategories].
  Future<void> createDailyMissions(
    String serverId,
    String userId,
    String date, {
    int? userLevel,
  }) async {
    try {
      final missions = <String, dynamic>{
        'fixed': {},
        'custom': {},
      };
      for (var category in AppConstants.fixedMissionCategories) {
        missions['fixed'][category] = {
          'name': AppConstants.fixedMissionNames[category] ?? category,
          'xp': 50,
          'completed': false,
        };
      }
      await _dailyMissionsRef(serverId, userId, date).set(missions);
      AppConstants.debugLog('✅ Missões diárias criadas');
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao criar missões: $e');
      throw Exception('Erro ao criar missões: $e');
    }
  }
}
