import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monarch/core/constants/app_constants.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/models/user_model.dart';
import 'dart:math' as math;

// ============================================================================
// ROTA CUSTOMIZADA — slide da direita com fade
// ============================================================================

/// Rota customizada com transição slide+fade para o perfil do ranking.
class RankingProfileRoute extends PageRouteBuilder {
  final UserModel user;
  final int position;

  RankingProfileRoute({required this.user, required this.position})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              RankingProfileScreen(user: user, position: position),
          transitionDuration: const Duration(milliseconds: 480),
          reverseTransitionDuration: const Duration(milliseconds: 380),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6)),
            );
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child),
            );
          },
        );
}

// ============================================================================
// RANKING PROFILE SCREEN
// ============================================================================

/// Tela de perfil detalhado de um jogador do ranking.
///
/// Exibe informações completas do jogador:
/// - Avatar animado com anel rotativo e glow pulsante
/// - Badge de XP com shimmer
/// - Estatísticas (nível, rank, streak, missões)
/// - Barras de atributos com animação de preenchimento
/// - Seção de conquistas
///
/// Todas as animações são coordenadas via stagger (entrada escalonada).
class RankingProfileScreen extends StatefulWidget {
  final UserModel user;
  final int position;

  const RankingProfileScreen({
    Key? key,
    required this.user,
    required this.position,
  }) : super(key: key);

  @override
  State<RankingProfileScreen> createState() => _RankingProfileScreenState();
}

class _RankingProfileScreenState extends State<RankingProfileScreen>
    with TickerProviderStateMixin {
  // ── controllers ───────────────────────────────────────────────────────────
  late AnimationController _entranceController;
  late AnimationController _glowController;
  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late AnimationController _barController;
  late AnimationController _shimmerController;
  late AnimationController _floatController;

  // ── animations ────────────────────────────────────────────────────────────
  late Animation<double> _entranceAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _barAnim;
  late Animation<double> _shimmerAnim;
  late Animation<double> _floatAnim;

  late Animation<double> _headerSlide;
  late Animation<double> _statsSlide;
  late Animation<double> _attrsSlide;

  late RankTheme _theme;

  @override
  void initState() {
    super.initState();
    _theme = RankThemes.getTheme(widget.user.rank);
    _setupAnimations();
  }

  void _setupAnimations() {
    // Entrance — stagger geral
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _entranceAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    // Seções com delays escalonados
    _headerSlide = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _statsSlide = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _attrsSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Brilho pulsante
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Rotação do anel
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _rotateAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Pulso do avatar
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Barras de atributos — animação de preenchimento
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _barAnim = CurvedAnimation(
      parent: _barController,
      curve: Curves.easeOutCubic,
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _barController.forward();
    });

    // Shimmer do XP badge
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Float suave do avatar
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    _rotateController.dispose();
    _pulseController.dispose();
    _barController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF06060F),
        body: Stack(
          children: [
            // ── camadas de fundo ─────────────────────────────────────────
            _buildBackground(),

            // ── conteúdo ─────────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildHeroSection(),
                          _buildXpBadge(),
                          const SizedBox(height: 24),
                          _buildStatsSection(),
                          const SizedBox(height: 16),
                          _buildAttributesSection(),
                          const SizedBox(height: 16),
                          _buildAchievementsSection(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FUNDO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Stack(
        children: [
          // Base escura
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.4,
                colors: [
                  _theme.primary.withOpacity(0.18 * _glowAnim.value),
                  const Color(0xFF06060F),
                ],
              ),
            ),
          ),
          // Grid sutil
          CustomPaint(
            painter: _GridPainter(color: _theme.primary.withOpacity(0.035)),
            size: Size.infinite,
          ),
          // Orb de luz superior
          Positioned(
            top: -80,
            left: MediaQuery.of(context).size.width / 2 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _theme.primary.withOpacity(0.12 * _glowAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Orb secundário
          Positioned(
            bottom: 200,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _theme.accent.withOpacity(0.08 * _glowAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Botão voltar
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E2A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _theme.primary.withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _theme.primary
                          .withOpacity(0.1 * _glowAnim.value),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _theme.primary,
                  size: 18,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Título
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERFIL DO JOGADOR',
                  style: TextStyle(
                    color: _theme.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  widget.user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Badge de posição
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _theme.primary.withOpacity(0.25),
                    _theme.accent.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _theme.primary.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _theme.primary
                        .withOpacity(0.25 * _glowAnim.value),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getMedal(widget.position),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '#${widget.position}',
                    style: TextStyle(
                      color: _theme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HERO — avatar + nome + rank
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeroSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceAnim, _headerSlide]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _headerSlide.value),
        child: Opacity(
          opacity: _entranceAnim.value.clamp(0.0, 1.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Column(
              children: [
                // Avatar animado
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_glowAnim, _rotateAnim, _pulseAnim, _floatAnim]),
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: Transform.scale(
                      scale: _pulseAnim.value,
                      child: _buildAnimatedAvatar(size: 120),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Nome
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.white, _theme.primary.withOpacity(0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    widget.user.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Chips rank + nível
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildChip(
                      gradient: LinearGradient(
                          colors: [_theme.primary, _theme.accent]),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/rank/rank_${widget.user.rank.toLowerCase()}.png',
                            width: 18,
                            height: 18,
                            errorBuilder: (_, __, ___) => Text(
                              widget.user.rank,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'RANK ${widget.user.rank}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildChip(
                      border: Border.all(
                          color: _theme.primary.withOpacity(0.5), width: 1.5),
                      color: _theme.primary.withOpacity(0.12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.military_tech_rounded,
                              color: _theme.primary, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            'NÍVEL ${widget.user.level}',
                            style: TextStyle(
                              color: _theme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
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

  // ── XP badge com shimmer ──────────────────────────────────────────────────

  Widget _buildXpBadge() {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceAnim, _shimmerAnim, _glowAnim]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _statsSlide.value),
        child: Opacity(
          opacity: (_entranceAnim.value * 2 - 0.5).clamp(0.0, 1.0),
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  _theme.primary.withOpacity(0.22),
                  _theme.accent.withOpacity(0.14),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(
                color: _theme.primary.withOpacity(0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _theme.primary
                      .withOpacity(0.2 * _glowAnim.value),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'XP TOTAL ACUMULADO',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [Colors.amber, Colors.white, Colors.amber],
                            stops: [
                              (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                              _shimmerAnim.value.clamp(0.0, 1.0),
                              (_shimmerAnim.value + 0.3).clamp(0.0, 1.0),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            AppConstants.formatNumber(widget.user.totalXp),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStatsSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceAnim, _statsSlide]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _statsSlide.value),
        child: Opacity(
          opacity: ((_entranceAnim.value - 0.2) * 1.5).clamp(0.0, 1.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(Icons.bar_chart_rounded, 'ESTATÍSTICAS'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0C20),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _theme.primary.withOpacity(0.12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.trending_up_rounded,
                              iconColor: Colors.white,
                              label: 'NÍVEL',
                              value: '${widget.user.level}',
                              isFirst: true,
                            ),
                          ),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.task_alt_rounded,
                              iconColor: const Color(0xFF00E676),
                              label: 'MISSÕES',
                              value: '${widget.user.stats.totalMissionsCompleted}',
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.05),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.local_fire_department_rounded,
                              iconColor: Colors.deepOrange,
                              label: 'SEQUÊNCIA',
                              value: '${widget.user.stats.currentStreak}d',
                              isFirst: true,
                            ),
                          ),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.workspace_premium_rounded,
                              iconColor: Colors.purple.shade300,
                              label: 'RECORDE',
                              value: '${widget.user.stats.bestStreak}d',
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
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isFirst = false,
  }) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: iconColor.withOpacity(0.25),
                ),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: iconColor.withOpacity(0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ATRIBUTOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAttributesSection() {
    final attrs = widget.user.stats.attributes;
    final attrData = [
      {
        'emoji': '🎯',
        'label': 'Disciplina',
        'value': attrs.discipline,
        'color': const Color(0xFF7C4DFF),
      },
      {
        'emoji': '🔥',
        'label': 'Hábito',
        'value': attrs.habit,
        'color': const Color(0xFFDD2C00),
      },
      {
        'emoji': '📚',
        'label': 'Estudo',
        'value': attrs.study,
        'color': const Color(0xFF448AFF),
      },
      {
        'emoji': '⚔️',
        'label': 'Shape',
        'value': attrs.shape,
        'color': const Color(0xFFFF6D00),
      },
      {
        'emoji': '⚡',
        'label': 'Evolução',
        'value': attrs.evolution,
        'color': const Color(0xFFFFD600),
      },
    ];

    return AnimatedBuilder(
      animation: Listenable.merge([_entranceAnim, _attrsSlide]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _attrsSlide.value),
        child: Opacity(
          opacity: ((_entranceAnim.value - 0.4) * 2).clamp(0.0, 1.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(Icons.psychology_rounded, 'ATRIBUTOS'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0C20),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _theme.primary.withOpacity(0.12),
                    ),
                  ),
                  child: Column(
                    children: attrData.asMap().entries.map((e) {
                      final attr = e.value;
                      final val = attr['value'] as int;
                      final color = attr['color'] as Color;
                      final emoji = attr['emoji'] as String;
                      final label = attr['label'] as String;
                      final maxPts = AppConstants.maxAttributePoints;
                      final targetProgress = (val / maxPts).clamp(0.0, 1.0);

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: e.key < attrData.length - 1 ? 18 : 0,
                        ),
                        child: _buildAttributeRow(
                          emoji: emoji,
                          label: label,
                          value: val,
                          maxValue: maxPts,
                          targetProgress: targetProgress,
                          color: color,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttributeRow({
    required String emoji,
    required String label,
    required int value,
    required int maxValue,
    required double targetProgress,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                '$value/$maxValue',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _barAnim,
          builder: (_, __) {
            final animatedProgress = targetProgress * _barAnim.value;
            return Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: animatedProgress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.55),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONQUISTAS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAchievementsSection() {
    final streak = widget.user.stats.currentStreak;
    final missions = widget.user.stats.totalMissionsCompleted;
    final level = widget.user.level;

    final badges = [
      if (streak >= 7)
        _BadgeData(
            emoji: '🔥',
            label: 'Sequência\n7 dias',
            color: Colors.deepOrange),
      if (streak >= 30)
        _BadgeData(
            emoji: '💎', label: 'Sequência\n30 dias', color: Colors.cyan),
      if (missions >= 50)
        _BadgeData(
            emoji: '⚔️', label: '50 Missões\nCompletas', color: Colors.orange),
      if (missions >= 100)
        _BadgeData(
            emoji: '🏆',
            label: '100 Missões\nCompletas',
            color: Colors.amber),
      if (level >= 10)
        _BadgeData(
            emoji: '🌟', label: 'Nível 10\nAlcançado', color: Colors.yellow),
      if (widget.position == 1)
        _BadgeData(emoji: '👑', label: 'Líder\nAbsoluto', color: Colors.amber),
      if (widget.position <= 3)
        _BadgeData(
            emoji: '🥇',
            label: 'Top 3\nRanking',
            color: const Color(0xFFFFD700)),
    ];

    if (badges.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _entranceAnim,
      builder: (_, __) => Opacity(
        opacity: ((_entranceAnim.value - 0.6) * 2.5).clamp(0.0, 1.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                  Icons.workspace_premium_rounded, 'CONQUISTAS'),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  physics: const BouncingScrollPhysics(),
                  itemCount: badges.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _buildBadgeCard(badges[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(_BadgeData badge) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C20),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: badge.color.withOpacity(0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: badge.color.withOpacity(0.1 * _glowAnim.value),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: badge.color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AVATAR ANIMADO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAnimatedAvatar({required double size}) {
    final isBeginner = widget.user.rank == 'E';
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow externo
        Container(
          width: size + 40,
          height: size + 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _theme.primary.withOpacity(0.35 * _glowAnim.value),
                blurRadius: 50,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: _theme.accent.withOpacity(0.15 * _glowAnim.value),
                blurRadius: 80,
                spreadRadius: 20,
              ),
            ],
          ),
        ),

        // Círculo tracejado externo
        Transform.rotate(
          angle: _rotateAnim.value * 0.5,
          child: CustomPaint(
            size: Size(size + 28, size + 28),
            painter: _DashedCirclePainter(
              color: _theme.primary.withOpacity(0.4),
              dashCount: 20,
            ),
          ),
        ),

        // Círculo tracejado interno (inverso)
        Transform.rotate(
          angle: -_rotateAnim.value * 0.3,
          child: CustomPaint(
            size: Size(size + 12, size + 12),
            painter: _DashedCirclePainter(
              color: _theme.accent.withOpacity(0.25),
              dashCount: 12,
            ),
          ),
        ),

        // Anel gradiente girando
        Container(
          width: size + 8,
          height: size + 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(_rotateAnim.value * 0.8),
              colors: isBeginner
                  ? [
                      Colors.grey.withOpacity(0.3),
                      Colors.transparent,
                      Colors.grey.withOpacity(0.3),
                      Colors.transparent,
                    ]
                  : [
                      _theme.primary,
                      _theme.accent.withOpacity(0.4),
                      Colors.transparent,
                      _theme.primary.withOpacity(0.6),
                      Colors.transparent,
                      _theme.primary,
                    ],
            ),
          ),
        ),

        // Fundo do avatar
        Container(
          width: size + 2,
          height: size + 2,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF0A0A1A),
          ),
        ),

        // Imagem do rank
        ClipOval(
          child: Image.asset(
            'assets/images/rank/rank_${widget.user.rank.toLowerCase()}.png',
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
                    _theme.primary.withOpacity(0.9),
                    _theme.primary.withOpacity(0.3),
                    const Color(0xFF0A0A1A),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Center(
                child: Text(
                  widget.user.rank,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Medal (top 3)
        if (widget.position <= 3)
          Positioned(
            bottom: 2,
            right: 2,
            child: Text(
              _getMedal(widget.position),
              style: const TextStyle(fontSize: 30),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionTitle(IconData icon, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _theme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _theme.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: _theme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    LinearGradient? gradient,
    Border? border,
    Color? color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: border,
        boxShadow: gradient != null
            ? [
                BoxShadow(
                  color: _theme.primary.withOpacity(0.35),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  String _getMedal(int position) {
    switch (position) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }
}

// ============================================================================
// BADGE DATA
// ============================================================================

class _BadgeData {
  final String emoji;
  final String label;
  final Color color;
  const _BadgeData({
    required this.emoji,
    required this.label,
    required this.color,
  });
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
