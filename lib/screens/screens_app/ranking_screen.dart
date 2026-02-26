import 'package:flutter/material.dart';
import 'package:monarch/constants/app_constants.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:monarch/screens/screens_app/animated_particles.dart';
import 'package:monarch/services/database_service.dart';
import 'package:monarch/services/cache_service.dart';
import 'package:monarch/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

// ============================================================================
// SERVIÇO DE BOAS-VINDAS (APENAS UMA VEZ)
// ============================================================================

class RankingWelcomeService {
  static const String _keyWelcomeShown = 'ranking_welcome_shown_v2';
  
  /// Verifica se deve mostrar popup de boas-vindas (apenas na primeira vez)
  static Future<bool> shouldShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(_keyWelcomeShown) ?? false;
    
    if (!hasShown) {
      await prefs.setBool(_keyWelcomeShown, true);
      return true;
    }
    
    return false;
  }
}


// ============================================================================
// GERADOR DE EMOJIS CONSISTENTE
// ============================================================================

class UserEmojiGenerator {
  static const List<String> _emojis = [
    '🦁', '🐯', '🐻', '🦊', '🐺', '🦅', '🦉', '🐉', '🦖', '🦕',
    '🐙', '🦑', '🦈', '🐬', '🐳', '🦏', '🦛', '🦍', '🐘', '🦒',
    '🦓', '🦌', '🐆', '🐅', '🐃', '🐂', '🐄', '🦬', '🐪', '🐫',
    '🦘', '🦨', '🦡', '🦝', '🐿️', '🦔', '🦇', '🦋', '🐝', '🐞',
    '🦗', '🕷️', '🦂', '🦟', '🦠', '👾', '🤖', '👻', '👽', '🎃',
    '⚡', '🔥', '💎', '👑', '⭐', '💫', '✨', '🌟', '🎯', '🏆',
  ];
  
  /// Gera um emoji consistente baseado no userId
  static String getEmojiForUser(String userId) {
    // Usar hash do userId para garantir consistência
    final hash = userId.hashCode.abs();
    final index = hash % _emojis.length;
    return _emojis[index];
  }
}

// ============================================================================
// RANKING SCREEN
// ============================================================================

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
  
  int _currentPage = 1;
  static const int _pageSize = 20;
  static const int _top3Size = 3;

  late AnimationController _fadeController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    setState(() => _loading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final serverId = userProvider.currentServerId;
      final userId = userProvider.currentUser?.id;

      if (serverId == null) {
        setState(() => _loading = false);
        return;
      }

      // Carregar última posição conhecida

      final top3CacheKey = 'ranking_${serverId}_top3';
      _top3Users = await _cache.getCached<List<UserModel>>(
        key: top3CacheKey,
        fetchFunction: () => _dbService.getServerRanking(
          serverId,
          page: 1,
          pageSize: _top3Size,
        ),
        cacheDuration: const Duration(minutes: 15),
        forceRefresh: forceRefresh,
      ) ?? [];

      final page1CacheKey = 'ranking_${serverId}_page1';
      _rankedUsers = await _cache.getCached<List<UserModel>>(
        key: page1CacheKey,
        fetchFunction: () => _dbService.getServerRanking(
          serverId,
          page: 1,
          pageSize: _pageSize,
        ),
        cacheDuration: CacheService.CACHE_SHORT,
        forceRefresh: forceRefresh,
      ) ?? [];

      if (userId != null) {
        final positionCacheKey = 'ranking_position_${serverId}_$userId';
        _userPosition = await _cache.getCached<int>(
          key: positionCacheKey,
          fetchFunction: () => _dbService.getUserRankingPosition(
            serverId: serverId,
            userId: userId,
          ),
          cacheDuration: CacheService.CACHE_SHORT,
          forceRefresh: forceRefresh,
        );
        
        // Verificar se deve mostrar feedback
        _checkAndShowWelcome();
      }

      _currentPage = 1;
      _hasMoreData = _rankedUsers.length >= _pageSize;

      setState(() => _loading = false);
    } catch (e) {
      AppConstants.debugLog('Erro ao carregar ranking: $e');
      setState(() => _loading = false);
    }
  }
  
  
  Future<void> _checkAndShowWelcome() async {
    final shouldShow = await RankingWelcomeService.shouldShowWelcome();
    
    if (shouldShow && mounted) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _showWelcomeDialog();
        }
      });
    }
  }
  
  void _showWelcomeDialog() {
    final userProvider = context.read<UserProvider>();
    final rank = userProvider.currentUser?.rank ?? 'E';
    final theme = _getThemeForRank(rank);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.surface,
                theme.surfaceLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.primary.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.primary.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: theme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Título
              Text(
                '🏆 Bem-vindo ao Ranking!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Mensagem
              Text(
                'Aqui você compete com outros jogadores do servidor!\n\nComplete suas missões diárias para subir no ranking e alcançar o topo!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Botão
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Entendi!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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

  Future<void> _loadMoreUsers() async {
    if (_loadingMore || !_hasMoreData || _loading) return;

    setState(() => _loadingMore = true);

    try {
      final userProvider = context.read<UserProvider>();
      final serverId = userProvider.currentServerId;

      if (serverId == null) return;

      final nextPage = _currentPage + 1;
      final cacheKey = 'ranking_${serverId}_page$nextPage';

      final moreUsers = await _cache.getCached<List<UserModel>>(
        key: cacheKey,
        fetchFunction: () => _dbService.getServerRanking(
          serverId,
          page: nextPage,
          pageSize: _pageSize,
        ),
        cacheDuration: CacheService.CACHE_SHORT,
      ) ?? [];

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showUserProfile(UserModel user, int position) {
    final userTheme = _getThemeForRank(user.rank);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserProfileSheet(
        user: user,
        position: position,
        theme: userTheme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final rank = userProvider.currentUser?.rank ?? 'E';
        final theme = _getThemeForRank(rank);
        final currentUserId = userProvider.currentUser?.id;

        return Scaffold(
          backgroundColor: theme.background,
          body: AnimatedParticlesBackground(
            particleColor: theme.primary,
            particleCount: 30,
            child: _loading
                ? _buildLoadingState(theme)
                : RefreshIndicator(
                    onRefresh: _refreshRanking,
                    color: theme.primary,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        // APP BAR
                        SliverAppBar(
                          floating: true,
                          snap: true,
                          backgroundColor: theme.background,
                          elevation: 0,
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [theme.primary, theme.accent],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.emoji_events,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Ranking',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          centerTitle: true,
                        ),

                        // POSIÇÃO DO USUÁRIO (se não estiver no TOP 3)
                        if (_userPosition != null && _userPosition! > 3)
                          SliverToBoxAdapter(
                            child: _buildUserPositionBanner(
                              currentUserId!,
                              _userPosition!,
                              theme,
                            ),
                          ),

                        // PÓDIO TOP 3
                        if (_top3Users.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildPodium(currentUserId, theme),
                          ),

                        // LISTA DE USUÁRIOS
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index < _rankedUsers.length) {
                                  final user = _rankedUsers[index];
                                  final position = index + 1;
                                  final isCurrentUser = user.id == currentUserId;

                                  return _buildRankingTile(
                                    user,
                                    position,
                                    theme,
                                    isCurrentUser: isCurrentUser,
                                  );
                                } else if (_loadingMore) {
                                  return _buildLoadingMoreIndicator(theme);
                                }
                                return null;
                              },
                              childCount: _rankedUsers.length + (_loadingMore ? 1 : 0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildUserPositionBanner(String userId, int position, RankTheme theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.3),
            theme.accent.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primary,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.primary, theme.accent],
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                UserEmojiGenerator.getEmojiForUser(userId),
                style: const TextStyle(fontSize: 25),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SUA POSIÇÃO',
                  style: TextStyle(
                    color: theme.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '#$position',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: theme.primary.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.1),
                child: Icon(
                  Icons.trending_up,
                  color: theme.primary,
                  size: 28,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(String? currentUserId, RankTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        children: [
          Text(
            'TOP 3',
            style: TextStyle(
              color: theme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2º Lugar
              if (_top3Users.length > 1)
                Flexible(
                  child: _buildPodiumPosition(
                    _top3Users[1],
                    2,
                    theme,
                    isCurrentUser: _top3Users[1].id == currentUserId,
                  ),
                ),

              const SizedBox(width: 8),

              // 1º Lugar
              if (_top3Users.isNotEmpty)
                Flexible(
                  child: _buildPodiumPosition(
                    _top3Users[0],
                    1,
                    theme,
                    isCurrentUser: _top3Users[0].id == currentUserId,
                  ),
                ),

              const SizedBox(width: 8),

              // 3º Lugar
              if (_top3Users.length > 2)
                Flexible(
                  child: _buildPodiumPosition(
                    _top3Users[2],
                    3,
                    theme,
                    isCurrentUser: _top3Users[2].id == currentUserId,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPosition(
    UserModel user,
    int position,
    RankTheme theme, {
    required bool isCurrentUser,
  }) {
    final heights = {1: 110.0, 2: 90.0, 3: 75.0};
    final sizes = {1: 55.0, 2: 48.0, 3: 45.0};
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};

    final height = heights[position]!;
    final size = sizes[position]!;
    final medal = medals[position]!;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcular largura máxima disponível (dividido por 3 + espaçamentos)
        final maxWidth = (MediaQuery.of(context).size.width - 64) / 3;
        final width = maxWidth.clamp(70.0, 85.0);
        final isBeginner = (user?.rank ?? 'E') == 'E';
        return GestureDetector(
          onTap: () => _showUserProfile(user, position),
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar + Medal
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isCurrentUser
                            ? LinearGradient(
                                colors: [theme.primary, theme.accent],
                              )
                            : LinearGradient(
                                colors: [
                                  theme.surfaceLight,
                                  theme.surface,
                                ],
                              ),
                        border: Border.all(
                          color: isCurrentUser ? theme.primary : theme.surfaceLight,
                          width: isCurrentUser ? 0.01 : 0.8,
                        ),
                        boxShadow: isCurrentUser
                            ? [
                                BoxShadow(
                                  color: theme.primary.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.primary.withOpacity(isBeginner ? 0.4 : 1),
                        width: isBeginner ? 2 : 4,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/rank/rank_${(user?.rank ?? 'E').toLowerCase()}.jpg',
                        width: 45,
                        height: 45,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.primary.withOpacity(0.8),
                            ),
                            child: Center(
                              child: Text(
                                user?.rank ?? 'E',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                      ),
                    ),
                    Positioned(
                      bottom: -6,
                      right: -6,
                      child: Text(
                        medal,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    if (isCurrentUser)
                      Positioned(
                        top: -6,
                        left: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: theme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 6),

                // Nome
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    user.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrentUser ? theme.primary : theme.textPrimary,
                      fontSize: 11,
                      fontWeight: isCurrentUser ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Pedestal
                Container(
                  width: width - 10,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCurrentUser
                          ? [
                              theme.primary.withOpacity(0.3),
                              theme.accent.withOpacity(0.2),
                            ]
                          : [
                              theme.surface.withOpacity(0.5),
                              theme.surfaceLight.withOpacity(0.3),
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    border: Border.all(
                      color: isCurrentUser ? theme.primary : theme.surfaceLight,
                      width: isCurrentUser ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'LVL ${user.level}',
                        style: TextStyle(
                          color: isCurrentUser ? theme.primary : theme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppConstants.formatNumber(user.totalXp),
                          style: TextStyle(
                            color: isCurrentUser ? theme.primary : theme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        'XP',
                        style: TextStyle(
                          color: theme.textTertiary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankingTile(
    UserModel user,
    int position,
    RankTheme theme, {
    required bool isCurrentUser,
  }) {
    final isBeginner = (user?.rank ?? 'E') == 'E';
    return GestureDetector(
      onTap: () => _showUserProfile(user, position),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? theme.primary.withOpacity(0.2)
              : theme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentUser ? theme.primary : theme.surfaceLight.withOpacity(0.3),
            width: isCurrentUser ? 2 : 1,
          ),
          boxShadow: isCurrentUser
              ? [
                  BoxShadow(
                    color: theme.primary.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Posição
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? theme.primary
                    : theme.surfaceLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '#$position',
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : theme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Avatar (emoji)
            Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.primary.withOpacity(isBeginner ? 0.6 : 1),
                        width: isBeginner ? 2 : 4,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/rank/rank_${(user?.rank ?? 'E').toLowerCase()}.jpg',
                        width: 35,
                        height: 35,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.primary.withOpacity(0.8),
                            ),
                            child: Center(
                              child: Text(
                                user?.rank ?? 'E',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

            const SizedBox(width: 10),

            // Info do usuário
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrentUser ? theme.primary : theme.textPrimary,
                            fontSize: 14,
                            fontWeight: isCurrentUser ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star,
                          color: theme.primary,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getThemeForRank(user.rank).primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'RANK ${user.rank}',
                          style: TextStyle(
                            color: _getThemeForRank(user.rank).primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LVL ${user.level}',
                        style: TextStyle(
                          color: theme.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // XP
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConstants.formatNumber(user.totalXp),
                  style: TextStyle(
                    color: isCurrentUser ? theme.primary : theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'XP',
                  style: TextStyle(
                    color: theme.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 4),
            
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(RankTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(theme.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Carregando ranking...',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(RankTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(theme.primary),
        ),
      ),
    );
  }

  RankTheme _getThemeForRank(String rank) {
    return RankThemes.getTheme(rank);
  }
}

// ============================================================================
// USER PROFILE SHEET
// ============================================================================

class _UserProfileSheet extends StatelessWidget {
  final UserModel user;
  final int position;
  final RankTheme theme;

  const _UserProfileSheet({
    required this.user,
    required this.position,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.surfaceLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  _buildStatsGrid(),
                  const SizedBox(height: 16),
                  _buildAttributes(),
                  const SizedBox(height: 24),
                  _buildCloseButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final isBeginner = (user?.rank ?? 'E') == 'E';
    return Column(
      children: [
        // Avatar
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: theme.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: theme.primary.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Center(
            child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.primary.withOpacity(isBeginner ? 0.6 : 1),
                        width: isBeginner ? 2 : 4,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/rank/rank_${(user?.rank ?? 'E').toLowerCase()}.jpg',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.primary.withOpacity(0.8),
                            ),
                            child: Center(
                              child: Text(
                                user?.rank ?? 'E',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 14),

        // Nome
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            user.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Rank
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: theme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'RANK ${user.rank}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Posição
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, color: theme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              'Posição #$position',
              style: TextStyle(
                color: theme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Level',
                  '${user.level}',
                  Icons.stars,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'XP Total',
                  AppConstants.formatNumber(user.totalXp),
                  Icons.bolt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Missões',
                  '${user.stats.totalMissionsCompleted}',
                  Icons.task_alt,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Sequência',
                  '${user.stats.currentStreak}d',
                  Icons.local_fire_department,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Recorde',
                  '${user.stats.bestStreak}d',
                  Icons.workspace_premium,
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: theme.primary, size: 22),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAttributes() {
    final attrs = user.stats.attributes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ATRIBUTOS',
            style: TextStyle(
              color: theme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildAttributeBar('🎯 Disciplina', attrs.discipline),
          const SizedBox(height: 12),
          _buildAttributeBar('🔥 Hábito', attrs.habit),
          const SizedBox(height: 12),
          _buildAttributeBar('📚 Estudo', attrs.study),
          const SizedBox(height: 12),
          _buildAttributeBar('💪 Shape', attrs.shape),
          const SizedBox(height: 12),
          _buildAttributeBar('⚡ Evolução', attrs.evolution),
        ],
      ),
    );
  }

  Widget _buildAttributeBar(String name, int value) {
    final percentage = value / AppConstants.maxAttributePoints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$value/${AppConstants.maxAttributePoints}',
              style: TextStyle(
                color: theme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: theme.surfaceLight.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation(theme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Fechar',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}