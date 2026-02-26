import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monarch/constants/app_constants.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:monarch/models/mission_model.dart';
import 'package:monarch/screens/screens_app/animated_particles.dart';
import 'package:monarch/screens/screens_init/login_screen.dart';
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
  
  // Dados carregados
  Map<String, dynamic> _todayMissions = {};
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  
  // Animações
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _fireController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fireAnimation;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
  }
  
  void _setupAnimations() {
    // Animação de pulso para o rank card
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Shimmer para loading states
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    // Animação de fogo para streak
    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _fireAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _fireController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _fireController.dispose();
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
      
      // Carregar missões do dia
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
      
      // Calcular estatísticas
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
    
    // Contar missões fixas
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
    
    // Contar missões customizadas
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
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }
  
  /// Mostra diálogo de confirmação para logout
  Future<void> _showLogoutDialog(RankTheme theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: theme.primary,
              size: 28,
            ),
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
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: theme.primary.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Sair',
              style: TextStyle(
                color: theme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      _performLogout();
    }
  }
  
  /// Realiza o logout do usuário
  Future<void> _performLogout() async {
    try {
      // Limpar dados do usuário
      final userProvider = context.read<UserProvider>();
      await userProvider.logout();
      
      
      // Navegar para tela de login
      if (!mounted) return;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );

    } catch (e) {
      AppConstants.debugLog('Erro ao fazer logout: $e');
      
      // Mostrar erro ao usuário
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao sair da conta. Tente novamente.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
          backgroundColor: theme.background,
          body: AnimatedParticlesBackground(
            particleColor: theme.primary,
            particleCount: 30,
            child: Container(
              decoration: BoxDecoration(
                gradient: theme.backgroundGradient,
              ),
              child: SafeArea(
                child: _loading
                    ? _buildLoadingState(theme)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: theme.primary,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // Header com saudação
                            _buildHeader(theme, user),
                            
                            // Rank Card com Pulsar
                            _buildRankCard(theme, user),
                            
                            // Progress Overview
                            _buildProgressOverview(theme, user),
                            
                            // Quick Stats Grid
                            _buildQuickStatsGrid(theme, user),
                            
                            // 🔥 NOVO: Streak Milestones Card
                            _buildStreakMilestonesCard(theme, user),
                            
                            // Today's Mission Summary
                            _buildTodayMissionsSummary(theme),
                            
                            // Attributes Preview
                            _buildAttributesPreview(theme, user),
                            
                            // Próximo Rank
                            _buildNextRankCard(theme, user),
                            
                            // Bottom Padding
                            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                          ],
                        ),
                      ),
              ),
            ),
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
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation(theme.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Carregando...',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  // ============================================================================
  // HEADER
  // ============================================================================
  
  Widget _buildHeader(RankTheme theme, dynamic user) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saudação
            Text(
              _getGreeting(),
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            
            // Nome do usuário
            Row(
              children: [
                Expanded(
                  child: Text(
                    user?.name ?? 'Caçador',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Botão de Logout
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showLogoutDialog(theme),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.surface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.surfaceLight.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: theme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // ============================================================================
  // RANK CARD COM PULSAR
  // ============================================================================
  
  Widget _buildRankCard(RankTheme theme, dynamic user) {
  final isBeginner = (user?.rank ?? 'E') == 'E';

  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isBeginner ? 1.0 : _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isBeginner ? const Color(0xFF1C1C1C) : null,
                gradient: isBeginner ? null : theme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isBeginner
                    ? [
                        const BoxShadow(
                          color: Colors.black38,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: theme.primary.withOpacity(0.35),
                          blurRadius: 24,
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // Avatar
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
                        width: 72,
                        height: 72,
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

                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.rankTitles[user?.rank ?? 'E'] ?? 'CAÇADOR',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: theme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'NÍVEL ${user?.level ?? 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
  
  Widget _buildProgressOverview(RankTheme theme, dynamic user) {
    final xpForNext = context.read<UserProvider>().xpForNextLevel;
    final progress = context.read<UserProvider>().levelProgress;
    
    return SliverToBoxAdapter(
      child: AnimatedParticlesBackground(
      particleColor: theme.primary,
      particleCount: 30,
    child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 13),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.surfaceLight.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    color: theme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PROGRESSO PARA NÍVEL ${(user?.level ?? 1) + 1}',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.surfaceLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: theme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // XP Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${user?.xp ?? 0} XP',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Faltam $xpForNext XP',
                    style: TextStyle(
                      color: theme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      )
    );
  }
  
  // ============================================================================
  // QUICK STATS GRID
  // ============================================================================
  
  Widget _buildQuickStatsGrid(RankTheme theme, dynamic user) {
    return SliverToBoxAdapter(
      child: AnimatedParticlesBackground(
      particleColor: theme.primary,
      particleCount: 30,
    child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            // Total XP
            Expanded(
              child: _buildStatCard(
                theme: theme,
                icon: Icons.bolt_rounded,
                label: 'XP TOTAL',
                value: AppConstants.formatNumber(user?.totalXp ?? 0),
                gradient: LinearGradient(
                  colors: [Colors.amber.shade700, Colors.orange.shade600],
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Missões Completadas
            Expanded(
              child: _buildStatCard(
                theme: theme,
                icon: Icons.task_alt_rounded,
                label: 'MISSÕES',
                value: '${user?.stats.totalMissionsCompleted ?? 0}',
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.teal.shade600],
                ),
              ),
            ),
          ],
        ),
      ),
      )
    );
  }
  
  Widget _buildStatCard({
    required RankTheme theme,
    required IconData icon,
    required String label,
    required String value,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
  
  // ============================================================================
  // 🔥 NOVO: STREAK MILESTONES CARD
  // ============================================================================
  
  Widget _buildStreakMilestonesCard(RankTheme theme, dynamic user) {
    final currentStreak = user?.stats.currentStreak ?? 0;
    final bestStreak = user?.stats.bestStreak ?? 0;
    
    // ✅ NOVO: Sistema de tiers dinâmico
    final streakService = StreakService.instance;
    final milestones = streakService.getCurrentTierMilestones(currentStreak);
    final currentTier = streakService.getCurrentTier(currentStreak);
    final nextMilestone = streakService.getNextMilestone(currentStreak);
    final hasCompletedTier = streakService.hasCompletedCurrentTier(currentStreak);
    
    final progressToNext = currentStreak / nextMilestone;
    final daysToNext = nextMilestone - currentStreak;
    
    // Ícones baseados no tier
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
      child: AnimatedParticlesBackground(
        particleColor: theme.primary,
        particleCount: 30,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _fireAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _fireAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange.shade600, Colors.red.shade600],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SEQUÊNCIA - TIER $currentTier',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Main Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.shade700.withOpacity(0.15),
                      Colors.red.shade800.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Current Streak Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$currentStreak',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            foreground: Paint()
                              ..shader = LinearGradient(
                                colors: [Colors.orange.shade400, Colors.red.shade600],
                              ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'dias',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      currentStreak == 0
                          ? 'Complete todas as fixas hoje!'
                          : hasCompletedTier
                              ? '🎉 Tier $currentTier completo! Próximo: ${milestones[0] + 30} dias'
                              : 'Faltam $daysToNext dias para $nextMilestone',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Progress to Next Milestone
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progressToNext.clamp(0.0, 1.0),
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade400, Colors.red.shade600],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Milestones Grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (int i = 0; i < milestones.length; i++)
                          _buildMilestoneIndicator(
                            theme: theme,
                            icon: tierIcons[i],
                            label: 'Meta ${i + 1}',
                            days: milestones[i],
                            achieved: currentStreak >= milestones[i],
                            inProgress: !hasCompletedTier && nextMilestone == milestones[i],
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Tier Info & Best Streak
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Tier progress
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.military_tech_rounded,
                                color: Colors.orange.shade400,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tier $currentTier: ',
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${milestones[0]}-${milestones[2]} dias',
                                style: TextStyle(
                                  color: Colors.orange.shade400,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Divider
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Best Streak
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.emoji_events_rounded,
                                color: Colors.amber.shade400,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Melhor Sequência: ',
                                style: TextStyle(
                                  color: theme.textSecondary,
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
  
  Widget _buildMilestoneIndicator({
    required RankTheme theme,
    required String icon,
    required String label,
    required int days,
    required bool achieved,
    required bool inProgress,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: achieved
                ? LinearGradient(
                    colors: [Colors.orange.shade400, Colors.red.shade600],
                  )
                : null,
            color: achieved ? null : Colors.white.withOpacity(0.1),
            border: Border.all(
              color: inProgress
                  ? Colors.orange.shade400
                  : achieved
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.2),
              width: inProgress ? 3 : 2,
            ),
            boxShadow: achieved
                ? [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              icon,
              style: TextStyle(
                fontSize: 28,
                color: achieved ? Colors.white : Colors.white.withOpacity(0.3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: achieved
                ? Colors.orange.shade400
                : inProgress
                    ? theme.textSecondary
                    : theme.textTertiary,
            fontSize: 11,
            fontWeight: achieved || inProgress ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        Text(
          '$days dias',
          style: TextStyle(
            color: theme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  // ============================================================================
  // TODAY'S MISSIONS SUMMARY
  // ============================================================================
  
  Widget _buildTodayMissionsSummary(RankTheme theme) {
    final totalCompleted = _stats['totalCompleted'] ?? 0;
    final totalMissions = _stats['totalMissions'] ?? 0;
    final totalXpGained = _stats['totalXpGained'] ?? 0;
    final progress = totalMissions > 0 ? totalCompleted / totalMissions : 0.0;
    
    return SliverToBoxAdapter(
      child: AnimatedParticlesBackground(
      particleColor: theme.primary,
      particleCount: 30,
    child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  color: theme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'MISSÕES DE HOJE',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.surface.withOpacity(0.8),
                    theme.surfaceLight.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.surfaceLight.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Progress Circle
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background circle
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 10,
                            backgroundColor: theme.surfaceLight.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation(
                              theme.surfaceLight.withOpacity(0.3),
                            ),
                          ),
                        ),
                        // Progress circle
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 10,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation(theme.primary),
                          ),
                        ),
                        // Center text
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$totalCompleted',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'de $totalMissions',
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMissionStat(
                          theme,
                          icon: Icons.star_rounded,
                          label: 'Fixas',
                          value: '${_stats['fixedCompleted']}/${_stats['fixedTotal']}',
                          color: Colors.amber,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: theme.surfaceLight.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _buildMissionStat(
                          theme,
                          icon: Icons.auto_awesome_rounded,
                          label: 'Custom',
                          value: '${_stats['customCompleted']}/${_stats['customTotal']}',
                          color: Colors.blue,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: theme.surfaceLight.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _buildMissionStat(
                          theme,
                          icon: Icons.bolt_rounded,
                          label: 'XP',
                          value: '+$totalXpGained',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      )
    );
  }
  
  Widget _buildMissionStat(
    RankTheme theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: theme.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
  
  // ============================================================================
  // ATTRIBUTES PREVIEW
  // ============================================================================
  
  Widget _buildAttributesPreview(RankTheme theme, dynamic user) {
    final attributes = user?.stats.attributes;
    
    if (attributes == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    return SliverToBoxAdapter(
      child: AnimatedParticlesBackground(
      particleColor: theme.primary,
      particleCount: 30,
    child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.psychology_rounded,
                  color: theme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'ATRIBUTOS',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Attributes Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.surfaceLight.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildAttributeBar(theme, '📚', 'Estudo', attributes.study, Colors.blue),
                  const SizedBox(height: 12),
                  _buildAttributeBar(theme, '🎯', 'Disciplina', attributes.discipline, Colors.purple),
                  const SizedBox(height: 12),
                  _buildAttributeBar(theme, '⚔️', 'Shape', attributes.shape, Colors.orange),
                  const SizedBox(height: 12),
                  _buildAttributeBar(theme, '🔥', 'Habito', attributes.habit, Colors.red),
                  const SizedBox(height: 12),
                  _buildAttributeBar(theme, '⚡', 'Evolução', attributes.evolution, Colors.amber),
                ],
              ),
            ),
          ],
        ),
      ),
      )
    );
  }
  
  Widget _buildAttributeBar(
    RankTheme theme,
    String emoji,
    String name,
    int value,
    Color color,
  ) {
    final maxValue = 100;
    final progress = (value / maxValue).clamp(0.0, 1.0);
    
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$value',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.surfaceLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // ============================================================================
  // PRÓXIMO RANK CARD
  // ============================================================================
  
  Widget _buildNextRankCard(RankTheme theme, dynamic user) {
    final currentRank = user?.rank ?? 'E';
    final totalXp = user?.totalXp ?? 0;
    final ranks = AppConstants.ranks;
    final currentIndex = ranks.indexOf(currentRank);
    
    if (currentIndex == -1 || currentIndex >= ranks.length - 1) {
      // Rank máximo alcançado
      return SliverToBoxAdapter(
        child: AnimatedParticlesBackground(
      particleColor: theme.primary,
      particleCount: 30,
    child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primary.withOpacity(0.3),
                  theme.accent.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.primary.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withOpacity(0.3),
                  blurRadius: 20,
                ),
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
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        )
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
    
    return SliverToBoxAdapter(
      child: AnimatedParticlesBackground(
      particleColor: theme.primary,
      particleCount: 30,
    child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.arrow_upward_rounded,
                  color: theme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'PRÓXIMO RANK',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Next Rank Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getRankColor(nextRank).withOpacity(0.2),
                    _getRankColor(nextRank).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getRankColor(nextRank).withOpacity(0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getRankColor(nextRank).withOpacity(0.2),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Next Rank Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getRankColor(nextRank).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          nextRank,
                          style: TextStyle(
                            color: _getRankColor(nextRank),
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 17),
                      
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.rankTitles[nextRank] ?? nextRank,
                              style: TextStyle(
                                color: _getRankColor(nextRank),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.trending_up_rounded,
                                  color: theme.textSecondary,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Faltam ${AppConstants.formatNumber(xpNeeded)} XP',
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: theme.surfaceLight.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getRankColor(nextRank),
                                  _getRankColor(nextRank).withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _getRankColor(nextRank).withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}% do caminho',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      )
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