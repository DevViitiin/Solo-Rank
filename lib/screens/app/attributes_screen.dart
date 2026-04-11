import 'package:flutter/material.dart';
import 'package:monarch/core/constants/app_constants.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/models/user_model.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

class AttributesScreen extends StatefulWidget {
  const AttributesScreen({Key? key}) : super(key: key);

  @override
  State<AttributesScreen> createState() => _AttributesScreenState();
}

class _AttributesScreenState extends State<AttributesScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _pulseAnimation;

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.loadUser(forceRefresh: false);
  }

  void _setupAnimations() {
    // Scale in animation
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    // Rotação contínua
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _rotateAnimation =
        Tween<double>(begin: 0, end: 2 * math.pi).animate(_rotateController);

    // Pulse animation (não usado mais, mas mantém para não quebrar)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Shimmer effect
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotateController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await context.read<UserProvider>().refreshUserData(force: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Atributos atualizados!'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Erro: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final user = userProvider.currentUser;
        if (user == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation(Colors.purple.shade300),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Carregando atributos...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final rank = user.rank;
        final theme = _getThemeForRank(rank);
        final attributes = user.stats.attributes;

        return Scaffold(
          backgroundColor: theme.background,
          body: RefreshIndicator(
            onRefresh: _refreshData,
            color: theme.primary,
            backgroundColor: theme.surface,
            child: Stack(
              children: [
                // Fundo animado
                AnimatedBuilder(
                  animation: _rotateAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: BackgroundWebPainter(
                        animation: _rotateAnimation,
                        color: theme.primary,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),

                // Conteúdo principal
                CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // AppBar
                    SliverAppBar(
                      expandedHeight: 140,
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          'ATRIBUTOS',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            fontSize: 20,
                            shadows: [
                              Shadow(
                                color: theme.primary.withOpacity(0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        centerTitle: true,
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.background,
                                theme.backgroundSecondary.withOpacity(0.8),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // 🕸️ TEIA PRINCIPAL - Radar Chart
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: _buildSpiderWebCard(theme, attributes),
                            ),

                            const SizedBox(height: 32),

                            // 📊 Stats Rápidos
                            _buildQuickStats(theme, attributes),

                            const SizedBox(height: 32),

                            // 📈 Barras de Progresso
                            _buildAttributeBars(theme, attributes),

                            const SizedBox(height: 32),

                            // 💡 Dicas de Evolução
                            _buildEvolutionTips(theme, attributes),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Loading overlay
                if (_isRefreshing)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.surface.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: theme.primary.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(theme.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Atualizando...',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🕸️ ========================================================================
  // TEIA / SPIDER WEB CARD
  // ========================================================================

  Widget _buildSpiderWebCard(RankTheme theme, UserAttributes attributes) {
    return Container(
      height: 360,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.surface.withOpacity(0.4),
            theme.surfaceLight.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: theme.primary.withOpacity(0.1),
            blurRadius: 60,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SpiderWebChart(
        attributes: {
          'Disciplina': attributes.discipline.toDouble(),
          'Hábito': attributes.habit.toDouble(),
          'Estudo': attributes.study.toDouble(),
          'Shape': attributes.shape.toDouble(),
          'Evolução': attributes.evolution.toDouble(),
        },
        maxValue: AppConstants.maxAttributePoints.toDouble(),
        theme: theme,
      ),
    );
  }

  // 📊 ========================================================================
  // STATS RÁPIDOS
  // ========================================================================

  Widget _buildQuickStats(RankTheme theme, UserAttributes attributes) {
    final total = attributes.discipline +
        attributes.habit +
        attributes.study +
        attributes.shape +
        attributes.evolution;
    final average = total / 5;
    final max = AppConstants.maxAttributePoints;
    final totalMax = max * 5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.15),
            theme.accent.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', '$total', totalMax.toString(), theme),
          Container(
              width: 1, height: 40, color: theme.primary.withOpacity(0.2)),
          _buildStatItem(
              'Média', average.toStringAsFixed(1), max.toString(), theme),
          Container(
              width: 1, height: 40, color: theme.primary.withOpacity(0.2)),
          _buildStatItem(
              'Maior', '${_getHighestAttribute(attributes)}', max.toString(), theme),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, String max, RankTheme theme) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: theme.primary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '/ $max',
          style: TextStyle(
            color: theme.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // 📈 ========================================================================
  // BARRAS DE PROGRESSO
  // ========================================================================

  Widget _buildAttributeBars(RankTheme theme, UserAttributes attributes) {
    final attrs = [
      {
        'name': '🎯 Disciplina',
        'value': attributes.discipline,
        'icon': Icons.track_changes
      },
      {
        'name': '🔥 Hábito',
        'value': attributes.habit,
        'icon': Icons.local_fire_department
      },
      {'name': '📚 Estudo', 'value': attributes.study, 'icon': Icons.school},
      {'name': '💪 Shape', 'value': attributes.shape, 'icon': Icons.fitness_center},
      {
        'name': '⚡ Evolução',
        'value': attributes.evolution,
        'icon': Icons.trending_up
      },
    ];

    return Column(
      children: attrs.map((attr) {
        return _buildAnimatedAttributeBar(
          name: attr['name'] as String,
          value: attr['value'] as int,
          icon: attr['icon'] as IconData,
          theme: theme,
        );
      }).toList(),
    );
  }

  Widget _buildAnimatedAttributeBar({
    required String name,
    required int value,
    required IconData icon,
    required RankTheme theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TweenAnimationBuilder<double>(
        tween:
            Tween(begin: 0.0, end: value / AppConstants.maxAttributePoints),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.surface.withOpacity(0.7),
                  theme.surfaceLight.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.primary.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withOpacity(progress * 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: theme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$value / ${AppConstants.maxAttributePoints}',
                      style: TextStyle(
                        color: theme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    // Background bar
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.surfaceLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // Progress bar com shimmer
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.primary,
                                  theme.accent,
                                  theme.primary,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primary.withOpacity(0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                  stops: [
                                    (_shimmerController.value - 0.3)
                                        .clamp(0.0, 1.0),
                                    _shimmerController.value,
                                    (_shimmerController.value + 0.3)
                                        .clamp(0.0, 1.0),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 💡 ========================================================================
  // DICAS DE EVOLUÇÃO
  // ========================================================================

  Widget _buildEvolutionTips(RankTheme theme, UserAttributes attributes) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.surface.withOpacity(0.6),
            theme.surfaceLight.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lightbulb,
                  color: theme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'COMO EVOLUIR',
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTip(
            '🎯 Disciplina',
            'Mantenha seu streak ativo e complete todas as missões fixas.',
            theme,
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildTip(
            '🔥 Hábito',
            'Complete TODAS as missões do dia sem falhar.',
            theme,
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildTip(
            '📚 Estudo',
            'Foque em missões relacionadas a estudo e leitura.',
            theme,
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildTip(
            '💪 Shape',
            'Complete missões de treino e exercícios físicos.',
            theme,
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildTip(
            '⚡ Evolução',
            'Suba de nível e de rank para ganhar grandes bônus.',
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String title, String description, RankTheme theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: theme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.primary.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            Icons.check,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // HELPERS
  // ========================================================================

  int _getHighestAttribute(UserAttributes attrs) {
    return [
      attrs.discipline,
      attrs.habit,
      attrs.study,
      attrs.shape,
      attrs.evolution,
    ].reduce((a, b) => a > b ? a : b);
  }

  RankTheme _getThemeForRank(String rank) {
    return RankThemes.getTheme(rank);
  }
}

// ============================================================================
// 🕸️ SPIDER WEB CHART (TEIA)
// ============================================================================

class SpiderWebChart extends StatelessWidget {
  final Map<String, double> attributes;
  final double maxValue;
  final RankTheme theme;

  const SpiderWebChart({
    Key? key,
    required this.attributes,
    required this.maxValue,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SpiderWebPainter(
        attributes: attributes,
        maxValue: maxValue,
        theme: theme,
      ),
      size: const Size(320, 320),
    );
  }
}

class SpiderWebPainter extends CustomPainter {
  final Map<String, double> attributes;
  final double maxValue;
  final RankTheme theme;

  SpiderWebPainter({
    required this.attributes,
    required this.maxValue,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 3.2;
    final angleStep = (2 * math.pi) / attributes.length;

    // 1. Desenhar teia de fundo (grid)
    _drawWebGrid(canvas, center, radius, angleStep);

    // 2. Desenhar dados do usuário
    _drawUserData(canvas, center, radius, angleStep);

    // 3. Desenhar labels
    _drawLabels(canvas, center, radius, angleStep);
  }

  void _drawWebGrid(
      Canvas canvas, Offset center, double radius, double angleStep) {
    // Círculos concêntricos (níveis da teia)
    for (int i = 1; i <= 5; i++) {
      final currentRadius = radius * (i / 5);

      // Círculo
      final circlePaint = Paint()
        ..color = theme.primary.withOpacity(0.1 + (i * 0.05))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, currentRadius, circlePaint);
    }

    // Linhas radiais (fios da teia)
    for (int i = 0; i < attributes.length; i++) {
      final angle = i * angleStep - math.pi / 2;
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final linePaint = Paint()
        ..color = theme.primary.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawLine(center, endPoint, linePaint);
    }
  }

  void _drawUserData(
      Canvas canvas, Offset center, double radius, double angleStep) {
    final values = attributes.values.toList();
    final path = Path();

    // Primeiro desenha múltiplos glows
    for (int glowLevel = 4; glowLevel > 0; glowLevel--) {
      final glowPath = Path();

      for (int i = 0; i < values.length; i++) {
        final angle = i * angleStep - math.pi / 2;
        final value = values[i];
        final normalizedValue = (value / maxValue).clamp(0.0, 1.0);
        final currentRadius = radius * normalizedValue;

        final point = Offset(
          center.dx + currentRadius * math.cos(angle),
          center.dy + currentRadius * math.sin(angle),
        );

        if (i == 0) {
          glowPath.moveTo(point.dx, point.dy);
        } else {
          glowPath.lineTo(point.dx, point.dy);
        }
      }
      glowPath.close();

      final glowPaint = Paint()
        ..color = theme.primary.withOpacity(0.15 * glowLevel / 4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12.0 * glowLevel
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15.0 * glowLevel);

      canvas.drawPath(glowPath, glowPaint);
    }

    // Criar path para os dados
    for (int i = 0; i < values.length; i++) {
      final angle = i * angleStep - math.pi / 2;
      final value = values[i];
      final normalizedValue = (value / maxValue).clamp(0.0, 1.0);
      final currentRadius = radius * normalizedValue;

      final point = Offset(
        center.dx + currentRadius * math.cos(angle),
        center.dy + currentRadius * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    // Preenchimento com gradiente
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          theme.primary.withOpacity(0.6),
          theme.accent.withOpacity(0.4),
          theme.primary.withOpacity(0.2),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    // Borda principal
    final borderPaint = Paint()
      ..color = theme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);

    // Desenhar pontos nos vértices
    for (int i = 0; i < values.length; i++) {
      final angle = i * angleStep - math.pi / 2;
      final value = values[i];
      final normalizedValue = (value / maxValue).clamp(0.0, 1.0);
      final currentRadius = radius * normalizedValue;

      final point = Offset(
        center.dx + currentRadius * math.cos(angle),
        center.dy + currentRadius * math.sin(angle),
      );

      // Glow do ponto
      canvas.drawCircle(
        point,
        8,
        Paint()
          ..color = theme.primary.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Ponto interno (core)
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white,
              theme.primary,
            ],
          ).createShader(Rect.fromCircle(center: point, radius: 5)),
      );

      // Borda do ponto
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawLabels(
      Canvas canvas, Offset center, double radius, double angleStep) {
    final labels = attributes.keys.toList();
    final values = attributes.values.toList();

    for (int i = 0; i < labels.length; i++) {
      final angle = i * angleStep - math.pi / 2;
      final labelRadius = radius + 35;

      final point = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );

      // Desenhar nome do atributo
      final textSpan = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          point.dx - textPainter.width / 2,
          point.dy - textPainter.height / 2 - 8,
        ),
      );

      // Desenhar valor
      final value = values[i].toInt();
      final valueSpan = TextSpan(
        text: '$value',
        style: TextStyle(
          color: theme.primary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: theme.primary.withOpacity(0.5),
              blurRadius: 8,
            ),
          ],
        ),
      );

      final valuePainter = TextPainter(
        text: valueSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      valuePainter.layout();
      valuePainter.paint(
        canvas,
        Offset(
          point.dx - valuePainter.width / 2,
          point.dy + 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// BACKGROUND WEB PAINTER
// ============================================================================

class BackgroundWebPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  BackgroundWebPainter({
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Desenhar teia de fundo rotacionando
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) + animation.value;

      final endX = centerX + size.width * math.cos(angle);
      final endY = centerY + size.height * math.sin(angle);

      canvas.drawLine(
        Offset(centerX, centerY),
        Offset(endX, endY),
        paint,
      );
    }

    // Círculos concêntricos
    for (int i = 1; i <= 6; i++) {
      final radius = (size.width / 2) * (i / 6);
      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        paint..color = color.withOpacity(0.02),
      );
    }
  }

  @override
  bool shouldRepaint(BackgroundWebPainter oldDelegate) => true;
}
