import 'package:flutter/foundation.dart';
import 'package:monarch/services/attribute_manager_service.dart';
import 'package:monarch/services/mission_service.dart';
import 'package:intl/intl.dart';
import 'package:monarch/services/streak_service.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import 'package:monarch/core/constants/app_constants.dart';
import 'dart:async';


/// Provider central de estado do usuário logado.
///
/// Gerencia o ciclo de vida completo do usuário autenticado:
/// - **Carregamento**: busca servidor e configura stream real-time
/// - **Sincronização**: escuta mudanças no Firebase via stream
/// - **Streak**: verifica e reseta streaks no login
/// - **Atributos**: atualiza atributos individuais
/// - **Cache**: invalida caches de ranking e usuário
/// - **Progresso**: calcula XP para próximo nível e barra de progresso
///
/// Notifica listeners ([ChangeNotifier]) quando dados mudam.
class UserProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  final _cache = CacheService.instance;
  final AttributesManagerService _attributesManager =
      AttributesManagerService();

  UserModel? _currentUser;
  String? _currentServerId;
  bool _isLoading = false;
  String? _error;
  bool _isInitialLoad = true;

  StreamSubscription<UserModel?>? _userStreamSubscription;

  // ================= GETTERS =================

  UserModel? get currentUser => _currentUser;
  UserModel? get user => _currentUser;
  String? get currentServerId => _currentServerId;
  String? get userServer => _currentServerId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUser => _currentUser != null;

  // ================= CORE =================

  /// Carrega o usuário atual do Firebase e configura stream real-time.
  ///
  /// Busca o servidor do usuário, configura listener de mudanças,
  /// e verifica se o streak precisa ser resetado.
  Future<void> loadUser({bool forceRefresh = false}) async {
    _isLoading = true;

    if (!_isInitialLoad) {
      notifyListeners();
    }

    _setError(null);

    try {
      final userId = _authService.currentUserId;

      if (userId == null) {
        _isLoading = false;
        _isInitialLoad = false;
        notifyListeners();
        return;
      }

      final serverId = await _dbService.getUserServer(
        userId,
        forceRefresh: forceRefresh,
      );

      if (serverId == null) {
        _currentUser = null;
        _currentServerId = null;
        _isLoading = false;
        _isInitialLoad = false;
        notifyListeners();
        return;
      }

      _currentServerId = serverId;

      await _setupUserListenerAndWait(serverId, userId);

      _isLoading = false;
      _isInitialLoad = false;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _isLoading = false;
      _isInitialLoad = false;
      AppConstants.debugLog('❌ Erro ao carregar usuário: $e');
      notifyListeners();
    }
  }

  /// Configura stream de dados do usuário e aguarda primeiro update.
  ///
  /// Timeout de 10 segundos para o primeiro update do stream.
  /// Após receber dados, verifica reset de bestStreak.
  Future<void> _setupUserListenerAndWait(String serverId, String userId) async {
    await _userStreamSubscription?.cancel();

    AppConstants.debugLog('📡 Configurando stream para $userId...');

    final firstUpdateCompleter = Completer<void>();
    bool receivedFirstUpdate = false;

    _userStreamSubscription = _dbService.getUserStream(serverId, userId).listen(
      (user) {
        if (user != null) {
          final hasChanged = _currentUser == null ||
              user.totalXp != _currentUser!.totalXp ||
              user.level != _currentUser!.level ||
              user.rank != _currentUser!.rank ||
              user.stats.attributes.totalPoints !=
                  _currentUser!.stats.attributes.totalPoints;

          if (hasChanged) {
            AppConstants.debugLog('📊 Stream update detectado!');
            AppConstants.debugLog(
                '   XP: ${_currentUser?.totalXp ?? 0} → ${user.totalXp}');
            AppConstants.debugLog(
                '   Level: ${_currentUser?.level ?? 0} → ${user.level}');
            AppConstants.debugLog(
                '   Rank: ${_currentUser?.rank ?? 'E'} → ${user.rank}');
          }

          _currentUser = user;

          if (!receivedFirstUpdate) {
            receivedFirstUpdate = true;
            firstUpdateCompleter.complete();
            AppConstants.debugLog('✅ Primeiro update do stream recebido!');

            _checkAndResetBestStreak(serverId, userId, user);
          }

          if (hasChanged && !_isInitialLoad) {
            notifyListeners();
          }
        }
      },
      onError: (error) {
        AppConstants.debugLog('❌ Erro no stream user: $error');
        _setError(error.toString());

        if (!receivedFirstUpdate) {
          receivedFirstUpdate = true;
          firstUpdateCompleter.complete();
        }
      },
    );

    AppConstants.debugLog(
        '✅ Stream configurado! Aguardando primeiro update...');

    await firstUpdateCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        AppConstants.debugLog(
            '⏱️ Timeout aguardando primeiro update do stream');
      },
    );

    AppConstants.debugLog(
        '✅ loadUser() completo - currentUser: ${_currentUser?.name ?? "null"}');
  }

  /// Verifica se o streak precisa ser resetado (ex: dia perdido).
  Future<void> _checkAndResetBestStreak(
    String serverId,
    String userId,
    UserModel user,
  ) async {
    try {
      final streakService = StreakService.instance;
      AppConstants.debugLog('🔍 Verificando se precisa resetar bestStreak...');
      await streakService.checkAndResetStreakIfNeeded(
        serverId: serverId,
        userId: userId,
        currentUser: user,
      );
      AppConstants.debugLog('✅ Verificação de streak concluída');
    } catch (e) {
      AppConstants.debugLog('⚠️ Erro ao verificar streak (não crítico): $e');
    }
  }

  /// Cria um novo usuário em um servidor e recarrega os dados.
  Future<void> createUserInServer(
    String userId,
    String userName,
    String userEmail,
    String serverId,
    bool terms,
  ) async {
    _setLoading(true);

    try {
      await _dbService.createUserInServer(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        serverId: serverId,
        termsAccepted: terms,
        IsPremium: false,
      );

      await loadUser(forceRefresh: true);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza campos do usuário no Firebase (adiciona lastSeen automaticamente).
  Future<void> updateUser(Map<String, dynamic> updates) async {
    if (_currentUser == null || _currentServerId == null) return;

    updates['lastSeen'] = DateTime.now().toIso8601String();

    await _dbService.updateUser(
      _currentServerId!,
      _currentUser!.id,
      updates,
    );
  }

  /// Faz logout completo: cancela stream, limpa estado e desautentica.
  Future<void> logout() async {
    try {
      AppConstants.debugLog('🚪 Iniciando logout...');

      await _userStreamSubscription?.cancel();
      _userStreamSubscription = null;

      _currentUser = null;
      _currentServerId = null;
      _error = null;
      _isLoading = false;
      _isInitialLoad = true;

      await _authService.signOut();

      AppConstants.debugLog('✅ Logout concluído com sucesso');

      notifyListeners();
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao fazer logout: $e');
      rethrow;
    }
  }

  // ================= ATUALIZAÇÃO LOCAL =================

  /// Atualiza o modelo do usuário localmente sem persistir no Firebase.
  ///
  /// Notifica listeners apenas se houve mudança significativa
  /// (level, rank, XP ou atributos).
  void updateLocalUser(UserModel updatedUser) {
    AppConstants.debugLog('📝 UserProvider: Atualizando usuário local...');

    final hasChanged = _currentUser == null ||
        updatedUser.level != _currentUser!.level ||
        updatedUser.rank != _currentUser!.rank ||
        updatedUser.totalXp != _currentUser!.totalXp ||
        updatedUser.stats.attributes.totalPoints !=
            _currentUser!.stats.attributes.totalPoints;

    _currentUser = updatedUser;

    if (hasChanged) {
      AppConstants.debugLog('✅ Notificando listeners...');
      notifyListeners();
    }
  }

  /// Busca dados frescos do Firebase e atualiza o estado local.
  Future<void> refreshUserData({bool force = false}) async {
    if (_currentUser == null || _currentServerId == null) return;

    try {
      final user = await _dbService.getUserFromServer(
        _currentServerId!,
        _currentUser!.id,
        forceRefresh: force,
      );

      if (user != null) {
        final hasChanged = user.level != _currentUser!.level ||
            user.rank != _currentUser!.rank ||
            user.totalXp != _currentUser!.totalXp ||
            user.stats.attributes.totalPoints !=
                _currentUser!.stats.attributes.totalPoints;

        _currentUser = user;

        if (hasChanged) {
          notifyListeners();
        }
      }
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao atualizar usuário: $e');
    }
  }

  // ================= STREAK =================

  /// Atualiza o streak do usuário e verifica milestones (7, 15, 30 dias).
  Future<void> updateStreak(int newStreak) async {
    if (_currentUser == null || _currentServerId == null) return;

    final oldStreak = _currentUser!.stats.currentStreak;
    final oldBestStreak = _currentUser!.stats.bestStreak;
    final newBestStreak = newStreak > oldBestStreak ? newStreak : oldBestStreak;

    final newStats = _currentUser!.stats.copyWith(
      currentStreak: newStreak,
      bestStreak: newBestStreak,
    );

    await updateUser({'stats': newStats.toMap()});

    if (newStreak > oldStreak) {
      AppConstants.debugLog('🔥 Streak atualizado: $oldStreak → $newStreak');

      final milestones = [7, 15, 30];
      for (final milestone in milestones) {
        if (oldStreak < milestone && newStreak >= milestone) {
          AppConstants.debugLog('🎉 Milestone atingido: $milestone dias!');
        }
      }
    }
  }

  // ================= LOGIN DIÁRIO =================

  /// Registra login diário e verifica se o streak precisa ser resetado.
  Future<void> registerDailyLogin() async {
    if (_currentUser == null || _currentServerId == null) return;

    final StreakService _streakService = StreakService.instance;

    try {
      await _streakService.checkAndResetStreakIfNeeded(
        serverId: _currentServerId!,
        userId: _currentUser!.id,
        currentUser: _currentUser!,
      );

      AppConstants.debugLog('✅ Login diário registrado');
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao registrar login diário: $e');
    }
  }

  /// Calcula e retorna o streak atual do usuário.
  Future<StreakCalculationResult?> getCurrentStreak() async {
    final StreakService _streakService = StreakService.instance;

    if (_currentUser == null || _currentServerId == null) return null;

    try {
      return await _streakService.calculateCurrentStreak(
        serverId: _currentServerId!,
        userId: _currentUser!.id,
      );
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao buscar streak: $e');
      return null;
    }
  }

  /// Força atualização do streak (usado ao completar todas as fixas).
  Future<void> forceUpdateStreak() async {
    final StreakService _streakService = StreakService.instance;

    if (_currentUser == null || _currentServerId == null) return;

    try {
      final result = await _streakService.updateStreakOnDayComplete(
        serverId: _currentServerId!,
        userId: _currentUser!.id,
        currentUser: _currentUser!,
      );

      if (result.success) {
        AppConstants.debugLog(
            '✅ Streak forçadamente atualizado: ${result.newStreak} dias');

        if (result.reachedNewMilestone) {
          AppConstants.debugLog(
              '🎉 Novo milestone atingido: ${result.milestone} dias!');
        }
      }
    } catch (e) {
      AppConstants.debugLog('❌ Erro ao forçar atualização de streak: $e');
    }
  }

  // ================= ATRIBUTOS =================

  /// Atualiza um atributo específico pelo nome (aceita pt-BR e en).
  ///
  /// Nomes aceitos: study/estudo, discipline/disciplina, evolution/evolução,
  /// shape, habit/hábito.
  Future<void> updateAttribute(String name, int value) async {
    if (_currentUser == null) return;

    final attrs = _currentUser!.stats.attributes;
    UserAttributes updated;

    switch (name.toLowerCase()) {
      case 'study':
      case 'estudo':
        updated = attrs.copyWith(study: value);
        break;
      case 'discipline':
      case 'disciplina':
        updated = attrs.copyWith(discipline: value);
        break;
      case 'evolution':
      case 'evolucao':
      case 'evolução':
        updated = attrs.copyWith(evolution: value);
        break;
      case 'shape':
        updated = attrs.copyWith(shape: value);
        break;
      case 'habit':
      case 'habito':
      case 'hábito':
        updated = attrs.copyWith(habit: value);
        break;
      default:
        return;
    }

    final stats = _currentUser!.stats.copyWith(attributes: updated);

    await updateUser({'stats': stats.toMap()});
  }

  // ================= CACHE =================

  /// Invalida cache de ranking (top3, page1, posição do usuário).
  void invalidateRankingCache() {
    if (_currentServerId == null) return;

    AppConstants.debugLog('🗑️ Invalidando cache do ranking...');

    final serverId = _currentServerId!;

    // Chaves usadas pelo ranking_screen
    _cache.invalidate('ranking_${serverId}_top3');
    _cache.invalidate('ranking_${serverId}_page1');

    // Invalida posição do usuário logado
    if (_currentUser != null) {
      _cache.invalidate('ranking_position_${serverId}_${_currentUser!.id}');
    }

    AppConstants.debugLog('✅ Cache do ranking invalidado');
  }

  /// Invalida todos os caches relevantes (usuário, missões, ranking).
  void invalidateCache() {
    if (_currentUser == null || _currentServerId == null) return;

    AppConstants.debugLog('🗑️ UserProvider: Invalidando cache...');

    _cache.invalidate('user_${_currentServerId}_${_currentUser!.id}');

    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _cache.invalidate('missions_${_currentServerId}_${_currentUser!.id}_$date');

    // FIX: usa o método correto que invalida as chaves certas do ranking
    invalidateRankingCache();
  }

  /// Limpa todo o estado do provider (stream, user, server, erro).
  void clearUser() {
    _userStreamSubscription?.cancel();
    _userStreamSubscription = null;
    _currentUser = null;
    _currentServerId = null;
    _error = null;
    notifyListeners();
  }

  // ================= PROGRESSO =================

  /// XP restante para o próximo nível (0 se nível máximo).
  int get xpForNextLevel {
    if (_currentUser == null) return 0;

    final level = _currentUser!.level;
    if (level >= AppConstants.maxLevel) return 0;

    final nextLevelXp = AppConstants.totalXpForLevel(level + 1);
    return (nextLevelXp - _currentUser!.totalXp).clamp(0, nextLevelXp);
  }

  /// Progresso do nível atual como fração (0.0 a 1.0).
  double get levelProgress {
    if (_currentUser == null) return 0.0;

    final level = _currentUser!.level;
    if (level >= AppConstants.maxLevel) return 1.0;

    final currentXp = AppConstants.totalXpForLevel(level);
    final nextXp = AppConstants.totalXpForLevel(level + 1);

    final xpInLevel = _currentUser!.totalXp - currentXp;
    final xpNeeded = nextXp - currentXp;

    return (xpInLevel / xpNeeded).clamp(0.0, 1.0);
  }

  // ================= HELPERS =================

  /// Atualiza flag de loading e notifica se não for carga inicial.
  void _setLoading(bool value) {
    _isLoading = value;
    if (!_isInitialLoad) {
      notifyListeners();
    }
  }

  /// Atualiza mensagem de erro e notifica se não for carga inicial.
  void _setError(String? value) {
    _error = value;
    if (!_isInitialLoad) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userStreamSubscription?.cancel();
    super.dispose();
  }
}
