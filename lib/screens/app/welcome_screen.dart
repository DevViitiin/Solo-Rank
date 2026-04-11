import 'package:flutter/material.dart';
import 'package:monarch/core/auth_wrapper.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:monarch/screens/app/main_navigation.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

/// Tela de boas-vindas com animação épica de entrada.
///
/// Comportamento condicional:
/// - Se [showAnimation] = `true`: exibe animação de rank (avatar, nome,
///   frase motivacional) antes de navegar para [MainNavigation].
/// - Se [showAnimation] = `false`: renderiza [MainNavigation] diretamente.
///
/// A frase motivacional e o ícone variam conforme o rank do usuário.
class WelcomeScreen extends StatefulWidget {
  final bool showAnimation;

  const WelcomeScreen({
    Key? key,
    this.showAnimation = true,
  }) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  bool _showingAnimation = true;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _glowController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  bool _showMotivation = false;
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();

    // Se NÃO deve mostrar animação, vai direto pro MainNavigation
    if (!widget.showAnimation) {
      _showingAnimation = false;
      return;
    }

    _setupAnimations();
    _startAnimationSequence();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _scaleController.forward();

    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() => _showMotivation = true);

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _canContinue = true);
  }

  @override
  void dispose() {
    if (widget.showAnimation) {
      _fadeController.dispose();
      _scaleController.dispose();
      _glowController.dispose();
    }
    super.dispose();
  }

  RankTheme _getThemeForRank(String rank) {
    switch (rank.toUpperCase()) {
      case 'E':
        return RankThemes.e;
      case 'D':
        return RankThemes.d;
      case 'C':
        return RankThemes.c;
      case 'B':
        return RankThemes.b;
      case 'A':
        return RankThemes.a;
      case 'S':
        return RankThemes.s;
      case 'SS':
        return RankThemes.ss;
      case 'SSS':
        return RankThemes.sss;
      default:
        return RankThemes.e;
    }
  }

  String _getMotivationForRank(String rank) {
    switch (rank.toUpperCase()) {
      case 'E':
        return '"Todo grande caçador começou do zero.\nSua jornada épica começa agora!"';
      case 'D':
        return '"O primeiro passo foi dado.\nMostre do que você é capaz!"';
      case 'C':
        return '"Você está evoluindo.\nAlcance novos patamares!"';
      case 'B':
        return '"Sua determinação está dando frutos.\nO poder está crescendo!"';
      case 'A':
        return '"Poucos chegam até aqui.\nVocê é extraordinário!"';
      case 'S':
        return '"Elite entre os caçadores.\nSeu nome será lembrado!"';
      case 'SS':
        return '"Lendário! Você transcendeu\nos limites humanos!"';
      case 'SSS':
        return '"MONARCA SUPREMO!\nVocê alcançou o ápice absoluto!"';
      default:
        return '"Sua jornada começa agora!"';
    }
  }

  IconData _getIconForRank(String rank) {
    switch (rank.toUpperCase()) {
      case 'E':
        return Icons.person;
      case 'D':
        return Icons.shield;
      case 'C':
        return Icons.star;
      case 'B':
        return Icons.whatshot;
      case 'A':
        return Icons.auto_awesome;
      case 'S':
        return Icons.bolt;
      case 'SS':
        return Icons.flash_on;
      case 'SSS':
        return Icons.workspace_premium;
      default:
        return Icons.person;
    }
  }

  /// Navega para [MainNavigation] substituindo a rota atual.
  void _continueToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const MainNavigation(),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;
    final size = MediaQuery.of(context).size;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Se não está mostrando animação, mostra o MainNavigation direto
    if (!_showingAnimation) {
      return const MainNavigation();
    }

    // Mostra a animação de boas-vindas
    final theme = _getThemeForRank(user.rank);
    final motivation = _getMotivationForRank(user.rank);

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: theme.backgroundGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Partículas de fundo (limitadas à tela)
              ..._buildParticles(theme, size),

              // Conteúdo principal com ScrollView
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Topo: Título
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    theme.primaryGradient.createShader(bounds),
                                child: const Text(
                                  'SISTEMA ATIVADO',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 2,
                                width: 80,
                                decoration: BoxDecoration(
                                  gradient: theme.primaryGradient,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Centro: Avatar + Informações
                        Column(
                          children: [
                            // Avatar com rank (reduzido)
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: AnimatedBuilder(
                                animation: _glowAnimation,
                                builder: (context, child) {
                                  return Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.primary.withOpacity(
                                            0.3 * _glowAnimation.value,
                                          ),
                                          blurRadius: 30 * _glowAnimation.value,
                                          spreadRadius:
                                              8 * _glowAnimation.value,
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: theme.primaryGradient,
                                      ),
                                      padding: const EdgeInsets.all(5),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: theme.background,
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        child: ClipOval(
                                          child: Image.asset(
                                            'assets/images/rank_${user.rank.toLowerCase()}.jpg',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              decoration: BoxDecoration(
                                                gradient: theme.primaryGradient,
                                              ),
                                              child: Icon(
                                                _getIconForRank(user.rank),
                                                size: 60,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Nome do usuário
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                children: [
                                  Text(
                                    'BEM-VINDO',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 12,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ShaderMask(
                                    shaderCallback: (bounds) => theme
                                        .primaryGradient
                                        .createShader(bounds),
                                    child: Text(
                                      user.name.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Rank badge
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: theme.primaryGradient,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: theme.neonGlowEffect,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getIconForRank(user.rank),
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'RANK ${user.rank}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Rodapé: Motivação + Botão
                        Column(
                          children: [
                            // Frase motivacional
                            AnimatedOpacity(
                              opacity: _showMotivation ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 600),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.primary.withOpacity(0.1),
                                      theme.accent.withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  motivation,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Botão continuar
                            AnimatedOpacity(
                              opacity: _canContinue ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 600),
                              child: GestureDetector(
                                onTap: _canContinue ? _continueToHome : null,
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: theme.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: theme.neonGlowEffect,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'INICIAR JORNADA',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  List<Widget> _buildParticles(RankTheme theme, Size size) {
    final random = math.Random(42); // Seed fixo para consistência
    final particles = <Widget>[];

    // Reduzido para 10 partículas e dentro dos limites da tela
    for (int i = 0; i < 10; i++) {
      final particleSize = 2.0 + random.nextDouble() * 3;
      final left = random.nextDouble() * (size.width - 20);
      final top = random.nextDouble() * (size.height - 20);
      final duration = 2000 + random.nextInt(2000);

      particles.add(
        Positioned(
          left: left,
          top: top,
          child: _Particle(
            size: particleSize,
            duration: duration,
            color: theme.primary,
          ),
        ),
      );
    }

    return particles;
  }
}

/// Partícula animada individual com fade pulsante.
///
/// Widget separado para evitar rebuilds desnecessários do pai.
class _Particle extends StatefulWidget {
  final double size;
  final int duration;
  final Color color;

  const _Particle({
    required this.size,
    required this.duration,
    required this.color,
  });

  @override
  State<_Particle> createState() => _ParticleState();
}

class _ParticleState extends State<_Particle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.duration),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value * 0.6,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withOpacity(0.4),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.3),
                  blurRadius: 3,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
