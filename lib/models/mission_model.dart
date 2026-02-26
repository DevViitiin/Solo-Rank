/// 📌 MISSION MODEL V2 - AJUSTADO PARA SISTEMA EXISTENTE
/// 
/// ✅ Mantém estrutura original
/// ✅ Adiciona categorias para customizadas
/// ✅ Adiciona helpers para detecção de tipo
/// ✅ Compatível com Firebase existente

enum MissionType {
  fixed,   // Missões fixas diárias (3-5)
  custom,  // Missões customizadas (5-7)
}

/// Categoria de missão customizada (opcional)
enum CustomMissionCategory {
  study,     // Estudo
  fitness,   // Treino/Shape
  habit,     // Hábito geral
  other,     // Outros
}

class MissionModel {
  final String id;
  final String name;
  final int xp;
  final bool completed;
  final DateTime? completedAt;
  final MissionType type;
  final CustomMissionCategory? category; // ✅ NOVO - apenas para custom

  MissionModel({
    required this.id,
    required this.name,
    required this.xp,
    this.completed = false,
    this.completedAt,
    required this.type,
    this.category, // ✅ NOVO
  });

  factory MissionModel.fromMap(String id, Map<String, dynamic> map, MissionType type) {
    // ✅ Parse category se for custom e tiver o campo
    CustomMissionCategory? category;
    if (type == MissionType.custom && map.containsKey('category')) {
      category = _parseCategoryFromString(map['category'] as String?);
    }
    
    return MissionModel(
      id: id,
      name: map['name']?.toString() ?? '',
      xp: _parseInt(map['xp']) ?? 0,
      completed: map['completed'] == true,
      completedAt: _parseDateTime(map['completedAt']),
      type: type,
      category: category, // ✅ NOVO
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    
    try {
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        return DateTime.parse(value);
      }
    } catch (e) {
      print('⚠️ Erro ao parsear DateTime: $e');
    }
    
    return null;
  }
  
  // ✅ NOVO - Parse categoria
  static CustomMissionCategory _parseCategoryFromString(String? str) {
    if (str == null) return CustomMissionCategory.other;
    
    switch (str.toLowerCase()) {
      case 'study':
      case 'estudo':
        return CustomMissionCategory.study;
      case 'fitness':
      case 'treino':
      case 'shape':
        return CustomMissionCategory.fitness;
      case 'habit':
      case 'habito':
      case 'hábito':
        return CustomMissionCategory.habit;
      default:
        return CustomMissionCategory.other;
    }
  }

  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'xp': xp,
      'completed': completed,
      if (completedAt != null) 'completedAt': completedAt!.millisecondsSinceEpoch,
    };
    
    // ✅ NOVO - Salvar categoria se for custom
    if (type == MissionType.custom && category != null) {
      map['category'] = category.toString().split('.').last;
    }
    
    return map;
  }

  MissionModel copyWith({
    String? name,
    int? xp,
    bool? completed,
    DateTime? completedAt,
    CustomMissionCategory? category, // ✅ NOVO
  }) {
    return MissionModel(
      id: id,
      name: name ?? this.name,
      xp: xp ?? this.xp,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      type: type,
      category: category ?? this.category, // ✅ NOVO
    );
  }
  
  // =========================================================================
  // ✅ NOVOS HELPERS - DETECÇÃO DE TIPO DE MISSÃO
  // =========================================================================
  
  /// Verifica se é missão fixa
  bool get isFixed => type == MissionType.fixed;
  
  /// Verifica se é missão customizada
  bool get isCustom => type == MissionType.custom;
  
  /// Verifica se é missão de estudo (por categoria OU palavras-chave)
  bool get isStudyMission => 
      category == CustomMissionCategory.study ||
      _containsStudyKeywords(name);
  
  /// Verifica se é missão de treino (por categoria OU palavras-chave)
  bool get isFitnessMission => 
      category == CustomMissionCategory.fitness ||
      _containsFitnessKeywords(name);
  
  /// Verifica se é missão de hábito
  bool get isHabitMission => 
      category == CustomMissionCategory.habit;
  
  // Keywords para detecção automática
  static bool _containsStudyKeywords(String name) {
    final keywords = [
      'estudo', 'estudar', 'ler', 'leitura', 'livro', 'curso',
      'aula', 'aprender', 'revisar', 'revisão', 'pesquisar',
      'study', 'read', 'book', 'course', 'learn', 'review',
    ];
    final lowerName = name.toLowerCase();
    return keywords.any((k) => lowerName.contains(k));
  }
  
  static bool _containsFitnessKeywords(String name) {
    final keywords = [
      'treino', 'treinar', 'academia', 'exercício', 'malhar',
      'corrida', 'correr', 'natação', 'nadar', 'yoga', 'alongamento',
      'workout', 'gym', 'exercise', 'run', 'swim', 'fitness',
    ];
    final lowerName = name.toLowerCase();
    return keywords.any((k) => lowerName.contains(k));
  }
  
  @override
  String toString() {
    return 'Mission(id: $id, name: $name, type: $type, completed: $completed, category: $category)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MissionModel && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

// =============================================================================
// ✅ NOVO - ESTADO DAS MISSÕES DO DIA
// =============================================================================

/// Estado agregado das missões do dia
class DailyMissionsState {
  final List<MissionModel> fixedMissions;
  final List<MissionModel> customMissions;
  final DateTime date;
  
  DailyMissionsState({
    required this.fixedMissions,
    required this.customMissions,
    required this.date,
  });
  
  // Totais
  int get totalMissions => fixedMissions.length + customMissions.length;
  int get completedMissions => 
      fixedMissions.where((m) => m.completed).length +
      customMissions.where((m) => m.completed).length;
  
  // Fixas
  int get fixedCompleted => fixedMissions.where((m) => m.completed).length;
  int get fixedTotal => fixedMissions.length;
  
  // Customizadas
  int get customCompleted => customMissions.where((m) => m.completed).length;
  int get customTotal => customMissions.length;
  
  // Status de completude
  bool get allFixedCompleted => 
      fixedMissions.isNotEmpty && 
      fixedMissions.every((m) => m.completed);
  
  bool get allCustomCompleted => 
      customMissions.isNotEmpty && 
      customMissions.every((m) => m.completed);
  
  bool get allDailyCompleted => allFixedCompleted && allCustomCompleted;
  
  // Bônus de customizadas
  bool get reached3CustomBonus => customCompleted >= 3;
  bool get reachedAllCustomBonus => allCustomCompleted;
  
  // Progresso
  double get progressPercentage => 
      totalMissions > 0 ? (completedMissions / totalMissions) : 0.0;
  
  double get fixedProgressPercentage => 
      fixedTotal > 0 ? (fixedCompleted / fixedTotal) : 0.0;
  
  double get customProgressPercentage => 
      customTotal > 0 ? (customCompleted / customTotal) : 0.0;
  
  @override
  String toString() {
    return 'DailyMissionsState('
        'fixed: $fixedCompleted/$fixedTotal, '
        'custom: $customCompleted/$customTotal, '
        'total: $completedMissions/$totalMissions)';
  }
}

// =============================================================================
// MANTÉM SEU XP CALCULATOR ORIGINAL
// =============================================================================

/// Calcula XP baseado no nível do usuário
class XpCalculator {
  /// XP para missões fixas (diárias obrigatórias)
  static int fixedMissionXp(int userLevel) {
    // Missões fixas dão mais XP e escalam com o nível
    return 50 + (userLevel * 10);
  }

  /// XP para missões customizadas
  static int customMissionXp(int userLevel) {
    // Missões customizadas dão menos XP
    return 30 + (userLevel * 5);
  }

  /// XP necessário para subir de nível
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return (level * 100) + ((level - 1) * 25);
  }

  /// XP total necessário até um nível
  static int totalXpForLevel(int level) {
    int total = 0;
    for (int i = 1; i <= level; i++) {
      total += xpForLevel(i);
    }
    return total;
  }

  /// Calcula XP bônus por streak
  static int streakBonus(int streakDays) {
    if (streakDays < 3) return 0;
    if (streakDays < 7) return 25;
    if (streakDays < 14) return 50;
    if (streakDays < 30) return 100;
    return 150; // 30+ dias
  }

  /// Penalidade por missões não completadas
  static int incompletePenalty(int userLevel, int incompleteMissions) {
    // Perde 40% do XP que ganharia por missão
    final penaltyPerMission = (fixedMissionXp(userLevel) * 0.4).toInt();
    return penaltyPerMission * incompleteMissions;
  }
}