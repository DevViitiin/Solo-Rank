import 'package:flutter/material.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/services/popup_service.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;


class AchievementPopup extends StatefulWidget {
  final String userId;
  final String popupId;
  final String title;
  final String description;
  final String emoji;
  final RankTheme theme;
  final VoidCallback onDismiss;
  final List<AttributeBonus>? attributeBonuses;
  
  const AchievementPopup({
    Key? key,
    required this.userId,
    required this.popupId,
    required this.title,
    required this.description,
    required this.emoji,
    required this.theme,
    required this.onDismiss,
    this.attributeBonuses,
  }) : super(key: key);
  
  @override
  State<AchievementPopup> createState() => _AchievementPopupState();
}

class _AchievementPopupState extends State<AchievementPopup>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _glowController;
  late AnimationController _slideController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _glowAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isDismissed = false;
  
  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    
    _rotateController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _rotateAnimation = Tween<double>(
      begin: -0.03,
      end: 0.03,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.easeInOut,
    ));
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _scaleController.forward();
    _slideController.forward();
    
    // Auto-dismiss após 5 segundos
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_isDismissed) {
        _dismiss();
      }
    });
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    _rotateController.dispose();
    _glowController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  Future<void> _dismiss() async {
    if (_isDismissed) return;
    _isDismissed = true;
    
    // Marca como mostrado usando os métodos públicos do PopupService
    await _markPopupAsShown();
    
    // Anima saída
    await Future.wait([
      _scaleController.reverse(),
      _slideController.reverse(),
    ]);
    
    if (mounted) {
      widget.onDismiss();
    }
  }
  
  /// ✅ ATUALIZADO: Marca o popup como mostrado usando os novos métodos
  Future<void> _markPopupAsShown() async {
    final popupService = PopupService.instance;
    
    switch (widget.popupId) {
      case PopupService.ACHIEVEMENT_ALL_FIXED:
        await popupService.markAllFixedShown(widget.userId);
        break;
      case PopupService.ACHIEVEMENT_3_CUSTOM:
        await popupService.mark3CustomShown(widget.userId);
        break;
      case PopupService.ACHIEVEMENT_ALL_CUSTOM:
        await popupService.markAllCustomShown(widget.userId);
        break;
      case PopupService.ACHIEVEMENT_PERFECT_DAY:
        await popupService.markPerfectDayShown(widget.userId);
        break;
      default:
        debugPrint('⚠️ Popup ID desconhecido: ${widget.popupId}');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _dismiss,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.85),
              ],
            ),
          ),
          child: Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: _buildPopupCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPopupCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.theme.background,
            widget.theme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: widget.theme.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.theme.primary.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Efeito de brilho de fundo
            _buildBackgroundGlow(),
            
            // Partículas animadas
            _buildParticles(),
            
            // Conteúdo principal
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emoji animado
                  _buildAnimatedEmoji(),
                  
                  const SizedBox(height: 24),
                  
                  // Título
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: widget.theme.textPrimary,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: widget.theme.primary.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Descrição
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.theme.textSecondary,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Bônus de atributos
                  if (widget.attributeBonuses != null && 
                      widget.attributeBonuses!.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildAttributeBonuses(),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Botão de continuar
                  _buildContinueButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBackgroundGlow() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: [
                  widget.theme.primary.withOpacity(_glowAnimation.value * 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildAnimatedEmoji() {
    return AnimatedBuilder(
      animation: _rotateAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotateAnimation.value,
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.theme.primary.withOpacity(0.2),
                      widget.theme.primary.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.theme.primary.withOpacity(_glowAnimation.value * 0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 72),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  Widget _buildAttributeBonuses() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.theme.primary.withOpacity(0.1),
            widget.theme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.theme.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.stars_rounded,
                color: widget.theme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'BÔNUS CONQUISTADOS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: widget.theme.textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.attributeBonuses!.map((bonus) => _buildBonusRow(bonus)),
        ],
      ),
    );
  }
  
  Widget _buildBonusRow(AttributeBonus bonus) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.theme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              bonus.icon,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            bonus.name,
            style: TextStyle(
              fontSize: 16,
              color: widget.theme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: widget.theme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.theme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '+${bonus.amount}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: widget.theme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: widget.theme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _dismiss,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: const Text(
              'CONTINUAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildParticles() {
    return Positioned.fill(
      child: CustomPaint(
        painter: ParticlePainter(
          animation: _glowAnimation,
          color: widget.theme.primary,
        ),
      ),
    );
  }
}

class AttributeBonus {
  final String name;
  final String icon;
  final int amount;
  
  const AttributeBonus({
    required this.name,
    required this.icon,
    required this.amount,
  });
}

class ParticlePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  
  ParticlePainter({
    required this.animation,
    required this.color,
  }) : super(repaint: animation);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42);
    
    for (int i = 0; i < 30; i++) {
      final x = size.width * random.nextDouble();
      final y = size.height * random.nextDouble();
      final radius = 1 + random.nextDouble() * 3;
      
      final opacity = (animation.value * 0.5 + random.nextDouble() * 0.3);
      paint.color = color.withOpacity(opacity * 0.15);
      
      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ✅ HELPERS ATUALIZADOS PARA MOSTRAR POPUPS
/// ═══════════════════════════════════════════════════════════════════════════

class AchievementPopups {
  
  /// ✅ ATUALIZADO: Todas as Fixas Completas (variável: 3, 4 ou 5)
  static Future<void> showAllFixedComplete(
    BuildContext context,
    String userId,
    int totalFixed,
    VoidCallback onDismiss,
  ) async {
    final userProvider = context.read<UserProvider>();
    final theme = RankThemes.getTheme(userProvider.currentUser?.rank ?? 'E');
    
    // Verificar se já foi mostrado
    final popupService = PopupService.instance;
    final canShow = await popupService.canShowAllFixedPopup(userId);
    
    if (!canShow) {
      debugPrint('⏭️ Popup todas fixas já foi mostrado hoje');
      return;
    }
    
    if (!context.mounted) return;
    
    // Bônus varia conforme total
    final bonus = totalFixed == 5 ? 50 : (totalFixed == 4 ? 40 : 30);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => AchievementPopup(
        userId: userId,
        popupId: PopupService.ACHIEVEMENT_ALL_FIXED,
        title: 'MISSÕES FIXAS COMPLETAS!',
        description: 'Você completou todas as $totalFixed missões diárias fixas!\n+$bonus XP de bônus',
        emoji: '🎯',
        theme: theme,
        onDismiss: () {
          Navigator.of(context).pop();
          onDismiss();
        },
        attributeBonuses: const [
          AttributeBonus(
            name: 'Disciplina',
            icon: '🎯',
            amount: 2,
          ),
        ],
      ),
    );
  }
  
  /// ✅ NOVO: 3 Customizadas Completas
  static Future<void> show3CustomComplete(
    BuildContext context,
    String userId,
    VoidCallback onDismiss,
  ) async {
    final userProvider = context.read<UserProvider>();
    final theme = RankThemes.getTheme(userProvider.currentUser?.rank ?? 'E');
    
    // Verificar se já foi mostrado
    final popupService = PopupService.instance;
    final canShow = await popupService.canShow3CustomPopup(userId);
    
    if (!canShow) {
      debugPrint('⏭️ Popup 3 custom já foi mostrado hoje');
      return;
    }
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => AchievementPopup(
        userId: userId,
        popupId: PopupService.ACHIEVEMENT_3_CUSTOM,
        title: 'COMEÇOU BEM!',
        description: '3 missões personalizadas completadas!\n+30 XP de bônus',
        emoji: '🔥',
        theme: theme,
        onDismiss: () {
          Navigator.of(context).pop();
          onDismiss();
        },
        attributeBonuses: const [
          AttributeBonus(
            name: 'Hábito',
            icon: '🔥',
            amount: 1,
          ),
        ],
      ),
    );
  }
  
  /// ✅ ATUALIZADO: Todas Customizadas Completas (7)
  static Future<void> showAllCustomComplete(
    BuildContext context,
    String userId,
    VoidCallback onDismiss,
  ) async {
    final userProvider = context.read<UserProvider>();
    final theme = RankThemes.getTheme(userProvider.currentUser?.rank ?? 'E');
    
    // Verificar se já foi mostrado
    final popupService = PopupService.instance;
    final canShow = await popupService.canShowAllCustomPopup(userId);
    
    if (!canShow) {
      debugPrint('⏭️ Popup todas custom já foi mostrado hoje');
      return;
    }
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => AchievementPopup(
        userId: userId,
        popupId: PopupService.ACHIEVEMENT_ALL_CUSTOM,
        title: 'PRODUTIVIDADE MÁXIMA!',
        description: 'Incrível! Todas as 7 missões personalizadas completadas!\n+70 XP de bônus',
        emoji: '🏆',
        theme: theme,
        onDismiss: () {
          Navigator.of(context).pop();
          onDismiss();
        },
        attributeBonuses: const [
          AttributeBonus(
            name: 'Hábito',
            icon: '🔥',
            amount: 2,
          ),
        ],
      ),
    );
  }
  
  /// ✅ ATUALIZADO: Dia Perfeito
  static Future<void> showPerfectDay(
    BuildContext context,
    String userId,
    VoidCallback onDismiss,
  ) async {
    final userProvider = context.read<UserProvider>();
    final theme = RankThemes.getTheme(userProvider.currentUser?.rank ?? 'E');
    
    // Verificar se já foi mostrado
    final popupService = PopupService.instance;
    final canShow = await popupService.canShowPerfectDayPopup(userId);
    
    if (!canShow) {
      debugPrint('⏭️ Popup dia perfeito já foi mostrado hoje');
      return;
    }
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => AchievementPopup(
        userId: userId,
        popupId: PopupService.ACHIEVEMENT_PERFECT_DAY,
        title: 'DIA PERFEITO! 🌟',
        description: 'Incrível! Você completou TODAS as missões!\nFixas + Customizadas = Perfeição!\n+150 XP de bônus',
        emoji: '👑',
        theme: theme,
        onDismiss: () {
          Navigator.of(context).pop();
          onDismiss();
        },
        attributeBonuses: const [
          AttributeBonus(
            name: 'Disciplina',
            icon: '🎯',
            amount: 2,
          ),
          AttributeBonus(
            name: 'Hábito',
            icon: '🔥',
            amount: 2,
          ),
        ],
      ),
    );
  }
}