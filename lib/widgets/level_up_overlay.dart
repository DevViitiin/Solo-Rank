import 'package:flutter/material.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

/// Overlay fullscreen de animação de Level Up.
///
/// Exibe quando o usuário sobe de nível, com:
/// - Confetti animado via [ConfettiController]
/// - Badge de nível com gradiente do rank
/// - Frase motivacional baseada no nível
/// - Card de mudança de posição no ranking (se aplicável)
///
/// Auto-dismiss após 4 segundos ou ao clicar em "CONTINUAR".
class LevelUpAnimation extends StatefulWidget {
  final int newLevel;
  final String? newRank;
  final int? oldRankingPosition;
  final int? newRankingPosition;
  final VoidCallback onComplete;

  const LevelUpAnimation({
    Key? key,
    required this.newLevel,
    this.newRank,
    this.oldRankingPosition,
    this.newRankingPosition,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<LevelUpAnimation> createState() => _LevelUpAnimationState();
}

class _LevelUpAnimationState extends State<LevelUpAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late ConfettiController _confettiController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  /// Configura AnimationControllers de escala, fade e slide.
  void _setupAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeIn,
      ),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  /// Inicia sequência escalonada de animações com auto-dismiss.
  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _scaleController.forward();
      _fadeController.forward();
      _confettiController.play();

      Future.delayed(const Duration(milliseconds: 600), () {
        _slideController.forward();
      });
    });

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _closeAnimation();
    });
  }

  /// Reverte animações e chama [onComplete] após 400ms.
  void _closeAnimation() {
    _scaleController.reverse();
    _fadeController.reverse();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeForRank(widget.newRank ?? 'E');
    final hasRankingChange =
        widget.oldRankingPosition != null &&
        widget.newRankingPosition != null &&
        widget.oldRankingPosition! > widget.newRankingPosition!;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(color: Colors.black.withOpacity(0.85)),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.3,
              colors: [
                theme.primary,
                theme.accent,
                const Color(0xFFFFD700),
                const Color(0xFFFF6B6B),
                const Color(0xFF4ECDC4),
              ],
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 420,
                        maxHeight:
                            MediaQuery.of(context).size.height * 0.9,
                      ),
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(28),
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
                          border:
                              Border.all(color: theme.primary, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primary.withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: theme.primaryGradient,
                                boxShadow: theme.neonGlowEffect,
                              ),
                              child: const Icon(
                                Icons.bolt,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 24),

                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  theme.primaryGradient
                                      .createShader(bounds),
                              child: const Text(
                                'LEVEL UP!',
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: theme.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star,
                                      color: Colors.white, size: 30),
                                  const SizedBox(width: 10),
                                  Text(
                                    'NÍVEL ${widget.newLevel}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            Text(
                              _getMotivationalMessage(widget.newLevel),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                              ),
                            ),

                            if (hasRankingChange) ...[
                              const SizedBox(height: 24),
                              SlideTransition(
                                position: _slideAnimation,
                                child: _buildRankingCard(theme),
                              ),
                            ],

                            const SizedBox(height: 24),

                            TextButton(
                              onPressed: _closeAnimation,
                              child: Text(
                                'CONTINUAR',
                                style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói card dourado indicando subida no ranking.
  Widget _buildRankingCard(RankTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700), width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.trending_up,
              color: Color(0xFFFFD700), size: 32),
          const SizedBox(height: 8),
          Text(
            'Você subiu no ranking!',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Retorna frase motivacional baseada na faixa de nível.
  String _getMotivationalMessage(int level) {
    if (level <= 10) return 'Continue assim! Você está no caminho certo!';
    if (level <= 25) return 'Sua dedicação está virando poder!';
    if (level <= 50) return 'Você está ficando cada vez mais forte!';
    if (level <= 75) return 'Poucos chegam até aqui. Continue!';
    return 'Você alcançou um nível lendário!';
  }

  RankTheme _getThemeForRank(String rank) {
    switch (rank) {
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
}

/// Exibe o overlay de Level Up como dialog modal.
void showLevelUpAnimation(
  BuildContext context, {
  required int newLevel,
  String? newRank,
  int? oldRankingPosition,
  int? newRankingPosition,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (_) => LevelUpAnimation(
      newLevel: newLevel,
      newRank: newRank,
      oldRankingPosition: oldRankingPosition,
      newRankingPosition: newRankingPosition,
      onComplete: () => Navigator.of(context).pop(),
    ),
  );
}
