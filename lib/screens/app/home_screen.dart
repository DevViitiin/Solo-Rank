import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monarch/core/constants/app_constants.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:monarch/models/mission_model.dart';
import 'package:monarch/widgets/animated_particles.dart';
import 'package:monarch/screens/auth/login_screen.dart';
import 'package:monarch/widgets/tutorial_guide.dart';
import 'package:monarch/services/database_service.dart';
import 'package:monarch/services/cache_service.dart';
import 'package:monarch/services/streak_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final _cache = CacheService.instance;

  Map<String, dynamic> _todayMissions = {};
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _fireController;
  late AnimationController _rotateController;
  late AnimationController _glowController;
  late AnimationController _entranceController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _fireAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _entranceAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fireAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _fireController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _fireController.dispose();
    _rotateController.dispose();
    _glowController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final userProvider = context.read<UserProvider>();
      final userId = userProvider.currentUser?.id;
      final serverId = userProvider.currentServerId;

      if (userId == null || serverId == null) {
        setState(() => _loading = false);
        return;
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final missionsData = await _cache.getCached<Map<String, dynamic>>(
        key: 'missions_${serverId}_${userId}_$today',
        fetchFunction: () async {
          final data = await _dbService.getDailyMissions(serverId, userId, today);
          return data ?? <String, dynamic>{};
        },
        cacheDuration: CacheService.CACHE_SHORT,
      );

      if (missionsData != null) {
        _todayMissions = missionsData;
      }

      _calculateStats();
      setState(() => _loading = false);
    } catch (e) {
      AppConstants.debugLog('Erro ao carregar dados: $e');
      setState(() => _loading = false);
    }
  }

  void _calculateStats() {
    int fixedCompleted = 0;
    int fixedTotal = 0;
    int customCompleted = 0;
    int customTotal = 0;
    int totalXpGained = 0;

    if (_todayMissions['fixed'] != null && _todayMissions['fixed'] is Map) {
      final fixed = Map<String, dynamic>.from(_todayMissions['fixed']);
      fixedTotal = fixed.length;
      fixed.forEach((key, value) {
        if (value is Map) {
          final mission = Map<String, dynamic>.from(value);
          if (mission['completed'] == true) {
            fixedCompleted++;
            totalXpGained += (mission['xp'] as num?)?.toInt() ?? 0;
          }
        }
      });
    }

    if (_todayMissions['custom'] != null && _todayMissions['custom'] is Map) {
      final custom = Map<String, dynamic>.from(_todayMissions['custom']);
      customTotal = custom.length;
      custom.forEach((key, value) {
        if (value is Map) {
          final mission = Map<String, dynamic>.from(value);
          if (mission['completed'] == true) {
            customCompleted++;
            totalXpGained += (mission['xp'] as num?)?.toInt() ?? 0;
          }
        }
      });
    }

    _stats = {
      'fixedCompleted': fixedCompleted,
      'fixedTotal': fixedTotal,
      'customCompleted': customCompleted,
      'customTotal': customTotal,
      'totalCompleted': fixedCompleted + customCompleted,
      'totalMissions': fixedTotal + customTotal,
      'totalXpGained': totalXpGained,
    };
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'BOM DIA';
    if (hour < 18) return 'BOA TARDE';
    return 'BOA NOITE';
  }

  Future<void> _showLogoutDialog(RankTheme theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.primary.withOpacity(0.4), width: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: theme.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              'Sair da Conta',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          'Tem certeza que deseja sair da sua conta?',
          style: TextStyle(color: theme.textSecondary, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar',
                style: TextStyle(color: theme.textSecondary, fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: theme.primary.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Sair',
                style: TextStyle(
                    color: theme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed == true) _performLogout();
  }

  Future<void> _performLogout() async {
    try {
      final userProvider = context.read<UserProvider>();
      await userProvider.logout();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      AppConstants.debugLog('Erro ao fazer logout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao sair da conta. Tente novamente.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final user = userProvider.currentUser;
        final theme = RankThemes.getTheme(user?.rank ?? 'E');

        return Scaffold(
          backgroundColor: const Color(0xFF06060F),
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.3),
                    radius: 1.2,
                    colors: [
                      Color(0xFF0E0E2A),
                      Color(0xFF06060F),
                    ],
                  ),
                ),
              ),
              CustomPaint(
                painter: _GridPainter(color: theme.primary.withOpacity(0.04)),
                size: Size.infinite,
              ),
              AnimatedParticlesBackground(
                particleColor: const Color(0xFF448AFF).withOpacity(0.5),
                particleCount: 20,
                child: const SizedBox.expand(),
              ),
              AnimatedParticlesBackground(
                particleColor: theme.primary.withOpacity(0.6),
                particleCount: 15,
                child: const SizedBox.expand(),
              ),
              SafeArea(
                child: _loading
                    ? _buildLoadingState(theme)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: theme.primary,
                        backgroundColor: const Color(0xFF0E0E2A),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            _buildHeader(theme, user),
                            _buildEpicRankCard(theme, user),
                            _buildXpProgressBar(theme, user),
                            _buildStatsRow(theme, user),
                            _buildStreakCard(theme, user),
                            _buildMissionsSummary(theme),
                            _buildAttributesSection(theme, user),
                            _buildNextRankSection(theme, user),
                            const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
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

  Widget _buildLoadingState(RankTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _rotateAnimation,
            builder: (context, child) => Transform.rotate(
              angle: _rotateAnimation.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.primary,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Center(
                  child: Icon(Icons.star_rounded, color: theme.primary, size: 28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'CARREGANDO...',
            style: TextStyle(
              color: theme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(RankTheme theme, dynamic user) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _entranceAnimation,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: theme.primary.withOpacity(0.8),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            color: theme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.name ?? 'CAÇADOR',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Botão Tutorial — pill com ícone + label
              GestureDetector(
                onTap: () => showTutorialGuide(context),
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primary.withOpacity(0.22),
                          theme.accent.withOpacity(0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: theme.primary.withOpacity(0.55),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primary.withOpacity(0.28 * _glowAnimation.value),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded, color: theme.primary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'GUIA',
                          style: TextStyle(
                            color: theme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botão Logout
              GestureDetector(
                onTap: () => _showLogoutDialog(theme),
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) => Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E2A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.primary.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primary.withOpacity(0.1 * _glowAnimation.value),
                          blurRadius: 12,
                        )
                      ],
                    ),
                    child: Icon(Icons.logout_rounded, color: theme.primary, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EPIC RANK CARD — REDESIGN COMPLETO
  // ============================================================

  Widget _buildEpicRankCard(RankTheme theme, dynamic user) {
    final rank = user?.rank ?? 'E';
    final isBeginner = rank == 'E';
    final classTitle = AppConstants.rankTitles[rank] ?? 'CAÇADOR';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _glowAnimation, _rotateAnimation, _shimmerAnimation]),
          builder: (context, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Glow externo pulsante
                if (!isBeginner)
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 1.04 + (0.025 * _glowAnimation.value),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primary.withOpacity(0.45 * _glowAnimation.value),
                              blurRadius: 60,
                              spreadRadius: 6,
                            ),
                            BoxShadow(
                              color: theme.accent.withOpacity(0.2 * _glowAnimation.value),
                              blurRadius: 100,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Card principal
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: isBeginner
                          ? const LinearGradient(
                              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                            )
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: const [0.0, 0.4, 0.7, 1.0],
                              colors: [
                                theme.primary.withOpacity(0.9),
                                theme.accent.withOpacity(0.6),
                                theme.primary.withOpacity(0.4),
                                theme.accent.withOpacity(0.7),
                              ],
                            ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0F0F24), Color(0xFF08081A)],
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildClassTitleBanner(theme, rank, classTitle, isBeginner),
                          _buildHeroImageSection(theme, rank, isBeginner),
                          _buildCardStatsStrip(theme, user, rank, isBeginner),
                        ],
                      ),
                    ),
                  ),
                ),

                // Reflexo shimmer diagonal
                if (!isBeginner)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, _) => Transform.translate(
                            offset: Offset(
                              (_shimmerAnimation.value * 400) - 200,
                              -60,
                            ),
                            child: Transform.rotate(
                              angle: -0.4,
                              child: Container(
                                width: 80,
                                height: 400,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.0),
                                      Colors.white.withOpacity(0.06),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Banner do título da classe
  Widget _buildClassTitleBanner(RankTheme theme, String rank, String classTitle, bool isBeginner) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            theme.primary.withOpacity(0.18),
            theme.accent.withOpacity(0.08),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.primary.withOpacity(0.12),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Badge rank pulsante
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primary.withOpacity(0.8),
                    theme.accent.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: theme.primary.withOpacity(0.7 * _glowAnimation.value),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Text(
                'RANK $rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Container(
            width: 1,
            height: 22,
            color: theme.primary.withOpacity(0.25),
          ),

          const SizedBox(width: 12),

          // Título da classe com gradiente
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLASSE',
                  style: TextStyle(
                    color: theme.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 2),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.white,
                      theme.primary,
                      Colors.white.withOpacity(0.9),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    classTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Ícone de status
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, _) => Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.primary.withOpacity(0.3 + 0.2 * _glowAnimation.value),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primary.withOpacity(0.3 * _glowAnimation.value),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Icon(Icons.shield_rounded, color: theme.primary, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Hero: imagem central épica
  Widget _buildHeroImageSection(RankTheme theme, String rank, bool isBeginner) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: AnimatedBuilder(
        animation: Listenable.merge([_glowAnimation, _rotateAnimation, _pulseAnimation]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Anel externo girando lento
              Transform.rotate(
                angle: _rotateAnimation.value * 0.3,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.primary.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                ),
              ),

              // Anel tracejado girando ao contrário
              Transform.rotate(
                angle: -_rotateAnimation.value * 0.5,
                child: CustomPaint(
                  size: const Size(178, 178),
                  painter: _DashedCirclePainter(
                    color: theme.primary.withOpacity(0.25),
                    dashCount: 24,
                  ),
                ),
              ),

              // Halo de glow radial
              if (!isBeginner)
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withOpacity(0.55 * _glowAnimation.value),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                      BoxShadow(
                        color: theme.accent.withOpacity(0.25 * _glowAnimation.value),
                        blurRadius: 90,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                ),

              // Anel de gradiente sweep
              Container(
                width: 152,
                height: 152,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    transform: GradientRotation(_rotateAnimation.value * 0.8),
                    colors: isBeginner
                        ? [
                            Colors.grey.withOpacity(0.15),
                            Colors.transparent,
                            Colors.grey.withOpacity(0.15),
                            Colors.transparent,
                          ]
                        : [
                            theme.primary,
                            theme.accent.withOpacity(0.3),
                            Colors.transparent,
                            theme.accent,
                            theme.primary.withOpacity(0.5),
                            Colors.transparent,
                            theme.primary,
                          ],
                  ),
                ),
              ),

              // Fundo interno escuro
              Container(
                width: 144,
                height: 144,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0A0A1A),
                ),
              ),

              // Imagem do rank — protagonista
              Transform.scale(
                scale: 0.98 + (0.02 * _glowAnimation.value),
                child: Container(
                  width: 134,
                  height: 134,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withOpacity(0.5 * _glowAnimation.value),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/rank/rank_${rank.toLowerCase()}.png',
                      width: 134,
                      height: 134,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 134,
                        height: 134,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.primary.withOpacity(0.9),
                              theme.primary.withOpacity(0.3),
                              const Color(0xFF0A0A1A),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            rank,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Orbs orbitando
              if (!isBeginner) ...[
                _buildOrbit(theme, _rotateAnimation.value, 96, 0),
                _buildOrbit(theme, _rotateAnimation.value, 96, math.pi * 0.66),
                _buildOrbit(theme, _rotateAnimation.value, 96, math.pi * 1.33),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrbit(RankTheme theme, double angle, double radius, double offset) {
    final x = radius * math.cos(angle + offset);
    final y = radius * math.sin(angle + offset) * 0.4;
    return Transform.translate(
      offset: Offset(x, y),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, _) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                theme.primary,
                theme.primary.withOpacity(0.3),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.primary.withOpacity(0.8 * _glowAnimation.value),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
        ),
      ),
    );
  }

  // Faixa de stats na base do card
  Widget _buildCardStatsStrip(RankTheme theme, dynamic user, String rank, bool isBeginner) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            theme.primary.withOpacity(0.07),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: theme.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStripStat(
              icon: Icons.trending_up_rounded,
              label: 'NÍVEL',
              value: '${user?.level ?? 1}',
              iconColor: theme.primary,
              theme: theme,
              large: true,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  theme.primary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildStripStat(
              icon: Icons.bolt_rounded,
              label: 'XP TOTAL',
              value: AppConstants.formatNumber(user?.totalXp ?? 0),
              iconColor: Colors.amber,
              theme: theme,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  theme.primary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildStripStat(
              icon: Icons.task_alt_rounded,
              label: 'MISSÕES',
              value: '${user?.stats.totalMissionsCompleted ?? 0}',
              iconColor: const Color(0xFF00E676),
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStripStat({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required RankTheme theme,
    bool large = false,
  }) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, _) => Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.25 * _glowAnimation.value),
                  blurRadius: 10,
                )
              ],
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: large ? 24 : 18,
            fontWeight: FontWeight.w900,
            height: 1.0,
            shadows: [
              Shadow(
                color: iconColor.withOpacity(0.4),
                blurRadius: 8,
              )
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: theme.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // XP PROGRESS BAR
  // ============================================================

  Widget _buildXpProgressBar(RankTheme theme, dynamic user) {
    final xpForNext = context.read<UserProvider>().xpForNextLevel;
    final progress = context.read<UserProvider>().levelProgress;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.primary.withOpacity(0.15),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: theme.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'PROGRESSO → NÍVEL ${(user?.level ?? 1) + 1}',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: AnimatedBuilder(
                      animation: _shimmerAnimation,
                      builder: (context, child) {
                        return Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.primary,
                                theme.accent,
                                theme.primary,
                              ],
                              stops: [0, _shimmerAnimation.value.clamp(0.0, 1.0), 1],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primary.withOpacity(0.6),
                                blurRadius: 8,
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      4,
                      (i) => Container(
                        width: 2,
                        height: 8,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${user?.xp ?? 0} XP atual',
                    style: TextStyle(
                      color: theme.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: theme.primary.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: theme.primary, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    'Faltam $xpForNext XP para o próximo nível',
                    style: TextStyle(
                      color: theme.primary.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATS ROW
  // ============================================================

  Widget _buildStatsRow(RankTheme theme, dynamic user) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: _buildGlowStatCard(
                theme: theme,
                icon: Icons.bolt_rounded,
                label: 'XP TOTAL',
                value: AppConstants.formatNumber(user?.totalXp ?? 0),
                colors: [const Color(0xFFFFA000), const Color(0xFFFF6D00)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGlowStatCard(
                theme: theme,
                icon: Icons.task_alt_rounded,
                label: 'MISSÕES',
                value: '${user?.stats.totalMissionsCompleted ?? 0}',
                colors: [const Color(0xFF00C853), const Color(0xFF00897B)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowStatCard({
    required RankTheme theme,
    required IconData icon,
    required String label,
    required String value,
    required List<Color> colors,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors[0].withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: colors[0].withOpacity(0.12 * _glowAnimation.value),
                blurRadius: 20,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: colors[0].withOpacity(0.4),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: theme.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // STREAK CARD
  // ============================================================

  Widget _buildStreakCard(RankTheme theme, dynamic user) {
    final currentStreak = user?.stats.currentStreak ?? 0;
    final bestStreak = user?.stats.bestStreak ?? 0;

    final streakService = StreakService.instance;
    final milestones = streakService.getCurrentTierMilestones(currentStreak);
    final currentTier = streakService.getCurrentTier(currentStreak);
    final nextMilestone = streakService.getNextMilestone(currentStreak);
    final hasCompletedTier = streakService.hasCompletedCurrentTier(currentStreak);

    final progressToNext = (currentStreak / nextMilestone).clamp(0.0, 1.0);
    final daysToNext = nextMilestone - currentStreak;

    List<String> tierIcons;
    if (currentTier == 1) {
      tierIcons = ['🔥', '⚡', '💪'];
    } else if (currentTier == 2) {
      tierIcons = ['💎', '🌟', '👑'];
    } else if (currentTier == 3) {
      tierIcons = ['🏆', '⚔️', '🛡️'];
    } else {
      tierIcons = ['🌌', '✨', '🎯'];
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E22),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.orange.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.08),
                blurRadius: 30,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.orange.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _fireAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _fireAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6D00), Color(0xFFDD2C00)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.5),
                                blurRadius: 12,
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'SEQUÊNCIA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Text(
                        'TIER $currentTier',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFFB300), Color(0xFFDD2C00)],
                          ).createShader(bounds),
                          child: Text(
                            '$currentStreak',
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, left: 6),
                          child: Text(
                            'DIAS',
                            style: TextStyle(
                              color: Colors.orange.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      currentStreak == 0
                          ? 'Complete todas as fixas hoje!'
                          : hasCompletedTier
                              ? '🎉 Tier $currentTier completo!'
                              : 'Faltam $daysToNext dias para $nextMilestone',
                      style: TextStyle(
                        color: Colors.orange.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progressToNext,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFB300), Color(0xFFDD2C00)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.7),
                                  blurRadius: 8,
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        milestones.length,
                        (i) => _buildMilestoneChip(
                          theme: theme,
                          icon: tierIcons[i],
                          days: milestones[i],
                          achieved: currentStreak >= milestones[i],
                          inProgress: !hasCompletedTier && nextMilestone == milestones[i],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events_rounded,
                              color: Colors.amber.shade400, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Melhor: ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$bestStreak dias',
                            style: TextStyle(
                              color: Colors.amber.shade400,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneChip({
    required RankTheme theme,
    required String icon,
    required int days,
    required bool achieved,
    required bool inProgress,
  }) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: achieved
                    ? const LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFDD2C00)],
                      )
                    : null,
                color: achieved ? null : Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: inProgress
                      ? Colors.orange.withOpacity(0.8)
                      : achieved
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.1),
                  width: inProgress ? 2 : 1.5,
                ),
                boxShadow: achieved
                    ? [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.5 * _glowAnimation.value),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 26,
                    color: achieved ? Colors.white : Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          '$days dias',
          style: TextStyle(
            color: achieved
                ? Colors.orange
                : inProgress
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white.withOpacity(0.2),
            fontSize: 10,
            fontWeight: achieved ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MISSIONS SUMMARY
  // ============================================================

  Widget _buildMissionsSummary(RankTheme theme) {
    final totalCompleted = _stats['totalCompleted'] ?? 0;
    final totalMissions = _stats['totalMissions'] ?? 0;
    final totalXpGained = _stats['totalXpGained'] ?? 0;
    final progress = totalMissions > 0 ? totalCompleted / totalMissions : 0.0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E22),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.primary.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.flag_rounded, color: theme.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'MISSÕES DE HOJE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: progress >= 1.0
                            ? Colors.green.withOpacity(0.15)
                            : theme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: progress >= 1.0
                              ? Colors.green.withOpacity(0.4)
                              : theme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        progress >= 1.0 ? '✓ COMPLETO' : '$totalCompleted/$totalMissions',
                        style: TextStyle(
                          color: progress >= 1.0 ? Colors.green : theme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 8,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(theme.primary),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$totalCompleted',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'de $totalMissions',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          _buildMissionStatRow(
                            icon: Icons.star_rounded,
                            label: 'FIXAS',
                            value: '${_stats['fixedCompleted'] ?? 0}/${_stats['fixedTotal'] ?? 0}',
                            color: Colors.amber,
                          ),
                          const SizedBox(height: 10),
                          _buildMissionStatRow(
                            icon: Icons.auto_awesome_rounded,
                            label: 'CUSTOM',
                            value: '${_stats['customCompleted'] ?? 0}/${_stats['customTotal'] ?? 0}',
                            color: const Color(0xFF448AFF),
                          ),
                          const SizedBox(height: 10),
                          _buildMissionStatRow(
                            icon: Icons.bolt_rounded,
                            label: 'XP GANHO',
                            value: '+${_stats['totalXpGained'] ?? 0}',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ATTRIBUTES
  // ============================================================

  Widget _buildAttributesSection(RankTheme theme, dynamic user) {
    final attributes = user?.stats.attributes;
    if (attributes == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final attrData = [
      {'emoji': '📚', 'name': 'Estudo', 'value': attributes.study, 'color': const Color(0xFF448AFF)},
      {'emoji': '🎯', 'name': 'Disciplina', 'value': attributes.discipline, 'color': const Color(0xFF7C4DFF)},
      {'emoji': '⚔️', 'name': 'Shape', 'value': attributes.shape, 'color': const Color(0xFFFF6D00)},
      {'emoji': '🔥', 'name': 'Hábito', 'value': attributes.habit, 'color': const Color(0xFFDD2C00)},
      {'emoji': '⚡', 'name': 'Evolução', 'value': attributes.evolution, 'color': const Color(0xFFFFD600)},
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E22),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.primary.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.psychology_rounded, color: theme.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'ATRIBUTOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: attrData.asMap().entries.map((entry) {
                    final attr = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: entry.key < attrData.length - 1 ? 14 : 0),
                      child: _buildAttrBarStyled(
                        theme: theme,
                        emoji: attr['emoji'] as String,
                        name: attr['name'] as String,
                        value: attr['value'] as int,
                        color: attr['color'] as Color,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttrBarStyled({
    required RankTheme theme,
    required String emoji,
    required String name,
    required int value,
    required Color color,
  }) {
    final progress = (value / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$value',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.6)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PRÓXIMO RANK
  // ============================================================

  Widget _buildNextRankSection(RankTheme theme, dynamic user) {
    final currentRank = user?.rank ?? 'E';
    final totalXp = user?.totalXp ?? 0;
    final ranks = AppConstants.ranks;
    final currentIndex = ranks.indexOf(currentRank);

    if (currentIndex == -1 || currentIndex >= ranks.length - 1) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E22),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.primary.withOpacity(0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withOpacity(0.2),
                  blurRadius: 20,
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, color: theme.primary, size: 32),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text(
                      'RANK MÁXIMO!',
                      style: TextStyle(
                        color: theme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Você alcançou o topo!',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final nextRank = ranks[currentIndex + 1];
    final currentRankXp = AppConstants.rankXpRequirements[currentRank] ?? 0;
    final nextRankXp = AppConstants.rankXpRequirements[nextRank] ?? 0;
    final xpNeededForRank = nextRankXp - currentRankXp;
    final xpInCurrentRank = totalXp - currentRankXp;
    final progress = xpNeededForRank > 0
        ? (xpInCurrentRank / xpNeededForRank).clamp(0.0, 1.0)
        : 0.0;
    final xpNeeded = (nextRankXp - totalXp).clamp(0, double.infinity).toInt();
    final rankColor = _getRankColor(nextRank);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E22),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: rankColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: rankColor.withOpacity(0.1 * _glowAnimation.value),
                    blurRadius: 24,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: rankColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.arrow_upward_rounded, color: rankColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'PRÓXIMO RANK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: rankColor.withOpacity(0.4 * _glowAnimation.value),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  )
                                ],
                              ),
                            ),
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    rankColor,
                                    Colors.transparent,
                                    rankColor.withOpacity(0.5),
                                    Colors.transparent,
                                    rankColor,
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: 78,
                              height: 78,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0A0A1A),
                              ),
                            ),
                            ClipOval(
                              child: Image.asset(
                                'assets/images/rank/rank_${nextRank.toLowerCase()}.png',
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 70,
                                  height: 70,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                  child: Center(
                                    child: Text(
                                      nextRank,
                                      style: TextStyle(
                                        color: rankColor,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConstants.rankTitles[nextRank] ?? nextRank,
                                style: TextStyle(
                                  color: rankColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Faltam ${AppConstants.formatNumber(xpNeeded)} XP',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Stack(
                                children: [
                                  Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: progress,
                                    child: Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [rankColor, rankColor.withOpacity(0.6)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: rankColor.withOpacity(0.6),
                                            blurRadius: 8,
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(progress * 100).toStringAsFixed(1)}% do caminho',
                                style: TextStyle(
                                  color: rankColor.withOpacity(0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getRankColor(String rank) {
    switch (rank) {
      case 'E': return const Color(0xFF9E9E9E);
      case 'D': return const Color(0xFF66BB6A);
      case 'C': return const Color(0xFF42A5F5);
      case 'B': return const Color(0xFF7E57C2);
      case 'A': return const Color(0xFFFF7043);
      case 'S': return const Color(0xFFFFD700);
      case 'SS': return const Color(0xFF00E5FF);
      case 'SSS': return const Color(0xFFAB47BC);
      default: return Colors.grey;
    }
  }
}

// ============================================================
// CUSTOM PAINTERS
// ============================================================

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
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) =>
      old.color != color || old.dashCount != dashCount;
}
