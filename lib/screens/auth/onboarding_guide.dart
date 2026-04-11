import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:monarch/services/database_service.dart';
import 'package:monarch/services/cache_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// =============================================================================
// WIDGET PRINCIPAL
// =============================================================================

/// Guia interativo de primeiro uso.
///
/// Exibido como overlay no [MainNavigation] enquanto
/// [UserModel.onboardingCompleted] for false/null no Firebase.
///
/// Ao criar a primeira missão, seta `onboardingCompleted: true`
/// no Firebase junto com a missão, em um único update.
/// O [UserProvider] detecta a mudança pelo stream e remove o overlay
/// automaticamente — sem SharedPreferences, sem flags locais.
class OnboardingGuide extends StatefulWidget {
  const OnboardingGuide({Key? key}) : super(key: key);

  @override
  State<OnboardingGuide> createState() => _OnboardingGuideState();
}

class _OnboardingGuideState extends State<OnboardingGuide>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const int _totalPages = 5;

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

  void _skipToMissionPage() {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(_totalPages - 1,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOutCubic);
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _resetEntrance();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = RankThemes.e;

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
                            _Hi(Icons.emoji_events, 'Dispute posições no ranking do servidor'),
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
                            _Hi(Icons.stars_rounded, 'Fixas: obrigatórias para manter seu Streak diário'),
                            _Hi(Icons.tune, 'Customizadas: criadas por você, refletem seus objetivos'),
                            _Hi(Icons.local_fire_department, 'Complete todas as fixas para não perder o Streak!'),
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
                            _Hi(Icons.fitness_center, 'Shape: missões de treino e fitness'),
                            _Hi(Icons.menu_book, 'Estudo: missões de aprendizado'),
                            _Hi(Icons.psychology, 'Disciplina & Hábito: constância diária'),
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
                            _Hi(Icons.group, 'Servidores são comunidades mensais de jogadores'),
                            _Hi(Icons.workspace_premium, 'Seu Rank (E → SSS) define o visual do app'),
                            _Hi(Icons.calendar_today, 'Streak mostra seus dias consecutivos ativos'),
                          ],
                          onNext: _goToNextPage,
                          isLastInfo: true,
                        ),
                        _CreateMissionPage(theme: theme),
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
          if (_currentPage < _totalPages - 1)
            TextButton(
              onPressed: _skipToMissionPage,
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              child: Text('Pular',
                  style:
                      TextStyle(color: theme.textSecondary, fontSize: 13)),
            )
          else
            const SizedBox(width: 60),
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
  final bool isLastInfo;

  const _InfoPage({
    Key? key,
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.highlights,
    required this.onNext,
    this.isLastInfo = false,
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
                color: theme.textSecondary, fontSize: 13, letterSpacing: 0.8),
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
                                    color:
                                        theme.textPrimary.withOpacity(0.88),
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
            label:
                isLastInfo ? 'Criar minha primeira missão →' : 'Próximo',
            onTap: onNext,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// =============================================================================
// PÁGINA DE CRIAÇÃO DA PRIMEIRA MISSÃO
// =============================================================================

class _CreateMissionPage extends StatefulWidget {
  final RankTheme theme;

  const _CreateMissionPage({Key? key, required this.theme}) : super(key: key);

  @override
  State<_CreateMissionPage> createState() => _CreateMissionPageState();
}

class _CreateMissionPageState extends State<_CreateMissionPage> {
  final TextEditingController _nameController = TextEditingController();
  final _dbService = DatabaseService();
  final _cache = CacheService.instance;

  bool _isCreating = false;
  bool _created = false;
  String? _errorText;

  static const List<String> _suggestions = [
    '🏃 Correr 30 minutos',
    '📚 Ler 20 páginas',
    '💧 Beber 2L de água',
    '🧘 Meditar 10 minutos',
    '💪 Academia',
    '📖 Estudar 1 hora',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createMission() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Dê um nome para sua missão!');
      return;
    }
    if (name.length < 3) {
      setState(() => _errorText = 'Nome muito curto (mínimo 3 caracteres)');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorText = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final userProvider = context.read<UserProvider>();
      final userId = userProvider.currentUser?.id;
      final serverId = userProvider.currentServerId;
      final userLevel = userProvider.currentUser?.level ?? 1;

      if (userId == null || serverId == null) {
        throw Exception('Usuário não encontrado');
      }

      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final xp = userLevel <= 1 ? 35 : (userLevel * 25) + 10;

      // ── 1. Cria a missão ────────────────────────────────────────────────
      await _dbService.addCustomMission(
        serverId: serverId,
        userId: userId,
        date: date,
        missionName: name,
        xp: xp,
        missionType: 'custom',
      );

      // ── 2. Marca onboarding como concluído no Firebase ──────────────────
      //
      // updateUser já existe no DatabaseService e aceita qualquer Map.
      // Isso grava `onboardingCompleted: true` no nó do usuário:
      //   serverData/{serverId}/users/{userId}/onboardingCompleted: true
      //
      // O UserProvider vai receber a atualização pelo getUserStream,
      // que fará o MainNavigation remover o overlay automaticamente.
      await _dbService.updateUser(serverId, userId, {
        'onboardingCompleted': true,
      });

      // Invalida cache de missoes E do usuario — garante que
      // onboardingCompleted: true seja lido direto do Firebase no loadUser
      _cache.invalidate('missions_\${serverId}_\${userId}_\$date');
      _cache.invalidatePattern('user_*');

      if (!mounted) return;

      HapticFeedback.heavyImpact();
      setState(() {
        _isCreating = false;
        _created = true;
      });

      await context.read<UserProvider>().loadUser();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _errorText = 'Erro ao criar missão. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: theme.primaryGradient,
                  boxShadow: theme.neonGlowEffect,
                ),
                child:
                    const Icon(Icons.add_task, size: 46, color: Colors.white),
              ),
              const SizedBox(height: 18),
              ShaderMask(
                shaderCallback: (b) => theme.primaryGradient.createShader(b),
                child: const Text(
                  'Sua primeira missão!',
                  style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Crie uma meta para hoje e comece sua jornada.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: theme.textSecondary, fontSize: 13.5),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          _label(theme, 'NOME DA MISSÃO'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            enabled: !_created,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: theme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Ex: Correr 30 minutos',
              hintStyle:
                  TextStyle(color: theme.textSecondary.withOpacity(0.45)),
              counterText: '',
              errorText: _errorText,
              filled: true,
              fillColor: theme.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: _border(theme, false),
              enabledBorder: _border(theme, false),
              focusedBorder: _border(theme, true),
              prefixIcon: Icon(Icons.edit_outlined,
                  color: theme.primary, size: 19),
            ),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          const SizedBox(height: 18),
          _label(theme, 'SUGESTÕES RÁPIDAS'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map((s) => GestureDetector(
                      onTap: _created
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              final clean = s.substring(s.indexOf(' ') + 1);
                              _nameController.text = clean;
                              _nameController.selection =
                                  TextSelection.fromPosition(
                                      TextPosition(offset: clean.length));
                              setState(() => _errorText = null);
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: theme.primary.withOpacity(0.3)),
                        ),
                        child: Text(s,
                            style: TextStyle(
                                color: theme.textPrimary.withOpacity(0.82),
                                fontSize: 12.5)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _created ? _buildSuccess(theme) : _buildButton(theme),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _label(RankTheme theme, String text) => Text(
        text,
        style: TextStyle(
            color: theme.textSecondary,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600),
      );

  OutlineInputBorder _border(RankTheme theme, bool focused) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: focused ? theme.primary : theme.primary.withOpacity(0.3),
          width: focused ? 2 : 1,
        ),
      );

  Widget _buildButton(RankTheme theme) => _GradientButton(
        key: const ValueKey('btn_create'),
        theme: theme,
        label: 'Criar missão e começar!',
        isLoading: _isCreating,
        onTap: _isCreating ? null : _createMission,
      );

  Widget _buildSuccess(RankTheme theme) => Container(
        key: const ValueKey('btn_success'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.success.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.success, width: 2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: theme.success, size: 22),
            const SizedBox(width: 10),
            Text('Missão criada! Vamos lá 🚀',
                style: TextStyle(
                    color: theme.success,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

// =============================================================================
// BOTÃO COM GRADIENTE
// =============================================================================

class _GradientButton extends StatelessWidget {
  final RankTheme theme;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _GradientButton({
    Key? key,
    required this.theme,
    required this.label,
    this.onTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
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
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4)),
        ),
      ),
    );
  }
}