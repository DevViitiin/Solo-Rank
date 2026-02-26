import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monarch/constants/app_constants.dart';
import 'package:monarch/controllers/mission_controller.dart';
import 'package:monarch/controllers/mission_queue_controller.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:monarch/screens/screens_app/animated_particles.dart';
import 'package:monarch/screens/screens_app/animations_mission.dart';
import 'package:monarch/screens/screens_app/level_up_screen.dart';
import 'package:monarch/services/database_service.dart';
import 'package:monarch/services/cache_service.dart';
import 'package:monarch/services/mission_service.dart';
import 'package:monarch/models/mission_model.dart';
import 'package:monarch/services/popup_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:math' as math;

// ✅ CONSTANTES GLOBAIS: Limites de missões
const int MIN_FIXED_MISSIONS = 3;
const int MAX_FIXED_MISSIONS = 5;
const int MAX_CUSTOM_MISSIONS = 7;

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({Key? key}) : super(key: key);

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen>
    with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final _cache = CacheService.instance;
  final MissionService _missionService = MissionService.instance;
  final MissionToggleController _toggleController = MissionToggleController.instance;
  final MissionBatchController _batchController = MissionBatchController.instance;
  final PopupService _popupService = PopupService.instance;
  
  Map<String, MissionModel> _fixedMissions = {};
  Map<String, MissionModel> _customMissions = {};
  bool _loading = true;
  bool _isRefreshing = false;
  String _selectedFilter = 'Todas';

  late AnimationController _confettiController;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _setupAnimations();
    _loadMissions();
    _initPopupService();
  }

  Future<void> _initPopupService() async {
    await _popupService.init();
  }

  /// ✅ ATUALIZADO: Sistema de popups para novos limites
  Future<void> _checkAndShowAchievementPopups() async {
    if (!mounted) return;
    
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.currentUser?.id;
    
    if (userId == null) return;
    
    final fixedCompleted = _fixedMissions.values.where((m) => m.completed).length;
    final customCompleted = _customMissions.values.where((m) => m.completed).length;
    final fixedTotal = _fixedMissions.length;
    
    AppConstants.debugLog('🎯 Verificando popups de conquistas...');
    AppConstants.debugLog('   Fixas: $fixedCompleted/$fixedTotal');
    AppConstants.debugLog('   Custom: $customCompleted/$MAX_CUSTOM_MISSIONS');
    
    // ✅ POPUP: Todas as Fixas Completas (variável: 3, 4 ou 5)
    if (fixedCompleted == fixedTotal && fixedTotal >= MIN_FIXED_MISSIONS) {
      final canShow = await _popupService.canShowAllFixedPopup(userId);
      
      if (canShow && mounted) {
        AppConstants.debugLog('🎉 Mostrando popup de todas fixas ($fixedTotal)!');
        
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (mounted) {
          await _popupService.showAllFixedMissionsPopup(context, userId, fixedTotal);
        }
      } else {
        AppConstants.debugLog('⏭️ Popup de todas fixas já foi mostrado hoje');
      }
    }
    
    // ✅ POPUP: 3 Customizadas Completas (primeiro bônus)
    if (customCompleted >= 3) {
      final canShow = await _popupService.canShow3CustomPopup(userId);
      
      if (canShow && mounted) {
        AppConstants.debugLog('🎉 Mostrando popup de 3 customizadas!');
        
        await Future.delayed(const Duration(milliseconds: 1000));
        
        if (mounted) {
          await _popupService.show3CustomMissionsPopup(context, userId);
        }
      } else {
        AppConstants.debugLog('⏭️ Popup de 3 customizadas já foi mostrado hoje');
      }
    }
    
    // ✅ POPUP: Todas Customizadas Completas (7)
    if (customCompleted == MAX_CUSTOM_MISSIONS) {
      final canShow = await _popupService.canShowAllCustomPopup(userId);
      
      if (canShow && mounted) {
        AppConstants.debugLog('🎉 Mostrando popup de todas customizadas!');
        
        await Future.delayed(const Duration(milliseconds: 1200));
        
        if (mounted) {
          await _popupService.showAllCustomMissionsPopup(context, userId);
        }
      } else {
        AppConstants.debugLog('⏭️ Popup de todas customizadas já foi mostrado hoje');
      }
    }
    
    // ✅ POPUP: Dia Perfeito (todas fixas + todas customizadas)
    final allCompleted = fixedCompleted == fixedTotal && 
                        customCompleted == MAX_CUSTOM_MISSIONS &&
                        fixedTotal >= MIN_FIXED_MISSIONS;
                        
    if (allCompleted) {
      final canShow = await _popupService.canShowPerfectDayPopup(userId);
      
      if (canShow && mounted) {
        AppConstants.debugLog('🎉 Mostrando popup de DIA PERFEITO!');
        
        await Future.delayed(const Duration(milliseconds: 1600));
        
        if (mounted) {
          await _popupService.showPerfectDayPopup(context, userId);
        }
      } else {
        AppConstants.debugLog('⏭️ Popup de dia perfeito já foi mostrado hoje');
      }
    }
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('pt_BR', null);
  }

  void _setupAnimations() {
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadMissions({bool forceRefresh = false}) async {
    setState(() => _loading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final userId = userProvider.currentUser?.id;
      final serverId = userProvider.currentServerId;

      if (userId == null || serverId == null) {
        setState(() => _loading = false);
        return;
      }

      final today = _getTodayKey();
      final cacheKey = 'missions_${serverId}_${userId}_$today';

      final missionsData = await _cache.getCached<Map<String, dynamic>>(
        key: cacheKey,
        fetchFunction: () async {
          final data = await _dbService.getDailyMissions(serverId, userId, today);
          return data ?? <String, dynamic>{};
        },
        cacheDuration: CacheService.CACHE_SHORT,
        forceRefresh: forceRefresh,
      );

      if (missionsData != null && missionsData.isNotEmpty) {
        _parseMissions(missionsData, userProvider.currentUser!.level);
      }

      setState(() => _loading = false);
      _updateProgress();
    } catch (e) {
      AppConstants.debugLog('Erro ao carregar missões: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshMissions() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      HapticFeedback.mediumImpact();
      await _loadMissions(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _parseMissions(Map<String, dynamic> data, int userLevel) {
    _fixedMissions.clear();
    _customMissions.clear();

    if (data['fixed'] != null && data['fixed'] is Map) {
      final fixed = Map<String, dynamic>.from(data['fixed']);
      fixed.forEach((key, value) {
        if (value is Map) {
          _fixedMissions[key] = MissionModel.fromMap(
            key,
            Map<String, dynamic>.from(value),
            MissionType.fixed,
          );
        }
      });
    }

    if (data['custom'] != null && data['custom'] is Map) {
      final custom = Map<String, dynamic>.from(data['custom']);
      custom.forEach((key, value) {
        if (value is Map) {
          _customMissions[key] = MissionModel.fromMap(
            key,
            Map<String, dynamic>.from(value),
            MissionType.custom,
          );
        }
      });
    }
  }

  String _getTodayKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  // =========================================================================
  //  SISTEMA DE CATEGORIZAÇÃO MELHORADO
  // =========================================================================

  String _categorizeMission(String missionName) {
    final name = missionName.toLowerCase();

    // FITNESS - Exercícios físicos, treino, força
    final fitnessKeywords = [
      'treino', 'treinar', 'exercício', 'exercicio', 'força', 'gym', 'academia',
      'corrida', 'correr', 'caminhada', 'caminhar', 'musculação', 'musculacao',
      'flexão', 'flexao', 'abdominais', 'abdominal', 'agachamento', 'cardio', 'aeróbico',
      'aerobico', 'yoga', 'pilates', 'crossfit', 'funcional', 'peso', 'halteres',
      'barra', 'supino', 'leg press', 'esteira', 'bike', 'bicicleta', 'natação',
      'natacao', 'nadar', 'alongamento', 'alongar', 'aquecimento', 'polichinelo',
      'burpee', 'prancha', 'remada', 'levantamento', 'pull', 'push', 'leg',
      'arm', 'chest', 'back', 'shoulder', 'biceps', 'triceps', 'glúteo', 'gluteo',
      'perna', 'braço', 'braco', 'peito', 'costas', 'ombro', 'abdômen', 'abdomen',
      'sport', 'esporte', 'atletismo', 'boxe', 'luta', 'artes marciais',
    ];

    // ESTUDOS - Aprendizado, leitura, cursos
    final studyKeywords = [
      'estudo', 'estudar', 'inglês', 'ingles', 'espanhol', 'francês', 'frances',
      'idioma', 'língua', 'lingua', 'leitura', 'ler', 'livro', 'curso', 'aula',
      'aprender', 'aprendizado', 'prova', 'exercício escolar', 'dever',
      'tarefa', 'homework', 'revisar', 'revisão', 'revisao', 'pesquisa', 'pesquisar',
      'resumo', 'resumir', 'fichamento', 'artigo', 'tcc', 'monografia', 'dissertação',
      'dissertacao', 'tese', 'seminário', 'seminario', 'apresentação', 'apresentacao',
      'slide', 'power point', 'trabalho', 'projeto', 'redação', 'redacao', 'texto',
      'gramática', 'gramatica', 'matemática', 'matematica', 'física', 'fisica',
      'química', 'quimica', 'biologia', 'história', 'historia', 'geografia',
      'filosofia', 'sociologia', 'programação', 'programacao', 'código', 'codigo',
      'algoritmo', 'python', 'java', 'javascript', 'html', 'css', 'react',
      'desenvolvimento', 'dev', 'coding', 'hacking', 'ti', 'tecnologia',
      'faculdade', 'escola', 'colégio', 'colegio', 'universidade', 'vestibular',
      'enem', 'concurso', 'prova', 'teste', 'exame', 'avaliação', 'avaliacao',
    ];

    // HIGIENE - Cuidados pessoais
    final hygieneKeywords = [
      'banho', 'tomar banho', 'ducha', 'chuveiro', 'dente', 'dentes', 'escovar',
      'escovação', 'escovacao', 'fio dental', 'enxaguante', 'higiene', 'limpeza',
      'barba', 'fazer barba', 'barbear', 'depilação', 'depilacao', 'depilar',
      'cabelo', 'lavar cabelo', 'shampoo', 'condicionador', 'hidratação capilar',
      'máscara capilar', 'unha', 'unhas', 'cortar unha', 'lixar unha', 'esmalte',
      'skincare', 'pele', 'rosto', 'limpar rosto', 'sabonete', 'lavar rosto',
      'protetor solar', 'hidratante', 'creme', 'sérum', 'serum', 'esfoliação',
      'esfoliacao', 'esfoliar', 'máscara facial', 'tônico', 'tonico', 'demaquilar',
      'maquiagem', 'perfume', 'desodorante', 'antitranspirante', 'loção', 'locao',
      'lavar mãos', 'lavar maos', 'limpar', 'higienizar',
    ];

    // NUTRIÇÃO - Alimentação e hidratação
    final nutritionKeywords = [
      'água', 'agua', 'beber água', 'beber agua', 'hidratação', 'hidratacao',
      'hidratar', 'litro', 'ml', 'copo', 'garrafa', 'nutrição', 'nutricao',
      'alimentação', 'alimentacao', 'comer', 'comida', 'refeição', 'refeicao',
      'café', 'cafe', 'almoço', 'almoco', 'jantar', 'lanche', 'merenda',
      'almoçar', 'fruta', 'frutas', 'verdura', 'verduras', 'legume', 'legumes', 'vegetal',
      'vegetais', 'salada', 'proteína', 'proteina', 'carboidrato', 'gordura',
      'vitamina', 'suplemento', 'whey', 'creatina', 'bcaa', 'shake', 'suco',
      'smoothie', 'natural', 'orgânico', 'organico', 'saudável', 'saudavel',
      'dieta', 'regime', 'emagrecer', 'engordar', 'ganhar peso', 'perder peso',
      'massa', 'definição', 'definicao', 'cutting', 'bulking', 'caloria', 'macro',
      'vegetariano', 'vegano', 'low carb', 'jejum', 'detox',
    ];

    // SAÚDE - Bem-estar geral, sono, saúde mental
    final healthKeywords = [
      'dormir', 'sono', 'descanso', 'descansar', 'relaxar', 'relaxamento', 'meditação',
      'meditacao', 'meditar', 'mindfulness', 'respiração', 'respiracao', 'respirar',
      'saúde', 'saude', 'bem-estar', 'bem estar', 'wellness', 'autocuidado',
      'terapia', 'terapeuta', 'psicólogo', 'psicologo', 'psiquiatra', 'consulta',
      'médico', 'medico', 'exame', 'check-up', 'checkup', 'pressão', 'pressao',
      'glicemia', 'colesterol', 'remédio', 'remedio', 'medicamento', 'medicação',
      'medicacao', 'compressa', 'gelo', 'calor', 'massagem', 'fisioterapia',
      'alongamento terapêutico', 'postura', 'ergonomia', 'coluna', 'lombar',
      'ansiedade', 'depressão', 'depressao', 'stress', 'estresse', 'mental',
      'emocional', 'gratidão', 'gratidao', 'journaling', 'diário', 'diario',
    ];

    // PRODUTIVIDADE - Organização, planejamento
    final productivityKeywords = [
      'organizar', 'organização', 'organizacao', 'planejar', 'planejamento',
      'agenda', 'calendário', 'calendario', 'lista', 'checklist', 'tarefa',
      'tarefas', 'afazer', 'to-do', 'todo', 'produtividade', 'foco', 'concentração',
      'concentracao', 'pomodoro', 'timer', 'cronômetro', 'cronometro', 'meta',
      'objetivo', 'revisar email', 'e-mail', 'inbox', 'limpar', 'arrumar',
      'mesa', 'quarto', 'casa', 'escritório', 'escritorio', 'arquivo', 'documento',
    ];

    if (fitnessKeywords.any((keyword) => name.contains(keyword))) {
      return 'Fitness';
    }
    
    if (studyKeywords.any((keyword) => name.contains(keyword))) {
      return 'Estudos';
    }
    
    if (hygieneKeywords.any((keyword) => name.contains(keyword))) {
      return 'Higiene';
    }
    
    if (nutritionKeywords.any((keyword) => name.contains(keyword))) {
      return 'Nutrição';
    }
    
    if (healthKeywords.any((keyword) => name.contains(keyword))) {
      return 'Saúde';
    }
    
    if (productivityKeywords.any((keyword) => name.contains(keyword))) {
      return 'Produtividade';
    }

    return 'Outras';
  }

  //  SISTEMA DE ATRIBUTOS BASEADO EM CATEGORIA
  Map<String, int> _getAttributesForMission(String missionName) {
    final category = _categorizeMission(missionName);
    final attributes = <String, int>{};

    switch (category) {
      case 'Estudos':
        attributes['study'] = 1;
        break;
      case 'Fitness':
        attributes['discipline'] = 1;
        break;
      case 'Nutrição':
        attributes['consistency'] = 1;
        break;
      case 'Higiene':
        attributes['responsibility'] = 1;
        break;
      case 'Saúde':
        attributes['evolution'] = 1;
        break;
      case 'Produtividade':
        attributes['discipline'] = 1;
        break;
    }

    return attributes;
  }

  List<MissionModel> _getFilteredMissions() {
    final allMissions = [..._fixedMissions.values, ..._customMissions.values];

    if (_selectedFilter == 'Todas') {
      return allMissions;
    }

    return allMissions.where((mission) {
      return _categorizeMission(mission.name) == _selectedFilter;
    }).toList();
  }

  List<String> _getAvailableFilters() {
    return [
      'Todas',
      'Fitness',
      'Estudos',
      'Saúde',
      'Higiene',
      'Nutrição',
      'Produtividade',
      'Outras',
    ];
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Todas':
        return Icons.grid_view_rounded;
      case 'Fitness':
        return Icons.fitness_center_rounded;
      case 'Estudos':
        return Icons.menu_book_rounded;
      case 'Higiene':
        return Icons.water_drop_rounded;
      case 'Nutrição':
        return Icons.restaurant_rounded;
      case 'Saúde':
        return Icons.favorite_rounded;
      case 'Produtividade':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'Fitness':
        return Colors.orange;
      case 'Estudos':
        return Colors.purple;
      case 'Higiene':
        return Colors.cyan;
      case 'Nutrição':
        return Colors.green;
      case 'Saúde':
        return Colors.red;
      case 'Produtividade':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Future<void> _toggleMission(MissionModel mission) async {
    if (mission.completed) {
      HapticFeedback.lightImpact();
      return;
    }

    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;
    final userId = currentUser?.id;
    final serverId = userProvider.currentServerId;

    if (userId == null || serverId == null || currentUser == null) {
      return;
    }

    HapticFeedback.mediumImpact();

    final newState = true;

    setState(() {
      if (mission.type == MissionType.fixed) {
        _fixedMissions[mission.id] = mission.copyWith(completed: newState);
      } else {
        _customMissions[mission.id] = mission.copyWith(completed: newState);
      }
    });

    _confettiController.forward(from: 0);
    _showXpGainAnimation(mission.xp);
    _updateProgress();

    await _batchController.enqueueMissionToggle(
      missionId: mission.id,
      optimisticState: newState,
      
      operation: () async {
        return await _missionService.toggleMission(
          serverId: serverId,
          userId: userId,
          currentUser: currentUser,
          mission: mission,
          newState: newState,
        );
      },
      
      onSuccess: (dynamic result) {
        if (!mounted) return;
        
        final toggleResult = result as MissionToggleResult;
        
        if (toggleResult.success && toggleResult.updatedUser != null) {
          userProvider.updateLocalUser(toggleResult.updatedUser!);
          
          HapticFeedback.heavyImpact();
          
          if (toggleResult.hasAttributeChanges) {
            _showAttributeAnimation(toggleResult.attributeChanges);
          }
          
          if (toggleResult.leveledUp) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                showLevelUpAnimation(
                  context,
                  newLevel: toggleResult.updatedUser!.level,
                  newRank: toggleResult.updatedUser!.rank,
                );
              }
            });
          }
          
          // ✅ VERIFICAR E MOSTRAR POPUPS DE CONQUISTAS
          Future.delayed(const Duration(milliseconds: 1000), () {
            _checkAndShowAchievementPopups();
          });
        }
      },
      
      onError: (dynamic error) {
        if (!mounted) return;
        
        HapticFeedback.heavyImpact();
        
        setState(() {
          if (mission.type == MissionType.fixed) {
            _fixedMissions[mission.id] = mission.copyWith(completed: false);
          } else {
            _customMissions[mission.id] = mission.copyWith(completed: false);
          }
        });
      },
    );
  }

  void _showAttributeAnimation(Map<String, int> changes) {
    if (changes.isEmpty) return;

    final overlay = Overlay.of(context);
    
    for (final entry in changes.entries) {
      final overlayEntry = OverlayEntry(
        builder: (context) => _AttributeGainAnimation(
          attribute: entry.key,
          value: entry.value,
          onComplete: () {},
        ),
      );

      overlay.insert(overlayEntry);
      Future.delayed(const Duration(milliseconds: 2000), () {
        overlayEntry.remove();
      });
    }
  }

  void _updateProgress() {
    _progressController.forward(from: 0);
  }

  void _showXpGainAnimation(int xp) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final position = Offset(size.width / 2, size.height / 2);

    final overlayEntry = OverlayEntry(
      builder: (context) => _XpGainAnimation(
        xp: xp,
        position: position,
        onComplete: () {},
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 1500), () {
      overlayEntry.remove();
    });
  }

  void _navigateToCreateMission() async {
    final userProvider = context.read<UserProvider>();
    final theme = _getThemeForRank(userProvider.currentUser?.rank ?? 'E');

    HapticFeedback.mediumImpact();

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMissionScreen(
          fixedMissionsCount: _fixedMissions.length,
          customMissionsCount: _customMissions.length,
          theme: theme,
        ),
      ),
    );

    if (result == true) {
      await _loadMissions(forceRefresh: true);
    }
  }

  Future<void> _deleteCustomMission(String missionId) async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.currentUser?.id;
    final serverId = userProvider.currentServerId;

    if (userId == null || serverId == null) return;

    final mission = _customMissions[missionId];
    if (mission == null) return;

    if (mission.completed) {
      HapticFeedback.mediumImpact();
      return;
    }

    HapticFeedback.lightImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = _getThemeForRank(userProvider.currentUser?.rank ?? 'E');
        return AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Deletar?', style: TextStyle(fontSize: 18)),
          content: Text(
            'Tem certeza?',
            style: TextStyle(color: theme.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: theme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('DELETAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final today = _getTodayKey();

      await _dbService.deleteDailyMission(
        serverId: serverId,
        userId: userId,
        date: today,
        missionType: 'custom',
        missionId: missionId,
      );

      _toggleController.clearMissionState(missionId);
      final cacheKey = 'missions_${serverId}_${userId}_$today';
      _cache.invalidate(cacheKey);
      await _loadMissions(forceRefresh: true);

      if (mounted) {
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      AppConstants.debugLog('Erro ao deletar missão: $e');
    }
  }

 @override
Widget build(BuildContext context) {
  return Consumer<UserProvider>(
    builder: (context, userProvider, _) {
      final theme = _getThemeForRank(userProvider.currentUser?.rank ?? 'E');
      final totalCompleted = [..._fixedMissions.values, ..._customMissions.values]
          .where((m) => m.completed)
          .length;
      final total = _fixedMissions.length + _customMissions.length;
      final totalXp = [..._fixedMissions.values, ..._customMissions.values]
          .where((m) => m.completed)
          .fold(0, (sum, m) => sum + m.xp);

      return Scaffold(
        backgroundColor: theme.background,
        body: AnimatedParticlesBackground(  
          particleColor: theme.primary,      
          particleCount: 30,                 
          child: Container(
            decoration: BoxDecoration(gradient: theme.backgroundGradient),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(theme, totalCompleted, total, totalXp),
                  _buildFilterTabs(theme),
                  Expanded(
                    child: _loading
                        ? _buildLoadingState(theme)
                        : _buildMissionsList(theme),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: _buildFloatingActionButton(theme),
      );
    },
  );
}

  Widget _buildHeader(RankTheme theme, int completed, int total, int totalXp) {
    return AnimatedParticlesBackground(
      particleColor: theme.primary,
      particleCount: 30,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Missões',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completed/$total completas • $totalXp pts ganhos',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isRefreshing ? null : _refreshMissions,
                icon: _isRefreshing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(theme.primary),
                        ),
                      )
                    : Icon(Icons.refresh_rounded, color: theme.primary, size: 24),
              ),
            ],
          ),
        ],
      ),
    )
    );
  }

  Widget _buildFilterTabs(RankTheme theme) {
    final filters = _getAvailableFilters();
    
    return AnimatedParticlesBackground(
      particleColor: theme.primary,
      particleCount: 30,
    child: Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          final color = _getFilterColor(filter);
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedFilter = filter);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: [color, color.withOpacity(0.7)])
                    : null,
                color: isSelected ? null : theme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : theme.surfaceLight.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getFilterIcon(filter),
                    size: 16,
                    color: isSelected ? Colors.white : theme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : theme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    )
    );
  }

  Widget _buildLoadingState(RankTheme theme) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(theme.primary),
      ),
    );
  }

  Widget _buildMissionsList(RankTheme theme) {
    final filteredMissions = _getFilteredMissions();
    final pendingMissions = filteredMissions.where((m) => !m.completed).toList();
    final completedMissions = filteredMissions.where((m) => m.completed).toList();

    return AnimatedParticlesBackground(
      particleColor: theme.primary,
      particleCount: 30,
    child: RefreshIndicator(
      onRefresh: _refreshMissions,
      color: theme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          // PENDENTES
          if (pendingMissions.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.radio_button_unchecked_rounded, size: 18, color: theme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pendentes (${pendingMissions.length})',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...pendingMissions.map((mission) => _buildCompactMissionCard(mission, theme)),
            const SizedBox(height: 20),
          ],

          // CONCLUÍDAS
          if (completedMissions.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: theme.success),
                const SizedBox(width: 8),
                Text(
                  'Concluídas (${completedMissions.length})',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...completedMissions.map((mission) => _buildCompactMissionCard(mission, theme)),
          ],

          if (filteredMissions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'Nenhuma missão nesta categoria',
                  style: TextStyle(
                    color: theme.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    )
    );
  }

  Widget _buildCompactMissionCard(MissionModel mission, RankTheme theme) {
    final isFixed = mission.type == MissionType.fixed;
    final category = _categorizeMission(mission.name);
    final categoryColor = _getFilterColor(category);
    final attributes = _getAttributesForMission(mission.name);
    
    //  COR DO CARD BASEADA NO TIPO (Fixa = Amarelada, Custom = Azul)
    final cardBaseColor = isFixed ? Colors.amber : Colors.blue;

    return StreamBuilder<MissionBatchState>(
      stream: _batchController.stateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isActive = state?.isActive(mission.id) ?? false;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          excludeFromSemantics: true,
          onTap: mission.completed ? null : () => _toggleMission(mission),
          onLongPress: !isFixed && !mission.completed
              ? () {
                  HapticFeedback.mediumImpact();
                  _deleteCustomMission(mission.id);
                }
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: mission.completed
                  ? LinearGradient(
                      colors: [
                        cardBaseColor.withOpacity(0.15),
                        cardBaseColor.withOpacity(0.08),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        cardBaseColor.withOpacity(0.25),
                        cardBaseColor.withOpacity(0.15),
                      ],
                    ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: mission.completed
                    ? theme.success.withOpacity(0.4)
                    : cardBaseColor.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // CHECKBOX
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: mission.completed
                        ? LinearGradient(colors: [theme.success, theme.success.withOpacity(0.7)])
                        : null,
                    color: mission.completed ? null : cardBaseColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: mission.completed ? Colors.transparent : cardBaseColor,
                      width: 2,
                    ),
                  ),
                  child: mission.completed
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : isActive
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(cardBaseColor),
                              ),
                            )
                          : null,
                ),
                const SizedBox(width: 12),

                // CONTEÚDO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.name,
                        style: TextStyle(
                          color: mission.completed ? theme.textSecondary : theme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          decoration: mission.completed ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      
                      // BADGES
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Badge de categoria
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: categoryColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getFilterIcon(category), size: 10, color: categoryColor),
                                const SizedBox(width: 3),
                                Text(
                                  category,
                                  style: TextStyle(
                                    color: categoryColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // BADGES DE ATRIBUTOS
                          ...attributes.entries.map((attr) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getAttributeColorByKey(attr.key).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _getAttributeColorByKey(attr.key).withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                '${_getAttributeIconByKey(attr.key)} +${attr.value}',
                                style: TextStyle(
                                  color: _getAttributeColorByKey(attr.key),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // XP BADGE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade700, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${mission.xp}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
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

  String _getAttributeIconByKey(String key) {
    switch (key) {
      case 'study':
        return '📚';
      case 'discipline':
        return '🎯';
      case 'responsibility':
        return '⚔️';
      case 'consistency':
        return '🔥';
      case 'evolution':
        return '⚡';
      default:
        return '✨';
    }
  }

  Color _getAttributeColorByKey(String key) {
    switch (key) {
      case 'study':
        return Colors.blue;
      case 'discipline':
        return Colors.purple;
      case 'responsibility':
        return Colors.orange;
      case 'consistency':
        return Colors.red;
      case 'evolution':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFloatingActionButton(RankTheme theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: theme.primaryGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _navigateToCreateMission,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        label: const Text(
          'NOVA MISSÃO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 13,
          ),
        ),
      ),
    );
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
}

// =============================================================================
// ANIMAÇÕES
// =============================================================================

class _AttributeGainAnimation extends StatefulWidget {
  final String attribute;
  final int value;
  final VoidCallback onComplete;

  const _AttributeGainAnimation({
    required this.attribute,
    required this.value,
    required this.onComplete,
  });

  @override
  State<_AttributeGainAnimation> createState() => _AttributeGainAnimationState();
}

class _AttributeGainAnimationState extends State<_AttributeGainAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  late Animation<double> _scale;

  String _getAttributeName(String attr) {
    switch (attr) {
      case 'study':
        return 'Estudo';
      case 'discipline':
        return 'Disciplina';
      case 'responsibility':
        return 'Responsabilidade';
      case 'consistency':
        return 'Consistência';
      case 'evolution':
        return 'Evolução';
      default:
        return attr;
    }
  }

  String _getAttributeIcon(String attr) {
    switch (attr) {
      case 'study':
        return '📚';
      case 'discipline':
        return '🎯';
      case 'responsibility':
        return '⚔️';
      case 'consistency':
        return '🔥';
      case 'evolution':
        return '⚡';
      default:
        return '✨';
    }
  }

  Color _getAttributeColor(String attr) {
    switch (attr) {
      case 'study':
        return Colors.blue;
      case 'discipline':
        return Colors.purple;
      case 'responsibility':
        return Colors.orange;
      case 'consistency':
        return Colors.red;
      case 'evolution':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);
    
    _offset = Tween<Offset>(
      begin: const Offset(0, 50),
      end: const Offset(0, -100),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Positioned(
      left: size.width / 2 - 100,
      top: size.height / 2 - 50,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: _offset.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getAttributeColor(widget.attribute),
                        _getAttributeColor(widget.attribute).withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _getAttributeColor(widget.attribute).withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getAttributeIcon(widget.attribute),
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getAttributeName(widget.attribute),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '+${widget.value}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
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
        },
      ),
    );
  }
}

class _XpGainAnimation extends StatefulWidget {
  final int xp;
  final Offset position;
  final VoidCallback onComplete;

  const _XpGainAnimation({
    required this.xp,
    required this.position,
    required this.onComplete,
  });

  @override
  State<_XpGainAnimation> createState() => _XpGainAnimationState();
}

class _XpGainAnimationState extends State<_XpGainAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -120),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scale = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 60,
      top: widget.position.dy - 30,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: _offset.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade700, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        '+${widget.xp}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// TELA DE CRIAR MISSÃO
// =============================================================================

class CreateMissionScreen extends StatefulWidget {
  final int fixedMissionsCount;
  final int customMissionsCount;
  final RankTheme theme;

  const CreateMissionScreen({
    Key? key,
    required this.fixedMissionsCount,
    required this.customMissionsCount,
    required this.theme,
  }) : super(key: key);

  @override
  State<CreateMissionScreen> createState() => _CreateMissionScreenState();
}

class _CreateMissionScreenState extends State<CreateMissionScreen> {
  final _nameController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final _cache = CacheService.instance;
  MissionType _selectedType = MissionType.custom;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createMission() async {
    if (_nameController.text.trim().isEmpty) {
      return;
    }

    // ✅ ATUALIZADO: Verificação com novos limites
    if (_selectedType == MissionType.fixed && widget.fixedMissionsCount >= MAX_FIXED_MISSIONS) {
      return;
    }

    if (_selectedType == MissionType.custom && widget.customMissionsCount >= MAX_CUSTOM_MISSIONS) {
      return;
    }

    setState(() => _isCreating = true);
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
      final xp = _selectedType == MissionType.fixed
          ? XpCalculator.fixedMissionXp(userLevel)
          : XpCalculator.customMissionXp(userLevel);

      await _dbService.addCustomMission(
        serverId: serverId,
        userId: userId,
        date: date,
        missionName: _nameController.text.trim(),
        xp: xp,
        missionType: _selectedType == MissionType.fixed ? 'fixed' : 'custom',
      );

      final cacheKey = 'missions_${serverId}_${userId}_$date';
      _cache.invalidate(cacheKey);

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Erro silencioso
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ATUALIZADO: Verificações com novos limites
    final canCreateFixed = widget.fixedMissionsCount < MAX_FIXED_MISSIONS;
    final canCreateCustom = widget.customMissionsCount < MAX_CUSTOM_MISSIONS;

    return Scaffold(
      backgroundColor: widget.theme.background,
      body: Container(
        decoration: BoxDecoration(gradient: widget.theme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTypeSelector(canCreateFixed, canCreateCustom),
                      const SizedBox(height: 20),
                      
                      TextField(
                        controller: _nameController,
                        style: TextStyle(color: widget.theme.textPrimary),
                        maxLength: 50,
                        decoration: InputDecoration(
                          labelText: 'Nome da Missão',
                          hintText: 'Ex: Estudar 2 horas',
                          labelStyle: TextStyle(color: widget.theme.textSecondary),
                          hintStyle: TextStyle(color: widget.theme.textTertiary),
                          filled: true,
                          fillColor: widget.theme.surface.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: widget.theme.primary, width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          counterStyle: TextStyle(color: widget.theme.textTertiary),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Consumer<UserProvider>(
                        builder: (context, userProvider, _) {
                          final userLevel = userProvider.currentUser?.level ?? 1;
                          final xp = _selectedType == MissionType.fixed
                              ? XpCalculator.fixedMissionXp(userLevel)
                              : XpCalculator.customMissionXp(userLevel);
                          final color = _selectedType == MissionType.fixed ? Colors.amber : Colors.blue;

                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color.withOpacity(0.25),
                                  color.withOpacity(0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: color.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: color, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'RECOMPENSA',
                                        style: TextStyle(
                                          color: widget.theme.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '+$xp XP',
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
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
                      const SizedBox(height: 32),
                      
                      Container(
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
                        child: ElevatedButton(
                          onPressed: _isCreating ? null : _createMission,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'CRIAR MISSÃO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.theme.surface.withOpacity(0.7),
                    widget.theme.surfaceLight.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.theme.surfaceLight.withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: widget.theme.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'NOVA MISSÃO',
              style: TextStyle(
                color: widget.theme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(bool canCreateFixed, bool canCreateCustom) {
    return Column(
      children: [
        _buildTypeOption(
          type: MissionType.fixed,
          title: 'MISSÃO FIXA',
          subtitle: 'Rotina diária essencial',
          icon: Icons.star_rounded,
          color: Colors.amber,
          canCreate: canCreateFixed,
          count: '${widget.fixedMissionsCount}/$MAX_FIXED_MISSIONS', // ✅ ATUALIZADO
        ),
        const SizedBox(height: 12),
        _buildTypeOption(
          type: MissionType.custom,
          title: 'MISSÃO PERSONALIZADA',
          subtitle: 'Sua meta única',
          icon: Icons.auto_awesome_rounded,
          color: Colors.blue,
          canCreate: canCreateCustom,
          count: '${widget.customMissionsCount}/$MAX_CUSTOM_MISSIONS', // ✅ ATUALIZADO
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required MissionType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool canCreate,
    required String count,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: canCreate
          ? () {
              HapticFeedback.lightImpact();
              setState(() => _selectedType = type);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [color.withOpacity(0.25), color.withOpacity(0.12)])
              : null,
          color: isSelected ? null : widget.theme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : widget.theme.surfaceLight.withOpacity(0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: widget.theme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: widget.theme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    color: canCreate ? color : widget.theme.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!canCreate)
                  Text(
                    'CHEIO',
                    style: TextStyle(
                      color: widget.theme.error,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, color: color, size: 24),
            ],
          ],
        ),
      ),
    );
  }
}