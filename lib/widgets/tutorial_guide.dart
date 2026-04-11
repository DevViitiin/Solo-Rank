import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:provider/provider.dart';

// =============================================================================
// TUTORIAL GUIDE — versão informativa (sem criação de missão)
//
// Aberto manualmente pelo botão na HomeScreen.
// Exibe 4 páginas explicando o app e fecha com um botão "Entendido!".
// =============================================================================

class TutorialGuide extends StatefulWidget {
  const TutorialGuide({Key? key}) : super(key: key);

  @override
  State<TutorialGuide> createState() => _TutorialGuideState();
}

class _TutorialGuideState extends State<TutorialGuide>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const int _totalPages = 4;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playEntrance();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));
  }

  void _playEntrance() {
    _fadeController.forward();
    _slideController.forward();
  }

  void _resetEntrance() {
    _fadeController.reset();
    _slideController.reset();
    _playEntrance();
  }

  void _goToNextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _resetEntrance();
  }

  void _close() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  RankTheme _resolveTheme(BuildContext context) {
    final rank =
        context.read<UserProvider>().currentUser?.rank ?? 'E';
    return RankThemes.getTheme(rank);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _resolveTheme(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(gradient: theme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(theme),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: _onPageChanged,
                      children: [
                        _InfoPage(
                          theme: theme,
                          icon: Icons.bolt,
                          title: 'Bem-vindo ao\nDracoryx',
                          subtitle: 'Seu sistema de evolução pessoal',
                          description:
                              'Dracoryx transforma seus hábitos e metas do dia a dia em uma jornada de evolução. Complete missões, suba de nível e conquiste novos Ranks.',
                          highlights: const [
                            _Hi(Icons.star, 'Ganhe XP completando missões'),
                            _Hi(Icons.trending_up, 'Evolua do Rank E até o SSS'),
                            _Hi(Icons.emoji_events,
                                'Dispute posições no ranking do servidor'),
                          ],
                          onNext: _goToNextPage,
                        ),
                        _InfoPage(
                          theme: theme,
                          icon: Icons.assignment,
                          title: 'Missões',
                          subtitle: 'O coração do seu progresso',
                          description:
                              'Você terá dois tipos de missões a cada dia. Complete-as para ganhar XP e evoluir seus atributos.',
                          highlights: const [
                            _Hi(Icons.stars_rounded,
                                'Fixas: obrigatórias para manter seu Streak diário'),
                            _Hi(Icons.tune,
                                'Customizadas: criadas por você, refletem seus objetivos'),
                            _Hi(Icons.local_fire_department,
                                'Complete todas as fixas para não perder o Streak!'),
                          ],
                          onNext: _goToNextPage,
                        ),
                        _InfoPage(
                          theme: theme,
                          icon: Icons.military_tech,
                          title: 'Atributos',
                          subtitle: 'Seu perfil de evolução',
                          description:
                              'Cada missão que você completa evolui atributos específicos. Eles mostram quem você está se tornando.',
                          highlights: const [
                            _Hi(Icons.fitness_center,
                                'Shape: missões de treino e fitness'),
                            _Hi(Icons.menu_book,
                                'Estudo: missões de aprendizado'),
                            _Hi(Icons.psychology,
                                'Disciplina & Hábito: constância diária'),
                          ],
                          onNext: _goToNextPage,
                        ),
                        _InfoPage(
                          theme: theme,
                          icon: Icons.leaderboard,
                          title: 'Ranking',
                          subtitle: 'Mostre sua evolução ao mundo',
                          description:
                              'Você compete no ranking do seu servidor. Quanto mais missões você completa e maior seu nível, mais alto você sobe.',
                          highlights: const [
                            _Hi(Icons.group,
                                'Servidores são comunidades mensais de jogadores'),
                            _Hi(Icons.workspace_premium,
                                'Seu Rank (E → SSS) define o visual do app'),
                            _Hi(Icons.calendar_today,
                                'Streak mostra seus dias consecutivos ativos'),
                          ],
                          onNext: _goToNextPage,
                          isLastPage: true,
                          onFinish: _close,
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

  Widget _buildTopBar(RankTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Indicadores de página
          Row(
            children: List.generate(_totalPages, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 6),
                width: isActive ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.primary
                      : theme.textSecondary.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          // Botão fechar
          GestureDetector(
            onTap: _close,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: theme.surfaceLight.withOpacity(0.3)),
              ),
              child: Text(
                'Fechar',
                style: TextStyle(
                    color: theme.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODELOS INTERNOS
// =============================================================================

class _Hi {
  final IconData icon;
  final String text;
  const _Hi(this.icon, this.text);
}

// =============================================================================
// PÁGINA INFORMATIVA
// =============================================================================

class _InfoPage extends StatelessWidget {
  final RankTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final List<_Hi> highlights;
  final VoidCallback onNext;
  final bool isLastPage;
  final VoidCallback? onFinish;

  const _InfoPage({
    Key? key,
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.highlights,
    required this.onNext,
    this.isLastPage = false,
    this.onFinish,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: theme.primaryGradient,
              boxShadow: theme.neonGlowEffect,
            ),
            child: Icon(icon, size: 52, color: Colors.white),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (b) => theme.primaryGradient.createShader(b),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 18),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: theme.textPrimary.withOpacity(0.82),
                fontSize: 14.5,
                height: 1.55),
          ),
          const SizedBox(height: 22),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: theme.primary.withOpacity(0.25)),
            ),
            child: Column(
              children: highlights
                  .map((h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.primary.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(h.icon,
                                color: theme.primary, size: 17),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(h.text,
                                style: TextStyle(
                                    color: theme.textPrimary
                                        .withOpacity(0.88),
                                    fontSize: 13,
                                    height: 1.4)),
                          ),
                        ]),
                      ))
                  .toList(),
            ),
          ),
          const Spacer(),
          _GradientButton(
            theme: theme,
            label: isLastPage ? 'Entendido! ✓' : 'Próximo',
            onTap: isLastPage ? onFinish : onNext,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// =============================================================================
// BOTÃO COM GRADIENTE
// =============================================================================

class _GradientButton extends StatelessWidget {
  final RankTheme theme;
  final String label;
  final VoidCallback? onTap;

  const _GradientButton({
    Key? key,
    required this.theme,
    required this.label,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: theme.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: theme.primary.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4),
        ),
      ),
    );
  }
}

// =============================================================================
// HELPER — abre o tutorial como bottom sheet de tela cheia
// =============================================================================

void showTutorialGuide(BuildContext context) {
  HapticFeedback.mediumImpact();
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.85),
      pageBuilder: (_, __, ___) => const TutorialGuide(),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    ),
  );
}