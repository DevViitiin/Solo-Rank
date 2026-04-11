import 'package:flutter/material.dart';
import 'package:monarch/core/constants/app_constants.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/helpers/ranking_helpers.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:monarch/widgets/animated_particles.dart';
import 'package:monarch/screens/app/ranking_profile_screen.dart';
import 'package:monarch/services/database_service.dart';
import 'package:monarch/services/cache_service.dart';
import 'package:monarch/models/user_model.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

// ============================================================================
// RANKING SCREEN
// ============================================================================

/// Tela de ranking do servidor no Dracoryx.
///
/// Exibe a classificação dos jogadores com:
/// - Pódio animado dos top 3 jogadores
/// - Lista paginada com scroll infinito
/// - Posição do usuário atual (banner fixo quando fora do top 3)
/// - Pull-to-refresh com invalidação de cache
/// - Detecção de dados desatualizados com reload automático (max 3 tentativas)
///
/// Navega para [RankingProfileScreen] ao clicar em um jogador.
class RankingScreen extends StatefulWidget {
  const RankingScreen({Key? key}) : super(key: key);

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final _cache = CacheService.instance;
  final ScrollController _scrollController = ScrollController();

  List<UserModel> _rankedUsers = [];
  List<UserModel> _top3Users = [];
  int? _userPosition;

  bool _loading = true;
  bool _isRefreshing = false;
  bool _loadingMore = false;
  bool _hasMoreData = true;
  bool _pendingReload = false;

  // FIX 2: contador de tentativas para evitar loop infinito
  int _staleReloadAttempts = 0;
  static const int _maxStaleReloadAttempts = 3;

  int _currentPage = 1;
  static const int _pageSize = 20;
  static const int _top3Size = 3;

  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _rotateController;
  late AnimationController _fireController;
  late AnimationController _entranceController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fireAnimation;
  late Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _fireAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _fireController, curve: Curves.easeInOut),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _rotateController.dispose();
    _fireController.dispose();
    _entranceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── data ──────────────────────────────────────────────────────────────────

  /// Carrega top 3, página 1 e posição do usuário com cache.
  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _pendingReload = false;
    });
    try {
      final userProvider = context.read<UserProvider>();
      final serverId = userProvider.currentServerId;
      final userId = userProvider.currentUser?.id;

      if (serverId == null) {
        setState(() => _loading = false);
        return;
      }

      // FIX 1: chaves alinhadas com o padrão interno do DatabaseService
      // (ranking_${serverId}_p${page}_s$pageSize)
      _top3Users = await _cache.getCached<List<UserModel>>(
            key: 'ranking_${serverId}_p1_s$_top3Size',
            fetchFunction: () =>
                _dbService.getServerRanking(serverId, page: 1, pageSize: _top3Size),
            cacheDuration: const Duration(minutes: 15),
            forceRefresh: forceRefresh,
            toEncodable: (list) => usersToEncodable(list),
            fromJson: (json) => usersFromJson(json),
          ) ??
          [];

      _rankedUsers = await _cache.getCached<List<UserModel>>(
            key: 'ranking_${serverId}_p1_s$_pageSize',
            fetchFunction: () =>
                _dbService.getServerRanking(serverId, page: 1, pageSize: _pageSize),
            cacheDuration: CacheService.CACHE_SHORT,
            forceRefresh: forceRefresh,
            toEncodable: (list) => usersToEncodable(list),
            fromJson: (json) => usersFromJson(json),
          ) ??
          [];

      if (userId != null) {
        _userPosition = await _cache.getCached<int>(
          key: 'ranking_position_${serverId}_$userId',
          fetchFunction: () => _dbService.getUserRankingPosition(
              serverId: serverId, userId: userId),
          cacheDuration: CacheService.CACHE_SHORT,
          forceRefresh: forceRefresh,
          fromJson: (json) => json as int,
        );
        _checkAndShowWelcome();
      }

      _currentPage = 1;
      _hasMoreData = _rankedUsers.length >= _pageSize;

      // FIX 2+3: reseta contador APENAS se o load trouxe dados frescos do Firebase
      // (forceRefresh=true). Se foi cache hit, não reseta — senão o contador nunca
      // acumula e o loop continua indefinidamente.
      if (forceRefresh) {
        _staleReloadAttempts = 0;
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      AppConstants.debugLog('Erro ao carregar ranking: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Verifica se o ranking está desatualizado comparando XP local vs cache.
  ///
  /// Limita a 3 tentativas de reload para evitar loops infinitos.
  void _checkIfRankingIsStale(String? currentUserId, int? currentXp) {
    if (_loading || _isRefreshing || _pendingReload) return;
    if (currentUserId == null || currentXp == null) return;

    // FIX 2: para após N tentativas sem sucesso
    if (_staleReloadAttempts >= _maxStaleReloadAttempts) {
      AppConstants.debugLog(
          '⚠️ RankingScreen: máximo de tentativas atingido, abortando reload automático.');
      return;
    }

    UserModel? userInList;
    for (final u in _rankedUsers) {
      if (u.id == currentUserId) {
        userInList = u;
        break;
      }
    }
    if (userInList == null) {
      for (final u in _top3Users) {
        if (u.id == currentUserId) {
          userInList = u;
          break;
        }
      }
    }

    if (userInList == null) return;

    final rankingXp = userInList.totalXp;
    if (rankingXp == currentXp) return;

    AppConstants.debugLog(
        '🔄 RankingScreen: dados desatualizados (ranking=$rankingXp, real=$currentXp). '
        'Tentativa ${_staleReloadAttempts + 1}/$_maxStaleReloadAttempts. Recarregando...');

    _pendingReload = true;
    _staleReloadAttempts++;

    // FIX 3: invalida explicitamente as chaves do cache de MEMÓRIA antes do reload.
    // Sem isso, o DatabaseService serve o dado stale direto da memória mesmo com
    // forceRefresh=true, porque o forceRefresh do ranking_screen não chega no
    // DatabaseService — ele só controla a chamada local ao CacheService.
    // O dado em memória vence e retorna XP antigo → loop nunca para.
    final serverId = context.read<UserProvider>().currentServerId;
    if (serverId != null) {
      _cache.invalidate('ranking_${serverId}_p1_s$_top3Size');
      _cache.invalidate('ranking_${serverId}_p1_s$_pageSize');
      _cache.invalidate('ranking_position_${serverId}_$currentUserId');
      AppConstants.debugLog('🗑️ Cache de ranking invalidado antes do reload.');
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_loading && !_isRefreshing) {
        _loadInitialData(forceRefresh: true);
      } else {
        _pendingReload = false;
      }
    });
  }

  Future<void> _checkAndShowWelcome() async {
    final shouldShow = await RankingWelcomeService.shouldShowWelcome();
    if (shouldShow && mounted) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _showWelcomeDialog();
      });
    }
  }

  void _showWelcomeDialog() {
    final userProvider = context.read<UserProvider>();
    final theme = RankThemes.getTheme(userProvider.currentUser?.rank ?? 'E');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F0F24), Color(0xFF08081A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.primary.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                  color: theme.primary.withOpacity(0.35),
                  blurRadius: 40,
                  spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [theme.primary, theme.accent]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events,
                    size: 44, color: Colors.white),
              ),
              const SizedBox(height: 20),
              ShaderMask(
                shaderCallback: (bounds) =>
                    LinearGradient(colors: [Colors.white, theme.primary])
                        .createShader(bounds),
                child: const Text(
                  '🏆 BEM-VINDO AO RANKING!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Compete com outros jogadores do servidor!\n\nComplete suas missões diárias para subir no ranking e alcançar o topo!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: theme.textSecondary, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('ENTENDIDO!',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreUsers();
    }
  }

  /// Carrega próxima página de usuários (scroll infinito).
  Future<void> _loadMoreUsers() async {
    if (_loadingMore || !_hasMoreData || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final userProvider = context.read<UserProvider>();
      final serverId = userProvider.currentServerId;
      if (serverId == null) return;

      final nextPage = _currentPage + 1;

      // FIX 1: chave alinhada com o padrão interno do DatabaseService
      final moreUsers = await _cache.getCached<List<UserModel>>(
            key: 'ranking_${serverId}_p${nextPage}_s$_pageSize',
            fetchFunction: () => _dbService.getServerRanking(serverId,
                page: nextPage, pageSize: _pageSize),
            cacheDuration: CacheService.CACHE_SHORT,
            toEncodable: (list) => usersToEncodable(list),
            fromJson: (json) => usersFromJson(json),
          ) ??
          [];

      setState(() {
        _rankedUsers.addAll(moreUsers);
        _currentPage = nextPage;
        _hasMoreData = moreUsers.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() => _loadingMore = false);
    }
  }

  /// Pull-to-refresh: recarrega ranking com forceRefresh.
  Future<void> _refreshRanking() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _loadInitialData(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✨ Ranking atualizado!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// Navega para o perfil detalhado de um jogador no ranking.
  void _openUserProfile(UserModel user, int position) {
    Navigator.push(
      context,
      RankingProfileRoute(user: user, position: position),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final rank = userProvider.currentUser?.rank ?? 'E';
        final theme = RankThemes.getTheme(rank);
        final currentUserId = userProvider.currentUser?.id;
        final currentXp = userProvider.currentUser?.totalXp;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkIfRankingIsStale(currentUserId, currentXp);
        });

        return Scaffold(
          backgroundColor: const Color(0xFF06060F),
          body: Stack(
            children: [
              // ── fundo ────────────────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.3),
                    radius: 1.2,
                    colors: [Color(0xFF0E0E2A), Color(0xFF06060F)],
                  ),
                ),
              ),
              CustomPaint(
                painter:
                    _GridPainter(color: theme.primary.withOpacity(0.04)),
                size: Size.infinite,
              ),
              AnimatedParticlesBackground(
                particleColor: const Color(0xFF448AFF).withOpacity(0.5),
                particleCount: 15,
                child: const SizedBox.expand(),
              ),
              AnimatedParticlesBackground(
                particleColor: theme.primary.withOpacity(0.5),
                particleCount: 12,
                child: const SizedBox.expand(),
              ),

              // ── lista ────────────────────────────────────────────────────
              SafeArea(
                child: _loading
                    ? _buildLoadingState(theme)
                    : RefreshIndicator(
                        onRefresh: _refreshRanking,
                        color: theme.primary,
                        backgroundColor: const Color(0xFF0E0E2A),
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics()),
                          slivers: [
                            _buildHeader(theme),
                            if (_userPosition != null && _userPosition! > 3)
                              SliverToBoxAdapter(
                                child: _buildUserPositionBanner(
                                  currentUserId!,
                                  _userPosition!,
                                  theme,
                                  userProvider.currentUser,
                                ),
                              ),
                            if (_top3Users.isNotEmpty)
                              SliverToBoxAdapter(
                                  child: _buildPodium(currentUserId, theme)),
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 50),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    if (index < _rankedUsers.length) {
                                      final user = _rankedUsers[index];
                                      return _buildRankingTile(
                                        user, index + 1, theme,
                                        isCurrentUser:
                                            user.id == currentUserId,
                                      );
                                    } else if (_loadingMore) {
                                      return _buildLoadingMoreIndicator(theme);
                                    }
                                    return null;
                                  },
                                  childCount: _rankedUsers.length +
                                      (_loadingMore ? 1 : 0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(RankTheme theme) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _entranceAnimation,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [theme.primary, theme.accent]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary
                            .withOpacity(0.6 * _glowAnimation.value),
                        blurRadius: 18,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Icon(Icons.emoji_events,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RANKING',
                      style: TextStyle(
                          color: theme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3)),
                  const Text('Servidor',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.1)),
                ],
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (_, __) => GestureDetector(
                  onTap: _isRefreshing ? null : _refreshRanking,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E2A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: theme.primary.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primary
                              .withOpacity(0.1 * _glowAnimation.value),
                          blurRadius: 12,
                        )
                      ],
                    ),
                    child: _isRefreshing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    theme.primary)),
                          )
                        : Icon(Icons.refresh_rounded,
                            color: theme.primary, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BANNER POSIÇÃO DO USUÁRIO LOGADO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildUserPositionBanner(
      String userId, int position, RankTheme theme, UserModel? currentUser) {
    final rank = currentUser?.rank ?? 'E';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (_, __) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primary.withOpacity(0.25),
                theme.accent.withOpacity(0.15),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: theme.primary
                    .withOpacity(0.3 * _glowAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              _buildRankAvatar(rank, theme, size: 54, isHighlight: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SUA POSIÇÃO',
                        style: TextStyle(
                            color: theme.textTertiary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2)),
                    const SizedBox(height: 2),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.white, theme.primary],
                      ).createShader(bounds),
                      child: Text('#$position',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.0)),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.trending_up_rounded,
                        color: theme.primary, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PÓDIO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPodium(String? currentUserId, RankTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: AnimatedBuilder(
        animation: Listenable.merge([_glowAnimation, _pulseAnimation]),
        builder: (_, __) => Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.primary.withOpacity(0.5),
                theme.accent.withOpacity(0.3),
                theme.primary.withOpacity(0.2),
              ],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F0F24), Color(0xFF08081A)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          theme.primary.withOpacity(0.5)
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedBuilder(
                      animation: _fireAnimation,
                      builder: (_, __) => Transform.scale(
                        scale: _fireAnimation.value,
                        child: const Text('🏆',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          theme.primary,
                          Colors.white,
                          theme.accent
                        ],
                      ).createShader(bounds),
                      child: const Text('TOP 3',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 40,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          theme.primary.withOpacity(0.5),
                          Colors.transparent
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_top3Users.length > 1)
                      Flexible(
                        child: _buildPodiumPosition(
                            _top3Users[1], 2, theme,
                            isCurrentUser:
                                _top3Users[1].id == currentUserId),
                      ),
                    const SizedBox(width: 10),
                    if (_top3Users.isNotEmpty)
                      Flexible(
                        child: _buildPodiumPosition(
                            _top3Users[0], 1, theme,
                            isCurrentUser:
                                _top3Users[0].id == currentUserId),
                      ),
                    const SizedBox(width: 10),
                    if (_top3Users.length > 2)
                      Flexible(
                        child: _buildPodiumPosition(
                            _top3Users[2], 3, theme,
                            isCurrentUser:
                                _top3Users[2].id == currentUserId),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumPosition(
    UserModel user,
    int position,
    RankTheme theme, {
    required bool isCurrentUser,
  }) {
    final podiumHeights = {1: 120.0, 2: 95.0, 3: 78.0};
    final avatarSizes = {1: 72.0, 2: 60.0, 3: 54.0};
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    final podiumColors = {
      1: [const Color(0xFFFFD700), const Color(0xFFFF8C00)],
      2: [const Color(0xFFB0C4DE), const Color(0xFF778899)],
      3: [const Color(0xFFCD7F32), const Color(0xFF8B4513)],
    };

    final height = podiumHeights[position]!;
    final avatarSize = avatarSizes[position]!;
    final medal = medals[position]!;
    final colors = podiumColors[position]!;
    final userRankTheme = RankThemes.getTheme(user.rank);

    return LayoutBuilder(builder: (context, _) {
      final maxWidth = (MediaQuery.of(context).size.width - 80) / 3;
      final width = maxWidth.clamp(72.0, 100.0);

      return GestureDetector(
        onTap: () => _openUserProfile(user, position),
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge(
                    [_glowAnimation, _rotateAnimation]),
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (position == 1)
                      Container(
                        width: avatarSize + 20,
                        height: avatarSize + 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors[0].withOpacity(
                                  0.5 * _glowAnimation.value),
                              blurRadius: 30,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    if (position == 1)
                      Transform.rotate(
                        angle: _rotateAnimation.value * 0.6,
                        child: CustomPaint(
                          size: Size(avatarSize + 16, avatarSize + 16),
                          painter: _DashedCirclePainter(
                              color: colors[0].withOpacity(0.5),
                              dashCount: 16),
                        ),
                      ),
                    Container(
                      width: avatarSize + 8,
                      height: avatarSize + 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          transform: GradientRotation(
                              _rotateAnimation.value * 0.5),
                          colors: [
                            colors[0].withOpacity(0.9),
                            Colors.transparent,
                            colors[1].withOpacity(0.7),
                            Colors.transparent,
                            colors[0].withOpacity(0.9),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: avatarSize + 2,
                      height: avatarSize + 2,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0A0A1A)),
                    ),
                    _buildRankAvatar(user.rank, userRankTheme,
                        size: avatarSize - 2,
                        isHighlight: isCurrentUser),
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Text(medal,
                          style: const TextStyle(fontSize: 22)),
                    ),
                    if (isCurrentUser)
                      Positioned(
                        top: -4,
                        left: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star,
                              color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: width,
                child: Text(user.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isCurrentUser ? theme.primary : Colors.white,
                        fontSize: position == 1 ? 12 : 11,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 2),
              Container(
                constraints: BoxConstraints(maxWidth: width),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: userRankTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: userRankTheme.primary.withOpacity(0.3)),
                ),
                child: Text(user.rank,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: userRankTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ),
              const SizedBox(height: 8),
              Container(
                width: width - 8,
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isCurrentUser
                        ? [
                            theme.primary.withOpacity(0.35),
                            theme.accent.withOpacity(0.2),
                          ]
                        : [
                            colors[0].withOpacity(0.25),
                            colors[1].withOpacity(0.15),
                          ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  border: Border.all(
                    color: isCurrentUser
                        ? theme.primary.withOpacity(0.6)
                        : colors[0].withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('LVL ${user.level}',
                        style: TextStyle(
                            color: (isCurrentUser
                                    ? theme.primary
                                    : colors[0])
                                .withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                            AppConstants.formatNumber(user.totalXp),
                            style: TextStyle(
                                color: isCurrentUser
                                    ? theme.primary
                                    : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                    Text('XP',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RANKING TILE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRankingTile(
    UserModel user,
    int position,
    RankTheme theme, {
    required bool isCurrentUser,
  }) {
    final userRankTheme = RankThemes.getTheme(user.rank);
    final positionColors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFB0C4DE),
      3: const Color(0xFFCD7F32),
    };
    final positionColor = positionColors[position] ?? theme.primary;

    return GestureDetector(
      onTap: () => _openUserProfile(user, position),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? theme.primary.withOpacity(0.18)
                : const Color(0xFF0E0E22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCurrentUser
                  ? theme.primary.withOpacity(0.6)
                  : position <= 3
                      ? positionColor.withOpacity(0.3)
                      : Colors.white.withOpacity(0.05),
              width: isCurrentUser ? 1.5 : 1,
            ),
            boxShadow: isCurrentUser
                ? [
                    BoxShadow(
                      color: theme.primary
                          .withOpacity(0.25 * _glowAnimation.value),
                      blurRadius: 16,
                      spreadRadius: 1,
                    )
                  ]
                : position <= 3
                    ? [
                        BoxShadow(
                          color: positionColor
                              .withOpacity(0.1 * _glowAnimation.value),
                          blurRadius: 12,
                        )
                      ]
                    : [],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: position <= 3
                        ? LinearGradient(
                            colors: [
                              positionColor.withOpacity(0.8),
                              positionColor.withOpacity(0.4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: position > 3
                        ? (isCurrentUser
                            ? theme.primary.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05))
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('#$position',
                        style: TextStyle(
                            color: position <= 3
                                ? Colors.white
                                : (isCurrentUser
                                    ? theme.primary
                                    : Colors.white.withOpacity(0.5)),
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildRankAvatar(user.rank, userRankTheme,
                  size: 44, isHighlight: isCurrentUser),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: isCurrentUser
                                      ? theme.primary
                                      : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.star_rounded,
                              color: theme.primary, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: userRankTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: userRankTheme.primary
                                      .withOpacity(0.3)),
                            ),
                            child: Text('RANK ${user.rank}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: userRankTheme.primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('LVL ${user.level}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppConstants.formatNumber(user.totalXp),
                      style: TextStyle(
                          color: isCurrentUser
                              ? theme.primary
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                  Text('XP',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.2),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AVATAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRankAvatar(String rank, RankTheme rankTheme,
      {required double size, required bool isHighlight}) {
    final isBeginner = rank == 'E';
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          if (isHighlight)
            Container(
              width: size + 10,
              height: size + 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: rankTheme.primary
                        .withOpacity(0.55 * _glowAnimation.value),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          Container(
            width: size + 4,
            height: size + 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(_rotateAnimation.value * 0.8),
                colors: isBeginner
                    ? [
                        Colors.grey.withOpacity(0.2),
                        Colors.transparent,
                        Colors.grey.withOpacity(0.2),
                        Colors.transparent,
                      ]
                    : [
                        rankTheme.primary,
                        rankTheme.accent.withOpacity(0.3),
                        Colors.transparent,
                        rankTheme.primary.withOpacity(0.5),
                        Colors.transparent,
                        rankTheme.primary,
                      ],
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF0A0A1A)),
          ),
          ClipOval(
            child: Image.asset(
              'assets/images/rank/rank_${rank.toLowerCase()}.png',
              width: size - 4,
              height: size - 4,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: size - 4,
                height: size - 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      rankTheme.primary.withOpacity(0.9),
                      rankTheme.primary.withOpacity(0.3),
                      const Color(0xFF0A0A1A),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Center(
                  child: Text(rank,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: size * 0.35,
                          fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOADING
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLoadingState(RankTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _rotateAnimation,
            builder: (_, __) => Transform.rotate(
              angle: _rotateAnimation.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.primary, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: theme.primary.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2)
                  ],
                ),
                child: Center(
                  child: Icon(Icons.emoji_events_rounded,
                      color: theme.primary, size: 28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('CARREGANDO RANKING...',
              style: TextStyle(
                  color: theme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3)),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(RankTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(theme.primary)),
      ),
    );
  }
}

// ============================================================================
// PAINTERS
// ============================================================================

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const spacing = 60.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final int dashCount;
  _DashedCirclePainter({required this.color, required this.dashCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dashAngle = (2 * math.pi) / dashCount;
    const gapFraction = 0.45;

    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * dashAngle,
        dashAngle * (1 - gapFraction),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) =>
      old.color != color || old.dashCount != dashCount;
}
